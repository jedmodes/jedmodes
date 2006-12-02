% newsflash.sl
% 
% $Id: newsflash.sl,v 1.1 2006/12/02 11:52:37 paul Exp paul $
%
% Copyright (c) 2006 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This is a RSS+Atom reader for JED.  It uses the expat module.
% Expat outputs UTF-8, so this works best in UTF-8 mode.

require("curl");
require("expat");
require("pcre");
require("sqlite");
require("view");
autoload("jedscape_get_url", "jedscape");

implements("newsflash");
variable mode = "newsflash";
variable item_struct = struct {
   title,
   link,
   description,
   date,
   is_read,
   
   line
};

variable userdata = struct {
   is_atom, % not used
   % <channel> will be an item_struct
   channel, % not used
   
   url,
   cleanlevel,
   
   % <item>s
   item,
   items,
   
   % parser state
   state,
   states,
   
   % reader-specific data
   buffer,
   lines,
   itemhandler,
   is_read
};

variable debug_mode=1;
%{{{ database

variable db, dbfile = dircat(Jed_Home_Directory, "rss.db");
$1 = file_status(dbfile);
db = sqlite_open(dbfile);
!if ($1)
{
   % Some fields (e.g. description and date in the items table) are currently not used
   sqlite_exec(db, "CREATE TABLE feeds (feed_id INTEGER PRIMARY KEY, name TEXT UNIQUE, url TEXT UNIQUE, cleanlevel INTEGER default '3')");
   sqlite_exec(db, "CREATE TABLE items (item_id INTEGER PRIMARY KEY, feed TEXT, title TEXT, link TEXT, description TEXT, is_read INTEGER default 0, date INTEGER, UNIQUE (feed, title, link))");
   foreach $2 ({
	{"BBC world news", "http://newsrss.bbc.co.uk/rss/newsonline_uk_edition/world/rss.xml"},
	{"Cadenhead", "http://www.cadenhead.org/workbench/rss"},
	{"CNET News.com", "http://export.cnet.com/export/feeds/news/rss/1,11176,,00.xml"},
	{"Debian Security Advisories", "http://www.debian.org/security/dsa.en.rdf"},
	{"Debian Security Advisories - Long format", "http://www.debian.org/security/dsa-long.en.rdf"},
	{"Debian Jed Group", "http://alioth.debian.org/export/rss20_news.php?group_id=30638"},
	{"Freshmeat.net", "http://freshmeat.net/backend/fm.rdf"},
	{"JED checkins", "http://cia.navi.cx/stats/project/jed/.rss?ver=2&medium=unquoted"},
	{"JMR file releases", "http://sourceforge.net/export/rss2_projfiles.php?group_id=14968"},
	{"Joel on Software", "http://www.joelonsoftware.com/rss.xml"},
	{"Kuro5hin.org", "http://www.kuro5hin.org/backend.rdf"},
	{"LWN (Linux Weekly News)", "http://lwn.net/headlines/rss"},
	{"Motley fool", "http://www.fool.com/xml/foolnews_rss091.xml"},
	{"NewsForge", "http://newsforge.com/index.rss"},
	{"NY Times: Technology", "http://partners.userland.com/nytRss/technology.xml"},
	{"NY Times", "http://partners.userland.com/nytRss/nytHomepage.xml"},
	{"Quote of the day", "http://www.quotationspage.com/data/qotd.rss"},
	{"The Register", "http://www.theregister.co.uk/tonys/slashdot.rdf"},
	{"Slashdot", "http://slashdot.org/index.rss"},
	{"Tweakers.net (Dutch)", "http://tweakers.net/feeds/mixed.xml"},
	{"Wired News", "http://www.wired.com/news_drop/netcenter/netcenter.rdf"},
	{"xml.com (rss 1.0)", "http://www.oreillynet.com/pub/feed/20?format=rss1"},
	{"xml.com (rss 2.0)", "http://www.oreillynet.com/pub/feed/20?format=rss2"},
	{"xml.com (Atom)", "http://www.oreillynet.com/pub/feed/20"}
   })
     sqlite_exec(db, sprintf("INSERT OR IGNORE INTO feeds ('name', 'url') VALUES ('%s', '%s')",
			     $2[0], $2[1]));
   sqlite_exec(db, "UPDATE feeds SET cleanlevel=0 WHERE name='JED checkins'");
   sqlite_exec(db, "UPDATE feeds SET cleanlevel=2 WHERE name='w3c'");
}
sqlite_exec(db, "PRAGMA synchronous = OFF;");

%}}}
%{{{ rss parser
define push_state(p, s)
{
   list_insert(p.userdata.states, s);
   p.userdata.state = s;
}

define pop_state(p)
{
   ()=list_pop(p.userdata.states);
   if (length(p.userdata.states))
     p.userdata.state = p.userdata.states[0];
   else p.userdata.state = "";
}

% We need all these function because it's not possible to pass  a reference
% to a structure member.  It would be easier to just read characterdata into a
% "characterdata" member and copy it to the correct member when the element's
% closing tag is seen, but in some RSS dialects the "item" elements are
% children of the "channel" element and in some they are siblings.
define read_title(p, s)
{
   p.userdata.item.title += s;
}

define read_link(p, s)
{
   p.userdata.item.link +=s;
}

define read_description(p, s)
{
   p.userdata.item.description += s;
}

define read_date(p, s)
{
   p.userdata.item.date += s;
}

define read_channel_description(p, s)
{
   p.userdata.channel.description += s;
}

define read_channel_title(p, s)
{
   p.userdata.channel.title += s;
}

define read_channel_link(p, s)
{
   p.userdata.channel.link +=s;
}

define startElement(p, name, atts) {
   if (name == "item" or name == "entry")
     {
	p.userdata.item = @item_struct;
	p.userdata.item.title = "";
	p.userdata.item.link = "";
	p.userdata.item.description = "";
	p.userdata.item.is_read = 0;
	p.userdata.item.date = "";
     }
   else if (name == "channel" or name == "feed")
     {
	if (name == "feed")
	  p.userdata.is_atom = 1;
	else
	  p.userdata.is_atom = 0;
	p.userdata.channel = @item_struct;
	p.userdata.channel.title = "";
	p.userdata.channel.description = "";
	p.userdata.channel.link = "";
     }
   else if (p.userdata.state == "item"
	   or p.userdata.state == "entry")
     {	  
	switch (name)
	  {
	   case "title":
	     p.characterdatahandler = &read_title;
	  }
	  {
	   case "link":
	     p.characterdatahandler = &read_link;
	  }
	  {
	     % summary and content are for Atom feeds
	     % presumably they are different things, but I can't find many
	     % Atom feeds to test this on.
	   case "description" or case "summary" or case "content":
	     p.characterdatahandler = &read_description;
	  }
	  {
	   case "dc:date":
	     p.characterdatahandler = &read_date;
	  }
     }
   else if (p.userdata.state == "channel"
	   or p.userdata.state == "feed")
     {	  
	switch (name)
	  {
	   case "title":
	     p.characterdatahandler = &read_channel_title;
	  }
	  {
	   case "link":
	     p.characterdatahandler = &read_channel_link;
	  }
	  {
	   case "description" or case "summary":
	     p.characterdatahandler = &read_channel_description;
	  }
     }

   push_state(p, name);
}



define endElement(p, name)
{
   p.characterdatahandler = NULL;
   switch (name)
     {
      case "dc:date":
	% dc:data may occur outside an item
	if (is_struct_type(p.userdata.item))
	  p.userdata.item.date = extract_element(p.userdata.item.date, 0, 'T');
     }
     {
      case "item" or case "entry":
	p.userdata.itemhandler();
	list_append(p.userdata.items, p.userdata.item);
     }
   pop_state(p);
}

%}}}
%{{{ get the feed
define write_callback(p, data)
{
   xml_parse(p, data, 0);
   if (debug_mode)
     {
	setbuf("XML source");
	insert(data);
	setbuf(p.userdata.buffer);
     }
   return 0;
}

define rss_new(url)
{
   if (debug_mode)
     {
	setbuf("XML source");
	erase_buffer();
     }
   variable p = xml_new();
   p.userdata = @userdata;
   p.userdata.items={};
   p.userdata.states={};
   p.userdata.state="";
   p.userdata.item="";
   p.startelementhandler = &startElement;
   p.endelementhandler = &endElement;
   p.userdata.url = url;
   return p;
}

define get_rss(p)
{
   variable c = curl_new(p.userdata.url);
   curl_setopt(c, CURLOPT_FOLLOWLOCATION, 1);
   curl_setopt(c, CURLOPT_WRITEFUNCTION, &write_callback, p);
   runhooks("jedscape_curlopt_hook", c);

   curl_perform (c);
   xml_parse(p, "", 1);
}

%}}}
%{{{ store the feed
% For now this only stores the name of the feed and the link
% The database is only used as a bookmark manager for feeds
% and to mark items as read.
% Actually, storing the unread items is not really necessary.
define store_feed(feed, items)
{
   variable item;
   variable qfeed = str_quote_string(feed, "'", '\'');
   % We know what items are in the feed now, presumably old items
   % won't come back so we can erase them from the database
   sqlite_exec(db, sprintf("delete from items where feed = '%s'", qfeed));
   foreach item (items)
     {
	sqlite_exec (db, sprintf("insert or ignore into items (feed, title, link, is_read) values ('%s', '%s', '%s', '%d')",
				 qfeed,
				 str_quote_string(item.title, "'", '\''),
				 str_quote_string(item.link, "'", '\''), 
				 item.is_read));
     }
}

   
%}}}

%{{{ rss mode
%{{{ html tagsoup cleaner

define remove_tags()
{
   mark_buffer();
   variable str = bufsubstr();
   variable re;
   if (_slang_utf8_ok)
     re = pcre_compile("<[^>]+>", PCRE_UTF8);
   else
     re = pcre_compile("<[^>]+>");
   bob();
   variable pos = 0, match_pos, match_len;
   while (pcre_exec(re, str, pos))
     {
	match_pos = pcre_nth_match(re, 0);
	match_len = match_pos[1] - match_pos[0];
	go_right(match_pos[0] - pos);
	deln(match_len);
	pos = match_pos[1];
     }
}

define characterdata_handler(p, t)
{
   p.userdata += t;
}

define clean_tagsoup()
{
   mark_buffer();
   variable item = bufsubstr();
   variable p = xml_new();
   p.userdata = "";
   p.characterdatahandler = &characterdata_handler;
   try
     {
	xml_parse(p, "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">", 0);
	xml_parse(p, "<html>", 0);
	xml_parse(p, item, 0);
	xml_parse(p, "</html>", 1);
	erase_buffer();
	insert(p.userdata);
     }
   catch ExpatError:
     {
	message("could not clean tagsoup");
	remove_tags();
     }
}

%}}}

define next_unread_item()
{
   push_mark();
   while (down(1))
     {
	if (get_line_color == color_number("keyword"))
	  {
	     pop_mark_0();
	     return;
	  }
     }
   pop_mark_1();
   message("no more unread items");
}

define item_at_point()
{
   variable feed = get_blocal_var("feed");
   variable i = wherefirst(what_line() < feed.lines);
   if (i == NULL) i = -1;
   else i--;
   return feed.items[i];
}

% Read in an item and mark it as read. Return  1 if the message is
% already in the window,  -1 if it had to be read in.

define get_item()
{
   variable u = get_blocal_var("feed");
   variable item = item_at_point();
   variable buf = whatbuf();
   if (buffer_visible("news description"))
     pop2buf("news description");
   else
     {
	onewindow();
	splitwindow();
	if (TOP_WINDOW_ROW != window_info('t'))
	  otherwindow();
	variable n1 = window_info('r');
	otherwindow();
	sw2buf("news description");
	loop (n1 - 5) enlargewin();
     }

   variable visible_item = get_blocal_var("item", NULL);
   if (visible_item == item) return 1;
   define_blocal_var("item", item);
   erase_buffer();
   insert(item.description);

   bob();
   push_mark();
   skip_chars(" \n");
   del_region();
   
   if (u.cleanlevel & 1)
     {
	replace("<p>", "\n");
	replace("</p>", "");
	clean_tagsoup();
	bob();
     }
   if (u.cleanlevel & 2)
     {
	do
	  {
	     skip_chars(" \n");
	     call("format_paragraph");
	  }
	while (bol_fsearch("\n"));
	bob();
     }
   set_buffer_modified_flag(0);
   sqlite_exec(db, sprintf("update items set is_read='1' where link='%s'",
			   str_quote_string(item.link, "'", '\'')));
   pop2buf(buf);
   set_line_color(color_number("normal"));
   variable next_line = wherefirst(u.lines > item.line);
   if (next_line==NULL) return -1;
   next_line=u.lines[next_line];
   loop(next_line - item.line - 1)
     {
	go_down_1();
	set_line_color(color_number("normal"));
     }
   return -1;
}

define scroll()
{
   variable buf =  whatbuf();
   variable item = item_at_point();
   pop2buf("news description");
   if (item == get_blocal_var("item", NULL))
     {
	push_spot();
	eob();
	if (what_line() - (pop_spot(), what_line()) > window_info('r') - window_line())
	  {
	     call("page_down");
	     pop2buf(buf);
	     return;
	  }
	else
	  {
	     pop2buf(buf);
	     next_unread_item();
	     ()=get_item();
	     pop2buf(buf);
	  }
     }
   else
     {
	pop2buf(buf);
	()= get_item();
	pop2buf(buf);
     }
}

define view_item()
{
   variable buf = whatbuf();
   ()=get_item();
   pop2buf(buf);
}


define rss_goto_page()
{
   variable item = item_at_point();
   browse_url(item.link);
}

define rss_jedscape()
{
   variable item = item_at_point();
   jedscape_get_url(item.link);
}

!if (keymap_p(mode))
{
   copy_keymap(mode, "view");
   definekey(&rss_goto_page, "g", mode);
   definekey(&onewindow, "h", mode);
   definekey(&rss_jedscape, "j", mode);
   definekey(&next_unread_item, "n", mode);
   definekey(&scroll, " ", mode);
}
      
define rss_mode()
{
   view_mode();
   use_keymap(mode);
   set_buffer_hook("newline_indent_hook", &view_item);
}

%}}}

%{{{ start reading news

define get_is_read(feed)
{
   variable links, is_read = struct {titles, links};
   variable t =sqlite_get_table(db, sprintf("select title, link from items where feed='%s' and is_read='1'",
					    str_quote_string(feed, "'", '\'')));
   if (length(t))
   {
      is_read.titles = t[[[1:]],0];
      is_read.links = t[[[1:]],1];
   }
   return is_read;
}

define item_handler(u)
{
   setbuf(u.buffer);
   u.item.line = what_line();
   if (NULL == wherefirst(u.item.title == u.is_read.titles
			  and u.item.link == u.is_read.links))
     {
	set_line_color(color_number("keyword"));
     }
   else
     {
	u.item.is_read=1;
	set_line_color(color_number("normal"));
     }
   if (u.item.date != "")
     {
	insert(u.item.date);
	insert("  ");
     }
   variable line;
   foreach line (strchop(u.item.title, '\n', 0))
     {
	insert(line);
	newline();
     }
   update(1);
}


public define newsflash()
{
   variable feeds = sqlite_get_table(db, "select name, url from feeds");
   variable names = feeds[[[1:]], 0], urls = feeds[[[1:]], 1];
   variable feed = read_with_completion(strjoin(feeds[[[1:]], 0], ","),
					"feed to read",
					"",
					"",
					's');
   variable url = wherefirst(feed == names);
   if (url == NULL)
     {
	url = read_mini("New feed! URL", "", "");
	sqlite_exec(db, sprintf("insert into feeds (name, url) values ('%s', '%s')",
				str_quote_string(feed, "'", '\''),
				str_quote_string(url, "'", '\'')));
     }
   else url = urls[url];
   variable p = rss_new(url);
   p.userdata.is_read = get_is_read(feed);
   p.userdata.cleanlevel = sqlite_get_row(db, sprintf("select cleanlevel from feeds where name='%s'",
					  str_quote_string(feed, "'", '\'')));
   p.userdata.itemhandler = &item_handler;
   p.userdata.buffer = feed;
   pop2buf(feed);
   get_rss(p);
   store_feed(feed, p.userdata.items);
   p.userdata.lines = Integer_Type[length(p.userdata.items)];
   variable item, i = 0;
   foreach item (p.userdata.items)
     {
	p.userdata.lines[i] = item.line;
	i++;
     }
   setbuf(feed);
   define_blocal_var("feed", p.userdata);
   rss_mode();
}

% This parses already fetched RSS data for reading an XML file from
% jedscape.sl
public define read_rss_data(url, data)
{
   variable feed = sqlite_get_table(db, sprintf("select name, url from feeds where url='%s'",
						str_quote_string(url, "'", '\'')));
   if (length(feed) > 2)
     {
	feed = feed[1, 0];
     }
   else
     {
	feed = read_mini("name for this feed", "", "");
	sqlite_exec(db, sprintf("insert into feeds (name, url) values ('%s', '%s')",
				str_quote_string(feed, "'", '\''),
				str_quote_string(url, "'", '\'')));
     }
   variable p = rss_new(url);
   p.userdata.is_read = get_is_read(feed);
   p.userdata.itemhandler = &item_handler;
   p.userdata.buffer = feed;
   pop2buf(feed);
   xml_parse(p, data, 1);
   store_feed(feed, p.userdata.items);
   p.userdata.lines = Integer_Type[length(p.userdata.items)];
   variable item, i = 0;
   foreach item (p.userdata.items)
     {
	p.userdata.lines[i] = item.line;
	i++;
     }
   define_blocal_var("feed", p.userdata);
   rss_mode();
}

%}}}

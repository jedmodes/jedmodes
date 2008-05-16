% jedscape.sl
%
% $Id: jedscape.sl,v 1.12 2008/05/16 18:55:02 paul Exp paul $
%
% Copyright (c) 2003-2008 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
%
% Mode for browsing the web in JED.
% 
% This uses the 'w3m -halfdump' command to parse the html, like Emacs-w3m
% does. To get w3m to output UTF-8 output with this option, you have to set
% some options: start w3m, press 'o', go down to 'Charset Settings'
% and set
% Display charset                                [Unicode (UTF-8)   ]
% Output halfdump with display charset           (*)YES  ( )NO
% go down, and press '[OK]'
% Or you can set these options in ~/.w3m/config:
% ext_halfdump 1
% display_charset UTF-8
provide("jedscape");
require("curl");
require("pcre");
require("sqlite");
require("bufutils");
require("view");
autoload("read_rss_data", "newsflash");
autoload("sqlited_table", "sqlited");
autoload("list2array", "datutils");

try
{
   require("gettext");
   eval("define _(s) {dgettext(\"lynx\", s);}", "jedscape");
}
catch OpenError:
{
   eval("define _(s) {s;}", "jedscape");
}
use_namespace("jedscape");


define jedscape_mode();
define find_page();
%!%+
%\variable{Jedscape_Home}
%\synopsis{the file name of the jedscape home page}
%\description
%  file opened by \var{jedscape}
%\seealso{jedscape}
%!%-
custom_variable("Jedscape_Home", dircat (Jed_Home_Directory, "jed_home.html"));

%!%+
%\variable{Jedscape_DB}
%\synopsis{filename of the jedscape database}
%\description
% The database has one table bookmarks(name, url) and a table for search
% engines.  Search Engines work more or less like in Firefox - e.g. type
% 'wp foo' at the 'open' prompt to search for 'foo' in Wikipedia.
%\seealso{jedscape}
%!%-
custom_variable("Jedscape_DB", dircat (Jed_Home_Directory, "jedscape_db"));

%!%+
%\variable{Jedscape_Emulation}
%\synopsis{jedscape key bindings scheme}
%\usage{String_Type Jedscape_Emulation = "w3"}
%\description
%  this may be lynx, netscape or w3
%\seealso{jedscape}
%!%-
custom_variable("Jedscape_Emulation", "w3");

private variable mode="jedscape";

private variable
  version="$Revision: 1.12 $",
  title="",
  url_file ="",			       %  /dir/file.html
  url_host="",			       %  http://host
  url_root,			       %  /dir
  href_list, href_begin_marks, href_end_marks,   %  hyperlinks
  href_anchor_list,		       %  part between <a> and </a>
  anchor_marks,	                       %  anchors
  links= struct{ previous, next, up, contents};   %  links in <head>

%{{{ database
$1 = file_status(Jedscape_DB);
variable db = sqlite_open(Jedscape_DB);
ifnot ($1)
{
   sqlite_exec(db, "CREATE TABLE bookmarks (name TEXT PRIMARY KEY, url TEXT)");
   sqlite_exec(db, "CREATE TABLE searchengines (name TEXT PRIMARY KEY, url TEXT)");
   sqlite_exec(db, "INSERT INTO searchengines (name, url) VALUES ('wp', 'http://en.wikipedia.org/wiki/Special:Search?&search=%s')");
   sqlite_exec(db, "INSERT INTO searchengines (name, url) VALUES ('php', 'http://php.net/search.php?pattern=%s&show=quickref')");
   sqlite_exec(db, "INSERT INTO searchengines (name, url) VALUES ('cpan', 'http://cpan.uwinnipeg.ca/search?query=%s&mode=dist')");
   sqlite_exec(db, "INSERT INTO searchengines (name, url) VALUES ('perl', 'http://cpan.uwinnipeg.ca/cgi-bin/docperl?query=%s&si=2')");
}

%}}}

%{{{ html parsing

private define bufsubstr_compress()
{
   strcompress(strtrim(bufsubstr()), " \n");
}

%{{{ <head>
% get the header links and title
private define get_links()
{
   variable href, rel;
   for (bob();
	re_fsearch("<link href=\"\\([^\"]*\\)\" rel=\"\\([^\"]*\\)\"");
	go_right_1())
     {
	(href, rel) =(regexp_nth_match(1), regexp_nth_match(2)); 
	if (length(where(get_struct_field_names(links) == rel)))
	  set_struct_field(links, rel, href);
	else if (rel == "home") % Docbook page
	  set_struct_field(links, "contents", href);
     }
   bob();
   if (re_fsearch("<title_alt title=\"\\([^\"]*\\)\""))
     title = str_replace_all(regexp_nth_match(1), char(160), " ");
}

%}}}

%{{{ w3m filtering
private variable entities = Assoc_Type[Char_Type];
foreach $1 ([{"nbsp", ' '},
	     {"gt", '>'},
	     {"lt", '<'},
	     {"amp", '&'},
	     {"quot", '\''},
	     {"apos", '\''},
	     {"circ", '^'},
	     {"tilde", '~'},
	     {"mdash", '-'}])
{
   entities[$1[0]] = $1[1];
}

	
private variable jedscape_temp=path_concat(Jed_Home_Directory, "jedscape_temp.html");
private define filter_html()
{
   bob();
   (href_list, href_anchor_list) = ({}, Assoc_Type[String_Type]);
   href_begin_marks = {};
   href_end_marks = {};
   anchor_marks = Assoc_Type[Mark_Type];
   set_struct_fields(links, NULL, NULL, NULL, NULL);
   flush("filtering");
   mark_buffer();
   ()=write_region_to_file(jedscape_temp);
   erase_buffer();
   setbuf("*jedscape*");
   set_readonly(0);
   erase_buffer();
   ()=run_shell_cmd(sprintf("w3m -cols %d -halfdump %s", window_info('w') - 5, jedscape_temp));
   %%% process links
   flush("marking links");
   get_links();
   
   %%% hrefs
   bob();
   while (re_fsearch("<a [^>]*href=\\([\"']\\)\\([^\"]*\\)\\1[^>]*>"))
     {
	list_append(href_list, str_replace_all(regexp_nth_match(2), "&amp;", "&"));
	()=replace_match("", 0);
	
	list_append(href_begin_marks, create_user_mark());
	insert("\e[29m");
	if (re_fsearch("</a>"))
	  ()=replace_match("\e[0]", 0);
	else
	  throw RunTimeError, "missing closing tag";
	list_append(href_end_marks, create_user_mark());
	
     }
   
   href_begin_marks = list2array(href_begin_marks, Mark_Type);
   href_end_marks = list2array(href_end_marks, Mark_Type);
   
   %%%  anchors
   for (bob(); re_fsearch("<a id=\\([\"']\\)\\([^\"]*\\)\\1"); go_right_1())
     {
	anchor_marks[regexp_nth_match(2)] = create_user_mark();
     }

   
   bob();
   while(re_fsearch("<[^>]*>"))
     ()=replace_match("", 0);
   
   bob();
   while(re_fsearch("&\([a-z]+\);"R))
     {
	if (assoc_key_exists(entities, regexp_nth_match(1)))
	  ()=replace_match(char(entities[regexp_nth_match(1)]), 0);
	else
	  ()=replace_match("?", 0);
     }
   bob();
   while(re_fsearch("&#\([0-9]+\);"R))
     ()=replace_match(char(atoi(regexp_nth_match(1))), 0);

   clear_message();
}

%}}}

%}}}

%{{{ browsing

private define goto_anchor(anchor)
{
   if (assoc_key_exists(anchor_marks, anchor))
     {
	goto_user_mark(anchor_marks[anchor]);
	recenter(3);
     }
}

private define write_callback (v, data)
{
   insert(data);
   return 0;
}

% flag to signal that the history should not be pushed
private variable page_is_download=0;
private variable se_re = pcre_compile("([^ ]+?) (.*)");

define find_page(url)
{
   variable file, anchor, v="";
   file=extract_element  (url, 0, '#');
   anchor=extract_element  (url, 1, '#');
   page_is_download=0;
   USER_BLOCK0
     {
	if (anchor != NULL)
	  goto_anchor(anchor);
     }

   % texi2html generated pages superfluously add the filename to #links
   if (file == url_file && bufferp("*jedscape*"))
     return sw2buf("*jedscape*"), X_USER_BLOCK0;
   
   setbuf(" jedscape_buffer");
   erase_buffer();
   if (pcre_exec(se_re, file))
     {
	variable se, term;
	(se, term) = pcre_nth_substr(se_re, file, 1), pcre_nth_substr(se_re, file, 2);
	se = sqlite_get_array(db, String_Type, "select url from searchengines where name = ?", se);
	if (length(se))
	  file = sprintf(se[0,0], curl_easy_escape(curl_new(""), term));
     }

   ifnot (strncmp(file, "http://", 7))
     {
	variable c = curl_new (file);
	curl_setopt(c, CURLOPT_FOLLOWLOCATION, 1);
	curl_setopt(c, CURLOPT_WRITEFUNCTION, &write_callback, &v);
	% You can use this hook to set a proxy server, e.g:
	% if (strncmp(curl_get_url(c), "http://localhost", 16))
	%  {
	%     curl_setopt(c, CURLOPT_PROXY, "localhost:8080");
	%     curl_setopt(c, CURLOPT_HTTPHEADER, "Pragma:");
	%  }
	runhooks("jedscape_curlopt_hook", c);
	flush(sprintf(_("Getting %s"), file));
	curl_perform (c);
	variable content_type=curl_get_info(c, CURLINFO_CONTENT_TYPE);
	file=curl_get_info(c, CURLINFO_EFFECTIVE_URL);
	ifnot (strncmp(content_type, "text/xml", 8)
	       && strncmp(content_type, "application/atom", 16))
	  {
	     if (get_y_or_n(sprintf("Content type=%s. View in newsflash", content_type, url)))
	       {
		  mark_buffer();
		  variable contents = bufsubstr();
		  read_rss_data(url, contents);
		  return;
	       }
	  }
	if(strncmp(content_type, "text/html", 9))
	  {
	     switch(get_mini_response(sprintf("Content type=%s. (D)isplay (S)ave (C)ancel", content_type)))
	       {case 's' or case 'S':
		  variable dest=read_with_completion(_("Enter name of file to create:"),
						     "", path_concat(getcwd(), path_basename(file)), 'f');
		  setbuf_info(getbuf_info() | 0x200);
		  variable state;
		  auto_compression_mode(0, &state);
		  try
		    {
		       ()=write_buffer(dest);
		       delbuf(whatbuf());
		    }
		  finally
		    {
		       auto_compression_mode(state);
		    }
	       }
	       {case 'd' or case 'D':
		  pop2buf(file);
		  erase_buffer();
		  insbuf(" jedscape_buffer");
	       }
	     page_is_download=1;
	     return;
	  }
	variable separator = is_substr(file[[7:]], "/");
	if (separator)
	  {
	     (url_host, url_file) = str_split(file, 7 + separator);
	  }
	else  % http://localhost
	  {
	     url_host=file;
	     url_file="/";
	  }
     }
   else
     {
	url_host="";
	url_file=file;
	switch(file_status(url_file))
	  { case 1: ()=insert_file(url_file);}
	  { case 2: return dired_read_dir(url_file); }
	  { throw OpenError, _("File does not exist.");}
     }
   url_root=path_dirname(url_file);
   filter_html();
   sw2buf("*jedscape*");
   setbuf_info(getbuf_info(), _stk_roll(-3), pop, path_dirname(url_file), _stk_roll(3));
   set_buffer_modified_flag(0);
   set_readonly(1);
   jedscape_mode();
   bob();
   set_status_line(sprintf ("Jedscape: %s %%p", title), 0);
   X_USER_BLOCK0;
}

%{{{ file download

private define download_callback (fp, str)
{
   return fputs (str, fp);
}

private define progress_callback (fp, dltotal, dlnow, ultotal, ulnow)
{
   if (dltotal > 0.0)
     flush(sprintf("Downloading... %d bytes of %d bytes received", int(dlnow), int(dltotal)));
   else
     flush(sprintf("Downloading... %d bytes received", int(dlnow)));
   return 0;
}

private define download(url)
{
   variable c = curl_new (url);
   variable dest=read_file_from_mini(_("Enter name of file to create:"));
   variable fp=fopen(dest, "w");
   if (fp == NULL)
     throw OpenError;
   curl_setopt(c, CURLOPT_FOLLOWLOCATION, 1);
   curl_setopt (c, CURLOPT_WRITEFUNCTION, &download_callback, fp);
   curl_setopt (c, CURLOPT_PROGRESSFUNCTION, &progress_callback, stdout);
   runhooks("jedscape_curlopt_hook", c);
   curl_perform (c);
}

%}}}

%{{{ history stack

ifnot (is_defined ("jedscape_position_type"))
{
   typedef struct
     {
	hostname,
	filename,
	line_number,
	column
     }
   jedscape_position_type;
}

variable jedscape_history = jedscape_position_type[16],
  jedscape_history_rotator = [[1:15],0],
  jedscape_stack_depth = -1,
  forward_stack_depth = 0;

define push_position(host, file, line, column)
{
   if (page_is_download) return;
   if (jedscape_stack_depth == 16)
     {
        --jedscape_stack_depth;
	jedscape_history  = jedscape_history [jedscape_history_rotator];
     }

   set_struct_fields (jedscape_history [jedscape_stack_depth], host, file, line, column);

   ++jedscape_stack_depth;
   forward_stack_depth = 0;
}

define goto_stack_position()
{
   variable pos, file, n;
   pos = jedscape_history [jedscape_stack_depth];
   file = strcat(pos.hostname, pos.filename);
   n = pos.line_number;
   if (file != strcat(url_host, url_file))
     find_page(file);
   goto_line(n);
   goto_column(pos.column);
}

define goto_last_position ()
{
   if (jedscape_stack_depth < 0) return message(_("You are already at the first document"));
   ifnot (forward_stack_depth)
     {
	push_position(url_host, url_file, what_line, what_column());
	--jedscape_stack_depth;
     }

   --jedscape_stack_depth;
   ++forward_stack_depth;
   goto_stack_position;
}

define goto_next_position()
{
   ifnot (forward_stack_depth) return message("Can't go forward");
   ++jedscape_stack_depth;
   --forward_stack_depth;
   goto_stack_position;
}

%}}}

%!%+
%\function{jedscape_get_url}
%\synopsis{Open a file or url in jedscape}
%\usage{ jedscape_get_url() [url]}
%\description
%   Opens the file or url argument in \var{jedscape}. Without argument it prompts
%   for a file or url.
%\seealso{jedscape}
%!%-
public define jedscape_get_url() % url
{
   variable url;
   if (_NARGS) url = ();
   else url = read_mini("open", "", "");
   variable last_host, last_file, last_line, last_column;
   (last_host, last_file, last_line, last_column) = (url_host, url_file, what_line, what_column());
   find_page(url);
   push_position(last_host, last_file, last_line, last_column);
}

define open_local()
{
   variable file=read_file_from_mini ("open local");
   variable last_host, last_file, last_line, last_column;
   (last_host, last_file, last_line, last_column) = (url_host, url_file, what_line, what_column());
   find_page(file);
   push_position(last_host, last_file, last_line, last_column);
}
   
%{{{ view history

private define get_url_this_line()
{
   variable url = line_as_string();
   close_buffer();
   jedscape_get_url(url);
}

define view_history()
{
   popup_buffer("*jedscape history*");
   set_readonly(0);
   erase_buffer();
   variable i = 0, file = "";
   loop(jedscape_stack_depth + forward_stack_depth)
     {
	file;
	file = strcat(jedscape_history[i].hostname, jedscape_history[i].filename);
	i++;
	if (file == ()) continue;
	insert (file + "\n");
     }
   fit_window();
   view_mode();
   set_buffer_hook("newline_indent_hook", &get_url_this_line);
}

define quit()
{
   push_position(url_host, url_file, what_line, what_column());
   url_file="";
   delbuf("*jedscape*");
}

%}}}

%{{{ follow hyperlink

define get_href()
{
   variable place, href;
   place =  create_user_mark();
   href = wherefirst(href_end_marks >= place);
   if (href != NULL && href_begin_marks[href] <= place)
     return href_list[href];
   else
     return "";
}

define follow_href() % href
{
   ifnot (_NARGS) get_href();
   variable href = ();
   ifnot (strlen(href)) return;
   if (url_host !="" && not strncmp(href, "//", 2))
     href = "http:" + href;
   if (is_substr(href, ":"))
     {
	variable url_type = extract_element(href, 0, ':');
	switch (url_type)
	  { case "mailto":
	     mail();
	     eol();
	     insert(extract_element(href, 1, ':'));
	  }
	  { case "http":
	     jedscape_get_url(href);
	  }
	  { case "file":
	     href = extract_element(href, 1, ':');
	     ifnot (strncmp (href, "//localhost", 11))
	       href = href[[11:]];
	     jedscape_get_url(href);
	  }
	  { message (strcat(_("Unsupported URL scheme!"), url_type)); }
	return;
     }
   if (href[0] == '#')
     {
	push_position(url_host, url_file, what_line, what_column());
	goto_anchor(href[[1:]]);
     }
   else
     {
	jedscape_get_url(url_host + expand_filename(path_concat(url_root,href)));
     }
   
}

define download_href()
{
   ifnot (_NARGS) get_href();
   variable href = ();
   ifnot (strlen(href)) return;
   if (url_host !="" && not strncmp(href, "//", 2))
     href = "http:" + href;
   if (is_substr(href, ":"))
     {
	download(href);
     }
   else
     {
	download(url_host + expand_filename(path_concat(url_root,href)));
     }
}

%}}}

%!%+
%\function{jedscape}
%\synopsis{start jedscape}
%\usage{ jedscape()}
%\description
%   opens the \var{Jedscape_Home} page
%\seealso{jedscape_get_url, jedscape_mode}
%!%-
public define jedscape()
{
   find_page(Jedscape_Home);
}

%{{{ info-like navigation

% next, previous, up, top = "contents"
define follow_link(link)
{
   variable url = get_struct_field(links, link);
   if (url == NULL)
     {
	% Many docs have no links, but ordinary hrefs called "next"
	if (assoc_key_exists(href_anchor_list, link))
	  url = href_anchor_list[link];
	else
	  throw RunTimeError, sprintf("page has no %s", link);
     }
   if (strncmp(url, "http://", 7))
     jedscape_get_url(url_host + path_concat(url_root,url));
   else
     jedscape_get_url(path_concat(url_root,url));
}

% menu
define complete_link()
{
   variable url =
     read_string_with_completion("Link", "", strjoin(assoc_get_keys(href_anchor_list),  ","));
   if (assoc_key_exists(href_anchor_list, url))
   {
      follow_href(href_anchor_list[url]);
   }
}

%}}}

%}}}

%{{{ other interactive functions

private define reread()
{
   variable line=what_line(), host=url_host, file=url_file;
   (url_host, url_file)="", "";
   find_page(strcat(host, file));
   goto_line(line);
}

define view_source()
{
   if (strlen(url_host)) return message ("viewing a remote file is not supported yet");
   ()=find_file(url_file);
}

define next_reference()
{
   go_right (fsearch("\e[29m"));
}

define previous_reference()
{
   if (bsearch("\e[0]"))
     {
	go_right(bsearch("\e[29m"));
     }
}

private define view_url()
{
   message(strcat(url_host, url_file));
}


%}}}

%{{{ mode stuff

%{{{ mouse

private variable mouse_href=-1;
private define mouse_hook(line, col, button, shift)
{
   switch(button)
     { case 1:  
	variable place, this_href;
	place = create_user_mark();
	this_href = wherefirst(href_begin_marks <= place and href_end_marks >= place);
	if (NULL != this_href) 
	  {
	     if (mouse_href == this_href)
	       follow_href(href_list[this_href]);
	     else
	       {
		  message(href_list[this_href]);
		  mouse_href=this_href;
	       }
	  }
	else mouse_href=-1;
     }
     { case 2: follow_href;}
     { goto_last_position;}
   -1;
}

private define mouse_2click_hook(line, col, button, shift)
{
   follow_href();
   1;
}

%}}}

%{{{ keymap

define add_bookmark();

ifnot (keymap_p(mode))
  copy_keymap(mode, "view");
$1 = _stkdepth;
switch (Jedscape_Emulation)
{ case "lynx":
   &next_reference,	Key_Down;
   &previous_reference,	Key_Up;
   &follow_href,	Key_Right;
   &goto_last_position,	Key_Left;
   "page_up",           "b";
   &view_source,	"\\";
   &view_history,	Key_BS;
   "write_buffer",	"p";
   &view_history,	"V";
}
{ case "netscape":
   "scroll_down_in_place",	Key_Up;
   "scroll_up_in_place",	Key_Down;
   &view_source,		"\eu";
   &goto_last_position,		Key_Alt_Left;
   &goto_next_position,		Key_Alt_Right;
}
{ case "w3":
   &goto_last_position,	"B";
   &goto_next_position,	"F";
   &previous_reference,	"b";
   &next_reference,	"f";
   &jedscape_get_url,	"^o";
   &open_local,		"o";
   &view_source,	"s";
   &view_url,		"v";
   "message(jedscape->get_href())",	"V";
   &view_history,		"^c^b";
}
&add_bookmark,		"a";
&jedscape_get_url,	"g";
&follow_href,		"^M";
&download_href,		"d";
&goto_last_position,	"l";
&goto_next_position,	";";
&goto_last_position,	",";
&goto_next_position,	".";
&next_reference,	"\t";
". 5 set_prefix_argument \"scroll_right\" call",         "}";
". 5 set_prefix_argument \"scroll_left\" call",          "{";
". 5 set_prefix_argument \"scroll_right\" call",         "[";
". 5 set_prefix_argument \"scroll_left\" call",          "]";
"jedscape->follow_link(\"previous\")",	"p";
"jedscape->follow_link(\"next\")",	"n";
"jedscape->follow_link(\"up\")",	"u";
"jedscape->follow_link(\"contents\")",	"t";
&complete_link,		"m";
&view_history,		"\eh";
&reread,		"^r";
&quit,			"q";
loop ((_stkdepth - $1)/2)
  definekey(mode);

%}}}

private define links_popup(menu)
{
   variable name, value;
   foreach name (get_struct_field_names(links))
     {
	value = get_struct_field(links, name);
	if (value != NULL)
	  menu_append_item(menu, sprintf("%s: %s", name, value), &follow_link, name);
     }
}

%{{{ bookmarks

private define bookmark_callback(bm)
{
   if (is_substr(bm, "%s"))
     {
	variable parameter = read_mini("bookmark parameter", "", "");
	bm = sprintf(bm, parameter);
     }
   jedscape_get_url(bm);
}

private define jedscape_bookmark_popup(menu)
{
   variable name, url;
   foreach name, url (db) using ("select name, url from bookmarks order by name")
     {
	menu_append_item(menu, name, &bookmark_callback, url);
     }
}

define add_bookmark()
{
   variable name = read_mini(_("name:"), title, "");
   
   sqlite_exec(db, "insert into bookmarks (name, url) values (?, ?)",
	       name, strcat(url_host, url_file));
   message ("bookmark added");
}

define edit_bookmarks()
{
   sqlited_table(db, Jedscape_DB, "bookmarks");
}

%}}}

%{{{ search engines

define add_searchengine()
{
   variable name = read_mini(_("name:"), title, "");
   variable url = read_mini("url:", "", "");
   
   sqlite_exec(db, "insert into searchengines (name, url) values (?, ?)",
	       name, url);
   message ("search engine added");
}

define edit_searchengines()
{
   sqlited_table(db, Jedscape_DB, "searchengines");
}

%}}}

define jedscape_menu(menu)
{
   variable item;
   foreach item ({
      ["&Dir", "jedscape"],
      ["&Open local page", "jedscape->open_local"],
      ["&Go to URL", "jedscape_get_url"],
      [_("History Page"), "jedscape->view_history"],
      ["&Source", "jedscape->view_source"],
      ["&Add Bookmark",	"jedscape->add_bookmark"],
      ["Edit bookmarks", "jedscape->edit_bookmarks"],
      ["Add search engine", "jedscape->add_searchengine"],
      ["Edit search engines", "jedscape->edit_searchengines"]})
     menu_append_item(menu, item[0], item[1]);
   menu_append_popup(menu, "&Links");
   menu_set_select_popup_callback(menu+".&Links", &links_popup);
   menu_append_popup(menu, "&Bookmarks");
   menu_set_select_popup_callback(menu+".&Bookmarks", &jedscape_bookmark_popup);
}

%!%+
%\function{jedscape_mode}
%\synopsis{web browser}
%\usage{ jedscape_mode()}
%\description
%  Jedscape is a simple web browser in JED.  It requires the curl module
%  to fetch documents from the web and w3m to render html markup.  You
%  can open a document in \var{jedscape_mode} with \var{jedscape} or
%  \var{jedscape_get_url}. You can customize \var{jedscape mode} in a
%  jedscape_hook.sl file.
%\seealso{Jedscape_Home, Jedscape_DB, Jedscape_Html_Filter, Jedscape_Emulation}
%!%-
define jedscape_mode()
{
   use_keymap(mode);
   _set_buffer_flag(0x1000);
   set_mode(mode, 0);
   set_buffer_hook("mouse_up", &mouse_hook);
   set_buffer_hook("mouse_2click", &mouse_2click_hook);
   mode_set_mode_info(mode, "init_mode_menu", &jedscape_menu);
   run_mode_hooks("jedscape_mode_hook");
}

$1 = expand_jedlib_file("jedscape_hook.sl");
if ($1 != "")
  () = evalfile ($1);

%}}}


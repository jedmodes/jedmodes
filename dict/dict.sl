% dict.sl
% A dict client.
%
% $Id: dict.sl,v 1.7 2007/10/04 16:19:49 paul Exp paul $
%
% Copyright (c) 2005-2007 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).

require("socket");
require("select");
require("pcre");
provide("dict");
require("bufutils");
require("view");
implements("dict");

custom_variable("Dict_Server", "localhost");
custom_variable("Dict_DB", "*");
custom_variable("Dict_Strat", ".");

!if (keymap_p("dict"))
  copy_keymap("dict", "view");

$0 =_stkdepth;
"dict->follow_link", "\r";
"dict->next", "\t";
"dict->previous", Key_Shift_Tab;
"dict->next", "n";
"dict->previous", "p";
"dict->next", "f";
"dict->previous", "b";
"dict", "s";
"dict_lookup", "d";
"dict->back", "l";
"dict_match", "m";
loop((_stkdepth() - $0)/2)
  definekey("dict");

variable s, connected=0, status, line="", buf="";
variable history = NULL;
%{{{ socket

define dict_close();
define dict_connect();
% This appends some data from the socket to buf, and reads one line from that
% into line.
define get_line()
{  
   !if (connected) throw RunTimeError, "I'm not connected to a dict server";
   variable more, nl = is_substr(buf, "\n"), buf2;
     while  (not nl)
       {
	  more = select([s], NULL, NULL, 1);
	  !if (more.nready) 
	    {
	       dict_close();
	       throw RunTimeError, "Dict server is not talking.";
	    }
	  % Dictd will hang up after 10 minutes of inactivity.  How do I check
	  % if a connection is still open?
	  !if(read(s, &buf2, 8192))
	    {
	       dict_close();
	       throw RunTimeError, "Dict server hung up. Try again";
	    }
	  buf += buf2;
	  nl = is_substr(buf, "\n");
       }
   line = strtrim_end(substr(buf, 1, nl)); % get rid of \r as well
   buf = substr(buf, nl + 1 , -1);
}

define dict_write(str)
{
   % Check if the connection is still open.
   variable buf2, more = select([s], NULL, NULL, 0.1);
   if (more.nready)
     {
	!if(read(s, &buf2, 8192))
	  {
	     dict_close();
	     dict_connect();
	  }
	buf += buf2;
     }
   if (-1 == write(s, str))
     throw RunTimeError, "error writing to socket";
}

%}}}

%{{{ server interaction

define get_status()
{
   variable p = pcre_compile("^[0-9]+");
   status = "";
   get_line();
   if (pcre_exec(p, line))
     status = pcre_nth_substr(p, line,  0);
}

define dict_close()
{
   ()=close(s);
   line="";
   buf="";
   connected=0;
}

define dict_error()
{
   variable msg = line;
   dict_close();
   throw RunTimeError, msg;
}

define dict_connect()
{
   if (connected) return;
   variable server, port, colon = is_substr(Dict_Server, ":");
   if (colon)
     (server, port) = substr(Dict_Server, 1, colon - 1), atoi(substr(Dict_Server, colon + 1, -1));
   else
     (server, port) = Dict_Server, 2628;
   s = socket (PF_INET, SOCK_STREAM, 0);
   connect(s, server, port);
   connected=1;
   get_status();
   if(status != "220") 
     return dict_error();
}

% read and insert an answer delimited by a . on a single line
define read_answer()
{
   forever
     {
	get_line();
	!if (strncmp(line, ".", 1))
	  {
	     if (strncmp(line, "..", 2))
	       return;
	     else
	       line = substr(line, 2, -1);
	  }
	insert(line);
	newline();
     }
}

%}}}

%{{{ history

variable Def_Type= struct
{
   prev,
     def,
     line,
     column,
     type % 0: search  1: match
};

define back()
{
   if (orelse {history == NULL}{history.prev == NULL})
     throw RunTimeError, "can't go back";
   history = history.prev;
   set_readonly(0);
   erase_buffer(); 
   insert(history.def);
   fit_window();
   goto_line(history.line);
   goto_column(history.column);
   set_readonly(1);
   set_buffer_modified_flag(0);
}

define history_add(t)
{
   mark_buffer();
   history;
   history = @Def_Type;
   history.prev = ();
   history.def = bufsubstr();
   history.type = t;
   history.line = 1;
   history.column = 1;
}

define store_position()
{
   if ("*dict*" != whatbuf() or history == NULL) return;
   history.line = what_line();
   history.column = what_column();
}

%}}}

%{{{ accented keys

% According to RFC 2229 the dict output is in UTF-8, but, at least in gcide,
% words with accented characters look like Zo["o]logy.
define dict_insert_accent (ch, ok_chars, maps_to)
{
   variable pos = is_substr (ok_chars, char (ch));
   if (pos)
     pos--;
   char (maps_to[pos]);
}


define mute_keymap_39 () % ' map
{
   "'AEIOUYaeiouy?!/1Cc";
   "'\d193\d201\d205\d211\d218\d221\d225\d233\d237\d243\d250\d253\d191\d161\d191\d161\d199\d231";
}

define mute_keymap_94 () % ^ map
{
   "^aeiou";
   "^\d226\d234\d238\d244\d251";
}

define mute_keymap_96 () % ` map
{
   "`AEIOUaeiou";   
   "`\d192\d200\d204\d210\d217\d224\d232\d236\d242\d249";
}

define mute_keymap_126 ()  % ~ map
{
   "~NnAOao";
   "~\d209\d241\d195\d213\d227\d245";
}

define mute_keymap_34 () % \" map
{
   "\"AEIOUaeiouys";   
   "\"\d196\d203\d207\d214\d220\d228\d235\d239\d246\d252\d255\d223";
}

define replace_accents()
{
   variable accent, letter;
   bob;
   while(re_fsearch("\\[\\([\"\'^`~\d168\d180]\\)\\([a-zA-Z]\\)\\]"))
     {
	accent = regexp_nth_match(1);
	letter = int(regexp_nth_match(2));
	switch (int(accent))
	  { case '"': mute_keymap_34(letter); }
	  { case '\'': mute_keymap_39(letter); }
	  { case '^': mute_keymap_94(letter); }
	  { case '`': mute_keymap_96(letter); }
	  { case '~': mute_keymap_126(letter); }
	  { continue; }
	()=replace_match(dict_insert_accent(), 0);
     }
}

%}}}

%{{{ menu

define set_db_callback(db)
{
   Dict_DB = db;
}

define database_popup(menu)
{
   dict_connect();
   dict_write("show db\r\n");
   get_status();
   if(strncmp(line, "110", 3))
     throw RunTimeError, sprintf("dict error: %s", line);
   variable item;
   foreach(["*   All dictionaries", "!   First matching dictionary\n"])
     {
	item = ();
	menu_append_item(menu, item, &set_db_callback, strtok(item)[0]);
     }

   forever
     {
	get_line();
	!if (strncmp(line, ".", 1))
	  {
	     if (strncmp(line, "..", 2))
	       break;
	     else
	       line = line[[1:]];
	  }
	menu_append_item(menu, line, &set_db_callback, strtok(line)[0]);
     }
   get_status();
   if(status != "250") dict_error();
}

define set_strategy_callback(strategy)
{
   Dict_Strat = strategy;
}

define strategy_popup(menu)
{
   dict_connect();
   dict_write("show strat\r\n");
   get_status();
   if(strncmp(line, "111", 3))
     throw RunTimeError, sprintf("dict error: %s", line);
   menu_append_item(menu, ".  Server default", &set_strategy_callback, ".");
   
   forever
     {
	get_line();
	!if (strncmp(line, ".", 1))
	  {
	     if (strncmp(line, "..", 2))
	       break;
	     else
	       line = line[[1:]];
	  }
	menu_append_item(menu, line, &set_strategy_callback, strtok(line)[0]);
     }
   get_status();
   if(status != "250") dict_error();
}

define dict_menu(menu)
{
   menu_append_item(menu, "search", "dict");
   menu_append_item(menu, "match", "dict_match");
   menu_append_popup(menu, "&database");
   menu_set_select_popup_callback(menu + ".&database", &database_popup);
   menu_append_popup(menu, "&strategy");
   menu_set_select_popup_callback(menu + ".&strategy", &strategy_popup);
   menu_append_item(menu, "&Quit", "close_buffer");
}

%}}}

%{{{ dict mode
variable begin_marker = sprintf("\e[%d]", color_number("keyword")),
end_marker = "\e[0]";

define next()
{
   go_right(fsearch(begin_marker));
}

define previous()
{
   if(bsearch(end_marker))
     go_right(bsearch(begin_marker));
}

define select_database()
{
   bol();
   push_mark;
   skip_chars("^ ");
   variable database = bufsubstr();
   !if (strlen(database)) return;
   Dict_DB = database;
   if (history != NULL)
     if (history.prev != NULL)
     back();
}


define query();
define search();

define follow_link()
{
   if (history.type) return query(sprintf("DEFINE %s\r\n", line_as_string()));
   push_spot;
   variable db = Dict_DB;
   if (re_bsearch("^From .* \\[\\([a-zA-Z]+\\)\\]$"))
     db = regexp_nth_match(1);
   goto_spot();
   !if (bsearch(begin_marker)) return;
   push_mark;
   while(re_bsearch("\e\\[[0-9]+\\]"))
     {
	if (regexp_nth_match(0) == end_marker) 
	  {
	     pop_mark_1();
	     break;
	  }
	else
	  {
	     pop_mark_0();
	     push_mark();
	  }
     }
   go_right(5);
   push_mark();
   pop_spot();
   !if (fsearch(end_marker)) return pop_mark_0();
   variable word = bufsubstr();
   variable pos, re=pcre_compile("\e\\[[0-9]+\\]");
   while (pcre_exec(re, word))
     {
	pos = pcre_nth_match(re, 0);
	word = substr(word, 1, pos[0]) + substr(word, pos[1] + 1, -1);
     }
   search(db, strcompress(word, " \r\n"));
}

% When closing the *dict* buffer, also close the connection.
define dict_close_buffer(buf)
{
   popup_close_buffer_hook(buf);
   history = NULL;
   dict_close();
}

%!%+
%\function{dict_mode}
%\synopsis{Mode of the *dict* buffer}
%\usage{Void dict_mode ();}
%\description
% This is a mode for searching a dictionary server implementing
% the protocol defined in RFC 2229.
%  \var{q} close the dictionary buffer
%  \var{h} display this help information
%  \var{s} ask for a new word to search
%  \var{d} search the word at point
%  \var{n}, \var{f}, \var{Tab} place point to the next link
%  \var{p}, \var{b}, \var{S-Tab} place point to the prev link
%  \var{Return} follow link
%  \var{l} go back
%  \var{m} ask for a pattern and list all matching words.
%!%-
define dict_mode()
{
   view_mode();
   use_keymap("dict");
   _set_buffer_flag(0x1000);
   define_blocal_var("close_buffer_hook", &dict_close_buffer);
   mode_set_mode_info ("dict", "init_mode_menu", &dict_menu);
   run_mode_hooks("dict_mode_hook");
   set_mode("dict", 0);
}

define dict_buffer()
{
   dict_connect();
   popup_buffer("*dict*");
   dict_mode();
}
variable re_152 = pcre_compile("^152 (\\d+)");

define match(word)
{
   dict_connect();
   store_position();
   dict_write(sprintf("MATCH %s %s \"%s\"\r\n", Dict_DB, Dict_Strat, word));
   get_status();
   set_readonly(0);
   erase_buffer();
   set_line_color(0);
   if(pcre_exec(re_152, line))
     {
	vinsert("%s matches for %s\n", pcre_nth_substr(re_152, line, 1), word);
	read_answer();
	get_status();
	if(status != "250") dict_error();
     }
   else insert(line);
   fit_window();
   history_add(1);
   bob();
   set_readonly(1);
   set_buffer_modified_flag(0);
}

variable re_150 = pcre_compile("^150 (\\d+)"),
  re_151 = pcre_compile("151 \".*\" (.*) \"(.*)\"$");

define query(q)
{
   dict_connect();
   store_position();
   dict_write(q);
   get_status();
   if(status=="552") return message ("no match");
   set_readonly(0);
   erase_buffer();
   set_line_color(0);
   if(pcre_exec(re_150, line))
     {
	loop(atoi(pcre_nth_substr(re_150, line, 1)))
	  {
	     get_status();
	     if (pcre_exec(re_151, line))
	       {
		  set_line_color(color_number("keyword1"));
		  vinsert("From %s [%s]", pcre_nth_substr(re_151, line, 2), 
			  pcre_nth_substr(re_151, line, 1));
		  newline();
		  set_line_color(0);
	       }
	     else
	       insert(line);
	     read_answer();
	  }
	
	get_status();
	if(status != "250") dict_error();
     }
   else 
     insert(line);
   replace_accents();
   bob();
   while(re_fsearch("^[^{]+}")) % escape-sequence coloring does not span lines
     {
	insert(begin_marker);
	!if(down_1) break;
     }
   bob();
   replace("{", begin_marker);
   replace("}", end_marker);
   fit_window();
   history_add(0);
   bob();
   set_readonly(1);
   set_buffer_modified_flag(0);
}

define search(word) % [db]
{
   if (_NARGS < 2) Dict_DB;
   variable db = ();
   query(sprintf("DEFINE %s \"%s\"\r\n", db, word));
}

%}}}

public define dict_lookup()
{
   !if (_NARGS)
     get_word();
   dict_buffer();
   search();
}

public define dict()
{
   read_mini("word", get_word(), ""); 
   dict_buffer();
   search();
}

public define dict_match()
{
   read_mini("word", get_word(), ""); 
   dict_buffer();
   match();
}


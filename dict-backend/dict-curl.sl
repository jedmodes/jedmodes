% dict-curl.sl: a backend to dict mode using the curl module
% 
% Copyright (c) 2006 Paul Boekholt
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Usage
% -----
% 
% Place in the jed library path. If dict-cli.sl is in the path as
% well but you prefer the curl interface, set the custom variable
% Dict_Backends, e.g. in jed.rc
% 
%   variable Dict_Backends = "dict-curl.sl";
% 
% Versions:
% ---------
% 
% 0.1 2006-03-03 First public version
% 0.2 2006-09-27 dollar strings caused segfaults with slang 2.0.6
%                fized lookup of multi word keywords
% _debug_info = 1;

require("curl");
provide("dict-backend");
provide("dict-curl");

private define write_callback (v, data)
{
   insert(data);
   return 0;
}

private define do_curl()
{
   variable args=__pop_args(_NARGS);
   variable v;
   variable c = curl_new (sprintf(__push_args(args)));
   curl_setopt (c, CURLOPT_WRITEFUNCTION, &write_callback, &v);
   curl_perform (c);
}

define dict_define(word, database, host)
{
   variable db, line;
   foreach db (strtok(database, ","))
     do_curl("dict://%s/d:\"%s\":%s", host, word, db);
   bob();
   replace("\r", "");
   push_mark();
   forever
     {
	!if (bol_fsearch("151 "))
	  {
	     eob();
	     del_region();
	     bob();
	     return;
	  }
	% convert
	%  151 "mode" jargon "Jargon File (4.4.4, 14 Aug 2003)"
	% to 
	%  From "Jargon File (4.4.4, 14 Aug 2003)" [jargon]:
	push_mark_eol();
	line = strtok(bufsubstr_delete(), " ");
	db = line[2];
	line = strjoin(line[[3:]], " ");
	go_down_1();
	del_region();
	vinsert("From %s [%s]:\n", line, db);
	while (bol_fsearch("."))
	  {
	     if (looking_at(".."))
	       {
		  del();
		  eol();
	       }
	     else
	       {
		  push_mark();
		  break;
	       }
	  }
     }
}

define dict_match(word, strategy, database, host)
{
   variable db;
   foreach db (strtok(database, ","))
     do_curl("dict://%s/m:%s:%s:%s", host, word, db, strategy);
   bob();
   replace("\r", "");
   push_mark();
   forever
     {
	!if (bol_fsearch("152 "))
	  {
	     eob();
	     del_region();
	     bob();
	     return;
	  }
	go_down_1();
	del_region();
	push_spot();
	while (bol_fsearch("."))
	  {
	     if (looking_at(".."))
	       {
		  del();
		  eol();
	       }
	     else
	       {
		  push_mark();
		  break;
	       }
	  }
     }
}

  
define dict_show(what, host)
{
   do_curl("dict://%s/show:%s", host, what);
   bob();
   replace("\r", "");
   bob();
   if(bol_fsearch("110")) delete_line();
   bob();
   while(bol_fsearch(".")) del();
   bob();
   while(bol_fsearch("2")) delete_line();
}

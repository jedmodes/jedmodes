% pcre.sl
% Perl-compatible searching functions
% 
% $Id: pcre.sl,v 1.1 2004/06/16 04:42:24 paul Exp paul $
% Keywords: matching
%
% Copyright (c) 2004 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This requires JED B0.99-17 and the pcre module.

import("pcre");
require("srchmisc");
!if (is_defined("occur_goto_line"))
  ()=evalfile("occur");

if (_featurep("pcre"))
  use_namespace("pcre");
else
  implements("pcre");
provide("pcre");

% _debug_info=1;
%{{{ search

public define pcre_fsearch(pat)
{
   variable re = pcre_compile(pat);
   push_spot;
   push_mark_eob;
   variable str = bufsubstr;
   pop_spot;
   variable match_pos;
   if (pcre_exec(re, str))
     {
	match_pos = pcre_nth_match(re, 0);
	go_right(match_pos[0]);
	return 1;
     }
   return 0;
}

variable last_pcre_search = "";

public define pcre_search_forward()
{
   variable pat;
   if (_NARGS) pat = ();
   else pat = read_mini ("Search for:", last_pcre_search, "");

   variable re = pcre_compile(pat);
   push_spot;
   push_mark_eob;
   variable str = bufsubstr;
   pop_spot;
   variable match_pos, pos = 0, ch;
   while (pcre_exec(re, str, pos))
     {
	match_pos = pcre_nth_match(re, 0);
	!if (pos) pos = 1;
	go_right(match_pos[0] - pos + 1);
	message ("Press RET to continue searching.");
	mark_next_nchars(match_pos[1] - match_pos[0], -1);
	pos = match_pos[0] + 1;
	ch = getkey ();
	if (ch != '\r')
	  {
	     ungetkey (ch);
	     return;
	  }
     }
   return message ("not found");
}

%}}}
%{{{ replace
   
public define pcre_query_replace()
{  
   variable pat, pat_len, rep, rep_len, re, str, pos = 0,
     query = 1, match_len, prompt;
   pat = read_mini ("Search for:", last_pcre_search, "");
   rep = read_mini ("replace with:", "", "");
   rep_len = strlen(rep);
   re = pcre_compile(pat);
   push_spot;
   push_mark_eob;
   str = bufsubstr;
   pos = 0;
   pop_spot;
   variable match_pos, ch;
   while (pcre_exec(re, str, pos))
     {
	match_pos = pcre_nth_match(re, 0);
	pat_len = match_pos[1] - match_pos[0];
	go_right(match_pos[0] - pos);
	prompt =  sprintf ("Replace '%s' with '%s'? (y/n/!/q)",
			   pcre_nth_substr(re, str, 0), rep);

	USER_BLOCK0
	  {
	     deln(pat_len);
	     insert(rep);
	     pos = match_pos[1];
	  }
	
	!if (query)
	  {
	     X_USER_BLOCK0;
	     continue;
	  }
	
	forever
	  {
	     message(prompt);
	     mark_next_nchars (pat_len, -1);

	     ch = getkey ();
	     if (ch == 'r')
	       {
		  recenter (window_info('r') / 2);
	       }
	     switch(ch)
	       { case 'y' :
		  X_USER_BLOCK0;
		  break;
	       }
	       { case 'n' :
		  go_right_1 ();
		  pos = match_pos[0] + 1;
		  break;
	       }
	       { case '!' :
		  query = 0;
		  X_USER_BLOCK0;
		  break;
	       }
	       { case 'q' : return; }
	  }
     }
   message ("done");
}

%}}}
%{{{ occur

variable occur_re;
define pcre_match(str)
{
   pcre_exec(occur_re, str);
}

public define pcre_occur()
{
   variable pat, str, tmp, n;
   
   pat = read_mini("Find All (Regexp):", LAST_SEARCH, Null_String);
   occur_re = pcre_compile(pat);
   tmp = "*occur*";
   Occur_Buffer = whatbuf();
   push_spot_bob;
   push_mark_eob;
   str = strchop(bufsubstr, '\n', 0);
   pop_spot;
   variable index = where(array_map(Integer_Type, &pcre_match, str));
   pop2buf(tmp);
   erase_buffer();
   foreach (index)
     {
	n = ();
	vinsert ("%4d: %s\n", 1+n, str[n]);
     }
   bob(); set_buffer_modified_flag(0);

   use_keymap ("Occur");
   run_mode_hooks ("occur_mode_hook");
}


%}}}

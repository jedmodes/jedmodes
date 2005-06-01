% pcre.sl
% Perl-compatible searching functions
% 
% $Id: pcre.sl,v 1.2 2005/06/01 11:59:16 paul Exp paul $
% Keywords: matching
%
% Copyright (c) 2004, 2005 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This requires JED B0.99-17 and the pcre module.
% 
% This provides some functions for searching, replacing and occurring
% pcre-regexps.  The searching and replacing functions can find multi-line
% matches.

provide("pcre");
import("pcre");
require("srchmisc");
require("occur");  % this requires the occur from jedmodes.sf.net/mode/occur

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

private variable last_pcre_search = "";

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

private variable occur_re;
private define pcre_match(str)
{
   pcre_exec(occur_re, str);
}

public define pcre_occur()
{
   variable pat, str, tmp, n;
   if (_NARGS) pat = ();
   else
     pat = read_mini("Find All (Regexp):", LAST_SEARCH, Null_String);
   occur_re = pcre_compile(pat);
   tmp = "*occur*";
   occur->obuf = whatbuf();
   occur->nlines=0;
   occur->mbuffers=0;
   push_spot_bob;
   push_mark_eob;
   str = strchop(bufsubstr, '\n', 0);
   pop_spot;
   variable index = where(array_map(Integer_Type, &pcre_match, str));
   !if (length(index)) return message("no matches");
   pop2buf(tmp);
   erase_buffer();
   foreach (index)
     {
	n = ();
	vinsert ("%*d: %s\n", occur->line_number_width, 1+n, str[n]);
     }
   bob(); set_buffer_modified_flag(0);
   occur_mode();
}


%}}}

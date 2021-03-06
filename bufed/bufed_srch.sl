% bufed_srch.sl
% 
% $Id: bufed_srch.sl,v 1.4 2007/05/13 08:25:55 paul Exp paul $
% 
% (c) 2003-2007 Paul Boekholt
% Released under the terms of the GNU GPL (version 2 or later).
% 
% The search functions for bufed.sl, placed in a 
% separate file to make bufed load faster.

provide ("bufed_srch");

require ("search");
require ("srchmisc");
() = evalfile ("regexp");
use_namespace("bufed");

% this is now a private function in regexp.sl
private define research_search_function (pat)
{
   re_fsearch (pat) - 1;
}

variable last_search_replace_cmd = "", continued = 0;
%{{{ search through marked buffers

variable search_fun, pat;

% This function says that the line is ok, I also use it
% to pop to the buffer if the string is found
static define bufed_srch_ok_fun()
{
   pop2buf(whatbuf);
   return 1;
}

static define bufed_search_buffer(line)
{
   variable buf = extract_element (line, 1, '"');
   if (buf == NULL) return 0;
   !if (bufferp (buf)) return 2; % buffer doesn't exist -> kill line
   setbuf(buf);
   variable buf_mark = create_user_mark;
   !if (continued)
     bob();
   continued = 0;
   if (search_maybe_again (search_fun, pat, 1, &bufed_srch_ok_fun))
     {
	listing->Dont_Ask = -1;
	setbuf (Bufed_buf);
	throw UserBreakError, "Quit";
     }
   goto_user_mark(buf_mark);
   pop2buf (Bufed_buf);
   return 1; % untag line
}

% Search the tagged buffers.  With prefix, do a regexp search.
define search_tagged ()
{
   continued = 0;
   last_search_replace_cmd="search";
   if (-1 == prefix_argument (-1))
     search_fun = &search_across_lines;
   else
     search_fun = &re_search_dir;
   LAST_SEARCH = read_mini("Search", LAST_SEARCH, "");
   pat = LAST_SEARCH;
   try
     {
	listing_map(2, &bufed_search_buffer);
     }
   catch UserBreakError;
}

%}}}

%{{{ replacing through marked buffers

variable rep_fun, rep_pat, rep_rep;

% this is replace_with_query from srchmisc.sl, the main difference 
% being we need to raise an error on 'q'
% The undo function only works within a buffer.
static define bufed_replace_with_query (line)
{
   variable buf = extract_element (line, 1, '"');
   if (buf == NULL) return 0;
   !if (bufferp (buf)) return 2; % buffer doesn't exist -> kill line
   setbuf(buf);
   variable buf_mark = create_user_mark();
   !if (continued) 
     bob();
   continued = 0;
   variable n, prompt, doit, err, ch, pat_len;
   variable undo_stack_type = struct
     {
	rep_len,
	prev_string,
	user_mark,
	next
     };
   variable undo_stack = NULL;
   variable tmp;
   variable replacement_length = strlen (rep_rep);

 
   prompt =  sprintf ("Replace '%s' with '%s'? (y/n/!/+/q/h)", rep_pat, rep_rep);

   while (pat_len = @rep_fun (rep_pat), pat_len >= 0)
     {
	pop2buf (buf);
	if (listing->Dont_Ask)  % from listing.sl
	  {
	     tmp = create_user_mark ();
	     () = replace_do_replace (rep_rep, pat_len);
	     if ((pat_len == 0) and (tmp == create_user_mark ()))
	       go_right_1 ();
	     continue;
	  }

	do 
	  {
	     message(prompt);
	     mark_next_nchars (pat_len, -1);
	     
	     ch = getkey ();
	     if (ch == 'r')
	       {
		  recenter (window_info('r') / 2);
	       }
	     
	  } while (ch == 'r');
	
	switch(ch)
	  { case 'u' and (undo_stack != NULL) :
	     goto_user_mark (undo_stack.user_mark);
	     push_spot ();
	     () = replace_do_replace (undo_stack.prev_string, undo_stack.rep_len);
	     pop_spot ();
	     undo_stack = undo_stack.next;
	  }   
	  { case 'y' :
	     tmp = @undo_stack_type; 
	     tmp.next = undo_stack;
	     undo_stack = tmp;

	     push_spot(); push_mark ();
	     go_right (pat_len); undo_stack.prev_string = bufsubstr ();
	     pop_spot (); 
	     undo_stack.user_mark = create_user_mark ();
	     undo_stack.rep_len  = replace_do_replace (rep_rep, pat_len);
	  }
	  { case 'n' : go_right_1 ();}
	  { case '+' :
	     () = replace_do_replace (rep_rep, pat_len); 
	     listing->Dont_Ask = -1;
	     setbuf (Bufed_buf);
	     throw UserBreakError, "Quit";
	     break;
	  }
	  { case '!' :
	     listing->Dont_Ask = 1;
	  }
          { case 'q' :  % Don't bother with the remaining buffers 
	     listing->Dont_Ask = -1;
	     setbuf (Bufed_buf);
	     throw UserBreakError, "Quit";
	  }
          {
	     flush ("y:replace, n:skip, !:replace all, u: undo last, +:replace then quit, q:quit");
	     () = input_pending (30); 
	  }
     }
   goto_user_mark(buf_mark);
   pop2buf (Bufed_buf);
   return 1; % untag line
}

% Replace across the tagged buffers.  With prefix, do a regexp search.
define replace_tagged ()
{
   variable prompt;
   continued = 0;
   last_search_replace_cmd="replace";
   if (-1 == prefix_argument (-1))
     rep_fun = &search_search_function;
   else
     rep_fun = &research_search_function;
   
   rep_pat = read_mini("Replace:", Null_String, Null_String);
   !if (strlen (rep_pat)) return;
   prompt = strcat ("Replace '", rep_pat, "' with:");
   rep_rep = read_mini(prompt, "", "");
   try
     {
	listing_map(2, &bufed_replace_with_query);
     }
   catch UserBreakError;
}

%}}}

%{{{ continue searching or replacing

% Continue with last search or replace where we are in the buffer where we 
% were without going back to bob.
% You may setkey this to M-, in global keymap, like in Emacs' dired.
public define bufed_search_or_replace_continue()
{
   continued = 1;
   setbuf(Bufed_buf);
   if (last_search_replace_cmd == "search")
     {
	try
	  {
	     listing_map(2, &bufed_search_buffer);
	  }
	catch UserBreakError;
     }
   else if (last_search_replace_cmd == "replace")
     {
	try
	  {
	     listing_map(2, &bufed_replace_with_query);
	  }
	catch UserBreakError;
     }
}
%}}}


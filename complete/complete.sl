% complete.sl
% 
% $Id: complete.sl,v 1.1 2004/07/01 19:37:17 paul Exp paul $
% Keywords: abbrev, tools
%
% Copyright (c) 2004 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This defines a function called "complete" that runs the blocal hook
% "complete_hook", and a function to find completions in a file.  The idea
% is to bind complete() to a key (M-tab say), make a keywords file, and
% set some blocal variables.  The keywords file is just a sorted file of
% keywords or function names, one per line. For example in php, write a
% php file like
% 
% <?php
% $funs = get_defined_functions();
% sort ($funs["internal"]);
% foreach($funs["internal"] as $word)
%   echo $word ."\n";
% ?>
% 
% save the output to the file php_words in your Jed_Home_Directory, and add
% this to .jedrc:
% 
% define php_mode_hook()
% {
%    define_blocal_var("Word_Chars", "a-zA-Z_0-9");
%    define_blocal_var("complete_hook", "complete_from_file");
% }
% setkey("complete", "\e\t");
% 
% To do partial completion, press M-tab.  To cycle through completions,
% press M-tab again.
%   
% You don't need this for completing in S-Lang, use sltabc.sl for that.

% find the completions of WORD in FILE
% The file should be sorted!
define complete_from_file() % (word [file])
{
   variable word, file;
   (word, file) = push_defaults(,, _NARGS);
   if (word == NULL) return message("no word"); % shouldn't happen
   if (file == NULL) file = dircat(Jed_Home_Directory, strlow
				   (sprintf("%s_words", what_mode, pop)));
   if (1 != file_status(file)) return message ("no completions file");
   
   variable n_completions, len = strlen(word);
   word = str_quote_string (word, "\\^$[]*.+?", '\\');
   n_completions= search_file(file, sprintf("\\c^%s", word), 50);
   switch (n_completions)
     {case 0: return message ("no completions");}
     {case 50: return _pop_n(50);} % we can't do a partial completion
     {case 1: variable completion = strtrim();
	insert (completion[[len:]]);
	return;};

   variable completions = __pop_args(n_completions);
   completions = array_map(String_Type, &strtrim, [__push_args(completions)]);

   variable first_completion, last_completion, i;
   first_completion = completions[0];
   last_completion = completions[-1];
   _for (len, strlen (first_completion), 1)
     {
   	i=();
   	if (first_completion[i] != last_completion[i])
   	  break;
     }
   insert (first_completion[[len:i-1]]);
   message (strjoin(completions, "  "));
   
   variable this_fun = CURRENT_KBD_COMMAND,
   fun_type, fun, n = 0;
   variable sd = _stkdepth;

   % if C-g pressed, undo.
   ERROR_BLOCK
     {
	if (n) del_region;
	return;
     }
   forever
     {
	if (n == n_completions) 
	  {
	     pop_mark_0;
	     return message("no more completions");
	  }
	update_sans_update_hook(1);
	(fun_type, fun) = get_key_binding();
	if(fun != this_fun)
	  break;
	if (n) del_region;
	push_mark;
	insert(completions[n][[i:]]);
	message (strjoin(completions[[n:]], "  "));
	n++;
     }
   if (n) pop_mark_0;
   if(fun_type) call(fun); else eval(fun);
}

define complete_word()
{
   variable word = bget_word();
   !if(strlen(word)) return message("nothing to complete");
   run_blocal_hook("complete_hook", word);
}

provide("complete");

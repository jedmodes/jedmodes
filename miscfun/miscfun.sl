% miscfun.sl   -*- mode: slang; mode: fold -*-
% miscellaneous autoloaded functions
%
% $Id: miscfun.sl,v 1.1.1.1 2004/10/28 08:16:24 milde Exp $
%
% Copyright (c) 2003 Paul Boekholt
% Released under the terms of the GNU GPL (version 2 or later).
%
% look through the file, copy functions you find useful to your own
% miscfun.sl and follow the installation instructions.

%{{{ complete_filename
% This is basically the ashell_completion() function for completing
% filenames from ashell.sl, minus the ashell-specific stuff.
public define complete_filename ()
{
   variable partial_completion;
   variable dir, file;

   push_spot ();
   bskip_chars ("-a-zA-z_.0-9~/\\");
   push_mark ();

   pop_spot ();
   partial_completion = bufsubstr();
   !if (strlen(partial_completion)) return;
   (dir, file) = parse_filename (partial_completion);
   if (andelse {strlen(dir)} {2 != file_status(dir)})
     return message ("directory does not exist");
   variable len = strlen (file);
   variable files = listdir (dir);
   files = files[where (0 == array_map (Int_Type, &strncmp, files, file, len))];

   variable num_matches = length (files);
   if (num_matches == 0)
     return message ("No completions");

   variable match;

   variable i;
   _for (0, num_matches-1, 1)
     {
	i = ();
	match = files[i];
	if (2 == file_status (path_concat (dir, match)))
	  files[i] = path_concat (match, "");   %  add /
     }

   files = files[array_sort(files)];

   match = files[0];
   if (num_matches == 1)
     {
	insert (match[[len:]]);
	return;
     }

   % Complete as much as possible.  By construction, the first len characters
   % in the matches list are the same.  Start from there.
   _for (len, strlen (match)-1, 1)
     {
	i=();
	if (match[i] != files[-1][i])
	  break;
     }
   
   insert (match[[len:i-1]]);

   message (strjoin(files, "  "));  
}

%}}}

%{{{ repeat
% Function to repeat the last command given.  It's inspired by Emacs'
% repeat.el, which was inspired by Vi's . command. However this one will
% repeat moving down or moving up!  To start repeating, type C-x z,
% assuming you've added this to .jedrc: setkey ("repeat", "^Xz");

% To repeat on this line, type z z z .....
% To go down and repeat, type Z Z Z ....
% To go up and repeat, type a a a ....
public define repeat()
{
   variable prefix = prefix_argument(-1);
   variable last_cmd = LAST_KBD_COMMAND, last_key,
     fun_type, fun;
   if (last_cmd == "") return message ("don't know what to repeat");
   forever
     {
	vmessage("repeating %s, z: repeat  Z: go down, repeat  a: go up, repeat", last_cmd);
	update_sans_update_hook(0);
	last_key = getkey;
	switch (last_key)
	  { case 'z' : }
	  { case 'Z' : go_down_1;}
	  { case 'a' : go_up_1;}
	  { break;}
	switch (is_defined(last_cmd))
	  {case 1: call (last_cmd);}
	  {case 2: eval (last_cmd);}
	  {(fun_type, fun) = get_key_binding(last_cmd);
	     if(fun_type) call(fun); else eval(fun);
	  }
     }
   ungetkey(last_key);
}

%}}}

%{{{ slang_format_paragraph
% Format slang comments.  We try to handle both bol comments and
% indented comments. Install:
%
% define slang_mode_hook
% {
%   definekey ("smart_format_par", "q", "C");
% }
autoload("c_format_paragraph", "cmisc");
static define slang_format_paragraph()
{
   push_spot_bol;
   push_mark;
   skip_white;
   !if(looking_at_char('%')) return pop_mark_0, pop_spot;
   go_right_1;
   variable comment = bufsubstr, clen = strlen(comment);
   % narrow to comment
   while (up_1)
     {
	bol;
	if (orelse
	    { not looking_at(comment)}
	    % test for listings, tm macros, changelog entries, folding marks,
	    % empty lines and "%%" section markers
	      { go_right(clen), skip_white, eolp}
	      { push_mark, go_right_1, is_substr("-%\\*{", bufsubstr())})
	    {
	       go_down_1;
	       break;
	    }
       }
   push_mark;
   goto_spot;
   while (down_1)
     {
	if (orelse
	    { not looking_at(comment)}
	      { go_right(clen), skip_white, eolp}
	      { push_mark, go_right_1, is_substr("-%\\*{", bufsubstr())})
	  {
	     go_up_1;
	     break;
	  }
     }
   narrow;
   % uncomment
   bob;
   deln(clen);
   while (down(1))
     deln(clen);
   goto_spot;
   % reformat
   text_mode();
   WRAP=75 - strlen(strreplace(comment, "\t", "        ", clen), pop);
   call("format_paragraph");
   slang_mode;
   % recomment
   bob;
   insert(comment);
   while (down(1))
     insert(comment);
   pop_spot;
   widen;
}

public define smart_format_par ()
{
   if ("SLang" == (what_mode, pop))
     slang_format_paragraph;
   else
     c_format_paragraph;
}

%}}}

%{{{ wdiff_mode
% Mode for viewing wdiff output.
#ifdef HAS_DFA_SYNTAX
create_syntax_table ("wdiff");
%%% DFA_CACHE_BEGIN %%%
static define setup_dfa_callback (mode)
{
   % This says that a chunk looks like: a [- followed by one or more
   % occurences of ((not a - and not a {) or (a - not followed by a ]) or
   % (a { not followed by a +)) , followed by one or more -'s and a ]
   dfa_define_highlight_rule ("\\[\\-([^\\-\\{]|\\-[^\\]]|\\{[^\\+])+\\-+\\]", "string", mode);
   dfa_define_highlight_rule ("\\{\\+([^\\+\\[]|\\+[^\\}]|\\[[^\\-])+\\++\\}", "comment", mode);
   dfa_build_highlight_table(mode);
}
dfa_set_init_callback (&setup_dfa_callback, "wdiff");
%%% DFA_CACHE_END %%%
enable_dfa_syntax_for_mode("wdiff");
#endif

define wdiff_mode()
{
   set_mode("wdiff", 0);
   use_syntax_table("wdiff");
   view_mode;
}

% Adapted from Günter's diff()
public define wdiff() % (old, new)
{
   variable old, new;
   (old, new) = push_defaults( , , _NARGS);
   variable prompt = sprintf("Compare ");
   if (old == NULL)
     old = read_with_completion(prompt, "", "", 'f');
   if (new == NULL)
     new = read_with_completion(prompt + old + " to", "", "", 'f');
   
   % Prepare the output buffer
   sw2buf("*wdiff*");
   set_readonly(0);
   erase_buffer();
   
   % call the diff command
   flush("calling wdiff");
   shell_perform_cmd(strjoin(["wdiff -n", old, new], " "), 1);
   set_buffer_modified_flag(0);
   wdiff_mode();
}

%}}}

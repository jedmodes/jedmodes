% flyspell.sl  -*- mode: SLang; mode: Fold -*-
%
% $Id: flyspell.sl,v 1.15 2004/03/25 16:31:03 paul Exp paul $
% 
% Copyright (c) 2003,2004 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This file provides a minor mode for on-the-fly spell checking.  We use
% the _jed_switch_active_buffer_hooks to set the _jed_after_key_hooks
% depending on the flyspell blocal var.  In English: you need JED 0.99.16
% or greater.
  
require("ispell_common");
autoload("get_blocal", "sl_utils");
autoload("add_keyword_n", "syntax");
use_namespace("ispell");
% The DFA trick used in this file does not work with "-" as an otherchar,
% so we trim it.
variable flyspell_otherchars = strtrim_beg(ispell_otherchars, "-");
variable flyspell_wordchars = flyspell_otherchars + ispell_letters;
variable flyspell_syntax_table;

% do you want to use keyword2 to have red misspellings?
custom_variable("flyspell_use_keyword2", 1);
static variable flyspell_chars = " ";

!if (is_defined("flyspell_process"))
  public variable flyspell_process = -1;

%{{{ Flyspell process

% This will also restart flyspell, through the flyspell_is_dead() function
public define kill_flyspell()
{
   if (-1 != flyspell_process)
     kill_process(flyspell_process);
}

public define flyspell_parse_output (pid, output)
{
   variable name = flyspell_syntax_table;
   output = strtrim(output);
   if (strlen(output))
     {
	output = strtok(output)[1];
	if (flyspell_use_keyword2)
	  add_keyword_n(name, output, 2);
	else
	  add_keyword(name, output);
     }
}

public define flyspell_is_dead (pid, flags, status)
{
   if (flags & 14)
     flyspell_process = -1;
}

static define toggle_local_flyspell();

static define flyspell_init_process ()
{
   % we need to redefine these in case this process was started
   % by switching to a buffer in another language
   flyspell_otherchars = strtrim_beg(ispell_otherchars, "-");
   flyspell_wordchars = flyspell_otherchars + ispell_letters;

   variable buf, ibuf = " *flyspell*";
   % JED has problems with asynchronous processes that are stopped and
   % immediately restarted so we make sure that we kill the process when
   % the dictionary changes, and start it when it's needed.
   if (flyspell_process != -1)
     return;
   buf = whatbuf();

   variable args = strtok (ispell_command + " -a");
   setbuf(ibuf);
   erase_buffer;
   message ("starting flyspell process....");
   foreach (args)
     ;
   length (args) - 1;
   flyspell_process = open_process ();

   sleep(0.5);
   get_process_input(2);

   if (flyspell_process == -1)
     error ("could not start ispell");
   
   % Give ispell a chance to start.  Maybe I should use 
   % wait_for_ispell_output() here.
   variable flyspell_started = 0;
   loop (5)
     {
	
	bob ();
	if (looking_at_char ('@'))     %  ispell header
	  {
	     flyspell_started = 1;
	     del_through_eol ();
	     break;
	  }
	else get_process_input(2);
     }
   
   !if (flyspell_started)
     
     % if we're not looking at the ispell header, there was probably an
     % error.  For some reason flyspell does not exit (or maybe the
     % signal handler can't run) before this function returns so telling
     % if a process has started successfully is a bit difficult.
     {
	pop2buf(whatbuf);
	flyspell_process = -1;
	pop2buf(buf);
	toggle_local_flyspell(0);
	verror ("Flyspell crashed!");
     }
   send_process(flyspell_process, "!\n");
   set_process (flyspell_process, "signal", "flyspell_is_dead");
   set_process (flyspell_process, "output", "flyspell_parse_output");
   process_query_at_exit(flyspell_process, 0);
   setbuf(buf);
}


%}}}

%{{{ Flyspelling

static variable lastword = "", lastpoint = 0;
public define flyspell_word()
{
   variable word, point;
   if (flyspell_process == -1) 
     flyspell_init_process;
   push_spot();
   bskip_chars(ispell_non_letters);
   push_mark();
   bskip_chars(flyspell_wordchars);
   skip_chars(flyspell_otherchars);
   point = _get_point();
   word = bufsubstr();
   if (word == "") return pop_spot();

   EXIT_BLOCK 
     { 
	(lastword, lastpoint) = word, point;
	pop_spot();
     }
   
   if (word == lastword)
   {
      if (point != lastpoint)
	{
	   bskip_chars(ispell_non_letters);
	   bskip_chars(flyspell_wordchars);
	   skip_chars(flyspell_otherchars);

	   if (looking_at(word))
	     {
		message("double word");
		beep();
	     }
	}
      return;
   }
   if (strlen(word) < 3) return;
   
   send_process( flyspell_process, strcat ("^", word, "\n"));
}

static define after_key_hook ()
{
   if (is_substr(flyspell_chars, LASTKEY))
     flyspell_word();
}


%}}}

%{{{ Turning flyspell mode on/off

static define flyspell_switch_active_buffer_hook(oldbuf)
{
   if (get_blocal("flyspell", 0))
     add_to_hook ("_jed_after_key_hooks", &after_key_hook);
   else
     remove_from_hook ("_jed_after_key_hooks", &after_key_hook);
   flyspell_syntax_table = get_blocal("flyspell_syntax_table", "Flyspell_" + flyspell_current_dictionary);
}

static define toggle_local_flyspell() % on/off
{
   variable flyspell;
   !if (_NARGS) not get_blocal("flyspell", 0);
   flyspell = ();
   define_blocal_var("flyspell", flyspell);
   if (flyspell)
     {
	set_status_line(str_replace_all(Status_Line_String, "%m", "%m fly"), 0);
	if (flyspell_current_dictionary != ispell_current_dictionary)
	  {
	     kill_flyspell;
	     flyspell_current_dictionary = ispell_current_dictionary;
	  }
     }
   else
     {
	set_status_line(Status_Line_String, 0);
     }
   flyspell_switch_active_buffer_hook("");  % hook expects an argument
}

%}}}


#ifdef HAS_DFA_SYNTAX
%%% DFA_CACHE_BEGIN %%%
static define setup_dfa_callback (name)
{
   dfa_enable_highlight_cache( sprintf("%s.dfa", name), name);
   dfa_define_highlight_rule 
     (sprintf("[%s][%s]*[%s]",ispell_letters, flyspell_wordchars, ispell_letters),
      "Kdelimiter", name);
   % Kdelimiter means "Keyword delimiter" or something.  I found this in
   % html.sl but there it needs fixing.
   dfa_build_highlight_table (name);
}
%%% DFA_CACHE_END %%%
#endif


static define flyspell_make_syntax_table(name)
{
   flyspell_otherchars = strtrim_beg(ispell_otherchars, "-");
   flyspell_wordchars = flyspell_otherchars + ispell_letters;

   create_syntax_table(name);
   set_syntax_flags(name, 0);
   define_syntax(ispell_wordchars, 'w', name);
   dfa_set_init_callback (&setup_dfa_callback, name);
}

% A change in syntax table is from starting flyspell in a buffer with
% another language, or from changing the language while flyspelling.  If
% you just switch to a buffer with a different setting for language, it
% should continue to use its own syntax table. 
public define flyspell_change_syntax_table(language)
{
   variable table = get_blocal("flyspell_syntax_table", NULL);
   if(table != NULL)
     {
	use_syntax_table(table);
	define_syntax(ispell_wordchars, 'w', table);

	use_dfa_syntax(0);
	flyspell_syntax_table=table;
     }
   else
     {
	table = "Flyspell_" + language;
	flyspell_make_syntax_table(table);
     }
   flyspell_syntax_table = table; 
   % this will get confused when you change the global language from a
   % buffer that has a blocal language.
   use_syntax_table(table);
   use_dfa_syntax(0); % the DFA otherchars trick works even without DFA?
}

%!%+
%\function{flyspell_mode}
%\synopsis{toggle flyspell mode}
%\usage{flyspell_mode()}
%\description
%   This toggles flyspell mode for the buffer.  In flyspell mode,
%   misspelled words are highlighted as you type.  If you're in doubt
%   whether flyspell mode is on, look at the statusbar - it should say
%   something like "(text fly)"
%\notes
%   Flyspell works by adding the misspellings to a flyspell syntax table
%   asynchronously, which means that JED's flyspell mode does not give
%   the slow responsiveness of Emacs' flyspell mode and other similar
%   products.  It also means that mode-dependent syntax highlighting is
%   turned off while you flyspell.  You can make flyspell write its
%   misspellings to a syntax table of your choice by setting the
%   bufferlocal variable \var{flyspell_syntax_table} (\var{mail_mode} does this)
%\seealso{ispell, flyspell_region}
%!%-
public define flyspell_mode()
{
   flyspell_init_process();
   flyspell_change_syntax_table(ispell_current_dictionary);
   toggle_local_flyspell();
   if (flyspell_use_keyword2)
     set_color("keyword2", "brightred", get_color("normal"), exch(), pop);
   add_to_hook("_jed_switch_active_buffer_hooks",
	       &flyspell_switch_active_buffer_hook);
}


% I can't give a whole region at once, see also the the changelog for
% version 1.4 of ishell.sl
%!%+
%\function{flyspell_region}
%\synopsis{highlight misspellings in the region}
%\usage{flyspell_region()}
%\description
%   Send the region, or the buffer if there is no visible mark, to the
%   flyspell process.  If the buffer is not in flyspell mode, flyspell
%   mode is turned on.
%\seealso{flyspell_mode, ispell_region}
%!%-
public define flyspell_region()
{
   variable string;
   
   flyspell_current_dictionary = ispell_current_dictionary;
   !if (get_blocal("flyspell", 0))
     flyspell_mode;

   push_spot;
   !if (is_visible_mark) 
     mark_buffer;
   flush ("flyspelling...");
   foreach(strchop(bufsubstr(), '\n', 0))
     {
   	string = ();
   	send_process( flyspell_process, "^" + string + "\n");
   	get_process_input(1);
     }
   pop_spot;
   flush("flyspelling...done");
}

provide("flyspell");

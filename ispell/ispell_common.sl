% ispell_common.sl	-*- mode: SLang; mode: fold -*-
%
% Author:	Paul Boekholt
%
% $Id: ispell_common.sl,v 1.11 2004/03/05 14:32:21 paul Exp $
% 
% Copyright (c) 2003,2004 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This file provides some definitions common to ispell, flyspell and
% vispell. It is not part of JED.
% The JMR ispell package can be found at http://jedmodes.sf.net

implements("ispell");

require ("ispell_init");

variable
  ispell_letters,
  ispell_non_letters,
  ispell_otherchars,       %  otherchars are chars that
  % may appear inside words, in .aff files they're called boundarychars.
  ispell_wordchars,
  ispell_wordlist,
  ispell_command;

variable ispell_current_dictionary = Ispell_Dictionary;
variable flyspell_current_dictionary = Ispell_Dictionary;

% make the ispell command (except for options only needed by some modes)
% and set the ispell_language settings
define make_ispell_command()
{
   variable options, ispell_options = "";
   % this was added after a discussion on the JED mailing list about a
   % security hole in modehook.sl
   if (Ispell_Program_Name != "ispell" and Ispell_Program_Name != "aspell")
     error ("spell program should be ispell or aspell");

   ispell_letters = Ispell_Letters [ispell_current_dictionary];
   ispell_otherchars =  Ispell_OtherChars [ispell_current_dictionary];
   ispell_wordlist =  Ispell_Wordlist [ispell_current_dictionary];

   if (ispell_current_dictionary != "default")
     ispell_options += " -d " + Ispell_Hash_Name[ispell_current_dictionary];

   if (Ispell_Extchar [ispell_current_dictionary] != "")
     ispell_options += " -T " + Ispell_Extchar [ispell_current_dictionary];

   % extra options come last
   ispell_options += " " + Ispell_Options [ispell_current_dictionary];

   ispell_wordchars = ispell_otherchars+ispell_letters;
   ispell_non_letters = "^" + ispell_letters;
   
   % we don't set a '-[thn]' option here because an ispell/flyspell
   % process may work on different buffers, and probably doesn't need it
   ispell_command = strcompress
     (strcat (Ispell_Program_Name, " ", ispell_options), " ");
}


%{{{ set language

%{{{ change the current language
static define ispell_change_current_dictionary(new_language)
{
   if (new_language != ispell_current_dictionary)
     {
	ispell_current_dictionary = new_language;
	make_ispell_command();
	runhooks("kill_ispell");
	if (get_blocal("flyspell", 0)
	    and flyspell_current_dictionary != ispell_current_dictionary)
	  {
	     runhooks("kill_flyspell");
	     flyspell_current_dictionary = ispell_current_dictionary;
	     runhooks("flyspell_change_syntax_table", new_language);
	  }
     }
}
%}}}
%{{{ change the global language

%!%+
%\function{ispell_change_dictionary}
%\synopsis{cange the ispell dictionary}
%\usage{ispell_change_dictionary([new_language])}
%\description
%   Change \var{Ispell_Dictionary} and the ispell-internal variable
%   \var{ispell_current_dictionary} to \var{new_language} and kill old
%   ispell and flyspell process if this means a change in
%   \var{ispell_current_dictionary}.  A new one will be started as
%   soon as necessary.
%\notes
%   Setting Ispell_Dictionary to "ask" will cause ispell to prompt
%   for a language the first time an ispell function is called.
%\seealso{ispell_change_local_dictionary, ispell, flyspell_mode}
%!%-
public define ispell_change_dictionary() % ([new_language])
{
   variable new_language;
   if (_NARGS)
     new_language = ();
   else
     {
	new_language = read_with_completion
	  (strjoin(assoc_get_keys(Ispell_Hash_Name), ","),
	   "new language", Ispell_Dictionary, "", 's');
     }
   Ispell_Dictionary = new_language;
   ispell_change_current_dictionary(new_language);
}

% kludge to get _NARGS right with menu selection
public define ispell_dictionary_menu_item(language)
{
   ispell_change_dictionary(language);
}

%}}}
%{{{ change blocal language

% Change the language
%!%+
%\function{ispell_change_local_dictionary}
%\synopsis{change the bufferlocal ispell dictionary}
%\usage{ispell_change_local_dictionary([new_language])}
%\description
%   Change the bufferlocal variable \var{ispell_dictionary} and the
%   ispell-internal variable \var{ispell_current_dictionary} to
%   \var{new_language} and kill old ispell and flyspell process if this
%   means a change in \var{ispell_current_dictionary}.  A new one will
%   be started as soon as necessary.
%\notes
%   There is only one \var{ispell_current_dictionary}.  When switching
%   between flyspelled buffers in different languages, the ispell
%   process has to be restarted.
%\seealso{ispell_change_dictionary, ispell, flyspell_mode}
%!%-
public define ispell_change_local_dictionary() % ([new_language])
{
   variable new_language;
   if (_NARGS)
     new_language = ();
   else
     {
	new_language = read_with_completion
	  (strjoin(assoc_get_keys(Ispell_Hash_Name), ","),
	   "new language", get_blocal("ispell_dictionary", Ispell_Dictionary), "", 's');
     }
   define_blocal_var("ispell_dictionary", new_language);
   ispell_change_current_dictionary(new_language);
}

% kludge to get _NARGS right with menu selection
public define ispell_local_dictionary_menu_item(language)
{
   ispell_change_local_dictionary(language);
}

public define ispell_switch_buffer_hook(old_buffer)
{
   ispell_change_current_dictionary(get_blocal("ispell_dictionary", Ispell_Dictionary));
}

add_to_hook("_jed_switch_active_buffer_hooks", &ispell_switch_buffer_hook);


%}}}

%}}}

%{{{ some helper functions

% this only works right if you're on a word of course
static define ispell_beginning_of_word()
{
   bskip_chars(ispell_wordchars);
   skip_chars(ispell_otherchars);
}
static define ispell_end_of_word()
{
   skip_chars(ispell_wordchars);
   bskip_chars(ispell_otherchars);
}

%}}}
if (Ispell_Dictionary == "ask") ispell_change_dictionary();
make_ispell_command;

provide ("ispell_common");

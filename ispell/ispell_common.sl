% ispell_common.sl
%
% $Id: ispell_common.sl,v 1.18 2007/09/29 18:50:46 paul Exp paul $
% 
% Copyright (c) 2003-2007 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This file provides some definitions common to ispell, flyspell and
% vispell. It is not part of JED.
% The JMR ispell package can be found at http://jedmodes.sf.net

provide ("ispell_common");

require ("ispell_init");
require("menutils");
implements("ispell");

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

define flyspell_switch_active_buffer_hook();
define flyspell_change_syntax_table();
define kill_ispell();
define kill_flyspell();

% make the ispell command (except for options only needed by some modes)
% and set the ispell_language settings
private define make_ispell_command()
{
   variable ispell_options = "";
   if (Ispell_Program_Name == "ispell")
     {
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
     }
   else if (Ispell_Program_Name == "aspell")
     {
	ispell_letters = Aspell_Letters [ispell_current_dictionary];
	ispell_otherchars =  Aspell_OtherChars [ispell_current_dictionary];
	ispell_wordlist =  Aspell_Wordlist [ispell_current_dictionary];
	
	if (ispell_current_dictionary != "default")
	  ispell_options += " -d " + Aspell_Hash_Name[ispell_current_dictionary];
	
	% extra options come last
	ispell_options += " " + Aspell_Options [ispell_current_dictionary];
	
	ispell_wordchars = ispell_otherchars+ispell_letters;
	ispell_non_letters = "^" + ispell_letters;
	
     }
   else
     throw RunTimeError, "spell program should be ispell or aspell";
   
   % we don't set a '-[thn]' option here because an ispell/flyspell
   % process may work on different buffers, and probably doesn't need it
   ispell_command = strcompress
     (strcat (Ispell_Program_Name, " ", ispell_options), " ");
}


%{{{ set language

%{{{ change the current language
private define ispell_change_current_dictionary(new_language)
{
   if (new_language != ispell_current_dictionary)
     {
	ispell_current_dictionary = new_language;
	make_ispell_command();
	kill_ispell();
	if (get_blocal_var("flyspell", 0)
	    and flyspell_current_dictionary != ispell_current_dictionary)
	  {
	     kill_flyspell();
	     flyspell_current_dictionary = ispell_current_dictionary;
	     flyspell_change_syntax_table(new_language);
	  }
     }
}
%}}}
%{{{ get dictionaries
private define dictionaries()
{
   if (Ispell_Program_Name == "aspell")
     return assoc_get_keys(Aspell_Hash_Name);
   else
     return assoc_get_keys(Ispell_Hash_Name);
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
	  (strjoin(dictionaries(), ","),
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
	  (strjoin(dictionaries(), ","),
	      "new language", get_blocal_var("ispell_dictionary", Ispell_Dictionary), "", 's');
     }
   define_blocal_var("ispell_dictionary", new_language);
   ispell_change_current_dictionary(new_language);
}

% kludge to get _NARGS right with menu selection
public define ispell_local_dictionary_menu_item(language)
{
   ispell_change_local_dictionary(language);
}

define ispell_switch_buffer_hook(old_buffer)
{
   ispell_change_current_dictionary(get_blocal_var("ispell_dictionary", Ispell_Dictionary));
   flyspell_switch_active_buffer_hook();
}

% The blocal may have been set from e.g. gdbmrecent.sl or a modehook
ispell_switch_buffer_hook("");
add_to_hook("_jed_switch_active_buffer_hooks", &ispell_switch_buffer_hook);


%}}}

%}}}
%{{{ menu

private variable menu_local_dummy; % menu_radio can't use blocals

public define ispell_change_dictionary_callback (popup)
{
   menu_append_item (popup, "&Word", "ispell");
   menu_append_item (popup, "&Region", "ispell_region");
   menu_append_item (popup, "&Flyspell", "flyspell_mode");
   menu_append_separator(popup);
   variable lang, languages = dictionaries();
   languages = languages[array_sort(languages)];
   menu_radio (popup, "dictionary", &Ispell_Dictionary, languages, ,
	       &ispell_change_dictionary); 
   
   menu_local_dummy= get_blocal_var("ispell_dictionary", Ispell_Dictionary);
   menu_radio (popup, "&buffer dictionary", &menu_local_dummy, languages, , 
	       &ispell_change_local_dictionary);
}

%}}}

%{{{ some helper functions

% this only works right if you're on a word of course
define ispell_beginning_of_word()
{
   bskip_chars(ispell_wordchars);
   skip_chars(ispell_otherchars);
}
define ispell_end_of_word()
{
   skip_chars(ispell_wordchars);
   bskip_chars(ispell_otherchars);
}

%}}}
if (Ispell_Dictionary == "ask") ispell_change_dictionary();
make_ispell_command;


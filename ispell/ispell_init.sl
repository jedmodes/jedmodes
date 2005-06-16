% ispell_init.sl	-*- mode: SLang; mode: fold -*-
%
% Author:	Paul Boekholt
%
% $Id: ispell_init.sl,v 1.9 2005/06/16 08:48:37 paul Exp paul $
%
% Copyright (c) 2003 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
%
% This defines global variables and functions for the ispell package. 
% You may evaluate this on starting JED. 
% Version numbering for this package follows the RCS numbering of
% ispell.sl
provide ("ispell_init");

variable ispell_version = "ispell.sl 1.18";

%{{{ autoloads

_autoload("ispell_change_dictionary", "ispell_common",
	  "ispell_dictionary_menu_item", "ispell_common",
	  "ispell_change_local_dictionary", "ispell_common",
	  "ispell_local_dictionary_menu_item", "ispell_common",
	  "ispell_complete", "look",
	  "flyspell_mode","flyspell",
	  "flyspell_region", "flyspell",
	  "auto_ispell", "ispell",
	  "ispell_region", "ispell",
	  "vispell", "vispell", 10);
_add_completion("ispell_change_dictionary",
		"ispell_change_local_dictionary",
		"flyspell_mode", "ispell_region", 
		"flyspell_region", 5);


%}}}
%{{{ custom variables

% Your spell program.  This could be ispell or aspell.
custom_variable("Ispell_Program_Name", "ispell");
% your default dictionary. "default" means use system default
custom_variable("Ispell_Dictionary", "default");

%}}}
%{{{ public variables


public variable Ispell_Hash_Name = Assoc_Type [String_Type, "default"];
public variable Ispell_Letters = Assoc_Type 
  [String_Type,
   "a-zA-Z‡ËÏÚ˘·ÈÌÛ˙‰ƒÎÀÔœˆ÷ﬂ¸‹‚ÍÓÙ˚¿»Ã“Ÿ¡…Õ”⁄ƒÀœ÷‹¬ Œ‘€Á«„√Ò—ı’Ê¯Â∆ÿ≈Ê¯Â∆ÿﬁ˛–"];
public variable Ispell_OtherChars = Assoc_Type [String_Type, "'"];
public variable Ispell_Extchar = Assoc_Type [String_Type, ""];
public variable Ispell_Options = Assoc_Type [String_Type, ""];
public variable Ispell_Wordlist = Assoc_Type [String_Type,"/usr/share/dict/words"];

public define ispell_add_dictionary() % (name, hash=name, letters = a-z etc.,
  % otherchars = "'", extchr = "", opts = "")
{
   variable name, hash, letters, otherchars, extchr, opts;
   (name, hash, letters, otherchars, extchr, opts)
     = push_defaults ( , , , , , , _NARGS);
   if (hash != NULL)
     Ispell_Hash_Name [name] = hash;
   else
     Ispell_Hash_Name [name] = name;
   if (letters != NULL)
     Ispell_Letters [name] = strcat ("a-zA-Z", letters);
   if (otherchars != NULL)
     Ispell_OtherChars [name] = otherchars;
   if (extchr != NULL)
     % Get rid of "~" char at beginning
     Ispell_Extchar [name] = strtrim_beg (extchr, "~");
   if (opts != NULL)
     Ispell_Options [name] = opts;
}

ispell_add_dictionary ("default");

% This will set up the dictionaries on your system, if you are a Debian Unstable user.
custom_variable("Ispell_Cache_File", "/var/cache/dictionaries-common/jed-ispell-dicts.sl");
if (1 == file_status (Ispell_Cache_File))
  () = evalfile (Ispell_Cache_File);
% else % otherwise, add your dictionaries here, or in your .jedrc after loading this file.
% {
%    ispell_add_dictionary("deutsch", "german", "", "", "latin1");
%    ispell_add_dictionary("nederlands", "dutch", "", "-'");
%    ispell_add_dictionary("british");
% }

%}}}
%{{{ menu
private variable menu_local_dummy; % menu_radio can't use blocals

public define ispell_change_dictionary_callback (popup)
{
   menu_append_item (popup, "&Word", "ispell");
   menu_append_item (popup, "&Region", "ispell_region");
   menu_append_item (popup, "&Flyspell", "flyspell_mode");
   menu_append_separator(popup);
   variable lang, languages = assoc_get_keys(Ispell_Hash_Name);
   languages = languages[array_sort(languages)];
   menu_radio (popup, "dictionary", &Ispell_Dictionary, languages, ,
	       &ispell_change_dictionary); 

   menu_local_dummy= get_blocal("ispell_dictionary", Ispell_Dictionary);
   menu_radio (popup, "&buffer dictionary", &menu_local_dummy, languages, , 
	       &ispell_change_local_dictionary);
}

static define ispell_load_popup_hook (menubar)
{
   variable menu = "Global.S&ystem";
   menu_delete_item (menu + ".&Ispell");
   menu_append_popup (menu, "&Ispell");
   menu = "Global.S&ystem.&Ispell";
   menu_set_select_popup_callback(menu, &ispell_change_dictionary_callback);
}
append_to_hook ("load_popup_hooks", &ispell_load_popup_hook);

%}}}


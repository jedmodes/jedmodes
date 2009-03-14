% ispell_init.sl	-*- mode: SLang; mode: fold -*-
%
% $Id: ispell_init.sl,v 1.15 2009/03/14 15:21:29 paul Exp paul $
%
% Copyright (c) 2003-2007 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
%
% This defines global variables and functions for the ispell package. 
% You may evaluate this on starting JED. 
require("sl_utils");
provide ("ispell_init");

%{{{ autoloads

_autoload("ispell_change_dictionary", "ispell_common",
	  "ispell_dictionary_menu_item", "ispell_common",
	  "ispell_change_local_dictionary", "ispell_common",
	  "ispell_local_dictionary_menu_item", "ispell_common",
	  "ispell_complete", "look",
	  "flyspell_mode","flyspell",
	  "flyspell_region", "flyspell",
	  "ispell_region", "ispell",
	  "vispell", "vispell", 9);
_add_completion("ispell_change_dictionary",
		"ispell_change_local_dictionary",
		"flyspell_mode", "ispell_region", 
		"flyspell_region", 5);


%}}}
%{{{ custom variables

% Your spell program.  This could be ispell or aspell.
ifnot (is_defined("Ispell_Program_Name"))
{
   variable Ispell_Program_Name;
   if (1 == file_status("/usr/bin/aspell")
       || 1 == file_status("/usr/local/bin/aspell"))
     Ispell_Program_Name = "aspell";
   else if (1 == file_status("/usr/bin/hunspell")
       || 1 == file_status("/usr/local/bin/hunspell"))
     Ispell_Program_Name = "hunspell";
   else
     Ispell_Program_Name = "ispell";
}

% your default dictionary. "default" means use system default
custom_variable("Ispell_Dictionary", "default");

%}}}
%{{{ public variables

typedef struct { hash_name, letters, otherchars, extchar, options } Ispell_Dictionary_Type;

private define make_ispell_dictionary() 
{
   variable name, hash, letters, otherchars, opts;
   (name, hash, letters, otherchars, opts)
     = push_defaults ( , , "", "", "", _NARGS);
   if (hash == NULL)
     hash = name;
   variable language = @Ispell_Dictionary_Type;
   set_struct_fields(language,
		     hash,
		     strcat ("a-zA-Z",letters),
		     otherchars,
		     strtrim_beg (qualifier("ext_chr", ""), "~"),
		     opts);
   return language;
}

variable Ispell_Languages = Assoc_Type[Ispell_Dictionary_Type];
variable Ispell_Wordlist = Assoc_Type [String_Type,"/usr/share/dict/words"];

public define ispell_add_dictionary() % (name, hash=name, letters = a-z etc.,
  % otherchars = "'", extchr = "", opts = "")
{
   variable args = __pop_list(_NARGS - 1);
   variable name = ();
   variable extchar;
   if (length(args) >= 4)
     extchar = list_pop(args, 4);
   else
     extchar = "";
   Ispell_Languages [name] = make_ispell_dictionary(name, __push_list(args); ext_char=extchar);
}

ispell_add_dictionary ("default");

variable Aspell_Languages = Assoc_Type[Ispell_Dictionary_Type];

public define aspell_add_dictionary() % (name, hash=name, letters = a-z etc.,
  % otherchars = "'", opts = "")
{
   variable args = __pop_list(_NARGS - 1);
   variable name = ();
   Aspell_Languages [name] = make_ispell_dictionary(name, __push_list(args));
}

aspell_add_dictionary ("default");

variable Hunspell_Languages = Assoc_Type[Ispell_Dictionary_Type];

public define hunspell_add_dictionary() % (name, hash=name, letters = a-z etc.,
  % otherchars = "'", opts = "")
{
   variable args = __pop_list(_NARGS - 1);
   variable name = ();
   Hunspell_Languages [name] = make_ispell_dictionary(name, __push_list(args));
}

hunspell_add_dictionary ("default");

% This will set up the dictionaries on your system, if you are a Debian Unstable user.
custom_variable("Ispell_Cache_File", "/var/cache/dictionaries-common/jed-ispell-dicts.sl");
if (1 == file_status (Ispell_Cache_File))
  () = evalfile (Ispell_Cache_File);
% else % otherwise, add your dictionaries here, or in your .jedrc after loading this file.
% {
%    ispell_add_dictionary("deutsch", "german", "", "", "latin1");
%    ispell_add_dictionary("british");
%    % if you're using utf-8, try something like
%    ispell_add_dictionary("nederlands", "nl", "a-zA-ZÄËÏÖÜäëïöüáéíóú", "-'", "", "-B");
% }

%}}}
%{{{ menu
autoload("ispell_change_dictionary_callback", "ispell_common");
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


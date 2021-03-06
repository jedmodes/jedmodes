% ding.sl   Ding dictionary lookup
%
% Copyright (c) 2006 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% inspired by the tcl/tk program "ding" for german-english translation
%
% Version    0.8   first draft
% Version    1     Adapted to the new format of the ding dictionary
% 2005-04-07 1.1   bugfix: added missing autoloads
% 2005-11-07 1.2   changed _implements() to implements()
% 2006-05-26 1.2.1 missing autoload and forward def. for ding() (J. Sommer)
% 2006-06-01 1.2.2 forward def needs to be public
% 2007-04-16 1.3   error message, if no dictionary found
% 2007-04-17 1.3.1 replaced custom variable Wordlists with private one and
%                  auxiliary function ding->add_dictionary
% 	     	   Documentation update, cleanup,
% 	     	   bugfixes: Case sensitivity, Ding_Dictionary
% 2007-06-03 1.4   convert iso-latin1 <-> UTF-8 if not in UTF-8 mode.
% 2007-09-20 1.4.1 reset blocal var "encoding" with buffer re-use,
% 	     	   use List for blocal var "generating_function"
% 2009-02-16 1.5   ding(): an empty string arg triggers an interactive
% 	     	   request for a word the same way as no optional arg does,
% 	     	   custom var Ding_Case_Search,
% 	     	   failsave formatting.
% 2009-12-08 1.8.1 Adapt to new require() syntax in Jed 0.99.19
%
% Usage
% -----
%
% * Place "ding.sl" in the jed_library_path
%
% * Add autoload("ding", "ding") to your .jedrc (or use update_ini()
%   from  make_ini.sl)
%
% * Add your dictionaries
%   "de-en" is automatically set, if the file is found in a standard location
%
%   Proposed scheme for keys is lang1-lang2 with abbreviations from 'locale'
%   settings, say "de-en" == German::English, e.g.::
%
%     autoload("ding->add_dictionary", "ding");
%     define ding_setup_hook()
%     {
%
%       ding->add_dictionary("de-en", "/usr/share/trans/de-en");
%       ding->add_dictionary("se-de", "~/dictionaries/swedish-german.txt");
%     }
%
% * Optionally change custom variables

% Requirements
% ------------
%
% * A bilingual wordlist in ASCII format (e.g. the one that comes
%   with "ding" http://www.tu-chemnitz.de/~fri/ding/ (German-English)
%   or the ones from the "magic dic" http://magic-dic.homeunix.net/ )
%
% * the grep command (with support for the -w argument, e.g. GNU grep)
% 
% * extensions from http://jedmodes.sf.net/
%
#if (_jed_version > 9918)
require("keydefs", "Global");  % standard mode not loaded by default
require("view", "Global");     % readonly-keymap
require("sl_utils", "Global"); % basic stuff
require("bufutils", "Global");
#else
require("keydefs");
require("view");
require("sl_utils");
require("bufutils");
#endif
autoload("get_word", "txtutils");
autoload("bget_word", "txtutils");
autoload("get_buffer", "txtutils");
autoload("get_table", "csvutils");
autoload("insert_table", "csvutils");
autoload("strtrans_latin1_to_utf8", "utf8helper");
autoload("utf8_to_latin1", "utf8helper");

% Customisation
% -------------

% The default wordlist, given as language pair
custom_variable("Ding_Dictionary", "de-en");

% Translating Direction: 0 to, 1 from, 2 both ["->", "<-", "<->"]
custom_variable("Ding_Direction", 2);

% what to look for  (0,1) == ["substring", "word"]
custom_variable("Ding_Word_Search", 1);

% do a case-sensitive lookup for the word?
custom_variable("Ding_Case_Search", CASE_SEARCH_DEFAULT);

% Initialization
% --------------

% name and namespace
provide("ding");
implements("ding");
private variable mode = "ding";

% private variables
% '''''''''''''''''

private variable Default_Sep = "::";
private variable Dingbuf = "*dictionary lookup*";
private variable Direction_Names = ["->", "<-", "<->"];
private variable help_string =
  "i:Insert r:Replace l:new_Lookup c:Case d:Direction w:Word_search";

% map of known dictionaries
private variable Dictionaries = Assoc_Type[String_Type];

% add a new dictionary to the map of known dictionaries
%
% TODO: Interaktive... ask in minibuffer?
% custom separator-string (Dictionaries as Assoc_Type[List_Type])
%  add_dictionary(key, file, sep=Default_Sep, word_chars=get_word_chars())
%    Dictionaries[key] = {file, sep, word_chars);
static define add_dictionary(key, file)
{
   Dictionaries[key] = file;
}

% Set default (works for Debian and SuSE Linux)
!if (assoc_key_exists(Dictionaries, "de-en"))
{
   foreach $1 (["/usr/share/trans/de-en", "/usr/X11R6/lib/ding/ger-eng.txt"])
   if (file_status($1))
       add_dictionary("de-en", $1);
}

% sanity check, provide an clear error message
!if (assoc_key_exists(Dictionaries, Ding_Dictionary))
  verror("Default dictionary (%s) not defined.", Ding_Dictionary);

% Functions
% ---------

private define ding_status_line()
{
   variable languages, str;
   languages = str_replace_all(Ding_Dictionary, "-",
			       Direction_Names[Ding_Direction]);
   str = sprintf("Look up[%s] %s  (Case %d, Word_Search %d)",
			  languages,
			  get_blocal("generating_function")[1],
			  Ding_Case_Search,
			  Ding_Word_Search);
   set_status_line(str + " (%p)", 0);
}

static define toggle_direction()
{
   Ding_Direction++;
   if (Ding_Direction > 2)
     Ding_Direction = 0;
   ding_status_line();
}

static define toggle_case()
{
   Ding_Case_Search = not(Ding_Case_Search);
   ding_status_line();
}

static define toggle_word_search()
{
   Ding_Word_Search = not(Ding_Word_Search);
   ding_status_line();
}

% % TODO: Interaktive... ask in minibuffer, save where???
% public define ding_add_dictionary() %(key, file, sep=ding->Default_Sep)
% {
%    variable key, file, sep;
%    (key, file, sep) = push_defaults( , , Default_Sep, _NARGS);
%    Wordlists[key] = file+\n+sep;
% }

% Switch focus to side: 0 left, 1 right, 2 toggle
static define switch_sides(side)
{
   variable len = ffind(get_blocal_var("delimiter"));
   % len == 0: right, len >0: left
   !if(len * side)
     bol;
   else
     {
	go_right(len);
	skip_white();
     }
}

% Do we need customizable comment strings?
private define delete_comments()
{
   push_spot();
   while (bol_fsearch("#"))
     call("kill_line");
   pop_spot();
}

% count the number of words in a string
private define string_wc(str)
{
   if(str == NULL)
     return 0;
   % TODO: filter additions like {m} or [Am]
   %       use only part until first '|'
   return length(strtok(str));
}

% format the output buffer
static define format_output()
{
   variable e, str = get_buffer();
   % enable undoing in case something goes wrong:
   try (e)
     {
	variable sep  = get_blocal("delimiter", Default_Sep);
	variable a1, a2, a = get_table(sep, 1); % read results into a 2d-array
	% show(a);
	%  Sort by length of result
	% TODO word-count on first alternative (until first |) in source lang
	% flush(sprintf("sorting %d results", what_line));
	% variable wc = array_map(Int_Type, &strlen, a);
	% % variable wc = array_map(Int_Type, &string_wc, a);
	% a = a[array_sort(wc[*, source_lang]), *];

	% Replace the | (alternative-bars) with newlines
	%  tricky, as we need this independently for the two sides
	sep = sprintf(" %s ", sep);
	% first language
	insert_table(a[*,[0]], "n", sep);
	bob();
	replace("|", "\n|");
	a1 = get_table(sep, 1)[*,0];
	% show("a1", a1);
	% second language
	insert_table(a[*,[1]], "n", sep);
	bob();
	replace("|", "\n");
	a2 = get_table(sep, 1)[*,0];
	% show("a2", a2);
	a = String_Type[length(a1), 2];
	a[*,0] = a1;
	a[*,1] = a2;
	% show("a", a);
	% show("a1,a2", a);
	insert_table(a, "n", sep);
     }
   catch AnyError:
     {
	insert(str);
	% show(e);
	throw e.error, e.message;
     }
}

public  define ding_mode(); % forward definition

public define ding() % ([word], direction=Ding_Direction)
{
   variable word, direction;
   (word, direction) = push_defaults("", Ding_Direction, _NARGS);
   word = strtrim(word);
   if (word == "")
     word = read_mini("word to translate:", bget_word(), "");
   % poor mans utf-8 conversion
   !if (_slang_utf8_ok)
     word = strtrans_latin1_to_utf8(word);

   variable pattern, lookup_cmd = "grep",
     file = extract_element(Dictionaries[Ding_Dictionary], 0, '\n'),
   sep  = extract_element(Dictionaries[Ding_Dictionary],1,'\n');
   if (sep == NULL)
     sep = Default_Sep;
   % Assemble command
   !if (Ding_Case_Search)
     lookup_cmd += " -i ";
   if (Ding_Word_Search) % Whole word search
     lookup_cmd += " -w";
   switch (direction) % Translating direction [0:"->", 1:"<-", 2:"<->"]
     {case 0: pattern = word + ".*" + sep;}
     {case 1: pattern = sep + ".*" + word;}
     {case 2: pattern = word;}

   lookup_cmd = sprintf("%s '%s' %s", lookup_cmd, pattern, file);

   % Prepare the output buffer
   popup_buffer(Dingbuf);
   set_readonly(0);
   erase_buffer();

   % call the grep command
   flush("calling " + lookup_cmd);
   shell_perform_cmd(lookup_cmd, 1);

   % post-process output
   delete_comments();
   trim_buffer();
   define_blocal_var("delimiter", sep);
   define_blocal_var("generating_function", {_function_name, word, direction});
   define_blocal_var("encoding", "utf8");
   !if (_slang_utf8_ok)
     utf8_to_latin1();
   if (bobp and eobp)
     {
	vinsert("No results for '%s'", word);
	% insert("\n\n" + lookup_cmd);
     }
   else
     {
	eob;
	% show(lookup_cmd, what_line, "results");
	if (what_line < 1000) % do not format too long buffers as this takes time
	  format_output();
	bob;
     }
   % find out which language the word is from
   fsearch(word);
   variable source_lang = not(ffind(sep));
   switch_sides(not(source_lang));
   ding_mode();
   fit_window(get_blocal("is_popup", 0));
}

% follow up lookup, normally started with Enter
static define ding_follow()
{
   variable word = get_word(), direction = Ding_Direction;
   % adapt lookup direction
   if(direction < 2)
     direction = not(ffind(get_blocal("delimiter", ' '))); % 0 left, 1 right
   ding(word, direction);
}

static define double_click_hook(line, col, but, shift)
{
   ding_follow();
   return (0);
}

% --- Keybindings

!if (keymap_p(mode))
  copy_keymap(mode, "view");

definekey("ding->toggle_case",        "c",  mode);
definekey("ding->toggle_direction",   "d",  mode);
definekey("ding->ding_follow",        "f",  mode);
definekey("close_and_insert_word",    "i",  mode);
definekey("ding",                     "l",  mode); % Lookup
definekey("close_and_replace_word",   "r",  mode);
definekey("ding",                     "t",  mode); % Translate
definekey("ding->toggle_word_search", "w",  mode);
definekey("ding->switch_sides(2)",    "^I", mode); % TAB
definekey("ding->ding_follow",        "^M", mode); % Enter

% TODO (Alt)-Left/Right - History (comes with the generalized navigage mode.)

% --- the mode menu
private define ding_menu (menu)
{
   menu_append_item (menu, "New &Lookup", "ding");
   menu_append_item (menu, "&Insert", "close_and_insert_word");
   menu_append_item (menu, "&Replace", "close_and_replace_word");
   menu_append_item (menu, "Toggle &Case", "ding->toggle_case");
   menu_append_item (menu, "Toggle &Direction", "ding->toggle_direction");
   menu_append_item (menu, "Toggle &Word Search", "ding->toggle_word_search");
   menu_append_item (menu, "&Quit", "close_buffer");
% TODO: popup_menu "Set &Wordlist", list assoc_get_keys(Dictionaries)
% 		   		    set Dictionary
% 	better feedback in toggle Case/Direction
}

% --- Create and initialize the syntax tables.
create_syntax_table (mode);
define_syntax("::", "", '%', mode);   % Comments (2nd language as comment)
% define_syntax("::", '>', mode);      % keyword
define_syntax('|', '#', mode);      % examples
% define_syntax("|", '+', mode);      % examples


set_syntax_flags (mode, 0);

public  define ding_mode()
{
   set_mode(mode, 0);
%  use_syntax_table (mode);
   set_readonly(1);
   set_buffer_modified_flag(0);
   use_keymap (mode);
   use_syntax_table(mode);
   mode_set_mode_info (mode, "init_mode_menu", &ding_menu);
   set_buffer_hook ("mouse_2click", &ding->double_click_hook);
   ding_status_line();
   run_mode_hooks(mode + "_mode_hook");
   message(help_string);
}

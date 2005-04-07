% Ding dictionary lookup
% inspired by the tcl/tk program "ding" for german-english translation
% Günter Milde <g.milde web.de>
% Version    0.8   first draft
% Version    1     Adapted to the new format of the ding dictionary
% 2005-04-07 1.1   bugfix: added missing autoloads
% 
% REQUIREMENTS
% * A bilingual wordlist in ASCII format (e.g. the one that comes
%   with ding http://www.tu-chemnitz.de/~fri/ding/ (German-English)
%   or the ones from the "magic dic" http://magic-dic.homeunix.net/ )
% * the grep command (with support for the -w argument, e.g. GNU grep)
%
% USAGE
% Place "ding.sl" in the jed_library_path
% 
% Add autoload("ding", "ding") to your .jedrc
%
% Add your dictionaries 
% Proposed scheme for keys is lang1-lang2 with abbreviations from 'locale' 
% settings, say "de-en" == German::English
% e.g.
% define ding_setup_hook()
% { 
%   ding_add_dictionary("de-en", "/usr/share/trans/de-en"); % for Debian
% % ding_add_dictionary("de-en", "/usr/X11R6/lib/ding/ger-eng.txt"); % for SuSE
%   ding_add_dictionary("se-de", "~/dictionaries/swedish-german.txt");
% }  
% 
% Optionally change custom variables

 

% debug information, comment these out when ready
_debug_info = 1;

% give it a name
static variable mode = "ding";

if (_featurep(mode))
  use_namespace(mode);
else
  implements(mode);
provide(mode);

% --- requirements ---

require("keydefs"); % symbolic names for keys
% non-standard extensions
require("view"); %  readonly-keymap
autoload("push_defaults", "sl_utils");
autoload("get_blocal", "sl_utils");
autoload("close_buffer", "bufutils");
autoload("popup_buffer", "bufutils");
autoload("close_and_insert_word", "bufutils");
autoload("close_and_replace_word", "bufutils");
autoload("get_word", "txtutils");
autoload("bget_word", "txtutils");
autoload("array", "datutils");
autoload("get_table", "csvutils");
autoload("insert_table", "csvutils");

% --- custom variables

% The default wordlist, given as language pair
custom_variable("Ding_Dictionary", "de-en");
% Translating Direction: 0 to, 1 from, 2 both ["->", "<-", "<->"]
custom_variable("Ding_Direction", 2);
% what to look for  (0,1) == ["substring", "word"]
custom_variable("Ding_Word_Search", 1);

% --- public variables

% the list of known dictionaries, define here
% if not done in the .jedrc. this default works for Debian and SuSE Linux
!if (is_defined("Wordlists"))
{
   public variable Wordlists = Assoc_Type[String_Type];
   foreach(["/usr/share/trans/de-en", "/usr/X11R6/lib/ding/ger-eng.txt"])
     if (file_status(dup))
       {
	  Wordlists["de-en"] = ();
	  break;
       }
}

% or with custom separator-string given after a newline-char
%   Wordlists["de-en"] = ["/usr/X11R6/lib/ding/ger-eng.txt\n::"];
% TODO: Wordlists[key] = (file\n sep="::"\n word_chars=get_word_chars);

% --- static variables -------------------------------------------

static variable Default_Sep = "::";
static variable Dingbuf = "*dictionary lookup*";
static variable Direction_Names = ["->", "<-", "<->"];
static variable help_string =
  "i:Insert r:Replace l:new_Lookup c:Case d:Direction w:Word_search";

% --- Functions

static define ding_status_line()
{
   variable languages, str;
   languages = str_replace_all(Ding_Dictionary, "-", 
			       Direction_Names[Ding_Direction]);
   str = sprintf("Translate[%s] %s  (Case %d, Word_Search %d)",
			  languages,
			  @get_blocal("generating_function")[1],
			  CASE_SEARCH,
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
   CASE_SEARCH = not(CASE_SEARCH);
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
     go_right(len+2);
}

% Do we need customizable comment strings?
static define delete_comments()
{
   push_spot();
   while (bol_fsearch("#"))
     call("kill_line");
   pop_spot();
}

% % transform word to search for whole words only
% % tricky, because regexp-search doenot count Umlauts as word_chars
% static define whole_word(word)
% {
%    variable wc = get_blocal("Word_Chars", get_word_chars());
%    return sprintf("\\(^\\|[^%s]\\)%s\\($\\|[^%s]\\)", wc, word, wc);
%    % with egrep
%    % return sprintf("(^|[^%s])%s($|[^%s])", wc, word, wc);
% }

% count the number of words in a string
static define string_wc(str)
{
   if(str == NULL)
     return 0;
   % TODO: filter additions like {m} or [Am]
   %       use only part until first '|'
   return length(strtok(str));
}

define ding_mode(); % dummy definition

public define ding() % ([word], direction=Ding_Direction)
{
   variable word, direction; 
   (word, direction) = push_defaults( , Ding_Direction, _NARGS);
   if (word == NULL)
     word = read_mini("word to translate:", bget_word(), "");

   variable pattern, lookup_cmd = "grep",
     file = extract_element(Wordlists[Ding_Dictionary], 0, '\n'),
   sep  = extract_element(Wordlists[Ding_Dictionary],1,'\n');
   
   if (sep == NULL)
     sep = Default_Sep;
   % Build up the command
   !if (CASE_SEARCH)
     lookup_cmd += " -i ";
   if (Ding_Word_Search) % Whole word search
     lookup_cmd = "grep -w";
   switch (direction) % Translating direction [0:"->", 1:"<-", 2:"<->"]
     {case 0: pattern = word + ".*" + sep;}
     {case 1: pattern = sep + ".*" + word;}
     {case 2: pattern = word;}

   lookup_cmd = strjoin([lookup_cmd, "\""+pattern+"\"", file], " ");

   % Prepare the output buffer
   popup_buffer(Dingbuf);
   set_readonly(0);
   erase_buffer();
   % call the grep command
   flush("calling " + lookup_cmd);
   shell_perform_cmd(lookup_cmd, 1);
   delete_comments();
   % find out which language the word is from
   fsearch(word);
   variable source_lang = not(ffind(sep));
   define_blocal_var("delimiter", sep);
   define_blocal_var("generating_function", array(&ding, word, direction));
   
   % sort results
   eob;
   if (bobp and eobp)
     {
	insert("No results for " + word);
	% insert("\n\n" + lookup_cmd);
     }
   else if (orelse {what_line < 1000}
       {get_y_or_n(sprintf("Format %d results (may take time)", what_line))})
     {
	% Format the lookup result
	% show(lookup_cmd, what_line, "results");
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
	% first language
	insert_table(a[*,[0]], NULL, " "+sep+" ");
	bob();
	replace("|", "\n");
	a1 = get_table(sep, 1)[*,0];
	% show("a1", a1);
	% second language
	insert_table(a[*,[1]], NULL, " "+sep+" ");
	bob();
	replace("|", "\n");
	a2 = get_table(sep, 1)[*,0];
	% show("a2", a2);
	a = String_Type[length(a1), 2];
	a[*,0] = a1;
	a[*,1] = a2;
	% show("a", a);
	% show("a1,a2", a);
	insert_table(a, NULL, " "+sep+" ");
     }
   bob;
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

% --- the mode dependend menu
static define ding_menu (menu)
{
   menu_append_item (menu, "New &Lookup", "ding");
   menu_append_item (menu, "&Insert", "close_and_insert_word");
   menu_append_item (menu, "&Replace", "close_and_replace_word");
   menu_append_item (menu, "Toggle &Case", "ding->toggle_case");
   menu_append_item (menu, "Toggle &Direction", "ding->toggle_direction");
   menu_append_item (menu, "Toggle &Word Search", "ding->toggle_word_search");
   menu_append_item (menu, "&Quit", "close_buffer");
% TODO: popup_menu "Set &Wordlist", list assoc_get_keys(Wordlists)
% 		   		    set Dictionary
% 	better feedback in toggle Case/Direction
}

% --- Create and initialize the syntax tables.
create_syntax_table (mode);
define_syntax ("::", "", '%', mode);   % Comments (2nd language as comment)
% define_syntax ("::", '>', mode);      % keyword

set_syntax_flags (mode, 0);

define ding_mode()
{
   set_mode(mode, 0);
%   use_syntax_table (mode);
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


% A "popup_buffer" with a table of characters
%
% Copyright (c) 2005 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% with additions by Dino Leonardo Sangoi.
%
% Version     1.0 first public version
%  	      1.1 standardization: abandonment of helper-function custom
% 2003-04-16  2.0 use readonly-map from bufutils (some new bindings)
%                 code cleanup
% 2003-03-07  2.1 ch_table calls ch_table_mode_hook instead of ct_mode_hook
% 2004-11-27  2.2 new format of the INITIALIZATION block allows 
% 	          auto-initialisation with make-ini >= 2.2
% 2005-11-07  2.3 changed _implements() to implements()
% 2006-01-10  2.3.1 minor code cleanup
% 2006-06-29  2.3.2 bugfix in ch_table: set_readonly(0) before erase_buffer()
% 2006-10-05  2.3.3 bugfix in ct_insert_and_close(), return to calling buf
% 2007-05-31  2.3.4 bugfix in ct_update: did mark too much if at eol,
%                   disable dfa syntax highlighting in UTF8 mode to make
%                   ch_table.sl UTF8 safe.
%                   documentation for public functions
% 2007-10-18  2.3.5 cosmetics (require() instead of autoloads, push_default())
% 2007-10-23  2.3.6 do not cache the dfa highlight table
% 2007-12-20  2.3.7 implement JöÃ¶rg Sommer's fix for DFA highlight under UTF-8
% 2008-01-21  2.4   variable upper limit, as unicode has more than 255 chars,
% 	      	    ch_table_unicode_block(), 
% 	      	    new menu name Edit>Char Table, 
% 	      	    menu popup with several "blocks" under utf8
% 	      	    do not mark the current char as region
% 	      	    mode menu
% 	      	    describe character (using unicode's NamesList.txt)
%
% TODO: * Menu binding for describe_character (which?)
%       * let pg_up pg_down "turn the page" to the next table
% 
%  
% Functions and Functionality
%
%   ch_table()        characters 000...255
%   ch_table(min)     characters min...255
%   ch_table(min,max) characters min...max
%   special_chars()   characters 160...255
%
%   - Arrow keys     move by collumn
%   - <Enter> 	     copy the character to the calling buffer and close
%   - Mouse click    goto character
%   - Double-click   goto character, copy to calling buffer and close
%   - q   	     close
%
% USAGE:
% put in the jed_library_path and make available e.g. by a keybinding or
% via the following menu entry (make-ini.sl >= 2.2 will do this for you)
 
#<INITIALIZATION>
autoload("ch_table", "ch_table.sl");
autoload("special_chars", "ch_table.sl");
autoload("ch_table->menu_callback", "ch_table.sl");
add_completion("special_chars");

static define ct_load_popup_hook(menubar)
{
   variable pos = "&Key Macros", menu = "Global.&Edit", 
      name = "Char &Table";
   menu_insert_item(pos, menu, name, "special_chars");
}

append_to_hook("load_popup_hooks", &ct_load_popup_hook);
#</INITIALIZATION>

% debug information, uncomment to locate errors
% _debug_info = 1;

% Requirements
% ------------

% modes from http://jedmodes.sf.net
require("view");      % readonly-keymap
require("bufutils");  % pop up buffer 
require("sl_utils");  % small helpers

% Name
% ----
provide("ch_table");

try 
   implements("ch_table");
catch NamespaceError:
   use_namespace("ch_table");
   
private variable mode = "ch_table";

% Customisation
% -------------

custom_variable("ChartableStartChar", 0);
custom_variable("ChartableNumBase", 10);
custom_variable("ChartableCharsPerLine", ChartableNumBase);
custom_variable("ChartableTabSpacing", 4);

custom_variable("Chartable_NamesList", 
		path_concat(path_dirname(__FILE__), "NamesList.txt"));



% --- global variables -------------------------------------------

% diplay options
private variable StartChar = ChartableStartChar;
private variable EndChar = 255;
private variable NumBase = ChartableNumBase;
private variable CharsPerLine = ChartableCharsPerLine;

% quasi constants
private variable Digits = "0123456789abcdef";

static variable UnicodeBlocks = Assoc_Type[Array_Type];
% TODO: initialize from Blocks.txt?
UnicodeBlocks["Basic Latin"] =                 [0x0000, 0x007F]; 
UnicodeBlocks["Latin-1 Supplement"] = 	       [0x0080, 0x00FF]; 
UnicodeBlocks["Latin Extended-A"] = 	       [0x0100, 0x017F]; 
UnicodeBlocks["Latin Extended-B"] = 	       [0x0180, 0x024F]; 
UnicodeBlocks["IPA Extensions"] = 	       [0x0250, 0x02AF]; 
UnicodeBlocks["Greek and Coptic"] = 	       [0x0370, 0x03FF]; 
UnicodeBlocks["Cyrillic"] = 		       [0x0400, 0x04FF]; 
UnicodeBlocks["Hebrew"] = 		       [0x0590, 0x05FF]; 
UnicodeBlocks["General Punctuation"] = 	       [0x2000, 0x206F]; 
UnicodeBlocks["Superscripts and Subscripts"] = [0x2070, 0x209F]; 
UnicodeBlocks["Currency Symbols"] = 	       [0x20A0, 0x20CF]; 
UnicodeBlocks["Arrows"] = 		       [0x2190, 0x21FF]; 
UnicodeBlocks["Mathematical Operators"] =      [0x2200, 0x22FF]; 
UnicodeBlocks["Miscellaneous Technical"] =     [0x2300, 0x23FF]; 
UnicodeBlocks["Box Drawing"] = 		       [0x2500, 0x257F]; 
UnicodeBlocks["Block Elements"] = 	       [0x2580, 0x259F]; 
UnicodeBlocks["Geometric Shapes"] = 	       [0x25A0, 0x25FF]; 
UnicodeBlocks["Miscellaneous Symbols"] =       [0x2600, 0x26FF]; 
UnicodeBlocks["Dingbats"] = 		       [0x2700, 0x27BF]; 

		 
% --- Helper functions --------------------------------------------

% Functions to revert a positive  integer to a string representation
% and vice versa

static define int2string(i, base)
{
   variable j, s = "";
   variable digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

   while (i) {
      j = i mod base;
      s = char(digits[j]) + s;
      i = (i - j) / base;
   }
   if (s == "")
     s = "0";
   return s;
}

static define string2int(s, base)
{
   variable v, r = 0, i = 0, c;

   while (s[i] > ' ') {
      c = toupper(s[i]);
      if (c >= 'A')
	v = c - 'A' + 10;
      else v = c - '0';
      if ((v < 0) or (v >= base))
	error("Invalid input (" + s + ")");
      r = r * base + v;
      i++;
   }
   return r;
}

% return current character (translating TAB, NL and ESC)
private define ct_what_char()
{
   if (looking_at("TAB"))
      return '\t';
   if (looking_at("NL"))
      return '\n'; 
   if (looking_at("ESC"))
      return '\e'; 
   return what_char();
}

static define ct_describe_character(ch)
{
   variable ch_nr = sprintf("%04X", ch);
   variable ch_nr1 = sprintf("%04X", ch+1);
   
   if (-1 == insert_file_region(Chartable_NamesList, ch_nr, ch_nr1)) 
      vinsert("No description. Check for %s\n", Chartable_NamesList);
   call("backward_delete_char"); % del last newline
   while (bol, looking_at_char('@')) {
      delete_line();
      call("backward_delete_char"); % del last newline
   }
}

public define describe_character() % (ch=what_char)
{
   variable ch = push_defaults(what_char(), _NARGS);
   
   popup_buffer("*character description*");
   set_readonly(0);  
   erase_buffer();
   vinsert("Character '%c' (%d, 0x%X)\n", ch, ch, ch);
   ct_describe_character(ch);
   bob();
   fit_window(get_blocal("is_popup", 0));
   call_function("view_mode");
}

% give the ASCII-number of current char in the status line
static define ct_status_line(ch)
{
   variable fmt = " Character Table: '%c' (%d, 0x%X) ---- press '?' for help ";
   set_status_line(sprintf(fmt, ch, ch, ch), 0);
}

static define ct_update()
{
   % ensure point is in char table
   if (what_line() < 3)
     {
	error("Top Of Buffer");
	goto_line(3);
	() = fsearch("\t");
	skip_chars("\t");
     }
   push_spot();
   !if (bol_fsearch_char('-')) {
      pop_spot();
      () = bol_bsearch_char('-');
   }
   else
      pop_spot();
   % get current char
   bskip_chars("^\t");
   variable ch = ct_what_char();
   
   % Update description
   push_spot();
   set_readonly(0);
   %  delete description
   eob();
   push_mark();
   () = bol_bsearch_char('-');
   go_down_1();
   del_region();
   vinsert("'%c' ", ch);
   ct_describe_character(ch);
   set_buffer_modified_flag(0);
   set_readonly(1);
   pop_spot();
   fit_window(get_blocal("is_popup", 0));

   % update status line
   ct_status_line(ch);
   % write again to minibuffer (as messages don't persist)
      % if resources are a topic, we could compute the message in
      % ch_table and store to a private variable GotoMessage
   vmessage("Goto char (%s ... %s, base: %d): ___",
        int2string(StartChar, NumBase), int2string(EndChar, NumBase),  NumBase);
}

% Move only in the ch_table, skipping the tabs

static define ct_up()
{
   if (what_line < 4)
     error("Top Of Buffer");
   call("previous_line_cmd");
   ct_update;
}

static define ct_down()
{
   call("next_line_cmd");
   ct_update();
}

static define ct_right()
{
   () = fsearch("\t");
   skip_chars("\t");
   ct_update();
}

static define ct_left()
{
   bsearch("\t");
   % bskip_chars("^\t");
   % call("previous_char_cmd");
   bskip_chars("^\t");
   if(bolp)
     call("previous_char_cmd");
   ct_update;
}

static define ct_page_up()
{
   call("page_up"); 
   ct_update();
}

static define ct_bob()   
{ 
   goto_line(3); 
   ct_right;
}

   
% insert current char into calling buffer
static define ct_insert()
{
   variable ch = ct_what_char();
   pop2buf(get_blocal_var("calling_buf"));
   insert_char(ch);
}

% insert current char and return to char table
static define ct_insert_and_return()
{
   variable buf = whatbuf();
   ct_insert();
   pop2buf(buf);
}

static define ct_insert_and_close()
{
   ct_insert_and_return();
   close_buffer();
}

static define ct_mouse_up_hook(line, col, but, shift)
{
   % if (but == 1)
   % if (what_line < 3)
   %   ct_bob();
   % ct_right;
   % ct_left;
   ct_update; %  error if click in first (number) collumn
   return (1);
}

static define ct_mouse_2click_hook(line, col, but, shift)
{
   ct_insert_and_close();
   return (0);
}

% goto character by input of ASCII-Nr.
static define ct_goto_char()
{
   variable goto_message =  sprintf("Goto char (%s ... %s, base: %d): ",
        int2string(StartChar, NumBase), int2string(EndChar, NumBase),  NumBase);
   variable GotoCharStr = read_mini(goto_message, "", char(LAST_CHAR));

   variable GotoChar = string2int(GotoCharStr, NumBase);

   if( (GotoChar<StartChar) or (GotoChar>EndChar) )
     verror("%s not in range (%s ... %s)",
	        GotoCharStr,
	        int2string(StartChar, NumBase) , int2string(EndChar, NumBase));
   ct_bob;
   loop(GotoChar - (StartChar - (StartChar mod CharsPerLine)))
     ct_right;
   % give feedback
   vmessage("Goto char: %s -> %c", GotoCharStr, GotoChar);
}

% insert the table into the buffer and fit window size
static define insert_ch_table()
{
   variable i, j;
   TAB = ChartableTabSpacing;    % Set TAB for buffer
   % j = lengt of number on first column
   j = strlen(int2string(EndChar+1-CharsPerLine, NumBase))+1;
   if (j < TAB)
      j = TAB;
   % heading
   vinsert("[% *d]", j-2, NumBase);
   for (i=0; i<CharsPerLine; i++)
      insert("\t" + int2string(i, NumBase));
   variable col = what_column();
   newline();
   loop(col)
      insert("-");
   % now construct/insert the table
   for (i = StartChar - (StartChar mod CharsPerLine) ; i<=EndChar; i++)
     {
	if ((i) mod CharsPerLine == 0)
	    vinsert("\n% *s", j, int2string(i, NumBase)); % first column with number
	insert_char('\t');
	% insert characters, symbolic notation for TAB, Newline and Escape
	switch (i)
	  { i < StartChar: ;}
	  { case '\t': insert("TAB");}
	  { case '\n': insert("NL");}
	  { case '\e': insert("ESC");}
	  { insert_char(i);}
     }
   % separator
   newline();
   loop(col)
      insert("-");
   newline();
   % fit_window(get_blocal("is_popup", 0));
   ct_bob;
   ct_update();
}

% set private variables and define keys to use specified number base
static define use_base(numbase)
{
   variable i;
   % (un)bind keys
   for (i=numbase; i<=NumBase; i++)
	undefinekey(char(Digits[i]), mode);
   for (i=0; i<numbase; i++)
	definekey("ch_table->ct_goto_char", char(Digits[i]), mode);
   % adapt CharsPerLine, if it matched NumBase
   if (CharsPerLine == NumBase)
     CharsPerLine = numbase;
   % set private variable
   NumBase = numbase;
}

% change the number base
static define ct_change_base()
{
   variable num_base = push_defaults( ,_NARGS); % optional argument
   if (num_base == NULL)
     num_base = integer(read_mini("New number base (2..16):", "", ""));
   use_base(num_base);
   set_readonly(0);
   erase_buffer();
   insert_ch_table();
   set_readonly(1);
}

% Mode menu
% ---------

% menu popup for unicode blocks
static define menu_callback(menu)
{
   variable block, blocks = assoc_get_keys(UnicodeBlocks);
   variable I = array_sort(blocks);
   
   foreach block (blocks[I]) 
      menu_append_item(menu, "&"+block, 
		       sprintf("ch_table_unicode_block(\"%s\")", block));
   menu_append_item(menu, "&Custom", "ch_table_unicode_block(\"\")");
}

private define ch_table_menu(menu)
{
   menu_append_popup(menu, "&Number base");
   variable popup = menu + ".&Number base";
   menu_append_item(popup, "&Binary",      &ct_change_base, 2);
   menu_append_item(popup, "&Octal",       &ct_change_base, 8);
   menu_append_item(popup, "&Decimal",     &ct_change_base, 10);
   menu_append_item(popup, "&Hexadecimal", &ct_change_base, 16);
   menu_append_item(popup, "&Custom",      "ch_table->ct_change_base");
   % select unicode block
   if (_slang_utf8_ok) {
      menu_append_popup(menu, "&Select Block");
      menu_set_select_popup_callback(menu+".&Select Block", &menu_callback);
   }
   % menu_append_item(menu, "&Describe character", "describe_character");
   menu_append_item(menu, "&Insert", "ch_table->ct_insert");
   menu_append_item(menu, "Insert and &return", "ch_table->ct_insert_and_return");
   menu_append_item(menu, "Insert and &close", "ch_table->ct_insert_and_close");
   menu_append_item(menu, "&Quit", "close_buffer");
}


% colorize numbers

create_syntax_table(mode);
define_syntax("0-9", '0', mode);
set_syntax_flags(mode, 0);

#ifdef HAS_DFA_SYNTAX
% numbers in first column
dfa_define_highlight_rule("^ *[0-9A-Z]+\t", "number", mode);
% header line
dfa_define_highlight_rule("^\[.*$"R, "number", mode);
% separator
dfa_define_highlight_rule("^----+", "number", mode);
% render non-ASCII chars as normal to fix a bug with high-bit chars in UTF-8
dfa_define_highlight_rule("[^ -~]+", "normal", mode);

dfa_build_highlight_table(mode);
enable_dfa_syntax_for_mode(mode);
#endif

% --- Keybindings
require("keydefs"); % symbolic constants for many function and arrow keys

!if (keymap_p(mode)) 
  copy_keymap(mode, "view");

% numerical input for goto_char is dynamically defined by function ct_use_base
definekey("ch_table->ct_up",              Key_Up,    mode);
definekey("ch_table->ct_down",            Key_Down,  mode);
definekey("ch_table->ct_right",           Key_Right, mode);
definekey("ch_table->ct_left",            Key_Left,  mode);
definekey("bol; ch_table->ct_right;",     Key_Home,  mode);
definekey("eol; ch_table->ct_update;",    Key_End,   mode);
definekey("ch_table->ct_page_up",   	  Key_PgUp,  mode);
definekey("call(\"page_down\"); ch_table->ct_update;", Key_PgDn,  mode);
definekey("ch_table->ct_change_base()",   "N",       mode);  % generic case
definekey("ch_table->ct_change_base(2)",  "B",       mode);
definekey("ch_table->ct_change_base(8)",  "O",       mode);
definekey("ch_table->ct_change_base(10)", "D",       mode);
definekey("ch_table->ct_change_base(16)", "H",       mode);
definekey("ch_table->ct_insert_and_close", "^M",     mode);  % Return
definekey("ch_table->ct_describe_character", "d",    mode);
definekey("ch_table->ct_insert", 	     "i",    mode);
definekey("ch_table->ct_insert_and_return",  "r",    mode);

set_help_message(
   "<RET>:Insert q:Quit, B:Binary, O:Octal, D:Decimal, H:hex N:Number_Base",
		 mode);

% main function  
% ------------------------------------------------------

%!%+
%\function{ch_table}
%\synopsis{}
%\usage{ch_tablech_table(min=ChartableStartChar, max=)}
%\description
% Display characters in the range \var{min} ... \var{max} 
% in a table with indizes indicating the "char-value".
%\seealso{special_chars, digraph_cmd}
%!%-
public define ch_table() % (min = ChartableStartChar, max=255)
{
   % (re) set static variables
   variable min, max;
   (min, max) = push_defaults(ChartableStartChar, 255, _NARGS); 
   StartChar = min;
   EndChar = max;
   use_base(NumBase);
   % Pop up ch_table in upper part (preferably)
   if (nwindows() - MINIBUFFER_ACTIVE == 1)
      % Scroll current line to lower half of window
      recenter (3 * window_info('r') / 4);
   % else if (window_info('t') <= 2) {
   %    % make sure we are in lower window
   %    variable buf = whatbuf();
   %    otherwindow();
   %    sw2buf(buf);
   % }
   update_sans_update_hook(1);
   popup_buffer("*ch_table*");
   set_readonly(0);
   erase_buffer();
   insert_ch_table();
   set_readonly(1);
   set_mode(mode, 0);
   use_keymap(mode);
   use_syntax_table(mode);
   mode_set_mode_info(mode, "init_mode_menu", &ch_table_menu);
   set_buffer_hook("mouse_up", &ct_mouse_up_hook);
   set_buffer_hook("mouse_2click", &ct_mouse_2click_hook);
   run_mode_hooks(mode + "_mode_hook");
}

%!%+
%\function{special_chars}
%\synopsis{Open a table of special characters for insertion}
%\usage{special_chars()}
%\description
% Display special characters of the current font (characters 160...255 in
% 1-byte encodings) in a table with indizes indicating the "char-value".
% 
% Keybindings:
%
%  Arrow keys     move by collumn and mark the character
%  [Enter] 	  copy the character to the calling buffer and close
%  Mouse click    goto character and mark
%  Double-click   goto character, copy to calling buffer and close
%  q   	     	  close
%\seealso{ch_table, digraph_cmd}
%!%-
public define special_chars()
{
   ch_table(160);
}


% Unicode blocks (see Blocks.txt)
public define ch_table_unicode_block(name)
{
   variable min, max;
   try {
      min = UnicodeBlocks[name][0];
      max = UnicodeBlocks[name][1];
   }
   catch AnyError: {
      min = integer(read_mini("List chars from Nr.", "", ""));
      max = integer(read_mini("List chars to Nr.", "", ""));
   }
   ch_table(min, max);
}

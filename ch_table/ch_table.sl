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
% 2007-12-20  2.3.7 implement J�örg Sommer's fix for DFA highlight under UTF-8
% 2008-01-21  2.4   variable upper limit, as unicode has more than 255 chars,
% 	      	    ch_table_unicode_block(),
% 	      	    new menu name Edit>Char Table,
% 	      	    menu popup with several "blocks" under UTF8,
% 	      	    do not mark the current char as region,
% 	      	    mode menu,
% 	      	    describe character (using unicode's NamesList.txt).
% 2008-04-02  2.4.1 bugfix in ct_update(): skip lines 1...3,
% 	            Edit>Char_Tables menu popup for UTF8-enabled Jed,
% 	            re-order mode-menu,
% 	            only fit ch-table window if too small (avoids flicker),
% 	            Add "Musical Symbols" block.
% 	            Menu binding for describe_character (under Help)
% 	            ct_goto_char(): choose from all available chars,
% 	            		   switching unicode table if needed.
% 	            "active links" (i.e. goto given char if click on number)
%
% TODO: * search for character or table by name
%       * apropos for character names and table names
%       * make combining characters visible (tricky)
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
autoload("describe_character", "ch_table.sl");
add_completion("special_chars");

static define ct_load_popup_hook(menubar)
{
   variable pos = "&Key Macros", menu = "Global.&Edit";
   if (_slang_utf8_ok) {
      menu_insert_popup(pos, menu, "Char &Tables");
      menu_set_select_popup_callback(menu+".Char &Tables", &ch_table->menu_callback);
   }
   else
      menu_insert_item(pos, menu, "Char &Table", "special_chars");

   menu_insert_item("&Describe Key Bindings", "Global.&Help",
		    "Describe &Character", "describe_character");
}

append_to_hook("load_popup_hooks", &ct_load_popup_hook);
#</INITIALIZATION>

% Requirements
% ------------

% modes from http://jedmodes.sf.net
% require("view");      % readonly-keymap  No longer used
require("bufutils");  % pop up buffer, rebind, close_buffer...
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
custom_variable("ChartableTabSpacing", 5);

custom_variable("Chartable_NamesList_File",
		path_concat(path_dirname(__FILE__), "NamesList.txt"));

custom_variable("Chartable_Blocks_File",
		path_concat(path_dirname(__FILE__), "Blocks.txt"));

% Unicode blocks listed in the Edit>Char_Tables popup
custom_variable("Chartable_Tables", [
					    "&Basic Latin",
					    "Latin-&1 Supplement",
					    "Latin Extended-A",
					    "Latin Extended-B",
					    "&IPA Extensions",
					    "&Greek and Coptic",
					    "C&yrillic",
					    "&Hebrew",
					    "General &Punctuation",
					    "&Superscripts and Subscripts",
					    "&Currency Symbols",
					    "&Arrows",
					    "&Mathematical Operators",
					    "Miscellaneous &Technical",
					    "Box &Drawing",
					    "&Block Elements",
					    "&Geometric Shapes",
					    "Miscellaneous &Symbols",
					    "Dingbats",
					    "&Musical Symbols"
					   ]);


% Global variables 
% ----------------

% diplay options
private variable StartChar = ChartableStartChar;
private variable EndChar = 255;
private variable BlockNr = 1;
private variable NumBase = ChartableNumBase;
private variable CharsPerLine = ChartableCharsPerLine;

% quasi constants
private variable Digits = "0123456789abcdef";

% List of unicode blocks 
private variable UnicodeBlocks; % defined later via parse_unicode_block_file()

% Functions
% =========

static define ct_unicode_block(); % forward definition

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

% Character description
% ---------------------

% return current character (translating TAB, NL and ESC)
private define ct_what_char()
{
   if (looking_at("\t"R))
      return '\t';
   if (looking_at("\n"R))
      return '\n'; 
   if (looking_at("\e"R))
      return '\e'; 
   return what_char();
}

% insert character description into current buffer
static define ct_describe_character(ch)
{
   variable ch_nr = sprintf("%04X", ch);
   variable ch_nr1 = sprintf("%04X", ch+1);
   
   if (-1 == insert_file_region(Chartable_NamesList_File, ch_nr, ch_nr1)) 
      vinsert("No description. Check for %s\n", Chartable_NamesList_File);
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
   % "active links"
   set_buffer_hook("mouse_up", "ch_table->ct_active_link_hook");
}

static define ct_update()
{
   % Ensure point is in char table
   %  normalize position
   bskip_chars("^\t");
   %  top
   if (what_line() < 3) 
      goto_line(3);
   %  left
   if (bolp) 
      () = fsearch("\t");
   % Workaround, as skip_chars("\t") skips lone combining chars too
   while (looking_at_char('\t')) {
      go_right_1(); % go_right skips combining chars!
      bskip_chars("^\t");
   }
   %  bottom
   push_spot();
   variable too_low = not(bol_fsearch_char('-'));
   pop_spot();
   if (too_low) {
      () = bol_bsearch_char('-');
      bskip_chars("^\t");
   }
   
   % Get current char
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
   %  write new one
   vinsert("'%c' ", ch);
   ct_describe_character(ch);
   if (what_line() > window_info('r'))
      fit_window(get_blocal("is_popup", 0));
   set_buffer_modified_flag(0);
   set_readonly(1);
   pop_spot();

   % give the Unicode-number of current char in the status line
   variable name = UnicodeBlocks[BlockNr][2];
   variable fmt = " Block %d: %s '%c' (%d, 0x%X)";
   set_status_line(sprintf(fmt, BlockNr, name, ch, ch, ch), 0);
   
   % write again to minibuffer (as messages don't persist)
   vmessage("Goto char (0 ... %s, base: %d): ",
	    int2string(UnicodeBlocks[-1][1], NumBase),  NumBase);
}

% Movement functions
% ------------------

% Move only in the ch_table, skipping the tabs

static define ct_up()
{
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
   go_right_1();
   % skip_chars("\t");
   ct_update();
}

static define ct_left()
{
   () = bsearch("\t");
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

static define ct_page_down()
{
   call("page_down");
   ct_update();
}

static define ct_bob()   
{
   bob();
   ct_update();
}

% parse Unicode Block description file
static define parse_unicode_block_file(file)
{
   % read file into array of lines
   variable line, lines = arrayread_file(file);
   % show(lines);
   
   % parse the lines 
   variable block, blocks = {};
   variable n, beg, end, name;
   foreach line (lines) {
      n = sscanf (line, "%x..%x; %[-a-zA-Z0-9 ]", &beg, &end, &name);
      % vshow("%s, [%X, %X]", name, beg, end);
      if (n == 3) 
	 list_append(blocks, {beg, end, name});
   }
   return blocks;
}


if (_slang_utf8_ok) 
   UnicodeBlocks = parse_unicode_block_file(Chartable_Blocks_File);
else
   UnicodeBlocks = [{0, 127, "Basic Latin"},
		    {128, 255, "High Bit Characters"}];
% show(UnicodeBlocks);

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

% goto character by input of Unicode-Nr.
static define ct_goto_char() % ([ch])
{
   variable max_ch = UnicodeBlocks[-1][1];
   !if (_NARGS) {
      variable msg = sprintf("Goto char (0 ... %s, base: %d): ",
			     int2string(max_ch, NumBase),  NumBase);
      variable str = read_mini(msg, "", char(LAST_CHAR));
      string2int(str, NumBase); % push on stack
   }
   variable ch = (); % get from stack

   if( (ch < 0) or (ch > max_ch) ) 
     verror("%s not in range (0 ... %s)",
	    int2string(ch, NumBase) , 
	    int2string(max_ch, NumBase));

   % switch unicode block if ch is outside of currently displayed table
   if( (ch < StartChar) or (ch > EndChar) ) {
      variable n;
      for (n=0; n<length(UnicodeBlocks); n++) {
      	 if (UnicodeBlocks[n][0] > ch)
      	    break;
      }
      ct_unicode_block(n-1);
   }
   else
      ct_bob;
   loop(ch - StartChar) {
      skip_chars("^\t");
      go_right_1(); % go_right skips combining chars!
      bskip_chars("^\t");
   }
   ct_update();
}

% insert the table into the buffer and fit window size
static define insert_ch_table()
{
   variable i, j;
   % Set TAB for buffer
   TAB = ChartableTabSpacing;    
   while (TAB * CharsPerLine > WRAP)
      TAB--;
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
	  { case '\t': insert("\t"R);}
	  { case '\n': insert("\n"R);}
	  { case '\e': insert("\e"R);}
	  { insert_char(i);}
     }
   % separator
   newline();
   loop(col)
      insert("-");
   newline();
   fit_window(get_blocal("is_popup", 0)); % (eventually reducing size)
   ct_bob();
}


% Number base
% -----------

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
   variable block, block_nr = -1, entry, entry_nr;
   variable selected_blocks = array_map(String_Type, &str_delete_chars, 
					Chartable_Tables, "&");
   % show(selected_blocks);
   
   foreach block (UnicodeBlocks) {
      block_nr++;
      entry_nr = wherefirst(block[2] == selected_blocks);
      if (entry_nr == NULL)
	 continue;
      entry = Chartable_Tables[entry_nr];
      % show(entry);
      menu_append_item(menu, entry, &ct_unicode_block, block_nr);
   }
   % menu_append_item(menu, "&Custom", "ch_table");
}

private define ch_table_menu(menu)
{
   % select unicode block
   if (_slang_utf8_ok) {
      menu_append_item(menu, "Next Table", "ch_table->ct_next_block");
      menu_append_item(menu, "Previous Table", "ch_table->ct_previous_block");
      menu_append_popup(menu, "Select &Table");
      menu_set_select_popup_callback(menu+".Select &Table", &menu_callback);
   }
   menu_append_item(menu, "Scroll Up", "ch_table->ct_page_up");
   menu_append_item(menu, "Scroll Down", "ch_table->ct_page_down");
   % menu_append_item(menu, "&Describe character", "describe_character");
   menu_append_item(menu, "&Insert", "ch_table->ct_insert");
   menu_append_item(menu, "Insert and &return", "ch_table->ct_insert_and_return");
   menu_append_item(menu, "Insert and &close", "ch_table->ct_insert_and_close");
   menu_append_popup(menu, "&Number base");
   variable popup = menu + ".&Number base";
   menu_append_item(popup, "&Binary",      &ct_change_base, 2);
   menu_append_item(popup, "&Octal",       &ct_change_base, 8);
   menu_append_item(popup, "&Decimal",     &ct_change_base, 10);
   menu_append_item(popup, "&Hexadecimal", &ct_change_base, 16);
   menu_append_item(popup, "&Custom",      "ch_table->ct_change_base");
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
% unicode numbers in description
dfa_define_highlight_rule(" [0-9A-F][0-9A-F][0-9A-F][0-9A-F]", "keyword", mode);
% render non-ASCII chars as normal to fix a bug with high-bit chars in UTF-8
dfa_define_highlight_rule("[^ -~]+", "normal", mode);

dfa_build_highlight_table(mode);
enable_dfa_syntax_for_mode(mode);
#endif

% --- Keybindings
require("keydefs"); % symbolic constants for many function and arrow keys

!if (keymap_p(mode)) 
   make_keymap(mode);

% numerical input for goto_char is dynamically defined by function ct_use_base
definekey("ch_table->ct_up",              Key_Up,    mode);
definekey("ch_table->ct_down",            Key_Down,  mode);
definekey("ch_table->ct_right",           Key_Right, mode);
definekey("ch_table->ct_left",            Key_Left,  mode);
definekey("bol; ch_table->ct_right;",     Key_Home,  mode);
definekey("eol; ch_table->ct_update;",    Key_End,   mode);
definekey("bob(); ch_table->ct_update;",  "<", 	     mode);
definekey("eob(); ch_table->ct_update;",  ">", 	     mode);
definekey("ch_table->ct_page_up",   	  Key_BS,    mode);
definekey("ch_table->ct_page_down;", 	  " ", mode);

definekey("ch_table->ct_previous_block",   Key_PgUp,      mode);
definekey("ch_table->ct_next_block;", 	   Key_PgDn,      mode);
definekey("ch_table->ct_unicode_block(0)", Key_Ctrl_PgUp, mode);
definekey(sprintf("ch_table->ct_unicode_block(%d)", 
		  length(UnicodeBlocks)-1),  Key_Ctrl_PgDn, mode);
   
definekey("ch_table->ct_change_base()",   "N",       mode);  % generic case
definekey("ch_table->ct_change_base(2)",  "B",       mode);
definekey("ch_table->ct_change_base(8)",  "O",       mode);
definekey("ch_table->ct_change_base(10)", "D",       mode);
definekey("ch_table->ct_change_base(16)", "H",       mode);

definekey("close_buffer",                    "\e\e\e", mode); % Escape
definekey("ch_table->ct_insert_and_close",   "^M",   mode);  % Return
definekey("ch_table->ct_describe_character", "d",    mode);
definekey("ch_table->ct_insert", 	     "i",    mode);
definekey("close_buffer",  		     "q",    mode);
definekey("ch_table->ct_insert_and_return",  "r",    mode);
definekey("help_message",                     "?",   mode);

set_help_message(
   "<RET>:Insert q:Quit, B:Binary, O:Octal, D:Decimal, H:hex N:Number_Base",
		 mode);

% Mouse bindings
% --------------

% goto "link" (codepoint-number in char description)
static define ct_active_link_hook(line, col, but, shift)
{
   variable nr, word = get_word("0-9A-Z");
   variable is_nr = sscanf (word, "%x", &nr);
   !if ((strlen(word) == 4) and is_nr) 
      return 0;
   % vshow("%d == %x", nr, nr);
   if (whatbuf == "*character description*")
      describe_character(nr);
   else
      ct_goto_char(nr);
   return 1;
}

static define ct_mouse_up_hook(line, col, but, shift)
{
   !if (ct_active_link_hook(line, col, but, shift))
      ct_update; %  move point inside character table
   return (1);
}

static define ct_mouse_2click_hook(line, col, but, shift)
{
   ct_insert();
   return (0);
}

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

% Unicode blocks (see Blocks.txt)
static define ct_unicode_block(n)
{
   variable 
      min = UnicodeBlocks[n][0],
      max = UnicodeBlocks[n][1];
   BlockNr = n;
   ch_table(min, max);
}

% Table selection
static define ct_next_block()
{
   if (BlockNr >= length(UnicodeBlocks)-1)
      error("already at last block");
   ct_unicode_block(BlockNr+1);
}

static define ct_previous_block()
{
   if (BlockNr <= 0) 
      error("already at first block");
   ct_unicode_block(BlockNr-1);
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
   BlockNr = 1;
}


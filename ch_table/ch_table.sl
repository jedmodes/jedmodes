% ch_table.sl
%
% A "popup_buffer" with all characters in a table
%
%  by Guenter Milde <g.milde@physik.tu-dresden.de>
%  with additions by Dino Leonardo Sangoi.
%
% ch_table()        characters 000-255
% ch_table(num)     characters num-255
% special_chars()     characters 160-255
%
%   - Arrow keys move by collumn and mark the character
%   - Mouse click also marks the character
%
%   - <Enter> copies the character to the calling buffer and closes table
%   - Mouse double click as well
%
%   - <Esc>   closes the table without copying

% TODO:
%
% + get a list of codes and names  via
%      recode --list=full latin1
%   (or what the actual encoding is) and give iso-name of actual char
%   (in status line or bottom line(s) of buffer)



% Auxiliary function custom: Should be moved to a more general place 
% like site.sl

%!%+
%\function{custom}
%\synopsis{make variable initialization user-customizable}
%\usage{AnyType custom (String var, AnyType default)}
%\description
%   If the variable c_var is defined, it is returned, otherwise
%   default is returned. Use this instead of custom_variable, if you 
%   want to change the variable but preserve the custom value for a 
%   possible reset.
%\seealso{custom_variable}
%\example{static variable TabSpacing = custom("ChartableTabSpacing", 4)
%!%-
define custom (varname, default)
{
   variable r = __get_reference (varname);
   if (r != NULL)
     if (__is_initialized(r))
     return(@r);
   return(default);
}

% --- static variables (user customizable, initialized in function ch_table)
static variable StartChar;
static variable NumBase;
static variable CharsPerLine;
static variable Digits ="0123456789abcdef";

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

#ifnexists fit_window
% a function, that fits the window size to the lenght of the buffer
% actually, this should go to a more general place to be usable for many modes
static define fit_window ()
{
   push_mark ();
   eob;
   variable misfit = what_line - window_info('r');
   if (misfit > 0) { % window too small
      loop(misfit)
	enlargewin ();
   }
   if (misfit < 0) { % window too large
      otherwindow;
      loop(-misfit)
	enlargewin ();
      loop(nwindows-1)  % return to original: fails if the minibuffer is active
	otherwindow;
   }
   pop_mark(1);
}
#endif

% give the ASCII-number of the current char in the status line
static define chartable_status_line()
{
   variable  cs;

   if (looking_at("TAB"))
     cs = "'TAB'=9/0x9/011";
   else if (looking_at("ESC"))
     cs = "'ESC'=27/0x1b/033";
   else if (looking_at("NL"))
     cs = "'NL'=10/0xa/012";
   else
     {
        cs = count_chars();
        cs = substr(cs, 1, string_match(cs, ",", 1)-1);
     }
   set_status_line(" Character Table:  "+ cs + "  ---- press '?' for help ", 0);
}

static define chartable_update ()
{
   bskip_chars ("^\t");
   % update status line
   chartable_status_line ();
   % write again to minibuffer (as messages don't persist)
      % if ressources are a topic, we could compute the message in
      % ch_table and store to a static variable GotoMessage
   vmessage("Goto char (%s ... %s, base: %d): ___", 
        int2string(StartChar, NumBase), int2string(255, NumBase),  NumBase);
   % mark character
   pop_mark(0);
   push_visible_mark;
   skip_chars ("^\t");
}

% give a message() with help usage.
define chartable_small_help()
{
   message(
"<RET>:Insert q:Quit, b:Binary, o:Octal, d:Decimal, h:hex n:Number_Base"
	      );
}

%move only in the ch_table, skipping the tabs
define chartable_up ()
{
   if (what_line < 4)
     error("Top Of Buffer");
   call ("previous_line_cmd");
   chartable_update;
}
define chartable_down ()
{
   call ("next_line_cmd");
   chartable_update;
}

define chartable_right ()
{
   () = fsearch("\t");
   call ("next_char_cmd");
   chartable_update;
}

define chartable_left ()
{
   bskip_chars ("^\t");
   call ("previous_char_cmd");
   bskip_chars ("^\t");
   if(bolp)
     call ("previous_char_cmd");
   if (what_line < 3)
     {
	chartable_right;
	error("Top Of Buffer");
     }
   chartable_update;
}

define chartable_bol ()   { bol; chartable_right; 
}
define chartable_eol ()   { eol; chartable_update; 
}
define chartable_bob ()   { goto_line(3); chartable_right;
}
define chartable_eob ()   { eob; chartable_update; 
}

#ifnexists close_buffer
define close_buffer()
{
   delbuf(whatbuf);
   call("delete_window");
}
#endif

define chartable_insert ()
{
   variable str = bufsubstr();
   close_buffer();
   if (str == "TAB")
     insert("\t");
   else if (str == "NL")
     insert("\n");
   else if (str == "ESC")
     insert("\e");
   else
     insert(str);
}

define chartable_mouse_up_hook (line, col, but, shift)
{
   % if (but == 1)
   if (what_line < 3)
     chartable_bob;
   chartable_right;
   chartable_left;
%   chartable_update;   error if click in first (number) collumn
   return (1);

}

define chartable_mouse_2click_hook (line, col, but, shift)
{
   chartable_insert();
   return (0);
}

% goto character by input of ASCII-Nr.
define chartable_goto_char ()
{
   variable goto_message =  sprintf("Goto char (%s ... %s, base: %d): ", 
        int2string(StartChar, NumBase), int2string(255, NumBase),  NumBase);
   variable GotoCharStr = read_mini(goto_message, "", char(LAST_CHAR));

   variable GotoChar = string2int(GotoCharStr, NumBase);

   if( (GotoChar<StartChar) or (GotoChar>255) )
     verror("%s not in range (%s ... %s)", 
	        GotoCharStr, 
	        int2string(StartChar, NumBase) , int2string(255, NumBase));
   chartable_bob;
   loop(GotoChar - (StartChar - (StartChar mod CharsPerLine)))
     chartable_right;
   % give feedback
   vmessage("Goto char: %s -> %c", GotoCharStr, GotoChar);
}

% insert the table into the buffer and fit window size
static define insert_ch_table ()
{
   variable i, j;
   TAB = custom("ChartableTabSpacing", 4);    % Set TAB for buffer
   % j = lengt of number on first column
   j = strlen(int2string(256-CharsPerLine, NumBase))+1;
   if (j < TAB)
      j = TAB;
   % heading
    vinsert("[% *d]\t", j-2, NumBase);
    for (i=0; i<CharsPerLine; i++)
      insert(int2string(i, NumBase) + "\t");
    newline;
   % now construct/insert the table
   for (i = StartChar - (StartChar mod CharsPerLine) ; i<256; i++)
     {
	if ((i) mod CharsPerLine == 0)
	    vinsert("\n% *s", j, int2string(i, NumBase)); % first column with number
	insert_char('\t');
	% insert characters, symbolic notation for TAB, Newline and Escape
	if (i < StartChar) continue;
	else if (i == '\t') insert("TAB");
	else if (i == '\n') insert ("NL");
	else if (i == '\e') insert ("ESC");
	else                insert_char(i);
     }
   fit_window;
   set_buffer_modified_flag (0);
   chartable_bob;
   chartable_update();
}

% set static variables and define keys to use specified number base
static define use_base (Base)
{
   NumBase = Base; 
   CharsPerLine = custom("ChartableCharsPerLine", NumBase);
   % bind keys
   for ($1=0; $1<16; $1++) 
     {
	undefinekey (char(Digits[$1]), "Char_Table_Map");
	definekey ("chartable_change_base(2)",   "b",     "Char_Table_Map"); 
	definekey ("chartable_change_base(10)",   "d",    "Char_Table_Map"); 
     }
   for ($1=0; $1<NumBase; $1++) 
     {
	definekey ("chartable_goto_char", char(Digits[$1]), "Char_Table_Map");
     }
}

% change the number base
define chartable_change_base ()
{
   variable Base;
   if (_NARGS)                  % optional argument present
     Base = ();
   else
     Base = integer(read_mini("New number base (2..16):", "", ""));
   use_base(Base);
   set_readonly(0);
   erase_buffer ();
   insert_ch_table();
   set_readonly(1);
}


   
% --- main function  ------------------------------------------------------

% a function that displays all chars of the current font
% in a table with indizes that give the "ASCII-value"
% skipping the first ones until optional argument Int "StartChar"
define ch_table () % ch_table(StartChar = 0)
{
   % (re) set options
   if (_NARGS)                  % optional argument present
     StartChar = ();
   else
     StartChar    = custom("ChartableStartChar", 0);           
   use_base (custom("ChartableNumBase", 10));
   CharsPerLine = custom("ChartableCharsPerLine", NumBase);  
      
   splitwindow;
   sw2buf ("*ch_table*");
   erase_buffer ();
   insert_ch_table();
   set_readonly(1);
   set_mode("Char_Table", 0);
   use_keymap ("Char_Table_Map");
   use_syntax_table ("Char_Table");
   set_buffer_hook ( "mouse_up", &chartable_mouse_up_hook);
   set_buffer_hook ( "mouse_2click", &chartable_mouse_2click_hook);
   run_mode_hooks("chartable_mode_hook");
}


% a function that displays the special chars of the current font
% (i.e. the chars with the high bit set)
% in a table with indizes that give the "ASCII-value"
define special_chars ()
{
   ch_table(160);
}

% colorize numbers

$1 = "Char_Table";
create_syntax_table ($1);
define_syntax ("0-9", '0', $1);
set_syntax_flags ($1, 0);

#ifdef HAS_DFA_SYNTAX
%%% DFA_CACHE_BEGIN %%%
static define setup_dfa_callback (name)
{
   dfa_enable_highlight_cache("ch_table.dfa", name);
   dfa_define_highlight_rule("^ *[0-9A-Z]+\t", "number", name);
   dfa_define_highlight_rule("^\\[.*$", "number", name);
   dfa_build_highlight_table(name);
}
dfa_set_init_callback (&setup_dfa_callback, $1);
%%% DFA_CACHE_END %%%
enable_dfa_syntax_for_mode($1);
#endif

% --- Keybindings
require("keydefs");

% $2 = "Char_Table_Map";
!if (keymap_p ("Char_Table_Map")) make_keymap ("Char_Table_Map");

% numerical input for goto_char is dynamically defined by function chartable_use_base

definekey ("chartable_up",Key_Up   , "Char_Table_Map");
definekey ("chartable_down",Key_Down , "Char_Table_Map");
definekey ("chartable_right",Key_Right, "Char_Table_Map");
definekey ("chartable_left",Key_Left , "Char_Table_Map");
definekey ("chartable_bol",Key_Home , "Char_Table_Map");
definekey ("chartable_eol",Key_End  , "Char_Table_Map");
definekey ("chartable_bob",Key_PgUp , "Char_Table_Map");
definekey ("chartable_eob",Key_PgDn , "Char_Table_Map");
definekey ("chartable_small_help", "?", "Char_Table_Map");
definekey ("chartable_change_base()",   "n",    "Char_Table_Map");  % generic case
definekey ("chartable_change_base(2)",   "b",     "Char_Table_Map"); 
definekey ("chartable_change_base(8)",   "o",    "Char_Table_Map"); 
definekey ("chartable_change_base(10)",   "d",    "Char_Table_Map"); 
definekey ("chartable_change_base(16)",   "h",    "Char_Table_Map"); 
definekey ("close_buffer",    "q",     "Char_Table_Map");
definekey ("chartable_insert"   ,    "^M",    "Char_Table_Map");  % Return
definekey ("close_buffer",    "\d155", "Char_Table_Map");  % "meta-escape"

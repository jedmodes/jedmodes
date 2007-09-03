%%  CUA (Windows/Mac/CDE/KDE-like) bindings for Jed.
%% 
%%  Copyright (c) 2006 Reuben Thomas, Guenter Milde (milde users.sf.net)
%%  Released under the terms of the GNU General Public License (ver. 2 or later)
%% 
%%  Versions:
%%  1   first version by Günter Milde <milde users.sf.net>
%%  1.1 05-2003    * triple (optional single) ESC-keypress aborts functions
%%                 * fixed missing definition of Key_Ins
%%                 * Key_Ctrl_Del calls cua_delete_word (was delete_word)
%%                 * F3 bound to repeat_search (tip by Guido Gonzato)
%%                 * removed definitions for F4...F10 (cua-compatible suggestions?)
%%                 * ^Q exits without asking for confirmation
%%  1.2 07-2003    * better support for older jed versions with
%%                   if (_jed_version >= 9916) around new functions
%%  1.3 2004-01-23 * Key_Del and Key_BS "region aware" (needs cuamisc >= 1.3)
%%  1.4 2005-05-26 * Merge with the version of jed 0.99-17
%%  1.4.1  	     bugfix: check for XWINDOWS before loading cuamouse.sl
%%  1.5 2005-06-07 * load backwards compatibility code from compat17-16.sl
%%  		     and compat16-15.sl (if needed)
%%  1.5.1 2005-11-02 bugfix: bind ESC to "back_menu" in menu map
%%  1.5.2 2006-01-17 more adaptions to the version of jed 0.99-17
%%  1.6   2006-06-16 remove the (optional) File>Print menu entry, so that
%%  	  	     the user can decide whether to use apsmode.sl (with its 
%%  	  	     Print menu popup or print.sl)
%%  1.6.1 2007-09-03 bind eol() instead of eol_cmd() to Key_End, as eol_cmd
%%  	  	     deletes trailing white which confuses moving and editing
%%  	  	     and might not be desired.
%%  	  	     
%%                   
%%  USAGE:
%% 
%%  put somewhere in your path and uncomment the line
%%  %  () = evalfile ("cua");            % CUA-like key bindings
%%  in your .jedrc/jed.rc file
%% 
%%  ESC-Key: unfortunately, some function keys return "\e\e<something>"
%%  as keystring. To have a single ESC-press aborting, add in jed.rc 
%%  either
%%  
%%     #ifdef XWINDOWS
%%     x_set_keysym(0xFF1B, 0, Key_Esc);   % one-press-escape
%%     #endif
%%  
%%  to get the one-press escape for xjed, or the experimental
%%     
%%     cua_one_press_escape();
%%     
%%  **Attention**, except for xjed, this is an experimental
%%  feature that can cause problems with functions that use getkey(),
%%  (e.g. isearch(), showkey(), wmark.sl (before jed 99.16), ...)
%% 
%%  Enhancements (optional helper modes from http://jedmodes.sf.net/):
%%   x-keydefs.sl: even more symbolic constants for function and arrow keys
%%   cuamouse.sl: cua-like mouse bindings
%%   cuamark.sl:  cua-like marking/copy/paste using yp_yank.sl (a ring of
%%                kill-buffers)
%%   numbuf.sl:   fast switch between buffers via ALT + Number
%%   print.sl:    printing
%%   ch_table.sl: popup_buffer with character table (special chars)

% --- Requirements ------------------------------------------------------

% backwards compatibility code (for older Jed versions)
if (_jed_version < 9915)
  require("compat16-15");
if (_jed_version < 9916)
  require("compat17-16");

require("cuamisc");   % "Outsourced" helper functions
require("keydefs");   % symbolic constants for many function and arrow keys
if(strlen(expand_jedlib_file("cuamark.sl")) and _jed_version >= 9916)
  require("cuamark");
else
  require("wmark");   % cua-like marking, standard version
require("recent");    % save a list of recent files

% --- Variables --------------------------------------------------------
set_status_line(" %b  mode: %m %n  (%p)   %t ", 1);
menu_set_menu_bar_prefix ("Global", " ");

Help_File = "cua.hlp";

%--- Keybindings --------------------------------------------------------

% This key will be used by the extension modes (e.g. c_mode.sl) to bind
% additional functions to
_Reserved_Key_Prefix = "^E";  % Extended functionality :-)

% ESC key
% unfortunately, some keys return strings starting with "\e\e", 
% see USAGE above for workaround
variable Key_Esc = "\e\e\e";
setkey ("cua_escape_cmd", Key_Esc);              % Triple-Esc -> abort
definekey("back_menu", Key_Esc, "menu"); % close (sub-)menus

% Function keys
setkey("menu_select_menu(\"Global.&Help\")",   Key_F1);
if (is_defined("context_help")) % from jedmodes.sf.net/mode/hyperhelp/
  setkey("context_help",                       Key_Shift_F1); 
setkey("cua_save_buffer",                      Key_F2);
setkey("save_buffer_as",                       Key_Shift_F2);
setkey("cua_repeat_search",                    Key_F3);
% setkey("menu_select_menu(\"Global.&Search\")", Key_F3); % open Search menu

% The "named" keys
setkey("cua_bdelete_char",                 Key_BS);
setkey("cua_delete_char",                  Key_Del);
setkey("toggle_overwrite",                 Key_Ins);
setkey("beg_of_line",                      Key_Home);
setkey("eol",                              Key_End);
setkey("page_up",                          Key_PgUp);
setkey("page_down",                        Key_PgDn);
setkey("cua_bdelete_word",                 Key_Ctrl_BS);
setkey("cua_delete_word",                  Key_Ctrl_Del);
setkey("beg_of_buffer",                    Key_Ctrl_Home);
setkey("eob; recenter(window_info('r'));", Key_Ctrl_End);
setkey("bskip_word",                       Key_Ctrl_Left);
setkey("skip_word",                        Key_Ctrl_Right);
setkey("forward_paragraph",                Key_Ctrl_Up);
setkey("backward_paragraph",               Key_Ctrl_Down);
%setkey("pop_mark(0)",                     Key_Ctrl_Up);
%setkey("push_mark",                       Key_Ctrl_Down);  % define region

% The Control Chars
unset_ctrl_keys();                         % unset to get a clear start
#ifdef UNIX
enable_flow_control(0);  %turns off ^S/^Q processing (Unix only)
#endif

setkey("mark_buffer",		"^A");   % mark All
%setkey("dabbrev",              "^A");	 % abbreviation expansion
%setkey("format_paragraph",	"^B");   % (ide default)
setkey("smart_set_mark_cmd",	"^B");   % Begin region
setkey("yp_copy_region_as_kill","^C");   % Copy (cua default)
set_abort_char('');                    % "logout"
% ^E ==  _Reserved_Key_Prefix              Extra functionality
% ^F map: 				   Find
setkey("search_backward", 	"^FB");
setkey("isearch_backward",	"^F^B");
setkey("toggle_case_search", 	"^FC");
setkey("re_search_forward", 	"^FE");  % rEgexp search
setkey("search_forward",	"^FF");
setkey("isearch_forward",	"^F^F");
setkey("re_search_backward",	"^FG");
setkey("isearch_forward",	"^FI");  % Incremental search
setkey("occur", 		"^FO");  % find all Occurences
setkey("query_replace_match", 	"^FP");  % regexp rePlace
setkey("replace_cmd", 		"^FR");

setkey("goto_line_cmd", 	"^G");   % Goto line
% set_abort_char('');                  % Jed Default, now on ^D
% ^H map: 				   Help ...
setkey("apropos", 		"^HA");
setkey("describe_function", 	"^HF");
setkey("help",   		"^HH");
setkey("info_mode", 		"^HI");
setkey("showkey", 		"^HK");
setkey("describe_mode", 	"^HM");
setkey ("unix_man",	      	"^HU");
setkey("describe_variable", 	"^HV");
setkey("where_is", 		"^HW");
setkey("menu_select_menu(\"Global.&Help\")", "^H?");

setkey("indent_line",           "^I");   % Key_Tab
% setkey("self_insert_cmd", 	"^I");
% setkey("",		   	"^J");   % Free!
setkey("del_eol",		"^K");   % Kill line
setkey("cua_repeat_search",	"^L");
%  ^M = Key_Enter
setkey("next_buffer",      	"^N");   % Next buffer
setkey("find_file",		"^O");   % Open file (cua default)
%setkey ("print_buffer", 	"^P");   % Print (with print.sl)
%setkey("exit_with_query",  	"^Q");   % Quit (ask for confirmation)
setkey("exit_jed",  		"^Q");   % Quit (without asking)
% ^R: 					   Rectangles
setkey("copy_rect",		"^RC");
setkey("insert_rect",		"^RV");
setkey("kill_rect",		"^RX");  % delete and copy to rect-buffer
setkey("open_rect",		"^R ");  % ^R Space: insert whitespace
setkey("blank_rect",		"^RY");  % delete (replace with spaces)
setkey("blank_rect",		"^R" + Key_Del);
setkey("cua_save_buffer",	"^S");   % Save 
% 				 ^T      % still free
setkey("yp_yank",              	"^V");   % insert/paste
setkey("delbuf(whatbuf)",     	"^W");
setkey("yp_kill_region",        "^X");   % cut
setkey("redo",		        "^Y");
setkey("undo",		        "^Z");

runhooks("keybindings_hook", "cua");    % user modifications

% --- menu additions --------------------------------------------------

private define cua_load_popup_hook (menubar)
{
   menu_delete_item ("Global.&File.&Close");
   menu_insert_item("&Save", "Global.&File", "&Close Buffer", "delbuf(whatbuf)");
   menu_insert_item (2, "Global.&Search", "Repeat &Search", "cua_repeat_search");
   menu_insert_item (3, "Global.&Search",
		     "&Incremental Search Forward", "isearch_forward");
   menu_insert_item (4, "Global.&Search",
		     "I&ncremental Search Backward", "isearch_backward");
   menu_insert_item ("&Replace", "Global.&Search",
		     "Toggle &Case Search", "toggle_case_search");
}
append_to_hook ("load_popup_hooks", &cua_load_popup_hook);

% signal the success in loading the cua emulation:
_Jed_Emulation = "cua";


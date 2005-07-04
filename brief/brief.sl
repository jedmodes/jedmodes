% brief.sl:    Brief editor emulation
% 
% modified by Guenter Milde to work with X-windows and a IBMPC keyboard
% using keymap.sl 
% 2003-08-18
% 
% Copyright (c) 2005 John E Davis, Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)

_Jed_Emulation = "brief";

% Since alt keys are used, make sure that they are enabled.
ALT_CHAR = 27;

% load the symbolic key definitions (variables Key_*)
require("keydefs");
% load and bind the additional key definitions for the Keypad
% require("kp_keydefs", "/full/path/to/kp_keydefs.sl");
require("kp_keydefs");

set_status_line("(Jed %v) Brief: %b    (%m%a%n%o)  %p   %t", 1);
Help_File = Null_String;

define brief_home ()
{
   if (bolp ())
     {
	if (window_line () == 1) bob ();
	else goto_top_of_window ();
     }
   bol ();
}

define brief_end ()
{
   if (eolp ())
     {
	if (window_line () == window_info ('r')) eob ();
	else goto_bottom_of_window ();
     }
   eol ();
}

define brief_line_to_eow ()
{
   recenter (window_info ('r'));
}

define brief_line_to_bow ()
{
   recenter (1);
}

define brief_line_to_mow ()
{
   recenter (window_info ('r') / 2);
}

define brief_set_bkmrk_cmd (n)
{
   ungetkey (n + '0');
   bkmrk_set_mark ();
}

define brief_delete_to_bol ()
{
   push_mark ();
   bol();
   del_region ();
}

define brief_toggle_case_search ()
{
   CASE_SEARCH = not (CASE_SEARCH);
}

variable Brief_Regexp_Search = 0;
define brief_toggle_regexp ()
{
   Brief_Regexp_Search = not (Brief_Regexp_Search);
}

variable Brief_Search_Forward = 1;
define brief_search_cmd ()
{
   if (Brief_Search_Forward)
     {
	if (Brief_Regexp_Search) re_search_forward ();
	else search_forward ();
     }
   else
     {
	if (Brief_Regexp_Search) re_search_backward ();
	else search_backward ();
     }
}

define brief_reverse_search ()
{
   Brief_Search_Forward = not (Brief_Search_Forward);
   brief_search_cmd ();
}

define brief_line_mark ()
{
   bol ();
   set_mark_cmd ();
   eol ();
}

variable Brief_Use_Rectangle = 0;
define brief_yank ()
{
   if (Brief_Use_Rectangle)
     {
	insert_rect ();
     }
   else call ("yank");
}

define brief_copy_region ()
{
   if (Brief_Use_Rectangle)
     {
	copy_rect ();
     }
   else call ("copy_region");
}

define brief_kill_region ()
{
   if (Brief_Use_Rectangle)
     {
	kill_rect ();
     }
   else call ("kill_region");
}

define brief_delete ()
{
   if (markp ())
     {
        if (Brief_Use_Rectangle)
          {
	     kill_rect ();
          }
	else
	  {
	     del_region ();
          }
	return;
     }
   del ();
}

define brief_set_mark_cmd ()
{
   Brief_Use_Rectangle = 0;
   smart_set_mark_cmd ();
}

define brief_set_column_mark ()
{
   Brief_Use_Rectangle = 1;
   set_mark_cmd ();
   message ("Column mark set.");
}

unsetkey ("^K");
unsetkey ("^X");
unsetkey ("^W");
unsetkey ("^F");
setkey ("page_down",             "^D"   );
setkey ("page_up",               "^E"   );
setkey ("brief_delete_to_bol",   "^K"   );
setkey ("goto_match",            "^Q["  );
setkey ("goto_match",            "^Q\e" );
setkey ("goto_match",            "^Q]"  );
setkey ("goto_match",            "^Q^]" );
setkey ("isearch_forward",       "^S"   );
setkey ("brief_line_to_bow",     "^T"   );
setkey ("brief_line_to_mow",     "^C"   );
setkey ("brief_line_to_eow",     "^B"   );

setkey ("brief_yank",            Key_Ins        );
setkey ("brief_delete",          Key_Del        );
setkey ("brief_home",            Key_Home       );
setkey ("brief_end",             Key_End        );
setkey ("scroll_left",           Key_Shift_End  );
setkey ("scroll_right",          Key_Shift_Home );
setkey ("bskip_word",            Key_Ctrl_Left  );
setkey ("skip_word",             Key_Ctrl_Right );
setkey ("bob",                   Key_Ctrl_PgUp  );
setkey ("eob",                   Key_Ctrl_PgDn  );
setkey ("goto_top_of_window",    Key_Ctrl_Home  );
setkey ("goto_bottom_of_window", Key_Ctrl_End   );
setkey ("bdelete_word",          Key_Ctrl_BS    );
setkey ("delete_word",           Key_Alt_BS     );

%setkey ("undo",                     Key_KP_Multiply );
%setkey ("brief_copy_region",        Key_KP_Plus    );
%setkey  ("brief_kill_region",        Key_KP_Minus   );
%
setkey  ("brief_search_cmd",         Key_F5         );
setkey  ("brief_reverse_search",     Key_Alt_F5     );
setkey  ("brief_search_cmd",         Key_Shift_F5   );
setkey  ("brief_toggle_case_search", Key_Ctrl_F5    );
setkey  ("replace_cmd",              Key_F6         );
setkey  ("brief_toggle_regexp",      Key_Ctrl_F6    );

setkey  ("brief_set_mark_cmd",    "\ea" ); % Alt A
%setkey ("list_buffers",          "\eb" ); % Alt B Buffers menu
setkey  ("brief_set_column_mark", "\ec" ); % Alt C
setkey  ("delete_line",           "\ed" ); % Alt D
%setkey ("find_file",             "\ee" ); % Alt E Edit    menu
setkey  ("goto_line_cmd",         "\eg" ); % Alt G
%setkey ("help_prefix",           "\eh" ); % Alt H Help    menu
%setkey ("toggle_overwrite",      "\ei" ); % Alt I Windows menu
setkey  ("bkmrk_goto_mark",       "\ej" ); % Alt J
setkey  ("kill_line",             "\ek" ); % Alt K
setkey  ("brief_line_mark",       "\el" ); % Alt L
setkey  ("set_mark_cmd",          "\em" ); % Alt M
setkey  ("switch_to_buffer",      "\en" ); % Alt N
%setkey ("write_buffer",          "\eo" ); % Alt O Mode    menu
setkey  ("insert_file",           "\er" ); % Alt R
setkey  ("brief_search_cmd",      "\es" ); % Alt S Search  menu
setkey  ("replace_cmd",           "\et" ); % Alt T
setkey  ("undo",                  "\eu" ); % Alt U
setkey  ("save_buffer",           "\ew" ); % Alt W
setkey  ("exit_jed",              "\ex" ); % Alt X
%
setkey (".0 brief_set_bkmrk_cmd", "\e0" ); % Alt 0
setkey (".1 brief_set_bkmrk_cmd", "\e1" ); % Alt 1
setkey (".2 brief_set_bkmrk_cmd", "\e2" ); % Alt 2
setkey (".3 brief_set_bkmrk_cmd", "\e3" ); % Alt 3
setkey (".4 brief_set_bkmrk_cmd", "\e4" ); % Alt 4
setkey (".5 brief_set_bkmrk_cmd", "\e5" ); % Alt 5
setkey (".6 brief_set_bkmrk_cmd", "\e6" ); % Alt 6
setkey (".7 brief_set_bkmrk_cmd", "\e7" ); % Alt 7
setkey (".8 brief_set_bkmrk_cmd", "\e8" ); % Alt 8
setkey (".9 brief_set_bkmrk_cmd", "\e9" ); % Alt 9

runhooks ("keybindings_hook", _Jed_Emulation);


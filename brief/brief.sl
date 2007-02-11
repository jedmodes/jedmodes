% brief.sl:    Brief editor emulation
% 
% This will not work well on konsole or in an x-terminal
% because of the heavy dependence on "exotic" keys.
% Try with DOS, MS-Windows, or X-Windows and an IBMPC keyboard
% 
% Copyright (c) 2005 John E Davis, Günter Milde, Marko Mahnic
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% 2003-08-18 Guenter Milde 
%   - work with X-windows and a IBMPC keyboard using keydefs.sl
%   
% 2005-10-11 Marko Mahnic
%   - double/triple home/end handling
%   - more Brief keybindings (based on emacs brief.el)
%   - more Brief-like region marking, copying, yanking
%   - page up/dn (mostly) leaves cursor on same screen line
%   - Brief-like macro recording (F7)
%   
% 2005-10-12 Guenter Milde
%   - fixed dependency on x-keydefs (kp_keydefs is obsolete)
%   
% 2006-03-07 Marko Mahnic
%   - added support for named scraps with region type info in blocal vars
%   
% 2006-03-15 Marko Mahnic
%   - disabled the "\em" keybinding that prevented menu access
%   - disabled the "\es" keybinding (Search menu)
%   
% 2007-02-11 Marko Mahnic
%   - moved all functions to briefmsc.sl
%   - functions marked "public"
%   - documentation added
%
_Jed_Emulation = "brief";

% load the extended set of symbolic key definitions (variables Key_*)
require("x-keydefs");
require("briefmsc");
autoload ("scroll_up_in_place",     "emacsmsc");
autoload ("scroll_down_in_place", "emacsmsc");

set_status_line("(Jed %v) Brief: %b    (%m%a%n%o)  %p   %t", 1);
Help_File = Null_String;

unsetkey ("^F");
unsetkey ("^K");
unsetkey ("^R");
unsetkey ("^X");
unsetkey ("^W");
setkey ("scroll_up_in_place",    "^D"   );
setkey ("scroll_down_in_place",  "^E"   );
setkey ("brief_delete_to_bol",   "^K"   );
setkey ("goto_match",            "^Q["  );
setkey ("goto_match",            "^Q\e" );
setkey ("goto_match",            "^Q]"  );
setkey ("goto_match",            "^Q^]" );
setkey ("isearch_forward",       "^S"   );
setkey ("brief_line_to_bow",     "^T"   );
setkey ("brief_line_to_mow",     "^C"   );
setkey ("brief_line_to_eow",     "^B"   );
%setkey ("brief_next_error",     "^N"   );
%setkey ("brief_error_window",   "^P"   );
_for (0, 9, 1) { $0 = (); setkey("digit_arg", "^R" + string($0)); }
%setkey ("redo",                 "^U"   );
%setkey ("brief_toggle_backup",  "^W"   );
%setkey ("save_buffers_and_exit","^X"   );
%setkey ("one_window",           "^Z"   );

setkey ("brief_yank",            Key_Ins        );
setkey ("brief_delete",          Key_Del        );
setkey ("brief_home",            Key_Home       );
setkey ("brief_end",             Key_End        );
setkey ("brief_pagedown",        Key_PgDn       );
setkey ("brief_pageup",          Key_PgUp       );
setkey ("scroll_left",           Key_Shift_End  ); % should be: right of window
setkey ("scroll_right",          Key_Shift_Home ); % should be: left of window
setkey ("bskip_word",            Key_Ctrl_Left  );
setkey ("skip_word",             Key_Ctrl_Right );
setkey ("bob",                   Key_Ctrl_PgUp  );
setkey ("eob",                   Key_Ctrl_PgDn  );
setkey ("goto_top_of_window",    Key_Ctrl_Home  );
setkey ("goto_bottom_of_window", Key_Ctrl_End   );
setkey ("bdelete_word",          Key_Ctrl_BS    );
setkey ("delete_word",           Key_Alt_BS     );
setkey ("brief_open_line",       Key_Ctrl_Return);

setkey ("undo",                  Key_KP_Multiply );
setkey ("brief_copy_region",     Key_KP_Add      );
setkey ("brief_kill_region",     Key_KP_Subtract );

% setkey ("brief_copy_region_named",     Key_Ctrl_KP_Add);
% setkey ("brief_kill_region_named",     Key_Ctrl_KP_Subtract);
% setkey ("brief_yank_named",            Key_Ctrl_Ins);

setkey  ("other_window",             Key_F1         );
setkey  ("one_window",               Key_Alt_F2     );
setkey  ("split_window",             Key_F3         );
setkey  ("delete_window",            Key_F4         );
setkey  ("brief_search_cmd",         Key_F5         );
setkey  ("brief_reverse_search",     Key_Alt_F5     );
setkey  ("brief_search_cmd",         Key_Shift_F5   );
setkey  ("brief_toggle_case_search", Key_Ctrl_F5    );
setkey  ("brief_replace_cmd",        Key_F6         );
setkey  ("brief_toggle_regexp",      Key_Ctrl_F6    );
setkey  ("brief_record_kbdmacro",    Key_F7         );
%setkey  ("brief_pause_kbdmacro",     Key_Shift_F7   );
setkey  ("execute_macro",            Key_F8         );
setkey  ("emacs_escape_x",           Key_F10        );
setkey  ("compile",                  Key_Alt_F10    );

setkey  (". 4 brief_set_mark_cmd","\ea" ); % Alt A
%setkey ("list_buffers",          "\eb" ); % Alt B Buffers menu
setkey  ("brief_set_column_mark", "\ec" ); % Alt C
setkey  ("delete_line",           "\ed" ); % Alt D
%setkey ("find_file",             "\ee" ); % Alt E Edit    menu
%setkey ("display_file_name",     "\ef" ); % Alt F File    menu
setkey  ("goto_line_cmd",         "\eg" ); % Alt G
%setkey ("help_prefix",           "\eh" ); % Alt H Help    menu
%setkey ("toggle_overwrite",      "\ei" ); % Alt I Windows menu
setkey  ("bkmrk_goto_mark",       "\ej" ); % Alt J
setkey  ("kill_line",             "\ek" ); % Alt K
setkey  ("brief_line_mark",       "\el" ); % Alt L
%setkey  (". 1 brief_set_mark_cmd","\em" ); % Alt M Menu access prefix
setkey  ("brief_next_buffer(1)",  "\en" ); % Alt N
%setkey ("write_buffer",          "\eo" ); % Alt O Mode    menu
setkey  ("brief_next_buffer(-1)", "\ep" ); % Alt P; should be: print region
%setkey ("quote_next_key",        "\eq" ); % Alt Q
setkey  ("insert_file",           "\er" ); % Alt R
%setkey  ("brief_search_cmd",      "\es" ); % Alt S Search  menu
setkey  ("brief_replace_cmd",     "\et" ); % Alt T
setkey  ("undo",                  "\eu" ); % Alt U
%setkey ("brief_show_version",    "\ev" ); % Alt V
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

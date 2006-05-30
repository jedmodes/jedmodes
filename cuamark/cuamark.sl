% cuamark.sl
% 
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% CUA/Windows style of marking ("volatile regions")
% 
% Version 0.9
% Version 0.9.1  use _jed_before_key_hooks (needs jed 0.99.16)
%                after the example by JED in wmarks.sl
%         1.0    added support for Dave Kuhlhard's yank_repop command
%         1.1  * removed the require("yankpop"), (autoloads in site.sl)

% Author: Guenter Milde (g.milde web.de)
% 
% Mark regions the CUA style:
%
% * Holding down Shift key and using navigation keys defines a region
% 
% * Arrow keys without Shift undefine the region, if defined with 
%   Shift-<arrow>
%   
% * Self-insert (Typing "normal" text) will replace such a  region,
%   del() and backward_delete_char[_untabify]() delete it.
%   Define 
%      variable CuaInsertReplacesRegion = ""
%   in your .jedrc if you don't like this.
%
% * You can still define a "non-cua"-region with push_visible_mark().
%   Such "permanent-region" will behave the "normal jed way" (i.e it can 
%   be extended by nonshifted navigation and will not be replaced with 
%   typed text)
% 
% The following bindings affect all visible regions:
% 
% * Shift-<Del> cuts the region  (in CUA also ^X)
% * Ctrl-<Ins>  copies the region (in CUA also ^C)
% * Shift-<Ins> inserts the yank_buffer (in CUA also ^V)
% 
% USAGE: Insert a line require("cuamark") into your .jedrc/jed.rc file.
%        Optionally customize using custom variables and the cuamark_hook.
% 
% NOTES: If you are having problems with Shift-arrow keys under linux, 
% 	 read the JED_ROOT/doc/txt/linux-keys.txt file.
%        
% TODO:
%        Extend the Shift+navigation marking to wordwise moving via 
%        Ctrl-Left/Right. 
%        Problem: with Unix/Linux Shift-Ctrl-Left/Right == Ctrl-Left/Right
%        Workaround:
%        Currently, "skip_word, bskip_word" are not listed as unmarking 
%        functions -> Start the region using Shift-Left/Right and then 
%        extend it with Ctrl-Left/Right.


require ("keydefs"); % part of standard jed distribution

% --- Custom Variables ---------------------------------------------------

% shall "copy" also place a copy to the clipboard (X-selection, cutbuffer)?
custom_variable("CuaCopyToClipboard", 1);

% Comma separated list of functions that unmark the region (movement functions)
custom_variable("Cua_Unmarking_Functions", 
   "beg_of_line, eol_cmd,"
   + "previous_char_cmd, next_char_cmd,"
   + "previous_line_cmd, next_line_cmd,"
   + "page_up, page_down, bob, eob,"
   %  + "skip_word, bskip_word " % Shift_Ctrl_Right/Left
   );

% List of functions that replace the region (insert-functions)
% (Define variable Cua_Replacing_Functions = "";
% in your .jedrc if you don't want the region replaced by inserting)
custom_variable("Cua_Replacing_Functions", "self_insert_cmd, yank, yp_yank");

% --- Functions ------------------------------------------------------------

static define before_key_hook (fun)
{
   if (is_substr(Cua_Unmarking_Functions, fun + ","))
     pop_mark_0();
   else if (is_substr(Cua_Replacing_Functions, fun + ","))
     del_region();
}

static define after_key_hook ();  % dummy definition
static define after_key_hook ()
{
   !if (is_visible_mark())
     {
	remove_from_hook ("_jed_before_key_hooks", &before_key_hook);
	remove_from_hook ("_jed_after_key_hooks", &after_key_hook);
     }
}

%!%+
%\function{cua_mark}
%\synopsis{Mark a cua-region (usually, with Shift-Arrow keys)}
%\usage{cua_mark()}
%\description
%   if no visible region is defined, set visible mark and key-hooks
%   so that Cua_Unmarking_Functions unmark the region and
%   Cua_Deleting_Functions delete it.
%\seealso{cua_kill_region, cua_copy_region, Cua_Unmarking_Functions, Cua_Deleting_Functions}
%!%-
define cua_mark()
{
   !if (is_visible_mark)
     {
	push_visible_mark ();
	add_to_hook ("_jed_before_key_hooks", &before_key_hook);
	add_to_hook ("_jed_after_key_hooks", &after_key_hook);
     }
}


% Copy region to system clipboards (The region stays marked)
% see also copy_region_to_clipboard() in cuamouse.sl
static define copy_to_clipboard()
{
   () = dupmark();                  % \ 
   if (bufsubstr() == "")           %  | no copy if the region is nil
     return;	      		    % /
   () = dupmark();		    
   if (is_defined("x_copy_region_to_selection"))
     eval("x_copy_region_to_selection");
   else if (is_defined("x_copy_region_to_cutbuffer"))
     eval("x_copy_region_to_cutbuffer");
   else
     pop_mark_0;
}


%!%+
%\function{cua_insert_clipboard}
%\synopsis{Insert X selection at point}
%\usage{Void cua_insert_clipboard()}
%\description
%   Insert the content of the X selection at point.
%   Use, if you want to have a keybinding for the "middle click" action.
%\seealso{x_insert_selection, x_insert_cutbuffer, CuaCopyToClipboard}
%!%-
define cua_insert_clipboard()
{
   if (is_defined("x_insert_selection"))
     eval("x_insert_selection");
   else if (is_defined("x_insert_cutbuffer"))
     eval("x_insert_cutbuffer");
}

%!%+
%\function{cua_kill_region}
%\synopsis{Kill region (and copy to yp-yankbuffer [and X selection])}
%\usage{Void cua_kill_region()}
%\description
%   Kill region. A copy is placed in the yp-yankbuffer and 
%   (with xjed and if CuaCopyToClipboard is true) to the X selection.
%\seealso{yp_kill_region, cua_copy_region, CuaCopyToClipboard}
%!%-
define cua_kill_region ()
{
   if (CuaCopyToClipboard)
     copy_to_clipboard();
   yp_kill_region;
}

%!%+
%\function{cua_copy_region}
%\synopsis{Copy region to yp-yankbuffer [and X selection])}
%\usage{Void cua_copy_region()}
%\description
%   Copy the region to the yp-yankbuffer and 
%   (with xjed and if CuaCopyToClipboard is true) to the X selection.
%\seealso{yp_copy_region_as_kill, cua_kill_region, CuaCopyToClipboard}
%!%-
define cua_copy_region()
{
   if (CuaCopyToClipboard)
     copy_to_clipboard();
   yp_copy_region_as_kill;
}

% --- Keybindings

setkey("cua_mark; go_up_1",             Key_Shift_Up);
setkey("cua_mark; go_down_1",           Key_Shift_Down);
setkey("cua_mark; go_left_1",           Key_Shift_Left);
setkey("cua_mark; go_right_1",          Key_Shift_Right);
setkey("cua_mark; call(\"page_up\")",   Key_Shift_PgUp);
setkey("cua_mark; call(\"page_down\")", Key_Shift_PgDn);
setkey("cua_mark; bol",                 Key_Shift_Home);
setkey("cua_mark; eol",                 Key_Shift_End);

setkey("cua_yank",		        Key_Shift_Ins);
setkey("cua_kill_region",  	        Key_Shift_Del);
setkey("cua_copy_region",	        Key_Ctrl_Ins);


% some more keybinding suggestions:

% setkey ("pop_spot",             Key_Alt_Up);  
% setkey ("push_spot",	   	  Key_Alt_Down);
% setkey ("cua_insert_clipboard", Key_Alt_Ins);

runhooks("cuamark_hook");

provide ("cuamark");

% cuamark.sl: CUA/Windows style of marking "volatile" regions
%
% Copyright (c) 2003, 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Version    0.9
%  	     0.9.1  use _jed_before_key_hooks (needs jed 0.99.16)
%                   after the example by JED in wmarks.sl
%            1.0    added support for Dave Kuhlhard's yank_repop command
%            1.1  * removed the require("yankpop"), (autoloads in site.sl)
% 2006-07-20 1.2  * bugfix: cua_insert_clipboard() returned a value
%		  * removed the call to cuamark_hook(): place your 
%		    customization just after the `require("cuamark");' line.
%		  * removed CuaCopyToClipboard: bind yp_copy_region() and
%		    yp_kill_region() if you do not like to copy to the X 
%		    selection
%		  
%
% Author: Günter Milde (g.milde web.de)
%
% Mark regions the CUA style
% --------------------------
%
% * Holding down Shift key and using navigation keys defines a region
%
% * Arrow keys without Shift undefine the region, if defined with
%   Shift-<arrow>
%
% * The custom variable `Cua_Replacing_Functions' holds all functions that
%   will replace a cua-region. By default this includes
%   self_insert_cmd (typing "normal" text), yank, yp_yank, and cua_yank.
%
%   (The cua emulation binds the <Delete> key to cua_delete_char(), which
%    deletes a character or any visible region).
%
% * You can still define a "non-cua"-region with push_visible_mark().
%   Such a "permanent-region" will behave the "normal" Jed way (i.e it can
%   be extended by nonshifted navigation and will not be replaced with
%   typed text)
%
% The following bindings affect all visible regions:
%
%   Shift-<Del> cut region
%   Ctrl-<Ins>  copy region
%   Shift-<Ins> inserts the yank_buffer
%
% Usage
% -----
% 
% Insert a line
%   require("cuamark")
% into your .jedrc/jed.rc file. Optionally customize using custom variables
% and|or change keybindings.
%
% Some keybinding suggestions:
%
%   setkey("pop_spot",             Key_Alt_Up);
%   setkey("push_spot",	   	 Key_Alt_Down);
%   setkey("cua_insert_clipboard", Key_Alt_Ins);
%   setkey("cua_kill_region",  	 "^X");
%   setkey("cua_copy_region",	 "^C");
%   setkey("cua_yank",		 "^V");
%   
% if you do not like to place a copy into the X selection
% or are never using Jed under X-windows:
% 
%   setkey("yp_kill_region",  	        Key_Shift_Del);
%   setkey("yp_copy_region",	        Key_Ctrl_Ins);
%
% Notes
% -----
% 
% If you are having problems with Shift-arrow keys under
% the Linux console, you can use the "console_keys" mode
% (http://jedmodes.sourceforge.net/mode/console_keys/)
%
% TODO
% ----
% 
% Extend the Shift+navigation marking to wordwise moving via Ctrl-Left/Right.
% Problem: with Unix/Linux Shift-Ctrl-Left/Right == Ctrl-Left/Right
%
% Workaround: Currently, "skip_word, bskip_word" are not listed as unmarking
% functions -> Start the region using Shift-Left/Right and then extend it with
% Ctrl-Left/Right.

require ("keydefs");

% --- Custom Variables ---------------------------------------------------


% Comma separated list of functions that unmark a cua-region (movement functions)
%!%+
%\variable{Cua_Replacing_Functions}
%\synopsis{Functions that unmark a cua-region (movement functions)}
%\usage{variable Cua_Unmarking_Functions = "beg_of_line,eol_cmd,..."}
%\description
% Comma separated string of functions that unmark a region defined via
% \sfun{cua_mark} (insert-functions).
%\example
% If you want to unmark a cua-region by wordwise movement, write
%#v+
%  Cua_Unmarking_Functions += ",skip_word, bskip_word ";
%#v-
% in your jed.rc (or .jedrc) file after the `require("cuamark")' line.
%\seealso{cua_mark}
%!%-
custom_variable("Cua_Unmarking_Functions",
   "beg_of_line,eol_cmd,"
   + "previous_char_cmd,next_char_cmd,"
   + "previous_line_cmd,next_line_cmd,"
   + "page_up,page_down,bob,eob,"
   %  + "skip_word, bskip_word" % Shift_Ctrl_Right/Left
   );

%!%+
%\variable{Cua_Replacing_Functions}
%\synopsis{Functions that replace the cua-region (insert-functions)}
%\usage{variable Cua_Replacing_Functions = "self_insert_cmd,yank,yp_yank,cua_yank"}
%\description
% Comma separated string of functions that replace a region started with
% \sfun{cua_mark} (insert-functions).
%\example
% If you don't want the region replaced by inserting, define
%#v+
%  variable Cua_Replacing_Functions = "";
%#v-
% in your jed.rc (or .jedrc) file.
%\seealso{cua_mark, Cua_Unmarking_Functions}
%!%-
custom_variable("Cua_Replacing_Functions",
                "self_insert_cmd,yank,yp_yank,cua_yank");

custom_variable("Cuamark_Pop_Key", "^P");
custom_variable("Cuamark_Repop_Key", "^N");

% --- Functions ------------------------------------------------------------

static define before_key_hook(fun)
{
   if (is_substr(Cua_Unmarking_Functions, fun + ","))
     pop_mark_0();
   else if (is_substr(Cua_Replacing_Functions, fun + ","))
     del_region();
}

static define after_key_hook();  % forward definition
static define after_key_hook()
{
   !if (is_visible_mark())
     {
	remove_from_hook("_jed_before_key_hooks", &before_key_hook);
	remove_from_hook("_jed_after_key_hooks", &after_key_hook);
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
	add_to_hook("_jed_before_key_hooks", &before_key_hook);
	add_to_hook("_jed_after_key_hooks", &after_key_hook);
     }
}

% Copy region to system clipboards (The region stays marked)
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
% Insert the content of the X selection at point.
% Use, if you want to have a keybinding for the "middle click" action.
%\notes
% This function doesnot return the number of characters inserted so it can
% be bound to a key easily.
%\seealso{x_insert_selection, x_insert_cutbuffer}
%!%-
define cua_insert_clipboard()
{
   if (is_defined("x_insert_selection"))
     () = eval("x_insert_selection");
   else if (is_defined("x_insert_cutbuffer"))
     () = eval("x_insert_cutbuffer");
}

%!%+
%\function{cua_kill_region}
%\synopsis{Kill region (and copy to yp-yankbuffer [and X selection])}
%\usage{Void cua_kill_region()}
%\description
%   Kill region. A copy is placed in the yp-yankbuffer.
%
%   If \sfun{x_copy_region_to_selection} or \sfun{x_copy_region_to_cutbuffer}
%   exist, a copy is pushed to the X selection as well.
%\seealso{yp_kill_region, cua_copy_region, yp_yank}
%!%-
define cua_kill_region ()
{
   copy_to_clipboard();
   yp_kill_region;
}

%!%+
%\function{cua_copy_region}
%\synopsis{Copy region to yp-yankbuffer [and X selection])}
%\usage{Void cua_copy_region()}
%\description
%   Copy the region to the yp-yankbuffer.
%
%   If \sfun{x_copy_region_to_selection} or \sfun{x_copy_region_to_cutbuffer}
%   exist, a copy is pushed to the X selection as well.
%\seealso{yp_copy_region_as_kill, cua_kill_region, yp_yank}
%!%-
define cua_copy_region()
{
   copy_to_clipboard();
   yp_copy_region_as_kill;
}

% % yp_yank wrapper with temporar rebinding of yank-pop keys
% % --------------------------------------------------------
% 
% static define cua_yank_pop_hook(fun); % forward definition
% static define cua_yank_pop_hook(fun)
% {
%    show("function, key(s)", fun, which_key(fun));
%    % if (fun == yank_repop_key_fun)
%    %   set_prefix_argument(1);
%    % yp_yank_pop();
%    show(LASTKEY, char(LAST_CHAR), CURRENT_KBD_COMMAND, LAST_KBD_COMMAND);
%    
%    remove_from_hook("_jed_before_key_hooks", &cua_yank_pop_hook);
% }
% 
% % yank from yankpop kill-buffer-ring and temporarily rebind yank-pop keys
% define cua_yank()
% {
%    yp_yank();
%    add_to_hook("_jed_before_key_hooks", &cua_yank_pop_hook);
%    vmessage("Press %s or %s to cycle among replacements",
%       Cuamark_Pop_Key, Cuamark_Repop_Key);
% }

% --- Keybindings

setkey("cua_mark; go_up_1",             Key_Shift_Up);
setkey("cua_mark; go_down_1",           Key_Shift_Down);
setkey("cua_mark; go_left_1",           Key_Shift_Left);
setkey("cua_mark; go_right_1",          Key_Shift_Right);
setkey("cua_mark; call(\"page_up\")",   Key_Shift_PgUp);
setkey("cua_mark; call(\"page_down\")", Key_Shift_PgDn);
setkey("cua_mark; bol",                 Key_Shift_Home);
setkey("cua_mark; eol",                 Key_Shift_End);

setkey("yp_yank",		        Key_Shift_Ins);
setkey("cua_kill_region",  	        Key_Shift_Del);
setkey("cua_copy_region",	        Key_Ctrl_Ins);

provide ("cuamark");

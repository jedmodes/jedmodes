%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% cuamark.sl
% Implements CUA/Windows style of marking ("volatile regions")
% 
% Version 0.9
% Version 1.0  use _jed_before_key_hooks (needs jed 0.99.16)
%              after the example by JED in wmarks.sl
%              added support for Dave Kuhlhard's yank_repop command       
%
% Author: Guenter Milde (g.milde@web.de)
% 
% Mark regions the CUA like style:
%
% * Holding down Shift key and using navigation keys defines a region
% 
% * Arrow keys without Shift undefine the region, if defined with 
%   Shift-<arrow>
%   
% * Self-insert (Typing "normal" text) will replace such a  region
%   Define 
%      variable CuaInsertReplacesRegion = 0 
%   in your .jedrc if you don't like it.
%
% * You can still define a "non-cua"-region with push_visible_mark().
%   Such "permanent-region" will behave the "normal jed way" (i.e it can 
%   be extended by nonshifted navigation and will not be replaced with 
%   typed text)
% 
% The following bindings affect all visible regions:
% 
% * <Del> deletes the region if one is defined (otherwise the char under 
%   cursor)
% * Shift-<Del> cuts the region  (also ^X in CUA)
% * Ctrl-<Ins>  copies the region (also ^C in CUA)
% * Shift-<Ins> inserts the yank_buffer (also ^V in CUA)
% 
% TODO:
%       Extend the Shift+navigation marking to wordwise moving via 
%       Ctrl-Left/Right. 
%       However, on Linux Shift-Ctrl-Left/Right is not defined
%       Still you can start a region using Shift-Left/Right and then 
%       extend it with Ctrl-Left/Right
% 
% Notes: If you are having problems with Shift-arrow keys under linux, 
% 	 then read the jed/doc/txt/linux-keys.txt file.
%        
%        If your Delete key deletes the charakter under the cursor but does 
%        not delete the region, comment out the line
%               setkey ("delete_char_cmd", "\e[3~");
% 	 in your .jedrc
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

require ("keydefs");
require ("yankpop");

% --- Variables

% shall copy also place a copy to the clipboard (X-selection, cutbuffer)?
custom_variable("CuaCopyToClipboard", 1);

% Comma separated list of functions that unmark the region (movement functions)
custom_variable("Cua_Unmarking_Functions", "beg_of_line eol_cmd," 
		+ "previous_char_cmd, next_char_cmd,"
		+ "previous_line_cmd, next_line_cmd,"
		+ "page_up, page_down, bob, eob,"
		%  + "skip_word bskip_word " % Shift_Ctrl_Right/Left
		);

% List of functions that delete the region (insert-functions)
%   Define 
%      variable CuaInsertReplacesRegion = ""
%   in your .jedrc if you don't want the region replaced by inserting
custom_variable("Cua_Replacing_Functions", "self_insert_cmd,yank,yp_yank,");


% --- Functions

static define before_key_hook (fun)
{
   if (is_substr(Cua_Unmarking_Functions, fun + ","))
     pop_mark_0();
   else if (is_substr(Cua_Replacing_Functions, fun + ","))
     del_region();
}

static define after_key_hook () {}  % dummy definition
static define after_key_hook ()
{
   !if (is_visible_mark())
     {
	remove_from_hook ("_jed_before_key_hooks", &before_key_hook);
	remove_from_hook ("_jed_after_key_hooks", &after_key_hook);
     }
}


% if no visible region is defined, set visible mark and key-hooks
define cua_mark ()
{
   !if (is_visible_mark)
     {
	push_visible_mark ();
	add_to_hook ("_jed_before_key_hooks", &before_key_hook);
	add_to_hook ("_jed_after_key_hooks", &after_key_hook);
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

% Insert selection at point
define cua_insert_clipboard()
{
   if (is_defined("x_insert_selection"))
     eval("x_insert_selection");
   else if (is_defined("x_insert_cutbuffer"))
     eval("x_insert_cutbuffer");
}

% Kill region with customizable function
define cua_kill_region ()
{
   if (CuaCopyToClipboard)
     copy_to_clipboard();
   yp_kill_region;
}

% Copy region with customizable function
define cua_copy_region ()
{
   if (CuaCopyToClipboard)
     copy_to_clipboard();
   yp_copy_region_as_kill;
}

% yank_pop or go_up (to have both on key Shift-Up)
define cua_shift_up_cmd () 
{
   if (LAST_KBD_COMMAND == "%yank%") 
     yp_yank_pop (); 
   else 
     {
	cua_mark (); 
	call ("previous_line_cmd");
     }
}

% yank_repop or go_down (to have both on key Shift-Down)
define cua_shift_down_cmd () 
{
   if (andelse
        {LAST_KBD_COMMAND == "%yank%"}
	{is_defined("yp_yank_repop")}
      ) 
     runhooks("yp_yank_repop");
   else 
     {
	cua_mark (); 
	call ("next_line_cmd");
     }
}

%!%+
%\function{delete_cmd}
%\synopsis{Delete of character or (if defined) region}
%\usage{Void delete_cmd ()}
%\description
%   Bind this to the Key_Delete, if you would like it to work 
%   context dependend
%\seealso{del, del_region}
%!%-
public define delete_cmd ()
{
   if (is_visible_mark) 
     del_region;
   else del;
}

% delete the char before the cursor or the region (if defined)
define backspace_cmd ()
{
   if (is_visible_mark) 
     del_region;
   else call("backward_delete_char_untabify");
}


% --- Keybindings

setkey ("cua_shift_up_cmd",                        Key_Shift_Up);
setkey ("cua_shift_down_cmd",       		   Key_Shift_Down);
setkey ("cua_mark; call(\"previous_char_cmd\")",   Key_Shift_Left);
setkey ("cua_mark; call(\"next_char_cmd\")",       Key_Shift_Right);
setkey ("cua_mark; call(\"page_up\")",             Key_Shift_PgUp);
setkey ("cua_mark; call(\"page_down\")",           Key_Shift_PgDn);
setkey ("cua_mark; bol",			   Key_Shift_Home);
setkey ("cua_mark; eol",			   Key_Shift_End);

setkey ("delete_cmd",           Key_Del);
setkey ("backspace_cmd",        Key_BS);

setkey ("yp_yank",		Key_Shift_Ins);
setkey ("cua_kill_region",  	Key_Shift_Del);
setkey ("cua_copy_region",	Key_Ctrl_Ins);


% some more keybinding suggestions:

% setkey ("pop_spot",             Key_Alt_Up);  
% setkey ("push_spot",	   	  Key_Alt_Down);
% setkey ("cua_insert_clipboard", Key_Alt_Ins);

runhooks("cuamark_hook");

provide ("cuamark");

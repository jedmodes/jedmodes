% cuamouse.sl: CUA-compatible mouse mode
%
% Copyright (c) 2006 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Version    1     1998 (published 15. 01. 03)
%            1.1   mark_word does no longer skip back to next word
%                  implemented mark_by_lines for right drag
% 2005-03-18 1.2   added some tm documentation
% 2005-07-05 1.3   added `xclip` workaround for interaction with QT
% 	     	   applications (tip by Jaakko Saaristo)
% 2006-02-15 1.4   made auxiliary variables static
% 2006-05-26 1.4.1 added missing autoload (J. Sommer)
% 2006-10-05 1.5   bugfixes after testing,
%                  use mark_word() from txtutils.sl (new dependency!)
% 		   use private variables instead of static ones
% 2007-10-23 1.5.1 provide("mouse") as mouse.sl does not do so
% 2008-02-06 1.6   * fix swapped args to click_in_region()
% 	     	     in cuamouse_left_down_hook()
% 	     	   * support for scroll-wheel
%		   * button-specific hooks with return values
% 2008-05-05 1.6.1 * use x_insert_selection() in cuamouse_insert()
% 	     	     (os.sl defines it, if it does not exist)
% 	     	   * remove `xclip` workaround, as PRIMARY selection
% 	     	     interaction should be ok by now
% 	     	     (but see cuamark.sl for CLIPBOARD selection handling).
% 2008-06-19 1.6.2 * re-introduce `xclip` workaround for X-selection bug
% 	     	     as the fix is only complete in 0.99.19
% 2008-12-16 1.6.3 * fix `xclip` insertion,
% 	     	     take pipe_region() return value from stack.
%
%
% Actions
% ========
%
% In the Text:
%
% Left click:
%    - no region defined: move point to mouse-cursor (mouse_goto_position)
%    - outside a region: undefine region
%    - inside a region: copy to selection and delete region ("pick")
%        + Shift:   copy to (yp)-yankbuffer
%
% Middle click:
%    - insert selection at mouse-cursor
%   Shift:
%      insert (yp)-yankbuffer (yank_from_jed)
%
% Right click:
%    - region defined: extend region to mouse-cursor (ggf exchange_point_and_mark first)
%    - no region defined: move point to mouse-cursor
%
% Left drag:
%    - define a region and copy to selection
% Middle drag:
%    - insert selection at mouse-point instead of point
% Right drag:
%    - mark by lines (or, as original left drag: mark but leave point)
%
% Statusline:
%
% Left click:
%    - next buffer (jed default)
% Right click:
%    - split window (jed default)
% TODO:
% Left drag: enlarge/shrink window
%
%----------------------------------------------------------------------------

% Requirements
% ------------

autoload("cua_mark", "cuamark");
autoload("mark_word", "txtutils");

% mouse.sl does not have a provide("mouse") line
% require("mouse");
() = evalfile("mouse");
provide("mouse");
provide("cuamouse");

% Customisation
% -------------

% Mouse_Wheel_Scroll_Lines is defined in mouse.sl but not documented:

%!%+
%\variable{Mouse_Wheel_Scroll_Lines}
%\synopsis{Number of lines to scroll per mouse-wheel event}
%\usage{variable Mouse_Wheel_Scroll_Lines = 3}
%\description
%  Number of lines a mouse whell event shall scroll at a time.
%\seealso{mouse_set_default_hook}
%!%-

%!%+
%\variable{CuaMouse_Use_Xclip}
%\synopsis{Use `xclip` instead of Jed's X selection interaction functions}
%\usage{Int_Type CuaMouse_Use_Xclip = 0}
%\description
%  Currently, a xjed selection doesnot paste into applications using the
%  QT toolkit (all KDE applications including Klipper, lyx-qt).
%
%  This workaround uses the command line tool `xclip` to copy the selected
%  text to the X selection and to insert from the X selection.
%
%  As it introduces a  dependency on `xclip` and some overhead, it is disabled
%  by default.
%\seealso{x_copy_region_to_selection, x_insert_selection}
%!%-
custom_variable("CuaMouse_Use_Xclip", 0);

% more customisation can be done by overruling the default hooks (see
% mouse_set_default_hook() and set_buffer_hook()).
%
% To quote the helpf for mouse_set_default_hook()
%
%   The meaning of these names should be obvious.  The second parameter,
%   `fun' must be defined as
%
%            define fun (line, column, btn, shift)
%
%   and it must return an integer.
%
%   `btn' indicates the button pressed and can take on the values
%      `1' left,
%      `2' middle,
%      `4' right,
%       8  wheel-up
%      16  wheel-down
%
%   `shift' can take on values
%      `0' no modifier key was pressed,
%      `1' SHIFT key was pressed, and
%      `2' CTRL key was pressed.
%
%   For more detailed information about the modifier keys, use the function
%   `mouse_get_event_info'.
%
%   When the hook is called, the editor will automatically change
%   to the window where the event occured.  The return value of
%   the hook is used to dictate whether or not hook handled the
%   event or whether the editor should switch back to the window
%   prior to the event.  Specifically, the return value is interpreted
%   as follows:
%
%      -1     Event not handled, pass to default hook.
%       0     Event handled, return [to GM] active window prior to event
%       1     Event handled, stay in current window.

% Private Variables
% -----------------

private variable Drag_Mode = 0;     % 0 no previous drag, 1 drag
private variable Clipboard = "";    % string where a mouse-drag is stored

% Functions
% ---------

%!%+
%\function{click_in_region}
%\synopsis{determine whether the mouse_click is in a region}
%\usage{Int click_in_region(line, col)}
%\description
%   Given the mouse click coordinates (line, col), the function
%   returns an Integer denoting:
%          -2   click "after" region
%          -1   click "before" region
%           0   no region defined
%           1   click in region
%           2   click in region but "void space" (i.e. past eol)
%\seealso{cuamouse_left_down_hook, cuamouse_right_down_hook}
%!%-
define click_in_region(line, col)
{
   !if(is_visible_mark())
     return 0;

   % Determine region boundries (region goes from (l_0, c_0) to (l_1, c_1)
   check_region(0);
   variable l_1 = what_line();
   variable c_1 = what_column();
   exchange_point_and_mark();
   variable l_0 = what_line();
   variable c_0 = what_column();
   exchange_point_and_mark();

   % vshow("region: [(%d,%d), (%d,%d)]", l_0, c_0, l_1, c_1);
   % Click before the region?
   if(orelse{line < l_0} {(line == l_0) and (col < c_0)})
     return -1;
   % click after the region (except last line)?
   if(line > l_1)
     return -2;
   % click in void space of region (past eol) or l_1 past endcol?
   push_spot();
   goto_line(line);
   variable eolcolumn = goto_column_best_try(col);
   pop_spot();
   if ((line == l_1) and (col >= c_1) and eolcolumn == col)
     return -2;
   if (eolcolumn < col)
     return 2;
   return 1;
}

% copy region to X-selection and internal clipboard (The region stays marked)
define copy_region_to_clipboard()
{
   % no copy if the region is void
   () = dupmark();
   if (bufsubstr() == "")
     return;
   % copy to PRIMARY x-selection or Windows clipboard
   () = dupmark();
   if (CuaMouse_Use_Xclip) {
      () = pipe_region("xclip");
   }
   else
      x_copy_region_to_selection();
   % copy to Jed-internal clipboard
   () = dupmark();
   Clipboard = bufsubstr();
}

% Insert x-selection (or, if (from_jed == 1), Clipboard) at point.
% wjed will insert the Windows clipboard
define cuamouse_insert(from_jed)
{
   if (from_jed)
      insert(Clipboard);
   else if (CuaMouse_Use_Xclip) {
      () = run_shell_cmd("xclip -o");
      update_sans_update_hook(1);
      % call("redraw");
   }
   else
      x_insert_selection();
}

% cursor follows mouse, scroll if pointer is outside window.
define cuamouse_drag(line, col)
{
   variable top, bot;
   variable y;

   mouse_goto_position(col, line);

   top = window_info ('t');
   bot = top + window_info('r');

   (,y, ) = mouse_get_event_info();

   if ((y < top) or (y > bot))
     x_warp_pointer();
}

% mark word
define cuamouse_2click_hook(line, col, but, shift)
{
   if (but == 1)
     {
	mouse_goto_position(col, line);
	mark_word();
	copy_region_to_clipboard(); % only if non-empty
	return 1;   		    % stay in current window
     }
   return -1;
}

% scroll with mouse-wheel events (but == 8 up, but == 16 down)
% see also Mouse_Wheel_Scroll_Lines
define cuamouse_wheel_hook(line, col, but, shift)
{
   % Variant with continuous point movement (as in mouse.sl)
   % variable l = window_line();
   % loop (Mouse_Wheel_Scroll_Lines)
   %   {
   % 	switch (but)
   % 	  { case 8:  skip_hidden_lines_backward (1); }
   % 	  { case 16: skip_hidden_lines_forward (1); }
   %   }
   % bol();
   % recenter(l);

   % Variant with point-wrap if it "falls of the screen"
   variable l = window_line();
   variable rows = window_info('r');

   switch (but)
     { case 8:  l += Mouse_Wheel_Scroll_Lines; } % wheel up
     { case 16: l -= Mouse_Wheel_Scroll_Lines; } % wheel down

   % wrap point if it leaves window
   if (l <= 0)
     {
   	l += Mouse_Wheel_Scroll_Lines;
   	loop (Mouse_Wheel_Scroll_Lines)
   	   skip_hidden_lines_forward(1);
     }
   if (l > rows)
     {
   	l -= Mouse_Wheel_Scroll_Lines;
   	loop (Mouse_Wheel_Scroll_Lines)
   	   skip_hidden_lines_backward(1);
	bol();
     }

   recenter(l);
   return 0;
}

% Button specific down hooks
% --------------------------

% Left button: goto position of pointer, if click-in-region, pick it
define cuamouse_left_down_hook(line, col, shift)
{
   switch (click_in_region(line, col))
     { case 1:
	   if (shift == 1)
	      yp_kill_region();
	   else
	     {
		copy_region_to_clipboard();
		del_region();
	     }
     }
     { % default
	if (is_visible_mark())           % undefine region if existent
	   pop_mark(0);
     }
   mouse_goto_position(col, line);
   return 1;                 % stay in current window
}

define cuamouse_middle_down_hook(line, col, shift)
{
   if (is_visible_mark())           % undefine region if existent
     pop_mark(0);
   mouse_goto_position(col, line);
   !if (input_pending(1))
      cuamouse_insert(shift);     % shift == 1: insert jed-clipboard
   % else
   %   show("input pending, maybe you scrolled too fast");
   return 1;   % stay in current window
}

define cuamouse_right_down_hook(line, col, shift)
{
   if (click_in_region(line, col) == -1)  % click "before" region
     exchange_point_and_mark();
   mouse_goto_position(col, line);
   return 1;                 % stay in current window
}

% Button specific drag hooks
% argument drag: Begin_Middle_End of drag: 0 Begin, 1 Middle, 2 End (up)

% mark region
define cuamouse_left_drag_hook(line, col, drag, shift)
{
   if (drag == 0)
     cua_mark();
   cuamouse_drag(line, col); % cursor follows mouse
   if (drag == 2) % last drag  (button up)
     copy_region_to_clipboard();
   return 1;
}

define cuamouse_middle_drag_hook(line, col, drag, shift)
{
   return -1;
}

% mark region by lines
define cuamouse_right_drag_hook(line, col, drag, shift)
{
   if (drag == 0)    % first drag
     {
	pop_mark_0();
	bol();
	cua_mark();
     }
   cuamouse_drag(line, col);
   eol();
   if (drag == 2) % last drag  (button up)
     copy_region_to_clipboard();
   return 1;
}

% Generic mouse hooks (down, drag, up)
% ------------------------------------

% down hook: calls the button specific ones
define cuamouse_down_hook(line, col, but, shift)
{
   switch (but)
     { case 1: return cuamouse_left_down_hook(line, col, shift); }
     { case 2: return cuamouse_middle_down_hook(line, col, shift); }
     { case 4: return cuamouse_right_down_hook(line, col, shift); }
     { case 8 or case 16: return cuamouse_wheel_hook(line, col, but, shift); }
}

% generic drag hook: calls the button specific ones
% with third argument Drag_Mode: 0 first drag, 1 subsequent drag
define cuamouse_drag_hook(line, col, but, shift)
{
   variable rv;
   switch (but)
     { case 1: rv = cuamouse_left_drag_hook(line, col, Drag_Mode, shift); }
     { case 2: rv = cuamouse_middle_drag_hook(line, col, Drag_Mode, shift);}
     { case 4: rv = cuamouse_right_drag_hook(line, col, Drag_Mode, shift); }
   Drag_Mode = 1;
   return rv;
}

% generic up hook: calls the button specific drag (!) hooks
% with third argument set to 2 (up = end of drag)
define cuamouse_up_hook(line, col, but, shift)
{
   if (Drag_Mode)
     {
	switch (but)
	  { case 1: cuamouse_left_drag_hook(line, col, 2, shift); }
	  { case 2: cuamouse_middle_drag_hook(line, col, 2, shift); }
	  { case 4: cuamouse_right_drag_hook(line, col, 2, shift); }
	Drag_Mode = 0;
     }
   return 1;
}

mouse_set_default_hook("mouse_2click", "cuamouse_2click_hook");
mouse_set_default_hook("mouse_down", "cuamouse_down_hook");
mouse_set_default_hook("mouse_drag", "cuamouse_drag_hook");
mouse_set_default_hook("mouse_up", "cuamouse_up_hook");
%mouse_set_default_hook("mouse_status_down", "mouse_status_down_hook");
%mouse_set_default_hook("mouse_status_up", "mouse_status_up_hook");

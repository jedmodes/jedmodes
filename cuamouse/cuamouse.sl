% file cuamouse.sl
% A more cua-compatible mouse mode
% by Guenter Milde (g.milde@physik.tu-dresden.de)
% 
% What does it do:
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
%    - no region defined: - insert selection at point (not at mouse-cursor!)   
%    - region defined: delete region and insert selection at point
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
%----------------------------------------------------------------------------

require ("mouse");

variable CuaMouse_Drag_Mode = 0;     % 0 no previous drag, 1 drag
variable CuaMouse_Return_Value = 1;  % return value for the mouse_hooks
  % -1 Event not handled, pass to default hook.
  %  0 Event handled, return active window prior to event
  %  1 Event handled, stay in current window.
variable CuaMouse_Clipboard = "";    % string where a mouse-drag is stored


% determine whether the mouse_click is in a region
% returns: -1 - click "before" region
%          -2 - click "after" region
%          -3 - click in region but "void space" (i.e. past eol)
%           0 - no region defined
%           1 - click in region
public define click_in_region(col,line)
{
   !if(is_visible_mark())
     return 0;
   check_region(0);                  % determine region boundries
   variable End_Line = what_line;
   variable End_Col = what_column;
   exchange_point_and_mark();
   variable Begin_Line = what_line;
   variable Begin_Col = what_column;
   exchange_point_and_mark();
   % click before the region?
   if((line < Begin_Line)  or ((line == Begin_Line) and (col <= Begin_Col)))
     return -1;
   % click after the region?
   if((line > End_Line) or ((line == End_Line) and (col >= End_Col)))
	return -2;
   % click in void space of region (past eol)?
   push_spot;
   goto_line (line);
   $1 = col - goto_column_best_try (col);
   pop_spot;
   if ($1)
     return -3;
   return 1;
}
       
  
% copy region to system and internal clipboards (The region stays marked)
public define copy_region_to_clipboard ()
{
   () = dupmark();                  % \
   if (bufsubstr() == "")           %  | no copy if the region is nil
     return;	      		    % /
   () = dupmark();		    
   if (is_defined("x_copy_region_to_selection"))
     eval("x_copy_region_to_selection");
   else if (is_defined("x_copy_region_to_cutbuffer"))
     eval("x_copy_region_to_cutbuffer");
   () = dupmark();		    
   CuaMouse_Clipboard = bufsubstr ();
}

% inserts selection (or, if (from_jed == 1), CuaMouse_Clipboard) at point
define cuamouse_insert(from_jed)
{
   if (from_jed)
     insert(CuaMouse_Clipboard);
   else
     {
   if (is_defined("x_insert_selection"))
     eval("x_insert_selection");
   else if (is_defined("x_insert_cutbuffer"))
     eval("x_insert_cutbuffer");
     }
}


% cursor follows mouse, warp if pointer is outside window.
define cuamouse_drag (col, line)
{
   variable top, bot;
   variable y;

   mouse_goto_position (col, line);
   
   top = window_info ('t');
   bot = top + window_info ('r');
   
   (,y, ) = mouse_get_event_info ();
   
   if ((y < top) or (y > bot))
     x_warp_pointer ();
}

% mark a word (to be bound to double-click)
% this function is hopefully some day part of the distro
static define mark_word ()
{
   bskip_word;
   call ("set_mark_cmd");
   skip_word;
}

define cuamouse_2click_hook (line, col, but, shift) %mark word
{
   if (but == 1)
     {
	mouse_goto_position (col, line);
	mark_word ();
	copy_region_to_clipboard;
	return 1;
     }
   return -1;
}	

% button specific down hooks
define	cuamouse_left_down_hook(line, col, shift)
{
   variable cir = click_in_region(col,line);
%    if (cir == -3)                     % click in region but void space
%      return;
   if (cir == 1)
     {
   	copy_region_to_clipboard;
   	del_region;
% 	CuaMouse_Return_Value = 0;          % return to prev window
% 	return ();
     }
   else if (is_visible_mark())           % undefine region if existent
     {
	pop_mark(0);
     }
   mouse_goto_position (col, line);
   CuaMouse_Return_Value = 1;                 % stay in current window
}

define	cuamouse_middle_down_hook(line, col, shift)
{
   if (is_visible_mark())           % undefine region if existent
     {
	pop_mark(0);
     }
   mouse_goto_position (col, line);
   cuamouse_insert (shift);     % shift == 1: insert jed-clipboard
   CuaMouse_Return_Value = 1;   % stay in current window
}

define	cuamouse_right_down_hook(line, col, shift)
{
   if (click_in_region(col, line) == -1)  % click "before" region   
     exchange_point_and_mark();
   mouse_goto_position (col, line);
   CuaMouse_Return_Value = 1;                 % stay in current window
}

% button specific drag hooks
% argument bme: Begin_Middle_End of drag: 0 Begin, 1 Middle, 2 End (up)
define	cuamouse_left_drag_hook(line, col, bme, shift)
{
   if (bme == 0)    
     cua_mark();
   cuamouse_drag (col, line);
   if (bme == 2) % last drag  (button up)
     copy_region_to_clipboard();
}

define	cuamouse_middle_drag_hook(line, col, bme, shift)
{ 
}

define	cuamouse_right_drag_hook(line, col, bme, shift)
{ 
   if (bme == 0)    % first drag
     cua_mark();
   cuamouse_drag (col, line);
   if (bme == 2) % last drag  (button up)
     copy_region_to_clipboard();
}

%generic down hook: calls the button specific ones
define cuamouse_down_hook (line, col, but, shift)
{
   if (but == 1)
     cuamouse_left_down_hook(line, col, shift);
   if (but == 2)
     cuamouse_middle_down_hook(line, col, shift);
   if (but == 4)
     cuamouse_right_down_hook(line, col, shift);
   return  CuaMouse_Return_Value;
}

% generic drag hook: calls the button specific ones
% with third argument CuaMouse_Drag_Mode: 0 first drag, 1 subsequent drag
define cuamouse_drag_hook (line, col, but, shift)
{
   if (but == 1)
     cuamouse_left_drag_hook(line, col, CuaMouse_Drag_Mode, shift);
   if (but == 2)
     cuamouse_middle_drag_hook(line, col, CuaMouse_Drag_Mode, shift);
   if (but == 4)
     cuamouse_right_drag_hook(line, col, CuaMouse_Drag_Mode, shift);
   CuaMouse_Drag_Mode = 1;
   return CuaMouse_Return_Value;
}

% generic up hook: calls the button specific drag (!) hooks 
% with third argument set to 2 (up = end of drag)
define cuamouse_up_hook (line, col, but, shift)
{
   !if (CuaMouse_Drag_Mode)
     return CuaMouse_Return_Value;
   if (but == 1)
     cuamouse_left_drag_hook(line, col, 2, shift);
   if (but == 2)
     cuamouse_middle_drag_hook(line, col, 2, shift);
   if (but == 4)
     cuamouse_right_drag_hook(line, col, 2, shift);
   CuaMouse_Drag_Mode = 0;
   return CuaMouse_Return_Value;
}
   

mouse_set_default_hook ("mouse_2click", "cuamouse_2click_hook");
mouse_set_default_hook ("mouse_down", "cuamouse_down_hook");
mouse_set_default_hook ("mouse_drag", "cuamouse_drag_hook");
mouse_set_default_hook ("mouse_up", "cuamouse_up_hook");
%mouse_set_default_hook ("mouse_status_down", "mouse_status_down_hook");
%mouse_set_default_hook ("mouse_status_up", "mouse_status_up_hook");

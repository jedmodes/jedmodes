% mousedrag.sl	-*- mode: Slang; mode: Fold -*-
% click-and-drag scrolling
%
% $Id: mousedrag.sl,v 1.1.1.1 2004/10/28 08:16:24 milde Exp $
% Keywords: mouse
%
% Copyright (c) 2003 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
%
% Hooks for scrolling by clicking and dragging. In drag mode, the buffer
% follows the mouse like the "hand" in graphics applications. In scroll
% mode, the window scrolls in the direction you drag in. When you release
% the mouse button, the window that was active is activated again.
%
% Dragging a statusbar will resize the window. The mouse_status_drag
% hook is only run when you drag the statusbar of the ACTIVE buffer,
% so the resizing functions have to be mixed up with the mousedrag-
% and mousescroll functions. There is no buffer-hook corresponding to
% the mouse_status_drag hook, so we set the default-mouse-hook. This
% means that you can evalfile this, and use the standard hooks for
% selecting text, but my status_drag hook for resizing the window,
% which may be more useful than randomly switching buffers. However,
% in that case you can only resize by dragging the statusbar of the
% active window (and the bottom window resizes the wrong way, and will
% only shrink when this is used in the console).
%
% To always use drag mode, add this to .jedrc
% mouse_set_default_hook("mouse_down", "mousedrag_down_hook");
% mouse_set_default_hook("mouse_drag", "mousedrag_drag_hook");
% mouse_set_default_hook("mouse_up", "mousedrag_up_hook");
% 
% You can't select text with the mouse anymore. If you want to select
% with the left button, scroll with the middle one, drag with the right
% one and delete with Ctrl-scroll, write your own hook.
% 
% Todo: integrate with mouse.sl and cuamouse.sl.


%{{{ scroll in place
define scroll_up_in_place ()
{
   variable m;
   m = window_line ();
   skip_hidden_lines_forward(1);
   recenter (m);
   bol ();
}

define scroll_down_in_place ()
{
   variable m;
   m = window_line ();
   skip_hidden_lines_backward(1);
   recenter (m);
   bol ();
}

%}}}

%{{{ hooks common to drag- and scroll mode

static variable dragging=0, status_clicked = 0;

define mousedrag_down_hook(line, col, but, shift)
{
   variable y;
   (, y, ) = mouse_get_event_info;

   % the mouse_status_hooks are only called when you click on the status
   % bar of the current window, and I want to resize even when I'm in the
   % bottom window.
   if (y == window_info('t') - 1)
     {
	status_clicked = 1;
     }
   else
     {
	goto_line(line);	% in the new buffer
	() = goto_column_best_try (col);
     }
   1;
}

% If we dragged, go back to the old window. If we clicked, stay here.
define mousedrag_up_hook(line, col, but, shift)
{
   not dragging and not status_clicked; % leave on stack
   dragging=0;
   status_clicked = 0;
}

%}}}

%{{{ scroll mode

% Drag the window by clicking, dragging and keeping the mouse down like
% in some windows programs.
define mousescroll_drag_hook(line, col, but, shift)
{
   dragging = 1;
   if (status_clicked)
     {
	variable y;
	(, y, ) = mouse_get_event_info;
	variable top = window_info('t');

	if ( y < top)
	  call("enlarge_window");
	else if (y > top)
	  {
	     otherwindow;
	     call("enlarge_window");
	  }
     }
   else
     {

	variable fun;
	if (line > what_line) fun = &scroll_up_in_place;
	else fun = &scroll_down_in_place;
	forever
	  {
	     @fun;
	     update_sans_update_hook(0);
	     if (input_pending(1)) break;
	  }
     }
   1;
}


%}}}

%{{{ drag mode

% Drag the text under the window, like in w3m or the "hand" function in
% some graphics programs.
define mousedrag_drag_hook(line, col, button, shift)
{
   dragging=1;
   variable y;
   (, y, ) = mouse_get_event_info;
   variable top = window_info('t'), bottom = top + window_info('r');

   if (status_clicked)
     {
	if ( y < top)
	  call("enlarge_window");
	else if (y > top)
	  {
	     otherwindow;
	     call("enlarge_window");
	  }
     }

   else
     {
	if (top < y and y <= bottom)
	  recenter(y - top);
     }
   update_sans_update_hook(1);
   1;
}


%}}}

%{{{ status line

define mousedrag_status_up_down_hook(l, c, b, s)
{
   1;
}

define mousedrag_status_hook(l, c, b, s)
{
   variable y;
   (, y, ) = mouse_get_event_info;
   if ( y > window_info('t') + window_info('r') + 1)
     call("enlarge_window");
   else if (y < window_info('t') + window_info('r') + 1)
     {
	otherwindow;
	call("enlarge_window");
     }
   1;
}


%}}}

public define mousescroll_mode()
{
   set_buffer_hook("mouse_drag", &mousescroll_drag_hook);
   set_buffer_hook("mouse_down", &mousedrag_down_hook);
   set_buffer_hook("mouse_up", &mousedrag_up_hook);
}

public define mousedrag_mode()
{
   set_buffer_hook("mouse_drag", &mousedrag_drag_hook);
   set_buffer_hook("mouse_down", &mousedrag_down_hook);
   set_buffer_hook("mouse_up", &mousedrag_up_hook);
}

mouse_set_default_hook("mouse_status_down", "mousedrag_status_up_down_hook");
mouse_set_default_hook("mouse_status_drag", "mousedrag_status_hook");
mouse_set_default_hook("mouse_status_up", "mousedrag_status_up_down_hook");

provide("mousedrag");

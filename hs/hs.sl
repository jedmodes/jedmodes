% hs.sl
% hide and show indented lines
% 
% $Id: hs.sl,v 1.1.1.1 2004/10/28 08:16:21 milde Exp $
% Keywords: convenience, tools, outlines, mouse
% 
% Copyright (c) 2003 Paul Boekholt
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This is for hiding and showing lines in an indented file, such as this
% one.  To see it in action, evalbuffer, use seldisp.sl to hide everything
% beyond column 1, type M-x hs_mode and right click to show lines.  See
% also: seldisp.sl, filter-view.sl, treemode.sl, outline.sl, folding.sl.

static define get_level()
{
   push_spot_bol;
   while (eolp) 
     !if (down_1) break;
   skip_white;
   what_column;
   pop_spot;
}

static define hs_hide()
{
   variable c = get_level;
   push_spot;
   forever
     {
	!if (down(1)) break;
	skip_white;
	!if (eolp)
	  !if (c < what_column)
	    break;
	set_line_hidden (1);
     }
   pop_spot;
}

static define hs_show()
{
   variable c;
   push_spot;
   skip_hidden_lines_forward(0);
   c = get_level;
   forever
     {
	!if (is_line_hidden)
	  break;
	skip_white;
	if (eolp or c >= what_column)
	  set_line_hidden (0);
	!if (down(1)) break;
     }
   pop_spot;
}

static define hs_mouse_hook(line, col, button, shift)
{
   if(button == 1)
     hs_show;
   else
     hs_hide;
   1;
}


public define hs_mode()
{
   set_buffer_hook("mouse_up", &hs_mouse_hook);
}

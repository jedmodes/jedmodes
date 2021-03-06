% navigate.sl: "history feature" known from many browsers.
%
% Store info about the last visited buffer with any buffer switch.
% Navigate between the recently visited buffers with Alt+Arrow.
%
% Copyright (c) 2006 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions
% ========
% 	      1.0
%             1.1   * Open closed buffers with recent.sl
%             1.2   * ... ask before reopening
%                   * bugfix in navigate: skip closed buffers
%                   * bugfix: use CURRENT_KBD_COMMAND instead of
%                     LAST_KBD_COMMAND (Adam Byrtek)
%                   * do not overwrite existing keybindings
%                     -> set keybindings in your .jedrc
%             1.3   * Reopen autogenerated buffers with blocal var
%             	      "generating_function"
%                   * new datatype BufferMark (save restoring information)
%                   * independend of recent.sl
% 2007-08-02  1.3.1 * blocal "generating_function" might now be
%                      Ref_Type, String_Type: function without args, or
%                      List_Type, Array_Type: function with args.
% 2008-05-05  1.3.1 * simplified testing appendix (the new sprint_var.sl can
%      		      handle user-defined data types)
% 2009-10-05  1.4   * define named namespace, remove debugging function

%
% USAGE  Put in the jed-library-path and do
%   	     require("navigate")
% 	 in your .jedrc
%
% CUSTOMIZATION
% 	 Bind navigate_back() and navigate_forward() to some keys
% 	 Example:
% 	 	setkey ("navigate_forward()",	  Key_Alt_Right);
% 		setkey ("navigate_back()",	  Key_Alt_Left);
% 	   will give you bindings as in Firefox or Konqueror.
% 	 Custom variables:            Default
% 	    Navigate_Stack_Size       10
% 	    Navigate_Restore_Buffers   2  (0 No, 1 Always, 2 Ask)
% 	    Navigate_Append_at_End"    0
%
% TODO   code cleanup

% _debug_info = 1;

% --- Requirements ------------------------------------------------------
require("keydefs"); % symbolic constants for many function and arrow keys
require("circle");  % "circular array" datatype for the history stack
autoload("get_blocal", "sl_utils");
autoload("push_defaults", "sl_utils");
autoload("run_function", "sl_utils");
autoload("what_line_if_wide", "sl_utils");
autoload("push_array", "sl_utils");
autoload("push_list", "datutils");
autoload("fold_open_fold", "folding");

% --- Custom Variables --------------------------------------------------

% Size of the navigation stack (won't change after loading navigate.sl)
custom_variable("Navigate_Stack_Size", 10);

% Do you want to restore closed buffers when passing by?
% 0 No, 1 Always, 2 Ask
custom_variable("Navigate_Restore_Buffers", 2);

% Do you want the new entries always appended at the end of the stack?
custom_variable("Navigate_Append_at_End", 0);
%   if 0, entries will be appended at current stack position, clipping
%         the ones one stepped back
%   if 1, no entries will be lost (at the cost of inconsistent manoeuvring)

% Name and Namespace
% ------------------

provide("navigate");
implements("navigate");

% Internal (static) Variables
% ---------------------------

!if (is_defined("BufferMark_Type"))
  typedef struct {
     name,    % buffer name
       file,    % full filename
       generating_function, % for autogenerated buffers,
                            % saved in blocal("generating_function")
       line,    % \_ Last editing point position
       column,  % /
  } BufferMark_Type;

% a circular array of recently visited buffers (History Stack)
% updated with every buffer switch (switch_active_buffer_hook)
static variable Navigation_Stack =
  create_circ(BufferMark_Type, Navigate_Stack_Size, "linear");

% --- Functions ---------------------------------------------------------

% Return a BufferMark with restoring information
define buffermark() % (buf=whatbuf)
{
   variable buf, dir, bmark = @BufferMark_Type;
   buf = push_defaults(whatbuf, _NARGS);

   (bmark.file, dir, bmark.name, ) = getbuf_info(buf);
   if (strlen(bmark.file))
     bmark.file = path_concat(dir, bmark.file);
   bmark.generating_function = get_blocal("generating_function", NULL);
   bmark.line = what_line_if_wide();
   bmark.column = what_column();
   return bmark;
}

% restore a closed buffer from the buffermark, return success
define reopen_buffer(bmark, ask)
{
   variable result;
   % is there information for reopening?
   if (andelse{bmark.file == ""}{bmark.generating_function == NULL})
     return 0;
   if(ask)
     {
	flush("Buffer " + bmark.name
	      + " no longer open. Press Enter to reopen!");
	variable key = getkey();
	if (key != '\r')  % Enter
	  {
	     ungetkey(key);
	     return 0;
	  }
     }
   % recreate the buffer
   if (strlen(bmark.file))
     result = find_file(bmark.file);
   else if (typeof(bmark.generating_function) == Array_Type)
     result = run_function(push_array(bmark.generating_function));
   else if (typeof(bmark.generating_function) == List_Type)
     result = run_function(push_list(bmark.generating_function));
   else
     result = run_function(bmark.generating_function);

   % goto saved position
   if (result and what_line() == 1)
     {
	goto_line(bmark.line);
 	() = goto_column_best_try(bmark.column);
	% open folds
	loop(count_narrows) % while (is_line_hidden) might cause an infinite loop!
	  if(is_line_hidden)
	    fold_open_fold();
     }
   !if (result)
     vmessage("Sorry. Cannot reopen %s", bmark.name);
   return result;
}

% argument is the buffer last visited
% (provided by _jed_switch_active_buffer_hooks but not used)
define navigate_append_buffermark(oldbuf)
{
   % show("navigate_append", whatbuf(), CURRENT_KBD_COMMAND);
   % no action if switch is caused by a navigate command
   if (CURRENT_KBD_COMMAND == "navigate_back" || 
       CURRENT_KBD_COMMAND == "navigate_forward")
      return;
     circ_append(Navigation_Stack, buffermark(), Navigate_Append_at_End);
}

static define navigate(bmark)
{
   if (buffer_visible(bmark.name))
     return pop2buf(bmark.name);
   if (bufferp(bmark.name))
     return sw2buf(bmark.name);
   if (Navigate_Restore_Buffers)
     !if(reopen_buffer(bmark, Navigate_Restore_Buffers - 1))
	  circ_delete(Navigation_Stack);
}

public define navigate_back()
{
   navigate(circ_previous(Navigation_Stack));
}

public define navigate_forward()
{
   navigate(circ_next(Navigation_Stack));
}

append_to_hook("_jed_switch_active_buffer_hooks", &navigate_append_buffermark);

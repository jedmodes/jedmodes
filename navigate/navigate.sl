% navigate.sl
% "history feature" (recent visited buffer) known from many browsers.
%
% Store info about the last visited buffer with any buffer switch.
% Navigate between the recently visited buffers with Alt+Arrow.
%
% Version 1.0

% --- Requirements ------------------------------------------------------
require("keydefs"); % symbolic names for keys
require("circle");  % "circular array" datatype for the history stack
%Test require("diagnose");
%Test static define show_history() {show(Recent_Buffers);}

% --- Custom Variables --------------------------------------------------

% Size of the navigation stack (won't change after loading navigate.sl)
custom_variable("Navigate_Stack_Size", 10);

% Do you want to restore closed buffers when passing by (needs recent.sl)?
custom_variable("Navigate_Restore_Buffers", 1);

% Do you want the new entries always appended at the end of the stack?
custom_variable("Navigate_Append_at_End", 0);
%   if 0, entries will be appended at current stack position, clipping
%         the ones one stepped back
%   if 1, no entries will be lost (at the cost of inconsistent maneuvering)


% --- Internal (static) Variables ---------------------------------------

% a circular array of recently visited buffers (History Stack)
% updated with every buffer switch (switch_active_buffer_hook)
static variable Navigation_Stack =
  create_circ(String_Type, Navigate_Stack_Size, "linear");

% --- Functions ---------------------------------------------------------

% argument is the buffer last visited
define navigate_append_buffer(oldbuf)
{
   %Test show("navigate_append", whatbuf(), "navigating:", navigating);
   % no action if switch is coused by a navigate command
   !if (LAST_KBD_COMMAND == "navigate_back" 
	or LAST_KBD_COMMAND == "navigate_forward")
     circ_append(Navigation_Stack, whatbuf(), Navigate_Append_at_End);
}

append_to_hook("_jed_switch_active_buffer_hooks", &navigate_append_buffer);

static define navigate(buf)
{
   if (buffer_visible(buf))
     pop2buf(buf);
   else if (bufferp(buf))
     sw2buf(buf);
   else if (Navigate_Restore_Buffers and is_defined("recent_restore_buffer"))
     eval("recent_restore_buffer(\"" + buf + "\");");
   else
     % TODO: restore some buffers from command (*help*, ...)
     message("Buffer " + buf + " no longer open");
}

public define navigate_back()
{
   navigate(circ_previous(Navigation_Stack));
}

public define navigate_forward()
{
   navigate(circ_next(Navigation_Stack));
}

setkey ("navigate_forward()",	  Key_Alt_Right);
setkey ("navigate_back()",	  Key_Alt_Left);

provide("navigate");

% helper functions for the cua suite
% "Outsourced" from cua.sl, so they can be used by other emulations as well.
%
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Changelog:
%            1   first public version
%            1.1 repeat search opens the Search menu if LAST_SEARCH is empty
%            1.2 menu_select_menu to keep bw compatibility with jed < 0.9.16
% 2004-01-23 1.3 "region aware" functions delete_cmd, bdelete_cmd
%                call to menu in repeat_search wrapped in runhooks()

% slang-emulation of menu_select_menu to keep bw compatibility with jed < 0.9.16
#ifnexists menu_select_menu
   public define menu_select_menu(menu_name)
   {
      variable hotkeys = where(bstring_to_array(menu_name) == '&') + 1;
      hotkeys = strlow(menu_name[hotkeys]);
      foreach (hotkeys[[-1:0:-1]])
         ungetkey();
      call("select_menubar");
   }
#endif

%!%+
%\function{cua_delete_word}
%\synopsis{Delete the current word (or a defined region)}
%\usage{ Void cua_delete_word ()}
%\description
%   cua_delete_word is somewhat context sensitive:
%    * Delete from the current position to the end of a word.
%    * If there is just whitespace following the editing point, delete it.
%    * If there is any other non-word char, delete just one char.
%    * If a region is defined, delete it (instead of the above actions).
%   This way, you can do a "piecewise" deletion by repeatedly pressing
%   the same key-combination.
%\notes
%   This is a slightly modified version of the ide_delete_word function form
%   Guido Gonzatos ide.sl mode, put here to be usable also with other emulations.
%\seealso{delete_word, delete_cmd, cua_kill_region}
%!%-
public define cua_delete_word ()		% ^T, Key_Ctrl_Del
{
   !if (is_visible_mark)
     {
	variable p = POINT, l = what_line();
	push_mark ();
	skip_chars (get_word_chars());
	if (POINT == p)
	  skip_chars (" \n\t");
	if (POINT == p and what_line() == l)
	  go_right (1);
     }
  del_region ();
}

% Context sensitive backwards deleting, again taken from ide.sl
define cua_bdelete_word ()              % Key_Ctrl_BS
{
   variable p = POINT, l = what_line(); % see _get_point
   push_mark ();
   bskip_chars ("a-zA-Z0-9");
   if (POINT == p)
     bskip_chars (" \n\t");
   if (POINT == p and what_line() == l)
     go_left (1);
   del_region ();
}

%!%+
%\function{delete_cmd}
%\synopsis{Delete current character or (if defined) region}
%\usage{Void delete_cmd ()}
%\description
%   Bind to the Key_Delete, if you want it to work "region aware"
%\seealso{bdelete_cmd, del, del_region}
%!%-
public define delete_cmd ()
{
   if (is_visible_mark)
     del_region;
   else del;
}

%!%+
%\function{delete_cmd}
%\synopsis{Delete the char before the cursor or the region (if defined)}
%\usage{Void bdelete_cmd ()}
%\description
%   Bind to the Key_BS, if you want it to work "region aware"
%\seealso{delete_cmd, backward_delete_char, backward_delete_char_untabify}
%!%-
define bdelete_cmd ()
{
   if (is_visible_mark)
     del_region;
   else call("backward_delete_char_untabify");
}

%!%+
%\function{next_buffer}
%\synopsis{Cycle through the list of buffers}
%\usage{Void next_buffer ()}
%\description
%   Switches to the next in the list of buffers.
%\notes
%   (This is the same function as mouse_next_buffer in mouse.sl)
%\seealso{buffer_list, list_buffers}
%!%-
public define next_buffer ()
{
   variable n, buf, cbuf = whatbuf ();

   n = buffer_list ();		       %/* buffers on stack */
   loop (n)
     {
	buf = ();
	n--;
	if (buf[0] == ' ') % hidden buffers like " <mini>"
	  continue;
	sw2buf (buf);
	_pop_n (n);
	return;
     }
}

%!%+
%\function{redo}
%\synopsis{Undo the last undo}
%\usage{Void redo()}
%\description
%   Undo the last undo. This works only one step, however
%   as any undo is appended to the end of the undo buffer, you can
%   actually roll the whole history back.
%\seealso{undo}
%!%-
public define redo ()
{
   ERROR_BLOCK {call("undo");};
   call("kbd_quit");
}

%!%+
%\function{repeat_search}
%\synopsis{continue searching with last searchstring}
%\usage{define repeat_search ()}
%\seealso{LAST_SEARCH, search_forward, search_backward}
%!%-
public define repeat_search ()
{
   !if (strlen(LAST_SEARCH))
     {
	message("no previous search");
	return runhooks("menu_select_menu", "Global.&Search");
     }
   go_right (1);
   !if (fsearch(LAST_SEARCH)) error ("Not found.");
}

%!%+
%\function{toggle_case_search}
%\synopsis{toggle the CASE_SEARCH variable}
%\usage{Void toggle_case_search ()}
%\seealso{CASE_SEARCH}
%!%-
public define toggle_case_search ()
{
   variable off_on = ["Off", "On"];
   CASE_SEARCH = not(CASE_SEARCH);
   message("Case Search " + off_on[CASE_SEARCH]);
}

%!%+
%\function{indent_region_or_line}
%\synopsis{Indent the current line or (if defined) the region}
%\usage{Void indent_region_or_line ()}
%\description
%   Call the indent_line_hook for every line in a region.
%   If no region is defined, call it for the current line.
%\seealso{indent_line, set_buffer_hook, is_visible_mark}
%!%-
public define indent_region_or_line ()
{
   !if(is_visible_mark)
     indent_line;
   else
     {
	check_region (1);                  % make sure the mark comes first
	variable End_Line = what_line;
	exchange_point_and_mark();         % now point is at start of region
	while (what_line <= End_Line)
	  {indent_line; down_1;}
	pop_mark (0);
	pop_spot;
      }
}

% --- Use the ESC key as abort character (still experimental)

%!%+
%\function{escape_cmd}
%\synopsis{Escape from a command/aktion}
%\usage{ escape_cmd()}
%\description
%   Undo/Stop an action. If a region is defined, undefine it. Else
%   call kbd_quit.
%\seealso{kbd_quit}
%!%-
define escape_cmd()
{
   if (Menus_Active)
     ungetkey("\e");
   else if (is_visible_mark)
     pop_mark(0);
   else
     call ("kbd_quit");
}

%!%+
%\function{meta_escape_cmd}
%\synopsis{Distinguish the ESC key from other keys starting with "\e"}
%\usage{Void meta_escape_cmd()}
%\description
%   If there is input pending (i.e. if the keycode is multi-character),
%   "\e" will be put back to the input stream. Otherwise (if the
%   ESC key is pressed, "\e\e\e" is pushed back. With ALT_CHAR = 27, the Alt
%   key can be used as Meta-key as usual (i.e. press both ALT + <some-key>
%   to get the equivalent of the ESC <some-key> key sequence.
%\seealso{escape_cmd, one_press_escape, kbd_quit, map_input, setkey}
define meta_escape_cmd ()
{
   if (input_pending(0))
     ungetkey (27);
   else
     buffer_keystring("\e\e\e");
}

%!%+
%\function{one_press_escape}
%\synopsis{Redefine the ESC key to issue "\e\e\e"}
%\usage{one_press_escape()}
%\description
%   Dependend on the jed-version, either x_set_keysym or
%   meta_escape_cmd is used to map the ESC key to "\e\e\e"
%\example
% To let the ESC key abort functions but retain bindings for
% keystrings that start with "\e" do
%#v+
%    one_press_escape();
%    setkey ("escape_cmd", "\e\e\e");     % Triple-Esc -> abort
%#v-
%\notes
%   The function is experimental and has sideeffects if not using xjed.
%   For not-x-jed:
%
%   It uses the "^^" character for temporarily remapping, i.e. Ctrl-^ will
%   call meta_escape_cmd().
%
%   In order to work, it must be loaded before any mode-specific keymaps are
%   defined -- otherwise this modes will be widely unusable due to not
%   working cursor keys...!
%
%   It breaks functions that rely on getkey() (e.g. isearch, showkey, old
%   wmark(pre 99.16), ...). These functions see ctrl-^ instead of \e.
%
%   It will not work in keybord macros and might fail on slow terminal links.
%
%\seealso{escape_cmd, meta_escape_cmd, getkey, setkey, x_set_keysym}
%!%-
define one_press_escape()
{
   if (is_defined("x_set_keysym"))
     runhooks("x_set_keysym", 0xFF1B, 0, "\e\e\e");   % one-press-escape
   else
     {
	map_input(27, 30);  % "\e" -> "^^" ("^6" on most keybords, undo in wordstar)
	setkey ("meta_escape_cmd", "^^");
     }
}

% New function save_buffer_as: Similar to the internal write_buffer
% (not the intrinsic write_buffer(buf)!) but asks for overwrite.

%{{{ save_buffer_as(force_overwrite = 0)
%!%+
%\function{save_buffer_as}
%\synopsis{Save the buffer to a different file/directory}
%\usage{Void save_buffer_as(force_overwrite=0)}
%\description
%   Asks for a new filename and saves the buffer under this name.
%   Asks before overwriting an existing file, if not called with
%   force_overwrite=1.
%   Sets readonly flag to 0, becouse if we are able to write,
%   we can also modify.
%\seealso{save_buffer, write_buffer}
%!%-
define save_buffer_as()
{
   variable force_overwrite = 0;
   if (_NARGS)
     force_overwrite = ();

   variable file = read_file_from_mini("Save %s to:");
   if (file_status(file) == 2) % directory
     file += extract_element(whatbuf(), 0, ' ');
   if (file_status(file) == 1 and not(force_overwrite)) % file exists
     if(get_y_or_n(sprintf("File \"%s\" exists, overwrite?", file)) != 1)
       return;
   () = write_buffer(file);
} add_completion("save_buffer_as");
%}}}

%{{{ save_buffer()
%!%+
%\function{save_buffer}
%\synopsis{save_buffer}
%\usage{Void save_buffer();}
%\description
% Save current buffer.
%!%-
define save_buffer()
{
   variable file;

   !if (buffer_modified())
     {
	message("Buffer not modified.");
	return;
     }

   file = buffer_filename();
   !if (strlen(file))
       save_buffer_as();

   () = write_buffer(file);

} add_completion("save_buffer");
%}}}

% this is an enhancement/fix of the function in site.sl that produces two
% buffers with indentical names if a buffer with this name already
%   exists.)

%!%+
%\function{rename_buffer}
%\synopsis{rename the buffer, overwriting an existing buffer}
%\usage{ Void rename_buffer (String name, [Integer force_overwrite])}
%\description
%   renames the active buffer to name, if a buffer of this name already
%   exists, ask before overwriting (i.e.  deleting the existing buffer).
%   (The optional argument force_overwrite skips the question)
%\seealso{rename_buffer}
%!%-
define rename_buffer() % (name, [force_overwrite])
{
   variable name, force_overwrite = 0;
   if (_NARGS == 2)
     force_overwrite = ();
   name = ();

   if (bufferp(name))
     {
	!if (force_overwrite)
	  if(get_y_or_n("Buffer exists, overwrite?") != 1)
	    return;
	delbuf(name);
     }
   variable flags = getbuf_info();
   pop();
   setbuf_info(name, flags);
}

provide ("cuamisc");


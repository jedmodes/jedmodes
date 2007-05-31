% cuamisc.sl: helper functions for the cua suite
%
% Copyright (c) 2006 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Changelog:
%            1   first public version
%            1.1 repeat search opens the Search menu if LAST_SEARCH is empty
%            1.2 menu_select_menu to keep bw compatibility with jed < 0.9.16
% 2004-01-23 1.3 "region aware" functions delete_cmd, bdelete_cmd
%            1.3.1 new implementation of redo by JED
%            1.4 next_buffer cycles in two directions (Dave Kuhlman)
% 2004-08-26 1.4.1 fixed small documentation typo in bdelete_cmd
% 2005-03-21 1.4.2 added missing tm-documentation block marker
% 2005-05-25 1.5   bugfixes and merge with version 1.1.1 from jed 0.99-17
%                  * generally, let function names start with "cua_"
%                  * removed optional arg 'force_overwrite' from
%                    save_buffer_as() (use call("write_buffer") instead)
%                  * improved redo() no longer toggles last undo
% 2005-06-07 1.5.1 * removed the "generic" functions
% 	     	     (for older jed versions, they are now accessible
% 	     	     in compat17-16.sl, compat16-15.sl)
% 2006-01-17 1.5.2 * some more tweaks and upload to jedmodes
% 2006-03-20 1.6   * name change: cua_meta_escape_cmd() -> cua_escape_handler()
%                  * [cua_]indent_region_or_line() moved to txtutils.sl
%                    (http://jedmodes.sf.net/mode/txtutils/)
% 2006-03-23 1.6.1 * cua_repeat_search() now searches across lines and has
%                    optional arg `direction'
% 2007-05-14 1.6.2 * removed ``add_completion("cua_save_as")``
% 	     	   * added Joergs Sommers jbol()
% 2007-05-31 1.6.3 * fix documentation of jbol()	     	   


provide ("cuamisc");

autoload("search_across_lines", "search");

%!%+
%\function{cua_delete_char}
%\synopsis{Delete current character (or a visible region)}
%\usage{Void cua_delete_char()}
%\description
%   Bind to the Key_Delete, if you want it to work "region aware"
%\seealso{bcua_delete_char, del, del_region}
%!%-
public define cua_delete_char()
{
   if (is_visible_mark)
     del_region;
   else 
     del;
}

%!%+
%\function{cua_bdelete_char}
%\synopsis{Delete the char before the cursor (or a visible region)}
%\usage{Void cua_bdelete_char ()}
%\description
%   Bind to the Key_BS, if you want it to work "region aware"
%\seealso{cua_delete_char, backward_delete_char, backward_delete_char_untabify}
%!%-
public define cua_bdelete_char()
{
   if (is_visible_mark)
     del_region;
   else call("backward_delete_char_untabify");
}

%!%+
%\function{cua_delete_word}
%\synopsis{Delete the current word (or a visible region)}
%\usage{ Void cua_delete_word ()}
%\description
%  Delete either
%    * a visible region,
%    * from the current position to the end of a word,
%    * whitespace following the editing point, or
%    * one non-word char.
%  This way, you can do a "piecewise" deletion by repeatedly pressing
%  the same key-combination.
%\notes
%  This is a modified version of \sfun{ide_delete_word} from Guido Gonzatos
%  ide emulation, put here to be usable with other emulations too.
%\seealso{delete_word, cua_bdelete_word, cua_delete_char, cua_kill_region}
%!%-
public define cua_delete_word ()		% ^T, Key_Ctrl_Del
{
   !if (is_visible_mark)
     {
	variable m = create_user_mark ();
	push_mark ();
	skip_chars (get_word_chars());
	if (create_user_mark () == m) skip_chars (" \n\t");
	if (create_user_mark () == m) go_right (1);
     }
  del_region ();
}

%!%+
%\function{cua_bdelete_word}
%\synopsis{Backwards delete the current word (or a visible region)}
%\usage{ cua_bdelete_word ()}
%\description
%  Delete either
%    * a visible region,
%    * from the current position to the start of a word,
%    * whitespace preceding the editing point, or
%    * one non-word char.
%   This way, you can do a "piecewise" deletion by repeatedly pressing
%   the same key-combination.
%\notes
%  This is a modified version of \sfun{ide_bdelete_word}, put here to be usable
%  with other emulations too.
%\seealso{cua_delete_word, cua_delete_char}
%!%-
define cua_bdelete_word ()              % Key_Ctrl_BS
{
   push_mark ();
   variable m = create_user_mark ();
   bskip_chars ("a-zA-Z0-9");
   if (create_user_mark () == m) bskip_chars (" \n\t");
   if (create_user_mark () == m) go_left (1);
   del_region ();
}

%!%+
%\function{cua_repeat_search}
%\synopsis{continue searching with last searchstring}
%\usage{cua_repeat_search(direction=1)}
%\description
%  Search for the next occurence of \var{LAST_SEARCH}.
%  If \var{direction} => 0, search forward, 
%  else search backward.
%\notes
%  I'd like to see this function as repeat_search() in search.sl.
%  It could be used in ide_repeat_search, ws_repeat_search and most.
%\seealso{search_forward, search_backward, isearch_forward}
%!%-
public define cua_repeat_search() % (direction=1)
{
   variable steps, direction = 1;
   if (_NARGS)
     direction = ();
   !if (strlen(LAST_SEARCH))
     return menu_select_menu("Global.&Search");
   steps = right(1);
   if (search_across_lines (LAST_SEARCH, direction) < 0)
     {
        go_left(steps);
        error ("Not found.");
     }
}

% --- Use the ESC key as abort character (still experimental)

custom_variable("Key_Esc", "\e\e\e");

%!%+
%\function{cua_escape_cmd}
%\synopsis{Escape from a command/aktion}
%\usage{cua_escape_cmd()}
%\description
%   Undo/Stop an action. If a (visible) region is defined, undefine it. Else 
%   call kbd_quit.
%\seealso{kbd_quit, is_visible_mark}
%!%-
define cua_escape_cmd()
{
  if (is_visible_mark)
    pop_mark(0);
  else
    call ("kbd_quit");
}

%!%+
%\function{cua_escape_handler}
%\synopsis{Distinguish the ESC key from other keys starting with "\e"}
%\usage{Void cua_escape_handler()}
%\description
%  If there is input pending (i.e. if the keycode is multi-character), "\\e"
%  will be put back to the input stream. Otherwise (assuming the ESC key
%  is pressed), the value of \var{Key_Esc} is pushed back. 
%  
%  With ALT_CHAR = 27, the Alt  key can be used as Meta-key as usual (i.e.
%  press both ALT + <some-key>  to get the equivalent of the ESC <some-key>
%  key sequence.
%\seealso{cua_escape_cmd, cua_one_press_escape}
%!%-
define cua_escape_handler ()
{
   if (input_pending(0))
     ungetkey (27);
   else
     buffer_keystring(Key_Esc);
}

%!%+
%\function{cua_one_press_escape}
%\synopsis{Let the ESC key issue the value of \var{Key_Esc}}
%\usage{cua_one_press_escape()}
%\description
% Dependend on the jed-version, either \sfun{x_set_keysym} or
% \sfun{meta_escape_cmd} is used to map the ESC key to the value of
% \var{Key_Esc}.
%\example
% To let the ESC key abort functions but retain bindings for
% keystrings that start with "\\e" do
%#v+
%    cua_one_press_escape();
%    setkey("cua_escape_cmd", Key_Esc);     % Esc -> abort
%#v-
%\notes
%   The function is experimental and has sideeffects if not using xjed.
%   For not-x-jed:
% 
%   It uses the "^^" character for temporarily remapping, i.e. Ctrl-^ will
%   call cua_escape_handler().
% 
%   In order to work, it must be loaded before any mode-specific keymaps are
%   defined -- otherwise this modes will be widely unusable due to not 
%   working cursor keys...!
%   
%   It breaks functions that rely on getkey() (e.g. isearch, showkey, old
%   wmark(pre 99.16), ...). These functions see ctrl-^ instead of \\e.
%   
%   It will not work in keybord macros and might fail on slow terminal links.
%\seealso{cua_escape_cmd, cua_escape_handler, getkey, setkey, x_set_keysym}
%!%-
define cua_one_press_escape()
{
   if (is_defined("x_set_keysym"))
     call_function ("x_set_keysym", 0xFF1B, 0, "\e\e\e");   % one-press-escape
   else
     {
	map_input(27, 30);  % "\e" -> "^^" ("^6" on most keybords, undo in wordstar)
	setkey ("cua_escape_handler", "^^");
     }
}

%!%+
%\function{cua_save_buffer}
%\synopsis{Save the current buffer}
%\usage{cua_save_buffer()}
%\description
% Save current buffer to the associated file. Asks for a filename if there is
% no file associated to the buffer.
%\seealso{save_buffer, buffer_filename, save_buffer_as}
%!%-
define cua_save_buffer()
{
   variable file;
   
   file = buffer_filename();
   if (file == "")           % buffer was never saved
     {
        save_buffer_as();
        return;
     }

   !if (buffer_modified())
     {
	message("Buffer not modified.");
	return;
     }
   
   () = write_buffer(file);

}

%!%+
%\function{jbol}
%\synopsis{Jumps to the begin of line or the first non-space character}
%\usage{jbol(skip_white)}
%\description
% Move the point to either the first column or the first non-white character
% of a line. The first call to \sfun{jbol} calls either \sfun{bol} or
% \sfun{bol_skip_white}, depending on the setting of the \var{skip_white}
% argument. Subsequent calls will jump between column 1 and the first
% non-white character.
%\example
% Get the behaviour of gedit with
%#v+
%   setkey("jbol(0)",                    Key_Home); % move to bol first
%#v-
% or the behaviour of jEdit, NetBeans, SciTe, or Boa Constructor with
%#v+
%   setkey("jbol(1)",                    Key_Home); % bol-skip-white first
%#v-
%\notes
% It's really handy if you use indention.
%\seealso{beg_of_line, bol, LAST_KBD_COMMAND}
%!%-
public define jbol(skip_white)
{
   if (skip_white)
     bol_skip_white();
   else
     bol();
   if (LAST_KBD_COMMAND == "jbol")
   {
     if (bolp())
       skip_white();
     else
       bol();
   }
}

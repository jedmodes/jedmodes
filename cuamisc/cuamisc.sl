% cuamisc.sl: helper functions for the cua suite
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
%  This is a modified version of \var{ide_delete_word} from Guido Gonzatos
%  ide emulatio, put here to be usable with other emulations too.
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
%  This is a modified version of \var{ide_bdelete_word}, put here to be usable
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
   else del;
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
%\function{cua_repeat_search}
%\synopsis{continue searching with last searchstring}
%\usage{define repeat_search ()}
%\description
%  Search forward for the next occurence of \var{LAST_SEARCH}.
%\seealso{search_forward, search_backward, isearch_forward}
%!%-
public define cua_repeat_search ()
{
   !if (strlen(LAST_SEARCH))
     return menu_select_menu("Global.&Search");
   go_right (1);
   !if (fsearch(LAST_SEARCH)) error ("Not found.");
}

% --- Use the ESC key as abort character (still experimental)

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
%\function{cua_meta_escape_cmd}
%\synopsis{Distinguish the ESC key from other keys starting with "\e"}
%\usage{Void cua_meta_escape_cmd()}
%\description
%   If there is input pending (i.e. if the keycode is multi-character),
%   "\\e" will be put back to the input stream. Otherwise (if the
%   ESC key is pressed, "\\e\\e\\e" is pushed back. With ALT_CHAR = 27, the Alt 
%   key can be used as Meta-key as usual (i.e. press both ALT + <some-key> 
%   to get the equivalent of the ESC <some-key> key sequence.
%\seealso{cua_escape_cmd, cua_one_press_escape, kbd_quit, map_input, setkey}
%!%-
define cua_meta_escape_cmd ()
{
   if (input_pending(0))
     ungetkey (27);
   else
     buffer_keystring("\e\e\e");
}

%!%+
%\function{cua_one_press_escape}
%\synopsis{Redefine the ESC key to issue "\\e\\e\\e"}
%\usage{cua_one_press_escape()}
%\description
%   Dependend on the jed-version, either x_set_keysym or 
%   meta_escape_cmd is used to map the ESC key to "\\e\\e\\e"
%\example
% To let the ESC key abort functions but retain bindings for
% keystrings that start with "\\e" do
%#v+
%    cua_one_press_escape();
%    setkey ("cua_escape_cmd", "\e\e\e");     % Triple-Esc -> abort
%#v-
%\notes
%   The function is experimental and has sideeffects if not using xjed.
%   For not-x-jed:
% 
%   It uses the "^^" character for temporarily remapping, i.e. Ctrl-^ will
%   call cua_meta_escape_cmd().
% 
%   In order to work, it must be loaded before any mode-specific keymaps are
%   defined -- otherwise this modes will be widely unusable due to not 
%   working cursor keys...!
%   
%   It breaks functions that rely on getkey() (e.g. isearch, showkey, old
%   wmark(pre 99.16), ...). These functions see ctrl-^ instead of \\e.
%   
%   It will not work in keybord macros and might fail on slow terminal links.
%\seealso{cua_escape_cmd, cua_meta_escape_cmd, getkey, setkey, x_set_keysym}
%!%-
define cua_one_press_escape()
{
   if (is_defined("x_set_keysym"))
     call_function ("x_set_keysym", 0xFF1B, 0, "\e\e\e");   % one-press-escape
   else
     {
	map_input(27, 30);  % "\e" -> "^^" ("^6" on most keybords, undo in wordstar)
	setkey ("cua_meta_escape_cmd", "^^");
     }
}

%{{{ cua_save_buffer()
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
   if (file == "")
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

} add_completion("cua_save_buffer");
%}}}

provide ("cuamisc");

% bufutils.sl  Tools for buffer and windows handling
%
% Copyright (c) 2003 Günter Milde
% Released under the terms% of the GNU General Public License (version 2 or later).
%
% Version 1.0   first public version
%         1.1   bugfix: restore_buffer now resets the "changed on disk" flag
%         1.2   new: "blocal_hooks"
%         1.2.2 "outsourcing" of window_set_rows (hint by Thomas Clausen)
%	  1.3   moved most often used programming helpers to sl_utils.sl
%	        new: (key_prefix="") argument to rebind, rebind_reserved
%	             (hint and bugfix Paul Boekholt)
%	        rework of popup_buffer
%	          - do not reuse popups
%	          - reload old buffer when closing (Paul Boekholt)
%	  1.4   new: help_message(): Give mode-dependend help message
%	             arrayread_file(name): read file to array (P. Boekholt)
%	        changed: close_buffer calls blocal_hook
%	                 popup_buffer uses this
%	  	moved next_buffer() to cuamisc.sl
%	  	renamed restore_buffer to reload_buffer (this is what it does)
%	  1.4.1 bugfix popup_buffer/close_buffer/popup_close_buffer_hook
%	        bugfix reload_buffer() reset "changed on disk" flag
%	                               before reloading,
%	                               reset buffer_modified flag
%	  1.5   (2004-03-17)
%	        new function bufsubfile() (save region|buffer to a tmp-file)
%	  1.5.1 (2004-03-23)
%	        bugfix: spurious ";" in delete_temp_files() 
%	        (helper for bufsubfile)
%	  1.6   moved untab_buffer from recode.sl here
%	  1.6.1 small bugfix in bufsubfile()

% --- Requirements ----------------------------------------------------

require("keydefs");
autoload("get_blocal", "sl_utils");
autoload("push_defaults", "sl_utils");
autoload("run_function", "sl_utils");
autoload("get_word", "txtutils");
autoload("mark_word", "txtutils");

% --- Variables -------------------------------------------------------

% A help string for modes to be shown on the message-line
variable Help_Message = Assoc_Type[String_Type, "no help available"];

% --- Functions -------------------------------------------------------

% Convert the modename to a canonic form (the donwcased first part)
% This can be used for mode-dependend help, variables, ...
define normalized_modename() % (mode=get_mode_name)
{
   variable mode;
   mode = push_defaults(get_mode_name, _NARGS);
   mode = extract_element (mode, 0, ' ');
   if (mode == "")
     mode = "no";
   return strlow (mode);
}

% Set the mode-dependend string with help (e.g. on keybindings)
define set_help_message() % (str, mode=normalized_modename())
{
   variable str, mode;
   (str, mode) = push_defaults( , normalized_modename(), _NARGS);
   Help_Message[mode] = str;
}

% Show a mode-dependend string with help (e.g. on keybindings)
define help_message()
{
  message(Help_Message[normalized_modename]);
}

% --- Buffer local hooks  -----------------------------------------------
%
% Tools for the definition and use of buffer local hooks -- just like the
% indent_hook or the newline_and_indent_hook jed already provides.
% Extend this idea to additional hooks that can be set by a mode and used by
% another. Allows customizatin to be split in the "language" mode that
% provides functionality and the "emulation" mode that does the keybinding.
%
% Implementation is done via blocal vars. The hook can either be given as
% a pointer (reference) to a function or as the function name as string.

%!%+
%\function{run_blocal_hook}
%\synopsis{Run a blocal hook if it exists}
%\usage{ Void run_blocal_hook(String hook, [args])}
%\description
%   Run a blocal hook if it exists
%\example
%#v+
% define run_buffer()
% {
%    run_blocal_hook("run_buffer_hook");
% }
%#v-
%\seealso{runhooks, run_function, get_blocal, get_blocal_var}
%!%-
define run_blocal_hook() % (hook, [args])
{
   variable args = __pop_args(_NARGS-1);
   variable hook = ();
   () = run_function(get_blocal(hook, NULL), __push_args(args));
}

%!%+
%\function{run_buffer}
%\synopsis{Evaluate the current buffer as script}
%\usage{ Void run_buffer()}
%\description
%  Evaluate the current buffer as script, using the blocal_hook
%  "run_buffer_hook" to find out which function to use. This way
%  a mode for a scriptiong language can set the right function but leave
%  a unified keybinding up to the emulation mode (or your .jedrc)
%\example
%  Up to date modes set the blocal var by themself, e.g.
%#v+
% public define gnuplot_mode ()
% {
%    set_mode(mode, 4);
%    use_syntax_table (mode);
%    use_keymap ("GnuplotMap");
%    mode_set_mode_info (mode, "fold_info", "#{{{\r#}}}\r\r");
%    mode_set_mode_info (mode, "init_mode_menu", &init_mode_menu);
%    define_blocal_var("help_for_word_hook", &gnuplot_help);
%    define_blocal_var("run_buffer_hook", &gnuplot_run);
%    run_mode_hooks("gnuplot_mode_hook");
% }
%#v-
%  For others you can do it using the mode_hooks, e.g.
%#v+
%   define latex_mode_hook ()
% {
%    define_blocal_var("run_buffer_hook", "latex_compose");
% }
%
% define calc_mode_hook ()
% {
%    define_blocal_var("run_buffer_hook", "calc_make_calculation");
%    set_buffer_undo(1);
% }
%#v-
%\seealso{run_blocal_hook, evalbuf}
%!%-
public define run_buffer()
{
   run_blocal_hook("run_buffer_hook");
}

% --- window operations ----------------------------------------------

%!%+
%\function{window_set_rows}
%\synopsis{Make the current window \var{rows} rows big}
%\usage{Void window_set_rows(Int rows)}
%\description
%   Resizes the current window:
%   If there is only one window, the no action is taken.
%   If \var{rows} is zero, the window is deleted
%   If \var{rows} is negative, the window is reduced by \var{rows} lines.
%   (Use loop(rows) enlargewin(); to get relative enlargement.)
%\notes
%   If there are more than two windows open,
%   the function might not work as desired.
%\seealso{fit_window, enlargewin, onewindow}
%!%-
define window_set_rows(rows)
{
   if (rows == 0)
     	call("delete_window");
   if (rows < 0)
       rows += window_info('r');
   if (nwindows () - MINIBUFFER_ACTIVE == 1)
     return;
   if (rows >= SCREEN_HEIGHT-3)
     onewindow();
   variable misfit = rows - window_info('r');
   if (misfit > 0) { % window too small
      loop(misfit)
	enlargewin ();
   }
   if (misfit < 0) { % window too large
      variable curbuf = whatbuf();
      otherwindow();
      loop(-misfit)
	enlargewin ();
      loop(nwindows() - 1)
	otherwindow();
   }
   if (eobp)
     recenter(rows);
}

%!%+
%\function{fit_window}
%\synopsis{fits the window size to the lenght of the buffer}
%\usage{ Void fit_window (max_rows=1.0)}
%\description
% the optional parameter max_rows gives the maximal size of the window,
% either as proportion of the total space or as fix number of lines.
% The default max_rows=1.0 means no limit, max_rows=0 means: don't fit.
%\seealso{enlargewin, popup_buffer}
%!%-
public define fit_window () % fit_window(max_rows = 1.0)
{
   variable max_rows = 1.0;
   if (_NARGS)
     max_rows = ();

   if (max_rows == 0)
     return;
   % convert max_rows from fraction to absolute if Double_Type:
   if (typeof(max_rows) == Double_Type)
	max_rows = int(SCREEN_HEIGHT-3 * max_rows);
   % get the desired number of rows (lines in the actual buffer or max_rows)
   push_spot();
   eob;
   variable wanted_rows = what_line;
   pop_spot();
   % limit to max_rows
   if (wanted_rows > max_rows)
     wanted_rows = max_rows;
   % fit window
   window_set_rows(wanted_rows);
   % % put eob at bottom line
   % if (eobp)
}

% --- closing the buffer -------------------------------------------------

%!%+
%\function{close_buffer}
%\synopsis{Close the current (or given) buffer}
%\usage{ Void close_buffer(buf = whatbuf())}
%\description
%   Close the current (or given) buffer.
%   Run the blocal "close_buffer_hook" ( if (buf == whatbuf) )
%\seealso{delbuf, close_window, popup_buffer}
%!%-
public define close_buffer() % (buf = whatbuf())
{
   % optional argument
   variable buf = push_defaults(whatbuf(), _NARGS);

   variable currbuf = whatbuf();
   if (buf != currbuf)
     setbuf(buf);
   run_blocal_hook("close_buffer_hook", buf);
   delbuf(buf);
}

% close buffer in second window if there are two windows
define close_other_buffer ()
{
   if (nwindows () - MINIBUFFER_ACTIVE > 1)
     {
	otherwindow();
	close_buffer();
     }
}

% Close buffer, insert current word in calling buffer
define close_and_insert_word()
{
   variable word = get_word();
   close_buffer();
   insert(word);
}

% Close buffer, replace current word in calling buffer with current word
define close_and_replace_word()
{
   variable word = get_word();
   close_buffer();
   !if (is_visible_mark)
     mark_word;
   del_region();
   insert(word);
}

% open buffer, preserve the number of windows currently open
define go2buf(buf)
{
   if(buffer_visible(buf))
     pop2buf(buf);   % open in other window
   else
     sw2buf(buf);    % open in current window
}

% --- "Popup Buffer" -----------------------------------------------------

custom_variable("Max_Popup_Size", 0.7);          % max size of one popup window
% TODO: more than 1 popup window in parrallel (i.e. more than 2 open windows)
% custom_variable("Popup_max_popups", 2);        % max number of popup windows
% custom_variable("Popup_max_total_size", 0.7);  % max size of all popup windows

% close popup window, if the buffer is visible and resizable
define popup_close_buffer_hook(buf)
{
   % abort if buffer is not attached to a window
   !if (buffer_visible(buf))
     return;
   % resizable popup window: close it
   if ( get_blocal_var("is_popup") != 0 )
     call("delete_window");
   else
     {
	variable replaced_buf = get_blocal("replaced_buf", "");
	if (bufferp(replaced_buf))
	  {
	     sw2buf(replaced_buf);
	     % resize popup windows
	     fit_window(get_blocal("is_popup", 0));
	  }
	otherwindow();
%         variable calling_buf = get_blocal("calling_buf", "");
%    if (bufferp(calling_buf))
%      sw2buf(calling_buf);
     }
}

%!%+
%\function{popup_buffer}
%\synopsis{Open a "popup" buffer}
%\usage{popup_buffer(buf, max_rows = Max_Popup_Size)}
%\description
% The "popup" buffer opens in a second window (using pop2buf).
% Closing with close_buffer closes the popup window (if new)
% or puts back the previous buffer (if reused).
%
% The blocal variable "is_popup" marks the buffer as "popup".
% It contains the upper limit when fitting the window or 0 if the window
% should not be resized.
%
%\example
%  Open a popup window and fit (if applicable) after inserting stuff:
%#v+
%        popup_buffer(buf);
%        insert("hello world");
%        % insert_file("hello.txt");
%        fit_window(get_blocal("is_popup", 0));
%#v-
%
%\seealso{setbuf, sw2buf, close_buffer, fit_window, delete_window}
%!%-
define popup_buffer() % (buf, max_rows = Max_Popup_Size)
{
   % get arguments
   variable buf, max_rows;
   (buf, max_rows) = push_defaults(whatbuf(), Max_Popup_Size, _NARGS);

   variable replaced_buf,
     open_windows = nwindows - MINIBUFFER_ACTIVE;
   %   variable calling_buf = whatbuf();
   % Open/go_to the buffer, store the replaced buffers name
   replaced_buf = pop2buf_whatbuf(buf);
   % find out if we can savely fit the window
   if (open_windows > 1)
     {
	sw2buf(replaced_buf);
	if (get_blocal("is_popup", 0) == 0)
	  max_rows = 0;
	sw2buf(buf);
     }
   define_blocal_var("is_popup", max_rows);
   define_blocal_var ("replaced_buf", replaced_buf);
   define_blocal_var("close_buffer_hook", &popup_close_buffer_hook);
   %    if(get_blocal("calling_buf", whatbuf) != whatbuf)
   %       define_blocal_var ("calling_buf", calling_buf);
}

% --- push_keymap/pop_keymap --- (turn on/off a minor mode) ----------------
%
% see also push_mode/pop_mode from pushmode.sl

static variable stack_name = "keymap_stack";

% temporarily push the keymap
define push_keymap(new_keymap)
{
   % push the old map's name on blocal stack
   define_blocal_var(stack_name, what_keymap()+"|"+get_blocal(stack_name, ""));
   use_keymap(new_keymap);
   % append the new keymap to the modename
   variable mode, flag;
   (mode, flag) = what_mode();
   set_mode(mode + " (" + new_keymap + ")", flag);
   %Test show("keymap stack is:", get_blocal_var(stack_name));
   %Test show("current keymap is:", what_keymap());
}

define pop_keymap ()
{
   variable kstack = get_blocal_var(stack_name);
   variable oldmap = extract_element (kstack, 0, '|');
   if (oldmap == "")
     error("keymap stack is empty.");

   variable mode, flag;
   (mode, flag) = what_mode();
   set_mode(mode[[0:-(strlen(what_keymap)+4)]], flag);
   use_keymap(oldmap);
   set_blocal_var(kstack[[strlen(oldmap)+1:]], stack_name);
  %Test show("keymap stack is:", get_blocal_var(stack_name));
  %Test	show("current keymap is:", what_keymap());
}

% Rebind all keys that are bound to old_fun to new_fun
define rebind() % (old_fun, new_fun, keymap=what_keymap(), key_prefix="")
{
   variable old_fun, new_fun, keymap, key_prefix;
   (old_fun, new_fun, keymap, key_prefix) =
     push_defaults( , , what_keymap(),"", _NARGS);

   variable key;
   loop (which_key (old_fun))
   {
      key = ();
      definekey(new_fun, key_prefix + key, keymap);
   }
}

% Make a binding for new_fun for all bindings to old_fun
% prepending the _Reserved_Key_Prefix
define rebind_reserved(old_fun, new_fun, keymap)
{
   rebind(old_fun, new_fun, keymap, _Reserved_Key_Prefix);
}

% --- some more buffer related helpers ----------------------------------

%!%+
%\function{buffer_dirname}
%\synopsis{Return the directory associated with the buffer}
%\usage{Str buffer_dirname()}
%\description
%   Return the directory associated with the buffer}
%\seealso{getbuf_info, buffer_filename}
%!%-
define buffer_dirname()
{
   variable dir, args = __pop_args(_NARGS);
   ( , dir, , ) = getbuf_info(__push_args(args));
   return dir;
}

% Read a file and return it as array of lines. Newlines are preserved.
% Note: To get rid of the newlines, you can do strchop(strread_file(name), '\n', 0);
define arrayread_file(name)
{
   variable fp = fopen (name, "r");
   if (fp == NULL) verror ("File %s not found", name);
   fgetslines(fp);
   () = fclose (fp);
}

% Read a file and return it as string
define strread_file(name)
{
   strjoin(arrayread_file(name), "");
}

% restore (or update, if file changed on disk) a buffer to the file version
public define reload_buffer()
{
   variable file = buffer_filename();
   variable col = what_column(), line = what_line();

   if(file_status(file) != 1)
     error("cannot open " + file);
   % turn off the "changed on disk" bit
   % cf. example set_overwrite_mode () in the setbuf_info help
   % but here we want to reset -> use  (a & ~b) instead of (a|b)
   setbuf_info (getbuf_info () & ~0x004);
   erase_buffer(whatbuf());
   () = insert_file(file);
   goto_line(line);
   goto_column(col);
   set_buffer_modified_flag(0);
   setbuf_info (getbuf_info () & ~0x004);
}

% ------- Write the region to a file and return its name. -----------------
%
% (if there is no region, save the buffer)
% Helper for interaction with system commands that expect a file to work on.
% Used e.g. in shell_cmd_on_region...

% Directory for temporary files
custom_variable("Jed_Temp_Dir", getenv("TEMP"));
if (Jed_Temp_Dir == NULL)
  Jed_Temp_Dir = getenv("TMP");
if (Jed_Temp_Dir == NULL)
  Jed_Temp_Dir = "/tmp";

% Ask before saving a changed buffer?
custom_variable("Bufsubfile_Save_Ask", 1);

% list of files to delete at exit 
% (defined with custom_variable, so a reevaluation of bufutils will not
%  delete the existing list.)
custom_variable("Temp_Files", "");

% cleanup at exit
static define delete_temp_files()
{
   variable file;
   foreach (strchop(strtrim_beg(Temp_Files), '\n', 0))
     {
	file = ();
	if (file_status(file) == 1)
	  delete_file(file);
     }
   return 1;
}
add_to_hook("_jed_exit_hooks", &delete_temp_files);

%!%+
%\function{bufsubfile}
%\synopsis{Write the region to a temporary file and return its name. }
%\usage{String = bufsubfile(delete=0)}
%\description
%   Write the region to a file. If no region is defined, write the buffer.
%   If \var{delete} != 0, delete the region/buffer after writing.
%   If there is already file associated to the buffer, and no region defined,
%   just save the buffer. Return the filename
%\notes
%   This bufsubfile enables shell commands working on files
%   to act on the current buffer and return the command output.
%   (run_shell_cmd returns output but doesnot take input from jed,
%    while pipe_region only takes input but outputs to stdout)
%\seealso{system, run_shell_cmd, shell_cmd_on_region, pipe_region}
%!%-
define bufsubfile() % (delete=0)
{
   variable delete = push_defaults(0, _NARGS);
   variable file, i=1, base;


   if (buffer_filename == "" or is_visible_mark())
     {
	push_spot ();
	!if (is_visible_mark)
	  mark_buffer;
	if (delete)
	  () = dupmark();
	% write region/buffer to temporary input file
	base = str_delete_chars(whatbuf(), "*+<> ");
	base = path_sans_extname(path_basename(base));
	base = path_concat(Jed_Temp_Dir, base);
	loop (1000)
	  {
	     file = sprintf ("%s%d%s", base, i, path_extname(whatbuf));
	     !if (file_status(file))
	       break;
	     i++;
	  }
	if (i >= 1000)
	  error ("Unable to create a tmp file!");
	() = write_region_to_file(file);
   	if (delete)
	  del_region();
	% delete the file at exit
	Temp_Files += "\n" + file;
	pop_spot();
     }
   else
     {
	if (buffer_modified())
	  if (orelse{not(Bufsubfile_Save_Ask)}{get_y_or_n("Save Buffer")})
	    save_buffer();
	file = buffer_filename();
	if (delete)
	  {
	     % erase_buffer();  % prevents undo operation
	     mark_buffer();
	     del_region();
	  }
     }
   % show("bufsubfile:", file, Temp_Files);
   return file;
}

%!%+
%\function{untab_buffer}
%\synopsis{Untab the whole buffer}
%\usage{Void untab_buffer()}
%\description
%  Converse all existing tabs in the current buffer into spaces
%\notes
%  The variables TAB and USE_TABS define, whether Tabs will be used
%  for editing
%\seealso{untab, TAB, USE_TABS}
%!%-
public define untab_buffer ()
{
   push_spot();
   mark_buffer();
   untab ();
   pop_spot();
}


provide("bufutils");

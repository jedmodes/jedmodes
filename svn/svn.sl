% svn.sl: Utilities for SVN and CVS access from jed. 
% -*- mode: slang -*-
% 
% :Date:      $Date$
% :Version:   $Revision$
% :URL:       $URL$
% :Copyright: (c) 2003,2006 Juho Snellman
%                 2007      Guenter Milde
%
% (Standard MIT/X11 license follows)
% 
% Permission is hereby granted, free of charge, to any person obtaining
% a copy of this software and associated documentation files (the
% "Software"), to deal in the Software without restriction, including
% without limitation the rights to use, copy, modify, merge, publish,
% distribute, sublicense, and/or sell copies of the Software, and to
% permit persons to whom the Software is furnished to do so, subject to
% the following conditions:
% 
% The above copyright notice and this permission notice shall be
% included in all copies or substantial portions of the Software.
% 
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
% MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
% NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
% LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
% OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
% WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
% 
% Installation
% ============
% 
% Add this file into a directory that's in your "Jed library path" (try
% M-X get_jed_library_path() to see what this is). 
% 
% After that, copy the <INITIALIZATION> block into your .jedrc (or run
% update_ini() from jedmodes.sf.net/mode/make_ini/)
%  
% Functionality
% =============
%   
% Only the most common (for me) CVS|SVN operations are supported (add, commit,
% diff, update). The operations can be targeted at a single buffer, a bunch of
% files that have been marked, or at whole directories.
% 
% Operations on buffers
% ---------------------
%
% In general, the buffer operations will save the buffer before
% doing the operation.
% 
%   C-c a    'svn add'    file
%   C-c c    'svn commit' file
%   C-c u    'svn update' file
%   C-c d    'svn diff'   file
%   C-c m m  Mark the file for batch operations
%   
%   
% Operations on marked files
% --------------------------
% 
% The easiest way to operate on marked files is to use the following
% command to open the marked file list buffer, from where you can easily
% start the other operations using keybindings specific to that
% buffer.
% 
%   C-c l  show list of marked files
% 
% The commands for operating on marked files are also available as
% general keyboard commands, for those who find them more convenient.
% 
%   C-c m a    'svn add'    all marked files
%   C-c m c    'svn commit' all marked files
%   C-c m u    'svn update' all marked files
%   C-c m d    'svn diff'   all marked files
%   
% For convenience, committing all marked files also unmarks the files.
% 
%   
% Operation on directories
% ------------------------
%  
% The directory operations ask the user for a directory before
% executing. The question defaults to the previous directory given.
%   
%   C-c C-a    'svn add'    directory
%   C-c C-c    'svn commit' directory
%   C-c C-u    'svn update' directory
%   
%   C-c C-l    open directory view (basically a 'svn -qnf update')
%   
% Directory level commit is not supported.
%   
%   
% Diff/directory views
% --------------------
% 
% Operations on single/marked files can also be applied from inside
% a *SVN diff* or *SVN dirlist* buffer, using the same keybindings
% as in a *SVN marked files* buffer. These views are probably the 
% most convenient methods for committing a large number of files,
% or doing only selective updates on a project.
% 
% 
% Most of the above commands are also accessible from
% the  File>Version_Control menu.
%
%
% Customization
% =============
%  
% The following custom variables are available for modifying the behaviour
% of this module.
%      
%   Variable                       Default value
%   ----------------------------   ---------------   
%   SVN_executable                 "svn"
%   CVS_executable                 "cvs"
%   SVN_set_reserved_keybindings   0
%
% See the definition below or 'Help>Describe Variable' for details.
%    
%
% Changelog
% =========
% 
% 2003-05-31 / Juho Snellman <jsnell@iki.fi>
%            * First public release
% 2003-05-31 * Run diff with -q
%            * Protect the Cvs_Mark_Type declaration inside "!if (reloading)"
% 2003-06-02 * Switch the commands affecting selected file to lowercase 
%              letters, since they seem to get used a lot more.
%            * Add revert (cvs update -C)
% 2003-12-09 * Fix find_marked_common_root
% 2006-11-21 * Rough SVN port
% 2007-04-27 / Guenter Milde <milde users.sf.net>
%            * <INITIALIZATION> block: no need to evaluate svn.sl at startup
%            * bugfix: return to directory listing before postprocessing
%            * use popup_buffer instead of pop2buf: 
%              - closing with close_buffer() closes the window as well 
%                (if it wasn't open before).
% 2007-04-30 * bugfix in dirlist_extract_filename(): strip spurious whitespace
%              (Joachim Schmitz)
%            * replace CVS with SVN in names and documentation
% 2007-05-04 * Support both SVN and CVS (checking for CVS or .svn subdir)
%            * removed otherwindow_if_messagebuffer_active() -- its not used
% 2007-05-16 * require_buffer_dir_in_svn() now also returns "entries" dir
%              as its path differs between CVS and SVN
% 2007-05-25 * Use buffer_dirname() instead of getcwd() for project directory
%              default
% 2007-07-23 * Set default of SVN_set_reserved_keybindings to 0 to prevent 
%              clashes with mode-specific bindings
%            * code reorganisation
%            * Mode menu for listings
%            * Removed SVN_help: Keybindings are shown in mode menu
% 2007-07-24 * Since svn version 1.4, the .svn/entries file is no longer XML:
%              adapted require_buffer_file_in_vc() (report J. Schmitz)
% 2007-08-02 * Revised layout and hotkeys of vc and vc_list_mode menu
% 2007-10-01   Bugfix (missing variable declaration)
% 2007-10-18 * vc_add_dir(): Non-recursive also under SVN
% 2007-12-11 * Key_Ins selects and moves down one line
% 	     * vc_list_dir() did open a buffer even if dir not under vc
% 	     * basic support for SVK (http://svk.bestpractical.com/)
% 	     * edit log-message in a dedicated buffer
% 	     * after commit, update all buffers that changed on disk
% 2007-12-18 * New functions: vc_subtract_selected(), vc_delete_selected,
% 	       vc_commit_dir()
% 	     * remove spurious arg in vc_commit_finish()
% 2008-01-03 * bugfix: swapped arguments in vc_commit_buffer()
% 2008-01-04 * bugfix: vc_commit_finish() left the window open
% 2008-01-07 * bugfix: diff_filenames holds Integer_Type values
% 	       bugfix: add missing autoloads, get_blocal --> get_blocal_var()
% 2008-02-19 * add CVS keywords for this file
% 	     * bury output buffer after commit (show last line in minibuffer)
% 	     * re-open instead of reload buffers to avoid 
% 	       "file changed on disk" questions
% 	     
%                           
% TODO
% ====
% 
% * Document public variables/functions
% * insert (and filter) a status report into the log-message buffer
% * use listings.sl for the listings
% * syntax highlight (DFA) in directory listing
% * Add support for 'diff -r HEAD'
% * Consider -u option for svn status (show externally updated files)

#<INITIALIZATION>
% Add a "File>Version Control" menu popup
autoload("vc_menu_callback", "svn");
define vc_load_popup_hook(menubar)
{
   variable menu = "Global.&File";
   menu_insert_popup("Canc&el Operation", menu, "&Version Control");
   menu_set_select_popup_callback(menu+".&Version Control", 
                                  &vc_menu_callback);
}
append_to_hook("load_popup_hooks", &vc_load_popup_hook);
#</INITIALIZATION>

% Requirements
% ============

% from  http://jedmodes.sourceforge.net/
autoload("reload_buffer", "bufutils");
autoload("popup_buffer", "bufutils");
autoload("buffer_dirname", "bufutils");
autoload("close_buffer", "bufutils");
autoload("fit_window", "bufutils");
autoload("strread_file", "bufutils");
autoload("push_array", "sl_utils");
autoload("get_line", "txtutils");       % >= 2.7
autoload("re_replace", "txtutils");       % >= 2.7
require("x-keydefs");              % symbolic keyvars, including Key_Esc

% require("listing");

implements("svn");
provide("svn");

%% Variables %{{{

%!%+
%\variable{SVN_executable}
%\synopsis{The location of the svn executable}
%\usage{variable SVN_executable = "/usr/bin/svn"}
%\description
%  Name or path to the SVN command line client
%\seealso{vc_list_dir, vc_diff_buffer}
%!%-
custom_variable("SVN_executable", "svn");

%!%+
%\variable{CVS_executable}
%\synopsis{The location of the svn executable}
%\usage{variable CVS_executable = "/usr/bin/svn"}
%\description
%  Name or path to the CVS command line client
%\seealso{vc_list_dir, vc_diff_buffer}
%!%-
custom_variable("CVS_executable", "cvs");

% command string for the svk version control system
custom_variable("SVK_executable", "svk");

% root of the local svk version control system repository
custom_variable("SVK_root", expand_filename("~/.svk"));
if (file_status(SVK_root) != 2 and getenv("SVKROOT") != NULL)
    SVK_root = getenv("SVKROOT");


%!%+
%\variable{SVN_set_reserved_keybindings}
%\synopsis{Set up reserved keybindings for SVN actions in the Global map?}
%\usage{variable SVN_set_reserved_keybindings = 1}
%\description
% By default, the initialization routines set up Global keybindings,
% using the reserved prefix (defaults to C-c). Setting this
% variable to zero *before the file is evaluated* prevents the 
% keybindings from being created.
%\notes
% If set up as shown in the "Installation" section on top of the svn.sl file,
% the SVN functions are accessible via the "File>Version Control" menu popup.
%\seealso{vc_list_dir, vc_diff_dir}
%!%-
custom_variable("SVN_set_reserved_keybindings", 0);

private variable diff_buffer = "*VC diff*";
private variable dirlist_buffer = "*VC directory list*";
private variable list_buffer = " *VC marked files*"; % normally hidden
private variable cmd_output_buffer = "*VC output*";
private variable project_root = ""; % cache for get_op_dir()

%}}}

%% Prototypes %{{{

public define vc_add_buffer();
public define vc_list_mode();
static define vc_log_mode();
private define update_list_buffer();
private define update_diff_buffer();
private define update_dirlist_buffer();
private define init_diff_buffer();
private define postprocess_diff_buffer();
private define diff_extract_filename();
private define list_extract_filename();
private define dirlist_extract_filename();
%}}}

% Auxiliary functions that maybe belong elsewhere
% ===============================================

% set the buffer directory to dir (-> bufutils.sl ?)
private define set_buffer_dirname(dir)
{
   variable file, name, flags;
   (file, , name, flags) = getbuf_info();
   setbuf_info(file, dir, name, flags);
}

%!%+
%\function{file_p}
%\synopsis{Return the number of open buffers associated to file}
%\usage{Integer file_p(file)}
%\description
%   Looks for the buffer-filenames of all open buffers and compares to
%   the argument. Return the buffer name of the first match or the empty
%   string.
%   (buffer-filename is dir + file, see \sfun{buffer_filename})
%\example
%#v+
%   if(file_p(file) == "")
%      find_file(file)
%#v-
%   will only open a new buffer (and do nothing is file is already open), 
%   while
%#v+
%   if(file_p(file) != "")
%      find_file(file)
%#v-
%   will never open a new buffer (and switch to an open buffer associated 
%   with \var{file}).
%\seealso{bufferp, buffer_filename, buffer_list, getbuf_info, find_file}
%!%-
public  define file_p(file)
{
   variable dir, buf, f, fp=0;
   loop (buffer_list())
     {
	buf = (); % retrieve from stack, as getbuf_info take optional arg
	% cannot use buffer_filename(), as it does not accept `buf' argument
	(f, dir, , ) = getbuf_info(buf);
	if (dir + f == file)
	  return buf;
     }
   return "";
}

% Re-open buffer \var{buf}.
% 
% In contrast to reload_buffer, this closes the buffer and opens a new one
% with find_file(). This prevents questions about changed versions on disk.
static define reopen_buffer(buf)
{
   variable file, dir, col, line;
   (file, dir, , ) = getbuf_info();
   if (file == "")
      verror("No file attached to %s", buf);
   line = what_line();
   col = what_column();
   
   delbuf(buf);
   find_file(dir + file);
   
   goto_line(line);
   goto_column_best_try(col);
}

% Executing version control commands
% ==================================

% find out whether `dir' is under svk version control
% * checks in the SVKROOT/config file (format as in svk version v2.0.1 )
% * `dir' should be a valid absolute path
static define is_svk_dir(dir)
{
   variable line, buf = whatbuf();
   EXIT_BLOCK { 
      delbuf("*svk-config-tmp*"); 
      sw2buf(buf);
   }
   sw2buf ("*svk-config-tmp*");
   erase_buffer ();
   if (-1 == insert_file_region(path_concat(SVK_root, "config"),
				"  hash: ",
				"  sep: "))
      return 0; % could not open config file
   set_buffer_modified_flag(0);
   bob();
   while (down_1()) {
      skip_white();
      !if (what_column() == 5)
	 continue;
      push_mark();
      () = ffind(":");
      if (is_substr(dir, bufsubstr()))
	 return 1;
   }
   return 0;
}

% find out how version control is managed for `dir'
private define get_vc_system(dir)
{
   if (file_status(path_concat(dir, ".svn")) == 2)
     return "svn";
   if (file_status(path_concat(dir, "CVS")) == 2)
     return "cvs";
   if (is_svk_dir(dir))
     return "svk";
   % <Add other version control systems here>
   verror("Directory '%s' is not under version control", dir);
}

private define require_buffer_file_in_vc() { %{{{
   % get buffer file and dir
   variable file, dir;
   (file, dir,,) = getbuf_info(whatbuf());
   if (file == "") 
     error("No file attached to this buffer. Please save buffer first.");
   % check if file is under version control
   variable entries, file_under_vc = 0;
   switch (get_vc_system(dir))
     { case "cvs": 
        entries = strread_file(
           path_concat(path_concat(dir, "CVS"), "Entries"));
        file_under_vc = is_substr(entries, sprintf("/%s/", file));
     }
     { case "svn": 
        entries = strread_file(
           path_concat(path_concat(dir, ".svn"), "entries"));
        file_under_vc = orelse{
           is_substr(entries, sprintf("name=\"%s\"", file)) % svn < 1.4
        }{ is_substr(entries, sprintf("\n%s\n", file)) };   % svn >= 1.4
     }
     { case "svk": % there is no quick-check under svk, just try
	file_under_vc = 1; 
     }
   !if (file_under_vc) {
      if (get_y_or_n("File " + file + " not found in VC entries. Add it?"))
        vc_add_buffer();
      else
        verror("File '%s' is not under version control", file);
   }
    
   return (file, dir);
}
%}}}

private define escape_arg(str) { %{{{
    return "'" + str_quote_string(str, "\\'$@", '\\') + "'";
}
%}}}

% Run vc-executable.
% 
% \var{args}             list of commands and options (will be shell-escaped)
% \var{dir}              dir to chdir() to before calling the command.
% \var{use_message_buf}  Insert report into " *VC output*" buffer
% 		         (else into current buffer)
% \var{signal_error}     throw an error if the command fails
%  
define do_vc(args, dir, use_message_buf, signal_error) %{{{
{
   variable executable, cmd, msg, result, 
      buf = whatbuf(), cwd = getcwd();
   switch (get_vc_system(dir)) % Errors if dir not under version control
     { case "cvs": executable = CVS_executable; }
     { case "svn": executable = SVN_executable; }
     { case "svk": executable = SVK_executable; }
   
   % Quote arguments and join to command string
   args = array_map(String_Type, &escape_arg, args);
   cmd = strjoin([executable, args], " ");
#ifdef OS2 UNIX
   cmd += " 2>&1";    % re-direct stderr
#endif

   % Prepare output buffer
   if (use_message_buf) {
      popup_buffer(cmd_output_buffer);
      set_readonly(0);
      erase_buffer();
   }
    
   % set working dir
   if (chdir(dir) == -1) {
      error("Couldn't chdir to '" + dir + "': " + errno_string(errno));
   }
   set_buffer_dirname(dir);
   % Run command
   msg = "Exec: " + cmd + "\nDir: " + dir;
   flush(msg);
   insert(msg + "\n\n");
   
   result = run_shell_cmd(cmd);
   
   if (bsearch("revision"))
      flush(get_line());
   else
      flush("done");
   % bob();
   set_buffer_modified_flag(0);
   set_readonly(1);
   fit_window(get_blocal_var("is_popup", 0)); % resize popup window

   % Restore buffer and working dir
   % show cmd output if return value != 0
   () = chdir(cwd);
   if (use_message_buf) {
      !if (result) 
	 bury_buffer(cmd_output_buffer);
	 % close_buffer(cmd_output_buffer);
       else 
	 pop2buf(buf);
   }
   
   % throw error if return value != 0
   if (result and signal_error) 
      error(sprintf("svn returned error code %d", result));
}
%}}}

%% Commit files %{{{

private variable end_of_log_str = 
   "# --- diese und die folgenden Zeilen werden ignoriert ---";
% "=== Targets to commit (you may delete items from it) ===";

% Prepare commit of files in array `files' in working dir `dir'.
% Edit Log message in a dedicated buffer.
% Do the 'real' commit with vc_commit_finish() bound in the "svn-log" keymap.
private define vc_commit_start(dir, files)
{
   popup_buffer("*Log Message*");
   set_buffer_dirname(dir);
   define_blocal_var("files", files);
   vc_log_mode();
   % insert info
   vinsert("\n%s\n", end_of_log_str);
   vinsert("Dir: %s\n", dir);
   if (length(files))
      vinsert("Files:\n%s", strjoin(files, "\n"));
   bob();
   variable msg = "Edit log message, commit with ESC or %s c";
   flush(sprintf(msg, _Reserved_Key_Prefix));
}


static define vc_commit_finish()
{
   variable dir = buffer_dirname();
   variable file, files = get_blocal_var("files");
   variable buf = whatbuf();
   
   % TODO: parse the files list so it can be edited like in SVK
   
   % get message (buffer-content up to info area)
   bob();
   push_mark();
   bol_fsearch(end_of_log_str);
   go_left_1();
   variable msg = bufsubstr();
   set_buffer_modified_flag(0);
   % show(msg);
   do_vc(["commit", "-m", msg, files], dir, 1, 1);
   
   % Re-load commited buffers to update changes (e.g. to $Keywords$)
   files = dir + files;
   variable buffer, flags,
      buffers = array_map(String_Type, &file_p, files);
   %   filter files without open buffer
   buffers = buffers[where(buffers != "")];
   foreach buffer (buffers) {
      % reload if changed one disk:
      (, , , flags) = getbuf_info(buffer);
      if (flags & 4) {
	 reopen_buffer();
      }
   }
   % if everything went fine, close the "*Log Message*" buffer
   sw2buf(buf); % make active so close_buffer closes the window as well
   close_buffer();
}
%}}}

%% Marking files %{{{

!if (is_defined("Cvs_Mark_Type"))
   typedef struct {
      filename, 
        diff_line_mark, 
        list_line_mark, 
        dirlist_line_mark
   } Cvs_Mark_Type;


variable marks = Assoc_Type[Cvs_Mark_Type];

private define make_line_mark () { %{{{
    return create_line_mark(color_number("menu_selection"));
}
%}}}

private define mark_file(file) { %{{{
    variable new = @Cvs_Mark_Type;
    new.filename = file;
    
    variable buf = whatbuf();
    
    update_list_buffer(new);
    update_diff_buffer(new);
    update_dirlist_buffer(new);
    sw2buf(buf);
    
    marks[file] = new;
    %% recenter(0);
    % call("redraw");
    message("Marked " + file);    
}
%}}}

private define unmark_file(file) { %{{{
    assoc_delete_key(marks, file);
    %% recenter(0);
    call("redraw");
    message("Unmarked " + file);
}
%}}}

public define vc_unmark_all() { %{{{
    marks = Assoc_Type[Cvs_Mark_Type];
}
%}}}

public define vc_mark_buffer() { %{{{
    mark_file(buffer_filename());
}
%}}}

public define vc_unmark_buffer() { %{{{
    unmark_file(buffer_filename());
}
%}}}

% define have_marked_files() { %{{{
%     return length(marks);
% }
%}}}

define toggle_marked_file(file)  %{{{
{
   if (file == "")
      return;
   
   % prepend buffer dir
   file = path_concat(buffer_dirname(), file);
   
   if (assoc_key_exists(marks, file)) {
      unmark_file(file);
   } else {
      mark_file(file);
   }
}
%}}}

%}}}


%% SVN operations on a single buffer %{{{

public define vc_add_buffer() { %{{{
    variable file, dir, entries;
    (file, dir,,) = getbuf_info(whatbuf());
    do_vc(["add", file], dir, 1, 1);
}
%}}}

public define vc_commit_buffer() { %{{{
    variable file, dir;
    (file, dir) = require_buffer_file_in_vc();
    save_buffer();
    vc_commit_start(dir, [file]);
}
%}}}

public define vc_diff_buffer() { %{{{
    variable file, dir;
    (file, dir) = require_buffer_file_in_vc();
    save_buffer();
    
    init_diff_buffer(dir, 1);
    
    do_vc([ "diff", file ], dir, 0, 0);
    
    postprocess_diff_buffer();
}
%}}}

public define vc_update_buffer() { %{{{
    variable file, dir;
    (file, dir) = require_buffer_file_in_vc();
    save_buffer();
    
    do_vc([ "update", file ], dir, 1, 1);
    
    if (bol_fsearch("retrieving")) {
        message("Updated");
    } else {
        message("Not updated (no new version available)");
    }
    
    find_file(path_concat(dir, file));    
}
%}}}

%}}}


%% Functions common to the marked files, diff, and directory list buffers %{{{

private define extract_filename() { %{{{
   switch (whatbuf())
     { case diff_buffer: return diff_extract_filename(); }
     { case list_buffer: return list_extract_filename(); }
     { case dirlist_buffer: return dirlist_extract_filename(); }
     { error("can only extract files from *SVN diff* and *SVN marked files*");}
}
%}}}

define toggle_marked() { %{{{
   toggle_marked_file(extract_filename());
}
%}}}

%}}}


%% "SVN diff" view %{{{

private variable diff_filenames = Assoc_Type[Integer_Type, 0];

private define init_diff_buffer(dir, new_window) { %{{{
    if (new_window)
     popup_buffer(diff_buffer);
    else
      sw2buf(diff_buffer);
    
    set_readonly(0);
    erase_buffer();
    % reset "global" (private) variable
    diff_filenames = Assoc_Type[Integer_Type, 0];
    set_buffer_dirname(dir);
}
%}}}

private define update_diff_buffer (mark) { %{{{
   variable buf = whatbuf();
   sw2buf(diff_buffer);
   variable line = diff_filenames [mark.filename];
   if (line != 0) {
      push_spot();
      goto_line(line);
      mark.diff_line_mark = make_line_mark();
      pop_spot();
    }
   sw2buf(buf);
}
%}}}

private define diff_extract_filename() %{{{
{
   push_spot();
   !if (bol_bsearch("Index: ")) 
      error("No file selected (call the command between 'Index: '- lines)");
   
   variable filename = line_as_string()[[7:]];
      
   pop_spot();
   return filename;        
}
%}}}

private define postprocess_diff_buffer() %{{{
{
    popup_buffer(diff_buffer);
    bob();
    () = down(2);
    
    set_readonly(0);
    
    while (bol_fsearch("Index: ")) {
        variable filename = line_as_string()[[7:]];
        variable dir = buffer_dirname();
                
        if (dir != NULL) {
            filename = path_concat(dir, filename);        
            diff_filenames[filename] = what_line();
         
            if (assoc_key_exists(marks, filename)) {
                update_diff_buffer(marks[filename]);
            }
        }
        () = down(1);
    }    
    set_readonly(1);
   % set to diff mode, if diff_mode is globally defined
   call_function("diff_mode");
   vc_list_mode();
   bob();
}
%}}}

private define diff_extract_linenumber() { %{{{
    push_spot();
    EXIT_BLOCK {
        pop_spot();    
    }
    
    if (andelse {bol_bsearch("@@ ")}
        {ffind_char('+')}) 
    {
        push_mark();
        ffind_char(',');
        return integer(bufsubstr());
    } else {
        return 0;
    }
}
%}}}

%}}}


%% "SVN marked files" view %{{{

private define list_extract_filename() %{{{
{    
   push_spot();
   EXIT_BLOCK { pop_spot(); }
    
   variable line = line_as_string();
    
   !if (andelse  {line != ""}
	  {line[[0]] != " "}
	  {path_is_absolute(line)})
      error("Line doesn't contain a valid filename\n");
   
   % return (path_dirname(line), path_basename(line));
   return strtrim(line);
}
%}}}

private define init_list_buffer(erase) { %{{{
    vc_list_mode();
    set_readonly(0);
    
    if (erase)
      erase_buffer();
    
    push_spot();
    bob();
    
    if (eobp()) {
        insert("The following files have been marked by SVN mode. ");
    } else {
        pop_spot();
    }
}
%}}}

public define vc_list_marked() { %{{{
   variable file;
   popup_buffer(list_buffer);
   
   init_list_buffer(1);
   insert("  ----- \n");
   
   push_spot();
   foreach file (marks) using ("keys") {
      marks[file].list_line_mark = make_line_mark();
      insert(file + "\n");            
   }
   pop_spot();
   set_readonly(1);
}
%}}}

private define update_list_buffer (mark) { %{{{
    sw2buf(list_buffer);
    init_list_buffer(0);
    
    push_spot();
    bob();
    if (re_fsearch("^" + mark.filename + "$")) {
        mark.list_line_mark = make_line_mark();
    } else {
        eob();
        mark.list_line_mark = make_line_mark();
        insert(mark.filename + "\n");
    }
    pop_spot();
    
    set_readonly(1);    
}
%}}}

%}}}


%% "SVN directory list" view %{{{

private variable dirlist_filenames = Assoc_Type[Integer_Type];


private define dirlist_extract_filename() %{{{
{    
   variable line = get_line(), dir = buffer_dirname(),
   flag_cols = Assoc_Type[Integer_Type];
   flag_cols["cvs"] = 1; 
   flag_cols["svn"] = 6; 
   flag_cols["svk"] = 3; 

   % get number of leading info columns for used VC system
   flag_cols = flag_cols[get_vc_system(dir)];

   if (orelse{strlen(line) <= flag_cols} {line[flag_cols] != ' '}) {
      % show(line, line[flag_cols], "no valid filename");
      return "";
   }

   return strtrim(line[[flag_cols:]]);
}
%}}}

private define update_dirlist_buffer(mark) { %{{{
    sw2buf(dirlist_buffer);
    push_spot();
    
    if (assoc_key_exists(dirlist_filenames, mark.filename)) {
        variable line = dirlist_filenames [mark.filename];

        push_spot();
        goto_line(line);
        mark.dirlist_line_mark = make_line_mark();
        pop_spot();
    }    
}
%}}}

% Set dirctory for VC operations.
% TODO: cache default (current behaviour) or use dir of current buffer?
private define get_op_dir() { %{{{
   if (project_root == "") {
      project_root = buffer_dirname();
   } 
   project_root = read_with_completion("Enter dir for operation: ", 
                                        "", project_root, 'f');
   return project_root;
}
%}}}

public define vc_list_dir() % (dir=get_op_dir())%{{{
{
   !if (_NARGS)
      get_op_dir(); % push on stack
   variable dir = ();
   % get vc system, abort if dir is not under version control
   variable vc_system = get_vc_system(dir);
   
   sw2buf(dirlist_buffer);
   vc_list_mode();
   % set buffer directory and unset readonly flag
   setbuf_info("", dir, dirlist_buffer, 0);
   define_blocal_var("generating_function", [_function_name, dir]);
   set_readonly(0);
   erase_buffer();
   
   % cvs returns a very verbose list with the status command 
   % the info recommends a dry-run of 'update' for a short list
   switch (vc_system)
     { case "cvs": do_vc(["-n", "-q", "update"], dir, 0, 0); }
     { do_vc(["status"], dir, 0, 0); }
   
   % postprocess dirlist buffer
   variable file;
   bob();
   re_replace("cvs update: warning: \(.*\) was lost"R, "! \1"R);
   bob();
   () = down(2);
   
   while (down(1)) {
      file = dirlist_extract_filename();
      if (file == "")
	 continue;
      file = path_concat(dir, file);
      dirlist_filenames[file] = what_line();
      
      if (assoc_key_exists(marks, file)) {
	 update_dirlist_buffer(marks[file]);
      }
   }
   set_readonly(1);
   bob();
}
%}}}

%!%+
%\function{vc_reread}
%\synopsis{Re-read the current file listing}
%\usage{vc_list_reread()}
%\description
%  Re run the function that generated the current file list to
%  update the view.
%\seealso{vc_list_mode}
%!%-
public  define vc_list_reread()
{
   variable line = what_line();
   () = run_function(push_array(get_blocal_var("generating_function")));
   goto_line(line);
}

%}}}


%% Operations on all marked files %{{{

private define find_marked_common_root() { %{{{
    variable afiles = assoc_get_keys(marks);
    if (length(afiles) == 0) {
        error("No files marked");
    }
    
    variable dir, dirs = array_map(String_Type, &path_dirname, afiles);
    variable rfiles = String_Type [length(afiles)];
    
    variable prefix = "";
    
    foreach dir (dirs) {
        if (strcmp(dir, "") != 0) {
            if (strcmp(prefix, "") == 0) {
                prefix = dir;
            } else {
                while (strcmp(dir, prefix) != 0 and
                       strlen(prefix) > 1) {
                    if (strlen(dir) == strlen(prefix)) {
                        prefix = path_dirname(prefix);
                        dir = path_dirname(dir);
                    } else if (strlen(dir) < strlen(prefix)) {
                        prefix = path_dirname(prefix);
                    } else {
                        dir = path_dirname(dir);
                    }
                }
            }
        }
    }
    
    % +1 to get rid of leading slash in unix. This assumption might
    % be invalid on other platforms
    variable prefixlen = strlen(prefix) + 1;
    
    variable i;
    for (i = 0; i < length(rfiles); i++) { 
        rfiles[i] = afiles[i][[prefixlen:]];
    }
    
    return (dir, rfiles);
}
%}}}

public define vc_add_marked() { %{{{
    variable dir, rfiles;    
    (dir, rfiles) = find_marked_common_root();
    
    do_vc(["add", rfiles], dir, 1, 1);
}
%}}}

public define vc_commit_marked() { %{{{
    variable dir, files;    
    (dir, files) = find_marked_common_root();
    vc_commit_start(dir, files);
    vc_unmark_all();
}
%}}}

public define vc_diff_marked() { %{{{
    variable dir, rfiles;    
    (dir, rfiles) = find_marked_common_root();
    
    init_diff_buffer(dir, 1);

    do_vc(["diff", rfiles], dir, 0, 0);
    postprocess_diff_buffer();
}
%}}}

public define vc_update_marked() { %{{{
    variable dir, rfiles;    
    (dir, rfiles) = find_marked_common_root();
    
    do_vc(["update", rfiles], dir, 1, 1);
}
%}}}

%}}}


%% Operations on single files (valid only in marked files, diff, or 
%% directory list buffers). %{{{

public define vc_add_selected() { %{{{
   variable dir = buffer_dirname(), 
   	    file = extract_filename();
    do_vc(["add", file], dir, 1, 1);
}
%}}}

% take file out of version control, keep local copy
public define vc_subtract_selected() %{{{
{ 
   variable dir = buffer_dirname(), 
      file = extract_filename(),
      tmpfile, 
      prompt = "Remove '%s' from VC (keep local copy)";
   
   if (get_y_or_n(sprintf(prompt, file)) != 1) 
      return;
   
   switch(get_vc_system(dir))
     { case "svn": 
	   tmpfile = make_tmp_file(dir+file);
	   () = rename_file(file, tmpfile);
	   do_vc(["remove", "--force", file], dir, 1, 1); 
	   () = rename_file(tmpfile, file);
     }
     { case "svk": 
	do_vc(["remove", "--force", "--keep-local", file], dir, 1, 1); 
     }
     { case "cvs": error("TODO: not implemented yet"); 
     	% move to backup, remove from vc, restore
     }
}
%}}}

% take file out of version control, delete local copy
public define vc_delete_selected() %{{{
{ 
   variable dir = buffer_dirname(), 
   	    tmpfile, file = extract_filename();
   if (get_y_or_n(sprintf("Delete '%s' from VC and local copy", file)) != 1) 
      return;
   switch(get_vc_system(dir))
     { case "svn": do_vc(["remove", "--force", file], dir, 1, 1); }
     { case "svk": do_vc(["remove", "--force", file], dir, 1, 1); }
     { case "cvs": error("TODO: not implemented yet"); 
	% delete from working cpy, remove from vc
     }
}
%}}}

% commit one selected file
public define vc_commit_selected() { %{{{
   variable file = extract_filename();
   vc_commit_start(buffer_dirname(), [file]);
}
%}}}

public define vc_diff_selected() { %{{{
   variable dir = buffer_dirname(), 
   	    file = extract_filename();
    init_diff_buffer(dir, 1);
    do_vc(["diff", file], dir, 0, 0);
    postprocess_diff_buffer();
}
%}}}

public define vc_update_selected() { %{{{
   variable file = extract_filename();
    do_vc(["update", file], buffer_dirname(), 1, 1);
}
%}}}

public define vc_revert_selected() %{{{
{ 
   variable file = extract_filename(), dir = buffer_dirname();
   
   !if (get_y_or_n(sprintf("Revert '%s'", file)) == 1)
      return;

   switch(get_vc_system(dir))
     { case "cvs": do_vc(["update", "-C", file], dir, 1, 1); }
     { 	    	   do_vc(["revert", file], dir, 1, 1); }
}
%}}}

public define vc_open_selected() { %{{{
    variable linenum, file = extract_filename();
    
    if (whatbuf() == diff_buffer) {
        linenum = diff_extract_linenumber();
    } else {
        linenum = 0; 
    }
    
    find_file(path_concat(buffer_dirname, file));
    if (linenum) {
        goto_line(linenum);
    }
}
%}}}


%}}}


%% SVN directory-level operations %{{{

public define vc_add_dir() { %{{{ 
   %% Kludge to get rid of a possible trailing separator
   variable dir = path_dirname(path_concat(get_op_dir(), ""));
   variable parent = path_dirname(dir);
   variable name = path_basename(dir);
   
   switch (get_vc_system(parent))
     { case "cvs": do_vc(["add", name], parent, 1, 1); }
     { case "svn" or case "svk": 
	do_vc(["add", "--non-recursive", name], parent, 1, 1); }
}
%}}}

% commit all modified files in dir and subdirs
public define vc_commit_dir() %{{{
{
   variable dir = get_op_dir();
   % commit with empty files list
   vc_commit_start(dir, String_Type[0]);
}


public define vc_diff_dir() { %{{{
    variable dir = get_op_dir();
    
    init_diff_buffer(dir, 0);
        
    do_vc(["diff"], dir, 0, 0);    
    postprocess_diff_buffer();
}
%}}}

public define vc_update_dir() { %{{{
    variable dir = get_op_dir();
    do_vc(["-q", "update"], dir, 1, 1);
}
%}}}

%}}}

%}}}


%% Initialization %{{{
private define vc_commom_menu_callback(menu) {
   menu_append_item(menu, "&Add marked", "vc_add_marked");
   menu_append_item(menu, "&Commit marked", "vc_commit_marked");
   menu_append_item(menu, "&Diff marked", "vc_diff_marked");
   menu_append_item(menu, "Unmark all", "vc_unmark_all");
   menu_append_item(menu, "&Update marked", "vc_update_marked");
   menu_append_separator(menu);
   
   menu_append_item(menu, "Add directory", "vc_add_dir");
   menu_append_item(menu, "Commit directory", "vc_commit_dir");
   menu_append_item(menu, "Diff directory", "vc_diff_dir");
   menu_append_item(menu, "Update directory", "vc_update_dir");
   menu_append_item(menu, "&Open directory list", "vc_list_dir");
}   

public define vc_menu_callback(menu) { %{{{
    menu_append_item(menu, "&add buffer", "vc_add_buffer");
    menu_append_item(menu, "&commit buffer", "vc_commit_buffer");
    menu_append_item(menu, "&diff buffer", "vc_diff_buffer");
    menu_append_item(menu, "&mark buffer", "vc_mark_buffer");
    menu_append_item(menu, "unmark buffer", "vc_unmark_buffer");
    menu_append_item(menu, "&update buffer", "vc_update_buffer");
    menu_append_separator(menu);
   
    menu_append_item(menu, "&List marked", "vc_list_marked");
    vc_commom_menu_callback(menu);
}
%}}}

static define vc_list_menu_callback(menu) { %{{{
   menu_append_item(menu, "&add file", "vc_add_selected");
   menu_append_item(menu, "&commit file", "vc_commit_selected");
   menu_append_item(menu, "&diff file", "vc_diff_selected");
   menu_append_item(menu, "&update file", "vc_update_selected");
   menu_append_item(menu, "&revert file", "vc_revert_selected");
   menu_append_item(menu, "&subtract file (keep local copy)", "vc_subtract_selected");
   menu_append_item(menu, "delete file (also local copy)", "vc_delete_selected");
   
   menu_append_separator(menu);
   
   menu_append_item(menu, "&toggle Mark", "svn->toggle_marked");
   menu_append_item(menu, "Unmark all", "vc_unmark_all");
   menu_append_separator(menu);

   vc_commom_menu_callback(menu);
   menu_append_separator(menu);
   
   menu_append_item(menu, "&Quit", "close_buffer");
   
   menu_insert_item("&Open directory list", menu, "Re&generate list", "vc_list_reread");
}
%}}}

private define keymap_init() { %{{{
   setkey_reserved("vc_add_buffer",    "a");  
   setkey_reserved("vc_add_marked",    "ma"); 
   setkey_reserved("vc_add_dir",       "^a"); 
   
   setkey_reserved("vc_commit_buffer", "c");  
   setkey_reserved("vc_commit_marked", "mc"); 
   
   setkey_reserved("vc_diff_buffer",   "d");  
   setkey_reserved("vc_diff_marked",   "md"); 
   setkey_reserved("vc_diff_dir",      "^d"); 
   
   setkey_reserved("vc_list_marked",   "l");  
   setkey_reserved("vc_list_marked",   "ml"); 
   setkey_reserved("vc_list_dir",      "^l"); 
   
   setkey_reserved("vc_mark_buffer",   "mm"); 
   setkey_reserved("vc_unmark_buffer", "m^m");
   setkey_reserved("vc_unmark_all",    "m^u");
   
   setkey_reserved("vc_update_buffer", "u");  
   setkey_reserved("vc_update_marked", "mu"); 
   setkey_reserved("vc_update_dir",    "^u"); 
   
   setkey_reserved("vc_re_eval",       "r");  
}

variable kmap = "svn-list";
!if (keymap_p(kmap)) {
   make_keymap(kmap);
   definekey("vc_add_marked", "A", kmap);
   definekey("vc_commit_marked", "C", kmap);
   definekey("vc_diff_marked", "D", kmap);
   definekey("vc_update_marked", "U", kmap);
   
   definekey("vc_add_selected", "a", kmap);
   definekey("vc_commit_selected", "c", kmap);
   definekey("vc_diff_selected", "d", kmap);
   definekey("vc_list_reread", "g", kmap);   % dired like
   definekey("vc_update_selected", "u", kmap);
   definekey("vc_open_selected", "\r", kmap);
   definekey("vc_revert_selected", "r", kmap);
   
   definekey("svn->toggle_marked; go_down_1", Key_Ins, kmap);
   definekey("svn->toggle_marked", "t", kmap);
   % definekey("svn->toggle_marked", " ", kmap);
   definekey("vc_unmark_all", "U", kmap);
   definekey("close_buffer", "q", kmap);
   
}
%}}}

if (SVN_set_reserved_keybindings) {
   keymap_init();
}
%}}}

% Log Mode
% ========
% 
% mode for the buffer where the commit log is edited.

private variable log_mode = "vc-log";
% >> User Survey: Which key should close this buffer and trigger the commit?
% > _Reserved_Key_Prefix + c      % Jörg Sommer
% > Key_Esc or ^W	       	  % Joachim Schmitz
% 
% IMO, Key_Esc is not suited as it is usually an "abort" key
% Maybe it should open the mode-menu to give a choice?
!if (keymap_p(log_mode)) {
   make_keymap(log_mode);
   definekey_reserved("svn->vc_commit_finish", "c", log_mode);
   % keep ^W as close_buffer (in CUA mode)
   definekey("close_buffer", Key_Esc, log_mode);
}

% context menu
static define log_mode_menu(menu)
{
   menu_append_item(menu, "&Commit",      "svn->vc_commit_finish");
   menu_append_item(menu, "&Quit", 	  "close_buffer");
}

static define vc_log_mode()
{
   set_mode(log_mode, 1);
   mode_set_mode_info(log_mode, "init_mode_menu", &log_mode_menu);
   mode_set_mode_info(log_mode, "run_buffer_hook", &vc_commit_finish);
   use_keymap(log_mode);
}

% VC list mode
% ============
% a common mode for all vc listings

private variable list_mode = "vc-list";

% Highlighting
% ------------ 
% NEEDS dfa for this mode to work.

create_syntax_table(list_mode);
#ifdef HAS_DFA_SYNTAX
dfa_define_highlight_rule("^[^ ]+: .*", "operator",   list_mode);
dfa_define_highlight_rule("^\? .*"R,    "comment",    list_mode); % not under vc
dfa_define_highlight_rule("^A .*",      "string",     list_mode); % added
dfa_define_highlight_rule("^C .*",      "error",      list_mode); % conflict
dfa_define_highlight_rule("^D .*",      "preprocess", list_mode); % delete
dfa_define_highlight_rule("^R .*",      "preprocess", list_mode); % delete (CVS)
dfa_define_highlight_rule("^M .*",      "keyword",    list_mode); % modified
dfa_define_highlight_rule("^~ .*",      "delimiter",  list_mode); % different object
dfa_define_highlight_rule("^! .*",      "error",      list_mode); % missing
% render non-ASCII chars as normal to fix a bug with high-bit chars in UTF-8
dfa_define_highlight_rule("[^ -~]+", "normal", list_mode);

dfa_build_highlight_table(list_mode);
enable_dfa_syntax_for_mode(list_mode);
#endif

public  define vc_list_mode()
{
   set_mode(list_mode, 0);
   % For some reason, DFA syntax highlight does overwrite the line-marks
   % (it works well in filelist_mode() though).
   % use_syntax_table(list_mode);
   mode_set_mode_info(list_mode, "init_mode_menu", 
      &svn->vc_list_menu_callback);
   use_keymap("svn-list");
}   

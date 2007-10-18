% -*- mode: slang -*-
%
% Utilities for SVN and CVS access from jed. 
% 
% Copyright (c) 2003,2006 Juho Snellman
%               2007      Guenter Milde
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
%                           
% TODO
% ====
% 
% * Document most public variables/functions
% * Add support for 'diff -r HEAD'
% * use filelist.sl for the listings
% * syntax highlight (DFA) in directory listing
% * fit_window() for popup buffers
% * support for SVK (http://svk.bestpractical.com/)

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
% from  http://jedmodes.sourceforge.net/
autoload("reload_buffer", "bufutils");
autoload("popup_buffer", "bufutils");
autoload("buffer_dirname", "bufutils");
autoload("strread_file", "bufutils");
require("filelist");

%% Variables %{{{
implements("svn");
provide("svn");
 
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

private variable message_buffer = " *SVN output*";
private variable diff_buffer = " *SVN diff*";
private variable list_buffer = " *SVN marked files*";
private variable dirlist_buffer = " *SVN directory list*";
private variable project_root = ""; % cache for get_op_dir()
%}}}

%% Prototypes %{{{

public define vc_add_buffer();
public define vc_list_mode();
private define update_list_buffer();
private define update_diff_buffer();
private define update_dirlist_buffer();
private define init_diff_buffer();
private define postprocess_diff_buffer();
private define diff_extract_filename();
private define list_extract_filename();
private define dirlist_extract_filename();
%}}}


%% Executing version control commands %{{{

% find out how version control is managed for `dir'
private define get_vc_system(dir)
{
   if (file_status(path_concat(dir, ".svn")) == 2)
     return "svn";
   if (file_status(path_concat(dir, "CVS")) == 2)
     return "cvs";
   % TODO: check for version control with `svk`
   % if (...)
   %   return "svk";
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
    return "\"" + str_quote_string(str, "\\\"$@", '\\') + "\"";
}
%}}}

define do_vc(args, dir, use_default_buf, signal_error) { %{{{
   variable executable, cmd, msg, result;
   switch (get_vc_system(dir)) % Errors if dir not under version control
     { case "cvs": executable = CVS_executable; }
     { case "svn": executable = SVN_executable; }

   args = array_map(String_Type, &escape_arg, args);
   cmd = strjoin([executable, args], " ");
    
#ifdef OS2 UNIX
    cmd += " 2>&1";    % re-direct stderr
#endif
    
    if (use_default_buf) {
        popup_buffer(message_buffer);
        set_readonly(0);
        erase_buffer();
    }
    
    if (chdir(dir)) {
        error("Couldn't chdir to '" + dir + "': " + errno_string(errno));
    }
    msg = "Exec: " + cmd + "\nDir: " + dir;
    flush(msg);
    insert(msg + "\n\n");
   
    result = run_shell_cmd(cmd);
    
    flush("done");
    bob();
    set_buffer_modified_flag(0);
    set_readonly(1);
    fit_window(get_blocal("is_popup", 0)); % resize popup window
    
    otherwindow();
    
    if (result and signal_error) {
        error(sprintf("svn returned error code %d", result));
    }
}
%}}}


%}}}


%% Marking files %{{{

!if (is_defined("Cvs_Mark_Type"))
   typedef struct {
      filename, 
        diff_line_mark, 
        list_line_mark, 
        dirlist_line_mark
   } Cvs_Mark_Type;


variable marks = Assoc_Type [];

private define make_line_mark () { %{{{
    return create_line_mark(color_number("menu_selection"));
}
%}}}

private define mark_file(file) { %{{{
    variable new = @Cvs_Mark_Type;
    new.filename = file;
    
    variable orig_buf = whatbuf();
    
    update_list_buffer(new);
    update_diff_buffer(new);
    update_dirlist_buffer(new);
    setbuf(orig_buf);
    
    marks[file] = new;
    %% recenter(0);
    call("redraw");
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
    marks = Assoc_Type [];
}
%}}}

public define vc_mark_buffer() { %{{{
    %% otherwindow_if_messagebuffer_active();  
    mark_file(buffer_filename());
}
%}}}

public define vc_unmark_buffer() { %{{{
    %% otherwindow_if_messagebuffer_active();    
    unmark_file(buffer_filename());
}
%}}}

define have_marked_files() { %{{{
    return length(assoc_get_keys(marks));
}
%}}}

define toggle_marked_file(file) { %{{{
    if (file != Null_String) {        
        if (assoc_key_exists(marks, file)) {
            unmark_file(file);
        } else {
            mark_file(file);
        }
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
    
    variable message = read_mini("Committing '" + file +"'. Log message: ", "", "");
    
    do_vc([ "commit", "-m", message, file ], dir, 1, 1);
    reload_buffer();
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
    if (whatbuf() == diff_buffer) {
        return diff_extract_filename();
    } else if (whatbuf() == list_buffer) {
        return list_extract_filename();
    }if (whatbuf() == dirlist_buffer) {
        return dirlist_extract_filename();
    } else {
        error("that can only be done in buffers *SVN diff* and *SVN marked files*");
    }
}
%}}}

define toggle_marked() { %{{{
    variable file, dir;
    (file, dir) = extract_filename();    
    toggle_marked_file(path_concat(file, dir));
}
%}}}

%}}}


%% "SVN diff" view %{{{

private variable diff_filenames = Assoc_Type [];

private define init_diff_buffer(dir, new_window) { %{{{
    if (new_window)
     popup_buffer(diff_buffer);
    else
      sw2buf(diff_buffer);
    
    set_readonly(0);
    erase_buffer();
    diff_filenames = Assoc_Type [];
    % set the buffer directory to dir
    setbuf_info("", dir, diff_buffer, 0);
}
%}}}

private define update_diff_buffer (mark) { %{{{
   variable orig_buf = whatbuf();
   setbuf(diff_buffer);
   if (assoc_key_exists(diff_filenames, mark.filename)) {
      variable line = diff_filenames [mark.filename];
      push_spot();
      goto_line(line);
      mark.diff_line_mark = make_line_mark();
      pop_spot();
    }
   setbuf(orig_buf);
}
%}}}

private define diff_extract_root() { %{{{
    push_spot();
    bob();
    () = down(1);
    
    EXIT_BLOCK {
        pop_spot();
    }
    
    !if (looking_at("Dir: ")) {
        error("Buffer doesn't contain a 'Dir: '-line on the second line");
    }
    
    return line_as_string()[[5:]];
}
%}}}

private define diff_extract_filename() { %{{{
    push_spot();
    
    EXIT_BLOCK {
        pop_spot();
    }
    
    if (bol_bsearch("Index: ")) {
        variable filename = line_as_string()[[7:]];
        variable dir = diff_extract_root();
        
        return (dir, filename);        
    }
    
    error("No file selected (try redoing the command between 'Index: '- lines)");
}
%}}}

private define postprocess_diff_buffer() { %{{{
    popup_buffer(diff_buffer);
    push_spot();
    bob();
    () = down(2);
    
    set_readonly(0);
    
    while (bol_fsearch("Index: ")) {
        variable filename = line_as_string()[[7:]];
        variable dir = diff_extract_root();
                
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
    pop_spot();
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
    EXIT_BLOCK {
        pop_spot();
    }
    
    variable line = line_as_string();
    
    if (andelse  {line != ""}
        {line[[0]] != " "}
        {path_is_absolute(line)})
    {
        return (path_dirname(line), path_basename(line));
    }
    
    error("Line doesn't contain a valid filename\n");
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
    setbuf(list_buffer);
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

private variable dirlist_filenames = Assoc_Type [];

private define dirlist_valid_filename(line) { %{{{
    return andelse {strlen(line) > 2} {line[[0]] != " "} {line[[1]] == " "};
}
%}}}

private define dirlist_extract_filename() %{{{
{    
    push_spot();
    EXIT_BLOCK {
        pop_spot();
    }
    
    variable line = line_as_string();
    
    if (dirlist_valid_filename(line))
    {
        variable file = strtrim(line[[2:]]);
        variable dir = diff_extract_root();
        
        return (dir, file);
    }
    
    error("Line doesn't contain a valid filename\n");
}
%}}}

private define update_dirlist_buffer(mark) { %{{{
    setbuf(dirlist_buffer);
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

private define postprocess_dirlist_buffer() { %{{{
    push_spot();
    bob();
    () = down(2);
    
    set_readonly(0);
    
    while (down(1)) {
        if (dirlist_valid_filename(line_as_string())) {
            variable filename, dir;
            (dir, filename) = dirlist_extract_filename();
            
            filename = path_concat(dir, filename);
            dirlist_filenames[filename] = what_line();
            
            if (assoc_key_exists(marks, filename)) {
                update_dirlist_buffer(marks[filename]);
            }
        }
    }    
    set_readonly(1);
    
    pop_spot();
}

%}}}

% Set dirctory for VC operations.
% TODO: ¿cache default (current behaviour) or use dir of current buffer?
private define get_op_dir() { %{{{
   if (project_root == "") {
      project_root = buffer_dirname();
   } 
   project_root = read_with_completion("Enter dir for operation: ", 
                                        "", project_root, 'f');
   return project_root;
}
%}}}

public define vc_list_dir() { %{{{
   variable dir = get_op_dir();
    
   sw2buf(dirlist_buffer);
   vc_list_mode();
   % set buffer directory and unset readonly flag
   setbuf_info("", dir, dirlist_buffer, 0);
   erase_buffer();
   
   % cvs returns a very verbose list with the status command 
   % the info recommends a dry-run of update for a short list
   switch (get_vc_system(dir))
     { case "cvs": do_vc(["-n", "-q", "update"], dir, 0, 0); }
     { do_vc(["status"], dir, 0, 0); }
   
   % return to directory listing and postprocess
   otherwindow();
   sw2buf(dirlist_buffer);
   postprocess_dirlist_buffer();
}
%}}}

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
    variable dir, rfiles;    
    (dir, rfiles) = find_marked_common_root();
    
    variable message = read_mini("Committing all marked files. Log message: ", "", "");
    
    do_vc(["commit", "-m", message, rfiles], dir, 1, 1);
    
    vc_unmark_all();
}
%}}}

public define vc_diff_marked() { %{{{
    variable dir, rfiles;    
    (dir, rfiles) = find_marked_common_root();
    
    init_diff_buffer(dir, 1);

    do_vc(["diff", rfiles], dir, 0, 0);
    postprocess_diff_buffer();

    sw2buf(diff_buffer);
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
    variable dir, file;
    (dir, file) = extract_filename();    
    do_vc(["add", file], dir, 1, 1);
}
%}}}

public define vc_commit_selected() { %{{{
    variable dir, file;
    (dir, file) = extract_filename();    
    variable message = read_mini("Committing '" + file + "'. Log message: ", "", "");
    
    do_vc(["commit", "-m", message, file], dir, 1, 1);
}
%}}}

public define vc_diff_selected() { %{{{
    variable dir, file;
    (dir, file) = extract_filename();
    init_diff_buffer(dir, 1);
    do_vc(["diff", file], dir, 0, 0);
    postprocess_diff_buffer();
}
%}}}

public define vc_update_selected() { %{{{
    variable dir, file;
    (dir, file) = extract_filename();
    do_vc(["update", file], dir, 1, 1);
}
%}}}

public define vc_revert_selected() { %{{{
    variable dir, file;
    (dir, file) = extract_filename();
    
    variable a = ' ';
    
    while (a != 'y' and a != 'n') {
        a = get_mini_response("Revert '" + file + "' [ny]?");    
    } 
    
    if (a == 'y') {    
        do_vc(["revert", file], dir, 1, 1);
    }
}
%}}}

public define vc_open_selected() { %{{{
    variable dir, file, linenum;
    (dir, file) = extract_filename();
    
    if (whatbuf() == diff_buffer) {
        linenum = diff_extract_linenumber();
    } else {
        linenum = 0; 
    }
    
    otherwindow();
    find_file(path_concat(dir, file));
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
     { case "svn": do_vc(["add", "--non-recursive", name], parent, 1, 1); }
}
%}}}

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
   menu_append_separator(menu);
   
   menu_append_item(menu, "&toggle Mark", "svn->toggle_marked");
   menu_append_item(menu, "Unmark all", "vc_unmark_all");
   menu_append_separator(menu);

   vc_commom_menu_callback(menu);
   menu_append_separator(menu);
   
   menu_append_item(menu, "&Quit", "close_buffer");
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
   definekey("vc_update_selected", "u", kmap);
   definekey("vc_open_selected", "\r", kmap);
   definekey("vc_revert_selected", "r", kmap);
   
   definekey("svn->toggle_marked", Key_Ins, kmap);
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

% VC list mode

public define vc_list_mode()
{
   set_mode("vc-list", 0);
   mode_set_mode_info("vc-list", "init_mode_menu", 
      &svn->vc_list_menu_callback);
   use_keymap("svn-list");
}   

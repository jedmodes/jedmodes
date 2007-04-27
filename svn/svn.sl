% -*- mode: slang -*-
%
% (Standard MIT/X11 license follows)
% 
% Copyright (c) 2003,2006 Juho Snellman
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
% Utilities for CVS access from jed. 
% 
%    ** Installation **
% 
% Add this file into a directory that's in your "Jed library path" (try
% M-X get_jed_library_path() to see what this is). 
% 
% After that, copy
% the <INITIALIZATION> block into your .jedrc (or run update_ini() from
% jedmodes.sf.net/mode/make_ini/)
%  
%    ** Functionality **
%   
% Only the most common (for me) CVS operations are supported (add, commit,
% diff, update). The operations can be targeted at a single buffer,
% a bunch of files that have been marked, or at whole directories.
% 
%    * Operations on buffers *
%
%   In general, the buffer operations will save the buffer before
%   doing the operation.
%   
%     C-c a    'cvs add'    file
%     C-c c    'cvs commit' file
%     C-c u    'cvs update' file
%     C-c d    'cvs diff'   file
%     C-c m m  Mark the file for batch operations
%     
%     
%    * Operations on marked files *
%   
%   The easiest way to operate on marked files is to use the following
%   command to open the marked file list buffer, from where you can easily
%   start the other operations using keybindings specific to that
%   buffer.
%   
%     C-c l  show list of marked files
%   
%   The commands for operating on marked files are also available as
%   general keyboard commands, for those who find them more convenient.
%   
%     C-c m a    'cvs add'    all marked files
%     C-c m c    'cvs commit' all marked files
%     C-c m u    'cvs update' all marked files
%     C-c m d    'cvs diff'   all marked files
%     
%   For convenience, committing all marked files also unmarks the files.
%   
%     
%    * Operation on directories *
%    
%   The directory operations ask the user for a directory before
%   executing. The question defaults to the previous directory given.
%     
%     C-c C-a    'cvs add'    directory
%     C-c C-c    'cvs commit' directory
%     C-c C-u    'cvs update' directory
%     
%     C-c C-l    open directory view (basically a 'cvs -qnf update')
%     
%   Directory level commit is not supported.
%     
%     
%    * Diff/directory views *
% 
%   Operations on single/marked files can also be applied from inside
%   a *CVS diff* or *CVS dirlist* buffer, using the same keybindings
%   as in a *CVS marked files* buffer. These views are probably the 
%   most convenient methods for committing a large number of files,
%   or doing only selective updates on a project.
% 
% 
% Most of the above commands are also accessible from the File/CVS 
% menu.
%
%
%    ** Customization **
%  
% The following variables are available for modifying the behaviour
% of this module.
%      
%   cvs_executable:  [/usr/bin/cvs/] 
%     The location of the cvs executable
%     
%   cvs_set_reserved_keybindings: [1]
%     By default, the initialization routines set up global keybindings,
%     using the reserved prefix (defaults to C-c). Giving setting this 
%     variable to zero *before the file is evaluated* prevents the 
%     keybindings from being created.
%   
%   cvs_help: [1]
%     Setting this variable to 0 disables showing the keyboard help
%     in the marked files, diff, and directory list views.
%     
%    
%    ** Todo **
% 
%  - Document most public variables/functions
%  - Add support for 'diff -r HEAD'
%    
%
%    ** Changelog **
% 
% 2003-05-31 / Juho Snellman <jsnell@iki.fi>
%   * First public release
%   
% 2003-05-31 / Juho Snellman <jsnell@iki.fi>
%   * Run diff with -q
%   * Protect the Cvs_Mark_Type declaration inside a "!if (reloading)"
%   
% 2003-06-02 / Juho Snellman <jsnell@iki.fi>
%   * Switch the commands affecting selected file to lowercase letters,
%     since they seem to get used a lot more.
%   * Add revert (cvs update -C)
%   
% 2003-12-09 / Juho Snellman <jsnell@iki.fi>
%   * Fix find_marked_common_root
%   
% 2006-11-21 / Juho Snellman <jsnell@iki.fi>
%   * Rough SVN port
% 2007-04-27 / Guenter Milde <milde users.sf.net>
%   * <INITIALIZATION> block replacing the evaluation of svn.sl at startup
%   * bugfix: return to directory listing before postprocessing
%   * use popup_buffer instead of pop2buf: 
%     - closing with close_buffer() closes the window as well 
%       (if it wasn't open before).
%   
% TODO: 
%   * syntax highlight (DFA) in directory listing
%   * auto-determine if cvs or svn is used (check for .CVS or .svn dir)
%   * fit_window() for popup buffers
   
% Uncomment these for bug hunting
% _debug_info=1; _traceback=1; _slangtrace=1;

#<INITIALIZATION>
% the CVS menu 
autoload("svn_menu_callback", "svn");
define svn_load_popup_hook(menubar)
{
   variable menu = "Global.&File";
   menu_insert_popup("Canc&el Operation", menu, "&Version Control");
   menu_insert_separator("Canc&el Operation", menu);
   menu_set_select_popup_callback(menu+".&Version Control", &svn_menu_callback);
}
append_to_hook("load_popup_hooks", &svn_load_popup_hook);
#</INITIALIZATION>


% Requirements
% from  http://jedmodes.sourceforge.net/
autoload("reload_buffer", "bufutils");
autoload("popup_buffer", "bufutils");

%% Variables %{{{
implements("svn");
provide("svn");

custom_variable("cvs_executable", "/usr/bin/svn");
custom_variable("cvs_set_reserved_keybindings", 1);
custom_variable("cvs_help", 1);

private variable message_buffer = " *CVS output*";
private variable diff_buffer = " *CVS diff*";
private variable list_buffer = " *CVS marked files*";
private variable dirlist_buffer = " *CVS directory list*";
variable project_root = "";
%}}}

%% Prototypes %{{{

public define cvs_add_buffer();

private define setbuf_unmodified();
private define killbuf();
private define setbuf_ro();
private define save_buffer_if_modified();
private define otherwindow_if_messagebuffer_active();
private define buffer_filename(buf);
private define buffer_dirname(buf);
private define require_buffer_dir_in_cvs();
private define entries_contains_filename(entries, filename);
private define require_buffer_file_in_cvs();
private define escape (str);
private define make_line_mark ();
private define mark_file(file);
private define unmark_file(file);
private define init_diff_buffer(new_window);
private define extract_filename();
private define insert_help();
private define update_diff_buffer (mark);
private define diff_extract_root();
private define diff_extract_filename();
private define postprocess_diff_buffer();
private define list_extract_filename();
private define init_list_buffer(erase);
private define update_list_buffer (mark);
private define dirlist_extract_filename();
private define update_dirlist_buffer (mark);
private define array_concat(a, b);
private define find_marked_common_root();
private define get_op_dir();
private define menu_init();
private define keymap_init();
%}}}

%% Manipulating buffers/windows %{{{

private define setbuf_unmodified() { %{{{
    setbuf_info( getbuf_info() & ~1 );
}
%}}}

private define killbuf() { %{{{
    setbuf_unmodified();
    delbuf(whatbuf());
}
%}}}

private define setbuf_ro() { %{{{
    setbuf_unmodified();
    set_readonly(1);
}
%}}}

private define save_buffer_if_modified() { %{{{
    variable flags;
    (,,,flags) =  getbuf_info();
    
    if (flags & 1) {
        save_buffer();
    }
}
%}}}

%% Actually, experience shows that this was a really bad idea. Code
%% not deleted in case someone actually wants to use it.
private define otherwindow_if_messagebuffer_active() { %{{{
    variable file; 
    (file,,,) = getbuf_info();
    
    % For the user's convenience. If we're currently in the CVS
    % output buffer (for example due to scrolling through a cvs diff), and 
    % there's exactly one other window visible, switch to that window 
    % and continue. 
    if (file == "") {
        if (nwindows != 2) {
            error("Active buffer doesn't contain a file. Can't execute CVS functions.");
        } 
        otherwindow();
        
        (file,,,) = getbuf_info();        
        if (file == "") {
            otherwindow();
            error("No visible window contains a file. Can't execute CVS functions.");
        }
    }
}

%}}}

private define buffer_filename(buf) { %{{{
    if (bufferp(buf)) {
        variable file, dir;
        (file, dir,,) = getbuf_info(buf);
        return path_concat(dir, file);
    } else {
        return "";
    }
}
%}}}

private define buffer_dirname(buf) { %{{{
    if (bufferp(buf)) {
        variable file, dir;
        (, dir,,) = getbuf_info(buf);
        return dir;
    } else {
        return "";
    }
}
%}}}


%}}}


%% Executing CVS commands %{{{

private define require_buffer_dir_in_cvs() { %{{{
    %% otherwindow_if_messagebuffer_active();
    
    variable file, dir; 
    (file, dir,,) = getbuf_info ( whatbuf() );
    
    if (file == Null_String or file == "") {
        error("Can't do CVS operations on buffers that don't contain a file.");
    }
    
    variable cvs_dir = path_concat(dir, ".svn");
    variable entries = path_concat(cvs_dir, "entries");
    
    if (file_status(cvs_dir) != 2) {
        error("Working directory " + dir + " lacks .svn/ subdirectory");
    }
    
    if (file_status(entries) != 1) {
        error("Working directory " + dir + " lacks .svn/entries");
    }
    
    return (file, dir);
}
%}}}

private define entries_contains_filename(entries, filename) { %{{{
    variable origbuf = whatbuf();
    
    setbuf(" *Entries*");
    erase_buffer();
    insert_file(entries);
    bob();
    
    variable found = fsearch("name=\"" + filename + "\"");
    
    erase_buffer();
    killbuf();
    setbuf(origbuf);
    
    return found;
}
%}}}

private define require_buffer_file_in_cvs() { %{{{
    variable file, dir; 
    (file, dir) = require_buffer_dir_in_cvs();
    
    variable cvs_dir = path_concat(dir, ".svn");
    variable entries = path_concat(cvs_dir, "entries");

    !if (entries_contains_filename(entries, file)) {
        variable res = 0;
        
        while (res != 'y' and res != 'n') {
            res = get_mini_response("File " + file +
                                    " not found in .svn/entries. Add it [yn]? ");
        }
        
        if (res == 'y') {
            cvs_add_buffer();
        } else {
            error("Unable to proceed");
        }
    }
    
    return (file, dir);
}
%}}}

private define escape (str) { %{{{
    return "\"" + str_quote_string(str, "\\\"$@", '\\') + "\"";
}
%}}}

define do_cvs (args, dir, use_default_buf, signal_error) { %{{{
    variable cmd = cvs_executable + " " +
      strjoin(array_map(String_Type, &escape, args), " ");        
    
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
    
    insert("Exec: " + cmd + "\nDir: " + dir + "\n\n");
    variable ret = run_shell_cmd(cmd);
    bob();
    setbuf_ro();
    
    otherwindow();
    
    if (ret and signal_error) {
        error(sprintf("cvs returned error code %d", ret));
    }
}
%}}}


%}}}


%% Marking files %{{{

!if (is_defined("Cvs_Mark_Type"))
   typedef struct {
      filename, diff_line_mark, list_line_mark, dirlist_line_mark
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

public define cvs_unmark_all() { %{{{
    marks = Assoc_Type [];
}
%}}}

public define cvs_mark_buffer() { %{{{
    %% otherwindow_if_messagebuffer_active();  
    mark_file(buffer_filename(whatbuf()));
}
%}}}

public define cvs_unmark_buffer() { %{{{
    %% otherwindow_if_messagebuffer_active();    
    unmark_file(buffer_filename(whatbuf()));
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


%% CVS operations on a single buffer %{{{

public define cvs_add_buffer() { %{{{
    variable file, dir;
    (file, dir) = require_buffer_dir_in_cvs();
    do_cvs([ "add", file ], dir, 1, 1);
}
%}}}

public define cvs_commit_buffer() { %{{{
    variable file, dir;
    (file, dir) = require_buffer_file_in_cvs();
    save_buffer_if_modified();
    
    variable message = read_mini("Committing '" + file +"'. Log message: ", "", "");
    
    do_cvs([ "commit", "-m", message, file ], dir, 1, 1);
    reload_buffer();
}
%}}}

public define cvs_diff_buffer() { %{{{
    variable file, dir;
    (file, dir) = require_buffer_file_in_cvs();
    save_buffer_if_modified();
    
    init_diff_buffer(1);
    
    do_cvs([ "diff", file ], dir, 0, 0);
    
    postprocess_diff_buffer();
}
%}}}

public define cvs_update_buffer() { %{{{
    variable file, dir;
    (file, dir) = require_buffer_file_in_cvs();
    save_buffer_if_modified();
    
    do_cvs([ "update", file ], dir, 1, 1);
    
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
        error("that can only be done in buffers *CVS diff* and *CVS marked files*");
    }
}
%}}}

define toggle_marked() { %{{{
    variable file, dir;
    (file, dir) = extract_filename();    
    toggle_marked_file(path_concat(file, dir));
}
%}}}

private define insert_help() { %{{{
    if (cvs_help) {
        insert("Commands:\n" +
               "  Affect selected file:    a:Add  c:Commit  d:Diff  u:Update\n" +
               "                           m:Toggle mark r:revert\n" +
               "  Affect all marked files: A:Add  C:Commit  D:Diff  U:Update\n" +
               "  Other:                   M:Unmark all  q:Close this window\n\n");
    }
}
%}}}

%}}}


%% "CVS diff" view %{{{

private variable diff_filenames = Assoc_Type [];

private define init_diff_buffer(new_window) { %{{{
    if (new_window)
     popup_buffer(diff_buffer);
    else
      sw2buf(diff_buffer);
    
    use_keymap("cvs-list");
    set_readonly(0);
    erase_buffer();
    diff_filenames = Assoc_Type [];
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
    insert_help();
    
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


%% "CVS marked files" view %{{{

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
    set_mode("cvs-list", 0);
    use_keymap("cvs-list");
    set_readonly(0);
    
    if (erase)
      erase_buffer();
    
    push_spot();
    bob();
    
    if (eobp()) {
        insert("The following files have been marked by CVS mode. ");
        insert_help();
    } else {
        pop_spot();
    }
}
%}}}

public define cvs_list_marked() { %{{{
    popup_buffer(list_buffer);
    
    init_list_buffer(1);
    
    insert("  ----- \n");

    push_spot();
    foreach (marks) using ("keys") {
        variable file = ();
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


%% "CVS directory list" view %{{{

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
        variable file = line[[2:]];
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
    insert_help();
    
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

public define cvs_list_dir() { %{{{
    variable dir = get_op_dir();
    
    sw2buf(dirlist_buffer);
    use_keymap("cvs-list");
    set_readonly(0);
    erase_buffer();
    
    do_cvs(["status"], dir, 0, 0);
   
    % return to directory listing and postprocess
    otherwindow();
    sw2buf(dirlist_buffer);
    postprocess_dirlist_buffer();
}
%}}}

%}}}


%% Operations on all marked files %{{{

% I refuse to believe there's no easier way merge two arrays...
private define array_concat(a, b) { %{{{
    variable lena = length(a);
    variable lenb = length(b);
    variable new = String_Type [lena + lenb];
    variable i;
    
    for (i = 0; i < lena; i++) {
        new[i] = a[i];
    }
    
    for (i = 0; i < lenb; i++) {
        new[i + lena] = b[i];
    }
    
    return new;
}
%}}}

private define find_marked_common_root() { %{{{
    variable afiles = assoc_get_keys(marks);
    if (length(afiles) == 0) {
        error("No files marked");
    }
    
    variable dirs = array_map(String_Type, &path_dirname, afiles);
    variable rfiles = String_Type [length(afiles)];
    
    variable prefix = "";
    
    foreach (dirs) {
        variable dir = ();
        
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

public define cvs_add_marked() { %{{{
    variable dir, rfiles;    
    (dir, rfiles) = find_marked_common_root();
    
    do_cvs(array_concat( ["add"], rfiles ), dir, 1, 1);
}
%}}}

public define cvs_commit_marked() { %{{{
    variable dir, rfiles;    
    (dir, rfiles) = find_marked_common_root();
    
    variable message = read_mini("Committing all marked files. Log message: ", "", "");
    
    do_cvs(array_concat( ["commit", "-m", message], rfiles ), dir, 1, 1);
    
    cvs_unmark_all();
}
%}}}

public define cvs_diff_marked() { %{{{
    variable dir, rfiles;    
    (dir, rfiles) = find_marked_common_root();
    
    init_diff_buffer(1);
    
    do_cvs(array_concat( ["diff"], rfiles ), dir, 0, 0);
    postprocess_diff_buffer();

    sw2buf(diff_buffer);
}
%}}}

public define cvs_update_marked() { %{{{
    variable dir, rfiles;    
    (dir, rfiles) = find_marked_common_root();
    
    do_cvs(array_concat( ["update"], rfiles ), dir, 1, 1);
}
%}}}

%}}}


%% Operations on single files (valid only in marked files, diff, or 
%% directory list buffers). %{{{

public define cvs_add_selected() { %{{{
    variable dir, file;
    (dir, file) = extract_filename();    
    do_cvs(["add", file], dir, 1, 1);
}
%}}}

public define cvs_commit_selected() { %{{{
    variable dir, file;
    (dir, file) = extract_filename();    
    variable message = read_mini("Committing '" + file + "'. Log message: ", "", "");
    
    do_cvs(["commit", "-m", message, file], dir, 1, 1);
}
%}}}

public define cvs_diff_selected() { %{{{
    variable dir, file;
    (dir, file) = extract_filename();
    init_diff_buffer(1);
    do_cvs(["diff", file], dir, 0, 0);
    postprocess_diff_buffer();
}
%}}}

public define cvs_update_selected() { %{{{
    variable dir, file;
    (dir, file) = extract_filename();
    do_cvs(["update", file], dir, 1, 1);
}
%}}}

public define cvs_revert_selected() { %{{{
    variable dir, file;
    (dir, file) = extract_filename();
    
    variable a = ' ';
    
    while (a != 'y' and a != 'n') {
        a = get_mini_response("Revert '" + file + "' [ny]?");    
    } 
    
    if (a == 'y') {    
        do_cvs(["revert", file], dir, 1, 1);
    }
}
%}}}

public define cvs_open_selected() { %{{{
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


%% CVS directory-level operations %{{{

private define get_op_dir() { %{{{
    variable default = project_root;
    
    if (default == "") {
        default = getcwd();
    } 
    
    % Filename completion wants to use the directory of the current
    % buffer as a prefix, even if a default value is given. Use
    % this massive kludge as a workaround. (We also need tinker with
    % cwd for the same reason).
    
    variable orig_buf = whatbuf();
    ERROR_BLOCK {
        sw2buf(orig_buf);    
    }
    
    sw2buf(" *Kludge*");
    setbuf_info("", "", " *Kludge*", 0);
    chdir(default);
    
    variable dir = read_with_completion("Enter dir for operation: ", 
                                        Null_String, Null_String, 'f');

    sw2buf(orig_buf);
    
    project_root = dir;
    
    return project_root;
}
%}}}

public define cvs_add_dir() { %{{{ 
    %% Kludge to get rid of a possible trailing separator
    variable dir = path_dirname(path_concat(get_op_dir(), "foo"));
    variable parent = path_dirname(dir);
    variable name = path_basename(dir);
    
    do_cvs(["add", name], parent, 1, 1);
}
%}}}

public define cvs_diff_dir() { %{{{
    variable dir = get_op_dir();
    
    init_diff_buffer(0);
        
    do_cvs(["diff"], dir, 0, 0);    
    postprocess_diff_buffer();
}
%}}}

public define cvs_update_dir() { %{{{
    variable dir = get_op_dir();
    do_cvs(["-q", "update"], dir, 1, 1);
}
%}}}

%}}}


%% Internal development helpers %{{{

public define cvs_re_eval() { %{{{
   () = evalfile("cvs");
}
%}}}

%}}}


%% Initialization %{{{

public define svn_menu_callback(menu) { %{{{
    menu_append_item(menu, "&Add buffer", "cvs_add_buffer");
    menu_append_item(menu, "&Commit buffer", "cvs_commit_buffer");
    menu_append_item(menu, "&Diff buffer", "cvs_diff_buffer");
    menu_append_item(menu, "&Mark buffer", "cvs_mark_buffer");
    menu_append_item(menu, "Unmark buffer", "cvs_unmark_buffer");
    menu_append_item(menu, "&Update buffer", "cvs_update_buffer");
    menu_append_separator(menu);
    
    menu_append_item(menu, "&List marked", "cvs_list_marked");
    menu_append_item(menu, "Add marked", "cvs_add_marked");
    menu_append_item(menu, "Commit marked", "cvs_commit_marked");
    menu_append_item(menu, "Diff marked", "cvs_diff_marked");
    menu_append_item(menu, "Unmark all", "cvs_unmark_all");
    menu_append_item(menu, "Update marked", "cvs_update_marked");
    menu_append_separator(menu);
    
    menu_append_item(menu, "Add directory", "cvs_add_dir");
    menu_append_item(menu, "Diff directory", "cvs_diff_dir");
    menu_append_item(menu, "Update directory", "cvs_update_dir");
    menu_append_item(menu, "Open directory list", "cvs_list_dir");
}
%}}}

private define keymap_init() { %{{{
    if (cvs_set_reserved_keybindings) {
        setkey_reserved( "cvs_add_buffer", "a");
        setkey_reserved( "cvs_add_marked", "ma");
        setkey_reserved( "cvs_add_dir", "^a");
    
        setkey_reserved( "cvs_commit_buffer", "c");
        setkey_reserved( "cvs_commit_marked", "mc");
    
        setkey_reserved( "cvs_diff_buffer", "d");
        setkey_reserved( "cvs_diff_marked", "md");
        setkey_reserved( "cvs_diff_dir", "^d");
        
        setkey_reserved( "cvs_list_marked", "l");
        setkey_reserved( "cvs_list_marked", "ml");
        setkey_reserved( "cvs_list_dir", "^l");
        
        setkey_reserved( "cvs_mark_buffer", "mm");
        setkey_reserved( "cvs_unmark_buffer", "m^m");
        setkey_reserved( "cvs_unmark_all", "m^u");
        
        setkey_reserved( "cvs_update_buffer", "u");
        setkey_reserved( "cvs_update_marked", "mu");
        setkey_reserved( "cvs_update_dir", "^u");
        
        setkey_reserved( "cvs_re_eval", "r");
    }
    
    variable kmap = "cvs-list";
    
    !if (keymap_p(kmap)) {
        make_keymap(kmap);
        definekey("cvs_add_marked", "A", kmap);
        definekey("cvs_commit_marked", "C", kmap);
        definekey("cvs_diff_marked", "D", kmap);
        definekey("cvs_update_marked", "U", kmap);
        
        definekey("cvs_add_selected", "a", kmap);
        definekey("cvs_commit_selected", "c", kmap);
        definekey("cvs_diff_selected", "d", kmap);
        definekey("cvs_update_selected", "u", kmap);
        definekey("cvs_open_selected", "o", kmap);
        definekey("cvs_revert_selected", "r", kmap);
        
        definekey("cvs->toggle_marked", "m", kmap);
        definekey("cvs->toggle_marked", " ", kmap);
        definekey("cvs->toggle_marked", "\r", kmap);
        definekey("cvs_unmark_all", "M", kmap);
        definekey("delete_window", "q", kmap);
        
    }
    
}
%}}}

menu_init();
keymap_init();

%}}}


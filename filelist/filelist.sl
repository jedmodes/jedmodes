% filelist.sl
% A special mode for file listings (ls, ls -a, locate)
% -> replace/extend dired mode
%
% Copyright (c) 2005 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Version   0.9   * initial version (beta)
%           0.9.1 (based on report by Paul Boekholt)
%                 * added USAGE documentation (including ...find_file_hook)
%                 * filelist_list_dir:
%                   + directories end in "/" ("\" with DOS-like OS-es)
%                     when listing with listdir
%                   + If no dir argument given, ask in minibuffer
%                 * filelist_open_file:
%                   use filelist_list_dir, if filename is a directory,
%                   goto line of child-dir if stepping up with ".."
%                 * bugfixes (and maybe new bugs =:-( )
% 	    	  * color syntax (DFA: mark directories)
% 	    	  * Mode directory
% 	    	  * dired-bindings (Paul Boekholt)
% 	      	  * works with PB-s tar_mode: a tar file is opened in tar-mode
% 2003-08-18  0.9.2 * bugfix to filelist_list_dir
% 2003-12-19  0.9.3   several fixes by Paul Boekholt, including
%                 * new functions for regexp-rename, tar and grep bindings
% 2004-02-19  0.9.4 * bugfix: filelist_delete_file now deletes also
%                     (empty) directories. (PB)
% 2004-07-07  1.0   if a file ends in .gz, check for another extension
% 2004-10-11  1.1   bugfix in filelist_list_base_dir()
% 2004-11-22  1.2   FileList_Trash_Bin now defaults to "" (delete files)
% 2005-03-18  1.2.1 added definition of filelist_find_file_hook() (was in doc)
% 2005-04-28  1.3   moved definition and call of filelist_find_file_hook() to
% 	      	    INITALIZATION block, i.e. with make_ini and home-lib
% 	      	    modes you will have this hook as default.
% 	      	    bugfix: extract_line_no gave error with filenames like
% 	      	    	    00debian.sl.
% 2005-05-13  1.3.1 filelist_open_file_with() now checks whether the file is
%                   a directory and (calls filelist_list_dir in this case)
%                   Thus, a directory ".lyx" will not be opened as a lyx file
% 2005-06-01  1.4   extract_filename() now uses whitespace as default delimiter
% 2005-11-08  1.4.1 changed _implements() to implements()
% 2005-11-23  1.5   added documentation for public functions and custom vars
%                   new function filelist_open_tagged() (initiated by T. Koeckritz)
%                   removed dependency on grep.sl (now recommandation)
% 2005-11-25  1.5.1 bugfix: mark directories and cleanup again
% 	      	    code cleanup regarding FileList_Cleanup
% 2006-02-16  1.5.2 added fit_window() to autoloads (report Mirko Rzehak)
% 2006-03-13  1.5.3 USAGE docu fix
% 2006-05-23  1.6   Copy and delete instead of rename if the destination is
%                   on a different filesystem.
% 2007-04-16  1.7   Changed the keybinding for (i)search from '^S' to 's'
% 	      	    to match the one in tokenlist and keep the original '^S'.
%
%
% TODO: * more bindings of actions: filelist_cua_bindings
%       * copy from filelist to filelist ...
%         ^C copy : cua_copy_region und copy_tagged (in separaten buffer)
%         ^X kill:  yp_kill_region und kill_tagged    ""   ""        ""
%         ^V filelist_insert (im filelist modus)
%         bzw die bindungen abfragen.
% 	* detailed directory listing (ls -l)
%       * custom_variable("dir_ls_cmd", "ls -la --quoting-style=shell")
% 	* quoting of special file names
% 	* give error reason with errno/errno_string (if not automatically done)
%       * use MIME_types and mailcap (view and edit commands) for
%         FileList_Default_Commands
%
% USAGE:
% * Place filelist.sl and required files in your library path.

% * Use filelist_list_dir() to open a directory in the "jed-file-manager"

% * To make file finding functions list the directory contents
%   if called with a directory path as argument (instead of reporting
%   an error), insert the content of the INITALIZATION block into your
%   .jedrc (or jed.rc) (or use the "make_ini" and "home-lib" modes from
%   jedmodes.sf.net)

#<INITIALIZATION>
"filelist_list_dir", "filelist.sl";
"filelist_mode", "filelist.sl";
"locate", "filelist.sl";
_autoload(3);
_add_completion("locate", "filelist_mode", 2);

define filelist_find_file_hook(filename)
{
   if (file_status(filename) == 2)
     {
	filelist_list_dir(filename);
	return 1; % abort hook chain, do not use the function actually called
     }
   return 0;  % try other hooks or use opening function
}
append_to_hook("_jed_find_file_before_hooks", &filelist_find_file_hook);
#</INITIALIZATION>

% _debug_info = 1;

% --- Requirements ------------------------------------------------------

require("listing");  % the listing widget, depends on datutils
"get_blocal", "sl_utils";
"run_function", "sl_utils";
"push_defaults", "sl_utils";
"push_array", "sl_utils";
"buffer_dirname", "bufutils";
"close_buffer", "bufutils";
"popup_buffer", "bufutils";
"fit_window", "bufutils";
"string_get_match", "strutils";
"get_line", "txtutils";
_autoload(10);
% optional extensions
if(strlen(expand_jedlib_file("filelistmsc")))
  _autoload("filelist_do_rename_regexp", "filelistmsc",
	    "filelist_do_tar", "filelistmsc", 2);

provide("filelist");

implements("filelist");
variable mode = "filelist";

% --- Custom Variables ----------------------------------------------------

%!%+
%\variable{FileList_Action_Scope}
%\synopsis{What files should filelist actions be applied to}
%\usage{Int_Type FileList_Action_Scope = 1}
%\description
% What files should actions like move, delete, open_with be applied to
%     0 current line                                        (MC-macro "%f")
%     1 tagged lines or current line, if no line is tagged. (MC-macro "%s")
%     2 tagged lines 		      	    	    	    (MC-macro "%t")
%\seealso{filelist_mode, filelist_open_tagged, filelist_rename_tagged, filelist_delete_tagged}
%!%-
custom_variable("FileList_Action_Scope", 1);

%!%+
%\variable{FileList_KeyBindings}
%\synopsis{Keybinding set for the filelist mode}
%\usage{String_Type FileList_KeyBindings = ""mc""}
%\description
%  Which set of keybindings should the filelist mode emulate?
%  ("mc" or "dired")
%\seealso{filelist_mode}
%!%-
custom_variable("FileList_KeyBindings", "mc");

%!%+
%\variable{FileList_Cleanup}
%\synopsis{Close a filelist when leaving?}
%\usage{Int_Type FileList_Cleanup = 1}
%\description
%  Close the directory listing when opening a file/dir from it?
%
%    0 keep open,
%    1 close when going to a new directory,
%    2 always close,
%\seealso{filelist_mode}
%!%-
custom_variable("FileList_Cleanup", 1);

%!%+
%\variable{FileList_max_window_size}
%\synopsis{}
%\usage{FileList_max_window_size = 1.0}
%\description
%  How big shall the filelist window be maximal
%    Integer: no. of rows,
%             0 do not fit to content size
%    Float:   screen-fraction,
%             1.0 no limit
%\seealso{filelist_mode, fit_window}
%!%-
custom_variable("FileList_max_window_size", 1.0);  % my default is full screen

%!%+
%\variable{FileList_Trash_Bin}
%\synopsis{Trash bin for files deleted in \sfun{filelist_mode}}
%\usage{String_Type FileList_Trash_Bin = ""}
%\description
% Directory, where deleted files are moved to.
% The default "" means real deleting.
% KDE users might want to set this to "~/Desktop/Trash"
% \notes
%  The value will be expanded with \sfun{expand_filename}.
%  The Trash_Bin will be checked for existence in filelist_delete_tagged,
%\seealso{filelist_mode, filelist_delete_tagged}
%!%-
custom_variable("FileList_Trash_Bin", "");
if (FileList_Trash_Bin != "")
   FileList_Trash_Bin = expand_filename(FileList_Trash_Bin);

% --- Static Variables ----------------------------------------------------
% Add to/Change in the filelist_mode_hook

% Default values for command opening a file with a certain extension
% The command is called via system(command + file + "&")
static variable FileList_Default_Commands = Assoc_Type[String_Type, ""];

% under xjed and jed in xterm use X programs
if (getenv("DISPLAY") != NULL) % assume X-Windows running
{
   FileList_Default_Commands[".eps"]     = "gv";
   FileList_Default_Commands[".ps"]      = "gv";
   FileList_Default_Commands[".ps.gz"]   = "gv";
   FileList_Default_Commands[".pdf"]     = "xpdf";
   FileList_Default_Commands[".pdf.gz"]  = "gv";
   FileList_Default_Commands[".dvi"]     = "xdvi";
   FileList_Default_Commands[".dvi.gz"]  = "xdvi";
   FileList_Default_Commands[".lyx"]     = "lyx-remote";
   FileList_Default_Commands[".html"]    = "dillo";   % fast and light browser
   FileList_Default_Commands[".htm"]     = "dillo";   % fast and light browser
   FileList_Default_Commands[".gnuplot"] = "gnuplot -persist";
   FileList_Default_Commands[".jpg"]     = "display";
   FileList_Default_Commands[".jpeg"]    = "display";
   FileList_Default_Commands[".gif"]     = "display";
   FileList_Default_Commands[".png"]     = "display";
   FileList_Default_Commands[".xpm"]     = "display";
   FileList_Default_Commands[".sk"]      = "sketch";
   FileList_Default_Commands[".dia"]     = "dia";
}

static variable listing = "listing";
static variable FileListBuffer = "*file-listing*";

static variable LAST_LOCATE = "";
static variable Dir_Sep = path_concat("a", "")[[1:]];  % path separator

% ------ Function definitions -------------------------------------------

public  define filelist_mode(); % forward definition

% truncate a string to the n last characters (prepending "..." if n >= 4)
static define strtail(str, n)
{
   if (strlen(str) <= n)
     return str;
   
   if (n >= 4)
     return "..." +  str[[-(n-3):]];
   return str[[-n:]];
}
   

% Extract the filename out of a string (with position given as blocal-var)
% Str = extract_filename(Str line)
static define extract_filename(line)
{
   % some listings refer to only one file, omitting it in the list
   variable filename = get_blocal("filename", "");

   !if (strlen(filename))
     {
	variable fp = get_blocal("filename_position", 0);
	variable del = get_blocal("delimiter");
	if (del == NULL)
	   filename = strtok(line)[fp];
	else
	  filename = extract_element(line, fp, del);
     }
   % remove trailing path-separator
   return strtrim_end(filename, Dir_Sep);
}

% Return the filenames of the tagged lines as a space separated string
static define list_tagged_files() % (scope, untag)
{
   variable args = __pop_args(_NARGS);
   variable tag_lines = listing_list_tags(__push_args(args));
   tag_lines = array_map(String_Type, &extract_filename, tag_lines);
   return strjoin(tag_lines, " ");
}

% Extract the line number out of a string (with position given as blocal-var)
static define extract_line_no(str)
{
   variable np = get_blocal("line_no_position", -1);
   variable nr_str = extract_element(str, np, get_blocal("delimiter", ' '));
   if (nr_str == NULL)
     return 0;
   ERROR_BLOCK
     {
	_clear_error();
	return 0;
     }
   return integer(nr_str);
}

% Move file/files
static define filelist_rename_file(line, dest)
{
   variable result, file = extract_filename(line);
   file = expand_filename(file);
   if (file_status(dest) == 2) % directory
     dest = path_concat(dest, path_basename(file));
   % vshow("moving %s to %s", file, dest);
   if (andelse{file_status(dest) > 0}
       {listing->get_confirmation(sprintf("'%s' exists, overwrite",
                                          strtail(dest, 30))) != 1})
     return 0;
   
   result = rename_file(file, dest);

   if (result == 0) % success
     return 2;

   % if dest is on a different filesystem, copy and delete
   % show("rename_file failed, try copy and delete", errno_string (errno));
   
   result = copy_file(file, dest); % -1 -> failure
   
   if (result != 0)
     verror ("copy '%s' to '%s' failed: %s",
        strtail(file, 10), strtail(dest, 20), errno_string (errno));
   
   result = delete_file(file); % 0 -> failure
   
   if (result != 0)
     return 2;
     
   if (get_y_or_n(sprintf("Delete %s failed (%s), remove copy? ", 
                           errno_string(errno))) == 1)
     result = delete_file(dest);
  
   % verror ("cannot delete '%s': %s", strtail(file, 10), errno_string (errno));
   return 1;
}

%!%+
%\function{filelist_rename_tagged}
%\synopsis{Rename/Move tagged files}
%\usage{filelist_rename_tagged()}
%\description
%  Move/Rename current or tagged files.
%  Ask in the minibuffer for the destination
%\seealso{filelist_mode, FileList_Action_Scope}
%!%-
public  define filelist_rename_tagged()
{
   () = chdir(buffer_dirname());
   variable dest = read_with_completion("Move/Rename file(s) to:", "", "", 'f');
   listing_map(FileList_Action_Scope, &filelist_rename_file, dest);
   help_message();
}

% Copy file/files
static define filelist_copy_file(line, dest)
{
   variable result, file = extract_filename(line);
   if (file_status(dest) == 2) % directory
     dest = path_concat(dest, path_basename(file));
   if (andelse{file_status(dest) > 0}
       {listing->get_confirmation(sprintf("'%s' exists, overwrite",
                                          strtail(dest, 30))) != 1})
     return 0;
   % show("copying", file, "to", dest);
   result = copy_file(extract_filename(line), dest);
   
   if(result == 0) % success
     return 1;
     
   if (get_y_or_n(sprintf("Copy failed %s, continue? ", 
                           errno_string(errno))) != 1)
     verror("copy failed: %s", errno_string(errno));
   return 0;
}

%!%+
%\function{filelist_copy_tagged}
%\synopsis{Copy tagged files}
%\usage{filelist_copy_tagged()}
%\description
%  Copy current or tagged files.
%  Ask in the minibuffer for the destination
%\seealso{filelist_mode, FileList_Action_Scope}
%!%-
public  define filelist_copy_tagged()
{
   () = chdir(buffer_dirname());
   variable dest = read_with_completion("Copy file(s) to:", "", "", 'f');
   listing_map(FileList_Action_Scope, &filelist_copy_file, dest);
   help_message();
}

%!%+
%\function{filelist_make_directory}
%\synopsis{Create a new directory}
%\usage{  filelist_make_directory()}
%\description
%  Create a new directory.
%  Ask the user for the name.
%\seealso{filelist_mode}
%!%-
public  define filelist_make_directory()
{
   () = chdir(buffer_dirname());
   variable dest = read_with_completion("Create the directory:", "", "", 'f');
   if (mkdir(dest, 0777))
          verror ("mkdir failed: %s", errno_string (errno));
   help_message();
}

% Delete file
static define filelist_delete_file(line)
{
   variable file = extract_filename(line);
   if (listing->get_confirmation("Delete " + file) != 1)
     return 0;
   % copy to Trash Bin
   if (strlen(FileList_Trash_Bin))
       return filelist_rename_file(line, FileList_Trash_Bin);
   % delete directory
   if (file_status(file) == 2)
     if (rmdir(file) == 0) % successfully removed dir
       return 2;
   % delete normal file
   if (delete_file(file) != 0) % success
     return 2;
   if (get_y_or_n(sprintf("Delete failed %s, continue? ", 
                           errno_string(errno))) != 1)
     verror("Delete failed %s", errno_string(errno));
   return 1;
}

%!%+
%\function{filelist_delete_tagged}
%\synopsis{Rename/Move tagged files}
%\usage{filelist_delete_tagged()}
%\description
%  Delete (or move to Trash_Bin) current or tagged files.
%\notes
%  If \var{FileList_Trash_Bin} is "" (default), directories can only be
%  deleted if they are empty.
%\seealso{filelist_mode, filelist_rename_tagged, FileList_Action_Scope}
%!%-
public  define filelist_delete_tagged()
{
   % check Trash Bin for existence
   while (andelse{FileList_Trash_Bin!=""}{file_status(FileList_Trash_Bin)!=2})
        FileList_Trash_Bin = 
          read_with_completion("Trash Bin (leave empty for real delete)", 
             "", FileList_Trash_Bin, 'f');
        
   () = chdir(buffer_dirname());
   listing_map(FileList_Action_Scope, &filelist_delete_file);
   help_message();
}

%!%+
%\function{filelist_reread}
%\synopsis{Re-read the current file listing}
%\usage{filelist_reread()}
%\description
%  Re run the function that generated the current file list to
%  update the view.
%\seealso{filelist_mode}
%!%-
public  define filelist_reread()
{
   variable line = what_line();
   () = run_function(push_array(get_blocal("generating_function")));
   goto_line(line);
}

%!%+
%\function{filelist_list_dir}
%\synopsis{List all files in \var{dir}}
%\usage{filelist_list_dir([dir], ls_cmd="listdir")}
%\description
%  List all files in the current (or given) directory and set the buffer to
%  \sfun{filelist_mode}.
%\notes
%  With the filelist_find_file_hook() as proposed in the INITIALIZATION
%  block of filelist.sl, Jed will open directories as a file listing instead
%  of issuing an error.
%\seealso{filelist_mode, FileList_Cleanup, listdir}
%!%-
public  define filelist_list_dir() % ([dir], ls_cmd="listdir")
{
   % get optional arguments
   variable dir, ls_cmd;
   (dir, ls_cmd) = push_defaults( , "listdir", _NARGS);

   variable calling_dir = buffer_dirname();

   if (dir == NULL)
     dir = read_with_completion("Open directory:", "", "", 'f');
   % make sure there is a trailing directory separator
   dir = path_concat(dir, "");
   % expand relative paths
   dir = expand_filename(path_concat(buffer_dirname(), dir));
   if (file_status(dir) != 2)
     error(dir + " is not a directory");
   % create (or reuse) the buffer
   popup_buffer(dir);
   setbuf_info("", dir, dir, 0);
   erase_buffer();

   % show(ls_cmd);
   if (ls_cmd == "listdir")
     {
	variable files = listdir(dir);
	files = files[array_sort(files)];
%	files = array_map(String_Type, &str_quote_string, files, "* ", '\\');
	insert("..\n");
	insert(strjoin(files, "\n"));
	do
	  if (file_status(dir + line_as_string()) == 2)
	      insert(Dir_Sep);
	while (up_1());
     }
   else
     {
	shell_perform_cmd(ls_cmd,1);
	% write_table([[8,[0:7],[9:length($1)-1]],*])
     }
   bob;
   % set point to the previous directory (when going up or using navigate_back)
   (calling_dir, ) = strreplace (calling_dir, buffer_dirname(), "", 1);
   () = fsearch(calling_dir);

   define_blocal_var("generating_function", [_function_name, dir]);
   fit_window(get_blocal("is_popup", 0));
   filelist_mode();
}

%!%+
%\function{filelist_list_base_dir}
%\synopsis{List the directory of the current file}
%\usage{filelist_list_base_dir()}
%\description
%  List the base directory of the current file. This is usefull e.g. in
%  \sfun{locate} or \sfun{grep} listings, where the files come from different
%  directories.
%\seealso{filelist_mode}
%!%-
public  define filelist_list_base_dir()
{
   variable line = get_line();
   % extract filename
   variable filename = extract_filename(line);
   filelist_list_dir(path_dirname(filename));
}

%!%+
%\function{filelist_open_file}
%\synopsis{Open current file}
%\usage{filelist_open_file(scope=0)}
%\description
% Open the file (or directory) in the current line in a buffer.
% If scope != 0, open tagged files (see \var{FileList_Action_Scope})
%\notes
% If the filename is not the first whitespace delimited token in the line,
% the function generating the list must set the blocal variables
%   "filename_position" (counting from 0) and
%   "delimiter"         (Char_Type, default == NULL, meaning 'whitespace')
%\seealso{filelist_mode, FileList_Cleanup}
%!%-
public  define filelist_open_file() % (scope=0)
{
   variable scope = push_defaults(0, _NARGS);
   variable buf = whatbuf(), bufdir = buffer_dirname();
   variable line, tag_lines = listing_list_tags(scope, 1);
   variable open_dir = 0;

   foreach (tag_lines)
     {
        line = ();

        % extract filename and line number
        variable filename = extract_filename(line);
        variable line_no = extract_line_no(line);
        filename = path_concat(bufdir, filename);

        % open the file or directory
        if (file_status(expand_filename(filename)) == 2) % directory
	  {
	     open_dir = 1;
	     filelist_list_dir(filename);
	  }
        else if (andelse % tar archive
           {is_defined("check_for_tar")} % optional fun from tarhooks.sl
             {runhooks("check_for_tar", filename)}
           )
          runhooks("tar", filename, 0); % open in tar-mode, read-write
        else
          () = find_file(filename);

        if (line_no)              % line_no == 0 means don't goto line
          goto_line(line_no);
     }
   % eventually close the calling buffer
   if (FileList_Cleanup + open_dir >= 2)
     close_buffer(buf);
}

%!%+
%\function{filelist_open_tagged}
%\synopsis{Open all tagged files in jed}
%\usage{filelist_open_tagged()}
%\description
%  This function calls \sfun{filelist_open_file} with
%  the \var{FileList_Action_Scope} argument to open
%  the set of tagged files (or the current)
%  in JED.
%\seealso{filelist_mode}
%!%-
public define filelist_open_tagged()
{
   filelist_open_file(FileList_Action_Scope);
}

%!%+
%\function{filelist_view_file}
%\synopsis{Open the file in view mode}
%\usage{  filelist_view_file()}
%\description
%  Open the file in \sfun{view_mode} (readonly).
%\seealso{filelist_mode, view_mode}
%!%-
public  define filelist_view_file()
{
   filelist_open_file();
   set_readonly(1);
   view_mode();
}

%!%+
%\function{filelist_open_file_with}
%\synopsis{Open the current file with a shell command}
%\usage{filelist_open_file_with(ask = 1)}
%\description
% Open the file with a shell command in a background process.
% The command is taken from \var{FileList_Default_Commands} or asked
% for in the minibuffer.
% If \var{ask} = 0, use default without asking.
%\seealso{filelist_mode, filelist_open_file, system, run_program}
%!%-
public  define filelist_open_file_with() % (ask = 1)
{
   variable ask = push_defaults(1, _NARGS);
   variable line, filename, extension, cmd;

   filename = extract_filename(listing_list_tags(0)[0]);
   extension = path_extname(filename);
   % double extensions:
   if (extension == ".gz") % some programs can handle gzipped files
     extension = path_extname(path_sans_extname(filename)) + extension;

   cmd = FileList_Default_Commands[extension];
   if (ask)
     cmd = read_mini(sprintf("Open %s with (Leave empty to open in jed):",
			     filename), cmd, "");

   if (cmd == "")
     return filelist_open_file();

   () = chdir(buffer_dirname());
   if (getenv("DISPLAY") != NULL) % assume X-Windows running
     () = system(cmd + " " + filename + " &");
   else
     () = run_program(cmd + " " + filename);
}

#ifexists grep
%!%+
%\function{filelist_do_grep}
%\synopsis{Grep for a string in tagged files}
%\usage{  filelist_do_grep()}
%\description
%  Grep for a string in the tagged files.
%  Prompts for the pattern in the minibuffer.
%\notes
%  This function is only available, when the \sfun{grep} function is defined at
%  the time of evaluation or preparsing of filelist.sl
%\seealso{grep, filelist_mode}
%!%-
public  define filelist_do_grep()
{
   grep( , list_tagged_files(FileList_Action_Scope, 1));
}
#endif

% --- The filelist mode -----------------------------------------

#ifdef HAS_DFA_SYNTAX
create_syntax_table(mode);
% set_syntax_flags (mode, 0);
% define_syntax ("-+0-9.", '0', mode);            % Numbers

%%% DFA_CACHE_BEGIN %%%
static define setup_dfa_callback(mode)
{
   dfa_enable_highlight_cache(mode + ".dfa", mode);
   dfa_define_highlight_rule(".*" + Dir_Sep + "$", "keyword", mode);
   dfa_define_highlight_rule(".*\\~$", "comment", mode);
   dfa_build_highlight_table(mode);
}
dfa_set_init_callback(&setup_dfa_callback, mode);
%%% DFA_CACHE_END %%%
enable_dfa_syntax_for_mode(mode);
#endif

static define mc_bindings()
{
   definekey("menu_select_menu(\"Global.M&ode\")", Key_F2,  mode); % Menu
   definekey("filelist_view_file",         Key_F3,  mode); % View
   definekey("filelist_open_file",         Key_F4,  mode); % Edit
   definekey("filelist_copy_tagged",       Key_F5,  mode); % Copy
   definekey("filelist_rename_tagged",     Key_F6,  mode); % Ren/Move
   definekey("filelist_make_directory",    Key_F7,  mode); % Mkdir
   definekey("filelist_delete_tagged",     Key_F8,  mode); % Delete
   definekey("select_menubar",       	   Key_F9,  mode); % PullDn
   definekey("close_buffer",               Key_F10, mode); % Quit
   definekey("filelist_open_file_with(0)", "^M",    mode); % Return
   definekey("isearch_forward", 	   "s",     mode);
   definekey("isearch_forward", 	   "/",     mode);
   % show("call set_help_message", "1Help...", mode);
   set_help_message(
     "1Help 2Menu 3View 4Edit 5Copy 6RenMov 7Mkdir 8Delete 9PullDn 10Quit",
		    mode);
}

static define dired_bindings()
{
   definekey("filelist_copy_tagged",		"C",  mode); % Copy
   definekey("filelist_delete_tagged",		"x",  mode); % Delete
   definekey("filelist_make_directory",		"+",  mode); % Mkdir
   definekey("filelist_open_file",		"e",  mode); % Edit
   definekey("filelist_open_file",		"^M", mode); % Return
   definekey("filelist_open_file_with(0)",	"X",  mode); % shell cmd
   definekey("filelist_rename_tagged",		"R",  mode); % Ren/Move
   definekey("filelist_do_rename_regexp",	"%r", mode); % rename regexp
   definekey("filelist_reread",			"g",  mode); % reread
   definekey("filelist_view_file",		"v",  mode); % View
   definekey("isearch_forward",			"s", mode);
   definekey("listing->tag_matching(1)",	"%d", mode); % tag regexp
   definekey("listing->tag(0); go_up_1",	_Backspace_Key,  mode);
   set_help_message(
     "Enter:Open t/Ins:Tag +/-:Tag-Matching s:search ^R:Reread q:Quit",
		    mode);
}

% Create the keymap
!if (keymap_p(mode)) {
   copy_keymap(mode, listing);
   undefinekey("^R", 			      	    mode);
   definekey ("filelist_reread", 	    "^R",   mode);
   runhooks(FileList_KeyBindings + "_bindings");
}

% --- the mode dependend menu
static define filelist_menu(menu)
{
   listing->listing_menu(menu);
   menu_insert_separator("&Edit Listing", menu);
   menu_insert_item ("&Edit Listing", menu, "&Open",             "filelist_open_file");
   menu_insert_item ("&Edit Listing", menu, "Open &With",        "filelist_open_file_with(1)");
   menu_insert_item ("&Edit Listing", menu, "Open &Tagged Files", "filelist_open_tagged");
   menu_insert_item ("&Edit Listing", menu, "&View (read-only)", "filelist_view_file");
   menu_insert_item ("&Edit Listing", menu, "Open &Directory",    "filelist_list_base_dir");
   menu_insert_separator("&Edit Listing", menu);
   menu_insert_item ("&Edit Listing", menu, "&Copy",      	 "filelist_copy_tagged");
   menu_insert_item ("&Edit Listing", menu, "Rename/&Move", 	 "filelist_rename_tagged");
   menu_insert_item ("&Edit Listing", menu, "&Rename/ regexp", 	 "filelist_do_rename_regexp");
   menu_insert_item ("&Edit Listing", menu, "Make Di&rectory", 	 "filelist_make_directory");
   menu_insert_item ("&Edit Listing", menu, "Delete",      	 "filelist_delete_tagged");
   menu_insert_separator("&Edit Listing", menu);
   menu_insert_item ("&Edit Listing", menu, "&Grep",      	 "filelist_do_grep");
   menu_insert_item ("&Edit Listing", menu, "Tar",      	 "filelist_do_tar");
   menu_insert_separator("&Edit Listing", menu);
   menu_append_item (		      menu, "&Quit",        	 "close_buffer");
}

public  define filelist_mouse_2click_hook (line, col, but, shift)
{
   filelist_open_file();
   return 1;  % stay in window
}

%!%+
%\function{filelist_mode}
%\synopsis{Interactive mode for file listings}
%\usage{filelist_mode()}
%\description
%  This mode transforms JED into a file manager (somewhat similar to
%  the  Midnight commander, MC). It can be used as a \sfun{dired} replacement
%  and gives (IMHO) a superiour look and feel. It works for directory listings
%  as well as the result of \sfun{locate}, \sfun{grep} or \sfun{find} actions.
%  Files can be listed, tagged, copied, moved, deleted, viewed, and opened
%  with ease.
%\seealso{filelist_list_dir, filelist_open_tagged}
%\seealso{FileList_KeyBindings, FileList_Action_Scope, FileList_max_window_size}
%!%-
public define filelist_mode()
{
   listing_mode();
   set_mode(mode, 0);
   use_syntax_table(mode);
   use_keymap(mode);
   mode_set_mode_info(mode, "init_mode_menu", &filelist_menu);
   set_buffer_hook("mouse_2click", &filelist_mouse_2click_hook);
   run_mode_hooks("filelist_mode_hook");
   help_message();
}

% ---------------------------------------------------------------------------

%!%+
%\function{locate}
%\synopsis{Search for a file with the `locate` command}
%\usage{ locate(what=<Ask>)}
%\description
%  The `locate` command performs a fast file lookup using a database.
%  This function is a backend to `locate` that presents the result
%  in a filelist buffer for easy browsing.
%\seealso{filelist_mode, grep}
%!%-
public define locate() % (what=<Ask>)
{
   variable what = "";
   if (_NARGS)
     what = ();

   % read pattern from minibuffer if not given as optional argument
   if (what == "")
     {
	what = read_mini("Locate: ", "", LAST_LOCATE);
	!if ( strlen(what) )
	  return;
	LAST_LOCATE = what;
     }

   popup_buffer("*locate*");
   set_readonly(0);
   erase_buffer();

   set_prefix_argument(1);     % insert result in current buffer
   do_shell_cmd("locate " + what);
   if (bobp and eobp)
     {
	set_buffer_modified_flag(0);
	delbuf(whatbuf);
	return message("Locate: No results");
     }
   fit_window(get_blocal("is_popup", 0));
   filelist_mode();
   set_status_line("locate:" + what + " (%p)", 0);
   define_blocal_var("generating_function", [_function_name, what]);
   bob();
}

% A special mode for file listings (ls, ls -a, locate)
% -> replace/extend dired mode
%
% Günter Milde <milde at web.de>
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
%
% TODO: * more bindings of actions: filelist_cua_bindings
% 	* detailed directory listing (ls -l)
% 	* quoting of special file names
% 	* give error reason with errno/errno_string (if not automatically done)
%
% USAGE:
% * Place filelist.sl, listing.sl and bufutils.sl in your library path.

% * Use filelist_list_dir() to open a directory in the "jed-file-manager"

% * To make file finding functions list the directory contents 
%   if called with a directory path as argument (instead of reporting an 
%   error), insert the INITALIZATION block into your .jedrc (or jed.rc)
%   (or use the "make_ini" and "home-lib" modes from jedmodes.sf.net)

#iffalse %<INITIALIZATION>
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
append_to_hook("_jed_find_file_before_hooks",
	       &filelist_find_file_hook);

#endif %</INITIALIZATION>

_debug_info = 1;


% --- Requirements ------------------------------------------------------

require("listing");  % the listing widget, depends on datutils
_autoload("get_blocal", "sl_utils",
	  "run_function", "sl_utils",
	  "push_defaults", "sl_utils",
	  "push_array", "sl_utils",
	  "_implements", "sl_utils",
	  "buffer_dirname", "bufutils",
	  "close_buffer", "bufutils",
	  "popup_buffer", "bufutils",
	  "string_get_match", "strutils",
	  "grep", "grep",
	  10);
% optional extensions
if(strlen(expand_jedlib_file("filelistmsc")))
  _autoload("filelist_do_rename_regexp", "filelistmsc",
	    "filelist_do_tar", "filelistmsc", 2);

% --- Declare modename and namespace -------------------------------------
%
private variable mode = "filelist";
_implements(mode);

% --- Custom Variables ----------------------------------------------------

% What files should actions like move, delete, open_with be applied to
%     0 current line                                        (MC-macro "%f")
%     1 tagged lines or current line, if no line is tagged. (MC-macro "%s")
%     2 tagged lines 		      	    	    	    (MC-macro "%t")
custom_variable("FileList_Action_Scope", 1);

% Set up MC like bindings for the filelist mode?
custom_variable("FileList_KeyBindings", "mc");

% Close the directory listing when opening a file/dir from it?
% 2 always close, 1 close when going to a directory, 0 keep open
custom_variable("FileList_Cleanup", 1);

% How big shall the filelist window be maximal (Integer: rows,
% Float: screen-fraction, 0 do not fit to content size)
custom_variable("FileList_max_window_size", 1.0);  % my default is full screen

% A directory, where deleted files are moved to.
% The default "" means real deleting. KDE users might want to set this to
% "~/Desktop/Trash"
custom_variable("FileList_Trash_Bin", "");
if (FileList_Trash_Bin != "")
   FileList_Trash_Bin = expand_filename(FileList_Trash_Bin);
% note: the Trash_Bin will be checked for existence in filelist_delete_tagged,
%       so we do not abort due to a missing or wrong definition.

% TODO
% * custom_variable("dir_ls_cmd", "ls -la --quoting-style=shell")
% * copy from filelist to filelist ...
%   ^C copy : cua_copy_region und copy_tagged (in separaten buffer)
%   ^X kill:  yp_kill_region und kill_tagged    ""   ""        ""
%   ^V filelist_insert (im filelist modus)
%   bzw die bindungen abfragen.

% --- Static Variables ----------------------------------------------------
% Add to/Change in the filelist_mode_hook

% Default values for command opening a file with a certain extension
% The command is called via system(command + file + "&")
% TODO: use MIME_types and mailcap (view and edit commands)
static variable FileList_Default_Commands = Assoc_Type[String_Type, ""];

% under xjed and jed in xterm use X programs
if (getenv("DISPLAY") != NULL) % assume X-Windows running
{
   FileList_Default_Commands[".eps"]     = "gv";
   FileList_Default_Commands[".ps"]      = "gv";
   FileList_Default_Commands[".ps.gz"]   = "gv";
   FileList_Default_Commands[".pdf"]     = "gv";
   FileList_Default_Commands[".pdf.gz"]  = "gv";
   FileList_Default_Commands[".dvi"]     = "xdvi";
   FileList_Default_Commands[".dvi.gz"]  = "xdvi";
   FileList_Default_Commands[".lyx"]     = "lyx-remote";
   FileList_Default_Commands[".html"]    = "dillo";   % fast and light browser
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

% dummy definition (circular dependencies)
 public define filelist_mode();

% Extract the filename out of a string (with position given as blocal-var)
% Str = extract_filename(Str line)
static define extract_filename(line)
{
   % some listings refer to only one file, omitting it in the list
   variable filename = get_blocal("filename", "");

   !if (strlen(filename))
     {
	variable fp = get_blocal("filename_position", 0);
	variable del = get_blocal("delimiter", ' ');
	% filename = strchop(line, del, '\\')[fp];
	% filename = strtok(line, del, '\\')[fp];
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
   variable file = extract_filename(line);
   % show("moving", file, "to", dest);
   if (file_status(dest) == 2) % directory
     dest = path_concat(dest, path_basename(file));
   if (file_status(dest) > 0)
     if (listing->get_confirmation(dest + " exists, overwrite") != 1)
       return 0;
   if (rename_file(file, dest)) % return value != 0
     {
	% alternative: if dest is on a different filesystem, copy and delete
	% 	if (copy_file(file, dest)) % return value != 0
	% 	  verror ("rename %s to %s failed: %s",
	% 		  file, dest, errno_string (errno));
	% 	else % copy successfull
	% 	  delete_file(file);

	% keep this one on list but continue with other tagged
	vmessage ("rename failed: %s", errno_string (errno));
	return 0;
     }
   return 2;
}

 public define filelist_rename_tagged()
{
   () = chdir(buffer_dirname());
   variable dest = read_with_completion("Move/Rename file(s) to:", "", "", 'f');
   listing_map(FileList_Action_Scope, &filelist_rename_file, dest);
   help_message();
}

% Copy file/files
static define filelist_copy_file(line, dest)
{
   variable file = extract_filename(line);
   if (file_status(dest) == 2) % directory
     dest = path_concat(dest, path_basename(file));
   if (file_status(dest) > 0)
     if (listing->get_confirmation(dest + " exists, overwrite") != 1)
       return 0;
   % show("copying", file, "to", dest);
   if(copy_file(extract_filename(line), dest))
     {
	vmessage("copy failed: %s", errno_string(errno));
	return 0;
     }
   return 1;
}

 public define filelist_copy_tagged()
{
   () = chdir(buffer_dirname());
   variable dest = read_with_completion("Copy file(s) to:", "", "", 'f');
   listing_map(FileList_Action_Scope, &filelist_copy_file, dest);
   help_message();
}

% Create a directory
 public define filelist_make_directory()
{
   () = chdir(buffer_dirname());
   variable dest = read_with_completion("Create the directory:", "", "", 'f');
   if (mkdir(dest, 0777))
          verror ("mkdir failed: %s", errno_string (errno));
   help_message();
}

% Delete file/files
static define filelist_delete_file(line)
{
   variable file = extract_filename(line);
   if (listing->get_confirmation("Delete " + file) != 1)
     return 0;
   if (strlen(FileList_Trash_Bin))
       return filelist_rename_file(line, FileList_Trash_Bin);
   if (file_status(file) == 2)
     () = rmdir(file);
   else
     () = delete_file(file);
   return 2;
}

 public define filelist_delete_tagged()
{
   % check Trash Bin for existence
   while (strlen(FileList_Trash_Bin) and
	  file_status(FileList_Trash_Bin) != 2)
     % not a directory, ask for another
     FileList_Trash_Bin = expand_filename(read_with_completion
     ("Trash Bin (leave empty for real delete)", "", FileList_Trash_Bin, 'f'));
   % TODO: delete directories
   () = chdir(buffer_dirname());
   listing_map(FileList_Action_Scope, &filelist_delete_file);
   help_message();
}

 public define filelist_reread()
{
   variable line = what_line();
   () = run_function(push_array(get_blocal("generating_function")));
   goto_line(line);
}

% listing of files in dir
 public define filelist_list_dir() % ([dir], ls_cmd="listdir")
{
   % get optional arguments
   variable dir, ls_cmd;
   (dir, ls_cmd) = push_defaults( , "listdir", _NARGS);
   if (dir == NULL)
     dir = read_with_completion("Open directory:", "", "", 'f');

   % append trailing directory separator
   dir = path_concat(dir, "");
   % expand relative paths
   dir = expand_filename(path_concat(buffer_dirname(), dir));
   if (file_status(dir) != 2)
     error(dir + " is not a directory");

   variable calling_dir = buffer_dirname();
   % eventually close the calling (see custom var FileList_Cleanup)
   if (get_blocal("FileList_Cleanup", 0))
     close_buffer();
   % create (or reuse) the buffer
   popup_buffer(dir);
   () = chdir(dir);
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
	  if (file_status(line_as_string()) == 2)
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

   define_blocal_var("FileList_Cleanup", FileList_Cleanup);
   define_blocal_var("generating_function", [_function_name, dir]);
   fit_window(get_blocal("is_popup", 0));
   filelist_mode();
}

% list directory where file is in
 public define filelist_list_base_dir()
{
   % get the line but keep the point (see also get_line in txtutils.sl)
   push_spot();
   variable line = line_as_string();
   pop_spot();
   % extract filename
   variable filename = extract_filename(line);
   filelist_list_dir(path_dirname(filename));
}

% Open the file in the current line in a buffer.
 public define filelist_open_file()
{
   % get the line but keep the point (see also get_line in txtutils.sl)
   push_spot();
   variable line = line_as_string();
   pop_spot();
   % extract filename and line number
   variable filename = extract_filename(line);
   variable line_no = extract_line_no(line);
   () = chdir(buffer_dirname());
   % eventually close the calling buffer
   if (get_blocal("FileList_Cleanup", 0) > 1)
     close_buffer();
   % open the file
   if (file_status(filename) == 2) % directory
     filelist_list_dir(filename);
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

% Open the file in view mode (readonly)
 public define filelist_view_file()
{
   filelist_open_file();
   set_readonly(1);
   view_mode();
}

% Open the file with the command in a background process
% If ask = 0, use default without asking
 public define filelist_open_file_with() % (ask = 1)
{
   variable ask = push_defaults(1, _NARGS);
   variable line, filename, extension, cmd;

   filename = extract_filename(listing_list_tags(0)[0]);
   extension = path_extname(filename);
   if (extension == ".gz") % some programs can handle gzipped files
     extension = path_extname(path_sans_extname(filename)) + extension;
   
   % check for directory
   if (file_status(filename) == 2) 
     return filelist_list_dir(filename);
   
   cmd = FileList_Default_Commands[extension];
   if (ask)
     cmd = read_mini(sprintf("Open %s with (Leave empty to open with jed):",
			     filename), cmd, "");

   !if (strlen(cmd))
     return filelist_open_file();

   () = chdir(buffer_dirname());
   if (getenv("DISPLAY") != NULL) % assume X-Windows running
     () = system(cmd + " " + filename + " &");
   else
     () = run_program(cmd + " " + filename);
}

% grep for a string in the tagged files (requires grep.sl)
 public define filelist_do_grep()
{
   grep( , list_tagged_files(FileList_Action_Scope, 1));
}

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
   undefinekey("^S", mode);
   definekey("isearch_forward", 	   "^S",    mode);
   % show("call set_help_message", "1Help...", mode);
   set_help_message(
     "1Help 2Menu 3View 4Edit 5Copy 6RenMov 7Mkdir 8Delete 9PullDn 10Quit",
		    mode);
}

static define dired_bindings()
{
   undefinekey("^S", mode);
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
   definekey("isearch_forward",			"^S", mode);
   definekey("listing->tag_matching(1)",	"%d", mode); % tag regexp
   definekey("listing->tag(0); go_up_1",	_Backspace_Key,  mode);
   set_help_message(
     "Enter:Open t/Ins:Tag +/-:Tag-Matching ^R:Reread q:Quit",
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
   menu_insert_item ("&Edit Listing", menu, "&View (read-only)", "filelist_view_file");
   menu_insert_item ("&Edit Listing", menu, "Open Directory",    "filelist_list_base_dir");
   menu_insert_separator("&Edit Listing", menu);
   menu_insert_item ("&Edit Listing", menu, "&Copy",      	 "filelist_copy_tagged");
   menu_insert_item ("&Edit Listing", menu, "Rename/&Move", 	 "filelist_rename_tagged");
   menu_insert_item ("&Edit Listing", menu, "&Rename/ regexp", 	 "filelist_do_rename_regexp");
   menu_insert_item ("&Edit Listing", menu, "Make &Directory", 	 "filelist_make_directory");
   menu_insert_item ("&Edit Listing", menu, "Delete",      	 "filelist_delete_tagged");
   menu_insert_separator("&Edit Listing", menu);
   menu_insert_item ("&Edit Listing", menu, "&Grep",      	 "filelist_do_grep");
   menu_insert_item ("&Edit Listing", menu, "Tar",      	 "filelist_do_tar");
   menu_insert_separator("&Edit Listing", menu);
   menu_append_item (		      menu, "&Quit",        	 "close_buffer");
}

 public define filelist_mouse_2click_hook (line, col, but, shift)
{
   filelist_open_file();
   return 1;  % stay in window
}

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

% listing of the result of a locate search
public define locate() % (what=<Ask>)
{
   variable what = "";
   if (_NARGS)
     what = ();

   % read command from minibuffer if not given as optional argument
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
}

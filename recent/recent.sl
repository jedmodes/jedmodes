% Provide easy access to recently opened/saved files.
%
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Version:
% 1.0.1. by Guido Gonzato, <ggonza@tin.it>
%
% 2.0    by Guenter Milde <g.milde@web.de>
%        *  Use a circular array -> no hidden recent buffer
%        *  Save to file only at exit -> less writing
%        *  Save last cursor position when saving a file
%        *  Support for "restore last session" (bug fixed)
%        *  Saving cursor position for open buffers at exit (report G. Gonzato)
% 2.1    15. Okt 2002   patch by   Paul Boekholt
%        *  correct linecounting in folds
%        *  goto_column -> goto_column_best_try
%        *  custom variable RECENT_FILES_EXCLUDE (by GM, based on PB)
%        *  if the line we jump to is in a fold, open it
% 2.2    12. 11. 2002
% 	 *  documentation error cleared (Joachim Schmitz)
% 	 *  local recent-files enabled (patch by Andree Borrmann)
% 	 *  restore_session moved to jed_startup_hooks so the custom settings
% 	    are valid when the last open files will be opened
% 	    (bug report Andree Borrmann)
% 	 *  auxiliary fun save_integer removed, as integer() is
% 	    already error save when feeded a string
% 2.2.1  *  if a file is already open, dont goto line (Paul Boekholt)
%        *  made exclude default more save "^/tmp/" (Adam Byrtek)
% 2.2.2  *  add path info to the popup menu (idea by Marko Mahnic)
% 	    (recent now depends on circle.sl and sl_utils.sl (> 1.1)
% 2.2.3  04-2003
% 	 *  renamed some custom variables according to J E Davies suggestions
% 	 *  parse the recent_files_file without loading to a buffer
% 	    (with arrayread_file() and a bugfix by Paul Boekholt)
% 	 *  new function recent_get_files()
% 3.0    15-01-2004
%        *  removed dependency on circle.sl -> store the file entries
%           in a "\n" delimited stringlist (like P. Boekholts sfrecent)
%        *  all custom variables start with "Recent_" 
%           (except Restore_Last_Session)
%           (renamed Local_Recent_List to Recent_Use_Local_Cache)
%        *  new menu option "Clear Cache"
%        *  empty cache files will be deleted (if permitted)
%
% USAGE:
%
% To activate the recent files feature, load recent.sl from your 
% init file (.jedrc or jed.rc) e.g. by including the following lines
%
% % Optionally set custom variables (here the defaults are given) :
% variable Recent_Files_Cache_File = ".jedrecent";
% variable Recent_Max_Cached_Files  = 15;
% variable Recent_Files_Exclude_Pattern = "/tmp"; % don't add tmp files
% variable Recent_Use_Local_Cache = -1; % use local if existent
% variable Restore_Last_Session = 0;    % reopen files from last session
%
% % Load recent.sl (assuming it is in the JED_LIBRARY path)
% require("recent");
%
% TODO: proper (tm) documentation of public functions and variables
%       think about synchronizing for different jed runs

_debug_info=1;

implements("recent");

autoload("what_line_if_wide", "sl_utils");
autoload("contract_filename", "sl_utils");
autoload("fold_open_fold", "folding");  % standard library function
autoload("buffer_dirname", "bufutils");
autoload("strread_file", "bufutils");

% --- custom variables: user-settable ----------------------------------

% The file to save the recent files list to.
% (Will be appended to Jed_Home_Directory if no absolute path is given.)
#ifdef IBMPC_SYSTEM
custom_variable("Recent_Files_Cache_File", "_jedrcnt");
#else
custom_variable("Recent_Files_Cache_File", ".jedrecent");
#endif

% Do you want a local recent list? (stored in directory where jed was started)
%  -1 local if cache file is already present,  
%   0 no, 
%   1 always local. 
% Toggle (0/1) with recent_toggle_local() or the menu entry
custom_variable("Recent_Use_Local_Cache", -1);

% Number of Recent_Files to remember
custom_variable("Recent_Max_Cached_Files", 15);

% Which files shall not be added to the recent files list?
% Give a regexp pattern that is matched to the full filename.
custom_variable("Recent_Files_Exclude_Pattern", "/tmp");

% Do you want to reopen the buffers that where open the last session?
%    0 no, 
%    1 yes, 
%    2 only files in working directory, 
%    3 only if local recent list
custom_variable("Restore_Last_Session", 0);

% Max space reserved for alignment of paths in the recent files menu
custom_variable("Recent_Files_Column_Width", 20);

% Deprecated: if recent-files-list is not wanted, don't evaluate this skript!
% custom_variable ("WANT_RECENT_FILES_LIST", 1);
if (__get_reference("WANT_RECENT_FILES_LIST") != NULL)
  if (@__get_reference("WANT_RECENT_FILES_LIST") == 0)
    error("Use Recent_Files_Exclude_Pattern to stop adding of files to the recent files list");

% --- Variables ----------------------------------------------------

% Filename of the cache files [global, local]
static variable recent_cache_name;

% Cache of recent files
%  (a "\n" delimited stringlist of recent file entries (latest last))
%    * initialized from recent_cache_name[Recent_Use_Local_Cache]
%      on startup and by recent_toggle_local()
%    * updated when loading or saving to a file
%    * saved to Recent_Files_Cache_File on exit
static variable recent_files_cache;


% --- Functions ----------------------------------------------------

% Return the filename part of an "filename:line:col:open" entry
static define get_entry_filename(entry)
{
   entry = strchop(entry, ':', 0);
   if (length(entry) < 4) % Backwards compatibility / error save ...
     return strjoin(entry,":");
   else
     return strjoin(entry[[0:-4]],":");
}

% Return the recent files as an array (last saved file first)
% (e.g. for use in the minibuffer with rimini.sl)
public define recent_get_files()
{
   return array_map(String_Type, &get_entry_filename,
      strchopr(strtrim(recent_files_cache), '\n', 0));
}

% Parse an entry of the recent files cache and return [filename, flags]
static define parse_cache_entry(entry)
{
   entry = strchop(entry, ':', 0);
   if (length(entry) < 4) % Backwards compatibility / error save ...
     return [strjoin(entry,":"),""];
   else
     return [strjoin(entry[[0:-4]],":"), strjoin(entry[[-3:]],":")];
}

% load a file from the recent_files_cache list and goto right position
% filemark = [String filename, String flags]
public define recent_load_file(filemark)
{
   % show("loading entry", entry);
   () = find_file(filemark[0]);
   if (what_line() != 1)     % file was already open
     return;
   % goto saved position
   variable flags = strchop(filemark[1], ':', 0);
   goto_line(integer(flags[0]));
   () = goto_column_best_try(integer(flags[1]));
   % open folds
   loop(count_narrows) % while (is_line_hidden) might cause an infinite loop!
     if(is_line_hidden)
       fold_open_fold();
}

% reopen the files that were open in the last exited session of jed
static define restore_session()
{
   variable filemark;
   foreach(strchop(strtrim(recent_files_cache), '\n', 0))
     {
	filemark = parse_cache_entry(());
	if (andelse
	    { filemark[1][-1] == '1' }
	    { orelse { Restore_Last_Session != 2 }
		   { strtrim_end(getcwd(),"\\/") != path_dirname(filemark[0]) }
	    }
	    { file_status(filemark[0]) }
	   )
	  recent_load_file(filemark);
     }
}

% Return a cache entry for the current buffer (see getbuf_info)
% (empty string if file matches Exclude Pattern or no file 
% associated to buffer)
static define getbuf_filemark()
{
   variable entry = buffer_filename(); 
   if (string_match(entry, Recent_Files_Exclude_Pattern, 1))
     entry = "";
   return [entry, sprintf("%d:%d:1", what_line_if_wide(), what_column())];
}

% This function will be called when loading or saving to a file
static define add_to_cache()
{
   _pop_n (_NARGS); % remove spurious arguments from stack
   variable filemark = getbuf_filemark();
   if (filemark[0] != "")
       recent_files_cache += "\n" + strjoin(filemark,":");
   % TODO: eventually purge and save (depending on sync-level)
}

% purge doublettes in the cache and reduce to Recent_Max_Cached_Files
% update the cache's line/col info
static define update_cache()
{
   variable filemark, 
     openfiles = Assoc_Type[String_Type],
     i=0, 
     new_cache = "\n"; % initialize for is_substr search
   
   % find out which buffers are open and update line/col info
   loop(buffer_list)
     {
	sw2buf(());
	filemark = getbuf_filemark();
	openfiles[filemark[0]] = filemark[1]; 
	% no need to check for filename=="", as only buffers
	% listed in the cache will be updated
     }
   % update and purge the cache
   foreach(strchopr(strtrim(recent_files_cache), '\n', 0)) % newest entry first
     {
	if (i >= Recent_Max_Cached_Files) 
	  break;
	filemark = parse_cache_entry(());
	% show(filemark);
	% skip empty filenames
	if (filemark[0] == "")
	  continue;
	% skip doublettes
	% (fails for "/path/foo", if "/path/foo:bar" is on the list,
	%  but this might be tolerable (given the needed effort to correct))
	if (is_substr(new_cache, "\n"+filemark[0]+":"))
	  continue;
	% update file flags
	if (assoc_key_exists(openfiles, filemark[0]))
	  filemark[1] = openfiles[filemark[0]][[:-2]] + "1";
	else
	  filemark[1] = filemark[1][[:-2]] + "0";
	new_cache = strcat("\n", strjoin(filemark,":"), new_cache);
	i++;
     }
   recent_files_cache = strtrim(new_cache);
}

% load the recent files list from file
static define load_cache()
{
   ERROR_BLOCK
     {
	_clear_error;
	return "";
     }
   return strread_file(recent_cache_name[Recent_Use_Local_Cache]);
}

% clear the cache
static define clear_cache()
{
   recent_files_cache = "";
}

% Save the recent files list to a file, delete the file if the cache is empty
static define save_cache()
{
   % recent_files_cache = strcat(load_cache(), recent_files_cache);
   update_cache();
   ERROR_BLOCK 
     {
	_clear_error;
     }
   if (recent_files_cache != "")
     () = write_string_to_file(recent_files_cache, 
	recent_cache_name[Recent_Use_Local_Cache]);
   else
     () = delete_file(recent_cache_name[Recent_Use_Local_Cache]);
   return 1;   % tell _jed_exit_hooks to continue
}

% Toggle the use of a local recent files file
public define recent_toggle_local()
{
   save_cache();                                  % save the current state
   Recent_Use_Local_Cache = not(Recent_Use_Local_Cache);          % toggle
   recent_files_cache = load_cache();           % load the new recent-file
   menu_select_menu("Global.&File.&Recent Files");
}

public define recent_files_menu_callback (popup)
{
   variable menu, n, i = '1', filemark, file, path,
     global_local = ["global", "local"],
     fmt_str = "&%c %-" + string(Recent_Files_Column_Width) + "s %s";
   
   update_cache();
   if (recent_files_cache != "")
     {
	foreach(strchopr(recent_files_cache, '\n', 0))
	  {
	     filemark = parse_cache_entry(());
	     file = path_basename(filemark[0]);
	     path = contract_filename(path_dirname(filemark[0]), "");
	     menu_append_item (popup, sprintf (fmt_str, i, file, path),
		&recent_load_file, filemark);
	     % menu index: 1-9, then a-z, then A-Z, then restart
	     switch (i)
	       { case '9': i = 'a'; }
	       { case 'z': i = 'A'; }
	       { case 'Z': i = '1'; }
	       {           i++;     }
	  }
	menu_append_separator(popup);
	menu_append_item (popup, "Clear Cache", "recent->clear_cache");
     }
   menu_append_item (popup, "&Use " + global_local[not(Recent_Use_Local_Cache)]
      + " filelist" , "recent_toggle_local");
}

static define add_recent_files_popup_hook (menubar)
{
   variable menu = "Global.&File";

   menu_append_separator (menu);
   menu_append_popup (menu, "&Recent Files");
   menu_set_select_popup_callback (strcat (menu, ".&Recent Files"),
				   &recent_files_menu_callback);
}

% ------ code that gets executed at evaluation of recent.sl -----

% --- Variable initialization

% expand the cache file path
!if (path_is_absolute(Recent_Files_Cache_File))
  Recent_Files_Cache_File = dircat(Jed_Home_Directory, Recent_Files_Cache_File);
#ifdef IBMPC_SYSTEM
!if (path_is_absolute (Recent_Files_Cache_File))
   if (getenv("TEMP") != NULL)
    Recent_Files_Cache_File = dircat(getenv("TEMP"), Recent_Files_Cache_File);
#endif

recent_cache_name = [Recent_Files_Cache_File,
   		  dircat(getcwd(), extract_filename(Recent_Files_Cache_File))];

% set local_session from 1 to 0, if no local recent file found
if (andelse{Recent_Use_Local_Cache != 1 } 
     {file_status(recent_cache_name[1]) != 1} )
  Recent_Use_Local_Cache = 0;

% load the recent-files-file into cache
recent_files_cache = load_cache();

% --- Hooks

% update the cache_file when loading and saving a buffer
% 1. opening a file (no arguments, no return value)
append_to_hook("_jed_find_file_after_hooks", &recent->add_to_cache);
% 2. saving to a file (one argument, no return value)
append_to_hook("_jed_save_buffer_after_hooks", &recent->add_to_cache);

% Save the list of recent files at exit
append_to_hook("_jed_exit_hooks", &recent->save_cache);

% Create the recent-files menu topic
append_to_hook ("load_popup_hooks", &add_recent_files_popup_hook);

% Restore the last session
% !! A strange bug lets the last line count (instead of AND) when
%    the arguments of andelse are on several lines and _debug_info is 1 !!
if ( andelse {__argc == 1} {not BATCH} {Restore_Last_Session} {Restore_Last_Session != 3 or Recent_Use_Local_Cache})
  add_to_hook("_jed_startup_hooks", &restore_session);

provide("recent");

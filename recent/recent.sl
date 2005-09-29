% Provide easy access to recently opened/saved files.
%
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Version:
% 1.0.1. by Guido Gonzato, <ggonza@tin.it>
%
% 2.0    by Guenter Milde <g.milde web.de>
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
%        *  removed dependency on circle.sl -> store the file records
%           in a "\n" delimited stringlist (like P. Boekholts sfrecent)
%        *  all custom variables start with "Recent_" 
%           (except Restore_Last_Session)
%           (renamed Local_Recent_List to Recent_Use_Local_Cache)
%        *  new menu option "Clear Cache"
%        *  empty cache files will be deleted (if permitted)
% 3.1    2005-03-34
%        *  made slang-2 proof: A[[0:-2]] --> A[[:-2]] (P. Boekholt)
% 3.2    2005-04-02
%        * code cleanup and reorganisation
%        * recent_load_file is now static (was public)
%        * synchronize recent files file between different running sessions
%
% USAGE:
%
% To activate the recent files feature, load recent.sl from your 
% init file (.jedrc or jed.rc) with require("recent") 
% or by including the following more elaborated example
%
% % Optionally set custom variables (here the defaults are given) :
% % variable Recent_Files_Cache_File = ".jedrecent";
% % variable Recent_Max_Cached_Files  = 15;
% % variable Recent_Files_Exclude_Pattern = "/tmp"; % don't add tmp files
% % variable Recent_Use_Local_Cache = -1; % use local if existent
% % variable Restore_Last_Session = 0;    % reopen files from last session
%
% % Load recent.sl (assuming it is in the jed library path)
% require("recent");

% _debug_info=1;

% Requirements
"what_line_if_wide", "sl_utils";
"contract_filename", "sl_utils";
"_implements",       "sl_utils"; % >= 1.5
"strread_file",      "bufutils";
_autoload(4);

% --- name it
provide("recent");
_implements("recent");
private variable mode = "recent";

% --- custom variables: user-settable ----------------------------------

% (Will be appended to Jed_Home_Directory if no absolute path is given.)
%!%+
%\variable{Recent_Files_Cache_File}
%\synopsis{Name of the recent files file}
%\usage{String_Type Recent_Files_Cache_File = ".jedrecent"}
%\description
%  The file to save the recent files list to.
%\seealso{Recent_Use_Local_Cache, Recent_Files_Synchronize_Cache}
%\seealso{Recent_Files_Exclude_Pattern, Recent_Files_Column_Width}
%!%-
#ifdef IBMPC_SYSTEM
custom_variable("Recent_Files_Cache_File", "_jedrcnt");
#else
custom_variable("Recent_Files_Cache_File", ".jedrecent");
#endif

%!%+
%\variable{Recent_Use_Local_Cache}
%\synopsis{Do you want a local recent list? }
%\usage{Int_Type Recent_Use_Local_Cache = -1}
%\description
% Should recent.sl use a local recent Recent_Files_Cache_File? 
% (i.e. stored in directory where jed was started)
% 
%   -1 -- local if local cache file is present at jed startup,
%    0 -- no,
%    1 -- always local.
%    
% Toggle (0/1) with recent_toggle_local() or the menu entry
%\seealso{Recent_Files_Cache_File, Recent_Files_Exclude_Pattern, Restore_Last_Session}
%!%-
custom_variable("Recent_Use_Local_Cache", -1);


%!%+
%\variable{Recent_Max_Cached_Files}
%\synopsis{Number of recent files to remember}
%\usage{Int_Type Recent_Max_Cached_Files = 15}
%\description
%  How many recent opened files should be stored in the 
%  Recent_Files_Cache_File?
%\seealso{Recent_Files_Cache_File, Recent_Files_Exclude_Pattern}
%!%-
custom_variable("Recent_Max_Cached_Files", 15);

%!%+
%\variable{Recent_Files_Exclude_Pattern}
%\synopsis{Which files shall not be added to the recent files list?}
%\usage{String_Type Recent_Files_Exclude_Pattern = "/tmp"}
%\description
%  Wildcard for files that shall not be added to the recent files list
%  (e.g. temporary files)
%  
%  The value is a regexp pattern that is matched to the full path.
%\seealso{Recent_Files_Cache_File, Recent_Use_Local_Cache}
%!%-
custom_variable("Recent_Files_Exclude_Pattern", "/tmp");

%!%+
%\variable{Restore_Last_Session}
%\synopsis{Reopen the buffers that were open in the last session?}
%\usage{Int_Type Restore_Last_Session = 0}
%\description
%  Should recent.sl reopen the buffers that were open in the last session?
%  
%    0 -- no, 
%    1 -- yes, 
%    2 -- only files in working directory, 
%    3 -- only if local recent list
%    
%  If \var{Recent_Use_Local_Cache} is True, \var{recent->restore_session} 
%  restores the last session from the local \var{Recent_Files_Cache_File}.
%  
%  \var{recent->restore_session} will not open files still open in another
%  running session if \var{Recent_Files_Synchronize_Cache} is true. 
%  
%  
%\seealso{Recent_Files_Exclude_Pattern, Recent_Max_Cached_Files}
%!%-
custom_variable("Restore_Last_Session", 0);


%!%+
%\variable{Recent_Files_Column_Width}
%\synopsis{Max space reserved for alignment of paths in the recent files menu}
%\usage{Int_Type Recent_Files_Column_Width = 20}
%\seealso{Recent_Files_Cache_File}
%!%-
custom_variable("Recent_Files_Column_Width", 20);

%!%+
%\variable{Recent_Files_Synchronize_Cache}
%\synopsis{Recent files synchronization level}
%\usage{Int_Type Recent_Files_Synchronize_Cache = 0}
%\description
% How often should the Recent_Files_Cache_File be read/saved to synchronize
% different instances of jed?
%   0 -- read at startup, save at exit
%   1 -- read with every call, save with every change
%\seealso{Recent_Files_Cache_File, Recent_Use_Local_Cache, Restore_Last_Session}
%!%-
custom_variable("Recent_Files_Synchronize_Cache", 1);

% Deprecated: if recent-files-list is not wanted, don't evaluate this skript!
% custom_variable ("WANT_RECENT_FILES_LIST", 1);
if (__get_reference("WANT_RECENT_FILES_LIST") != NULL)
  if (@__get_reference("WANT_RECENT_FILES_LIST") == 0)
    error("Use Recent_Files_Exclude_Pattern to stop adding of files to the recent files list");


% --- Variables ----------------------------------------------------

% expand the cache file path
!if (path_is_absolute(Recent_Files_Cache_File))
  Recent_Files_Cache_File = dircat(Jed_Home_Directory, Recent_Files_Cache_File);
#ifdef IBMPC_SYSTEM
!if (path_is_absolute (Recent_Files_Cache_File))
   if (getenv("TEMP") != NULL)
    Recent_Files_Cache_File = dircat(getenv("TEMP"), Recent_Files_Cache_File);
#endif

% Filename of the cache files [global, local]
static variable recent_cachefile_name =
  [Recent_Files_Cache_File,
   dircat(getcwd(), extract_filename(Recent_Files_Cache_File))];

% set local_session from 1 to 0, if no local recent file found
if (andelse{Recent_Use_Local_Cache != 1 } 
     {file_status(recent_cachefile_name[1]) != 1} )
  Recent_Use_Local_Cache = 0;

% Cache of recent files
%  (a "\n" delimited stringlist of recent file records (latest last))
%    * initialized from recent_cachefile_name[Recent_Use_Local_Cache]
%      on startup and by recent_toggle_local()
%    * updated when loading or saving to a file
%    * saved to Recent_Files_Cache_File on exit
static variable recent_files_cache;


% --------------------------------------------------------------------------

% Load, Save, Append 
% ------------------

% Load the recent files list from file
% 
% Return "", if the Cache file doesnot exist or is inaccessible
% (e.g. after a new value of Recent_Files_Cache_File or with
%  "use local cache files" on.
static define load_cache()
{
   ERROR_BLOCK
     {

	_clear_error;
	return "";
     }
   return strread_file(recent_cachefile_name[Recent_Use_Local_Cache]);
}

% Return a filerecord string for the current buffer (cf. getbuf_info)
% result == "filename:line:col"
% (result == "", if file matches Exclude Pattern or no file is
% 	     	 associated with the buffer)
static define getbuf_filerecord()
{
   variable filename = buffer_filename(); 
   if (orelse {filename == ""}
              {string_match(filename, Recent_Files_Exclude_Pattern, 1)}
      )
     return "";
   return sprintf("%s:%d:%d",
      	           filename, what_line_if_wide(), what_column());
}


% Parse the filerecord(s) string 
% ------------------------------

% Parse a file record of the recent files cache and return as array
% result = ["filename", "line", "column", "is_open"]
static define chop_filerecord(filerecord)
{
   variable fields = strchop(filerecord, ':', 0);
   % Backwards compatibility (old jedrecent files without line/column info)
   if (length(fields) < 4) 
     return [strjoin(fields,":"),"0", "0", "0"];
   return [strjoin(fields[[:-4]],":"), fields[[-3:]]];
}

% Parse a string with list of filerecords, return array of filerecord arrays
% (newest record first)
static define chop_filerecords(filerecords)
{
   if (filerecords == "")
     return String_Type[0];
   % split filerecords (newest record first)
   variable records = strchopr(strtrim(filerecords), '\n', 0);
   return array_map(Array_Type, &chop_filerecord, records);
}


% Return the filename part of an filerecord string
% "filename:line:col:open"
static define get_record_filename(filerecord)
{
   filerecord = strchop(filerecord, ':', 0);
   if (length(filerecord) < 4) % Backwards compatibility / error save ...
     return strjoin(filerecord,":");
   else
     return strjoin(filerecord[[:-4]],":");
}

% Return array of filenames from a "\n" delimited filerecords list
static define get_record_filenames(filerecords)
{
   variable records = strchopr(strtrim(filerecords), '\n', 0);
   return array_map(String_Type, &get_record_filename, records);
}


% Cache maintenance
% -----------------

% Add a filerecord for the current buffer to the cache
% 
% This function will be called when loading or saving to a file
static define add_to_cache()
{
   _pop_n(_NARGS); % remove spurious arguments from stack (when used as hook)
   variable fp, filerecord_string = getbuf_filerecord();
   
   if (filerecord_string == "")
     return;
   
   filerecord_string += ":0\n";
   if (Recent_Files_Synchronize_Cache)
     {
	variable file = recent_cachefile_name[Recent_Use_Local_Cache]; 
	fp = fopen(file, "a+");
	if (fp == NULL) verror("%s could not be opened", file);
	() = fputs(filerecord_string, fp);
	() = fclose(fp);
     }
   else
     recent_files_cache += filerecord_string;
}

% purge doublettes in the cache and reduce to Recent_Max_Cached_Files
% update the cache's line/col info
% if flag_open_files == 1, mark open files with the is_open flag.
static define update_cache(flag_open_files)
{
   if (Recent_Files_Synchronize_Cache)
     recent_files_cache = load_cache();
   % update line/col info for open buffers
   variable openfiles = Assoc_Type[String_Type];
   loop(buffer_list)
     {
	sw2buf(());
	openfiles[buffer_filename()] = getbuf_filerecord();
     }
   % there will be a spurious element openfiles[""] == ""
   % (for buffers with filename == "")
   % This does not matter, as only buffers already listed in the cache 
   % will be updated below

   % update and purge the cache
   variable filerecord, filename, i=0, 
     new_cache = "\n"; % initialize for is_substr() search (see below)
   
   foreach(chop_filerecords(recent_files_cache))
     {
	filerecord = ();     % ["filename", "line", "column", "is_open"]
	filename = filerecord[0];
	% show(filerecord);
	
	% skip empty filenames (cleanup of corrupt .jedrecent files)
	if (filename == "")
	  continue;
	
	% skip doublettes
	if (is_substr(new_cache, "\n"+filename+":"))
	  continue;
	% (fails for "/path/foo", if "/path/foo:bar" is on the list,
	%  but this might be tolerable (given the needed effort to correct))

	% update file flags and convert to string
	if (assoc_key_exists(openfiles, filename))
	  {
	     filerecord = strcat(openfiles[filename], ":", string(1));
	  }
	else
	  filerecord = strjoin(filerecord,":");
	
	% prepend to cache
	new_cache = strcat("\n", filerecord, new_cache);
	
	if (i >= Recent_Max_Cached_Files) 
	  break;
	i++;
     }
   recent_files_cache = strtrim_beg(new_cache);
}

% Save the recent files list to a file, delete the file if the cache is empty
% Return 1 to tell _jed_exit_hooks to continue
static define save_cache()
{
   update_cache(1);
   ERROR_BLOCK 
     {
	_clear_error;
     }
   if (recent_files_cache != "")
     () = write_string_to_file(recent_files_cache, 
	recent_cachefile_name[Recent_Use_Local_Cache]);
   else
     () = delete_file(recent_cachefile_name[Recent_Use_Local_Cache]);
   return 1;   
}


% Find a file and goto given positon
% filerecord == ["filename", "line", "column", "is_open"]
static define recent_load_file(filerecord)
{
   % show("loading record", filerecord);
   () = find_file(filerecord[0]);
   % goto saved position
   if (what_line() != 1)     % file was already open
     return;
   goto_line(integer(filerecord[1]));
   () = goto_column_best_try(integer(filerecord[2]));
   % open folds
   loop (10) % while (is_line_hidden) might cause an infinite loop!
     {
	!if (is_line_hidden) 
	  break;
	runhooks("fold_open_fold");
     }
}

% reopen the files that were open in the last session of jed
static define restore_session()
{
   variable record, records = chop_filerecords(recent_files_cache);
   foreach (chop_filerecords(recent_files_cache))
     {
	record = ();
	if (andelse
	    { record[3] == "1" }
	    { orelse { Restore_Last_Session != 2 }
		   { path_dirname(getcwd()) != path_dirname(record[0]) }
	    }
	    { file_status(record[0]) }
	   )
	  recent_load_file(record);
     }
   % goto first opened buffer
   if (bufferp(path_basename(records[0][0])))
      sw2buf(path_basename(records[0][0]));
}


% Functions for the File>Recent_Files menu 
% ----------------------------------------

% clear the cache
static define clear_cache()
{
   recent_files_cache = "";
   if (Recent_Files_Synchronize_Cache)
     () = delete_file(recent_cachefile_name[Recent_Use_Local_Cache]);
}


% Toggle the use of a local recent files file
 public define recent_toggle_local()
{
   save_cache();                                  % save the current state
   Recent_Use_Local_Cache = not(Recent_Use_Local_Cache);          % toggle
   recent_files_cache = load_cache();           % load the new recent-file
   menu_select_menu("Global.&File.&Recent Files"); % reopen menu
}

static define recent_files_menu_callback(popup)
{
   variable menu, n, i = '1', filerecord, filename, dir,
     toggle_str = ["&Use local filelist", "&Use global filelist"],
     format_str = "&%c %-"+string(Recent_Files_Column_Width)+"s %s";
   
   update_cache(0);
   foreach (chop_filerecords(recent_files_cache))
     {
	filerecord = ();
	% show(filerecord);
	filename= path_basename(filerecord[0]);
	dir = contract_filename(path_dirname(filerecord[0]), "");
	menu_append_item (popup, sprintf (format_str, i, filename, dir),
	   &recent_load_file, filerecord);
	% menu index: 1-9, then a-z, then A-Z, then restart
	switch (i)
	  { case '9': i = 'a'; }
	  { case 'z': i = 'A'; }
	  { case 'Z': i = '1'; }
	  {           i++;     }
     }
   menu_append_separator(popup);
   menu_append_item(popup, "Clear Cache", "recent->clear_cache");
   menu_append_item(popup, toggle_str[Recent_Use_Local_Cache], 
      		    "recent_toggle_local");
}

static define add_recent_files_popup_hook(menubar)
{
   variable menu = "Global.&File";

   menu_append_separator (menu);
   menu_append_popup (menu, "&Recent Files");
   menu_set_select_popup_callback (strcat (menu, ".&Recent Files"),
				   &recent_files_menu_callback);
}

% Interface functions
% -------------------

% Return the recent files as an array (last saved file first)
% (e.g. for use in the minibuffer with rimini.sl)
 public define recent_get_files()
{
   update_cache(0);
   return get_record_filenames(recent_files_cache);
}


% Code run at evaluation time (usually startup)
% ---------------------------------------------

% Load the filerecords list
if (Restore_Last_Session or not(Recent_Files_Synchronize_Cache))
  recent_files_cache = load_cache();

% Hooks

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


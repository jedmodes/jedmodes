% sfrecent.sl
% small fast recent
%
% $Id: sfrecent.sl,v 1.1.1.1 2004/10/28 08:16:25 milde Exp $
% Keywords: convenience
% 
% Copyright (c) 2003 Paul Boekholt
% Released under the terms of the GNU GPL (version 2 or later).

_autoload("strread_file", "bufutils",
	 "filelist_mode", "filelist",2);
implements("recent");
custom_variable ("RECENT_FILES_LIST", dircat (Jed_Home_Directory, ".jedrecent"));

static variable recent_files = "";

% load the recent list
static define load_recent_files_file ()
{
   ERROR_BLOCK
     {
	"";
	_clear_error;
     }
   strread_file(RECENT_FILES_LIST);
}

% Build a list of at most 25 unique recent files
static define uniquify_recent_list()
{
   variable i = 0, element;
   strchop (recent_files, '\n', 0);
   recent_files = "";
   foreach ()
     {
	element = ();
	if (i == 25) break;
	if (is_list_element(recent_files, element, '\n')) continue;
	recent_files = strcat (recent_files, element, "\n");
	i++;
     }
}

% return recent files as array
public define recent_get_files()
{
   uniquify_recent_list;
   return (strchopr(strtrim(recent_files, "\n"), '\n', 0));
}

public define show_recent()
{
   uniquify_recent_list;
   sw2buf("*recent*");
   set_readonly(0);
   erase_buffer;
   insert(recent_files);
   bob;
   filelist_mode;
   define_blocal_var("FileList_Cleanup", 2);
}

% Add a file to the list of recent files
public define append_recent_files ()
{
   variable file, dir;
   (file,dir,,) = getbuf_info ();
   if (andelse 
	{strlen (file)} 
	  {strncmp(dir, "/tmp", 4)})
     recent_files = strcat(dircat (dir, file), "\n", recent_files);
}
add_to_hook ("_jed_find_file_after_hooks", &append_recent_files);


% Save the recent file list
static define save_recent_files()
{
   variable disk_recent_file = load_recent_files_file;
   recent_files = strcat(recent_files, disk_recent_file);
   uniquify_recent_list;
   ERROR_BLOCK 
     {
	_clear_error;
     }
   () = write_string_to_file(recent_files, RECENT_FILES_LIST);
   1;          % tell _jed_exit_hooks to continue
}
append_to_hook("_jed_exit_hooks", &save_recent_files);

recent_files = load_recent_files_file;

provide("recent");

% gdbmrecent.sl
% 
% $Id: gdbmrecent.sl,v 1.4 2006/05/21 10:27:35 paul Exp paul $
% Keywords: convenience
%
% Copyright (c) 2004, 2005, 2006 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% Yet another recent mode. This one was written to test my gdbm module.
% You should get slgdbm version 1.7 or later from
% http://www.cheesit.com/downloads/slang/slgdbm.html
% or if you're on Debian install the slang-gdbm package.
% 
% Features:
% -delayed synchronization of the database. It should still be possible
%  to work in multiple instances at the same time
% -stores line and column information
% -goes to last line and column even when file is not opened from recent menu
% -recent menu shows only the most recent `Recent_Max_Cached_Files' files, but line and
%  column information is remembered for Recent_Files_Expire_Time days.
% -Make buffer-local variables persistent.  For now this can be used to make
%  a buffer's ispell dictionary setting persist - make sure to upgrade
%  ispell_common.sl to revision 1.13.

!if(is_defined("_gdbm_module_version_string"))
  import("gdbm");

provide("recent");
provide("gdbmrecent");

% customvariables.

% where to store the list
custom_variable("Recent_Db", dircat(Jed_Home_Directory, "recent_db"));
% length of the recent popup menu
custom_variable("Recent_Max_Cached_Files", 15);
% regexp for files not to be added to the recent list (/tmp/mutt-1234)
custom_variable("Recent_Files_Exclude_Pattern", "/tmp");
% Time before entries expire (in days)
custom_variable("Recent_Files_Expire_Time", 7);

% This is a comma-separated list of blocal variables that are stored in the
% recent files database.  The entry is still purged if a file is not opened
% for a week.  The blocal's values have to be strings, and for now `=' and `:'
% are not allowed in them.
custom_variable("Gdbm_Pvars", "ispell_dictionary");

% the idea of the recent_flag is that when a script opens a file that should
% not be added to the recent list it should say
% public variable recent_flag;
% ...
% recent_flag = 0;
% () = find_file("/some/file");
public variable recent_flag=1;

private variable recent_files=Assoc_Type[String_Type];

% Return a cache entry for the current buffer (see getbuf_info)
% (NULL if file matches Exclude Pattern or no file 
% associated with buffer)
private define getbuf_filemark()
{
   if(blocal_var_exists("no_recent")) return NULL;
   variable entry = buffer_filename();
   !if (strlen(entry)) return NULL;
   if (string_match(entry, Recent_Files_Exclude_Pattern, 1))
     return NULL;
   variable varname, val=sprintf("%d:%d:%d",_time(), what_line_if_wide(), what_column());
   foreach(strchop(Gdbm_Pvars, ',', 0))
     {
	varname=();
	if (blocal_var_exists(varname))
	  val = sprintf("%s:%s=%s", val, varname, get_blocal_var(varname));
     }
   return [entry, val];
}

% find_file_after_hook
% goto line, column
% update date in assoc
private define open_hook ()
{
   !if (recent_flag)
     {
	create_blocal_var("no_recent");
	recent_flag = 1;
	return;
     }
   variable date, line=1, column=1, pvars="", pvar;
   variable filename = buffer_filename();
   !if (strlen(filename)) return;
   if (string_match(filename, Recent_Files_Exclude_Pattern, 1))
     return;
   
   variable val = NULL, db=gdbm_open(Recent_Db, GDBM_READER, 0600);
   if (db != NULL)
     val = db[filename];
   if (andelse
       {val != NULL}
       {4 == sscanf(val, "%d:%d:%d%s", &date, &line, &column, &pvars)})
     {
	% goto saved position
	goto_line(line);
	() = goto_column_best_try(column);
	% open folds
	loop(10) % while (is_line_hidden) might cause an infinite loop!
	  {
	     !if(is_line_hidden) break;
	     runhooks("fold_open_fold");
	  }
	if (strlen(pvars))
	  {
	     foreach(strchop(pvars, ':', 0))
	       {
		  pvar=();
		  pvar=strchop(pvar, '=', 0);
		  if (2==length(pvar))
		       define_blocal_var(pvar[0], pvar[1]);
	       }
	  }
     }
   recent_files[filename] = sprintf("%d:%d:%d:%s", _time(), what_line(), 
				    what_column(), pvars);
}

% save hook
% update assoc
private define save_hook()
{
   _pop_n (_NARGS); % remove spurious arguments from stack
   variable filemark = getbuf_filemark();
   if (filemark == NULL) return;
   recent_files[filemark[0]] = filemark[1];
}

% save the recent files assoc to the database
private define update_db(db)
{
   variable k, v;
   foreach(recent_files) using ("keys", "values")
     {
	(k,v) = ();
	% if write fails, stop trying
	if (gdbm_store(db, k, v, GDBM_REPLACE))
	  break;
     }
   recent_files=Assoc_Type[String_Type];
}


private define _get_files(db)
{
   variable keys, values, dates;
   (keys, values) = gdbm_get_keys_and_values(db);
   dates = array_map(Integer_Type, &atoi, values);
   keys=keys[array_sort(-dates)];
   return keys;
}

public define recent_get_files()
{
   variable db=gdbm_open(Recent_Db, GDBM_READER, 0600);
   if (db != NULL)
     _get_files(db);
}


% build the menu
private define menu_callback (popup)
{
   variable db=gdbm_open(Recent_Db, GDBM_WRCREAT, 0600);
   if (db == NULL) return vmessage("gdbm: %s", gdbm_error());
   update_db(db);
   variable keys, cmd, l, i;
   
   keys = _get_files(db);
   l = length(keys);
   
   if (l > Recent_Max_Cached_Files)
     l = Recent_Max_Cached_Files;
   
   _for(0, l - 1, 1)
     {
	i=();
	cmd = sprintf ("() = find_file (\"%s\")", keys[i]);
	menu_append_item (popup, keys[i], cmd);
     }  
}


% this shows a menu of at most Recent_Max_Cached_Files that were opened in the
% current buffer's directory or a subdirectory thereof.
private define recent_here_callback (popup)
{
   variable dir = buffer_dirname(), dirlen = strlen(dir), key;
   !if(dirlen) return;
   variable db=gdbm_open(Recent_Db, GDBM_WRCREAT, 0600);
   if (db == NULL) return vmessage("gdbm: %s", gdbm_error());
   update_db(db);
   variable keys, cmd, l, i;
   
   keys = _get_files(db);
   keys = keys[where(not array_map(Integer_Type, &strncmp, keys, dir, dirlen))];
   l = length(keys);
   
   if (l > Recent_Max_Cached_Files)
     l = Recent_Max_Cached_Files;
   
   _for(0, l - 1, 1)
     {
	i=();
	cmd = sprintf ("() = find_file (\"%s\")", keys[i]);
	menu_append_item (popup, keys[i], cmd);
     }  
}

private define purge_not_so_recent(db)
{
   variable key, keys, values, dates;
   (keys, values) = gdbm_get_keys_and_values(db);
   variable cutoff_date = _time() - 86400 * Recent_Files_Expire_Time;
   dates = array_map(Integer_Type, &atoi, values);
   keys = keys[where(dates < cutoff_date)];
   % it's not possible to use foreach(db) here
   % see info:(gdbm)Sequential
   foreach(keys)
     {
	key=();
	gdbm_delete(db, key);
     }
}

% update the cache's line/col info
% purge entries older than a week
private define exit_hook()
{
   variable db=gdbm_open(Recent_Db, GDBM_WRCREAT, 0600);
   if (db == NULL) return 1;
   variable filemark;
   % update line/col info
   loop(buffer_list)
     {
	sw2buf();
	filemark = getbuf_filemark();
	if (filemark != NULL)
	  recent_files[filemark[0]] = filemark[1];
     }
   update_db(db);
   purge_not_so_recent(db);
   variable st=stat_file(Recent_Db);
   if (st.st_size > 50000)
     ()=gdbm_reorganize(db);
   return 1;   % tell _jed_exit_hooks to continue
}


private define add_recent_files_popup_hook (menubar)
{
   variable menu = "Global.&File";

   menu_insert_popup (0, menu, "&Recent Files");
   menu_set_select_popup_callback (strcat (menu, ".&Recent Files"),
				   &menu_callback);
   menu_insert_popup (1, menu, "&Recent Here");
   menu_set_select_popup_callback (strcat (menu, ".&Recent Here"),
				   &recent_here_callback);

}

append_to_hook ("_jed_find_file_after_hooks", &open_hook);
append_to_hook("_jed_save_buffer_after_hooks", &save_hook);

% update list at exit
append_to_hook("_jed_exit_hooks", &exit_hook);

append_to_hook ("load_popup_hooks", &add_recent_files_popup_hook);


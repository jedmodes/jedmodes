% Interface to mtools (http://mtools.linux.lu/) 
% for easy floppy read/write under UNIX
% 
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 1.0 2003-xx-xx  first public version
% 1.1 2004-02-16  use a temp-file for mtools_find_file to preserve the CR-LFs
%                 (bugreport P. Boekholt)
%                 separate the directory listing to mtools_list_dir()
% 1.1.1 2004-06-03 bugfix in mtools_find_file (normalize pathname)                
% 
% USAGE:
% 
% Put in your jed_library_path and add autoloads for the functions
% (or run make_ini from jedmodes.sf.net/mode/make_ini/).
% Optionally set the custom variable Mtools_Write_Args.
%   variable Mtools_Write_Args = "-D o";  % overwrite existing files
% 
% See extensive mtools documentation with info.
% 
% EXAMPLE: 
%   mtools_find_file("a:")     -> get a listing of the floppy dir (mdir)
%   mtools_find_file("a:test") -> load file "test" from floppy into buffer
%   mtools_write("a:test")     -> write buffer/region to floppy
%   
% RECOMMENDS:
% uri.sl (http://jedmodes.sf.net/mode/uri) to access the floppy using
% the normal find_file/write_buffer/write_region functions (via hooks)

% _debug_info = 1;

% requirements
% autoload("filelist_mode", "filelist");

% --- Variables

% mtools_write doesnot work interactive, so nameclashes result in an error, 
% if no solution scheme is set: 
% custom_variable("Mtools_Write_Args", "-D o");  % overwrite existing file
custom_variable("Mtools_Write_Args", "-D a");  % autorename the new file

% Directory for temporary files
custom_variable("Jed_Temp_Dir", getenv("TEMP"));
if (Jed_Temp_Dir == NULL)
  Jed_Temp_Dir = getenv("TMP");
if (Jed_Temp_Dir == NULL)
  Jed_Temp_Dir = "/tmp";

% call mdir for path
define mtools_list_dir(path)
{
   variable status;
   
   sw2buf(path);
   set_readonly(0);
   erase_buffer();
   status = run_shell_cmd("mdir " + path);  % directory listing
   set_buffer_modified_flag(0);
   % error handling
   if (status)
     {
	delbuf(whatbuf);
	verror("mdir returned %d, %s", status, errno_string(status));
     }
   setbuf_info("", path, path, 8);
   define_blocal_var("filename_position", 5);
   % filelist_mode();
   return(not(status)); % success
}

% Find a file using (usually on a floppy) using mtools
% If the filename has no basepart or is just "a:", do a directory listing
% Return success
define mtools_find_file(path)
{
   variable status, flags,
     tmp_file = make_tmp_file(path_concat(Jed_Temp_Dir, path))
                + path_extname(path); % (to get the mode right)
   
   % standardize the name of the root dir (so path_basename() works)
   !if (is_substr(path, "a:/"))
     (path, ) = strreplace (path, "a:", "a:/", 1);

   % show(_function_name, path, path_basename(path));
   % return a listing if the path is a directory
   if (path_basename(path) == "")
     return mtools_list_dir(path);
     
   % copy file to tmp_file
   status = system(strjoin(["mcopy", path, tmp_file], " "));
   if (status)
     verror("mtools returned %d, %s", status, errno_string(status));

   % open the temp file, delete it and correct buffer settings
   () = find_file(tmp_file);
   delete_file(tmp_file);
   (, , , flags) = getbuf_info();
   % the dirname is always expanded, so I cannot set it to a:<something> :-(
   % setbuf_info(path_basename(path), path_dirname(path), tmp_file, flags);
   % set to empty file and dir names, so save_buffer asks where to save
   % TODO: do not reopen if buffer exists.
   setbuf_info("", "", tmp_file, flags);
   rename_buffer(path); % be sure not to have 2 buffers 
                                       % with the same name
   
   return(not(status)); % success
}

% Write buffer (or if defined region) to a file (usually on a floppy) 
% using mtools
% Return success
define mtools_write(path)
{
   % show("mtools-write", path);
   variable status;
   push_spot();
   !if (is_visible_mark())
     mark_buffer();
   flush ("Saving to " + path );
   status = pipe_region(sprintf("mcopy %s - %s", Mtools_Write_Args, path));
   
   !if (status)
	set_buffer_modified_flag(0);
   else
	verror("mtools returned %d, %s", status, errno_string(status));
   return(not(status)); % success
}

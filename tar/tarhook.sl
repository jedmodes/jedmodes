% usually, you will have tar.sl if you have this file
autoload("tar", "tar");

% This checks if the file has a tar extension.
% To be used from e.g. filelist.sl
public define check_for_tar (file)
{
   variable exts = strchopr( path_basename( file), '.', 0);
   if ( 1 == length( exts)) return 0;
   if ( is_list_element( "tgz,tar,tZ,tbz", exts[0], ','))
     return 1;
   if (andelse 
       { 2 != length( exts) }
	 { exts[1] == "tar" }
	 { is_list_element( "gz,Z,bz2,bz", exts[0], ',') })
     return 1;
   return 0;
}

% This checks if file is a tar, and if so opens it read-only.
% To be added to _jed_find_file_before_hooks.
public define check_for_tar_hook (file)
{
   if (check_for_tar( file))
     {
	tar( file, 1); % open read-only
	return 1;
     }
   else return 0;
}
   
provide("tarhook");   

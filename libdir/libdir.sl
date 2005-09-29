% libdir.sl: Support for library directories with jed extensions
% 
% % Copyright (c) Günter Milde and released under the terms 
% of the GNU General Public License (version 2 or later).
% 
% Versions
% 0.9   2005-09-19  first public version, based on home-lib.sl
% 0.9.1 2005-09-29  removed custom_variable stuff
% 
% FEATURES
% 
% The functions add_libdir(path) and append_libdir(path) declare
% additional library directories:
% 
%  * prepend|append `path' to the jed-library-path (searched for modes)
%  * set Color_Scheme_, dfa-cache- and documentation- path
%  * evaluate (if existent) the file ini.sl in path
%    (ini.sl files can be autocreated by make_ini.sl)
%  
% Together with make_ini.sl, this provides a convenient way of extending
% jed with contributed or home-made scripts.
% 
% INITIALIZATION
% 
% Write in your .jedrc (or jed.rc on winDOS) e.g.
%   require("libdir", "/FULL_PATH_TO/libdir.sl");
%   add_libdir("/usr/local/share/jed/lib"));
%   add_libdir(path_concat(Jed_Home_Directory, "lib"));
        
  

%!%+
%\function{add_libdir}
%\synopsis{Register a library dir for use by jed}
%\usage{add_libdir(path)}
%\description
%  * Prepend \var{path} to the library path
%  * Set \var{Color_Scheme_Path}, \var{Jed_Doc_Files},
%    \var{Jed_Highlight_Cache_Dir}, and \var{Jed_Highlight_Cache_Path}
%  * Evaluate (if existent) the file \var{ini.sl} in this library
%    to enable initialization (autoloads etc)
%\example
%#v+
%  add_libdir(path_concat(Jed_Local_Directory, "lib"));
%  add_libdir(path_concat(Jed_Home_Directory, "lib"));
%#v-
% will register the local and user-specific library-dir
%\seealso{append_libdir, make_ini, set_jed_library_path, Jed_Doc_Files}
%\seealso{Color_Scheme_Path, Jed_Highlight_Cache_Dir, Jed_Highlight_Cache_Path}
%!%-
define add_libdir(lib)
{
   % abort, if directory doesnot exist
   if (orelse{lib == ""}{2 != file_status(lib)}) 
     continue;
   
   variable path;
   % jed library path
   set_jed_library_path(lib + "," + get_jed_library_path());
   % colors
   path = path_concat(lib, "colors");
   if (2 == file_status(path))
     Color_Scheme_Path = path + "," + Color_Scheme_Path;
   % documentation
   path = path_concat(lib, "libfuns.txt");
   if (1 == file_status(path))
     Jed_Doc_Files = path + "," + Jed_Doc_Files;
   % dfa cache
#ifdef HAS_DFA_SYNTAX
   % Jed_Highlight_Cache_Dir = lib;
   Jed_Highlight_Cache_Path = lib + "," + Jed_Highlight_Cache_Path;
#endif
   % Check for a file ini.sl containing initialization code
   % (e.g. autoload declarations) and evaluate it.
   path = path_concat(lib, "ini.sl");
   if (1 == file_status(path))
     () = evalfile(path);
}

%!%+
%\function{append_libdir}
%\synopsis{Register a library dir for use by jed}
%\usage{append_libdir(path)}
%\description
%  * Append \var{path} to the library path
%  * Set \var{Color_Scheme_Path}, \var{Jed_Doc_Files},
%    \var{Jed_Highlight_Cache_Dir}, and \var{Jed_Highlight_Cache_Path}
%  * Evaluate (if existent) the file \var{ini.sl} in this library
%    to enable initialization (autoloads etc)
%\example
%#v+
%  append_libdir(path_concat(Jed_Local_Directory, "lib"));
%#v-
% will register the local
%\seealso{add_libdir, make_ini, set_jed_library_path, Jed_Doc_Files}
%\seealso{Color_Scheme_Path, Jed_Highlight_Cache_Dir, Jed_Highlight_Cache_Path}
%!%-
define append_libdir(lib)
{
   % abort, if directory doesnot exist
   if (orelse{lib == ""}{2 != file_status(lib)}) 
     continue;
   
   variable path;
   % jed library path
   set_jed_library_path(get_jed_library_path() + "," + lib);
   % colors
   path = path_concat(lib, "colors");
   if (2 == file_status(path))
     Color_Scheme_Path = Color_Scheme_Path + "," + path;
   % documentation
   path = path_concat(lib, "libfuns.txt");
   if (1 == file_status(path))
     Jed_Doc_Files = Jed_Doc_Files + "," + path;
   % dfa cache
#ifdef HAS_DFA_SYNTAX
   Jed_Highlight_Cache_Path = Jed_Highlight_Cache_Path + "," + lib;
#endif
   % Check for a file ini.sl containing initialization code
   % (e.g. autoload declarations) and evaluate it.
   path = path_concat(lib, "ini.sl");
   if (1 == file_status(path))
     () = evalfile(path);
}


% libdir.sl: Support for library directories with jed extensions
% 
% % Copyright (c) Günter Milde and released under the terms 
% of the GNU General Public License (version 2 or later).
% 
% Versions
% 0.9   2005-09-19  first public version, based on home-lib.sl
% 0.9.1 2005-09-29  removed custom_variable stuff
% 0.9.2 2005-10-12  documentation fix
% 0.9.3 2005-11-03  evaluation of ini.sl now customizable with optional arg
% 0.9.4 2005-11-06  added provide() statement
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
        
% _debug_info = 1;  

provide("libdir");

%!%+
%\function{add_libdir}
%\synopsis{Register a library dir for use by jed}
%\usage{add_libdir(path, initialize=1)}
%\description
%  * Prepend \var{path} to the library path
%  * Add \var{path} to \var{Color_Scheme_Path}, \var{Jed_Doc_Files},
%    and \var{Jed_Highlight_Cache_Path}
%  * Evaluate (if existent and \var{initialize} is TRUE) the file \var{ini.sl} 
%    in this library to enable initialization (autoloads etc)
%\example
%#v+
%  add_libdir("usr/local/jed/lib/", 0));  % do not initialize
%  add_libdir(path_concat(Jed_Home_Directory, "lib"));
%#v-
% will register the local and user-specific library-dir
%\seealso{append_libdir, make_ini, set_jed_library_path, Jed_Doc_Files}
%\seealso{Color_Scheme_Path, Jed_Highlight_Cache_Dir, Jed_Highlight_Cache_Path}
%!%-
define add_libdir()
{
   variable lib, initialize=1;
   if (_NARGS == 2)
     initialize = ();
   lib = ();
   
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
   if (initialize and 1 == file_status(path))
     () = evalfile(path);
}

%!%+
%\function{append_libdir}
%\synopsis{Register a library dir for use by jed}
%\usage{append_libdir(path, initialize=1)}
%\description
%  * Append \var{path} to the library path
%  * Append \var{path} to \var{Color_Scheme_Path}, \var{Jed_Doc_Files},
%    and \var{Jed_Highlight_Cache_Path}
%  * Evaluate (if existent and \var{initialize} is TRUE) the file \var{ini.sl} 
%    to enable initialization (autoloads etc)
%\seealso{add_libdir}
%!%-
define append_libdir()
{
   variable lib, initialize=1;
   if (_NARGS == 2)
     initialize = ();
   lib = ();
   
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
   if (initialize and 1 == file_status(path))
     () = evalfile(path);
}


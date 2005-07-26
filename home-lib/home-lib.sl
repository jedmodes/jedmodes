% Extended support for a user-specific directory with private extensions
% 
% % Copyright (c) 2003 Günter Milde and released under the terms 
% of the GNU General Public License (version 2 or later).
% 
% Versions
% 0.9    first public version
% 0.9.1  Jed_Highlight_Cache_Path += Jed_Home_Library;
% 0.9.2  cleanup of code and documentation + bugfix
%        custom_variable for Jed_Site_Library and Jed_Home_Library
% 0.9.3  documentation bugfix: "%!%" -> "%!%-"
% 0.9.4  outsourcing of the registration -> register_library(dir)
%        added custom_variable Jed_Debian_Library = ""
% 0.9.5  removed the adding of Jed_Home_Directory/doc/txt/libfuns.txt
%        to Jed_Doc_Files
%        removed Jed_Debian_Library and introduced Jed_Local_Library
%        (thanks to Dino Sangoi for a Windows default).
% 0.9.5  renamed register_library() to register_libdir()
% 2005-07-11
% 1.0    make the script less "aggresive", so it can be evaluated without
%        side-effects. 
%          * !! new way of invocation, see INITIALIZATION !!
%          * no automatic change of Jed_Home_Directory (do this in
%            the configuration file instead)
%          * do not change Default_Jedrc_Startup_File
%        * prepend (instead of append) <libdir>/colors to Color_Scheme_Path 
%          (report J. Sommer)
%          UNIX home-lib default without trailing "/"
% 1.1    2005-07-22 further code cleanup
% 	 shedding of the *_Library custom variables, added 
% 	 Jed_Local_Directory instead (in line with Jed_Home_Directory)
%
% FEATURES
% 
% the function register_libdir(path):
% 
%  * prepends path to the jed-library-path (searched for modes)
%  * sets Color_Scheme_, dfa-cache- and documentation- path
%  * evaluates (if existent) the file ini.sl in path
%    (ini.sl files can be autocreated by make_ini.sl)
%  
% Together with make-ini.sl, this provides a convenient way of extending
% jed with contributed or home-made scripts.
% 
% INITIALIZATION
% 
% Write in your .jedrc (or jed.rc on winDOS) e.g.
%   require("home-lib", "/FULL_PATH_TO/home-lib.sl");
%   register_libdir(path_concat(Jed_Local_Directory, "lib"));
%   register_libdir(path_concat(Jed_Home_Directory, "lib"));
        
% Jed_Home_Directory
% ------------------
%
% Jed_Home_Directory is defined in site.sl, defaulting to $HOME
% previous versions contained code to change this to ~/.jed/
% 
% With the code below in jed.conf (or defaults.sl), Jed looks for .jedrc 
% in "~/.jed/".
% 
%   % If Jed_Home_Directory/.jed/ exists, point Jed_Home_Directory there,
%   $1 = path_concat(Jed_Home_Directory, ".jed");
%   if(2 == file_status($1))
%     Jed_Home_Directory = $1; 
%
% Alternatively, place .jedrc in HOME and set there
%   Jed_Home_Directory = path_concat(Jed_Home_Directory, ".jed");
  

%!%+
%\variable{Jed_Local_Directory}
%\synopsis{Directory for local site-wide jed extensions}
%\description
%\description
%  The value of this variable specifies the systems local "jed directory"
%  where system-wide non-standard jed-related files are assumed to be found.
%  Normally, this corresponds to "/usr/local/share/jed" on UNIX and
%  "$ALLUSERSPROFILE\\$APPDATA\\Jedsoft\\JED" on Windows
%  unless an alternate directory is specified via the \var{JED_LOCAL} 
%  environment variable. 
%
%  As it is a custom_variable, it can be set/changed in defaults.sl, jed.conf,
%  and/or .jedrc, of course.  
%  
%  It is set to "" if the specified directory does not exist.
%\seealso{JED_ROOT, Jed_Home_Directory}
%!%-
custom_variable("Jed_Local_Directory", getenv("JED_LOCAL"));
if (Jed_Local_Directory == NULL) % no custom or environment var set
{
#ifdef IBMPC_SYSTEM
   $2 = getenv("ALLUSERSPROFILE");
   $3 = getenv("APPDATA");
   if ($2 == NULL or $3 == NULL)
     Jed_Local_Directory = "";
   else
     Jed_Local_Directory = path_concat(path_concat($2, path_basename($3)), 
                                     "Jedsoft\\JED");
#else
     Jed_Local_Directory = "/usr/local/share/jed";
#endif
}

if (file_status(Jed_Local_Directory) != 2) % no directory
  Jed_Local_Directory = "";


%!%+
%\function{register_libdir}
%\synopsis{Register a library dir for use by jed}
%\usage{register_libdir(path)}
%\description
%  * Prepend \var{path} to the library path
%  * Set \var{Color_Scheme_Path}, \var{Jed_Doc_Files},
%    \var{Jed_Highlight_Cache_Dir}, and \var{Jed_Highlight_Cache_Path}
%  * Evaluate (if existent) the file \var{ini.sl} in this library
%    to enable initialization (autoloads etc)
%\example
%#v+
%  register_libdir(path_concat(Jed_Local_Directory, "lib"));
%  register_libdir(path_concat(Jed_Home_Directory, "lib"));
%#v-
% will register the local and user-specific library-dir
%\seealso{make_ini, set_jed_library_path, Color_Scheme_Path, Jed_Doc_Files}
%\seealso{Jed_Highlight_Cache_Dir, Jed_Highlight_Cache_Path}
%!%-
define register_libdir(lib)
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
   Jed_Highlight_Cache_Dir = lib;
   Jed_Highlight_Cache_Path = lib + "," + Jed_Highlight_Cache_Path;
#endif
   % Check for a file ini.sl containing initialization code
   % (e.g. autoload declarations) and evaluate it.
   path = path_concat(lib, "ini.sl");
   if (1 == file_status(path))
     () = evalfile(path);
}


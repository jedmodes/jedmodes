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
% 1.0    make the script less "aggresive", so it can be evaluated without
%        side-effects. 
%          * !! new way of invocation, see INITIALIZATION !!
%          * do not change Jed_Home_Directory (do this in
%            the configuration file instead)
%          * do not change Default_Jedrc_Startup_File
%        * prepend (instead of append) /colors to Color_Scheme_Path (J. Sommer)
%
% FEATURES
% 
%  * If a subdirectory .jed/ exists in Jed_Home_Directory,
%    change Jed_Home_Directory to point there
%    
%  * Initializes up to 3 extension libraries:
%  
%    1. Jed_Site_Library  (default "JED_ROOT/site-lib")
%       
%       for modes provided by the distribution (e.g. Debian GNU/Linux)
%
%    2. Jed_Local_Library (default "/usr/local/share/jed/lib")
%    
%    	for site-wide extensions|modifications by the local administrator
%    	
%    3. Jed_Home_Library  (default "~/.jed/lib")
%    
%    	for user extensions|modifications
%  
%  * evaluate (if existent) the file ini.sl in the extension libraries
%    (ini.sl files can be autocreated by make_ini.sl)
%    
%  * set Color_Scheme_, dfa-cache- and documentation- path
%  
% Together with make-ini.sl, this provides a convenient way of extending
% jed with contributed or home-made scripts.
% 
% INITIALIZATION
% 
% Write in your .jedrc (or jed.rc on winDOS) e.g.
%   require("home-lib", "/FULL_PATH_TO/home-lib.sl");
%   register_libdir(Jed_Home_Library, Jed_Local_Library, Jed_Site_Library);
% 
% CUSTOMIZATION
% 
% For other than the default paths use the environment variables 
% JED_HOME and JED_SITE_LIB or define Jed_Site_Library, Jed_Local_Library, 
% and Jed_Home_Library before evaluating home-lib.sl.
        
private variable path;

% Jed_Home_Directory
% ------------------

% Jed_Home_Directory is defined in site.sl, defaulting to $HOME
% previous versions contained code to change this to ~/.jed/
% 
% With the code below in jed.conf (or defaults.sl), Jed looks for .jedrc 
% in ~/.jed/ only. 
% 
%   % If Jed_Home_Directory/.jed/ exists, point Jed_Home_Directory there,
%   $1 = path_concat(Jed_Home_Directory, ".jed");
%   if(2 == file_status($1))
%     Jed_Home_Directory = $1; 

% Alternatively, place .jedrc in HOME and set there
%   Jed_Home_Directory = expand_filename("~/.jed");
  
% custom variables
% ----------------

%!%+
%\variable{Jed_Site_Library}
%\synopsis{Directory for site-wide non-standard slang scripts}
%\description
%  \var{Jed_Site_Library} specifies the directory for site-wide
%  jed modes provided by the distribution (e.g. Debian GNU/Linux)
%  
%  It is a custom variable that defaults to the value of the 
%  \var{JED_SITE_LIB} environment variable or "JED_ROOT/site-lib"
%  and is set to "" if the specified directory does not exist.
%\seealso{Jed_Local_Library, Jed_Home_Library, set_jed_library_path}
%!%-
custom_variable("Jed_Site_Library", getenv("JED_SITE_LIB"));
if (Jed_Site_Library == NULL) % no custom or environment var set
  Jed_Site_Library = path_concat(JED_ROOT, "site-lib");
if (file_status(Jed_Site_Library) != 2) % no directory
  Jed_Site_Library = "";

%!%+
%\variable{Jed_Local_Library}
%\synopsis{Directory for site-wide non-standard slang scripts}
%\description
%  \var{Jed_Local_Library} specifies the directory for site-wide
%  jed modes provided by the distribution (e.g. Debian GNU/Linux)
%  
%  It is a custom variable that defaults to the value of the 
%  \var{JED_LOCAL_LIB} environment variable or "/usr/local/share/jed/lib"
%  and is set to "" if the specified directory does not exist.
%\seealso{Jed_Site_Library, Jed_Home_Library, set_jed_library_path}
%!%-
custom_variable("Jed_Local_Library", getenv("JED_LOCAL_LIB"));
if (Jed_Local_Library == NULL) % no custom or environment var set
{
#ifdef IBMPC_SYSTEM
   $2 = getenv("ALLUSERSPROFILE");
   $3 = getenv("APPDATA");
   if ($2 == NULL or $3 == NULL)
     Jed_Local_Library = "";
   else
     Jed_Local_Library = path_concat(path_concat($2, path_basename($3)), 
                                     "Jedsoft\\JED\\lib");
#else
     Jed_Local_Library = "/usr/local/share/jed/lib";
#endif
}

if (file_status(Jed_Local_Library) != 2) % no directory
  Jed_Local_Library = "";

%!%+
%\variable{Jed_Home_Library}
%\synopsis{Directory for private non-standard slang scripts}
%\description
%  The directory for private jed-slang scripts. Defaults to 
%  "~/.jed/lib".
%  Set to "" if the specified directory does not exist.
%\seealso{Jed_Site_Library, Jed_Local_Library, Jed_Home_Directory}
%\seealso{set_jed_library_path, get_jed_library_path}
%!%-
#ifdef UNIX
custom_variable("Jed_Home_Library", expand_filename("~/.jed/lib/"));
#else
custom_variable("Jed_Home_Library", path_concat(Jed_Home_Directory, "lib"));
#endif
if (file_status(Jed_Home_Library) != 2) % no directory
  Jed_Home_Library = "";


%!%+
%\function{register_libdir}
%\synopsis{Register a library dir for use by jed}
%\usage{register_libdir(dir, [dir2, ...])}
%\description
%  * Prepend \var{lib} to the library path
%  * Set \var{Color_Scheme_Path}, \var{Jed_Doc_Files},
%    and \var{Jed_Highlight_Cache_Path}
%  * Evaluate (if existent) the file \var{ini.sl} in this library
%    to enable initialization (autoloads etc)
%\notes
%  This functions takes a variable number of arguments and processes them
%  in reversed order.    
%\example
%#v+
%  register_libdir(Jed_Home_Library, Jed_Local_Library, Jed_Site_Library);
%#v-
% will register Jed_Site_Library first and Jed_Home_Library last.
%\seealso{set_jed_library_path, Jed_Home_Library, Jed_Local_Library, Jed_Site_Library}
%!%-
define register_libdir() %(args)
{
   variable lib;
   loop (_NARGS)
     {
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
        path = path_concat(lib, "dfa");
        if (2 != file_status(path))
          path = lib;
        Jed_Highlight_Cache_Dir = path;
        Jed_Highlight_Cache_Path += "," + path;
#endif
        % Check for a file ini.sl containing initialization code
        % (e.g. autoload declarations) and evaluate it.
        path = path_concat(lib, "ini.sl");
        if (1 == file_status(path))
          () = evalfile(path);
     }
}

% --- "register" the libraries -------------------------------------------

% foreach ([Jed_Site_Library, Jed_Local_Library, Jed_Home_Library])
%   register_libdir(());


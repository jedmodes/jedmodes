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
%
% FEATURES
% 
%  * If a subdirectory .jed/ exists in Jed_Home_Directory,
%    change Jed_Home_Directory to point there
%    
%  * Initializes up to 3 extension libraries:
%      1. Jed_Site_Library  (default "JED_ROOT/site-lib")        
%      2. Jed_Local_Library (default "/usr/local/share/jed/lib")
%      3. Jed_Home_Library  (default "~/.jed/lib")
%    for
%      1. modes provided by the distribution (e.g. Debian GNU/Linux)
%      2. site-wide extensions by the local administrator
%      3. user extensions
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
% Write in your .jedrc (or jed.rc on winDOS)
%   require("home-lib", "/FULL_PATH_TO/home-lib.sl")
% or put home-lib.sl in JED_ROOT/lib and write in .jedrc 
%   require("home-lib")
% or rename to (or insert into) defaults.sl.
% On Debian, you can put it in /etc/jed-init.d for automatic evaluation
% 
% With the latter variants "jedrc" is found at following places (assuming UNIX)
%    ~/.jed/.jedrc
%    ~/.jedrc
%    ~/.jed/lib/jed.rc    (actually, Jed_Home_Library + "/jed.rc")
%    Jed_Site_Library + "/jed.rc"
%    JED_ROOT + "/lib/jed.rc"
% 
% CUSTOMIZATION
% 
% For other than the default paths use the environment variables 
% JED_HOME and JED_SITE_LIB or define Jed_Site_Library, and 
% Jed_Home_Library before evaluating home-lib.sl.
        
private variable path;

% --- Jed_Home_Directory ------------------------------------------

% Jed_Home_Directory is defined in site.sl, defaulting to $HOME
% If Jed_Home_Directory/.jed/ exists, point Jed_Home_Directory there,
path = path_concat(Jed_Home_Directory, ".jed");
if(2 == file_status(path))
  Jed_Home_Directory = path; 

% TODO: find out if this is really needed. Otherwise remove.
% % documentation on library functions can reside in
% % Jed_Home_Directory/doc/txt/libfuns.txt or
% % Jed_Home/lib/libfuns.txt (see later in this file)
% if(2 == file_status(Jed_Home_Directory)) % directory does exist
% {
%    path = expand_filename(Jed_Home_Directory+"/doc/txt/libfuns.txt");
%    if(1 == file_status(path))
%      Jed_Doc_Files = Jed_Doc_Files + "," + path;
% }

% backwards compatibility of jedrc-location 
% (if nonexistent, Jed_Home_Library+"/jed.rc" will be tried)
#ifdef UNIX
Default_Jedrc_Startup_File = "~/.jedrc";
#endif

% --- Jed_Site_Library and Jed_Home_Library  ------------------------

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
%  Jed_Home_Directory+"/lib".
%  Set to "" if the specified directory does not exist.
%\seealso{Jed_Site_Library, Jed_Local_Library, Jed_Home_Directory}
%\seealso{set_jed_library_path, get_jed_library_path}
%!%-
custom_variable("Jed_Home_Library", path_concat(Jed_Home_Directory, "lib"));
if (file_status(Jed_Home_Library) != 2) % no directory
  Jed_Home_Library = "";

%  * Prepend \var{lib} to the library path,
%  * evaluate (if existent) the file ini.sl in this library
%    to enable initialization (autoloads etc).
%  * set Color_Scheme_, dfa-cache- and documentation- path
define register_library(lib)
{
   !if (2 == file_status(lib)) % directory doesnot exist
     return;
     
   variable path;
   
   % jed library path
   set_jed_library_path(lib + "," + get_jed_library_path());
   % colors
   path = path_concat(lib, "colors");
   if (2 == file_status(path))
     Color_Scheme_Path = Color_Scheme_Path + "," + path;
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


% --- "register" the libraries -------------------------------------------

foreach ([Jed_Site_Library, Jed_Local_Library, Jed_Home_Library])
  register_library(());


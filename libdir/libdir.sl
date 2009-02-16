% libdir.sl: Support for library directories with jed extensions
%
% Copyright © 2005 Günter Milde and released under the terms
% of the GNU General Public License (version 2 or later).
%
% Versions
% --------
% 0.9   2005-09-19  first public version, based on home-lib.sl
% 0.9.1 2005-09-29  removed custom_variable stuff
% 0.9.2 2005-10-12  documentation fix
% 0.9.3 2005-11-03  evaluation of ini.sl now customizable with optional arg
% 0.9.4 2005-11-06  added provide() statement
% 0.9.5 2006-04-05  added year to copyright statement
% 0.9.6 2006-04-13  replaced continue with return
%                   and binary string ops with strcat
% 0.9.7 2006-05-17  added remove_libdir()
% 0.9.8 2007-10-18  add|append doc-file to doc_files list (report J. Sommer)
% 0.9.9 2008-05-05  libdir initialisation: load ini.slc, ini.sl or pass
%
% Features
% --------
% The functions add_libdir(path) and append_libdir(path) declare
% additional library directories:
%
%  * prepend|append `path' to the jed-library-path (searched for modes)
%  * set Color_Scheme_, dfa-cache- and documentation- path
%  * evaluate (if existent) the file ini.sl in path
%    (ini.sl files can be autocreated by make_ini.sl)
%
% Together with make_ini.sl, this provides a convenient way of extending
% jed with contributed or home-made scripts. ::

provide("libdir");

% Usage
% -----
% Write in your jed.rc file e.g. ::
%
%   () = evalfile("/FULL_PATH_TO/libdir");
%   %add_libdir("/usr/local/share/jed/lib"));
%   add_libdir(path_concat(Jed_Home_Directory, "lib"));

% Functions
% ---------

%!%+
%\function{add_libdir}
%\synopsis{Register a library dir for use by jed}
%\usage{add_libdir(lib, initialize=1)}
%\description
% Perform the following actions if the relevant paths are valid:
%  * Prepend \var{lib} to the library path and the \var{Jed_Highlight_Cache_Path}
%  * Add \var{lib}/colors to \var{Color_Scheme_Path} and
%    \var{lib}/libfuns.txt to \var{Jed_Doc_Files} or using \sfun{add_doc_file}.
%  * If \var{initialize} is TRUE, evaluate the file \var{lib}/ini.sl
%    to enable initialization (autoloads etc)
%\example
% The following lines in jed.rc
%#v+
%  () = evalfile("/FULL_PATH_TO/libdir.sl");
%  add_libdir("usr/local/jed/lib/", 0));  % do not initialize
%  add_libdir(path_concat(Jed_Home_Directory, "lib"));
%#v-
% will register the local and user-specific library-dir
%\notes
%  The function \sfun{make_ini} (from jedmodes.sf.net/mode/make_ini/)
%  can be used to auto-create an ini.sl file for a library dir.
%\seealso{append_libdir, set_jed_library_path}
%!%-
define add_libdir()
{
   variable lib, path, initialize;

   if (_NARGS == 2)
     initialize = ();
   else
     initialize = 1; % backwards compatibility
   lib = ();

   % abort, if directory doesnot exist
   if (orelse{lib == ""}{2 != file_status(lib)})
     return;

   % jed library path
   set_jed_library_path(strcat(lib, ",", get_jed_library_path()));
   % colors
   path = path_concat(lib, "colors");
   if (2 == file_status(path))
     Color_Scheme_Path = strcat(path, ",", Color_Scheme_Path);
   % documentation
   path = path_concat(lib, "libfuns.txt");
   if (1 == file_status(path))
     {
#ifexists Jed_Doc_Files
	Jed_Doc_Files = strcat(path, ",", Jed_Doc_Files);
#endif
#ifexists set_doc_files
	set_doc_files ([path, get_doc_files ()]);
	% add_doc_file(path);  % actually appends!!
#endif
     }
   % dfa cache
#ifdef HAS_DFA_SYNTAX
   % Jed_Highlight_Cache_Dir = lib;
   Jed_Highlight_Cache_Path = strcat(lib, ",", Jed_Highlight_Cache_Path);
#endif
   % Evaluate initialisation code
   if (initialize) {
      try {
	 () = evalfile(path_concat(lib, "ini"));
      }
      catch OpenError;
   }
}

%!%+
%\function{append_libdir}
%\synopsis{Register a library dir for use by jed}
%\usage{append_libdir(lib, initialize=1)}
%\description
%  This function is similar to \sfun{add_libdir} but appends the library
%  dir to the paths.
%\seealso{add_libdir, set_jed_library_path}
%!%-
define append_libdir()
{
   variable lib, path, initialize;

   if (_NARGS == 2)
     initialize = ();
   else
     initialize = 1; % backwards compatibility
   lib = ();

   % abort, if directory doesnot exist
   if (orelse{lib == ""}{2 != file_status(lib)})
     return;

   % jed library path
   set_jed_library_path(strcat(get_jed_library_path(), ",", lib));
   % colors
   path = path_concat(lib, "colors");
   if (2 == file_status(path))
     Color_Scheme_Path = strcat(Color_Scheme_Path, ",", path);
   % documentation
   path = path_concat(lib, "libfuns.txt");
   if (1 == file_status(path))
     {
#ifexists Jed_Doc_Files
	Jed_Doc_Files = strcat(Jed_Doc_Files, ",", path);
#endif
#ifexists add_doc_file
	add_doc_file(path); % actually appends
#endif
     }
   % dfa cache
#ifdef HAS_DFA_SYNTAX
   % Jed_Highlight_Cache_Dir = lib;
   Jed_Highlight_Cache_Path = strcat(Jed_Highlight_Cache_Path, ",", lib);
#endif
   % Evaluate initialisation code
   if (initialize) {
      try {
	 () = evalfile(path_concat(lib, "ini"));
      }
      catch AnyError;
   }
}

%!%+
%\function{remove_libdir}
%\synopsis{Remove a library dir from search paths}
%\usage{remove_libdir(lib)}
%\description
% Revert the actions of \sfun{add_libdir} or \sfun{append_libdir}.
%  * Remove \var{lib} from the jed library path and the \var{Jed_Highlight_Cache_Path}
%  * Remove \var{lib}/colors from \var{Color_Scheme_Path}
%  * Remove \var{lib}/libfuns.txt from \var{Jed_Doc_Files}.
%\notes
%  As it is impossibly to revert the evaluation of \var{lib}/ini.sl,
%  only add_libdir(dir, 0); or append_libdir(dir, 0)
%  can be fully reversed.
%\seealso{set_jed_library_path, add_libdir, append_libdir, str_replace_all}
%!%-
define remove_libdir(lib)
{
   variable path, dir;
   % jed library path
   dir =  strcat(",", lib, ",");
   path = strcat(",", get_jed_library_path(), ",");
   path = str_replace_all(path, dir, ",");
   set_jed_library_path(strtrim(path, ","));
   % colors
   dir =  strcat(",", path_concat(lib, "colors"), ",");
   path = strcat(",", Color_Scheme_Path, ",");
   path = str_replace_all(path, dir, ",");
   Color_Scheme_Path = strtrim(path, ",");
   % documentation
   dir =  strcat(",", path_concat(lib, "libfuns.txt"), ",");
   path = strcat(",", Jed_Doc_Files, ",");
   path = str_replace_all(path, dir, ",");
   Jed_Doc_Files = strtrim(path, ",");
   % dfa cache
#ifdef HAS_DFA_SYNTAX
   dir =  strcat(",", lib, ",");
   path = strcat(",", Jed_Highlight_Cache_Path, ",");
   path = str_replace_all(path, dir, ",");
   Jed_Highlight_Cache_Path = strtrim(path, ",");
#endif
}

% make_ini.sl: functions to set up extensions (modes and tools) for Jed.
%
% Copyright (c) 2003, 2006 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Usage
% =====
% 
% M-x make_ini   create a buffer with the autoload commands (and helpfull
%                comments) for viewing/editing and subsequent saving
% M-x update_ini update the ini.sl file in the current buffers working
%                dir without user interaction
%
% Versions
% ========
% 	     0.9 initial release
%            1.0 non-interactive functions and support for batch use
%            1.1 08/07/03 made compatible to txtutils 2.2 (change in get_word)
%            1.2 only write _autoload statements, do not add_completion
%            1.3 * make_ini_look_for_functions made public:
%                  add autoloads for specified file (request P. Boekholt)
%                * parse the files in a special buffer (avoiding mode-sets
%                  and problems with currently open files)
% 2004-03-08 2.0 * added support for documentation extraction with tm.sl
%                * make_ini no longer bytecompiles (use update_ini for that)
% 2004-06-10 2.1 * fixed a bug that prevented bytecompiling
%                * added tm documentation for public functions and variables
%                * provisions for a section with custom code in ini.sl
% 2004-11-26 2.2 * code cleanup (hopefully without introducing bugs)
% 	         * look for a <INITIALIZATION> </INITIALIZATION> block
% 	           Use this for custom initialization code (menu addings, etc)
% 	           If such a block is found, no search for functions is done!
% 2005-03-18 2.3 * bugfixes: list_slang_files() did only work, if 
%                            dir == current working dir (report Dino Sangoi)
%                            "%" in vinsert needs to be doubled (Dino Sangoi)
%                            documentation comments did not work
%                  removed the need for a chdir() alltogether
% 2005-03-31 2.4 * windows bugfix: quote backslashes in add_autoload_fun() (Dino)
% 	         * bugfix in list_slang_files(): skip jed lock files
% 2005-04-01 2.5 * cleanup in make_ini_look_for_functions(): do not insert
% 	     	   library path in autoload commands
% 2005-04-07 2.6 * provide add_completion commands (with Make_ini_Add_Completions)
% 2005-04-25 2.7 * bugfix: list_slang_files() failed for directories without 
% 	     	   	   slang files or nonexisting directories.
% 	     	   	   make_libfun_doc() failed if there was no documentation
%                * Test for existing tm.sl with #ifexists:
%                  the function tm_parse() must be defined/declared at 
%                  evaluation/preparse time of make_ini.sl in order to enable 
%                  the documentation extract feature.
% 2005-05-25 2.7.1 * bugfix: andelse -> orelse (report Paul Boekholt)
% 2005-07-04 2.8   * separated function byte_compile_library()
% 2005-07-04 2.8.1 * renamed byte_compile_library() to byte_compile_libdir
% 2005-07-11 2.8.2 * bugfix in make_ini_look_for_functions(), strip trailing
% 	     	     slash from libdir name.
% 2005-07-15 2.8.3 * critical bugfix-fix: make_ini_look_for_functions(): use
% 	     	     path_concat(dir, "") to normalize the dir-path.
% 2005-07-22 2.9   * adapted to home-lib 1.1 
% 	     	     (removed reference to Jed_Home_Library and Jed_Site_Library)
% 2005-07-30 2.9.1 bugfix in update_ini()
% 2005-11-02 2.9.2 * adapted to libdir 0.9.1 (removed update_site_lib())
%                  * new custom variable Make_ini_Bytecompile_Exclusion_List
% 2005-11-14 2.9.3 * added missing autoload for buffer_dirname()
% 2005-11-18 2.9.4 * removed the if(BATCH) clause as it does not work as expected
%                    and prevents the use from another script with jed-script
% 2005-11-22 2.9.5 * code cleanup
% 2006-01-10 2.9.6 * documentation cleanup
% 2006-03-15 2.10  * tighten the rules for <INITIALIZATION> block: now it must
%                    be a preprocessor cmd ("#<INITIALIZATION>" at bol)
% 2006-05-31 2.11  * added missing break in make_ini_look_for_functions()
%                  * missing end tag of INITIALIZATION block triggers error
%                  * update_ini(): evaluate new ini.sl (test, add autoloads)
% 2007-10-01 2.11.1 * optional extensions with #if ( )
% 2007-10-23 2.12   * documentation update
% 	     	    * create DFA cache files
%                   

% TODO:  * Consider preprocessor options (How?)


autoload("get_word", "txtutils");
autoload("push_array", "sl_utils");
autoload("buffer_dirname", "bufutils");

provide("make_ini");

% Customisation
% =============

%!%+
%\variable{Make_ini_Scope}
%\synopsis{Scope for automatic generation of autoload commands}
%\usage{Int_Type Make_ini_Scope = 1}
%\description
%  Set the scope for automatic generation of \sfun{autoload} commands
%   0 no autoloads
%   1 only explicitly public definitions: bol_fsearch("public define ")
%   2 all global definitions
%\seealso{make_ini, make_ini_look_for_functions}
%!%-
custom_variable("Make_ini_Scope", 1);

%!%+
%\variable{Make_ini_Verbose}
%\synopsis{Comment the ini-file}
%\usage{Int_Type Make_ini_Verbose = 1}
%\description
% Comment the ini.sl file generated by make_ini().
%  n == 0: no comments
%  n >  0: n lines of global comments + list of custom variables
%\seealso{make_ini}
%!%-
custom_variable("Make_ini_Verbose", 0);

%!%+
%\variable{Make_ini_Bytecompile}
%\synopsis{Bytecompile the files with update_ini()}
%\usage{Int_Type Make_ini_Bytecompile = 1}
%\description
% Let \sfun{update_ini} and \sfun{update_home_lib} bytecompile 
% the files as well.
% This gives considerable evalutation speedup but might introduce problems.
%\notes 
%  Attention: byte-compiling can give problems
%     * with constructs like #ifdef XWINDOWS
%     	when xjed and jed are used in parallel
%     * with constructs like
%       #ifndefined my_new_function()
%       define my_new_function()
%       {  ... }
%       #endif
%\seealso{update_ini, update_home_lib}
%!%-
custom_variable("Make_ini_Bytecompile", 1);

%!%+
%\variable{Make_ini_Exclusion_List}
%\synopsis{Array of files to exclude from make_ini()}
%\usage{String_Type[] Make_ini_Exclusion_List = ["ini.sl"]}
%\description
% Exclusion list: do not scan these files.
%\seealso{make_ini, update_ini, Make_ini_Bytecompile_Exclusion_List}
%!%-
custom_variable("Make_ini_Exclusion_List", ["ini.sl"]);

%!%+
%\variable{Make_ini_Bytecompile_Exclusion_List}
%\synopsis{Array of files to exclude from bytecompiling}
%\usage{Int_Type Make_ini_Bytecompile_Exclusion_List = []}
%\description
% Exlude these files from bytecompiling with \sfun{byte_compile_libdir},
% \sfun{update_ini}, and \sfun{update_home_lib}.
%\seealso{Make_ini_Exclusion_List}
%!%-
custom_variable("Make_ini_Bytecompile_Exclusion_List", String_Type[0]);

%!%+
%\variable{Make_ini_DFA_Exclusion_List}
%\synopsis{Array of files to exclude from DFA caching}
%\usage{Int_Type Make_ini_DFA_Exclusion_List = []}
%\description
% Exlude these files from DFA highlight cache creation with 
% \sfun{update_dfa_cache_files}, \sfun{ \sfun{update_ini},
% and \sfun{update_home_lib}.
%\seealso{Make_ini_Exclusion_List}
%!%-
custom_variable("Make_ini_DFA_Exclusion_List", String_Type[0]);

%!%+
%\variable{Make_ini_Extract_Documentation}
%\synopsis{Extract documentation with update_ini}
%\usage{Int_Type Make_ini_Extract_Documentation = 1}
%\description
% Let update_ini() also extract documentation and save in libfuns.txt file.
%\notes 
% Documentation extraction requires tm_parse() from the tm.sl mode.
% If tm_parse() is not defined at evaluation (or byt-compile) time of
% make_ini.sl, Make_ini_Extract_Documentation will be set to 0.
%\seealso{update_ini, tm_parse, tm_view}
%!%-
custom_variable("Make_ini_Extract_Documentation", 1);

!if (is_defined("tm_parse"))
  Make_ini_Extract_Documentation = 0;

%!%+
%\variable{Make_ini_Add_Completions}
%\synopsis{Insert add_completion commands into ini.sl}
%\usage{Int_Type Make_ini_Add_Completions = 1}
%\description
%  Should \sfun{make_ini} insert \sfun{add_completion} commands into ini.sl?
%   0 no
%   1 only explicitly public definitions
%   2 all global definitions
%\seealso{Make_ini_Scope, Make_ini_Extract_Documentation, Make_ini_Verbose}
%!%-
custom_variable("Make_ini_Add_Completions", 1);

% Internal Variables
% ==================

% valid chars in function and variable definitions
static variable Slang_word = "A-Za-z0-9_";

static variable Ini_File = "ini.sl";
private variable Parsing_Buffer = "*make_ini tmp*";
static variable Tm_Doc_File = "libfuns.txt";

% Functions
% =========

static define _get_function_name()
{
   variable str, fun;
   !if (ffind("define"))
     return "";
   skip_word();
   return get_word(Slang_word, 1);  % (Slang_word, skip=True)
}

%!%+
%\function{make_ini_look_for_functions}
%\synopsis{Insert initialisation code for a slang file}
%\usage{Str = make_ini_look_for_functions(file)}
%\description
%  Browse file and insert 
%    either the #<INITIALIZATION> #</INITIALIZATION> block 
%    or autoload commands for function definitions
%  in the current buffer.  The variables \var{Make_ini_Scope} and
%  \var{Make_ini_Add_Completions} can be used to control which function
%  definitions are handled
%\notes
%  If there is an INITIALIZATION block, no automatic search for function
%  definitions is done. You must explicitely list the required autoload()
%  commands! (This way, people not using make_ini can copy the content of the
%  INITIALIZATION block directly to their .jedrc file.
%  
%  The preprocessor directives
%#v+
%  #<INITIALIZATION>
%     ... initialisation block ...
%  #</INITIALIZATION>
%#v-
%  will hide the initialisation block from normal slang processing/preparsing
%  (see slang documentation file "preprocess.txt").
%\seealso{make_ini, update_ini, Make_ini_Scope,}
%!%-
define make_ini_look_for_functions(file)
{
   variable str = "", public_funs = "",
     simple_funs = "", funs, funs_n_files,
     named_namespace = 0,
     currbuf = whatbuf();

   % show("processing", whatbuf(), file);

   % Parse the file in a temp buffer, without setting the mode
   % (saves time and does not interfere with open files)
   sw2buf(Parsing_Buffer);
   erase_buffer(); % paranoia
   () = insert_file(file);
   set_buffer_modified_flag(0);
   
   % if `file' is in the jed library path, remove the library-path from it:
   variable dir, libdirs = strchop(get_jed_library_path, ',' , 0);
   libdirs = libdirs[where(libdirs != ".")]; % filter the current dir
   foreach dir (libdirs)
     {
	dir = path_concat(dir, "");  % ensure trailing path-separator
	if (is_substr(file, dir) == 1)
          {
             file = file[[strlen(dir):]];
             break;
          }
        
     }

   % global comment
   bob();
   loop(Make_ini_Verbose)  % max as many lines as Make_ini_Verbose indicates
     {
	!if (looking_at("%"))
	  break;
	push_mark();
	go_down_1();
	str += bufsubstr();
     }
   % list custom variables (assuming the definition starts at bol)
   if (Make_ini_Verbose)
     while (bol_fsearch("custom_variable"))
       {
	  push_mark_eol();
	  str += "% " + bufsubstr() + "\n";
       }
   % find out if the mode defines/uses a namespace
   bob();
   if (orelse{bol_fsearch("implements")}  
        {bol_fsearch("_implements")} 
        {bol_fsearch("use_namespace")})
     {
	named_namespace = 1;
        str += "% private namespace: " + line_as_string + "\n";
     }

   % Look for an #<INITIALIZATION> block
   bob();
   if (bol_fsearch("#<INITIALIZATION>"))
     {
	go_down_1(); bol();
	push_mark();
	!if (bol_fsearch("#</INITIALIZATION>"))
	  {
	     pop_mark(0);
	     error("no </INITIALIZATION> end tag in " + file);
	  }
        str += bufsubstr();
     }
   else 
     {
	% Search function definitions
	% 1. explicitly public definitions
        while (bol_fsearch("public define "))
          public_funs += _get_function_name() + "\n";
        
	bob;
	% 2. "simple" (i.e. unspecified) definitions
        !if (named_namespace)
          while (bol_fsearch("define "))
            simple_funs += _get_function_name() + "\n";
        
        % autoloads
	switch (Make_ini_Scope)
          { case 0: funs = String_Type[0]; }
          { case 1: funs = strtok(public_funs, "\n"); }
          { case 2: funs = strtok(public_funs+simple_funs, "\n"); }
        
	if (length(funs))
	  {
	     funs = "\"" + funs + "\"";
	     funs_n_files = 
               funs + sprintf(", \"%s\";", str_quote_string(file, "", '\\'));
	     str += strjoin(funs_n_files, "\n") + "\n"
	          + sprintf("_autoload(%d);\n", length(funs));
	  }
        
        % add_completions
	switch (Make_ini_Add_Completions)
          { case 0: funs = String_Type[0]; }
          { case 1: funs = strtok(public_funs, "\n"); }
          { case 2: funs = strtok(public_funs+simple_funs, "\n"); }
        
	if (length(funs))
	  {
	     funs = "\"" + funs + "\";";
	     str += "\n" + strjoin(funs, "\n") + "\n"
		 + sprintf("_add_completion(%d);\n", length(funs));
          }
        
     }
   % cleanup
   delbuf(Parsing_Buffer);
   sw2buf(currbuf);
   insert(str);
}

% Return sorted array of full path names of all *.sl files in dir
static define list_slang_files(dir)
{
   variable files = listdir(dir);
   if (files == NULL or length(files) == 0)
     return String_Type[0];
   % Skip files that are  no slang-source (test for extension ".sl")
   files = files[where(array_map(String_Type, &path_extname, files) == ".sl")];
   !if (length(files))
     return String_Type[0];
   % Skip jed lock files
   files = files[where(array_map(Integer_Type, &is_substr, files, ".#") != 1)];
   !if (length(files))
     return String_Type[0];
   % Prepend the directory to the path
   files = array_map(String_Type, &path_concat, dir, files);
   % Sort alphabetically and return
   return files[array_sort(files)];
}

%!%+
%\function{make_ini}
%\synopsis{}
%\usage{make_ini([dir])}
%\description
%   Scan all slang files in \var{dir} for function definitions and
%   place autoload commands in a buffer ini.sl.
%   After customizing, it can be saved and serve as an initialization
%   for a slang-library. The libdir mode at jedmodes.sf.net will
%   automatically evaluate this ini.sl files at startup, making the 
%   installation of additional modes easy.
%\seealso{update_ini, Make_ini_Scope, Make_ini_Exclusion_List, Make_ini_Verbose}
%!%-
public define make_ini() % ([dir])
{
   % optional argument
   !if (_NARGS)
     read_file_from_mini("Make ini.sl for:");
   variable dir = ();

   variable files = list_slang_files(dir), file;
   
   % find old ini file 
   () = find_file(path_concat(dir, Ini_File));
   slang_mode();
   bob();
   % skip customized part, write header
   !if (bol_fsearch("% [code below will be replaced"))
     vinsert("%% ini.sl: initialization file for the library dir %s\n"
	+ "%% automatically generated by make_ini()\n\n"
	+ "%% --- Place customized code above this line ---\n"
	+ "%% [code below will be replaced by the next run of make_ini()]\n"
	, dir);
   % blank rest of buffer
   go_down_1; bol();
   push_mark_eob();
   del_region();
   
   foreach file (files)
     {
	% show(file, file_type(file), file_status(file));
        % Skip files from the exclusion list
        if (length(where(path_basename(file) == Make_ini_Exclusion_List)))
             continue;
	insert("\n% " + path_basename(file) + "\n");
	make_ini_look_for_functions(file);
     }
}

%!%+
%\function{byte_compile_libdir}
%\synopsis{Byte compile all *.sl files in a directory}
%\usage{ byte_compile_libdir(dir)}
%\description
%  Call \sfun{byte_compile_file} on all files returned by 
%  \sfun{list_slang_files}(dir).
%\seealso{byte_compile_file, update_home_lib, Make_ini_Bytecompile_Exclusion_List}
%!%-
define byte_compile_libdir(dir)
{
   variable file, files = list_slang_files(dir);
   foreach file (files)
     {
        % Skip files from the exclusion list
        if (length(where(path_basename(file) 
           == Make_ini_Bytecompile_Exclusion_List)))
          continue;
        byte_compile_file(file, 0);
     }
}

% Online Documentation
% ====================

#ifexists tm_parse
%!%+
%\function{make_libfun_doc}
%\synopsis{Write tm documentation in dir to "libfuns.txt"}
%\usage{ make_libfun_doc([dir])}
%\description
%  Extract tm documentation for all Slang files in \var{dir}, 
%  convert to ascii format and write to file "libfuns.txt".
%\notes
%  requires tm.sl (jedmodes.sf.net/mode/tm/) 
%\seealso{update_ini, Make_ini_Extract_Documentation}
%!%-
public define make_libfun_doc() % ([dir])
{
   !if (_NARGS)
     read_file_from_mini("Extract tm Documentation from dir:");
   variable dir = ();
   
   % extract tm documentation blocks
   variable docstrings, str, files=list_slang_files(dir);
   !if (length(files))
     return vmessage("no slang files in %s", dir);
   docstrings = array_map(String_Type, &tm_parse, files);
   str = strjoin(docstrings, "");
   if (str == "")
     return vmessage("no tm documentation in %s", dir);
   
   () = write_string_to_file(str, path_concat(dir, Tm_Doc_File));
}
#endif

% DFA syntax highlight cache files
% ================================

#ifdef HAS_DFA_SYNTAX

% create a DFA cache file for `file` 
% 
% The cache file is removed from Jed_Highlight_Cache_Dir and re-created
% if no matching cache file is found in the Jed_Highlight_Cache_Path
%\seealso{update_dfa_cache_files} 
define make_dfa_cache_file(file)
{
   variable buf = whatbuf();
   sw2buf(Parsing_Buffer);
   EXIT_BLOCK
     {
   	set_buffer_modified_flag(0);
    	delbuf(Parsing_Buffer);
   	sw2buf(buf);
     }
   
   % load relevant part of a file into parsing buffer
   erase_buffer(); % paranoia
   if (0 >= insert_file_region(file, 
      "%%% DFA_CACHE_BEGIN %%%",
      "%%% DFA_CACHE_END %%%"))
     {
	% show(file," not found or no '%%% DFA_CACHE' section"); 
	return;
     }
   
   % Remove and re-create the cache file
   bob ();
   !if (re_fsearch ("[ \t]*dfa_enable_highlight_cache[ \t]*([ \t]*\"\\(.+\\)\""))
     {
	% vshow("did not find DFA cache file in %s", file);
	return;
     }
   variable cache_file = dircat(Jed_Highlight_Cache_Dir, regexp_nth_match(1));
   % show("Cache file", cache_file);
   if (file_status(cache_file) == 1)
	() = remove(cache_file);
   
   % Check whether dfa cache is enabled and get the name of the dfa table
   eob ();
   !if (re_bsearch ("[ \t]*dfa_set_init_callback[ \t]*([ \t]*&[ \t]*\\([^,]+\\),[ \t]*\\(.+\\))"))
     {
	% show("no matching callback set in ", file); 
	return;
     }
   variable line = regexp_nth_match(0);
   variable fun = regexp_nth_match (1);
   variable mode = regexp_nth_match (2);
   if (mode == strtrim(mode, "\""))
     {
	vmessage("%s: dfa caching needs string-literal in %s", 
	   path_basename(file), line);
	return;
     }
   
   % Replace the setting of the callback function with a call to it:
   delete_line();
   vinsert("create_syntax_table(%s);\n", mode);
   vinsert("%s(%s);", fun, mode);
   
   % (Re)-create the cache file
   if (file_status(cache_file) == 1)
	() = remove(cache_file);
   evalbuffer ();
}

% Remove *.dfa files in `dir' and re-create them.

define update_dfa_cache_files() % ([dir])
{
   % optional argument
   !if (_NARGS)
     read_file_from_mini("Make|Update DFA cache files in:");
   variable dir = ();
   variable file, files = list_slang_files(dir);

   % Restrict updating to `dir'
   variable cache_dir = Jed_Highlight_Cache_Dir;
   variable cache_path = Jed_Highlight_Cache_Path;
   Jed_Highlight_Cache_Dir = dir;
   Jed_Highlight_Cache_Path = dir;
   
   foreach file (files)
     {
        % Skip files from the exclusion list
        if (length(where(path_basename(file) == Make_ini_DFA_Exclusion_List)))
          continue;
        make_dfa_cache_file(file);
     }
   % restore settings
   Jed_Highlight_Cache_Dir = cache_dir;
   Jed_Highlight_Cache_Path = cache_path;
}
#endif

% Update initialization files
% ===========================

% Front-end functions for ini.sl generation, byte-compiling,
% and  documentation extraction
% 
% DFA cache generation is left out, as it ist susceptible to faults
% Use update_dfa_cache_files([dir]) if you think it is sure.

%!%+
%\function{update_ini}
%\synopsis{Update the ini.sl initialization file}
%\usage{update_ini(directory=buffer_dir())}
%\description
%  Create or update the ini.sl initialization file with \sfun{make_ini}.
%  Bytecompile the files with \sfun{byte_compile_libdir}.
%  Extract online help text (tm documentation) with \sfun{make_libfun_doc}.
%  
%  Customise behaviour with the the Make_ini_* custom variables
%  (hint: try Help>Apropos Make_ini).
%\seealso{update_home_lib}
%!%-
public define update_ini() % (directory=buffer_dirname())
{
   variable dir, buf = whatbuf();
   if (_NARGS)
     dir = ();
   else
     dir = buffer_dirname(); % default

   !if (length(list_slang_files(dir)))
     return vmessage("no SLang files in %s", dir);
   make_ini(dir);
   save_buffer();
   % evaluate to test and add new autoloads
   evalbuffer();
   delbuf(whatbuf());
   % bytecompile (the ini-file as well)
   if(Make_ini_Bytecompile)
     {
	flush("byte compiling files in " + dir);
        byte_compile_libdir(dir);
	byte_compile_file(path_concat(dir, Ini_File), 0);
     }
#ifexists tm_parse
   % extract the documentation and put in file libfuns.txt
   if(Make_ini_Extract_Documentation)
     {
	flush("extracting on-line documentation in " + dir);
	make_libfun_doc(dir);
     }
#endif
   sw2buf(buf);
   % message("update_ini completed");
}

#ifexists Jed_Home_Directory
%!%+
%\function{update_home_lib}
%\synopsis{update Jed_Home_Directory/lib/ini.sl}
%\usage{update_home_lib()}
%\description
%   Run \sfun{update_ini} for the users "Jed library dir"
%\seealso{update_ini, make_ini, Jed_Home_Directory}
%!%-
public define update_home_lib()
{
   update_ini(path_concat(Jed_Home_Directory, "lib"));
   message("done");
}
#endif

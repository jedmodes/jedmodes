% A tool to set up extensions (modes and tools)for jed.
%
% Creates a file ini.sl that declares all (public) functions
% in the current directory. Also bytecompiles the files, if set to do so.
%
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% USAGE:
%    M-x make_ini   to get a buffer with the autoload commands (and helpfull
%                   comments) for viewing/editing and subsequent saving
%    M-x update_ini to update the ini.sl file in the current buffers working
%                   dir without user interaction
%
%    jed -batch -l make_ini.sl   to update the ini.sl file in the current
%                                directory in a batch process
%                                (using update_ini)
%
%    Load the ini.sl file, e.g. with require("ini.sl") in your .jedrc
%    (The home-lib mode at jedmodes.sf.net does this automatically)
%
% TODO:  * Consider preprocessor options (How?)
% 	 * Make online documentation out of tm-commented sources
%
% Versions: 0.9  initial release     Guenter Milde <g.milde@web.de>
%           1.0  non-interactive functions and support for batch use
%           1.1  08/07/03 made compatible to txtutils 2.2 (change in get_word)
%           1.2  only write _autoload statements, do not add_completion
%           1.3  * make_ini_look_for_functions made public:
%                  add autoloads for specified file (request P. Boekholt)
%                * parse the files in a special buffer (avoiding mode-sets
%                  and problems with currently open files)
%           1.4  added proper tm-documentation for public functions

% Debug info (comment out when tested)
_debug_info=1;

autoload("get_word", "txtutils.sl");

% --- Settings -----------------------------------------------------------

%!%+
%\variable{Make_ini_Scope}
%\usage{variable Make_ini_Scope = Integer_Type}
%\description
%  Set the scope of autodeclarations that make/update_ini should
%  produce for ini.sl
%    0 no declarations
%    1 only explicitly public definitions
%    2 public definitions and (if no namespace is declared) 
%      simple definitions
%  Default value is 1    
%\seealso{make_ini, update_ini, Make_ini_Verbose, Make_ini_Bytecompile}
%!%-
custom_variable("Make_ini_Scope", 1);

%!%+
%\variable{Make_ini_Verbose}
%\usage{variable Make_ini_Verbose = Integer_Type}
%\description
%  How verbosely should make/update-ini comment the ini-file
%    0 no comments,
%    1 global comments + list of custom variables,
%    2 one line/function,
%    3 full comments
%  Default value is 2  
%\seealso{make_ini, update_ini, Make_ini_Scope, Make_ini_Bytecompile}
%!%-
custom_variable("Make_ini_Verbose" ,2);

%!%+
%\variable{Make_ini_Bytecompile}
%\usage{variable Make_ini_Bytecompile = Integer_Type}
%\description
%  Should make/update-ini bytecompile the *.sl files as well?
%    0 no
%    1 yes
%  Default value is 1
%\notes
%  Attention: can give problems with preprocessor constructs like 
%  #ifdef XWINDOWS
%  when xjed and jed in xterm or on the konsole are used in parallel.
  
%\seealso{make_ini, update_ini, Make_ini_Exclusion_List}
%!%-
custom_variable("Make_ini_Bytecompile", 1);

%!%+
%\variable{Make_ini_Exclusion_List}
%\usage{variable Make_ini_Exclusion_List = Array_Type[String_Type]}
%\description
%  Which files should be excluded from scanning with make/update_ini?
%  Default value is ["ini.sl"].
%\notes
%  Excluded files are also not bytecompiled.
%\seealso{make_ini, update_ini, Make_ini_Scope}
%!%-
custom_variable("Make_ini_Exclusion_List", ["ini.sl"]);

% valid chars in function and variable definitions
static variable Slang_word = "A-Za-z0-9_";
static variable ini_file = "ini.sl";
static variable Parsing_Buffer = "*make_ini tmp*";

% --- functions ---------------------------------------------------

static define add_autoload(mode)
{
   variable fun = get_word(Slang_word, 1);
   variable str = sprintf("\"%s\", \"%s\";\n", fun, mode);
   return str;
}

% Insert autoload commands for function definitions in "file"
define make_ini_look_for_functions(file)
{
   variable str = "",
     funs = "", no_of_funs,
     named_namespace = 0,
     currbuf = whatbuf();

   % show("processing", whatbuf(), file);

   sw2buf(Parsing_Buffer);
   erase_buffer(); % paranioa
   () = insert_file(file);
   set_buffer_modified_flag(0);

   % global comment
   if (Make_ini_Verbose)
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
   bob;
   % find out if the mode defines/uses a namespace
   if (andelse{bol_fsearch("implements")}
	{bol_fsearch("use_namespace")}
      )
     {
	named_namespace = 1;
        str += "% private namespace: " + line_as_string + "\n";
	bob;
     }
   % Search function definitions
   % 1. explicitly public definitions
   if (Make_ini_Scope)
     {
	while (bol_fsearch("public define "))
	  {
	     skip_word; skip_word;
	     funs += add_autoload(file);
	  }
	bob;
     }
   % 2. "normal" (i.e. unspecified) definitions
   if (Make_ini_Scope - named_namespace > 1)
     {
	while (bol_fsearch("define "))
	  {
	     skip_word;
	     funs += add_autoload(file);
	  }
     }
   no_of_funs = length(strchop(funs, '\n', 0)) - 1; % (last element is empty)

   if (no_of_funs)
     {
	str += funs + sprintf("_autoload(%d);\n", no_of_funs);
     }

   delbuf(Parsing_Buffer);
   sw2buf(currbuf);
   insert(str);
}

%!%+
%\function{make_ini}
%\synopsis{Create initialization data for a jed library directory}
%\usage{ make_ini(directory=Ask)}
%\description
%   Get a buffer with autoload commands (and helpfull comments) for a
%   jed library. Also bytecompiles the files, if set to do so.
%
%   Searches all files in dir, defined functions are written a buffer.
%   This way you can inspect and finetune by hand before saving.
%   Use update_ini for non-interactive creation/update of the ini.sl file
%\notes
%   make_ini works on the saved versions only.
%\seealso{update_ini, Make_ini_Scope, Make_ini_Bytecompile, Make_ini_Verbose, Make_ini_Exclusion_List}
%!%-
public define make_ini() % (directory= Ask)
{
   % get optional argument
   variable dir;
   if (_NARGS)
     dir = ();
   else
     {
	(, dir, , ) = getbuf_info (); % default
	dir = read_file_from_mini("Make ini.sl for:");
     }

   variable files, file="", is_open;
   () = chdir(dir);

   % get and sort files
   files = listdir(dir);
   files = files[array_sort(files)];

   sw2buf(ini_file);
   erase_buffer;
   slang_mode();
   insert("% ini.sl initialization file for the library dir " + dir + "\n" +
	  "% automatically generated by make_ini([dir])\n\n");

   foreach (files)
     {
	file = ();
	% show(file, file_type(file), file_status(file));
	% Skip files that are  no slang-source or unaccessible
	if ( orelse {file_type(file) != "sl"} {file_status(file) != 1})
	  continue;
	% Skip files from the exclusion list
	if (length(where(Make_ini_Exclusion_List == file)))
	  continue;
	insert("\n% " + file + "\n");
	make_ini_look_for_functions(file);
	if(Make_ini_Bytecompile)
	     byte_compile_file (file, 0);
     }
}

%!%+
%\function{update_ini}
%\synopsis{Create initialization file for a jed library directory}
%\usage{update_ini(dir= buffer_dirname)}
%\description
%   Create/update the ini.sl initialization file with autoload commands
%   (and helpfull comments) for a jed library.
%   Also bytecompiles the files, if set to do so.
%\seealso{make_ini, Make_ini_Scope, Make_ini_Bytecompile, Make_ini_Verbose, Make_ini_Exclusion_List}
%!%-
public define update_ini() % (dir= buffer_dirname)
{

   variable file, dir, name, flags;
   if (_NARGS)
     dir = ();
   else
	(, dir, , ) = getbuf_info (); % default

   make_ini(dir);
   ()= write_buffer(whatbuf);
   delbuf(whatbuf);
   % now bytecompile the ini-file as well
   if(Make_ini_Bytecompile)
     byte_compile_file (ini_file, 0);
   vmessage("ini.sl file for %s updated", dir);
}

% run update_ini, if called as a batch process
if (BATCH)
  update_ini;

#ifexists Jed_Home_Library
public define update_home_lib()
{
   update_ini(Jed_Home_Library);
}
#endif

#ifexists Jed_Site_Library
public define update_site_lib()
{
   update_ini(Jed_Site_Library);
}
#endif


% apsmode -*- mode: slang; mode: fold; -*-

% apsmode
% Copyright (c) 2003 Thomas Koeckritz (tkoeckritz@gmx.de)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% ChangeLog
% ---------
% 0.1   2003-07-01 started as "lunch-hour" project
%                  quick and dirty printing via hardcoded a2ps-command
% 0.2   2003-07-31 most a2ps options included
% 0.3   2003-08-12 QuickPrint added
% 0.4   2003-08-27 a2ps style-sheet support added
% 1.0   2003-09-18 Initial (stable) version
% 1.1   2004-01-05 JEDFILENAME, JEDDATETIME added, minor modifications
% 1.2   2004-02-20 apsmode.hlp written
% 1.3   2004-03-09 region stays highlighted after preview/printing
%                  internal documentation enhanced
% 1.4   2004-03-22 printer.conf renamed to apsconf.sl
%                  all user-definable variables moved to apsconf.sl
%                  add variable to choose menu-support (aps_menu)
%                  add variable to choose deletion of ps-file (aps_del_ps_file)
%                  handling of options for WINDOWS corrected/improved
% 1.5   2005-04-14 added handling of font size
%                  added saving of current parameters in apsconf format
% 1.5.1 2005-11-21 modified apsconf.sl: GM: use path_concat() for aps_tmp_dir
% 1.5.2 2006-06-01 made user-definable variables custom_variables (G Milde)
%
%
% Description
% -----------
% JED-mode to support printing from jed using a2ps and ghostview.
% This mode has been designed for and successfully tested
% under
%  - UNIX (SunOS 5.8)
%  - WINDOWS (Windows NT 4.0, Windows 2000, Windows ME)
% see also ./apsconf/aps.hlp
%
% Features
% --------
% - creation of a postscript file of the current buffer or marked region
% - preview/printing of the created postscript file
% - printing with syntax highlighting (acc. to JED mode and/or a2ps style
%   sheets)
% - print preview mode (with ghostview)
% - supports printing of several pages on one sheet, borders,
%   title, footer definitions...
% - new menu entries for printing
% - printer definitions in a separate configuration file (apsconf.sl)
%   covering most of a2ps layout features
% - QuickPrint: modification of a printer setting for the open jed session
%   allows quick (small) changes of a defined printer setting,
%   changes will not be saved!
% - basic support for creation of a2ps style sheets from JED modes
%   (scans xyz-mode.sl for keywords)
%
% Requirements
% ------------
% jed 0.99.16
% a2ps installed and running on your OS
% - UNIX      : a2ps v4.12  (tested)
% - MSWINDOWS : a2ps v4.13b (tested)
% see http://www.inf.enst.fr/~demaille/a2ps or
%     http://www.gnu.org/software/a2ps/ or
%     http://sourceforge.net/project/showfiles.php?group_id=23617
%     a2ps-4.13b-bin.zip (for windows version)
%
% ghostview for viewing installed on your OS
% - UNIX      : gv v3.0.4  (tested)
% - MSWINDOWS : GSview 4.4 (tested)
% see http://www.cs.wisc.edu/~ghost
%
% popup menues enabled within your jed
%
% Modifications to do for installation
% ------------------------------------
% os.sl:      Uncomment the following line to enable text menus in WINGUI
%             %. "menus" evalfile pop
% default.sl: add the following line
%             () = evalfile("apsmode");
% apsconf.sl: edit the file for your personal a2ps/printer settings
%             (see there for details)
%
% Implemented Functions (main functions)
% --------------------------------------
% The functions of apsmode are designed to be executable from menu entries.
% Nevertheless the main print functions can also be used from jed commandline
% and/or your personal keybindings.
% - print_buffer()
% - print_region()
% - print_buffer_preview()
% - print_region_preview()
% - show_print_log()
% - aps_help()
% Functions to define special print settings (QuickPrint) are only accessible
% via the menu.
%
% Notes
% -----
% - if no postscript printer is installed on your system use ghostview
%   for printing
% - error handling under WINDOWS is not working properly,
%   if something strange happened during printing, look at the
%   print-log buffer (via function show_print_log() )
%
% Global Variables
% ----------------
% for description see below in the coding
%   JEDFILENAME
%   JEDDATETIME
%   a2ps_cmd
%   a2ps_sheet_dir
%   aps_config_file
%   aps_creation_date
%   aps_creator
%   aps-del_ps_file
%   aps_help_file
%   aps_jed_tested
%   aps_menu
%   aps_pid
%   aps_preview
%   aps_tmp_dir
%   aps_tmp_file
%   aps_version
%   default_printer
%   max_no_printers
%   printer
%   use_jed_a2ps_style_sheet
%
% ToDo
% ----
% no ideas left for now
%
% Known Bugs
% ----------
% For creating an a2ps style sheet, the exact mode name as defined for the
% syntax table has to be given.
% Look for lines like
%         $1 = "TCL";
%         create_syntax_table ($1);
% in the <mode>.sl file to catch the real mode name.
% If the wrong name will be given function create_a2ps_style_sheet(mode)
% will crash.
% There seems to be no slang function to test, whether a mode exists.
%
% Windows version (14.3b) of a2ps seems to have some bugs:
% - line truncating works opposite to UNIX version
% - If a header string is defined, then automatically date, filename, pagecount
%   will be inserted in title and footer, if the strings for that are empty.
%   To prevent printing the same information twice, define strings for
%   title and footer as " " instead of ""
%   e.g. printer[aps_pid].footer_left = " ";
%
% (Windows only?): If the path to the a2ps/gsview executables contains blanks,
% apsmode can't access them.
% So prevent installation of executables in Directories containing blanks
% in name or add the a2ps directory to the path.
%   (a2ps Windows version (14.3b)):
%   For a2ps.exe I encountered this problem. a2ps.exe requested to be
%   in C:\Program Files\a2ps. So I did a "double" installation, one a2ps in
%   C:\Program Files\a2ps, the other in C:\Programs\a2ps.
%   In apsconf.sl I referenced the a2ps command in C:\Programs\a2ps, which then
%   takes it config files and other stuff from C:\Program Files\a2ps.
%   Or adding the a2ps directory to the path will also help.
%

% Helper functions for Postscript printing %{{{

% global variables, settings
provide(__FILE__);
static define path_rel( b, r)
{
   % source code by klaus.schmid@kdt.de
   variable i, a;
   a= strchop( r, '/', 0);
   for (i=0;i<length(a);i++)
     {
        if ( a[i] == "..")
          b= path_dirname( b);
        else
          b= path_concat( b, a[i]);
     }
   return b;
}

% printer properties definition
typedef struct
{
   setup,
     name,
     description,
     columns,
     rows,
     fontsize,
     chars,
     borders,
     orientation,
     medium,
     sides,
     truncate,
     linenumbers,
     copies,
     major,
     margin,
     header,
     title_left,
     title_center,
     title_right,
     footer_left,
     footer_center,
     footer_right,
     color,
     pretty,
     print_cmd,
     view_cmd,
     copy_of
}
Printer_Type;

variable use_jed_a2ps_style_sheet = Assoc_Type[Integer_Type];
%}}}

%%%%%%%%%%%%%%% user-definable variables begin %%%%%%%%%%%%%
% define user-definable variables and set default values which
% could be overwritten by apsconf.sl
%
% modify values in apsconf.sl instead of here!!!
%
custom_variable("aps_tmp_dir", path_rel(__FILE__,"../apsconf/"));
custom_variable("a2ps_cmd", "a2ps");
custom_variable("default_printer", 1);
custom_variable("aps_tmp_file", path_rel(__FILE__,"../apsconf/print_from_jed.ps"));
custom_variable("aps_menu", 1);
custom_variable("aps_del_ps_file", 1);
%%%%%%%%%%%%%%% user-definable variables end %%%%%%%%%%%%%

%{{{
% this variable will be used to give the path/filename of the buffer to a2ps
variable JEDFILENAME = "";
% this variable will be used to give the date/time of printing to a2ps
variable JEDDATETIME = "";
variable aps_version = "1.5.1";
variable aps_creation_date = "2005-11-22";
variable aps_jed_tested = "0.99-16";
variable aps_creator = "tkoeckritz@gmx.de";

custom_variable("aps_help_file", path_rel(__FILE__,"../apsconf/aps.hlp"));
custom_variable("a2ps_sheet_dir", path_rel(__FILE__,"../apsconf/"));
custom_variable("aps_config_file", path_rel(__FILE__,"../apsconf/apsconf.sl"));
custom_variable("aps_preview", "off");
% number of printers which can be defined in apsconf.sl
% (default = 20 should be sufficient in most cases)
variable max_no_printers = 20;
variable printer = Printer_Type[max_no_printers];
variable aps_pid = 0;

% now read printer settings
()= evalfile(aps_config_file);

% define QuickPrint settings as copy of default printer
%!%+
%\function{qp_is_copy_of}
%\synopsis{fill QuickPrint data with a predefined printer setup}
%\usage{qp_is_copy_of (Integer_Type pid_in)}
%\description
% This function is used to fill QuickPrint data with a predefined printer
% setup given by \var{pid_in}.
% The QuickPrint setup uses index=0 in \var{printer}.
% This function returns nothing.
%!%-
define qp_is_copy_of(pid_in)
{
   variable aps_pid = 0;
   printer[aps_pid].setup = "QuickPrint";
   printer[aps_pid].name = printer[pid_in].name;
   printer[aps_pid].description = printer[pid_in].description;
   printer[aps_pid].columns = printer[pid_in].columns;
   printer[aps_pid].rows = printer[pid_in].rows;
   printer[aps_pid].fontsize = printer[pid_in].fontsize;
   printer[aps_pid].chars = printer[pid_in].chars;
   printer[aps_pid].borders = printer[pid_in].borders;
   printer[aps_pid].orientation = printer[pid_in].orientation;
   printer[aps_pid].medium = printer[pid_in].medium;
   printer[aps_pid].sides = printer[pid_in].sides;
   printer[aps_pid].truncate = printer[pid_in].truncate;
   printer[aps_pid].linenumbers = printer[pid_in].linenumbers;
   printer[aps_pid].copies = printer[pid_in].copies;
   printer[aps_pid].major = printer[pid_in].major;
   printer[aps_pid].margin = printer[pid_in].margin;
   printer[aps_pid].header = printer[pid_in].header;
   printer[aps_pid].title_left = printer[pid_in].title_left;
   printer[aps_pid].title_center = printer[pid_in].title_center;
   printer[aps_pid].title_right = printer[pid_in].title_right;
   printer[aps_pid].footer_left = printer[pid_in].footer_left;
   printer[aps_pid].footer_center = printer[pid_in].footer_center;
   printer[aps_pid].footer_right = printer[pid_in].footer_right;
   printer[aps_pid].color = printer[pid_in].color;
   printer[aps_pid].pretty = printer[pid_in].pretty;
   printer[aps_pid].print_cmd = printer[pid_in].print_cmd;
   printer[aps_pid].view_cmd = printer[pid_in].view_cmd;
   printer[aps_pid].copy_of = pid_in;
   return;
}

% QuickPrint settings (as copy of default_printer)
qp_is_copy_of(default_printer);

%}}}

%!%+
%\function{jed_date_time}
%\synopsis{create a Date/Time string}
%\usage{String_Type jed_date_time ()}
%\description
% This function is used to create Date/Time string to be used as value
% for \var{JEDDATETIME}.
% This function returns a date/time string.
% \example
%   JEDDATETIME = jed_date_time();
%   value of JEDDATETIME will be "2004-Feb-29, 14:03:57"
%!%-
static define jed_date_time() %{{{
{
   variable tm;
   variable tm_string = "";
   variable month, day, hour, min, sec;
   tm = localtime (_time());

   switch (tm.tm_mon)
     { tm.tm_mon == 0 : month = "Jan";}
     { tm.tm_mon == 1 : month = "Feb";}
     { tm.tm_mon == 2 : month = "Mar";}
     { tm.tm_mon == 3 : month = "Apr";}
     { tm.tm_mon == 4 : month = "May";}
     { tm.tm_mon == 5 : month = "Jun";}
     { tm.tm_mon == 6 : month = "Jul";}
     { tm.tm_mon == 7 : month = "Aug";}
     { tm.tm_mon == 8 : month = "Sep";}
     { tm.tm_mon == 9 : month = "Oct";}
     { tm.tm_mon == 10 : month = "Nov";}
     { tm.tm_mon == 11 : month = "Dec";};
   if (tm.tm_mday < 10)
     {
	day = sprintf("0%d", tm.tm_mday);
     }
   else
     {
	day = sprintf("%d", tm.tm_mday);
     }
   if (tm.tm_hour < 10)
     {
	hour = sprintf("0%d", tm.tm_hour);
     }
   else
     {
	hour = sprintf("%d", tm.tm_hour);
     }
   if (tm.tm_min < 10)
     {
	min = sprintf("0%d", tm.tm_min);
     }
   else
     {
	min = sprintf("%d", tm.tm_min);
     }
   if (tm.tm_sec < 10)
     {
	sec = sprintf("0%d", tm.tm_sec);
     }
   else
     {
	sec = sprintf("%d", tm.tm_sec);
     }
   tm_string = sprintf("%d-%s-%s, %s:%s:%s",1900+tm.tm_year, month, day, hour, min, sec );
   return tm_string;
}

%}}}

%%%%%%%%%%%%%%%%%%%%% Menu Entries Begin %%%%%%%%%%%%%%%%%%%%%%% %{{{

static define default_printer_callback (popup)
{
   menu_append_item (popup, string(printer[default_printer].setup), strcat("show_printer_settings(",string(default_printer),",1)"));
}

static define set_default_printer_callback (popup)
{
   variable i;
   for (i = 0; i <= max_no_printers-1; i++)
     {
	if (printer[i].setup != NULL)
	  {
	     if (i == default_printer)
	       {
		  menu_append_item (popup, strcat("* ", string(printer[i].setup)), strcat("set_default_printer(",string(i),")"));
	       }
	     else
	       {
		  menu_append_item (popup, strcat("  ", string(printer[i].setup)), strcat("set_default_printer(",string(i),")"));
	       }
	  }
     }
   return;
}

static define show_default_printer_callback (popup)
{
   variable i;
   for (i = 0; i <= max_no_printers-1; i++)
     {
	if (printer[i].setup != NULL)
	  {
	     if (i == default_printer)
	       {
		  menu_append_item (popup, strcat("* ", string(printer[i].setup)), strcat("show_printer_settings(",string(i),",1)"));
	       }
	     else
	       {
		  menu_append_item (popup, strcat("  ", string(printer[i].setup)), strcat("show_printer_settings(",string(i),",1)"));
	       }
	  }
     }
   return;
}

static define show_default_printer2_callback (popup)
{
   variable i;
   for (i = 0; i <= max_no_printers-1; i++)
     {
	if (printer[i].setup != NULL)
	  {
	     if (i == default_printer)
	       {
		  menu_append_item (popup, "Current Settings in apsconf format", strcat("show_printer_settings(",string(default_printer),",2)"));
	       }
%	     else
%	       {
%		  menu_append_item (popup, strcat("  ", string(printer[i].setup)), strcat("show_printer_settings(",string(i),",1)"));
%	       }
	  }
     }
   return;
}

%!%+
%\function{set_qp}
%\synopsis{execute QuickPrint settings from menu}
%\usage{set_qp (String_Type setting)}
%\description
% This function is used to define new settings for QuickPrint.
% \var{setting} is a string containing slang-code, which
% will be executed by this function.
% \var{setting} will be defined via menu entries.
% This function returns nothing.
% \example
% The following command appends a menu item (called "A4")
% Clicking on that item will execute the code
%  "printer[0].medium=\"A4\""
%	menu_append_item (popup, strcat("* ", "A&4"), strcat("set_qp(\"printer[0].medium=\\\"A4\\\"\")"));
%!%-
define set_qp(setting)
{
   eval(setting);
   menu_select_menu("Global.&Print.&QuickPrint");
   return;
}
static define set_qp_orientation_callback (popup)
{
   if (strup(printer[0].orientation) == "PORTRAIT")
     {
	menu_append_item (popup, strcat("* ", "&portrait"), strcat("set_qp(\"printer[0].orientation=\\\"portrait\\\"\")"));
	menu_append_item (popup, strcat("  ", "&landscape"), strcat("set_qp(\"printer[0].orientation=\\\"landscape\\\"\")"));
     }
   if (strup(printer[0].orientation) == "LANDSCAPE")
     {
	menu_append_item (popup, strcat("  ", "&portrait"), strcat("set_qp(\"printer[0].orientation=\\\"portrait\\\"\")"));
	menu_append_item (popup, strcat("* ", "&landscape"), strcat("set_qp(\"printer[0].orientation=\\\"landscape\\\"\")"));
     }
   return;
}
static define set_qp_no_columns_callback (popup)
{
   variable i;
   for (i = 1; i <= 4; i++)
     {
	if (printer[0].columns == string(i))
	  {
	     menu_append_item (popup, strcat("* ", string(i)), strcat("set_qp(\"printer[0].columns=\\\"", string(i), "\\\"\")"));
	  }
	else
	  {
	     menu_append_item (popup, strcat("  ", string(i)), strcat("set_qp(\"printer[0].columns=\\\"", string(i), "\\\"\")"));
	  }
     }
   return;
}
static define set_qp_no_rows_callback (popup)
{
   variable i;
   for (i = 1; i <= 4; i++)
     {
	if (printer[0].rows == string(i))
	  {
	     menu_append_item (popup, strcat("* ", string(i)), strcat("set_qp(\"printer[0].rows=\\\"", string(i), "\\\"\")"));
	  }
	else
	  {
	     menu_append_item (popup, strcat("  ", string(i)), strcat("set_qp(\"printer[0].rows=\\\"", string(i), "\\\"\")"));
	  }
     }
   return;
}
static define set_qp_no_sides_callback (popup)
{
   variable i;
   for (i = 1; i <= 2; i++)
     {
	if (printer[0].sides == string(i))
	  {
	     menu_append_item (popup, strcat("* ", string(i)), strcat("set_qp(\"printer[0].sides=\\\"", string(i), "\\\"\")"));
	  }
	else
	  {
	     menu_append_item (popup, strcat("  ", string(i)), strcat("set_qp(\"printer[0].sides=\\\"", string(i), "\\\"\")"));
	  }
     }
   return;
}
static define set_qp_borders_callback (popup)
{
   if (strup(printer[0].borders) == "ON")
     {
	menu_append_item (popup, strcat("* ", "o&n"), strcat("set_qp(\"printer[0].borders=\\\"on\\\"\")"));
	menu_append_item (popup, strcat("  ", "o&ff"), strcat("set_qp(\"printer[0].borders=\\\"off\\\"\")"));
     }
   if (strup(printer[0].borders) == "OFF")
     {
	menu_append_item (popup, strcat("  ", "o&n"), strcat("set_qp(\"printer[0].borders=\\\"on\\\"\")"));
	menu_append_item (popup, strcat("* ", "o&ff"), strcat("set_qp(\"printer[0].borders=\\\"off\\\"\")"));
     }
   return;
}
static define set_qp_no_copies_callback (popup)
{
   variable i;
   for (i = 1; i <= 10; i++)
     {
	if (printer[0].copies == string(i))
	  {
	     menu_append_item (popup, strcat("* ", string(i)), strcat("set_qp(\"printer[0].copies=\\\"", string(i), "\\\"\")"));
	  }
	else
	  {
	     menu_append_item (popup, strcat("  ", string(i)), strcat("set_qp(\"printer[0].copies=\\\"", string(i), "\\\"\")"));
	  }
     }
   return;
}
static define set_qp_linenumbers_callback (popup)
{
   variable i;
   for (i = 0; i <= 10; i++)
     {
	if (printer[0].linenumbers == string(i))
	  {
	     menu_append_item (popup, strcat("* ", string(i)), strcat("set_qp(\"printer[0].linenumbers=\\\"", string(i), "\\\"\")"));
	  }
	else
	  {
	     menu_append_item (popup, strcat("  ", string(i)), strcat("set_qp(\"printer[0].linenumbers=\\\"", string(i), "\\\"\")"));
	  }
     }
   return;
}
static define set_qp_medium_callback (popup)
{
   if (strup(printer[0].medium) == "A4")
     {
	menu_append_item (popup, strcat("* ", "A&4"), strcat("set_qp(\"printer[0].medium=\\\"A4\\\"\")"));
	menu_append_item (popup, strcat("  ", "A&3"), strcat("set_qp(\"printer[0].medium=\\\"A3\\\"\")"));
	menu_append_item (popup, strcat("  ", "&Letter"), strcat("set_qp(\"printer[0].medium=\\\"Letter\\\"\")"));
     }
   if (strup(printer[0].medium) == "A3")
     {
	menu_append_item (popup, strcat("  ", "A&4"), strcat("set_qp(\"printer[0].medium=\\\"A4\\\"\")"));
	menu_append_item (popup, strcat("* ", "A&3"), strcat("set_qp(\"printer[0].medium=\\\"A3\\\"\")"));
	menu_append_item (popup, strcat("  ", "&Letter"), strcat("set_qp(\"printer[0].medium=\\\"Letter\\\"\")"));
     }
   if (strup(printer[0].medium) == "LETTER")
     {
	menu_append_item (popup, strcat("  ", "A&4"), strcat("set_qp(\"printer[0].medium=\\\"A4\\\"\")"));
	menu_append_item (popup, strcat("  ", "A&3"), strcat("set_qp(\"printer[0].medium=\\\"A3\\\"\")"));
	menu_append_item (popup, strcat("* ", "&Letter"), strcat("set_qp(\"printer[0].medium=\\\"Letter\\\"\")"));
     }
   return;
}
static define set_qp_printer_callback (popup)
{
   variable i;
   variable action;
   action = strcat("read_mini\\\(\\\"Enter print command\\\",\\\"", printer[0].print_cmd,"\\\",\\\"", printer[0].print_cmd,"\\\"\\\)");
   action = strcat("printer[0].print_cmd=", action);
   action = strcat("set_qp(\"", action, "\")");
   menu_append_item (popup, "&Add temporary Print Command", action);
   for (i = 0; i <= max_no_printers-1; i++)
     {
	if (printer[i].setup != NULL)
	  {
	     if (printer[0].print_cmd == printer[i].print_cmd)
	       {
		  menu_append_item (popup, strcat("* ", printer[i].print_cmd), strcat("set_qp(\"printer[0].print_cmd=\\\"", printer[i].print_cmd, "\\\"\")"));
	       }
	     else
	       {
		  menu_append_item (popup, strcat("  ", printer[i].print_cmd), strcat("set_qp(\"printer[0].print_cmd=\\\"", printer[i].print_cmd, "\\\"\")"));
	       }
	  }
     }
   return;
}
static define set_qp_header_callback (popup)
{
   variable i;
   variable action;
   action = strcat("read_mini\\\(\\\"Enter header string\\\",\\\"", printer[0].header,"\\\",\\\"", printer[0].header,"\\\"\\\)");
   action = strcat("printer[0].header=", action);
   action = strcat("set_qp(\"", action, "\")");
   menu_append_item (popup, "&Add temporary Header String", action);
   for (i = 0; i <= max_no_printers-1; i++)
     {
	if (printer[i].setup != NULL)
	  {
	     if (printer[i].header != "")
	       {
		  if (printer[0].header == printer[i].header)
		    {
		       menu_append_item (popup, strcat("* ", printer[i].header), strcat("set_qp(\"printer[0].header=\\\"", printer[i].header, "\\\"\")"));
		    }
		  else
		    {
		       menu_append_item (popup, strcat("  ", printer[i].header), strcat("set_qp(\"printer[0].header=\\\"", printer[i].header, "\\\"\")"));
		    }
	       }
	  }
     }
   return;
}
static define set_qp_is_copy_of_callback (popup)
{
   variable i;
   for (i = 1; i <= max_no_printers-1; i++)
     {
	if (printer[i].setup != NULL)
	  {
	     if (printer[0].copy_of == i)
	       {
		  menu_append_item (popup, strcat("* ", printer[i].setup), strcat("qp_is_copy_of(", string(i), ")"));
	       }
	     else
	       {
		  menu_append_item (popup, strcat("  ", printer[i].setup), strcat("qp_is_copy_of(", string(i), ")"));
	       }
	  }
     }
   return;
}
static define set_qp_fontsize_callback (popup)
{
   variable i;
   variable increment = 1;

   if (printer[0].fontsize == "none")
     {
        menu_append_item (popup, strcat("* ", "don't care"), strcat("set_qp(\"printer[0].fontsize=\\\"", "none", "\\\"\")"));
     }
   else
     {
        menu_append_item (popup, strcat("  ", "don't care"), strcat("set_qp(\"printer[0].fontsize=\\\"", "none", "\\\"\")"));
     }
   % add fontsize in points
   for (i = 6; i <= 72; i = i + increment)
     {
	if (printer[0].fontsize == strcat(string(i), "points"))
	  {
	     menu_append_item (popup, strcat("* ", string(i), "points"), strcat("set_qp(\"printer[0].fontsize=\\\"", string(i), "points", "\\\"\")"));
	  }
	else
	  {
	     menu_append_item (popup, strcat("  ", string(i), "points"), strcat("set_qp(\"printer[0].fontsize=\\\"", string(i), "points", "\\\"\")"));
	  }
	if ( i == 12)
	  {
	     increment = 2;
	  }
	if ( i == 28)
	  {
	     increment = 8;
	  }
	if ( i == 36)
	  {
	     increment = 12;
	  }
	if ( i == 48)
	  {
	     increment = 24;
	  }
     }
   return;
}
static define set_qp_max_chars_callback (popup)
{
   variable action;
   action = strcat("read_mini\\\(\\\"Enter min:max characters\\\",\\\"", printer[0].chars,"\\\",\\\"", printer[0].chars,"\\\"\\\)");
   action = strcat("printer[0].chars=", action);
   action = strcat("set_qp(\"", action, "\")");
   menu_append_item (popup, "&Change Max Characters", action);
   menu_append_item (popup, "0:80", strcat("set_qp(\"printer[0].chars=\\\"0:80\\\"\")"));
   menu_append_item (popup, "0:100", strcat("set_qp(\"printer[0].chars=\\\"0:100\\\"\")"));
   menu_append_item (popup, "0:132", strcat("set_qp(\"printer[0].chars=\\\"0:132\\\"\")"));
   menu_append_item (popup, "80:100", strcat("set_qp(\"printer[0].chars=\\\"80:100\\\"\")"));
   menu_append_item (popup, "80:132", strcat("set_qp(\"printer[0].chars=\\\"80:132\\\"\")"));
   return;
}

if ( aps_menu == 1)
{
   menu_append_popup ("Global", "&Print");
   $1 = "Global.&Print";
   menu_append_item ($1, "Print &Buffer", "print_buffer");
   menu_append_item ($1, "Print &Region", "print_region");

   menu_append_separator ($1);
   menu_append_item ($1, "Print B&uffer Preview", "print_buffer_preview");
   menu_append_item ($1, "Print R&egion Preview", "print_region_preview");

   menu_append_separator ($1);
   menu_append_popup ($1, "&Default Printer");
   menu_set_select_popup_callback (strcat ($1, ".&Default Printer"), &default_printer_callback);
   menu_append_popup ($1, "Set Default &Printer");
   menu_set_select_popup_callback (strcat ($1, ".Set Default &Printer"), &set_default_printer_callback);

   menu_append_separator ($1);
   menu_append_popup ($1, "&QuickPrint");
   menu_append_popup (strcat($1, ".&QuickPrint"), "&Orientation");
   menu_set_select_popup_callback (strcat ($1, ".&QuickPrint.&Orientation"), &set_qp_orientation_callback);
   menu_append_popup (strcat($1, ".&QuickPrint"), "Number of &Columns");
   menu_set_select_popup_callback (strcat ($1, ".&QuickPrint.Number of &Columns"), &set_qp_no_columns_callback);
   menu_append_popup (strcat($1, ".&QuickPrint"), "Number of &Rows");
   menu_set_select_popup_callback (strcat ($1, ".&QuickPrint.Number of &Rows"), &set_qp_no_rows_callback);
   menu_append_popup (strcat($1, ".&QuickPrint"), "2 &Sides");
   menu_set_select_popup_callback (strcat ($1, ".&QuickPrint.2 &Sides"), &set_qp_no_sides_callback);
   menu_append_popup (strcat($1, ".&QuickPrint"), "&Borders");
   menu_set_select_popup_callback (strcat ($1, ".&QuickPrint.&Borders"), &set_qp_borders_callback);
   menu_append_popup (strcat($1, ".&QuickPrint"), "&Copies");
   menu_set_select_popup_callback (strcat ($1, ".&QuickPrint.&Copies"), &set_qp_no_copies_callback);
   menu_append_popup (strcat($1, ".&QuickPrint"), "&Linenumbers");
   menu_set_select_popup_callback (strcat ($1, ".&QuickPrint.&Linenumbers"), &set_qp_linenumbers_callback);
   menu_append_popup (strcat($1, ".&QuickPrint"), "&Max Characters");
   menu_set_select_popup_callback (strcat ($1, ".&QuickPrint.&Max Characters"), &set_qp_max_chars_callback);
   menu_append_popup (strcat($1, ".&QuickPrint"), "&Fontsize");
   menu_set_select_popup_callback (strcat ($1, ".&QuickPrint.&Fontsize"), &set_qp_fontsize_callback);
   menu_append_popup (strcat($1, ".&QuickPrint"), "Paper &Format");
   menu_set_select_popup_callback (strcat ($1, ".&QuickPrint.Paper &Format"), &set_qp_medium_callback);
   menu_append_popup (strcat($1, ".&QuickPrint"), "&Header");
   menu_set_select_popup_callback (strcat ($1, ".&QuickPrint.&Header"), &set_qp_header_callback);
   menu_append_popup (strcat($1, ".&QuickPrint"), "&Print Command");
   menu_set_select_popup_callback (strcat ($1, ".&QuickPrint.&Print Command"), &set_qp_printer_callback);
   menu_append_popup (strcat($1, ".&QuickPrint"), "QP is Cop&y of");
   menu_set_select_popup_callback (strcat ($1, ".&QuickPrint.QP is Cop&y of"), &set_qp_is_copy_of_callback);

   menu_append_separator ($1);
   menu_append_popup ($1, "Show Printer &Settings");
   menu_set_select_popup_callback (strcat ($1, ".Show Printer &Settings"), &show_default_printer_callback);
   menu_append_item ($1, "Show Print &Logfile", "show_print_log()");

   menu_append_separator ($1);
   menu_append_item ($1, "Edi&t apsconf.sl", "find_file(aps_config_file)");
   menu_append_item ($1, "Rel&oad apsconf.sl", "aps_pid=0;evalfile(aps_config_file)");
   menu_append_item ($1, "Current Settings in apsconf format", strcat("show_printer_settings(",string(default_printer),",2)"));
   menu_append_item ($1, "&Create Style Sheet", "create_a2ps_style_sheet(\"\")");

   menu_append_separator ($1);
   menu_append_item ($1, "&Help apsmode", "aps_help");
   menu_append_popup ($1, "&About apsmode");
   menu_append_item (strcat($1, ".&About apsmode"), "apsmode", "");
   menu_append_item (strcat($1, ".&About apsmode"), strcat("Version ", aps_version), "");
   menu_append_item (strcat($1, ".&About apsmode"), strcat("created ", aps_creation_date), "");
   %menu_append_item (strcat($1, ".&About apsmode"), strcat("by ", aps_creator), "");
   menu_append_item (strcat($1, ".&About apsmode"), strcat("tested with JED ", aps_jed_tested), "");
}

%%%%%%%%%%%%%%%%%%%%% Menu Entries End %%%%%%%%%%%%%%%%%%%%%%%

%}}}

%!%+
%\function{get_a2ps_cmd}
%\synopsis{create a2ps command}
%\usage{String_Type get_a2ps_cmd (Integer_Type id, Integer_Type max_char)}
%\description
% This function is used to create an a2ps command, which will be used later to
% create a postscript file.
% \var{id} will be used as index for the \var{printer}-array. Values of this
% array will be taken to create the a2ps command.
% \var{max_char} defines the maximum number of characters per line in
% the printout.
% This function returns the a2ps command.
%!%-
static define get_a2ps_cmd(id, max_char) %{{{
{
   variable cmd = strcat(a2ps_cmd, " ");
   variable no_header = "";
   variable chars = Integer_Type [2];

   cmd = strcat(cmd, " --output=", aps_tmp_file);
   cmd = strcat(cmd, " --columns=", printer[id].columns);
   cmd = strcat(cmd, " --rows=", printer[id].rows);

   % now determine , how much characters have to be printed per line
   % first extract min/max values from printer setting

   chars = strchop(printer[id].chars,':',0);

   switch (max_char)
     { max_char < integer(chars[0]) :
	cmd = strcat(cmd, " --chars-per-line=", string(chars[0]));
     }
     { max_char > integer(chars[1]) :
	cmd = strcat(cmd, " --chars-per-line=", string(chars[1]));
     }
     {
	cmd = strcat(cmd, " --chars-per-line=", string(max_char));
     };

   if (printer[id].fontsize != "none")
     {
	cmd = strcat(cmd, " --font-size=", printer[id].fontsize);
     }

   cmd = strcat(cmd, " --borders=", printer[id].borders);
   cmd = strcat(cmd, " --", printer[id].orientation);
   cmd = strcat(cmd, " --medium=", printer[id].medium);
   cmd = strcat(cmd, " --sides=", printer[id].sides);
   cmd = strcat(cmd, " --truncate-line=", printer[id].truncate);
   cmd = strcat(cmd, " --line-numbers=", printer[id].linenumbers);
   cmd = strcat(cmd, " --copies=", printer[id].copies);
   cmd = strcat(cmd, " --major=", printer[id].major);
   cmd = strcat(cmd, " --margin=", printer[id].margin);

   % string settings must be differently defined for UNIX and Windows
   % Windows needs some extra \\ for hashing, otherwise only parts of
   % the defined strings will be considered
#ifdef UNIX
   if ( printer[id].header != "" )
     {
	cmd = strcat(cmd, " --header=\"", printer[id].header, "\"");
	no_header = "1";
     }
   if ( printer[id].title_left != "" )
     {
	cmd = strcat(cmd, " --left-title=\"", printer[id].title_left, "\"");
	no_header = "1";
     }
   if ( printer[id].title_center != "" )
     {
	cmd = strcat(cmd, " --center-title=\"", printer[id].title_center, "\"");
	no_header = "1";
     }
   if ( printer[id].title_right != "" )
     {
	cmd = strcat(cmd, " --right-title=\"", printer[id].title_right, "\"");
	no_header = "1";
     }
   if (no_header == "")
     {
	cmd = strcat(cmd, " --no-header");
     }
   if ( printer[id].footer_left != "" )
     {
	cmd = strcat(cmd, " --left-footer=\"", printer[id].footer_left, "\"");
     }

   if ( printer[id].footer_center != "" )
     {
	cmd = strcat(cmd, " --footer=\"", printer[id].footer_center, "\"");
     }
   if ( printer[id].footer_right != "" )
     {
	cmd = strcat(cmd, " --right-footer=\"", printer[id].footer_right, "\"");
     }
#endif
#ifdef MSWINDOWS
   if ( printer[id].header != "" )
     {
	cmd = strcat(cmd, " --header=\\\"", printer[id].header, "\\\"");
	no_header = "1";
     }
   if ( printer[id].title_left != "" )
     {
	cmd = strcat(cmd, " --left-title=\\\"", printer[id].title_left, "\\\"");
	no_header = "1";
     }
   if ( printer[id].title_center != "" )
     {
	cmd = strcat(cmd, " --center-title=\\\"", printer[id].title_center, "\\\"");
	no_header = "1";
     }
   if ( printer[id].title_right != "" )
     {
	cmd = strcat(cmd, " --right-title=\\\"", printer[id].title_right, "\\\"");
	no_header = "1";
     }
   if (no_header == "")
     {
	cmd = strcat(cmd, " --no-header");
     }
   if ( printer[id].footer_left != "" )
     {
	cmd = strcat(cmd, " --left-footer=\\\"", printer[id].footer_left, "\\\"");
     }

   if ( printer[id].footer_center != "" )
     {
	cmd = strcat(cmd, " --footer=\\\"", printer[id].footer_center, "\\\"");
     }
   if ( printer[id].footer_right != "" )
     {
	cmd = strcat(cmd, " --right-footer=\\\"", printer[id].footer_right, "\\\"");
     }
#endif
   cmd = strcat(cmd, " --prologue=", printer[id].color);
   % pretty-print must be the last entry to have a chance to append
   % local a2ps style sheet later
   if (strup(printer[id].pretty) == "ON")
     {
	cmd = strcat(cmd, " --pretty-print");
     }
   else
     {
	cmd = strcat(cmd, " --pretty-print=\"plain\"");
     }
   % remove the placeholders for filename and date/time
   cmd = str_replace_all(cmd, "JEDFILENAME", JEDFILENAME);
   cmd = str_replace_all(cmd, "JEDDATETIME", JEDDATETIME);

   return cmd;
}

%}}}

%!%+
%\function{show_printer_settings}
%\synopsis{show current printer settings}
%\usage{show_printer_settings (Integer_Type id, Integer_Type format)}
%\description
% This function is used to show the current printer settings in a
% separate buffer.
% \var{id} will be used as index for the \var{printer}-array, which
% contains the settings.
% \var{format} will be used to format the output either as
% - human readable text or
% - as configuration data for apsconf.sl
% This function returns nothing.
%!%-
define show_printer_settings(id,format) %{{{
{
   variable bufname = strcat("*Printer-settings-for-Printer-", string(id), "*");
   sw2buf(bufname);
   set_readonly(0);
   erase_buffer();
   bob();
   
   % print settings in a readable format
   if (format == 1)
     {
	insert(sprintf("\nSettings for %s\n", printer[id].setup));
	insert("==========================================\n\n");
	insert("\nPrint options\n");
	insert("------------------------------------------\n");
	insert(sprintf("Printer Name          : %s\n", printer[id].name));
	insert(sprintf("Printer Description   : %s\n", printer[id].description));
	insert(sprintf("Number of Columns     : %s\n", printer[id].columns));
	insert(sprintf("Number of Rows        : %s\n", printer[id].rows));
	insert(sprintf("Fontsize              : %s\n", printer[id].fontsize));
	insert(sprintf("Characters per Line   : %s\n", printer[id].chars));
	insert(sprintf("Orientation           : %s\n", printer[id].orientation));
	insert(sprintf("Paper Format          : %s\n", printer[id].medium));
	insert(sprintf("One/Two Sides Print   : %s\n", printer[id].sides));
	insert(sprintf("Truncate Lines        : %s\n", printer[id].truncate));
	insert(sprintf("Number of copies      : %s\n", printer[id].copies));
	insert(sprintf("Major Print Direction : %s\n", printer[id].major));
	insert(sprintf("\nPrint Linenumbers every %s row(s)\n", printer[id].linenumbers));

	insert("\nLayout options\n");
	insert("------------------------------------------\n");
	insert(sprintf("Print Borders         : %s\n", printer[id].borders));
	insert(sprintf("Margin [points]       : %s\n", printer[id].margin));
	insert(sprintf("Header                : %s\n", printer[id].header));
	insert(sprintf("Left Title            : %s\n", printer[id].title_left));
	insert(sprintf("Center Title          : %s\n", printer[id].title_center));
	insert(sprintf("Right Title           : %s\n", printer[id].title_right));
	insert(sprintf("Left Footer           : %s\n", printer[id].footer_left));
	insert(sprintf("Center Footer         : %s\n", printer[id].footer_center));
	insert(sprintf("Right Footer          : %s\n", printer[id].footer_right));
	insert(sprintf("Color                 : %s\n", printer[id].color));
	insert(sprintf("Syntax Highlighting   : %s\n", printer[id].pretty));

	insert("------------------------------------------\n\n");
	insert("a2ps command:\n");
	insert(get_a2ps_cmd(id,0));
	insert("\n\n");
	insert("print command:\n");
	insert(printer[id].print_cmd);
	insert("\n\n");
	insert("view command:\n");
	insert(printer[id].view_cmd);
	insert("\n");
     }

   % print settings in a apsconf format
   if (format == 2)
     {
insert("aps_pid++;\n");
insert(sprintf("printer[aps_pid].setup = \"%s\";\n",printer[id].setup));
insert(sprintf("printer[aps_pid].name = \"%s\";\n",printer[id].name));
insert(sprintf("printer[aps_pid].description = \"%s\";\n",printer[id].description));
insert(sprintf("printer[aps_pid].columns = \"%s\";\n",printer[id].columns));
insert(sprintf("printer[aps_pid].rows = \"%s\";\n",printer[id].rows));
insert(sprintf("printer[aps_pid].fontsize = \"%s\";\n",printer[id].fontsize));
insert(sprintf("printer[aps_pid].chars = \"%s\";\n",printer[id].chars));
insert(sprintf("printer[aps_pid].borders = \"%s\";\n",printer[id].borders));
insert(sprintf("printer[aps_pid].orientation = \"%s\";\n",printer[id].orientation));
insert(sprintf("printer[aps_pid].medium = \"%s\";\n",printer[id].medium));
insert(sprintf("printer[aps_pid].sides = \"%s\";\n",printer[id].sides));
insert(sprintf("printer[aps_pid].truncate = \"%s\";\n",printer[id].truncate));
insert(sprintf("printer[aps_pid].linenumbers = \"%s\";\n",printer[id].linenumbers));
insert(sprintf("printer[aps_pid].copies = \"%s\";\n",printer[id].copies));
insert(sprintf("printer[aps_pid].major = \"%s\";\n",printer[id].major));
insert(sprintf("printer[aps_pid].margin = \"%s\";\n",printer[id].margin));
insert(sprintf("printer[aps_pid].header = \"%s\";\n",printer[id].header));
insert(sprintf("printer[aps_pid].title_left = \"%s\";\n",printer[id].title_left));
insert(sprintf("printer[aps_pid].title_center = \"%s\";\n",printer[id].title_center));
insert(sprintf("printer[aps_pid].title_right = \"%s\";\n",printer[id].title_right));
insert(sprintf("printer[aps_pid].footer_left = \"%s\";\n",printer[id].footer_left));
insert(sprintf("printer[aps_pid].footer_center = \"%s\";\n",printer[id].footer_center));
insert(sprintf("printer[aps_pid].footer_right = \"%s\";\n",printer[id].footer_right));
insert(sprintf("printer[aps_pid].color = \"%s\";\n",printer[id].color));
insert(sprintf("printer[aps_pid].pretty = \"%s\";\n",printer[id].pretty));
insert(sprintf("printer[aps_pid].print_cmd = \"%s\";\n",printer[id].print_cmd));
insert(sprintf("printer[aps_pid].view_cmd = \"%s\";\n",printer[id].view_cmd));
insert("printer[aps_pid].copy_of = 0;\n");

     }
   
   set_buffer_modified_flag(0);
   set_readonly(1);
   bob();

   return;
}

%}}}

static define get_max_chars(file) %{{{
{
   % scan the input file and determine the maximum length of rows
   variable max = 0, col = 0;
   find_file(file);
   bob();
   do
     {
	eol();
	col = what_column();
	if ( col > max)
	  {
	     max = col;
	  }
     }
   while (down_1());
   delbuf(whatbuf());
   return max;
}

%}}}

%!%+
%\function{print_log}
%\synopsis{log a string in print log buffer}
%\usage{print_log (String_Type prompt, String_Type string_in)}
%\description
% This function is used to log the given \var{string_in} into the current
% buffer.
% \var{prompt} will be used as prompt (or identifier) of \var{string_in}.
% This function returns nothing.
%!%-
static define print_log(prompt, string_in) %{{{
{
   variable string_out = strcat(string(prompt), " : ", string(string_in), "\n");
   insert(string_out);
   return;
}

%}}}

%!%+
%\function{show_print_log}
%\synopsis{show print log buffer}
%\usage{show_print_log ()}
%\description
% This function is used to switch to the print log buffer
% This function returns nothing.
%!%-
define show_print_log() %{{{
{
   sw2buf ("*print-output*");
   return;
}

%}}}

%!%+
%\function{print_region}
%\synopsis{print a defined region}
%\usage{print_region ()}
%\description
% This function is the major function  for printing/previewing.
% It will create a postscript file from the marked region using the settings
% in \var{printer}-array.
% Printing/Previewing will be determined via global variable \var{aps_preview}.
% A marked region will stay highlighted after preview/printing.
% This function returns nothing.
%!%-
define print_region() %{{{
{
   variable pfile;
   variable bufname;
   variable bufdir;
   variable buffile;
   variable file;
   variable msg;
   variable cmd;
   variable mode_name;
   variable sheet_file;
   variable max_char=0;
   variable rc;
   variable region_highlighted = is_visible_mark;
   variable redirect;

   if ( region_highlighted == 1)
     {
	narrow_to_region();
	bob();
	push_visible_mark();
	eob();
     }

   pfile = strcat(aps_tmp_dir,"#");

   % Find out the name of the buffer
   (buffile,bufdir,bufname,) = getbuf_info ();
   % if it is an internal buffer replace filename with buffer name
   if (buffile == "")
     {
	buffile = bufname;
	bufdir = "";
     }

   % set JEDFILENAME variable
   JEDFILENAME = sprintf("%s%s", bufdir, buffile);
#ifdef MSWINDOWS
   JEDFILENAME = str_replace_all(JEDFILENAME,"\\","\\\\");
#endif
   JEDDATETIME = jed_date_time();

   % extract mode name to check later, whether local a2ps style sheet
   % should be used
   mode_name = get_mode_name();
   sheet_file = strcat(a2ps_sheet_dir, mode_name, ".ssh");

   msg = sprintf("Formatting %s...", bufname);
   flush (msg);

   % Save region in temporary file named pfile
   pfile = strcat(pfile,bufname);
   % replace special characters in filename
   pfile = strtrans(pfile, " ","_");
   pfile = strtrans(pfile, "*","");
   pfile = strtrans(pfile, "<","");
   pfile = strtrans(pfile, ">","");
   pfile = strtrans(pfile, "(","");
   pfile = strtrans(pfile, ")","");

   write_region_to_file (pfile);

   max_char = get_max_chars(pfile);

   % switch to print-log buffer for logging purposes
   sw2buf ("*print-output*");
   eob();
   print_log("Max Chars ", max_char);

   % create the a2ps command
   cmd = get_a2ps_cmd(default_printer, max_char);

   if (strup(printer[default_printer].pretty) == "ON")
     {
	print_log("Pretty Print Mode", mode_name);
	% now check whether jed-created a2ps style sheets should be used
	% if yes append them to "pretty-print=jed-style.ssh"
	if ( assoc_key_exists (use_jed_a2ps_style_sheet, mode_name) == 1 )
	  {
	     print_log("Sheet File", sheet_file);
	     if (file_status(sheet_file) == 1)
	       {
		  cmd = strcat(cmd, "=", sheet_file);
	       }
	  }
     }

   % Format the file by executing a2ps, creating a second temporary (ps) file
   cmd = strcat(cmd, " ", pfile);
   % do some logging
   print_log("a2ps cmd  ", cmd);
   print_log("view cmd  ", printer[default_printer].view_cmd);
   print_log("print cmd ", printer[default_printer].print_cmd);

   % use " 2>&1" to re-direct stderr as well
#ifdef UNIX
   redirect = "2>&1";
#endif
#ifdef MSWINDOWS
   redirect = "";
#endif

   insert ("\n--------------------- a2ps preprocessing --- (a2ps cmd) -------------------------\n");
   rc = run_shell_cmd (sprintf ("%s %s", cmd, redirect));
   insert ("--------------------------------------------------------------------------------\n\n");
   % return code under MSWINDOWS seems not to work very well, always 0 ?
   % so error handling works only correct under UNIX
   if (rc == 0)
     {
	if (aps_preview == "on")
	  {
	     % View the temporary file
             insert ("\n--------------------- Viewing --- (view cmd) -------------------------\n");
	     msg = sprintf("Viewing %s...", bufname);
	     flush(msg);
	     rc = run_shell_cmd (sprintf ("%s %s", printer[default_printer].view_cmd, redirect));
	     msg = sprintf("Viewing done (%s)", bufname);
	     flush(msg);
	  }
	else
	  {
	     % Print the temporary file
             insert ("\n--------------------- Printing --- (print cmd) -----------------------\n");
	     msg = sprintf("Printing %s...", bufname);
	     flush(msg);
	     rc = run_shell_cmd (sprintf ("%s %s", printer[default_printer].print_cmd, redirect));
	     msg = sprintf("Printing done (%s --> %s)", bufname, printer[default_printer].name);
	     flush(msg);
	  }
     }
   insert ("\n\n");
   set_buffer_modified_flag(0);

   if (rc == 0)
     {
	% if all was ok, switch back to the original buffer
	sw2buf(bufname);
	% restore previous selection, if there was one
	if ( region_highlighted == 1)
	  {
	     bob();
	     push_visible_mark();
	     eob();
	     widen_region();
	  }
     }
   else
     {
	error ("An error occured!");
     }

   % Clean up
   delete_file (pfile);
   if (aps_del_ps_file = 1)
     {
	delete_file (aps_tmp_file);
     }

   return;
}
%}}}

%!%+
%\function{print_buffer}
%\synopsis{print the buffer}
%\usage{print_buffer ()}
%\description
% This function is called to print the whole buffer. It calls function
% \var{print_region} for printing.
% This function returns nothing.
% \seealso{print_region}
%!%-
define print_buffer() %{{{
{
   aps_preview = "off";
   push_spot ();
   mark_buffer ();
   print_region ();
   pop_spot ();
}
%}}}

%!%+
%\function{print_buffer_preview}
%\synopsis{print preview of the buffer}
%\usage{print_buffer_preview ()}
%\description
% This function is called to preview the whole buffer. It sets variable
% \var{aps_preview} to \var{on} and calls then function \var{print_region}
% for previewing. After that \var{aps_preview} will be reset to \var{off}.
% This function returns nothing.
% \seealso{print_region}
%!%-
define print_buffer_preview() %{{{
{
   aps_preview = "on";
   push_spot ();
   mark_buffer ();
   print_region ();
   pop_spot ();
   aps_preview = "off";
}
%}}}

%!%+
%\function{print_region_preview}
%\synopsis{print preview of the marked region}
%\usage{print_region_preview ()}
%\description
% This function is called to preview the marked region. It sets variable
% \var{aps_preview} to \var{on} and calls then function \var{print_region}
% for previewing. After that \var{aps_preview} will be reset to \var{off}.
% This function returns nothing.
% \seealso{print_region}
%!%-
define print_region_preview() %{{{
{
   aps_preview = "on";
   print_region();
   aps_preview = "off";
}
%}}}

%!%+
%\function{set_default_printer}
%\synopsis{define default printer}
%\usage{set_default_printer (Integer_Type id)}
%\description
% This function is called to set the default printer, which will be used
% for preview/printing.
% This function returns nothing.
%!%-
define set_default_printer(id) %{{{
{
   default_printer = id;
}
%}}}

% taken from jed help for strchop()
static define sort_string_list (a) %{{{
{
   variable i, b, c;
   b = strchop (a, ',', 0);

   i = array_sort (b, &strcmp);
   b = b[i];   % rearrange

   % Convert array back into comma separated form
   return strjoin (b, ",");
}
%}}}

%!%+
%\function{extract_comment_definition}
%\synopsis{scan a jed mode for comment definition}
%\usage{extract_comment_definition (String_Type file)}
%\description
% This function is called to scan the given mode file (\var{file}) for
% comment definition. It searches for the string "define syntax" and
% extracts the comment definition. This definition will be used in
% \var{create_a2ps_style_sheet}
% This function returns the comment definition format for a2ps style sheets.
% \example
% SLang mode   : define_syntax ("%", "", '%', $1);
% return value : "%" Comment
% \seealso{create_a2ps_style_sheet}
%!%-
static define extract_comment_definition(file) %{{{
{
   variable pos=0;
   variable syn="";
   variable parts = String_Type[10];
   variable nth = 0;
   variable part;
   variable comment_str = "", comment1, comment2;

   find_file(file);
   bob();
   do
     {
	bol();
	pos = ffind("define_syntax");
	if (pos != 0)
	  {
	     syn = substr(line_as_string,pos+1, -1);
	     parts = strchop(syn,',',0);
	     nth = 0;
	     while (NULL != extract_element (syn, nth, ','))
	       {
		  nth++;
	       }
	     if (nth == 4)
	       {
		  part = extract_element (syn, 2, ',');
		  part = strtrans(part, " ","");
		  if (strcmp(part,string("'%'")) == 0)
		    {
		       comment1 = extract_element (syn, 0, ',');
		       comment1 = strtrans(comment1, " ","");
		       comment1 = strtrans(comment1, "(","");
		       comment2 = extract_element (syn, 1, ',');
		       comment2 = strtrans(comment2, " ","");
		       if (strcmp(comment2,string("\"\"")) == 0)
			 {
			    comment2 = "";
			 }
		       comment_str = strcat(comment_str, comment1, " Comment ", comment2, "\n");
		    }
	       }
	  }
     }
   while (down_1());
   delbuf(whatbuf());
   return comment_str;
}

%}}}

%!%+
%\function{create_a2ps_style_sheet}
%\synopsis{Create an a2ps style sheet from existing jed mode definition}
%\usage{create_a2ps_style_sheet (String_Type mode)}
%\description
% This function is called to create an a2ps style sheet (*.ssh) for
% a given (existing) jed mode.
%
% If \var{mode} is empty, the function will ask for a mode name. The modename
% has to be exactly the string used for the syntax table definition of
% the mode.
%
% Look for lines like (example for tcl mode):
%         $1 = "TCL";
%         create_syntax_table ($1);
% in the <mode>.sl file to catch the real mode name.
%
% The created style sheet will contain the a2ps style sheet header,
% definition for comment lines and all keywords defined for the jedmode
% (via define_keywords_n).
%!%-
define create_a2ps_style_sheet(mode) %{{{
{
   variable sheet_file;
   variable kws, kws_str="", kws_substr="";
   variable len;
   variable n=0;
   variable i, j;
   variable mode_file = "";
   variable comment_str;

   if (mode == "")
     {
	mode = read_mini("Enter exact(!) mode name (e.g. TCL, SLang, awk)",get_mode_name,"");
     }
   % SLang mode uses syntax table SLANG (instead of SLang,
   % maybe to be changed in slmode.sl ?)
   % therefore sheet_file name has to be created before mode name modification
   sheet_file = strcat(a2ps_sheet_dir, mode, ".ssh");
   if (mode == "SLang")
     {
	mode = strup(mode);
     }

#ifdef UNIX
   mode_file = strcat(JED_ROOT,"/lib/",mode,"mode.sl");
#endif
#ifdef MSWINDOWS
   mode_file = strcat(JED_ROOT,"\\lib\\",mode,"mode.sl");
#endif
   mode_file = read_mini("Enter mode filename","",mode_file);

   if (file_status(mode_file) != 1)
     {
	flush(strcat(mode_file, " does not exist!"));
	return;
     }
   % load mode_file, necessary for evaluation of syntax table
   % ERROR_BLOCK necessary, if a mode file couldn't be loaded two times
   ERROR_BLOCK
     {
	_clear_error();
     }
   require(mode_file);
   comment_str = extract_comment_definition(mode_file);

   if (file_status(sheet_file) == 1)
     {
	if ( get_yes_no(strcat("Overwrite ", sheet_file)) == 0 )
	  {
	     return;
	  }
     }

   find_file(sheet_file);
   erase_buffer();

   insert(strcat("# ", mode, ".ssh --- Sheet definitions for ", strup(mode), " scripts\n"));
   insert("# This style sheet is based on stylesheets provided by Edward Arthur, Akim Demaille, Miguel Santana\n");
   insert("# Copyright (c) 1999 Edward Arthur, Akim Demaille, Miguel Santana\n");
   insert("#\n");
   insert("\n");
   insert("#\n");
   insert("# This file is not part of a2ps.\n");
   insert("# It is automatically created from within jed using functions\n");
   insert(strcat("# in apsmode.sl (V",aps_version, ").\n"));
   insert("#\n");
   insert("# This program is free software; you can redistribute it and/or modify\n");
   insert("# it under the terms of the GNU General Public License as published by\n");
   insert("# the Free Software Foundation; either version 2, or (at your option)\n");
   insert("# any later version.\n");
   insert("#\n");
   insert("# This program is distributed in the hope that it will be useful,\n");
   insert("# but WITHOUT ANY WARRANTY; without even the implied warranty of\n");
   insert("# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n");
   insert("# GNU General Public License for more details.\n");
   insert("#\n");
   insert("# You should have received a copy of the GNU General Public License\n");
   insert("# along with this program; see the file COPYING.  If not, write to\n");
   insert("# the Free Software Foundation, 59 Temple Place - Suite 330,\n");
   insert("# Boston, MA 02111-1307, USA.\n");
   insert("\n");
   insert(strcat("## 1.0 ", get_realname(), "\n"));
   insert("# Initial implementation.\n");
   insert("\n");
   insert(strcat("style ", strup(mode), " is\n"));
   insert("\n");
   insert(strcat("written by \"", get_realname(), ", ", get_emailaddress, "\"\n"));
   insert("version is 1.0\n");
   insert("requires a2ps version 4.9.7\n");
   insert("\n");
   insert("   \n");
   insert("\n");

   insert("documentation is\n");
   insert(strcat("   \"This style is devoted to the ", strup(mode), " language.\n"));
   insert("   It has been automatically created from within editor jed\n");
   insert(strcat("   using apsmode.sl (V",aps_version, ")\"\n"));
   insert("end documentation\n");
   insert("\n");
   insert("alphabets are\n");
   insert("   \"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0\"\n");
   insert("case sensitive\n");

   insert("\n");
   % if syntax table is not defined as it could happen for dfa highlighting
   % don't grep for keywords, otherwise it would lead to an error
   if (( NULL != what_syntax_table()) & ("DEFAULT" != what_syntax_table()))
     {
	insert("keywords in Keyword_strong are\n");

	for (i = 1; i <= 30; i++)
	  {
	     kws = define_keywords_n (mode, "", i, n);
	     len = strlen(kws);
	     if (len > 0)
	       {
		  for (j = 1; j <= len; j=j+i)
		    {
		       kws_substr = substr(kws,j,i);
		       % there are several keywords in a2ps keyword list, which
		       % needs to be quoted
		       switch (kws_substr)
			 { kws_substr == "alphabet" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "alphabets" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "are" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "case" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "documentation" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "end" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "exceptions" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "first" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "in" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "insensitive" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "is" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "keywords" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "operators" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "optional" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "second" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "sensitive" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "sequences" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "style" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "Comment" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "Comment_strong" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "Encoding" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "Error" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "Index1" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "Index2" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "Index3" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "Index4" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "Invisible" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "Keyword" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "Keyword_strong" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "Label" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "Label_strong" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "Plain" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "String" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "Symbol" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "Tag1" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "Tag2" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "Tag3" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "Tag4" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "C-char" : kws_substr = strcat("\"", kws_substr, "\"");}
			 { kws_substr == "C-string" : kws_substr = strcat("\"", kws_substr, "\"");};

		       if (kws_str == "")
			 {
			    kws_str = kws_substr;
			 }
		       else
			 {
			    kws_str = strcat(kws_str, ",", kws_substr);
			 }
		    }
	       }
	  }
	sort_string_list(kws_str);
	insert(kws_str);
	insert("\n");
	insert("end keywords\n");
	insert("\n");
     }

   insert("sequences are\n");
   insert(comment_str);
   insert("\n");
   insert("end sequences\n");
   insert("\n");
   insert("end style\n");
   bob();
   return;
}
%}}}

%!%+
%\function{aps_help}
%\synopsis{apsmode help}
%\usage{aps_help ()}
%\description
% This function opens the aps help file
% This function returns nothing.
%!%-
define aps_help () %{{{
{
   jed_easy_help(aps_help_file);
}

%}}}

% Keybindings
% (none)

%---8&lt;------- (end of apsmode.sl)--------


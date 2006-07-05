% apsmode -*- mode: slang; mode: fold; -*-

% apsmode
% Copyright (c) 2003-2006 Thomas Koeckritz (tkoeckritz at gmx dot de)
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
%                  add variable to choose menu-support (Apsmode_menu)
%                  add variable to choose deletion of ps-file (Apsmode_del_ps_file)
%                  handling of options for WINDOWS corrected/improved
% 1.5   2005-04-14 added handling of font size
%                  added saving of current parameters in apsconf format
% 1.5.1 2005-11-21 modified apsconf.sl: GM: use path_concat() for Apsmode_tmp_dir
% 1.5.2 2006-06-01 made user-definable variables custom_variables (G Milde)
% 2.0   2006-06-02 lot of modifications done to integrate apsmode better into
%                  jed-libraries (triggered by G.Milde for usability with
%                  debian)
%                  - include apsconf.sl into apsmode.sl
%                    apsconf.sl could be still be used optional with
%                        () = evalfile("apsconf.sl");
%                  - make more variables custom_variable
%                  - rename custom-variables to "Apsmode_<xyz>"
%                  - make aps_pid a private variable
%                  - rename directory /apsconf to /apsmode
%                  - rename aps.hlp to apsmode.hlp
%                  - Apsmode_a2ps_sheet_dir removed (style sheets have to be
%                    in the jed library path)
%                  - make Apsmode_help_file a private variable
%                    help file must be located in jed library path
%                  - make aps_max_no_printers a private variable
%                  - function path_rel removed
%                  - apsmode.hlp adapted
%                  - apsconf.sl has always to be loaded separately by the user
%                    Therefore variable Apsmode_config_file has been removed.
%                    (also editing/reloading of apsconf.sl via Print-Menu
%                     will not be supported anymore)
%                  - function show_apsmode_settings added
% 2.1   2006-06-15 some more proposals by GM
%                  - make Apsmode_Printer, Apsmode_style_sheet public variables
%                  - redefine position of popup-menu
% 2.2   2006-06-19 - jed_date_time modified
%                  - QuickPrint menu entries show now current settings
%                  - change Apsmode_Printers[].setup --> Apsmode_Printers[].setupname
%                  - change aps_pid --> setup
%                  - more QuickPrint menu entries added
%                  
% Description
% -----------
% JED-mode to support printing from jed using a2ps and ghostview.
% This mode has been designed for and successfully tested
% under
%  - UNIX (SunOS 5.8)
%  - WINDOWS (Windows NT 4.0, Windows 2000, Windows ME)
% see also apsmode.hlp
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
% - printer definitions in a separate configuration file possible (apsconf.sl)
%   covering most of a2ps layout features
% - QuickPrint: modification of a printer setting for the open jed session
%   allows quick (small) changes of a defined printer setting,
%   changes will not be saved!
% - basic support for creation of a2ps style sheets from JED modes
%   (scans xyz-mode.sl for keywords)
%
% Requirements
% ------------
% jed 0.99.18
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
% jed.rc:     Add the following line to enable text menus in WINGUI
%               () = evalfile("menus");
%             Load the apsmode
%               require("apsmode");
%             Append and customize personal a2ps/printer settings from
%             apsconf.sl or customize apsconf.sl and eval with
%               () = evalfile("apsconf");
%             Maybe you have to copy the file to your personal
%             jed files first, in Unix this could be "~/.jed/lib/"
%             in this case, make sure it is in the jed-library-path (see
%             set_jed_library_path())
% see also apsmode.hlp for details (esp. conversion from V1.5 to V2.0)
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
% Global Variables
% ----------------
% for description see below in the coding
%   Apsmode_a2ps_cmd
%   Apsmode_default_printer
%   Apsmode_del_ps_file
%   Apsmode_menu
%   Apsmode_Printers
%   Apsmode_style_sheet
%   Apsmode_tmp_dir
%   Apsmode_tmp_file
%
% Notes
% -----
% - if no postscript printer is installed on your system use ghostview
%   for printing
% - error handling under WINDOWS is not working properly,
%   if something strange happened during printing, look at the
%   print-log buffer (via function show_print_log() )
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
%   e.g. Apsmode_Printers[setup].footer_left = " ";
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

% --- requirements ---

% from jed's standard library
% none required

% non-standard extensions
% none required

% --- requirements ---

% Helper functions for Postscript printing %{{{

% global variables, settings

% printer properties definition
typedef struct
{
   setupname,
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

%%%%%%%%%%%%%%% private variables begin %%%%%%%%%%%%%
%
% do'nt change this block
%
% this variable will be used to give the path/filename of the buffer to a2ps
private variable aps_jedfilename = "";
% this variable will be used to give the date/time of printing to a2ps
private variable aps_jeddatetime = "";

private variable setup = 0;
private variable aps_preview = "off";
private variable aps_help_file = expand_jedlib_file("apsmode.hlp");
% number of printers which can be defined in apsconf.sl
% (default = 50 should be sufficient in most cases)
private variable aps_max_no_printers = 50;
private variable menu_entry = "";

% do not change the definitions for Apsmode_Printers and Apsmode_style_sheet
% here, but you can define new values for these structures later (see below)
% e.g.
%    Apsmode_Printers[setup].description = "Default Printer";
% or
%    Apsmode_style_sheet["awk"] = 1;
%
public variable Apsmode_Printers = Printer_Type[aps_max_no_printers];
public variable Apsmode_style_sheet = Assoc_Type[Integer_Type];

% version information
private variable aps_version = "2.2";
private variable aps_creation_date = "2006-06-19";
private variable aps_jed_tested = "0.99-18";
private variable aps_creator = "tkoeckritzatgmxdotde";

%%%%%%%%%%%%%%% private variables end %%%%%%%%%%%%%

%}}}

%%%%%%%%%%%%%%% custom_variables begin %%%%%%%%%%%%%
% define custom variables and set default values which
% could be configured in jed.rc or a local|private apsconf.sl
%

% Directory used to hold temporary files (defined in site.sl since jed 0.99.18)
custom_variable("Jed_Tmp_Directory", getenv("TEMP"));
if (Jed_Tmp_Directory == NULL)
  Jed_Tmp_Directory = getenv("TMP");
if (Jed_Tmp_Directory == NULL)
#ifdef MSWINDOWS
  Jed_Temp_Dir = "C:\\temp";
#elseif
  Jed_Tmp_Directory = "/tmp";
#endif

% OS specific command to run a2ps (a2ps programm call (with path))
#ifdef UNIX
custom_variable("Apsmode_a2ps_cmd", "a2ps");
#endif

#ifdef MSWINDOWS
custom_variable("Apsmode_a2ps_cmd", "D:\\Programs\\a2ps\\bin\\a2ps.exe");
#endif

% directory for temporary files and ps file
custom_variable("Apsmode_tmp_dir", path_concat(Jed_Tmp_Directory, "")); % ensure trailing separator

% name of the ps file, which will be created by a2ps
%custom_variable("Apsmode_tmp_file", strcat(Apsmode_tmp_dir, "print_from_jed.ps"));
custom_variable("Apsmode_tmp_file", path_concat(Apsmode_tmp_dir, "print_from_jed.ps"));

% id of the default printer
% id = 0 is reserved for QuickPrint, don't use it !
% aps_max_no_printers > id of Apsmode_default_printer > 0
custom_variable("Apsmode_default_printer", 1);

% defines, where the Print popup menu should be created
% alternatives: "Global.&File.&Print"    CUA compatible
%               "Global.&Print"          top level (add a keybinding for Alt-P)
%               "Global.S&ystem.&Print"
%               ""                       no print menu
% be aware that quickprint settings are only available via menu
% wmenu is not supported
custom_variable("Apsmode_menu", "Global.&File.&Print");

% delete created ps file after printing/viewing (0 = keep, 1 = delete)
custom_variable("Apsmode_del_ps_file", 1);

% define a default printer here
% initially no real printer is defined
% could be done by a jed admin locally in a config file (defaults.sl or
% /etc/jed.conf on UNIX) or by the user in jed.rc (or .jedrc)
% print_cmd and view_cmd are examples for UNIX/MSWINDOWS
% for details see printer definition description in apsmode.hlp
% for more printer setups (or user defined ones ), add the definitions in
% .jedrc or use a separate apsconf.sl file evaluated from .jedrc
setup++;
Apsmode_Printers[setup].setupname = "default printer not defined yet";
Apsmode_Printers[setup].name = "default_printer_name";
Apsmode_Printers[setup].description = "Default Printer";
Apsmode_Printers[setup].columns = "2";
Apsmode_Printers[setup].rows = "1";
Apsmode_Printers[setup].fontsize = "6points";
Apsmode_Printers[setup].chars = "80:100";
Apsmode_Printers[setup].borders = "on";
Apsmode_Printers[setup].orientation = "landscape";
Apsmode_Printers[setup].medium = "A4";
Apsmode_Printers[setup].sides = "2";
Apsmode_Printers[setup].truncate = "on";
Apsmode_Printers[setup].linenumbers = "5";
Apsmode_Printers[setup].copies = "1";
Apsmode_Printers[setup].major = "columns";
Apsmode_Printers[setup].margin = "5";
Apsmode_Printers[setup].header = "";
Apsmode_Printers[setup].title_left = "";
Apsmode_Printers[setup].title_center = "";
Apsmode_Printers[setup].title_right = "";
Apsmode_Printers[setup].footer_left = "JEDDATETIME";
Apsmode_Printers[setup].footer_center = "JEDFILENAME";
Apsmode_Printers[setup].footer_right = "%s./%s#";
Apsmode_Printers[setup].color = "bw";
Apsmode_Printers[setup].pretty = "on";
Apsmode_Printers[setup].print_cmd = "";
Apsmode_Printers[setup].view_cmd = "";
#ifdef UNIX
Apsmode_Printers[setup].print_cmd = strcat("lpr -P ", Apsmode_Printers[setup].name, " ", Apsmode_tmp_file);
Apsmode_Printers[setup].view_cmd = strcat("gv ", Apsmode_tmp_file);
#endif
#ifdef MSWINDOWS
Apsmode_Printers[setup].print_cmd = strcat("D:\\Programs\\gstools\\gsview\\gsview32.exe ", Apsmode_tmp_file);
Apsmode_Printers[setup].view_cmd = strcat("D:\\Programs\\gstools\\gsview\\gsview32.exe ", Apsmode_tmp_file);
#endif
Apsmode_Printers[setup].copy_of = 0;

% array containing all jed mode names (as index), for which a
% jed specific style sheet for a2ps should be used
% style sheets must be available in jed library path
% can be created by function <create_a2ps_style_sheet(mode)>
Apsmode_style_sheet["SLang"] = 1;


%%%%%%%%%%%%%%% custom_variables variables end %%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% There is no need to change something below this line ! %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% define QuickPrint settings as copy of default printer
%!%+
%\function{qp_is_copy_of}
%\synopsis{fill QuickPrint data with a predefined printer setup}
%\usage{qp_is_copy_of (Integer_Type pid_in)}
%\description
% This function is used to fill QuickPrint data with a predefined printer
% setup given by \var{pid_in}.
% The QuickPrint setup uses index=0 in \var{Apsmode_Printers}.
% This function returns nothing.
%!%-
define qp_is_copy_of(pid_in) %{{{
{
   variable setup = 0;
   Apsmode_Printers[setup].setupname = "QuickPrint";
   Apsmode_Printers[setup].name = Apsmode_Printers[pid_in].name;
   Apsmode_Printers[setup].description = Apsmode_Printers[pid_in].description;
   Apsmode_Printers[setup].columns = Apsmode_Printers[pid_in].columns;
   Apsmode_Printers[setup].rows = Apsmode_Printers[pid_in].rows;
   Apsmode_Printers[setup].fontsize = Apsmode_Printers[pid_in].fontsize;
   Apsmode_Printers[setup].chars = Apsmode_Printers[pid_in].chars;
   Apsmode_Printers[setup].borders = Apsmode_Printers[pid_in].borders;
   Apsmode_Printers[setup].orientation = Apsmode_Printers[pid_in].orientation;
   Apsmode_Printers[setup].medium = Apsmode_Printers[pid_in].medium;
   Apsmode_Printers[setup].sides = Apsmode_Printers[pid_in].sides;
   Apsmode_Printers[setup].truncate = Apsmode_Printers[pid_in].truncate;
   Apsmode_Printers[setup].linenumbers = Apsmode_Printers[pid_in].linenumbers;
   Apsmode_Printers[setup].copies = Apsmode_Printers[pid_in].copies;
   Apsmode_Printers[setup].major = Apsmode_Printers[pid_in].major;
   Apsmode_Printers[setup].margin = Apsmode_Printers[pid_in].margin;
   Apsmode_Printers[setup].header = Apsmode_Printers[pid_in].header;
   Apsmode_Printers[setup].title_left = Apsmode_Printers[pid_in].title_left;
   Apsmode_Printers[setup].title_center = Apsmode_Printers[pid_in].title_center;
   Apsmode_Printers[setup].title_right = Apsmode_Printers[pid_in].title_right;
   Apsmode_Printers[setup].footer_left = Apsmode_Printers[pid_in].footer_left;
   Apsmode_Printers[setup].footer_center = Apsmode_Printers[pid_in].footer_center;
   Apsmode_Printers[setup].footer_right = Apsmode_Printers[pid_in].footer_right;
   Apsmode_Printers[setup].color = Apsmode_Printers[pid_in].color;
   Apsmode_Printers[setup].pretty = Apsmode_Printers[pid_in].pretty;
   Apsmode_Printers[setup].print_cmd = Apsmode_Printers[pid_in].print_cmd;
   Apsmode_Printers[setup].view_cmd = Apsmode_Printers[pid_in].view_cmd;
   Apsmode_Printers[setup].copy_of = pid_in;
   return;
}

%}}}

%!%+
%\function{jed_date_time}
%\synopsis{create a Date/Time string}
%\usage{String_Type jed_date_time ()}
%\description
% This function is used to create Date/Time string to be used as value
% for \var{aps_jeddatetime}.
% This function returns a date/time string.
% \example
%   aps_jeddatetime = jed_date_time();
%   value of aps_jeddatetime will be "2004-Feb-29, 14:03:57"
%!%-
static define jed_date_time() %{{{
{
   return strftime("%Y-%b-%d, %H:%M:%S");
}

%}}}

%%%%%%%%%%%%%%%%%%%%% Menu Entries Begin %%%%%%%%%%%%%%%%%%%%%%% %{{{
static define create_menu_string (menu_string, value)
{
   variable menu_entry;

   % & will be used to highlight a menu letter
   % so do not take its length into account
   if (is_substr(menu_string, "&"))
     {
        menu_string = sprintf("%-19s(",menu_string);
     }
   else
     {
        menu_string = sprintf("%-18s(",menu_string);
     }

   value = str_delete_chars(value,"\.");
   if (strlen(value) > 12)
     {
        menu_entry = strcat(menu_string, substr(value,1,12), " >>)");
     }
   else
     {
        menu_entry = strcat(menu_string, value, ")");
     }
   return menu_entry;
}

static define default_printer_callback (popup)
{
   menu_append_item (popup, string(Apsmode_Printers[Apsmode_default_printer].setupname), strcat("show_printer_settings(",string(Apsmode_default_printer),",1)"));
}

define show_default_printer_menu(setting, menu)
{
   variable menu_entry ="";

   if (Apsmode_default_printer == 0)
     {
        menu_entry = strcat("Show &Default Printer  (QuickPrint)");
     }
   else
     {
        menu_entry = strcat("Show &Default Printer  (setup ", string(Apsmode_default_printer), ")");
     }

   menu_delete_item(strcat (Apsmode_menu, ".", menu_entry));

   eval(setting);
   if (Apsmode_default_printer == 0)
     {
        menu_entry = strcat("Show &Default Printer  (QuickPrint)");
     }
   else
     {
        menu_entry = strcat("Show &Default Printer  (setup ", string(Apsmode_default_printer), ")");
     }
   menu_insert_popup (6, Apsmode_menu, menu_entry);

   menu_set_select_popup_callback (strcat (Apsmode_menu, ".", menu_entry), &default_printer_callback);

   menu_select_menu(strcat(Apsmode_menu, menu));

   return;

}

static define set_default_printer_callback (popup)
{
   variable i;
   for (i = 0; i <= aps_max_no_printers-1; i++)
     {
        if (Apsmode_Printers[i].setupname != NULL)
          {
             if (i == Apsmode_default_printer)
               {
                  menu_append_item (popup, strcat("* ", sprintf("%2s  ",string(i)), Apsmode_Printers[i].setupname), strcat("show_default_printer_menu(\"set_default_printer(", string(i),")\",)"));
               }
             else
               {
                  menu_append_item (popup, strcat("  ", sprintf("%2s  ",string(i)), Apsmode_Printers[i].setupname), strcat("show_default_printer_menu(\"set_default_printer(", string(i),")\",\"\")"));
               }
          }
     }
   return;
}
static define show_default_printer_callback (popup)
{
   variable i;
   for (i = 0; i <= aps_max_no_printers-1; i++)
     {
        if (Apsmode_Printers[i].setupname != NULL)
          {
             if (i == Apsmode_default_printer)
               {
                  menu_append_item (popup, strcat("* ", sprintf("%2s  ",string(i)), string(Apsmode_Printers[i].setupname)), strcat("show_printer_settings(",string(i),",1)"));
               }
             else
               {
                  menu_append_item (popup, strcat("  ", sprintf("%2s  ",string(i)), string(Apsmode_Printers[i].setupname)), strcat("show_printer_settings(",string(i),",1)"));
               }
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
% This function returns nothing, but opens the QuickPrint menu again
% \example
% The following command appends a menu item (called "A4")
% Clicking on that item will execute the code
%  "Apsmode_Printers[0].medium=\"A4\""
%       menu_append_item (popup, strcat("* ", "A&4"), strcat("set_qp(\"Apsmode_Printers[0].medium=\\\"A4\\\"\")"));
%!%-
define set_qp(setting)
{
   eval(setting);
   % intention is to open QuickPrint menu again
   menu_select_menu(strcat(Apsmode_menu, ".&QuickPrint"));
   return;
}
static define set_qp_orientation_callback (popup)
{
   if (strup(Apsmode_Printers[0].orientation) == "PORTRAIT")
     {
        menu_append_item (popup, strcat("* ", "&portrait"), strcat("set_qp(\"Apsmode_Printers[0].orientation=\\\"portrait\\\"\")"));
        menu_append_item (popup, strcat("  ", "&landscape"), strcat("set_qp(\"Apsmode_Printers[0].orientation=\\\"landscape\\\"\")"));
     }
   if (strup(Apsmode_Printers[0].orientation) == "LANDSCAPE")
     {
        menu_append_item (popup, strcat("  ", "&portrait"), strcat("set_qp(\"Apsmode_Printers[0].orientation=\\\"portrait\\\"\")"));
        menu_append_item (popup, strcat("* ", "&landscape"), strcat("set_qp(\"Apsmode_Printers[0].orientation=\\\"landscape\\\"\")"));
     }
   return;
}
static define set_qp_no_columns_callback (popup)
{
   variable i;
   for (i = 1; i <= 4; i++)
     {
        if (Apsmode_Printers[0].columns == string(i))
          {
             menu_append_item (popup, strcat("* ", string(i)), strcat("set_qp(\"Apsmode_Printers[0].columns=\\\"", string(i), "\\\"\")"));
          }
        else
          {
             menu_append_item (popup, strcat("  ", string(i)), strcat("set_qp(\"Apsmode_Printers[0].columns=\\\"", string(i), "\\\"\")"));
          }
     }
   return;
}
static define set_qp_no_rows_callback (popup)
{
   variable i;
   for (i = 1; i <= 4; i++)
     {
        if (Apsmode_Printers[0].rows == string(i))
          {
             menu_append_item (popup, strcat("* ", string(i)), strcat("set_qp(\"Apsmode_Printers[0].rows=\\\"", string(i), "\\\"\")"));
          }
        else
          {
             menu_append_item (popup, strcat("  ", string(i)), strcat("set_qp(\"Apsmode_Printers[0].rows=\\\"", string(i), "\\\"\")"));
          }
     }
   return;
}
static define set_qp_no_sides_callback (popup)
{
   variable i;
   for (i = 1; i <= 2; i++)
     {
        if (Apsmode_Printers[0].sides == string(i))
          {
             menu_append_item (popup, strcat("* ", string(i)), strcat("set_qp(\"Apsmode_Printers[0].sides=\\\"", string(i), "\\\"\")"));
          }
        else
          {
             menu_append_item (popup, strcat("  ", string(i)), strcat("set_qp(\"Apsmode_Printers[0].sides=\\\"", string(i), "\\\"\")"));
          }
     }
   return;
}
static define set_qp_borders_callback (popup)
{
   if (strup(Apsmode_Printers[0].borders) == "ON")
     {
        menu_append_item (popup, strcat("* ", "o&n"), strcat("set_qp(\"Apsmode_Printers[0].borders=\\\"on\\\"\")"));
        menu_append_item (popup, strcat("  ", "o&ff"), strcat("set_qp(\"Apsmode_Printers[0].borders=\\\"off\\\"\")"));
     }
   if (strup(Apsmode_Printers[0].borders) == "OFF")
     {
        menu_append_item (popup, strcat("  ", "o&n"), strcat("set_qp(\"Apsmode_Printers[0].borders=\\\"on\\\"\")"));
        menu_append_item (popup, strcat("* ", "o&ff"), strcat("set_qp(\"Apsmode_Printers[0].borders=\\\"off\\\"\")"));
     }
   return;
}
static define set_qp_no_copies_callback (popup)
{
   variable i;
   for (i = 1; i <= 10; i++)
     {
        if (Apsmode_Printers[0].copies == string(i))
          {
             menu_append_item (popup, strcat("* ", string(i)), strcat("set_qp(\"Apsmode_Printers[0].copies=\\\"", string(i), "\\\"\")"));
          }
        else
          {
             menu_append_item (popup, strcat("  ", string(i)), strcat("set_qp(\"Apsmode_Printers[0].copies=\\\"", string(i), "\\\"\")"));
          }
     }
   return;
}
static define set_qp_linenumbers_callback (popup)
{
   variable i;
   for (i = 0; i <= 10; i++)
     {
        if (Apsmode_Printers[0].linenumbers == string(i))
          {
             menu_append_item (popup, strcat("* ", string(i)), strcat("set_qp(\"Apsmode_Printers[0].linenumbers=\\\"", string(i), "\\\"\")"));
          }
        else
          {
             menu_append_item (popup, strcat("  ", string(i)), strcat("set_qp(\"Apsmode_Printers[0].linenumbers=\\\"", string(i), "\\\"\")"));
          }
     }
   return;
}
static define set_qp_truncate_callback (popup)
{
   if (strup(Apsmode_Printers[0].truncate) == "ON")
     {
        menu_append_item (popup, strcat("* ", "o&n"), strcat("set_qp(\"Apsmode_Printers[0].truncate=\\\"on\\\"\")"));
        menu_append_item (popup, strcat("  ", "o&ff"), strcat("set_qp(\"Apsmode_Printers[0].truncate=\\\"off\\\"\")"));
     }
   if (strup(Apsmode_Printers[0].truncate) == "OFF")
     {
        menu_append_item (popup, strcat("  ", "o&n"), strcat("set_qp(\"Apsmode_Printers[0].truncate=\\\"on\\\"\")"));
        menu_append_item (popup, strcat("* ", "o&ff"), strcat("set_qp(\"Apsmode_Printers[0].truncate=\\\"off\\\"\")"));
     }
   return;
}
static define set_qp_medium_callback (popup)
{
   if (strup(Apsmode_Printers[0].medium) == "A4")
     {
        menu_append_item (popup, strcat("* ", "A&4"), strcat("set_qp(\"Apsmode_Printers[0].medium=\\\"A4\\\"\")"));
        menu_append_item (popup, strcat("  ", "A&3"), strcat("set_qp(\"Apsmode_Printers[0].medium=\\\"A3\\\"\")"));
        menu_append_item (popup, strcat("  ", "&Letter"), strcat("set_qp(\"Apsmode_Printers[0].medium=\\\"Letter\\\"\")"));
     }
   if (strup(Apsmode_Printers[0].medium) == "A3")
     {
        menu_append_item (popup, strcat("  ", "A&4"), strcat("set_qp(\"Apsmode_Printers[0].medium=\\\"A4\\\"\")"));
        menu_append_item (popup, strcat("* ", "A&3"), strcat("set_qp(\"Apsmode_Printers[0].medium=\\\"A3\\\"\")"));
        menu_append_item (popup, strcat("  ", "&Letter"), strcat("set_qp(\"Apsmode_Printers[0].medium=\\\"Letter\\\"\")"));
     }
   if (strup(Apsmode_Printers[0].medium) == "LETTER")
     {
        menu_append_item (popup, strcat("  ", "A&4"), strcat("set_qp(\"Apsmode_Printers[0].medium=\\\"A4\\\"\")"));
        menu_append_item (popup, strcat("  ", "A&3"), strcat("set_qp(\"Apsmode_Printers[0].medium=\\\"A3\\\"\")"));
        menu_append_item (popup, strcat("* ", "&Letter"), strcat("set_qp(\"Apsmode_Printers[0].medium=\\\"Letter\\\"\")"));
     }
   return;
}
static define set_qp_color_callback (popup)
{
   if (strup(Apsmode_Printers[0].color) == "BW")
     {
        menu_append_item (popup, strcat("* ", "&bw"), strcat("set_qp(\"Apsmode_Printers[0].color=\\\"bw\\\"\")"));
        menu_append_item (popup, strcat("  ", "&color"), strcat("set_qp(\"Apsmode_Printers[0].color=\\\"color\\\"\")"));
     }
   if (strup(Apsmode_Printers[0].color) == "COLOR")
     {
        menu_append_item (popup, strcat("  ", "&bw"), strcat("set_qp(\"Apsmode_Printers[0].color=\\\"bw\\\"\")"));
        menu_append_item (popup, strcat("* ", "&color"), strcat("set_qp(\"Apsmode_Printers[0].color=\\\"color\\\"\")"));
     }
   return;
}
static define set_qp_printer_callback (popup)
{
   variable i;
   variable action;
   action = strcat("read_mini\\\(\\\"Enter print command\\\",\\\"", Apsmode_Printers[0].print_cmd,"\\\",\\\"", Apsmode_Printers[0].print_cmd,"\\\"\\\)");
   action = strcat("Apsmode_Printers[0].print_cmd=", action);
   action = strcat("set_qp(\"", action, "\")");
   menu_append_item (popup, "&Add temporary Print Command", action);
   for (i = 0; i <= aps_max_no_printers-1; i++)
     {
        if (Apsmode_Printers[i].setupname != NULL)
          {
             if (Apsmode_Printers[0].print_cmd == Apsmode_Printers[i].print_cmd)
               {
                  menu_append_item (popup, strcat("* ", Apsmode_Printers[i].print_cmd), strcat("set_qp(\"Apsmode_Printers[0].print_cmd=\\\"", Apsmode_Printers[i].print_cmd, "\\\"\")"));
               }
             else
               {
                  menu_append_item (popup, strcat("  ", Apsmode_Printers[i].print_cmd), strcat("set_qp(\"Apsmode_Printers[0].print_cmd=\\\"", Apsmode_Printers[i].print_cmd, "\\\"\")"));
               }
          }
     }
   return;
}
static define set_qp_view_callback (popup)
{
   variable i;
   variable action;
   action = strcat("read_mini\\\(\\\"Enter view command\\\",\\\"", Apsmode_Printers[0].view_cmd,"\\\",\\\"", Apsmode_Printers[0].view_cmd,"\\\"\\\)");
   action = strcat("Apsmode_Printers[0].view_cmd=", action);
   action = strcat("set_qp(\"", action, "\")");
   menu_append_item (popup, "&Add temporary View Command", action);
   for (i = 0; i <= aps_max_no_printers-1; i++)
     {
        if (Apsmode_Printers[i].setupname != NULL)
          {
             if (Apsmode_Printers[0].view_cmd == Apsmode_Printers[i].view_cmd)
               {
                  menu_append_item (popup, strcat("* ", Apsmode_Printers[i].view_cmd), strcat("set_qp(\"Apsmode_Printers[0].view_cmd=\\\"", Apsmode_Printers[i].view_cmd, "\\\"\")"));
               }
             else
               {
                  menu_append_item (popup, strcat("  ", Apsmode_Printers[i].view_cmd), strcat("set_qp(\"Apsmode_Printers[0].view_cmd=\\\"", Apsmode_Printers[i].view_cmd, "\\\"\")"));
               }
          }
     }
   return;
}
static define set_qp_header_callback (popup)
{
   variable i;
   variable action;
   action = strcat("read_mini\\\(\\\"Enter header string\\\",\\\"", Apsmode_Printers[0].header,"\\\",\\\"", Apsmode_Printers[0].header,"\\\"\\\)");
   action = strcat("Apsmode_Printers[0].header=", action);
   action = strcat("set_qp(\"", action, "\")");
   menu_append_item (popup, "&Add temporary Header String", action);
   for (i = 0; i <= aps_max_no_printers-1; i++)
     {
        if (Apsmode_Printers[i].setupname != NULL)
          {
             if (Apsmode_Printers[i].header != "")
               {
                  if (Apsmode_Printers[0].header == Apsmode_Printers[i].header)
                    {
                       menu_append_item (popup, strcat("* ", Apsmode_Printers[i].header), strcat("set_qp(\"Apsmode_Printers[0].header=\\\"", Apsmode_Printers[i].header, "\\\"\")"));
                    }
                  else
                    {
                       menu_append_item (popup, strcat("  ", Apsmode_Printers[i].header), strcat("set_qp(\"Apsmode_Printers[0].header=\\\"", Apsmode_Printers[i].header, "\\\"\")"));
                    }
               }
          }
     }
   return;
}
static define set_qp_title_left_callback (popup)
{
   variable i;
   variable action;
   action = strcat("read_mini\\\(\\\"Enter Left Title string\\\",\\\"", Apsmode_Printers[0].title_left,"\\\",\\\"", Apsmode_Printers[0].title_left,"\\\"\\\)");
   action = strcat("Apsmode_Printers[0].title_left=", action);
   action = strcat("set_qp(\"", action, "\")");
   menu_append_item (popup, "&Add temporary Left Title String", action);
   for (i = 0; i <= aps_max_no_printers-1; i++)
     {
        if (Apsmode_Printers[i].setupname != NULL)
          {
             if (Apsmode_Printers[i].title_left != "")
               {
                  if (Apsmode_Printers[0].title_left == Apsmode_Printers[i].title_left)
                    {
                       menu_append_item (popup, strcat("* ", Apsmode_Printers[i].title_left), strcat("set_qp(\"Apsmode_Printers[0].title_left=\\\"", Apsmode_Printers[i].title_left, "\\\"\")"));
                    }
                  else
                    {
                       menu_append_item (popup, strcat("  ", Apsmode_Printers[i].title_left), strcat("set_qp(\"Apsmode_Printers[0].title_left=\\\"", Apsmode_Printers[i].title_left, "\\\"\")"));
                    }
               }
          }
     }
   return;
}
static define set_qp_title_center_callback (popup)
{
   variable i;
   variable action;
   action = strcat("read_mini\\\(\\\"Enter Center Title string\\\",\\\"", Apsmode_Printers[0].title_center,"\\\",\\\"", Apsmode_Printers[0].title_center,"\\\"\\\)");
   action = strcat("Apsmode_Printers[0].title_center=", action);
   action = strcat("set_qp(\"", action, "\")");
   menu_append_item (popup, "&Add temporary Center Title String", action);
   for (i = 0; i <= aps_max_no_printers-1; i++)
     {
        if (Apsmode_Printers[i].setupname != NULL)
          {
             if (Apsmode_Printers[i].title_center != "")
               {
                  if (Apsmode_Printers[0].title_center == Apsmode_Printers[i].title_center)
                    {
                       menu_append_item (popup, strcat("* ", Apsmode_Printers[i].title_center), strcat("set_qp(\"Apsmode_Printers[0].title_center=\\\"", Apsmode_Printers[i].title_center, "\\\"\")"));
                    }
                  else
                    {
                       menu_append_item (popup, strcat("  ", Apsmode_Printers[i].title_center), strcat("set_qp(\"Apsmode_Printers[0].title_center=\\\"", Apsmode_Printers[i].title_center, "\\\"\")"));
                    }
               }
          }
     }
   return;
}
static define set_qp_title_right_callback (popup)
{
   variable i;
   variable action;
   action = strcat("read_mini\\\(\\\"Enter Right Title string\\\",\\\"", Apsmode_Printers[0].title_right,"\\\",\\\"", Apsmode_Printers[0].title_right,"\\\"\\\)");
   action = strcat("Apsmode_Printers[0].title_right=", action);
   action = strcat("set_qp(\"", action, "\")");
   menu_append_item (popup, "&Add temporary Right Title String", action);
   for (i = 0; i <= aps_max_no_printers-1; i++)
     {
        if (Apsmode_Printers[i].setupname != NULL)
          {
             if (Apsmode_Printers[i].title_right != "")
               {
                  if (Apsmode_Printers[0].title_right == Apsmode_Printers[i].title_right)
                    {
                       menu_append_item (popup, strcat("* ", Apsmode_Printers[i].title_right), strcat("set_qp(\"Apsmode_Printers[0].title_right=\\\"", Apsmode_Printers[i].title_right, "\\\"\")"));
                    }
                  else
                    {
                       menu_append_item (popup, strcat("  ", Apsmode_Printers[i].title_right), strcat("set_qp(\"Apsmode_Printers[0].title_right=\\\"", Apsmode_Printers[i].title_right, "\\\"\")"));
                    }
               }
          }
     }
   return;
}
static define set_qp_footer_left_callback (popup)
{
   variable i;
   variable action;
   action = strcat("read_mini\\\(\\\"Enter Left Footer string\\\",\\\"", Apsmode_Printers[0].footer_left,"\\\",\\\"", Apsmode_Printers[0].footer_left,"\\\"\\\)");
   action = strcat("Apsmode_Printers[0].footer_left=", action);
   action = strcat("set_qp(\"", action, "\")");
   menu_append_item (popup, "&Add temporary Left Footer String", action);
   for (i = 0; i <= aps_max_no_printers-1; i++)
     {
        if (Apsmode_Printers[i].setupname != NULL)
          {
             if (Apsmode_Printers[i].footer_left != "")
               {
                  if (Apsmode_Printers[0].footer_left == Apsmode_Printers[i].footer_left)
                    {
                       menu_append_item (popup, strcat("* ", Apsmode_Printers[i].footer_left), strcat("set_qp(\"Apsmode_Printers[0].footer_left=\\\"", Apsmode_Printers[i].footer_left, "\\\"\")"));
                    }
                  else
                    {
                       menu_append_item (popup, strcat("  ", Apsmode_Printers[i].footer_left), strcat("set_qp(\"Apsmode_Printers[0].footer_left=\\\"", Apsmode_Printers[i].footer_left, "\\\"\")"));
                    }
               }
          }
     }
   return;
}
static define set_qp_footer_center_callback (popup)
{
   variable i;
   variable action;
   action = strcat("read_mini\\\(\\\"Enter Center Footer string\\\",\\\"", Apsmode_Printers[0].footer_center,"\\\",\\\"", Apsmode_Printers[0].footer_center,"\\\"\\\)");
   action = strcat("Apsmode_Printers[0].footer_center=", action);
   action = strcat("set_qp(\"", action, "\")");
   menu_append_item (popup, "&Add temporary Center Footer String", action);
   for (i = 0; i <= aps_max_no_printers-1; i++)
     {
        if (Apsmode_Printers[i].setupname != NULL)
          {
             if (Apsmode_Printers[i].footer_center != "")
               {
                  if (Apsmode_Printers[0].footer_center == Apsmode_Printers[i].footer_center)
                    {
                       menu_append_item (popup, strcat("* ", Apsmode_Printers[i].footer_center), strcat("set_qp(\"Apsmode_Printers[0].footer_center=\\\"", Apsmode_Printers[i].footer_center, "\\\"\")"));
                    }
                  else
                    {
                       menu_append_item (popup, strcat("  ", Apsmode_Printers[i].footer_center), strcat("set_qp(\"Apsmode_Printers[0].footer_center=\\\"", Apsmode_Printers[i].footer_center, "\\\"\")"));
                    }
               }
          }
     }
   return;
}
static define set_qp_footer_right_callback (popup)
{
   variable i;
   variable action;
   action = strcat("read_mini\\\(\\\"Enter Right Footer string\\\",\\\"", Apsmode_Printers[0].footer_right,"\\\",\\\"", Apsmode_Printers[0].footer_right,"\\\"\\\)");
   action = strcat("Apsmode_Printers[0].footer_right=", action);
   action = strcat("set_qp(\"", action, "\")");
   menu_append_item (popup, "&Add temporary Right Footer String", action);
   for (i = 0; i <= aps_max_no_printers-1; i++)
     {
        if (Apsmode_Printers[i].setupname != NULL)
          {
             if (Apsmode_Printers[i].footer_right != "")
               {
                  if (Apsmode_Printers[0].footer_right == Apsmode_Printers[i].footer_right)
                    {
                       menu_append_item (popup, strcat("* ", Apsmode_Printers[i].footer_right), strcat("set_qp(\"Apsmode_Printers[0].footer_right=\\\"", Apsmode_Printers[i].footer_right, "\\\"\")"));
                    }
                  else
                    {
                       menu_append_item (popup, strcat("  ", Apsmode_Printers[i].footer_right), strcat("set_qp(\"Apsmode_Printers[0].footer_right=\\\"", Apsmode_Printers[i].footer_right, "\\\"\")"));
                    }
               }
          }
     }
   return;
}
static define set_qp_is_copy_of_callback (popup)
{
   variable i;
   for (i = 1; i <= aps_max_no_printers-1; i++)
     {
        if (Apsmode_Printers[i].setupname != NULL)
          {
             if (Apsmode_Printers[0].copy_of == i)
               {
                  menu_append_item (popup, strcat("* ", sprintf("%2s  ",string(i)), Apsmode_Printers[i].setupname), strcat("set_qp(\"qp_is_copy_of(", string(i), ")\")"));
               }
             else
               {
                  menu_append_item (popup, strcat("  ", sprintf("%2s  ",string(i)), Apsmode_Printers[i].setupname), strcat("set_qp(\"qp_is_copy_of(", string(i), ")\")"));
               }
          }
     }
   return;
}
static define set_qp_fontsize_callback (popup)
{
   variable i;
   variable increment = 1;

   if (Apsmode_Printers[0].fontsize == "none")
     {
        menu_append_item (popup, strcat("* ", "don't care"), strcat("set_qp(\"Apsmode_Printers[0].fontsize=\\\"", "none", "\\\"\")"));
     }
   else
     {
        menu_append_item (popup, strcat("  ", "don't care"), strcat("set_qp(\"Apsmode_Printers[0].fontsize=\\\"", "none", "\\\"\")"));
     }
   % add fontsize in points
   for (i = 6; i <= 72; i = i + increment)
     {
        if (Apsmode_Printers[0].fontsize == strcat(string(i), "points"))
          {
             menu_append_item (popup, strcat("* ", string(i), "points"), strcat("set_qp(\"Apsmode_Printers[0].fontsize=\\\"", string(i), "points", "\\\"\")"));
          }
        else
          {
             menu_append_item (popup, strcat("  ", string(i), "points"), strcat("set_qp(\"Apsmode_Printers[0].fontsize=\\\"", string(i), "points", "\\\"\")"));
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
   action = strcat("read_mini\\\(\\\"Enter min:max characters\\\",\\\"", Apsmode_Printers[0].chars,"\\\",\\\"", Apsmode_Printers[0].chars,"\\\"\\\)");
   action = strcat("Apsmode_Printers[0].chars=", action);
   action = strcat("set_qp(\"", action, "\")");
   menu_append_item (popup, "&Change Max Characters", action);
   menu_append_item (popup, "0:80", strcat("set_qp(\"Apsmode_Printers[0].chars=\\\"0:80\\\"\")"));
   menu_append_item (popup, "0:100", strcat("set_qp(\"Apsmode_Printers[0].chars=\\\"0:100\\\"\")"));
   menu_append_item (popup, "0:132", strcat("set_qp(\"Apsmode_Printers[0].chars=\\\"0:132\\\"\")"));
   menu_append_item (popup, "80:100", strcat("set_qp(\"Apsmode_Printers[0].chars=\\\"80:100\\\"\")"));
   menu_append_item (popup, "80:132", strcat("set_qp(\"Apsmode_Printers[0].chars=\\\"80:132\\\"\")"));
   return;
}

static define set_qp_margin_callback (popup)
{
   variable i;
   variable increment = 1;

   % add margin in points
   for (i = 0; i <= 12; i = i + increment)
     {
        if (Apsmode_Printers[0].margin == string(i))
          {
             menu_append_item (popup, strcat("* ", string(i), " points"), strcat("set_qp(\"Apsmode_Printers[0].margin=\\\"", string(i), "\\\"\")"));
          }
        else
          {
             menu_append_item (popup, strcat("  ", string(i), " points"), strcat("set_qp(\"Apsmode_Printers[0].margin=\\\"", string(i), "\\\"\")"));
          }
        % this code has been left here in case of more than 12 points needed.
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
static define set_qp_major_callback (popup)
{
   if (strup(Apsmode_Printers[0].major) == "COLUMNS")
     {
        menu_append_item (popup, strcat("* ", "&columns"), strcat("set_qp(\"Apsmode_Printers[0].major=\\\"columns\\\"\")"));
        menu_append_item (popup, strcat("  ", "&rows"), strcat("set_qp(\"Apsmode_Printers[0].major=\\\"rows\\\"\")"));
     }
   if (strup(Apsmode_Printers[0].major) == "ROWS")
     {
        menu_append_item (popup, strcat("  ", "&columns"), strcat("set_qp(\"Apsmode_Printers[0].major=\\\"columns\\\"\")"));
        menu_append_item (popup, strcat("* ", "&rows"), strcat("set_qp(\"Apsmode_Printers[0].major=\\\"rows\\\"\")"));
     }
   return;
}
static define set_qp_pretty_callback (popup)
{
   if (strup(Apsmode_Printers[0].pretty) == "ON")
     {
        menu_append_item (popup, strcat("* ", "o&n"), strcat("set_qp(\"Apsmode_Printers[0].pretty=\\\"on\\\"\")"));
        menu_append_item (popup, strcat("  ", "o&ff"), strcat("set_qp(\"Apsmode_Printers[0].pretty=\\\"off\\\"\")"));
     }
   if (strup(Apsmode_Printers[0].pretty) == "OFF")
     {
        menu_append_item (popup, strcat("  ", "o&n"), strcat("set_qp(\"Apsmode_Printers[0].pretty=\\\"on\\\"\")"));
        menu_append_item (popup, strcat("* ", "o&ff"), strcat("set_qp(\"Apsmode_Printers[0].pretty=\\\"off\\\"\")"));
     }
   return;
}

static define set_qp_context_callback (popup)
{
   variable menu_entry = "";

   % QuickPrint settings (as copy of Apsmode_default_printer)
   % if not yet defined
   if (Apsmode_Printers[0].orientation == NULL)
     {
        qp_is_copy_of(Apsmode_default_printer);
     }

   % Orientation
   menu_entry = strcat("&Orientation       (", Apsmode_Printers[0].orientation, ")");
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_orientation_callback);
   % Paper Format
   menu_entry = strcat("&Paper Format      (", Apsmode_Printers[0].medium, ")");
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_medium_callback);
   % Number of columns
   menu_entry = strcat("Number of &Columns (", Apsmode_Printers[0].columns, ")");
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_no_columns_callback);
   % Number of rows
   menu_entry = strcat("Number of &Rows    (", Apsmode_Printers[0].rows, ")");
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_no_rows_callback);
   % 2 Sides
   menu_entry = strcat("2 &Sides           (", Apsmode_Printers[0].sides, ")");
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_no_sides_callback);
   % Copies
   menu_entry = strcat("Cop&ies            (", Apsmode_Printers[0].copies, ")");
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_no_copies_callback);

   menu_append_separator (popup);

   % Fontsize
   menu_entry = strcat("&Fontsize          (", Apsmode_Printers[0].fontsize, ")");
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_fontsize_callback);
   % Max Characters
   menu_entry = strcat("&Max Characters    (", Apsmode_Printers[0].chars, ")");
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_max_chars_callback);
   % Truncate Lines
   menu_entry = strcat("&Truncate Lines    (", Apsmode_Printers[0].truncate, ")");
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_truncate_callback);
   % Linenumbers
   menu_entry = strcat("Line&numbers       (", Apsmode_Printers[0].linenumbers, ")");
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_linenumbers_callback);

   menu_append_separator (popup);

   % Borders
   menu_entry = strcat("&Borders           (", Apsmode_Printers[0].borders, ")");
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_borders_callback);
   % Margin
   menu_entry = strcat("M&argin            (", Apsmode_Printers[0].margin, ")");
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_margin_callback);
   % Major Print Direction
   menu_entry = strcat("Print &Direction   (", Apsmode_Printers[0].major, ")");
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_major_callback);
   % Color
   menu_entry = strcat("Co&lor             (", Apsmode_Printers[0].color, ")");
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_color_callback);
   % Pretty Printing
   menu_entry = strcat("Pr&etty Printing   (", Apsmode_Printers[0].pretty, ")");
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_pretty_callback);

   menu_append_separator (popup);

   % Header
   menu_entry = create_menu_string ("&Header", Apsmode_Printers[0].header);
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_header_callback);
   % Title Left
   menu_entry = create_menu_string ("Title Left", Apsmode_Printers[0].title_left);
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_title_left_callback);
   % Title Center
   menu_entry = create_menu_string ("Title Center", Apsmode_Printers[0].title_center);
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_title_center_callback);
   % Title Right
   menu_entry = create_menu_string ("Title Right", Apsmode_Printers[0].title_right);
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_title_right_callback);
   % Footer Left
   menu_entry = create_menu_string ("Footer Left", Apsmode_Printers[0].footer_left);
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_footer_left_callback);
   % Footer Center
   menu_entry = create_menu_string ("Footer Center", Apsmode_Printers[0].footer_center);
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_footer_center_callback);
   % Footer Right
   menu_entry = create_menu_string ("Footer Right", Apsmode_Printers[0].footer_right);
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_footer_right_callback);

   menu_append_separator (popup);

   % Print Command
   menu_entry = create_menu_string ("Pri&nt Command", Apsmode_Printers[0].print_cmd);
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_printer_callback);
   % View Command
   menu_entry = create_menu_string ("&View Command", Apsmode_Printers[0].view_cmd);
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_view_callback);

   menu_append_separator (popup);

   % QP is copy of
   menu_entry = strcat("Set QP as Cop&y of setup  (", string(Apsmode_Printers[0].copy_of), ")");
   menu_append_popup (popup, menu_entry);
   menu_set_select_popup_callback (strcat (popup, strcat(".", menu_entry)), &set_qp_is_copy_of_callback);
   % set QP as default printer, if necessary
   if (Apsmode_default_printer != 0)
     {
        menu_append_item (popup, "Set QP as default printer", strcat("show_default_printer_menu(\"set_default_printer(0)\",\".&QuickPrint\")"));
     }
   else
     {
        menu_append_item (popup, "QP is default printer", strcat("show_default_printer_menu(\"set_default_printer(0)\",\".&QuickPrint\")"));
     }

   return;
}

if ( Apsmode_menu != "")
{
   % remove existing Print menu entry
   % (this might fail with older cua emulations)
   % if (_Jed_Emulation == "cua" and is_defined("print_buffer"))
   %   menu_delete_item("Global.&File.&Print");

   $1 = Apsmode_menu;
   $2 = strtok(Apsmode_menu, ".");
   menu_insert_popup(7, strjoin($2[[:-2]], "."), $2[-1]);

   menu_append_item ($1, "Print &Buffer", "print_buffer");
   menu_append_item ($1, "Print &Region", "print_region");

   menu_append_separator ($1);
   menu_append_item ($1, "Print B&uffer Preview", "print_buffer_preview");
   menu_append_item ($1, "Print R&egion Preview", "print_region_preview");

   menu_append_separator ($1);
   if (Apsmode_default_printer == 0)
     {
        menu_entry = strcat("Show &Default Printer  (QuickPrint)");
     }
   else
     {
        menu_entry = strcat("Show &Default Printer  (setup ", string(Apsmode_default_printer), ")");
     }

   menu_append_popup ($1, menu_entry);
   menu_set_select_popup_callback (strcat ($1, ".", menu_entry), &default_printer_callback);

   menu_append_popup ($1, "Set Default &Printer");
   menu_set_select_popup_callback (strcat ($1, ".Set Default &Printer"), &set_default_printer_callback);

   menu_append_separator ($1);
   % add the context sensitive QuickPrint entries
   menu_append_popup ($1, "&QuickPrint");
   menu_set_select_popup_callback (strcat ($1, ".&QuickPrint"), &set_qp_context_callback);

   menu_append_separator ($1);
   menu_append_popup ($1, "Show Printer &Settings");
   menu_set_select_popup_callback (strcat ($1, ".Show Printer &Settings"), &show_default_printer_callback);
   menu_append_item ($1, "Show Print &Logfile", "show_print_log()");

   menu_append_separator ($1);
   menu_append_item ($1, "Current Settings in apsconf format", strcat("show_printer_settings(\"default\",2)"));
   menu_append_item ($1, "&Create Style Sheet", "create_a2ps_style_sheet(\"\")");

   menu_append_separator ($1);
   menu_append_item ($1, "Show apsmode Settings", "show_apsmode_settings()");
   menu_append_item ($1, "&Help apsmode", "aps_help");
   menu_append_popup ($1, "&About apsmode");
   menu_append_item (strcat($1, ".&About apsmode"), "apsmode", "menu_select_menu(Apsmode_menu)");
   menu_append_item (strcat($1, ".&About apsmode"), strcat("Version ", aps_version), "menu_select_menu(Apsmode_menu)");
   menu_append_item (strcat($1, ".&About apsmode"), strcat("created ", aps_creation_date), "menu_select_menu(Apsmode_menu)");
   %menu_append_item (strcat($1, ".&About apsmode"), strcat("by ", aps_creator), "menu_select_menu(Apsmode_menu)");
   menu_append_item (strcat($1, ".&About apsmode"), strcat("tested with JED ", aps_jed_tested), "menu_select_menu(Apsmode_menu)");
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
   variable cmd = strcat(Apsmode_a2ps_cmd, " ");
   variable no_header = "";
   variable chars = Integer_Type [2];

   cmd = strcat(cmd, " --output=", Apsmode_tmp_file);
   cmd = strcat(cmd, " --columns=", Apsmode_Printers[id].columns);
   cmd = strcat(cmd, " --rows=", Apsmode_Printers[id].rows);

   % now determine , how much characters have to be printed per line
   % first extract min/max values from printer setting

   chars = strchop(Apsmode_Printers[id].chars,':',0);

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

   if (Apsmode_Printers[id].fontsize != "none")
     {
        cmd = strcat(cmd, " --font-size=", Apsmode_Printers[id].fontsize);
     }

   cmd = strcat(cmd, " --borders=", Apsmode_Printers[id].borders);
   cmd = strcat(cmd, " --", Apsmode_Printers[id].orientation);
   cmd = strcat(cmd, " --medium=", Apsmode_Printers[id].medium);
   cmd = strcat(cmd, " --sides=", Apsmode_Printers[id].sides);
   cmd = strcat(cmd, " --truncate-line=", Apsmode_Printers[id].truncate);
   cmd = strcat(cmd, " --line-numbers=", Apsmode_Printers[id].linenumbers);
   cmd = strcat(cmd, " --copies=", Apsmode_Printers[id].copies);
   cmd = strcat(cmd, " --major=", Apsmode_Printers[id].major);
   cmd = strcat(cmd, " --margin=", Apsmode_Printers[id].margin);

   % string settings must be differently defined for UNIX and Windows
   % Windows needs some extra \\ for hashing, otherwise only parts of
   % the defined strings will be considered
#ifdef UNIX
   if ( Apsmode_Printers[id].header != "" )
     {
        cmd = strcat(cmd, " --header=\"", Apsmode_Printers[id].header, "\"");
        no_header = "1";
     }
   if ( Apsmode_Printers[id].title_left != "" )
     {
        cmd = strcat(cmd, " --left-title=\"", Apsmode_Printers[id].title_left, "\"");
        no_header = "1";
     }
   if ( Apsmode_Printers[id].title_center != "" )
     {
        cmd = strcat(cmd, " --center-title=\"", Apsmode_Printers[id].title_center, "\"");
        no_header = "1";
     }
   if ( Apsmode_Printers[id].title_right != "" )
     {
        cmd = strcat(cmd, " --right-title=\"", Apsmode_Printers[id].title_right, "\"");
        no_header = "1";
     }
   if (no_header == "")
     {
        cmd = strcat(cmd, " --no-header");
     }
   if ( Apsmode_Printers[id].footer_left != "" )
     {
        cmd = strcat(cmd, " --left-footer=\"", Apsmode_Printers[id].footer_left, "\"");
     }

   if ( Apsmode_Printers[id].footer_center != "" )
     {
        cmd = strcat(cmd, " --footer=\"", Apsmode_Printers[id].footer_center, "\"");
     }
   if ( Apsmode_Printers[id].footer_right != "" )
     {
        cmd = strcat(cmd, " --right-footer=\"", Apsmode_Printers[id].footer_right, "\"");
     }
#endif
#ifdef MSWINDOWS
   if ( Apsmode_Printers[id].header != "" )
     {
        cmd = strcat(cmd, " --header=\\\"", Apsmode_Printers[id].header, "\\\"");
        no_header = "1";
     }
   if ( Apsmode_Printers[id].title_left != "" )
     {
        cmd = strcat(cmd, " --left-title=\\\"", Apsmode_Printers[id].title_left, "\\\"");
        no_header = "1";
     }
   if ( Apsmode_Printers[id].title_center != "" )
     {
        cmd = strcat(cmd, " --center-title=\\\"", Apsmode_Printers[id].title_center, "\\\"");
        no_header = "1";
     }
   if ( Apsmode_Printers[id].title_right != "" )
     {
        cmd = strcat(cmd, " --right-title=\\\"", Apsmode_Printers[id].title_right, "\\\"");
        no_header = "1";
     }
   if (no_header == "")
     {
        cmd = strcat(cmd, " --no-header");
     }
   if ( Apsmode_Printers[id].footer_left != "" )
     {
        cmd = strcat(cmd, " --left-footer=\\\"", Apsmode_Printers[id].footer_left, "\\\"");
     }

   if ( Apsmode_Printers[id].footer_center != "" )
     {
        cmd = strcat(cmd, " --footer=\\\"", Apsmode_Printers[id].footer_center, "\\\"");
     }
   if ( Apsmode_Printers[id].footer_right != "" )
     {
        cmd = strcat(cmd, " --right-footer=\\\"", Apsmode_Printers[id].footer_right, "\\\"");
     }
#endif
   cmd = strcat(cmd, " --prologue=", Apsmode_Printers[id].color);
   % pretty-print must be the last entry to have a chance to append
   % local a2ps style sheet later
   if (strup(Apsmode_Printers[id].pretty) == "ON")
     {
        cmd = strcat(cmd, " --pretty-print");
     }
   else
     {
        cmd = strcat(cmd, " --pretty-print=\"plain\"");
     }
   % remove the placeholders for filename and date/time
   cmd = str_replace_all(cmd, "JEDFILENAME", aps_jedfilename);
   cmd = str_replace_all(cmd, "JEDDATETIME", aps_jeddatetime);

   return cmd;
}

%}}}

%!%+
%\function{show_printer_settings}
%\synopsis{show current printer settings}
%\usage{show_printer_settings (String_Type/Integer_Type id, Integer_Type format)}
%\description
% This function is used to show the current printer settings in a
% separate buffer.
% \var{id} will be used as index for the \var{Apsmode_Printers}-array, which
% contains the settings. Value "default" will use the settings of the currently
% defined default printer.
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

   % set id to the default printer id (if requested)
   if (string(id) == "default")
     {
        id = Apsmode_default_printer;

     }

   % print settings in a readable format
   if (format == 1)
     {
        insert(sprintf("\nSettings for %s\n", Apsmode_Printers[id].setupname));
        insert("==========================================\n\n");
        insert("\nPrint options\n");
        insert("------------------------------------------\n");
        insert(sprintf("Printer Name          : %s\n", Apsmode_Printers[id].name));
        insert(sprintf("Printer Description   : %s\n", Apsmode_Printers[id].description));
        insert(sprintf("Number of Columns     : %s\n", Apsmode_Printers[id].columns));
        insert(sprintf("Number of Rows        : %s\n", Apsmode_Printers[id].rows));
        insert(sprintf("Fontsize              : %s\n", Apsmode_Printers[id].fontsize));
        insert(sprintf("Characters per Line   : %s\n", Apsmode_Printers[id].chars));
        insert(sprintf("Orientation           : %s\n", Apsmode_Printers[id].orientation));
        insert(sprintf("Paper Format          : %s\n", Apsmode_Printers[id].medium));
        insert(sprintf("One/Two Sides Print   : %s\n", Apsmode_Printers[id].sides));
        insert(sprintf("Truncate Lines        : %s\n", Apsmode_Printers[id].truncate));
        insert(sprintf("Number of copies      : %s\n", Apsmode_Printers[id].copies));
        insert(sprintf("Major Print Direction : %s\n", Apsmode_Printers[id].major));
        insert(sprintf("\nPrint Linenumbers every %s row(s)\n", Apsmode_Printers[id].linenumbers));

        insert("\nLayout options\n");
        insert("------------------------------------------\n");
        insert(sprintf("Print Borders         : %s\n", Apsmode_Printers[id].borders));
        insert(sprintf("Margin [points]       : %s\n", Apsmode_Printers[id].margin));
        insert(sprintf("Header                : %s\n", Apsmode_Printers[id].header));
        insert(sprintf("Left Title            : %s\n", Apsmode_Printers[id].title_left));
        insert(sprintf("Center Title          : %s\n", Apsmode_Printers[id].title_center));
        insert(sprintf("Right Title           : %s\n", Apsmode_Printers[id].title_right));
        insert(sprintf("Left Footer           : %s\n", Apsmode_Printers[id].footer_left));
        insert(sprintf("Center Footer         : %s\n", Apsmode_Printers[id].footer_center));
        insert(sprintf("Right Footer          : %s\n", Apsmode_Printers[id].footer_right));
        insert(sprintf("Color                 : %s\n", Apsmode_Printers[id].color));
        insert(sprintf("Syntax Highlighting   : %s\n", Apsmode_Printers[id].pretty));

        insert("------------------------------------------\n\n");
        insert("a2ps command:\n");
        insert(get_a2ps_cmd(id,0));
        insert("\n\n");
        insert("print command:\n");
        insert(Apsmode_Printers[id].print_cmd);
        insert("\n\n");
        insert("view command:\n");
        insert(Apsmode_Printers[id].view_cmd);
        insert("\n");
     }

   % print settings in a apsconf format
   if (format == 2)
     {
        insert("% You can use this definition in your local apsconf.sl file.\n");
        insert("% Don't forget to define a private variable 'setup'\n");
        insert("% in your local apsconf file;\n");
        insert("% private variable aps_id = 0;\n\n");
        insert("setup++;\n");
        insert(sprintf("Apsmode_Printers[setup].setupname = \"%s\";\n",Apsmode_Printers[id].setupname));
        insert(sprintf("Apsmode_Printers[setup].name = \"%s\";\n",Apsmode_Printers[id].name));
        insert(sprintf("Apsmode_Printers[setup].description = \"%s\";\n",Apsmode_Printers[id].description));
        insert(sprintf("Apsmode_Printers[setup].columns = \"%s\";\n",Apsmode_Printers[id].columns));
        insert(sprintf("Apsmode_Printers[setup].rows = \"%s\";\n",Apsmode_Printers[id].rows));
        insert(sprintf("Apsmode_Printers[setup].fontsize = \"%s\";\n",Apsmode_Printers[id].fontsize));
        insert(sprintf("Apsmode_Printers[setup].chars = \"%s\";\n",Apsmode_Printers[id].chars));
        insert(sprintf("Apsmode_Printers[setup].borders = \"%s\";\n",Apsmode_Printers[id].borders));
        insert(sprintf("Apsmode_Printers[setup].orientation = \"%s\";\n",Apsmode_Printers[id].orientation));
        insert(sprintf("Apsmode_Printers[setup].medium = \"%s\";\n",Apsmode_Printers[id].medium));
        insert(sprintf("Apsmode_Printers[setup].sides = \"%s\";\n",Apsmode_Printers[id].sides));
        insert(sprintf("Apsmode_Printers[setup].truncate = \"%s\";\n",Apsmode_Printers[id].truncate));
        insert(sprintf("Apsmode_Printers[setup].linenumbers = \"%s\";\n",Apsmode_Printers[id].linenumbers));
        insert(sprintf("Apsmode_Printers[setup].copies = \"%s\";\n",Apsmode_Printers[id].copies));
        insert(sprintf("Apsmode_Printers[setup].major = \"%s\";\n",Apsmode_Printers[id].major));
        insert(sprintf("Apsmode_Printers[setup].margin = \"%s\";\n",Apsmode_Printers[id].margin));
        insert(sprintf("Apsmode_Printers[setup].header = \"%s\";\n",Apsmode_Printers[id].header));
        insert(sprintf("Apsmode_Printers[setup].title_left = \"%s\";\n",Apsmode_Printers[id].title_left));
        insert(sprintf("Apsmode_Printers[setup].title_center = \"%s\";\n",Apsmode_Printers[id].title_center));
        insert(sprintf("Apsmode_Printers[setup].title_right = \"%s\";\n",Apsmode_Printers[id].title_right));
        insert(sprintf("Apsmode_Printers[setup].footer_left = \"%s\";\n",Apsmode_Printers[id].footer_left));
        insert(sprintf("Apsmode_Printers[setup].footer_center = \"%s\";\n",Apsmode_Printers[id].footer_center));
        insert(sprintf("Apsmode_Printers[setup].footer_right = \"%s\";\n",Apsmode_Printers[id].footer_right));
        insert(sprintf("Apsmode_Printers[setup].color = \"%s\";\n",Apsmode_Printers[id].color));
        insert(sprintf("Apsmode_Printers[setup].pretty = \"%s\";\n",Apsmode_Printers[id].pretty));
        insert(sprintf("Apsmode_Printers[setup].print_cmd = \"%s\";\n",Apsmode_Printers[id].print_cmd));
        insert(sprintf("Apsmode_Printers[setup].view_cmd = \"%s\";\n",Apsmode_Printers[id].view_cmd));
        insert("Apsmode_Printers[setup].copy_of = 0;\n");
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
%\function{show_apsmode_settings}
%\synopsis{show apsmode settings}
%\usage{show_apsmode_settings ()}
%\description
% This function is used to show some apsmode settings, e.g. global variables
% This function returns nothing.
%!%-
define show_apsmode_settings() %{{{
{
   variable key = "";
   variable keys = "";
   variable use_style = 0;
   variable i = 0;
   variable printer_count = 0;

   jed_easy_help("");
   set_buffer_modified_flag(0);
   erase_buffer();

   insert("Global Variables\n----------------\n");

   print_log("Apsmode_a2ps_cmd       ",Apsmode_a2ps_cmd);
   print_log("Apsmode_default_printer",Apsmode_default_printer);
   print_log("Apsmode_del_ps_file    ",Apsmode_del_ps_file);
   print_log("Apsmode_menu           ",Apsmode_menu);
   print_log("Apsmode_tmp_dir        ",Apsmode_tmp_dir);
   print_log("Apsmode_tmp_file       ",Apsmode_tmp_file);

   insert("\n\napsmode Settings\n----------------\n");

   print_log("apsmode File     ", expand_jedlib_file("apsmode.sl"));
   print_log("apsmode Help     ", expand_jedlib_file("apsmode.hlp"));

   % i= 0 is for Quickprint and will therefore not be counted
   for (i = 1; i <= aps_max_no_printers-1; i++)
     {
        if (Apsmode_Printers[i].setupname != NULL)
          {
             printer_count ++;
          }
     }
   print_log("No Printer Setups", printer_count);

   insert("\n\nStyle Sheets\n------------\n");

   keys = assoc_get_keys (Apsmode_style_sheet);
   keys = keys[array_sort (keys)];
   foreach (keys)
     {
        key = ();
        use_style = Apsmode_style_sheet[key];
        if (use_style == 1)
          {
             print_log(key, expand_jedlib_file(strcat(key, ".ssh")));
          }
     }

   insert("\n\napsmode Version\n---------------\n");

   print_log("apsmode Version", aps_version);
   print_log("Creation Date  ", aps_creation_date);
   print_log("tested with jed", aps_jed_tested);

   insert("\n");
   bob();
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
% in \var{Apsmode_Printers}-array.
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

   pfile = strcat(Apsmode_tmp_dir,"#");

   % Find out the name of the buffer
   (buffile,bufdir,bufname,) = getbuf_info ();
   % if it is an internal buffer replace filename with buffer name
   if (buffile == "")
     {
        buffile = bufname;
        bufdir = "";
     }

   % set aps_jedfilename variable
   aps_jedfilename = sprintf("%s%s", bufdir, buffile);
#ifdef MSWINDOWS
   aps_jedfilename = str_replace_all(aps_jedfilename,"\\","\\\\");
#endif
   aps_jeddatetime = jed_date_time();

   % extract mode name to check later, whether local a2ps style sheet
   % should be used
   mode_name = get_mode_name();
   sheet_file = expand_jedlib_file(strcat(mode_name, ".ssh"));

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
   cmd = get_a2ps_cmd(Apsmode_default_printer, max_char);

   if (strup(Apsmode_Printers[Apsmode_default_printer].pretty) == "ON")
     {
        print_log("Pretty Print Mode", mode_name);
        % now check whether jed-created a2ps style sheets should be used
        % if yes append them to "pretty-print=jed-style.ssh"
        if ( assoc_key_exists (Apsmode_style_sheet, mode_name) == 1 )
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
   print_log("view cmd  ", Apsmode_Printers[Apsmode_default_printer].view_cmd);
   print_log("print cmd ", Apsmode_Printers[Apsmode_default_printer].print_cmd);

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
             rc = run_shell_cmd (sprintf ("%s %s", Apsmode_Printers[Apsmode_default_printer].view_cmd, redirect));
             msg = sprintf("Viewing done (%s)", bufname);
             flush(msg);
          }
        else
          {
             % Print the temporary file
             insert ("\n--------------------- Printing --- (print cmd) -----------------------\n");
             msg = sprintf("Printing %s...", bufname);
             flush(msg);
             rc = run_shell_cmd (sprintf ("%s %s", Apsmode_Printers[Apsmode_default_printer].print_cmd, redirect));
             msg = sprintf("Printing done (%s --> %s)", bufname, Apsmode_Printers[Apsmode_default_printer].name);
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
   if (Apsmode_del_ps_file = 1)
     {
        delete_file (Apsmode_tmp_file);
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
   Apsmode_default_printer = id;
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
   variable sheet_dir;
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

   % get a default sheet_dir from SLang.ssh
   sheet_dir = path_dirname(expand_jedlib_file("SLang.ssh"));

   sheet_file = strcat(mode, ".ssh");

   % ask the user for the directory, where the new style sheet should be saved
   sheet_dir = read_with_completion(strcat("Enter directory for new style sheet (", sheet_file, "): "),"",sheet_dir,'f');
   sheet_file = path_concat(sheet_dir, sheet_file);

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
   mode_file = read_with_completion("Enter mode filename:","",mode_file,'f');

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

provide("apsmode");

%---8&lt;------- (end of apsmode.sl)--------


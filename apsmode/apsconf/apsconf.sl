% apsconf.sl -*- mode: slang; mode: fold; -*-
% 
% apsconf.sl is the configurable part of apsmode.
% Here you can modify some global settings as temp directory,
% default printer id, style sheet usage, ...
% some of them are OS specific
% 
% requires apsmode version >=1.5
% 
% 2005-11-21 GM: use path_concat() for aps_tmp_dir
% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% name        : aps_menu
% description : defines, whether a popup menu should be created
%               by apsmode.sl
%               be aware that quickprint settings are only available
%               via menu
%               wmenu will not be supported
%               (0 = no menu, 1 = popup menu)
% value       : path
%
% name        : aps_del_ps_file
% description : delete created ps file after printing/viewing 
%               (0 = keep, 1 = delete)
% value       : 0 or 1
%
% name        : aps_tmp_dir
% description : directory for temporary files and ps file
% value       : path
%
% name        : a2ps_cmd
% description : OS specific command to run a2ps
% value       : a2ps programm call (with path)
%
% name        : default_printer
% description : id of the default printer
%               id = 0 is reserved for QuickPrint, don't use it !
%               the configuration file handles UNIX and Windows
%               printers separately
% value       : max_no_printers > default_printer > 0
%
% name        : aps_tmp_file
% description : name of the ps file, which will be created by a2ps
% value       : *.ps
%
% name        : use_jed_a2ps_style_sheet
% description : array containing all jed mode names (as index), for which a
%               jed specific style sheet for a2ps should be used
%               style sheets must be available in ./apsconf directory
%               can be created by function <create_a2ps_style_sheet(mode)>
% value       : use_jed_a2ps_style_sheet[<jed-mode-name>] = 1;
%

aps_menu = 1;
aps_del_ps_file = 1;

#ifdef UNIX
aps_tmp_dir = path_concat(getenv("TMPDIR"), ""); % ensure trailing "/"
if (aps_tmp_dir == "")
  aps_tmp_dir = "/tmp/";
a2ps_cmd = "a2ps";
default_printer = 5;
#endif

#ifdef MSWINDOWS
aps_tmp_dir = "C:\\temp\\";
a2ps_cmd = "D:\\Programs\\a2ps\\bin\\a2ps.exe";
default_printer = 1;
#endif

aps_tmp_file = strcat(aps_tmp_dir, "print_from_jed.ps");

use_jed_a2ps_style_sheet["SLang"] = 1;
use_jed_a2ps_style_sheet["TSL"] = 1;
use_jed_a2ps_style_sheet["awk"] = 1;
use_jed_a2ps_style_sheet["tl1"] = 1;
use_jed_a2ps_style_sheet["tm"] = 1;
use_jed_a2ps_style_sheet["occur"] = 1;

  
%%%%%%%%%%%%%%%%%% Define printers %%%%%%%%%%%%%%%%%%%%%%%%%%% %{{{
% 
% This structure contains the printer settings for apsmode.sl
% Most of the settings are directly copied from a2ps options
% See a2ps documentation for further details.
% These settings have been tested with:
% - UNIX      : a2ps v4.12
% - MSWINDOWS : a2ps v4.13b
% 
% The printer settings have been "divided" for UNIX/Windows. so that only
% the relevant printers will show up under the specific OS.
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% JED<XYZ> variables used as placeholder for print options
% 
% name       : JEDFILENAME
% description: use this variable in footer/header definitions to print
%              the path/name of the buffer to be printed
%              do not use "$f" option of a2ps, because this will print
%              the name of the temporary print file instead of the name of 
%              the buffer
% 
% name       : JEDDATETIME
% description: use this variable in footer/header definitions to print
%              the current date, time of the buffer print formatted
%              as YYYY-MMM-DD, HH:MM:SS
%              this is a replacement for the "%e %*" option of a2ps
%              which seems to not work correctly under MSWINDOWS
%              Correction: with apsmode V1.4 options for Windows are 
%              correctly send to a2ps, so "%e %*" should work
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% name       : aps_pid
% description: printer id
%              this will be used as program internal identifier for 
%              the print setup
% value(s)   : integer, incremented by 1
% 
% name       : setup
% description: that's the name of the printer setup, which will be used as 
%              identifier
%              should not be too long, because it will be used within 
%              the menus
% value(s)   : text
% example    : "code 2x1x1, A4"
% 
% name       : name
% description: physical printer name as known by the OS
% value(s)   : text
% example    : "114_f004"
% 
% name       : description
% description: Your information about the printer setup
% value(s)   : text
% example    : "This is an example description"
% 
% name       : columns
% description: specify the number of columns of virtual pages per physical page
% value(s)   : integer (1...n)
% example    : "2"
% 
% name       : rows
% description: specify the number of rows of virtual pages per physical page
% value(s)   : integer (1...n)
% example    : "2"
% 
% name       : fontsize
% description: defines fontsize in points
%              if other formats than points needs to be supported 
%              by QuickPrint then function <set_qp_fontsize_callback> has to be 
%              modified accordingly
% value(s)   : 8,...,72 points, anything your printer and a2ps supports
% example    : "8points"
% 
% name       : chars
% description: number of characters to be printed on one line
%              format = min:max
%              min - minimum of characters to be printed
%              max - maximum of characters to be printed
% value(s)   : Integer:Integer
% example    : "80:100"
% 
% name       : borders
% description: switches border printing around each page on/off
% value(s)   : on,off
% example    : "on"
% 
% name       : orientation
% description: defines sheet orientation
% value(s)   : portrait,landscape
% example    : "portrait"
% 
% name       : medium
% description: defines print medium (sheet size)
%              if other formats than a3, a4, letter needs to be supported 
%              by QuickPrint then function <set_qp_medium_callback> has to be 
%              modified accordingly
% value(s)   : a4, a3, letter, ..., anything your printer and a2ps supports
% example    : "a4"
% 
% name       : sides
% description: printing on one/both sides of a sheet
% value(s)   : 1,2
% example    : "2"
% 
% name       : truncate
% description: truncate lines, if they are longer than maximum number of 
%              printing characters
%              !!! ATTENTION !!!
%              try on/off values with your a2ps installation
%              there seems to be a bug in different a2ps version 
%              and/or OS version
%              UNIX     , a2ps v4.12  : truncate=on does not truncate
%              MSWINDOWS, a2ps v4.13b : truncate=off does not truncate
% value(s)   : on,off
% example    : "on"
% 
% name       : linenumbers
% description: add linenumbers every x line to your printout
%              helpful for program code
%              switch off with value 0
% value(s)   : 0...n
% example    : "5"
% 
% name       : copies
% description: number of copies to be printed
% value(s)   : 1...n
% example    : "1"
% 
% name       : major
% description: specify whether the virtual pages should be first filled in 
%              rows (direction = rows) or in columns (direction = columns).
% value(s)   : rows,columns
% example    : "columns"
% 
% name       : margin
% description: Specify the size of the margin (num PostScript points, 
%              or 12 points without arguments) to leave in the inside 
%              (i.e. left for the front side page, and right for the back 
%              side).  This is intended to ease the binding.
% value(s)   : 0...n
% example    : "5"
% 
% name       : header
% description: sets the page header
% value(s)   : text
% example    : "Your Page header"
% 
% name       : title_left
% description: Set virtual page left title to text
%              see a2ps documentation for more detailed options
% value(s)   : text and/or a2ps options
% example    : "%e %*"
% 
% name       : title_center
% description: Set virtual page center title to text
%              see a2ps documentation for more detailed options
% value(s)   : text and/or a2ps options
% example    : "$f", "JEDFILENAME"
% 
% name       : title_right
% description: Set virtual page right title to text
%              see a2ps documentation for more detailed options
% value(s)   : text and/or a2ps options
% example    : "%s./%s#"
% 
% name       : footer_left
% description: Set virtual page left footer to text
%              see a2ps documentation for more detailed options
% value(s)   : text and/or a2ps options
% example    : "%e %*"
% 
% name       : footer_center
% description: Set virtual page center footer to text
%              see a2ps documentation for more detailed options
% value(s)   : text and/or a2ps options
% example    : "$f"
% 
% name       : footer_right
% description: Set virtual page right footer to text
%              see a2ps documentation for more detailed options
% value(s)   : text and/or a2ps options
% example    : "%s./%s#"
% 
% name       : color
% description: switches color printing on/off
%              bw - Style is plain: pure black and white, with standard fonts
%              color - Colors are used to highlight the keywords
% value(s)   : bw,color
% example    : "color"
% 
% name       : pretty
% description: switches pretty printing feature of a2ps on/off
% value(s)   : on,off
% example    : "on"
% 
% name       : print_cmd
% description: string containing the OS specific command to send the created
%              postscript file to the physical printer
%              could also be a ghostview command if direct printing 
%              is somehow not supported
% value(s)   : text
% example    : strcat("lpr -P ", printer[aps_pid].name, " ", aps_tmp_file)
% 
% name       : view_cmd
% description: string containing the OS specific command to view the created
%              postscript file (ghostview preferred)
% value(s)   : text
% example    : strcat("gv ", aps_tmp_file)
%              strcat("gsview32.exe ", aps_tmp_file);
% 
% name       : copy_of
% description: internal variable, which is needed for QuickPrint settings
%              has to be 0, don't change it
% value(s)   : 0
% example    : "0"
% 

% reset index for printer setting
aps_pid = 0;

#ifdef UNIX

aps_pid++;
printer[aps_pid].setup = "code, A4, 6pt, 2x1, duplex, CCB_3_F008";
printer[aps_pid].name = "CCB_3_F008";
printer[aps_pid].description = "Printer 1";
printer[aps_pid].columns = "2";
printer[aps_pid].rows = "1";
printer[aps_pid].fontsize = "6points";
printer[aps_pid].chars = "80:100";
printer[aps_pid].borders = "on";
printer[aps_pid].orientation = "landscape";
printer[aps_pid].medium = "A4";
printer[aps_pid].sides = "2";
printer[aps_pid].truncate = "on";
printer[aps_pid].linenumbers = "5";
printer[aps_pid].copies = "1";
printer[aps_pid].major = "columns";
printer[aps_pid].margin = "5";
printer[aps_pid].header = "";
printer[aps_pid].title_left = "";
printer[aps_pid].title_center = "";
printer[aps_pid].title_right = "";
%printer[aps_pid].footer_left = "%e %*";
printer[aps_pid].footer_left = "JEDDATETIME";
%printer[aps_pid].footer_center = "$f";
printer[aps_pid].footer_center = "JEDFILENAME";
printer[aps_pid].footer_right = "%s./%s#";
printer[aps_pid].color = "bw";
printer[aps_pid].pretty = "on";
printer[aps_pid].print_cmd = strcat("lpr -P ", printer[aps_pid].name, " ", aps_tmp_file);
printer[aps_pid].view_cmd = strcat("gv ", aps_tmp_file);
printer[aps_pid].copy_of = 0;

aps_pid++;
printer[aps_pid].setup = "code, A4, 8pt, 1x1, duplex, CCB_3_F008";
printer[aps_pid].name = "CCB_3_F008";
printer[aps_pid].description = "Printer1";
printer[aps_pid].columns = "1";
printer[aps_pid].rows = "1";
printer[aps_pid].fontsize = "8points";
printer[aps_pid].chars = "80:100";
printer[aps_pid].borders = "on";
printer[aps_pid].orientation = "portrait";
printer[aps_pid].medium = "A4";
printer[aps_pid].sides = "2";
printer[aps_pid].truncate = "on";
printer[aps_pid].linenumbers = "5";
printer[aps_pid].copies = "1";
printer[aps_pid].major = "columns";
printer[aps_pid].margin = "5";
printer[aps_pid].header = "";
printer[aps_pid].title_left = "";
printer[aps_pid].title_center = "";
printer[aps_pid].title_right = "";
%printer[aps_pid].footer_left = "%e %*";
printer[aps_pid].footer_left = "JEDDATETIME";
%printer[aps_pid].footer_center = "$f";
printer[aps_pid].footer_center = "JEDFILENAME";
printer[aps_pid].footer_right = "%s./%s#";
printer[aps_pid].color = "bw";
printer[aps_pid].pretty = "on";
printer[aps_pid].print_cmd = strcat("lpr -P ", printer[aps_pid].name, " ", aps_tmp_file);
printer[aps_pid].view_cmd = strcat("gv ", aps_tmp_file);
printer[aps_pid].copy_of = 0;

aps_pid++;
printer[aps_pid].setup = "code, A3, 6pt, 3x2, simplex, CCB_3_F008_A3";
printer[aps_pid].name = "CCB_3_F008_A3";
printer[aps_pid].description = "Printer1";
printer[aps_pid].columns = "3";
printer[aps_pid].rows = "2";
printer[aps_pid].fontsize = "6points";
printer[aps_pid].chars = "80:132";
printer[aps_pid].borders = "off";
printer[aps_pid].orientation = "landscape";
printer[aps_pid].medium = "A3";
printer[aps_pid].sides = "1";
printer[aps_pid].truncate = "on";
printer[aps_pid].linenumbers = "5";
printer[aps_pid].copies = "1";
printer[aps_pid].major = "columns";
printer[aps_pid].margin = "5";
printer[aps_pid].header = "";
printer[aps_pid].title_left = "";
printer[aps_pid].title_center = "";
printer[aps_pid].title_right = "";
%printer[aps_pid].footer_left = "%e %*";
printer[aps_pid].footer_left = "JEDDATETIME";
%printer[aps_pid].footer_center = "$f";
printer[aps_pid].footer_center = "JEDFILENAME";
printer[aps_pid].footer_right = "%s./%s#";
printer[aps_pid].color = "bw";
printer[aps_pid].pretty = "on";
printer[aps_pid].print_cmd = strcat("lpr -P ", printer[aps_pid].name, " -Z simplex ", aps_tmp_file);
printer[aps_pid].view_cmd = strcat("gv ", aps_tmp_file);
printer[aps_pid].copy_of = 0;

aps_pid++;
printer[aps_pid].setup = "text, A4, 8pt, 2x1, duplex, CCB_3_F008";
printer[aps_pid].name = "CCB_3_F008";
printer[aps_pid].description = "Printer 1";
printer[aps_pid].columns = "2";
printer[aps_pid].rows = "1";
printer[aps_pid].fontsize = "8points";
printer[aps_pid].chars = "80:100";
printer[aps_pid].borders = "on";
printer[aps_pid].orientation = "landscape";
printer[aps_pid].medium = "A4";
printer[aps_pid].sides = "2";
printer[aps_pid].truncate = "on";
printer[aps_pid].linenumbers = "0";
printer[aps_pid].copies = "1";
printer[aps_pid].major = "columns";
printer[aps_pid].margin = "5";
printer[aps_pid].header = "";
printer[aps_pid].title_left = "";
printer[aps_pid].title_center = "";
printer[aps_pid].title_right = "";
%printer[aps_pid].footer_left = "%e %*";
printer[aps_pid].footer_left = "JEDDATETIME";
%printer[aps_pid].footer_center = "$f";
printer[aps_pid].footer_center = "JEDFILENAME";
printer[aps_pid].footer_right = "%s./%s#";
printer[aps_pid].color = "bw";
printer[aps_pid].pretty = "off";
printer[aps_pid].print_cmd = strcat("lpr -P ", printer[aps_pid].name, " ", aps_tmp_file);
printer[aps_pid].view_cmd = strcat("gv ", aps_tmp_file);
printer[aps_pid].copy_of = 0;

#endif

%%%%%%%%%%%%%%%%%% MS Windows Printers %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#ifdef MSWINDOWS
aps_pid++;
printer[aps_pid].setup = "code, 2x1x2";
printer[aps_pid].name = "PR6730";
printer[aps_pid].description = "HP Postscript Printer, Convenience Center";
printer[aps_pid].columns = "2";
printer[aps_pid].rows = "1";
printer[aps_pid].fontsize = "8points";
printer[aps_pid].chars = "80:100";
printer[aps_pid].borders = "on";
printer[aps_pid].orientation = "landscape";
printer[aps_pid].medium = "A4";
printer[aps_pid].sides = "2";
printer[aps_pid].truncate = "off";
printer[aps_pid].linenumbers = "5";
printer[aps_pid].copies = "1";
printer[aps_pid].major = "columns";
printer[aps_pid].margin = "5";
printer[aps_pid].header = "";
printer[aps_pid].title_left = "";
printer[aps_pid].title_center = "";
printer[aps_pid].title_right = "";
%printer[aps_pid].footer_left = "%e %*";
%printer[aps_pid].footer_left = "%e";
printer[aps_pid].footer_left = "JEDDATETIME";
%printer[aps_pid].footer_center = "$f";
printer[aps_pid].footer_center = "JEDFILENAME";
printer[aps_pid].footer_right = "%s./%s#";
printer[aps_pid].color = "bw";
printer[aps_pid].pretty = "on";
printer[aps_pid].print_cmd = strcat("D:\\Programs\\gstools\\gsview\\gsview32.exe ", aps_tmp_file);
printer[aps_pid].view_cmd = strcat("D:\\Programs\\gstools\\gsview\\gsview32.exe ", aps_tmp_file);
printer[aps_pid].copy_of = 0;

aps_pid++;
printer[aps_pid].setup = "code, 1x1x2";
printer[aps_pid].name = "PR6730";
printer[aps_pid].description = "HP Postscript Printer, Convenience Center";
printer[aps_pid].columns = "1";
printer[aps_pid].rows = "1";
printer[aps_pid].fontsize = "8points";
printer[aps_pid].chars = "80:100";
printer[aps_pid].borders = "on";
printer[aps_pid].orientation = "portrait";
printer[aps_pid].medium = "A4";
printer[aps_pid].sides = "2";
printer[aps_pid].truncate = "off";
printer[aps_pid].linenumbers = "5";
printer[aps_pid].copies = "1";
printer[aps_pid].major = "columns";
printer[aps_pid].margin = "5";
printer[aps_pid].header = "";
printer[aps_pid].title_left = "";
printer[aps_pid].title_center = "";
printer[aps_pid].title_right = "";
%printer[aps_pid].footer_left = "%e %*";
%printer[aps_pid].footer_left = "%e";
printer[aps_pid].footer_left = "JEDDATETIME";
%printer[aps_pid].footer_center = "$f";
printer[aps_pid].footer_center = "JEDFILENAME";
printer[aps_pid].footer_right = "%s./%s#";
printer[aps_pid].color = "bw";
printer[aps_pid].pretty = "on";
%printer[aps_pid].print_cmd = strcat("lpr -P ", printer[aps_pid].name, " ", aps_tmp_file);
printer[aps_pid].print_cmd = strcat("D:\\Programs\\gstools\\gsview\\gsview32.exe ", aps_tmp_file);
printer[aps_pid].view_cmd = strcat("D:\\Programs\\gstools\\gsview\\gsview32.exe ", aps_tmp_file);
printer[aps_pid].copy_of = 0;

aps_pid++;
printer[aps_pid].setup = "text, 2x1x2";
printer[aps_pid].name = "PR6730";
printer[aps_pid].description = "HP Postscript Printer, Convenience Center";
printer[aps_pid].columns = "2";
printer[aps_pid].rows = "1";
printer[aps_pid].fontsize = "8points";
printer[aps_pid].chars = "80:100";
printer[aps_pid].borders = "on";
printer[aps_pid].orientation = "landscape";
printer[aps_pid].medium = "A4";
printer[aps_pid].sides = "2";
printer[aps_pid].truncate = "off";
printer[aps_pid].linenumbers = "0";
printer[aps_pid].copies = "1";
printer[aps_pid].major = "columns";
printer[aps_pid].margin = "5";
printer[aps_pid].header = "";
printer[aps_pid].title_left = "";
printer[aps_pid].title_center = "";
printer[aps_pid].title_right = "";
%printer[aps_pid].footer_left = "%e %*";
%printer[aps_pid].footer_left = "%e";
printer[aps_pid].footer_left = "JEDDATETIME";
%printer[aps_pid].footer_center = "$f";
printer[aps_pid].footer_center = "JEDFILENAME";
printer[aps_pid].footer_right = "%s./%s#";
printer[aps_pid].color = "bw";
printer[aps_pid].pretty = "off";
%printer[aps_pid].print_cmd = strcat("lpr -P ", printer[aps_pid].name, " ", aps_tmp_file);
printer[aps_pid].print_cmd = strcat("D:\\Programs\\gstools\\gsview\\gsview32.exe ", aps_tmp_file);
printer[aps_pid].view_cmd = strcat("D:\\Programs\\gstools\\gsview\\gsview32.exe ", aps_tmp_file);
printer[aps_pid].copy_of = 0;

aps_pid++;
printer[aps_pid].setup = "text, 1x1x2";
printer[aps_pid].name = "PR6730";
printer[aps_pid].description = "HP Postscript Printer, Convenience Center";
printer[aps_pid].columns = "1";
printer[aps_pid].rows = "1";
printer[aps_pid].fontsize = "8points";
printer[aps_pid].chars = "80:100";
printer[aps_pid].borders = "on";
printer[aps_pid].orientation = "portrait";
printer[aps_pid].medium = "A4";
printer[aps_pid].sides = "2";
printer[aps_pid].truncate = "off";
printer[aps_pid].linenumbers = "0";
printer[aps_pid].copies = "1";
printer[aps_pid].major = "columns";
printer[aps_pid].margin = "5";
printer[aps_pid].header = "";
printer[aps_pid].title_left = "";
printer[aps_pid].title_center = "";
printer[aps_pid].title_right = "";
%printer[aps_pid].footer_left = "%e %*";
%printer[aps_pid].footer_left = "%e";
printer[aps_pid].footer_left = "JEDDATETIME";
%printer[aps_pid].footer_center = "$f";
printer[aps_pid].footer_center = "JEDFILENAME";
printer[aps_pid].footer_right = "%s./%s#";
printer[aps_pid].color = "bw";
printer[aps_pid].pretty = "off";
%printer[aps_pid].print_cmd = strcat("lpr -P ", printer[aps_pid].name, " ", aps_tmp_file);
printer[aps_pid].print_cmd = strcat("D:\\Programs\\gstools\\gsview\\gsview32.exe ", aps_tmp_file);
printer[aps_pid].view_cmd = strcat("D:\\Programs\\gstools\\gsview\\gsview32.exe ", aps_tmp_file);
printer[aps_pid].copy_of = 0;

aps_pid++;
printer[aps_pid].setup = "PR6763_PCL color, A4, 2x1";
printer[aps_pid].name = "PR6763_PCL";
printer[aps_pid].description = "HP Color Inkjet, 114-E000";
printer[aps_pid].columns = "2";
printer[aps_pid].rows = "1";
printer[aps_pid].fontsize = "8points";
printer[aps_pid].chars = "80:100";
printer[aps_pid].borders = "on";
printer[aps_pid].orientation = "landscape";
printer[aps_pid].medium = "A4";
printer[aps_pid].sides = "1";
printer[aps_pid].truncate = "off";
printer[aps_pid].linenumbers = "5";
printer[aps_pid].copies = "1";
printer[aps_pid].major = "columns";
printer[aps_pid].margin = "5";
printer[aps_pid].header = "";
printer[aps_pid].title_left = "";
printer[aps_pid].title_center = "";
printer[aps_pid].title_right = "";
%printer[aps_pid].footer_left = "%e %*";
%printer[aps_pid].footer_left = "%e";
printer[aps_pid].footer_left = "JEDDATETIME";
%printer[aps_pid].footer_center = "$f";
printer[aps_pid].footer_center = "JEDFILENAME";
printer[aps_pid].footer_right = "%s./%s#";
printer[aps_pid].color = "color";
printer[aps_pid].pretty = "on";
%printer[aps_pid].print_cmd = strcat("lpr -P ", printer[aps_pid].name, " ", aps_tmp_file);
printer[aps_pid].print_cmd = strcat("D:\\Programs\\gstools\\gsview\\gsview32.exe ", aps_tmp_file);
printer[aps_pid].view_cmd = strcat("D:\\Programs\\gstools\\gsview\\gsview32.exe ", aps_tmp_file);
printer[aps_pid].copy_of = 0;

aps_pid++;
printer[aps_pid].setup = "text, 1x1x2, Testfloor";
printer[aps_pid].name = "PR6560";
printer[aps_pid].description = "HP Postscript Printer, Testfloor C1";
printer[aps_pid].columns = "1";
printer[aps_pid].rows = "1";
printer[aps_pid].fontsize = "8points";
printer[aps_pid].chars = "80:100";
printer[aps_pid].borders = "on";
printer[aps_pid].orientation = "portrait";
printer[aps_pid].medium = "A4";
printer[aps_pid].sides = "2";
printer[aps_pid].truncate = "off";
printer[aps_pid].linenumbers = "0";
printer[aps_pid].copies = "1";
printer[aps_pid].major = "columns";
printer[aps_pid].margin = "5";
printer[aps_pid].header = "";
printer[aps_pid].title_left = "";
printer[aps_pid].title_center = "";
printer[aps_pid].title_right = "";
%printer[aps_pid].footer_left = "%e %*";
%printer[aps_pid].footer_left = "%e";
printer[aps_pid].footer_left = "JEDDATETIME";
%printer[aps_pid].footer_center = "$f";
printer[aps_pid].footer_center = "JEDFILENAME";
printer[aps_pid].footer_right = "%s./%s#";
printer[aps_pid].color = "bw";
printer[aps_pid].pretty = "off";
%printer[aps_pid].print_cmd = strcat("lpr -P ", printer[aps_pid].name, " ", aps_tmp_file);
printer[aps_pid].print_cmd = strcat("D:\\Programs\\gstools\\gsview\\gsview32.exe ", aps_tmp_file);
printer[aps_pid].view_cmd = strcat("D:\\Programs\\gstools\\gsview\\gsview32.exe ", aps_tmp_file);
printer[aps_pid].copy_of = 0;


#endif


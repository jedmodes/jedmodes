% -*- mode: slang; mode: fold -*-
% 
%{{{ Documentation
%
% Description
% 
%   JED mode for editing Linux manpages.
%   
%   This mode implements a syntax highlighting scheme for editing Linux
%   manpages with groff macros, as described in the man(7) and groff_man(7)
%   manpages in any decent Linux distribution. 
%   
%   There are also some utility functions that can make life much easier for 
%   the developer. Via the "Template" menu option one can even craft a manpage 
%   without knowing the theory behind such magic. The functions should, 
%   preferably, be chosen from the mode menu, but can of course also be bound 
%   to key combination of ones personal preference. 
%   
% Implementation notes
% 
%   Since I wanted to highlight escape sequences and that had to be done by
%   enabling TeX-like keywords, those are highlighted using the keyword color 
%   and regular nroff macros using the keyword1 color.
%
%   Some things are still missing (see Todo below), but the mode is already 
%   very useful, at least to me. Important documentation on section and font
%   standards is included in their respective function definitions. 
%   
%   I borrowed a piece of code from the standard nroff mode, which is very
%   limited in features.
%
% Usage
% 
%   Put this file in your JED_LIBRARY path and add the following lines to your
%   startup file (.jedrc or jed.rc):
%
%     autoload("manedit_mode", "manedit");
%     add_mode_for_extension("manedit", "man");
%     add_mode_for_extension("manedit", "1");
%     ...
%     add_mode_for_extension("manedit", "8");
%
%   Every time you open a file called something.man or something.1 etc., 
%   manedit_mode will automatically be loaded.
%   
%   There are also a couple of variables that can be changed in .jedrc like 
%   this (default values are shown):
%   
%     variable manedit_par_macro   = ".PP";   % .PP, .LP or .P are synonyms
%     variable manedit_dot_section = "1";     % 1 puts a '.' before sections
%   
% Changelog
%
%   1.0.1 - 2002/02/21:
%     - Bugfix: Default size in the mode menu outputted *S instead of \*S.
%     
%   1.0   - 2002/01/16:
%     - First public release.
%
% Todo
% 
%   - DFA patterns.
%   - "Transform region" functionality.
%   
% Author
% 
%   Johann Gerell, johann dot gerell at home dot se
%
%}}}

$0 = "manedit";

%{{{ Syntax definition
create_syntax_table($0);
define_syntax(".\\\"", "", '%', $0);	            % comment
define_syntax('\\', '\\', $0);		            % quote character
define_syntax(".a-zA-Z0-9(){}*$-%\"'`[]", 'w', $0); % word chars
set_syntax_flags($0, 0x08);                         % highlight quoted words
%}}}
%{{{ Keywords: the macros described in the man(7) manpage
() = define_keywords_n($0, ".", 1, 1);
() = define_keywords_n($0, ".B.I.P", 2, 1);
() = define_keywords_n($0, ".BI.BR.HP.IB.IP.IR.LP.PP.RB.RE.RI.RS.SB.SH.SM.SS.TH.TP.UE.UN.UR", 3, 1);
%}}}

custom_variable("manedit_par_macro", ".PP");   % one of .LP, .P or .PP
custom_variable("manedit_dot_section", 1);     % dot before section, 0 or 1

define manedit_parsep() { %{{{
  bol();
  (looking_at_char('.') or looking_at_char('\\') or (skip_white(), eolp()));
}
%}}}
define manedit_insert_title() { %{{{
  bol;
  !if(_NARGS) {
    variable t   = read_mini("Title:", "", "APPNAME"),
             se  = read_mini("Section:", "", "1"),
             d   = read_mini("Date:", "", "2002-01-01"),
             so  = read_mini("Source:", "", "GNU"),
             m   = read_mini("Manual:", "", "The Application Manual"),
             sep = "\" \"";
    insert(".TH \"" + t + sep + se + sep + d + sep + so + sep + m + "\"\n");
  }
  else insert(".TH \"APPNAME\" \"1\" \"2002-01-01\" \"GNU\" \"The Application Manual\"\n");
}
%}}}
define manedit_insert_section(name) { %{{{
  % The only required heading is NAME, which should be the first section and
  % be followed on the next line by a one line description of the program:
  %
  %   .SH NAME
  %   chess \- the game of chess
  %
  % It is extremely important that this format is followed, and that there is
  % a backslash before the single dash which follows the command name. This
  % syntax is used by the makewhatis(8) program to create a database of short
  % command descriptions for the whatis(1) and apropos(1) commands.
  %
  % Some other traditional sections have the following contents:
  %
  % SYNOPSIS briefly describes the command or  function's interface. For 
  % commands, this  shows the syntax of the command and its arguments
  % (including options); boldface is used for as-is text and italics are used
  % to indicate replaceable arguments. Brackets ([]) surround optional
  % arguments, vertical bars (|) separate choices, and ellipses (...) can be
  % repeated. For functions, it shows any required data declarations or
  % #include directives, followed by the function  declaration.
  %
  % DESCRIPTION gives an explanation of what the command, function, or format
  % does. Discuss how it interacts with files and standard input, and whhat it
  % produces on standard output or standard error. Omit internals and
  % implementation details unless they're critical for understanding the
  % interface. Describe the usual case; for information on options use the
  % OPTIONS section. If there is some kind of input grammar or complex set of
  % subcommands, consider describing them in a separate USAGE section (and 
  % just place an overview in the DESCRIPTION section).
  %
  % RETURN VALUE gives a list of the values the library routine will return to
  % the caller and the conditions that cause these values to be returned.
  %
  % EXIT STATUS lists the possible exit status values or a program and the 
  % conditions that cause these values to be returned.
  %
  % OPTIONS describes the options accepted by the program and how they change 
  % its behavior.
  %
  % USAGE describes the grammar of any sublanguage this implements.
  %
  % FILES lists the files the program or function uses, such as configuration
  % files, startup files, and files the program directly operates on. Give the 
  % full pathname of these files, and use the installation process to modify
  % the directory part to match user preferences. For many programs, the
  % default installation location is in /usr/local, so your base manual page
  % should use /usr/local as the base.
  %
  % ENVIRONMENT lists all environment variables that affect your program or
  % function and how they affect it.
  %
  % DIAGNOSTICS gives an overview of the most common error messages and how to 
  % cope with them. You don't need to explain system error messages or fatal
  % signals that can appear during execution of any program unless they're 
  % special in some way to your program.
  %
  % SECURITY discusses security issues and  implications. Warn about 
  % configurations or environments that should be avoided, commands that may
  % have security implications, and so on, especially if they aren't obvious. 
  % Discussing security in a separate section isn't necessary; if it's easier
  % to understand, place security information in the other sections (such as 
  % the DESCRIPTION or USAGE  section). However, please include security
  % information somewhere!
  %
  % CONFORMING TO describes any standards or conventions this implements.
  %
  % NOTES provides miscellaneous notes.
  %
  % BUGS lists limitations, known defects or inconveniences, and other 
  % questionable  activities.
  %
  % AUTHOR lists authors of the documentation or program so you can mail in
  % bug reports.
  %
  % SEE ALSO lists related man pages in alphabetical order, possibly followed  
  % by other related pages or documents. Conventionally this is the last 
  % section.
  
  !if(bolp()) bol();
  if(manedit_dot_section) insert(".\n");
  if(name == "NAME") insert(".SH NAME\nappname \- short description\n");
  else if(name == "SS") insert(".SS Subsection name\n");
  else insert(".SH " + name + "\n");
}
%}}}
define manedit_insert_font(font) { %{{{
  % For functions, the arguments are always specified using italics, even in 
  % the SYNOPSIS section, where the rest of the function is specified in bold:
  %
  % Filenames are always in italics, except in the SYNOPSIS section, where 
  % included files are in bold.
  %  
  % Special macros, which are usually in upper case, are in bold.
  %
  % When enumerating a list of error codes, the codes are in bold (this list 
  % usually uses the .TP macro).
  %
  % Any reference to another man page (or to the subject of the current man
  % page) is in bold. If the manual section number is given, it is given in
  % Roman (normal) font, without any spaces.
  %
  % The commands to select the type face are:
  %
  % .B  Bold
  % .BI Bold alternating with italics (function specifications)
  % .BR Bold alternating with Roman (for referring to other manual pages)
  % .I  Italics
  % .IB Italics alternating with bold
  % .IR Italics alternating with Roman
  % .RB Roman alternating with bold
  % .RI Roman alternating with italics
  % .SB Small alternating with bold
  % .SM Small (useful for acronyms)
  %
  % Traditionally, each command can have up to six arguments, but the GNU 
  % implementation removes this limitation (you might still want to limit 
  % yourself to 6 arguments for portability's sake). Arguments are delimited
  % by spaces. Double quotes can be used to specify an argument which contains 
  % spaces. All of the arguments will be printed next to each other without 
  % intervening spaces, so that the .BR command can be used to specify a word 
  % in bold followed by a mark of punctuation in Roman. If no arguments are
  % given, the command is applied to the following line of text.
  
  bol(); insert(font + " \n"); up_1; eol;
}
%}}}
define manedit_insert_paragraph() { %{{{
  bol; insert(manedit_par_macro + "\n");
}
%}}}
define manedit_insert_relative_indent(start) { %{{{
  bol;
  if(start) insert(".RS " + read_mini("Length [default is the prevailing indent]:", "", "") + "\n");
  else insert(".RE\n");
}
%}}}
define manedit_insert_indented_paragraph(type) { %{{{
  bol;
  if(type == 1) insert(".HP " + read_mini("Length [default is the prevailing indent]:", "", "") + "\n");
  else if(type == 2) insert(".IP " + read_mini("Tag:", "", "") + read_mini("Length [default is the prevailing indent]:", "", "") + "\n");
  else if(type == 3) insert(".TP " + read_mini("Length [default is the prevailing indent]:", "", "") + "\n...tagline...\n");
  else if(type == 4) insert(".IP \\(bu\nitem\n.IP \\(bu\nitem\n.IP \\(bu\nitem\n");
  else if(type == 5) insert(".IP \\(em\nitem\n.IP \\(em\nitem\n.IP \\(em\nitem\n");
  else if(type == 6) insert(".IP 1.\nitem\n.IP 2.\nitem\n.IP 3.\nitem\n");
  else if(type == 7) insert(".IP a.\nitem\n.IP b.\nitem\n.IP c.\nitem\n");
}
%}}}
define manedit_insert_hypertext(type) { %{{{
  bol;
  if(type == 1) insert(".UR " + read_mini("URL:", "", "") + "\n.UE\n");
  else if(type == 2) insert(".UN " + read_mini("Name:", "", "") + "\n");
}
%}}}
define manedit_insert_template() { %{{{
  manedit_insert_title(1);
  manedit_insert_section("NAME");
  manedit_insert_section("SYNOPSIS");
  manedit_insert_section("DESCRIPTION");
  manedit_insert_section("OPTIONS");
  manedit_insert_section("USAGE");
  manedit_insert_section("FILES");
  manedit_insert_section("NOTES");
  manedit_insert_section("BUGS");
  manedit_insert_section("AUTHOR");
  manedit_insert_section("SEE ALSO");
  bob; 
  if(manedit_dot_section) go_down(6);
  else go_down(4);
  insert("\n"); up_1;
}
%}}}
define manedit_menu(menu) {  %{{{
  menu_append_item(menu, "&Title", "manedit_insert_title");
  %{{{ Section
  menu_append_popup(menu, "&Section");
  menu_append_item(menu + ".&Section", "&NAME", "manedit_insert_section(\"NAME\")");
  menu_append_item(menu + ".&Section", "&SYNOPSIS", "manedit_insert_section(\"SYNOPSIS\")");
  menu_append_item(menu + ".&Section", "&DESCRIPTION", "manedit_insert_section(\"DESCRIPTION\")");
  menu_append_item(menu + ".&Section", "&RETURN VALUE", "manedit_insert_section(\"RETURN VALUE\")");
  menu_append_item(menu + ".&Section", "E&XIT STATUS", "manedit_insert_section(\"EXIT STATUS\")");
  menu_append_item(menu + ".&Section", "ERR&OR HANDLING", "manedit_insert_section(\"ERROR HANDLING\")");
  menu_append_item(menu + ".&Section", "&ERRORS", "manedit_insert_section(\"ERRORS\")");
  menu_append_item(menu + ".&Section", "O&PTIONS", "manedit_insert_section(\"OPTIONS\")");
  menu_append_item(menu + ".&Section", "&USAGE", "manedit_insert_section(\"USAGE\")");
  menu_append_item(menu + ".&Section", "&FILES", "manedit_insert_section(\"FILES\")");
  menu_append_item(menu + ".&Section", "EN&VIRONMENT", "manedit_insert_section(\"ENVIRONMENT\")");
  menu_append_item(menu + ".&Section", "D&IAGNOSTICS", "manedit_insert_section(\"DIAGNOSTICS\")");
  menu_append_item(menu + ".&Section", "SECURIT&Y", "manedit_insert_section(\"SECURITY\")");
  menu_append_item(menu + ".&Section", "CONFOR&MING TO", "manedit_insert_section(\"CONFORMING TO\")");
  menu_append_item(menu + ".&Section", "NO&TES", "manedit_insert_section(\"NOTES\")");
  menu_append_item(menu + ".&Section", "&BUGS", "manedit_insert_section(\"BUGS\")");
  menu_append_item(menu + ".&Section", "&AUTHOR", "manedit_insert_section(\"AUTHOR\")");
  menu_append_item(menu + ".&Section", "SEE A&LSO", "manedit_insert_section(\"SEE ALSO\")");
  menu_append_separator(menu + ".&Section");
  menu_append_popup(menu + ".&Section", "Mis&c");
  menu_append_item(menu + ".&Section.Mis&c", "&Generic", "manedit_insert_section(\"Section name\")");
  menu_append_item(menu + ".&Section.Mis&c", "&Subsection", "manedit_insert_section(\"SS\")");
  %}}}
  %{{{ Font
  menu_append_popup(menu, "&Font");
  menu_append_item(menu + ".&Font", "&Bold", "manedit_insert_font(\".B\")");
  menu_append_item(menu + ".&Font", "B&old/Italics", "manedit_insert_font(\".BI\")");
  menu_append_item(menu + ".&Font", "Bo&ld/Roman", "manedit_insert_font(\".BR\")");
  menu_append_separator(menu + ".&Font");
  menu_append_item(menu + ".&Font", "&Italics", "manedit_insert_font(\".I\")");
  menu_append_item(menu + ".&Font", "I&talics/Bold", "manedit_insert_font(\".IB\")");
  menu_append_item(menu + ".&Font", "It&alics/Roman", "manedit_insert_font(\".IR\")");
  menu_append_separator(menu + ".&Font");
  menu_append_item(menu + ".&Font", "&Roman/Bold", "manedit_insert_font(\".RB\")");
  menu_append_item(menu + ".&Font", "Ro&man/Italics", "manedit_insert_font(\".RI\")");
  menu_append_separator(menu + ".&Font");
  menu_append_item(menu + ".&Font", "Small/Bol&d", "manedit_insert_font(\".SB\")");
  menu_append_item(menu + ".&Font", "&Small", "manedit_insert_font(\".SM\")");
  menu_append_separator(menu + ".&Font");
  menu_append_item(menu + ".&Font", "&Default size", "insert(\"\\\\*S\")");
  %}}}
  %{{{ Indent
  menu_append_popup(menu, "&Indent");
  menu_append_popup(menu + ".&Indent", "&Relative indent");
  menu_append_item(menu + ".&Indent.&Relative indent", "&Start", "manedit_insert_relative_indent(1)");
  menu_append_item(menu + ".&Indent.&Relative indent", "&End", "manedit_insert_relative_indent(0)");
  menu_append_popup(menu + ".&Indent", "&Hanging indent");
  menu_append_item(menu + ".&Indent.&Hanging indent", "&Normal", "manedit_insert_indented_paragraph(1)");
  menu_append_item(menu + ".&Indent.&Hanging indent", "&Short tag", "manedit_insert_indented_paragraph(2)");
  menu_append_item(menu + ".&Indent.&Hanging indent", "&Long tag", "manedit_insert_indented_paragraph(3)");
  %}}}
  %{{{ Lists
  menu_append_popup(menu, "&Lists");
  menu_append_item(menu + ".&Lists", "&Bullet", "manedit_insert_indented_paragraph(4)");
  menu_append_item(menu + ".&Lists", "&Dash", "manedit_insert_indented_paragraph(5)");
  menu_append_item(menu + ".&Lists", "&Number", "manedit_insert_indented_paragraph(6)");
  menu_append_item(menu + ".&Lists", "&Alpha", "manedit_insert_indented_paragraph(7)");
  %}}}
  %{{{ Hypertext
  menu_append_popup(menu, "&Hypertext");
  menu_append_item(menu + ".&Hypertext", "&URL", "manedit_insert_hypertext(1)");
  menu_append_item(menu + ".&Hypertext", "&Name", "manedit_insert_hypertext(2)");
  %}}}
  %{{{ Symbol
  menu_append_popup(menu, "S&ymbol");
  menu_append_item(menu + ".S&ymbol", "&Registration", "insert(\"\\\\*R\")");
  menu_append_item(menu + ".S&ymbol", "&Trademark", "insert(\"\\\\*(Tm\")");
  menu_append_item(menu + ".S&ymbol", "&Left quotemark", "insert(\"\\\\*(lq\")");
  menu_append_item(menu + ".S&ymbol", "R&ight quotemark", "insert(\"\\\\*(rq\")");
  menu_append_item(menu + ".S&ymbol", "&Backslash", "insert(\"\\\\e\")");
  %}}}
  menu_append_item(menu, "&Paragraph", "manedit_insert_paragraph");
  menu_append_separator(menu);
  menu_append_item(menu, "Te&mplate", "manedit_insert_template");
}
%}}}

define manedit_mode() {
  set_mode("manedit", 1);
  use_syntax_table("manedit");
  set_buffer_hook("par_sep", "manedit_parsep");
  set_comment_info("manedit", ".\\\" ", "", 0);
  mode_set_mode_info("manedit", "init_mode_menu", &manedit_menu);
  run_mode_hooks("manedit_mode_hook");
}

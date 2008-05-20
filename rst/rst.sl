% rst.sl: Mode for reStructured Text
% **********************************
% 
% Copyright (c) 2004, 2006 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
% 
% ReStructuredText_ (from Python docutils_) is a revision of Structured
% Text, a simple markup language that can be translated to Html and LaTeX (and
% more, if someone writes a converter).
% This mode turns Jed into an IDE for reStructured Text.
% 
% .. _ReStructuredText: http://docutils.sourceforge.net/docs/rst/quickref.html
% .. _docutils:         http://docutils.sourceforge.net/
% 
% .. contents::
% 
% Versions
% ========
% 
% .. class:: borderless
%
% ===== ========== ============================================================
% 1.1   2004-10-18 initial attempt
% 1.2   2004-12-23 removed dependency on view mode (called by runhooks now)
% 1.2.1 2005-03-11 bugfix in Mode>Layout>Hrule
%                  bugfix remove spurious ":" from anonymous target markup
% 1.3   2005-04-14 restructuring of the export and view functions
% 1.3.1 2005-11-02 hide "public" in some functions
% 1.3.2 2005-11-08 changed _implements() to implements()
% 1.3.3 2006-01-09 separated Html and Latex output options
% 1.4   2006-03-29 improved syntax highlight
%                  removed dependency on ishell.sl
%                  merged export help into set_rst2*_options()
%                  nagivation buffer with tokenlist
% 1.4.1 2006-05-18 fix syntax for sub- and supscript
%                  conservative highlight of list markers
% 1.4.2 2006-05-26 fixed autoloads (J. Sommer)
% 1.5              new menu entry names matching the docutils use of terms
% 1.5.1 2006-08-14 Adapted to structured_text v. 0.5 (do not call text_mode()).
% 1.5.2 2006-11-27 Bugfix: let rst_mode() really call the structured_text_hook
% 1.6   2006-11-28 Drop the .py ending from the Rst2* custom variables defaults
%                  use do_shell_cmd() for error redirection
% 1.7   2007-02-06 * Removed the Rst2*_Options custom variables.
%                    (Set the command line options in Rst2*_Cmd and change
%                    with set_export_options(cmd) (or from Mode menu))
%                  * "Directives" menu entry (incomplete)
%                  * Support PDF export with rst2pdf.py
%                  * Menu entries to browse docutils html documentation with
%                    browse_url() (you probabely need to set
%                    Rst_Documentation_Path on non Debian systems)
%                  * goto error line from export output buffer (with filelist)
%                  * section_markup(): go up if standing at the underline
%                  * Erase the export output buffer before exporting
%                  * rename rst_list_routines_hook() to
%                    rst_list_routines_done() to match the new tokenlist.sl
% 1.7.1 2007-02-26 * the rst2pdf.py script did not work. It is replaced by
%                    `py.rest --topdf`.
% 1.8   2007-03-13 Replace set_export_options() with set_export_cmd()
% 1.8.1 2007-03-30 Unit testing and fixes
% 1.8.2 2007-05-14 * removed leading \n from Markup_Tags,
%                    (handled by insert_block_markup() since textutils 2.6.3)
%                  * simplified dfa rules using ""R string suffix
%                  * rst_levels: use String instead of List
% 1.9   2007-07-23 * rename section_markup() to section_header(), allow
%                    integer arguments (section level)
%                  * new functions rst_view() and rst_view_html(),
%                    rst_view_pdf, rst_view_latex obsoleting rst_browse()
% 1.9.1 2007-10-18 * update to work with tokenlist.sl newer than 2007-05-09
% 1.9.2 2007-10-23 * Add admonitions popup to the Directives menu
%                  * use hard-coded TAB in non-expanded (""R) syntax rules
%                  * add '.' to chars allowed in crossreference marks
% 2.0   2007-11-06 * highlight simple table rules
%                  * fix fold info
%                  * outline functionality (fold sections, fast moving)
% 2.1   2007-11-13 * rewrite syntax highlight rules with ""$ string
%                    replacement (Attention! can lead to segfaults with older,
%                    buggy S-Lang versions: update S-Lang or downgrade rst.sl)
%                  * more work on "rst-fold"
% 2.2   2007-11-15 * custom colors.
% 2.3   2008-01-11 * section headings: allow for adorning with overline,
%                  * split outline and section functions to rst-outline.sl,
%                  * implement J. Sommer's fix for DFA under UTF-8,
% 2.3.1 2008-01-22 * made export_cmds static for better testing
% 		     and configuring.
% 2.3.2 2008-05-05 * DFA fix for interpreted text
% 2.3.3 2008-05-20 * one more DFA tweak

% ===== ========== ============================================================
% 
% TODO
% ====
% 
% * jump from reference to target and back again
% * "link creation wizard"
% * line-block: if no visible region, mark paragraph, prefix all lines with "| "
%               (with prefix argument: remove the "| ")
% * Look at demo.txt and refine the syntax highlight
% 
% Requirements
% ============

% extra modes (from http://jedmodes.sf.net/mode/)::

require("structured_text");  % >= 0.5
require("rst-outline");      % outline with rst section markup

autoload("push_defaults", "sl_utils");
autoload("push_array", "sl_utils");
autoload("prompt_for_argument", "sl_utils");
autoload("get_blocal", "sl_utils");
autoload("popup_buffer", "bufutils");
autoload("buffer_dirname", "bufutils");
autoload("close_buffer", "bufutils");
autoload("fit_window", "bufutils");
autoload("run_buffer", "bufutils");
autoload("insert_markup", "txtutils");   % >= 2.3
autoload("insert_block_markup", "txtutils");   % >= 2.3


% Recommendations
% ===============
% 
% Jump to the error locations from output buffer::

#if (expand_jedlib_file("filelist.sl") != "")
autoload("filelist_mode", "filelist");
#endif

% Browse documentation::

#if (expand_jedlib_file("browse_url.sl") != "")
autoload("browse_url", "browse_url");
#endif

% Initialization
% --------------

% Name and Namespace
% ===================
% Namespace "rst" is defined in rst-outline.sl already required by this file::

provide("rst");
use_namespace("rst");
private variable mode = "rst";

% Customizable Defaults
% =====================
% ::

%!%+
%\variable{Rst2Html_Cmd}
%\synopsis{ReStructured Text to Html converter}
%\usage{String_Type Rst2Html_Cmd = "rst2html"}
%\description
% Shell command and options for the ReStructured Text to Html converter
%
% Command and options can be changed from the "Mode>Set Export Cmd >>>" menu
% popup. However, these changes are only valid for the current jed session.
% Permanent changes should be done by defining the variable in the jed.rc
% file.
%\notes
% The default works if the executable `rst2html` is installed in the
% PATH (e.g. with the Debian package python-docutils.deb).
%\seealso{rst_mode, Rst2Latex_Cmd, Rst2Pdf_Cmd}
%!%-
custom_variable("Rst2Html_Cmd", "rst2html");

%!%+
%\variable{Rst2Latex_Cmd}
%\synopsis{ReStructured Text to LaTeX converter}
%\usage{String_Type Rst2Latex_Cmd = "rst2latex"}
%\description
% Shell command and options for the ReStructured Text to LaTeX converter.
%
% Command and options can be changed from the "Mode>Set Export Cmd >>>" menu
% popup. However, these changes are only valid for the current jed session.
% Permanent changes should be done by defining the variable in the jed.rc
% file.
%\notes
% The default works if the executable `rst2latex` is installed in the
% PATH (e.g. with the Debian package python-docutils.deb).
%\seealso{rst_mode, Rst2Pdf_Cmd, Rst2Html_Cmd}
%!%-
custom_variable("Rst2Latex_Cmd", "rst2latex");

%!%+
%\variable{Rst2Pdf_Cmd}
%\synopsis{ReStructured Text to LaTeX converter}
%\usage{String_Type Rst2Pdf_Cmd = "rst2pdf.py"}
%\description
% Shell command and options for the ReStructured Text to LaTeX converter.
%
% Command and options can be changed from the "Mode>Set Export Cmd >>>" menu
% popup. However, these changes are only valid for the current jed session.
% Permanent changes should be done by defining the variable in the jed.rc
% file.
%\notes
% The default works if the executable `py.rest` is installed in the
% PATH (e.g. with the Debian package `python-codespeak-lib`).
%\seealso{rst_mode, Rst2Pdf_Cmd, Rst2Html_Cmd}
%!%-
custom_variable("Rst2Pdf_Cmd", "py.rest --topdf");

%!%+
%\variable{Rst_Documentation_Path}
%\synopsis{Base URL of the Docutils Project Documentation}
%\usage{variable Rst_Documentation_Path = "file:/usr/share/doc/python-docutils/docs/"}
%\description
%  Pointer to the Docutils Project Documentation
%  which will be opened by the Mode>Help>Doc Overview menu entry.
%
%  The default works with the Debian "python-docutils" package.
%  Set to your local documentation mirror or "http://docutils.sf.net/docs/"
%\seealso{rst_mode}
%!%-
custom_variable("Rst_Documentation_Path",
   "file:/usr/share/doc/python-docutils/docs/");

%!%+
%\variable{Rst_Html_Viewer}
%\synopsis{External program to view HTML rendering of rst documents}
%\usage{variable Rst_Html_Viewer = "firefox"}
%\description
%  The command started by \sfun{rst_view_html}
%\seealso{Rst_Pdf_Viewer, Rst2Html_Cmd, rst->rst_view, rst_to_html}
%!%-
custom_variable("Rst_Html_Viewer", "firefox");

%!%+
%\variable{Rst_Pdf_Viewer}
%\synopsis{External program to view PDF rendering of rst documents}
%\usage{variable Rst_Pdf_Viewer = "xpdf"}
%  The command started by \sfun{rst_view_pdf}
%\seealso{Rst_Html_Viewer, Rst2Pdf_Cmd, rst->rst_view, rst_to_pdf}
%!%-
custom_variable("Rst_Pdf_Viewer", "xpdf");

% Color Definitions
% -----------------
% ::

% defined since Jed 0-99.18
custom_color("bold",             get_color("error"));     
custom_color("italic",           get_color("operator"));    
custom_color("url",              get_color("keyword"));
custom_color("underline",        get_color("delimiter"));
% local extensions
custom_color("rst_literal",      get_color("bold"));
custom_color("rst_interpreted",  get_color("string"));    
custom_color("rst_substitution", get_color("preprocess"));  
custom_color("rst_list_marker",  get_color("number")); % operator?
custom_color("rst_line",         get_color("underline"));   
custom_color("rst_reference",    get_color("keyword"));   
custom_color("rst_target",       get_color("keyword1"));   
custom_color("rst_directive",    get_color("keyword2"));  

% Internal Variables
% ------------------
% ::

private variable helpbuffer = "*rst export help*";

% Pointer to the export command string for a given file extension
static variable export_cmds = Assoc_Type[Ref_Type];
export_cmds["html"] = &Rst2Html_Cmd;
export_cmds["tex"] = &Rst2Latex_Cmd;
export_cmds["pdf"] = &Rst2Pdf_Cmd;

% Markup strings ::

static variable Markup_Tags = Assoc_Type[Array_Type];

% Layout Character (inline)
Markup_Tags["strong"]      = ["**", "**"];     % bold
Markup_Tags["emphasis"]    = ["*",  "*"];      % usually typeset as italics
Markup_Tags["literal"]     = ["``", "``"];     % usually fixed width
Markup_Tags["interpreted"] = ["`", "`"];
Markup_Tags["subscript"]   = [":sub:`", "`"];
Markup_Tags["superscript"] = [":sup:`", "`"];

% Layout Pragraph (block)
Markup_Tags["hrule"]         = ["\n-------------\n", ""];  % transition
Markup_Tags["preformatted"] = ["::\n    ", "\n"];

% References (outgoing links, occure in the text)
Markup_Tags["hyperlink_ref"]                = ["`", "`_"];   % hyperlink, anchor
Markup_Tags["anonymous_hyperlink_ref"]      = ["`", "`__"];
Markup_Tags["hyperlink_embedded"]           = ["`<", ">`_"];
Markup_Tags["anonymous_hyperlink_embedded"] = ["`<", ">`__"]; % "one-off" hyperlink
Markup_Tags["numeric_footnote_ref"]         = ["",  " [#]_"]; % automatic  numbering
Markup_Tags["symbolic_footnote_ref"]        = ["",  " [*]_"]; % automatic  numbering
Markup_Tags["citation_ref"]                 = ["[", "]_"];    % also for footnotes
Markup_Tags["substitution_ref"]             = ["|", "|"];

% Reference Targets
Markup_Tags["hyperlink"]           = [".. _", ":"];   % URL, crossreference
Markup_Tags["anonymous_hyperlink"] = ["__ ", ""];
Markup_Tags["numeric_footnote"]   = [".. [#] ", ""];   % automatic  numbering
Markup_Tags["symbolic_footnote"]  = [".. [*] ", ""];   % automatic  numbering
Markup_Tags["citation"]           = [".. [", "]"];
Markup_Tags["directive"]          = [".. ", "::"];
Markup_Tags["substitution"]       = [".. |", "|"];

% Functions
% =========
% 
% Export
% ------
% ::

private define get_outfile(format)
{
   variable outfile = path_sans_extname(whatbuf())+ "." + format;
   outfile = path_concat(buffer_dirname(), outfile);
   return outfile;
}

% export the buffer/region to outfile using export_cmds[]
static define rst_export() % (format, outfile=get_outfile(format))
{
   variable format, outfile;
   (format, outfile) = push_defaults( , , _NARGS);

   if (format == NULL)
     format = read_with_completion(strjoin(assoc_get_keys(export_cmds), ","),
      "Export buffer to ", "html", "", 's');

   if (outfile == NULL)
     outfile = get_outfile(format);
   else if (outfile != "") % complete path if relative path is given
     outfile = path_concat(buffer_dirname(), outfile);

   % Assemble export command line:
   variable cmd = @export_cmds[format];
   % do not specify outfile for `py.rest`
   if (extract_element(cmd, 0, ' ') == "py.rest")
     outfile = "";
   cmd = strjoin([cmd, buffer_filename(), outfile], " ");

   save_buffer();
   flush("exporting to " + format);
   popup_buffer("*rst export output*");
   set_readonly(0);
   erase_buffer();
   set_prefix_argument(1);
   do_shell_cmd(cmd);
   set_buffer_modified_flag(0);
   if (bobp and eobp)
     close_buffer();
   else
     {
      fit_window(get_blocal("is_popup", 0));
#ifexists filelist_mode
      % jump to the error locations
      define_blocal_var("delimiter", ':');
      define_blocal_var("line_no_position", 1);
      filelist_mode();
#endif
     }

   message("exported to " + outfile);
}

% export to html
public  define rst_to_html()
{
   rst_export("html");
}

% export to LaTeX
public  define rst_to_latex()
{
   rst_export("tex");
}

% export to PDF
public  define rst_to_pdf()
{
     rst_export("pdf");
}

% View output files
% -----------------
% ::

% View the rst document in `format'
static define rst_view() % (format, outfile=get_outfile(format), viewer)
{
   variable format, outfile, viewer;
   (format, outfile, viewer) = push_defaults( , , , _NARGS);

   if (format == NULL)
     format = read_with_completion(strjoin(assoc_get_keys(export_cmds), ","),
      "Export buffer to ", "html", "", 's');

   if (outfile == NULL)
     outfile = get_outfile(format);
   else % complete path if relative path is given
     outfile = path_concat(buffer_dirname(), outfile);

   if (viewer == NULL)
   variable cmd_var = sprintf("Rst_%s_Viewer",
      strup(format[[:0]])+strlow(format[[1:]]));
   if (is_defined(cmd_var))
     viewer = @(__get_reference(cmd_var));
   else
     viewer = "";

   % recreate outfile, if the buffer is newer
   save_buffer();
   if (file_time_compare(buffer_filename(), outfile) > 0)
     rst_export(format, outfile);

   % open outfile with viewer (or in a new buffer, if viewer is empty string)
   if (viewer == "")
     {
        () = find_file(outfile);
        return;
     }

   % convert `outfile' to URL if `format' is html
   if (format == "html")
     outfile = "file:" + outfile;

   if (getenv("DISPLAY") != NULL) % assume X-Windows running
       () = system(viewer + " " + outfile + " &");
   else
     () = run_program(viewer + " " + outfile);
}

% View the html conversion of the current buffer in an external browser
public  define rst_view_html()
{
   rst_view("html");
}

% Find the LaTeX conversion of the current buffer
public  define rst_view_latex() % (outfile=*.tex, viewer="")
{
   rst_view("tex");
}

% View the pdf conversion of the current buffer with Rst_Pdf_Viewer
public  define rst_view_pdf() % (outfile=*.pdf, viewer=Rst_Pdf_Viewer)
{
   rst_view("pdf");
}

% open popup-buffer with help for cmd
% TODO: this is of more general interest. where to put it?
static define command_help(cmd)
{
   popup_buffer(helpbuffer, 1.0);
   set_prefix_argument(1);
   do_shell_cmd(extract_element(cmd, 0, ' ') + " --help");
   fit_window(get_blocal("is_popup", 0));
   set_buffer_modified_flag(0);
   call_function("view_mode");
   bob();
}

% set Rst2* (export command) command and options for export_type
% (see private variable export_cmds for available export types,
%  e.g. "html", "tex", pdf")
static define set_export_cmd(export_type)
{
   variable cmd_var = export_cmds[export_type]; % variable reference
   @cmd_var = read_mini(strup(export_type)+" export cmd and options:", 
			"", @cmd_var);
}

% Markup
% ------
% ::

% insert a markup
static define markup(type)
{
   insert_markup(Markup_Tags[type][0], Markup_Tags[type][1]);
}

% insert markup and (re) indent
static define block_markup(type)
{
   insert_block_markup(Markup_Tags[type][0], Markup_Tags[type][1]);
}

static define insert_directive(name)
{
   !if (bolp())
     newline();
   vinsert(".. %s:: ", name);
}


% Syntax Highlight
% ================
% Sample files (on my box):
% ~/Code/Python/docutils-svn/docutils/docs/user/rst/cheatsheet.txt
% ~/Code/Python/docutils-svn/docutils/docs/user/rst/demo.txt
% ::

create_syntax_table (mode);
define_syntax( '\\', '\\', mode);               % escape character
set_syntax_flags (mode, 0);

% keywords
% admonitions
() = define_keywords_n(mode, "hintnote", 4, 0);
() = define_keywords_n(mode, "attention", 9, 0);

#ifdef HAS_DFA_SYNTAX
%%% DFA_CACHE_BEGIN %%%

% Inline Markup
% 
% The rules for inline markup are stated in quickref.html. They cannot be
% easily and fully translated to DFA syntax, as
% 
%  * in JED, DFA patterns do not cross lines
%  * excluding visible patterns outside the to-be-highlighted region via
%    e.g. [^a-z] will erroneously color allowed chars.
%  * also, [-abc.] must be written [\\-abc\\.]
% 
% Therefore only a subset of inline markup will be highlighted correctly.
% 
% Felix Wiemann recommendet in a mail at Docutils-users:
% 
%   You can have a look at docutils/parsers/rst/states.py.  It contains all
%   the regular expressions needed to parse reStructuredText, even though
%   they may not be in the format in which you need them.
% 
% ::

private define dfa_rule(rule, color)
{
   dfa_define_highlight_rule(rule, color, $1);
}

% Inline markup start-string and end-string recognition rules
% -----------------------------------------------------------
% 
% If any of the conditions are not met, the start-string or end-string
% will not be recognized or processed.
% 
% 1. start-strings must start a text block or be immediately
%    preceded by whitespace or one of: ' " ( [ { < - / :
% 2. start-strings must be immediately followed by non-whitespace.
% 3. end-strings must be immediately preceded by non-whitespace.
% 4. end-strings must end a text block or be immediately followed
%    by whitespace or one of: ' " ) ] } > - / : . , ; ! ? \
% 5. If a start-string is immediately preceded by a single or
%    double quote, "(", "[", "{", or "<", it must not be immediately followed
%    by the corresponding single or double quote, ")", "]", "}", or ">".
% 6. An end-string must be separated by at least one character
%    from the start-string.
% 7. An unescaped backslash preceding a start-string or end-string will
%    disable markup recognition, except for the end-string of inline literals.
%    See Escaping Mechanism above for details.
%    
% Return a regexp pattern for inline markup with string `s`.
% Due to limitations in Jed's DFA syntax, only a part of the algorithm can
% be reproduced:
%    
% * 1 and 5 not implemented: 
%    
%   * matching char would be highlighted
%   * start|end of line or white (^|[ \t]) and ($|[ \t]) seems not to work
%    
% * 2 and 3 extended: must not be followed by char of the start- end string
%   so **strong emphasis** is not highlit as *emphasis*
% * 6 OK
% * 7 only implemented for end-string (cf. 1, 4, and 5).
% 
% Multi-line inline-markup will not be highlighted!
% ::
  
private define inline_rule(pat)
{
   variable blank = " \t";
   variable del = blank; % also tried: = "$blank'\")\]}>\-/:\.,;!\\?"R$;
   % boundaries
   variable rechts = "$pat[^$blank$pat]"R$;
   variable links  = "[^$blank$pat]$pat"R$;
   % content
   % variable mitte  = "[^$pat]+($pat[^$del][^$pat]+)*"R$;
   variable mitte = "([^$pat]|($pat[^$del$pat]))+"R$;
   return "$rechts$mitte$links"R$;
}

private define setup_dfa_callback(mode)
{
   % dfa_enable_highlight_cache("rst.dfa", mode);
   $1 = mode; % used by dfa_rule()
   
   % Character Classes:
   variable blank = " \t";     % white space
   variable alpha = "a-zA-Z";     % alphabetic characters
   variable alnum = "a-zA-Z0-9";     % alphanumeric characters
   %  simple reference names (alphanumeric + internal [.-_])
   variable label = "[$alnum]+([\.\-_][$alnum]+)*"R$; 
   
   % Inline Markup
   dfa_rule(inline_rule("\*"R), "Qitalic");
   dfa_rule(inline_rule("\|"R), "Qrst_substitution");
   % dfa_rule(inline_rule(":", "rst_list_marker");
   dfa_rule(inline_rule("\*\*"R), "Qbold");
   dfa_rule(inline_rule("``"), "Qrst_literal");
   % interpreted text, maybe with a role
   variable role_re = ":$label:"$;
   dfa_rule(        inline_rule("`")+role_re, "Qrst_interpreted");
   dfa_rule(role_re+inline_rule("`"), 	      "Qrst_interpreted");
   % cannot be defined as "Q", as this prevents `link`_ highlight
   dfa_rule(        inline_rule("`"), 	      "rst_interpreted");
   
   % Literal Block marker
   dfa_rule("::[$blank]*$"$, "rst_literal");
   % Doctest Block marker
   dfa_rule("^[$blank]*>>>"$, "rst_literal");

   % Reference Marks
   %  URLs and Email
   dfa_rule("(https?|ftp|file)://[^ \t>]+", "url");
   dfa_rule("(mailto:)?$label@$label"$, "url");
   %  simple crossreferences
   dfa_rule("${label}__?"R$, "rst_reference");
   %   revert false positives
   dfa_rule("${label}_${label}"R$, "normal");
   %  reference with backticks
   dfa_rule("`(\\`|[^`])*`__?", "Qrst_reference");
   %  footnotes and citations
   dfa_rule("\[([#\*]|#?$label)\]_"R$, "rst_reference");

   % Reference Targets
   %  inline target
   dfa_rule("_`[^`]+`"R, "rst_target");
   dfa_rule("_${label}"R$, "rst_target");
   %  named crosslinks
   dfa_rule("^\.\.[$blank]+_[^:]+:[$blank]"R$, "rst_target");
   dfa_rule("^\.\.[$blank]+_[^:]+:$"R$, "rst_target");
   %  anonymous
   dfa_rule("^__[$blank]"$, "rst_target");
   %  footnotes and citations
   dfa_rule("^\.\.[$blank]+\[([#\*]|#?$label)\]"R$, "rst_target");
   % substitution definitions
   dfa_rule("^\.\.[$blank]+\|.*\|[$blank]+$label::"R$, "rst_directive");

   % Comments
   dfa_rule("^\.\.[$blank]"R$, "Pcomment");
   dfa_rule("^\.\.$"R, "comment");

   % Directives
   dfa_rule("^\.\.[$blank][^ ]+[$blank]?::"R$, "rst_directive");

   % Lists
   %  itemize
   dfa_rule("^[$blank]*[\-\*\+][$blank]+"R$, "Qrst_list_marker");
   %  enumerate: number, single letter, roman or #; formatting: #. #) (#)
   variable enumerator = "([0-9]+|[a-zA-Z]|[ivxlcdmIVXLCDM]+|#)";
   dfa_rule("^[$blank]*$enumerator[\)\.][$blank]+"R$, "rst_list_marker");
   dfa_rule("^[$blank]*\($enumerator\)[$blank]+"R$, "rst_list_marker");
   %  field list
   dfa_rule("^[$blank]*:[^ ].*[^ ]:[$blank]"R$, "Qrst_list_marker");
   dfa_rule("^[$blank]*:[^ ].*[^ ]:$$"R$, "Qrst_list_marker");
   %  option list
   variable option = "([\-/][a-zA-Z0-9]|--[a-zA-Z=]+)([\-= ][a-zA-Z0-9]+)*"R$;
   dfa_rule("^[$blank]*$option(, $option)*  "R$, "rst_list_marker");
   dfa_rule("^[$blank]*$option(, $option)* ?$$"R$, "rst_list_marker");
   % dfa_rule("^[$blank]*$option(, $option)*(  +|$$)"R$, "rst_list_marker");
   %  definition list
   % doesnot work as jed's DFA regexps span only one line
   
   % Line Block and Table VLines
   %  false positives (any `` | ``), as otherwise table vlines would not work
   dfa_rule("[$blank]\|[$blank]"R$, "rst_line");
   dfa_rule("^\|[$blank]"R$, "rst_line");
   dfa_rule("[$blank]\|$"R$, "rst_line");
   dfa_rule("^\|$"R$, "rst_line");

   % Tables
   %  simple tables
   dfa_rule("^[$blank]*=+( +=+)*[$blank]*$"$, "rst_line");
   dfa_rule("^[$blank]*-+( +-+)*[$blank]*$"$, "rst_line");
   %  grid tables
   dfa_rule("^[$blank]*\+-+\+"R$, "rst_line");
   dfa_rule("^[$blank]*\+-+\+(-+\+)*"R$, "rst_line");
   dfa_rule("^[$blank]*\+=+\+(=+\+)*"R$, "rst_line");

   % Hrules and Sections
   % dfa_rule(Underline_Regexp, "rst_transition");
   % doesnot work, as DFA regexps do not support "\( \) \1"-syntax.
   % So we have to resort to separate rules
   foreach $2 ("*=-~\"'`^:+#<>_") % Rst_Underline_Chars (verbatim, to enable cache generation)
       {
          $2 = str_quote_string(char($2), "^$[]*.+?", '\\');
          $2 = sprintf("^%s%s+[$blank]*$"$, $2, $2);
          dfa_rule($2, "rst_line");
       }

   % render non-ASCII chars as normal to fix a bug with high-bit chars in UTF-8
   dfa_define_highlight_rule("[^ -~]+", "normal", mode);
   
   dfa_build_highlight_table(mode);
}
dfa_set_init_callback(&setup_dfa_callback, "rst");
%%% DFA_CACHE_END %%%

enable_dfa_syntax_for_mode(mode);

#else
% define_syntax( '`', '"', mode);              % strings
define_syntax ("..", "", '%', mode);           % Comments
define_syntax ("[", "]", '(', mode);           % Delimiters
define_syntax ("0-9a-zA-Z", 'w', mode);        % Words
% define_syntax ("-+*=", '+', mode);           % Operators
% define_syntax ("-+0-9.", '0', mode);         % Numbers
% define_syntax (",", ',', mode);              % Delimiters
% define_syntax (";", ',', mode);              % Delimiters
#endif

% Keymap
% ======
% ::

!if (keymap_p(mode))
  make_keymap(mode);

% the backtick is is needed too often to be bound to quoted insert
definekey("self_insert_cmd", "`", mode);
% I recommend "°" but this might not be everyones favourite
% definekey("self_insert_cmd", "°", mode);
% Fallback: _Reserved_Key_Prefix+"`":
definekey_reserved("quoted_insert", "`", mode); %

% "&Layout");                                                  "l", mode);
definekey_reserved("rst->heading",                      "ls", mode); % "&Section"
definekey_reserved("rst->block_markup(\"preformatted\")",      "lp", mode); % "P&reformatted"
definekey_reserved("rst->markup(\"emphasis\")",                "le", mode); % "&Emphasis"
definekey_reserved("rst->markup(\"strong\")",                  "ls", mode); % "&Strong"
definekey_reserved("rst->markup(\"literal\")",                 "ll", mode); % "&Literal"
definekey_reserved("rst->markup(\"subscript\")",               "lb", mode); % "Su&bscript"
definekey_reserved("rst->markup(\"superscript\")",             "lp", mode); % "Su&bscript"
definekey_reserved("rst->markup(\"hrule\")",                   "lh", mode); % "&Hrule"
definekey_reserved("comment_region_or_line\")",                "lc", mode); % "&Comment"
% "&References\")",                        %                   "", mode);
definekey_reserved("rst->markup(\"hyperlink_ref\")",           "rh", mode); % "&Reference (link)"
definekey_reserved("rst->markup(\"anonymous_hyperlink_ref\")", "ra", mode); % "&Anonymous Reference"
definekey_reserved("rst->markup(\"numeric_footnote_ref\")",    "rf", mode); % "&Footnote"
definekey_reserved("rst->markup(\"symbolic_footnote_ref\")",   "rs", mode); % "&Symbolic Footnote"
definekey_reserved("rst->markup(\"citation_ref\")",            "rc", mode); % "&Citation"
definekey_reserved("rst->markup(\"substitution_ref\")",        "rs", mode); % "&Substitution"
% "Reference &Targets\")",                  %                  "", mode);
definekey_reserved("rst->markup(\"hyperlink\")",               "tr", mode); % "&Reference (link)"
definekey_reserved("rst->markup(\"anonymous_hyperlink\")",     "ta", mode); % "&Anonymous Reference"
definekey_reserved("rst->markup(\"numeric_footnote\")",        "tf", mode); % "&Footnote"
definekey_reserved("rst->markup(\"symbolic_footnote\")",       "ts", mode); % "&Symbolic Footnote"
definekey_reserved("rst->markup(\"citation\")",                "tc", mode); % "&Citation"
definekey_reserved("rst->markup(\"directive\")",               "td", mode); % "&Directive"
definekey_reserved("rst->markup(\"substitution\")",            "ts", mode); % "&Substitution"
% "&Export\")",                            %                   "", mode);
definekey_reserved("rst_to_html",                              "eh", mode); % "&Html"
definekey_reserved("rst_to_latex",                             "el", mode); % "&Latex"
definekey_reserved("rst_to_pdf",                               "ep", mode); % "&Latex"
definekey_reserved("rst->set_export_cmd(\"html\")",            "oh", mode); % "Set H&tml Export Options"
definekey_reserved("rst->set_export_cmd(\"tex\")",             "ol", mode); % "Set Late&x Export Options"
definekey_reserved("rst->set_export_cmd(\"pdf\")",             "op", mode); % "Set Late&x Export Options"
% "&View\")",                              %                   "", mode);
definekey_reserved("rst_view_html",                            "vh", mode); % "&Html"
definekey_reserved("rst_view_latex",                           "vl", mode); % "&Latex"
definekey_reserved("rst_view_pdf",                             "vp", mode); % "&Latex"
%                                                              "", mode);
#ifexists list_routines
definekey_reserved("list_routines",                            "n", mode); % &Navigator"
#endif

% Mode Menu
% =========
% ::

% append a new popup to menu and return the handle
static define new_popup(menu, popup)
{
   menu_append_popup(menu, popup);
   return strcat(menu, ".", popup);
}

static define rst_menu(menu)
{
   variable popup;
   popup = new_popup(menu, "Block &Markup");
   % ^CP...  Paragraph styles, etc. (<p>, <br>, <hr>, <address>, etc.)
   menu_append_item(popup, "&Section", "rst->heading");
   menu_append_item(popup, "P&reformatted", &block_markup, "preformatted");
   menu_append_item(popup, "&Hrule", &markup, "hrule");
   menu_append_item(popup, "&Directive", &markup, "directive");
   menu_append_item(popup, "&Comment", "comment_region_or_line");
   % ^CS...  Character styles (<em>, <strong>, <b>, <i>, etc.)
   popup = new_popup(menu, "&Inline Markup");
   menu_append_item(popup, "&Emphasis", &markup, "emphasis");
   menu_append_item(popup, "&Literal", &markup, "literal");
   menu_append_item(popup, "&Interpreted", &markup, "interpreted");
   menu_append_item(popup, "&Strong", &markup , "strong");
   menu_append_item(popup, "Su&bscript", &markup, "subscript");
   menu_append_item(popup, "Su&perscript", &markup, "superscript");
   % References (outgoing links)
   popup = new_popup(menu, "&References (outgoing links)");
   menu_append_item(popup, "&Hyperlink", &markup, "hyperlink_ref");
   menu_append_item(popup, "&Anonymous Hyperlink", &markup, "anonymous_hyperlink_ref");
   menu_append_item(popup, "&Embedded Hyperlink", &markup, "hyperlink_embedded");
   menu_append_item(popup, "&One-off Hyperlink", &markup, "anonymous_hyperlink_embedded");
   menu_append_item(popup, "Numeric &Footnote", &markup, "numeric_footnote_ref");
   menu_append_item(popup, "&Symbolic Footnote", &markup, "symbolic_footnote_ref");
   menu_append_item(popup, "&Citation", &markup, "citation_ref");
   menu_append_item(popup, "&Substitution", &markup, "substitution_ref");
   % Reference Targets
   popup = new_popup(menu, "&Targets");
   menu_append_item(popup, "&Hyperlink (URL)", &markup, "hyperlink");
   menu_append_item(popup, "&Anonymous Hyperlink", &markup, "anonymous_hyperlink");
   menu_append_item(popup, "Numeric &Footnote", &markup, "numeric_footnote");
   menu_append_item(popup, "&Symbolic Footnote", &markup, "symbolic_footnote");
   menu_append_item(popup, "&Citation", &markup, "citation");
   menu_append_item(popup, "&Substitution", &markup, "substitution");
   % Directives
   popup = new_popup(menu, "&Directives");
   menu_append_item(popup, "Table of &Contents", &insert_directive, "contents");
   menu_append_item(popup, "&Number Sections", &insert_directive, "sectnum");
   menu_append_item(popup, "Ima&ge",  &insert_directive, "image");
   menu_append_item(popup, "&Figure", &insert_directive, "figure");
   menu_append_item(popup, "T&able",  &insert_directive, "table");
   menu_append_item(popup, "&CSV Table",  &insert_directive, "csv-table");
   menu_append_item(popup, "&Title",  &insert_directive, "title");
   menu_append_item(popup, "&Include", &insert_directive, "include");
   menu_append_item(popup, "&Raw", &insert_directive, "raw");
   popup = new_popup(popup, "&Admonitions");
   menu_append_item(popup, "&Admonition",  &insert_directive, "admonition");
   menu_append_item(popup, "&attention",  &insert_directive, "attention");
   menu_append_item(popup, "&caution",  &insert_directive, "caution");
   menu_append_item(popup, "&danger",  &insert_directive, "danger");
   menu_append_item(popup, "&error",  &insert_directive, "error");
   menu_append_item(popup, "&hint",  &insert_directive, "hint");
   menu_append_item(popup, "&important",  &insert_directive, "important");
   menu_append_item(popup, "&note",  &insert_directive, "note");
   menu_append_item(popup, "&tip",  &insert_directive, "tip");
   menu_append_item(popup, "&warning",  &insert_directive, "warning");
   menu_append_separator(menu);
   % Navigation
#ifexists list_routines
   menu_append_item(menu, "&Navigator", "list_routines");
   menu_append_separator(menu);
#endif
   % Export to a target file
   popup = new_popup(menu, "&Export");
   menu_append_item(popup, "&Html", "rst_to_html");
   menu_append_item(popup, "&Latex", "rst_to_latex");
   menu_append_item(popup, "&Pdf", "rst_to_pdf");
   % View target file
   popup = new_popup(menu, "&View");
   menu_append_item(popup, "&Html", "rst_view_html");
   menu_append_item(popup, "&Latex", "rst_view_latex");
   menu_append_item(popup, "&Pdf", "rst_view_pdf");
   % Set export command
   popup = new_popup(menu, "Set Export &Cmd");
   menu_append_item(popup, "&Html", &set_export_cmd, "html");
   menu_append_item(popup, "&Latex", &set_export_cmd, "tex");
   menu_append_item(popup, "&Pdf", &set_export_cmd, "pdf");
   % Help commands
   menu_append_separator(menu);
   popup = new_popup(menu, "&Help");
#ifexists browse_url
   menu_append_item(popup, "Doc &Index", "browse_url",
      path_concat(Rst_Documentation_Path, "index.html"));
   menu_append_item(popup, "&Quick Reference", "browse_url",
      path_concat(Rst_Documentation_Path, "user/rst/quickref.html"));
   menu_append_item(popup, "&Directives", "browse_url",
      path_concat(Rst_Documentation_Path, "ref/rst/directives.html"));
   menu_append_separator(popup);
#endif
   menu_append_item(popup, "Rst2&Html Help", &command_help, Rst2Html_Cmd);
   menu_append_item(popup, "Rst2&Latex Help", &command_help, Rst2Latex_Cmd);
   % Default conversion and browse
   menu_append_item(menu, "&Run Buffer", "run_buffer");
}

% Rst Mode
% ========
% 
% ::

% set the comment string
set_comment_info(mode, ".. ", "", 0);

% Modify line_is_blank() from structured_text.sl
% let section heading underlines separate paragraphs 
% (rst does not require a blank line after a section title)
define line_is_blank()
{
   bol_skip_white();
   if (eolp())
      return 1;
   return is_heading_underline();
}
   

public define rst_mode()
{
   set_mode(mode, 1);
   % indent|format with structured_text_hook from structured_text.sl
   structured_text_hook();
   use_syntax_table(mode);
   % use_keymap (mode);
   mode_set_mode_info(mode, "fold_info", ".. {{{\r.. }}}\r\r");
   mode_set_mode_info(mode, "init_mode_menu", &rst_menu);
   mode_set_mode_info("run_buffer_hook", &rst_to_html);
   mode_set_mode_info("dabbrev_word_chars", get_word_chars());

   % define_blocal_var("help_for_word_hook", &rst_help);
   run_mode_hooks(mode + "_mode_hook");
}

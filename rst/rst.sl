% rst.sl: Mode for reStructured Text
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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
% 		     replacement (Attention! can lead to segfaults with older,
% 		     buggy S-Lang versions: update S-Lang or downgrade rst.sl)
% 		   * more work on "rst-fold"
% 2.2   2007-11-15 * custom colors		   
% ===== ========== ============================================================
%
% TODO
% ====
%
% * jump from reference to target and back again
% * "link creation wizard"
% * Function to "normalise" section adornment chars to given order
% * line-block: if no visible region, mark paragraph, prefix all lines with "| "
%               (with prefix argument: remove the "| ")
% * Look at demo.txt and refine the syntax highlight
% * Customisable syntax colours a-la diffmode.sl
%
%
% Requirements
% ============
%
% standard modes::

require("comments");

% extra modes (from http://jedmodes.sf.net/mode/)::

autoload("structured_text_hook", "structured_text");  % >= 0.5

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
autoload("string_repeat", "strutils");

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

% Navigation buffer (navigable table of contents) with
% http://jedmodes.sf.net/mode/tokenlist
% ::

#if (expand_jedlib_file("tokenlist.sl") != "")
autoload("list_routines", "tokenlist"); % >= 2006-12-19
#endif

% name it
% =======
% ::

provide("rst");
implements("rst");
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

%!%+
%\variable{Rst_Underline_Chars}
%\synopsis{Characters used for underlinign of section titles}
%\usage{variable Rst_Underline_Chars = "*=-~\"'`^:+#<>_"}
%\description
%  String of non-alphanumeric characters that serve as underlining chars
%  (adornments) for section titles.
%  Order is important - as default oder for the section level (overwritten
%  by existing use of adornment chars in the current buffer).
%\seealso{rst->heading}
%!%-
custom_variable("Rst_Underline_Chars", "*=-~\"'`^:+#<>_");

% Color Definitions
% -----------------

% new since Jed 0-99.18
custom_color("bold",             get_color("error"));     
custom_color("italic",           get_color("operator"));    
custom_color("url",              get_color("keyword"));
custom_color("underline",	 get_color("delimiter"));
% local extensions
custom_color("rst_literal",      get_color("preprocess"));
custom_color("rst_interpreted",  get_color("string"));    
custom_color("rst_substitution", get_color("operator"));  
custom_color("rst_list_marker",  get_color("number")); 
custom_color("rst_line",         get_color("underline"));   
custom_color("rst_reference",    get_color("keyword"));   
custom_color("rst_target",       get_color("keyword1"));   
custom_color("rst_directive",    get_color("keyword2"));  

% Internal Variables
% ------------------
% ::

private variable Last_Underline_Char = "=";
private variable ws = "[ \t]"; % white space
static variable Underline_Regexp = sprintf("^\([%s]\)\1+$ws*$"R$,
   str_replace_all(Rst_Underline_Chars, "-", "\\-"));
% static variable Underline_PcRegexp = sprintf("^([%s])\1+$ws*$"R$,
%    str_replace_all(Rst_Underline_Chars, "-", "\\-"));

private variable helpbuffer = "*rst export help*";

% Pointer to the export command string for a given file extension
private variable export_cmds = Assoc_Type[Ref_Type];
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
Markup_Tags["hyperlink_ref"]           = ["`", "`_"];   % hyperlink, anchor
Markup_Tags["anonymous_hyperlink_ref"] = ["`", "`__"];
Markup_Tags["numeric_footnote_ref"]   = ["",  " [#]_"]; % automatic  numbering
Markup_Tags["symbolic_footnote_ref"]  = ["",  " [*]_"]; % automatic  numbering
Markup_Tags["citation_ref"]           = ["[", "]_"];    % also for footnotes
Markup_Tags["substitution_ref"]       = ["|", "|"];

% Reference Targets
Markup_Tags["hyperlink"]           = [".. _", ":"];   % URL, crossreference
Markup_Tags["anonymous_hyperlink"] = ["__ ", ""];
Markup_Tags["numeric_footnote"]   = [".. [#]", ""];   % automatic  numbering
Markup_Tags["symbolic_footnote"]  = [".. [*]", ""];   % automatic  numbering
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
   % return show(cmd);

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
   variable cmd = @cmd_var;
   @cmd_var = read_mini("export cmd and options:", "", cmd);
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

% Navigation, handling of sections titles
% ----------------------------------------
% ::

% string of sorted adornment (underline) characters.
% used and amended with get_rst_level()
% (re)set from existing section titles with update_adornments()
private variable adornments = "";

% auxiliary fun for is_heading_underline:
% get the column number of the last non-white char
private define get_line_len()
{
   eol();
   bskip_white();
   what_column(); % push return value on stack
   bol();
}

% Check whether the point is in a line underlining a section title.
% (underline is equal or longer than previous line and previous line is
% non-blank).
% Leave point at bol of underline.
define is_heading_underline()
{
   % Get length of heading
   !if (up(1)) % already on first line
     return 0;
   variable title_len = get_line_len();
   go_down_1();
   if (title_len == 1) % no heading
     return 0;
   % Compare to length of underline adornment
   return get_line_len() >= title_len;
}

% Return level of section title underlined with `ch'
% (starting with level 1 == H1)
% Return 0 (if ch == 0)
% Add ch to list of adornments if not found there.
static define get_section_level(ch)
{
   ch = char(ch);
   variable i = is_substr(adornments, ch);
   if (i)
     return i;
   adornments += ch;
   return strlen(adornments);
}

% search next section title, return section level or 0
% skip sections titles with a level higher than max_level
% TODO: Skip hidden headings?
static define fsearch_heading() % (max_level=10)
{
   variable level, max_level = push_defaults(10, _NARGS);
   while (eol(), re_fsearch(Underline_Regexp))
     {
        !if (is_heading_underline)
          continue;
        level = get_section_level(what_char());
        if (level <= max_level)
          return level;
     }
   return 0;
}

% search previous section title, return adornment char or 0
static define bsearch_heading()
{
   variable level, max_level = push_defaults(10, _NARGS);
   while (re_bsearch(Underline_Regexp))
     {
        !if (is_heading_underline)
          continue;
        level = get_section_level(what_char());
        if (level <= max_level)
          return level;
     }
   return 0;
}

% update the sorted listing of section title adornments,
% return number of existing section title levels
define update_adornments()
{
   variable l_max, ch;
   adornments = "";      % reset private var
   % List underline characters used for sections in the document
   push_spot_bob();
   while (fsearch_heading())
     !if (down_1())
       break;
   pop_spot();
   l_max = strlen(adornments);
   % Append the Rst_Underline_Chars not used in the document to the adornments string
   foreach ch (Rst_Underline_Chars)
     () = get_section_level(ch);
   return l_max;
}

%!%+
%\function{rst->heading}
%\synopsis{Mark up current line as section title}
%\usage{heading([adornment])}
%\description
% Mark up current line as section title by underlining it.
% Replace eventually existing underline.
%
% If \var{adornment} is an integer (or a string convertible to an
% integer),  use the adornment for this section level.
%
% Read argument if not given
%   * "canonical" adornments are listed starting with already used ones
%      sorted by level
%   * integer argument level can range from 1 to `no of already defined levels`
%\notes
%\seealso{rst_mode, Rst_Underline_Chars}
%!%-
static define heading() % ([adornment_char])
{
   % Get optional argument
   variable ch = push_defaults( , _NARGS);
   % update the listing of adornment characters used in the document
   if (typeof(ch) == Integer_Type or ch == NULL)
     variable max_level = update_adornments();
   % read from minibuffer
   if (ch == NULL)
     {
        flush(sprintf("Underline char [%s] or level [1-%d] (default: %s):",
           adornments, max_level+1, Last_Underline_Char));
        ch = getkey();
        switch (ch)
          { case 13: ch = Last_Underline_Char; } % Key_Return
          { ch = char(ch); }
        flush("");
     }
   % Convert numeral to Integer
   if (andelse{typeof(ch) == String_Type}
        {string_match(ch,"^[0-9]+$" , 1)})
     ch = integer(ch);
   % Convert Integer (level) to character:
   if (typeof(ch) == Integer_Type)
     ch = char(adornments[ch-1]);
   % Store as default
   Last_Underline_Char = ch;

   % Go up to the title line, if at the underline
   bol();
   if (re_looking_at(Underline_Regexp))
        go_up_1();
   % Get the title length (trim by the way)
   eol_trim();
   variable len = what_column();
   if (len == 1) % transition
     len = WRAP;

   % Underline the heading (replacing an existing underline)
   !if (right(1))
     newline();
   if (re_looking_at(Underline_Regexp))
     delete_line();
   insert(string_repeat(ch, len-1) + "\n");
}

% Go to the next section title.
% Skip (sub)sections with level above max_level
static define next_heading()  % (max_level=100)
{
   variable max_level = push_defaults(100, _NARGS);
   go_down_1();
   if (fsearch_heading(max_level))
     {
        go_up_1();
        bol();
     }
   else
     eob;
}

static define next_visible_heading()
{
   do
     next_heading();
   while (is_line_hidden() and not(eobp));
}

%!%+
%\function{rst->skip_section}
%\synopsis{Go to the next heading of same level or above}
%\usage{skip_section()}
%\description
% Skip content and sub-sections.
%\notes
% Point is placed at bol of next heading or eob
%\seealso{rst_mode; rst->heading}
%!%-
static define skip_section()
{
   () = update_adornments();
   go_down(2);
   next_heading(bsearch_heading());
}

% Go to the previous section title (with level below or equal to max_level)
static define previous_heading() % (max_level=100)
{
   variable max_level = push_defaults(100, _NARGS);
   if (bsearch_heading(max_level))
     {
        go_up_1();
        bol();
     }
   else
     bob;
}

static define previous_visible_heading()
{
   do
     previous_heading();
   while (is_line_hidden() and not(bobp));
}

% Go to the previous section title of same level or above,
% skip content and sub-sections.
static define bskip_section()
{
   () = update_adornments();
   go_down(2);
   previous_heading(bsearch_heading());
}

% Go to section title of containing section (one level up)
static define up_section()
{
   () = update_adornments();
   go_down(2);
   previous_heading(bsearch_heading()-1);
}

% Use Marko Mahnics tokenlist to create a navigation buffer with all section
% titles. ::

#ifexists list_routines

%% message("tokenlist present");

% rst mode's hook for tkl_list_tokens():
%
% tkl_list_tokens searches for a set of regular expressions defined
% by an array of strings arr_regexp. For every match tkl_list_tokens
% calls the function defined in the string fn_extract with an integer
% parameter that is the index of the matched regexp. At the time of the
% call, the point is at the beginning of the match.
%
% The called function should return a string that it extracts from
% the current line.
%
% ::

% extract section title and format for tokenlist
static define extract_heading(regexp_index)
{
   variable ch, title;
   % point is, where fsearch_heading leaves it
   % (at first matching adornment character)
   % Get adornment char
   ch = what_char();
   % Get section title
   go_up_1();
   push_mark(); bol();
   title =  bufsubstr();
   go_down_1();
   % show(what_line, char(ch), title);
   % Format
   % do not indent at all (simple, missing information)
   % return(sprintf("%c %s", ch, title));
   variable level = get_section_level(ch);
   variable indent = string_repeat(" ", (level-1)*2);
   % indent by 2 spaces/level, underline char as marker (best)
   return sprintf("%s%c %s", indent, ch, title);
}

% Set up list_routines for rst mode
public  define rst_list_routines_setup(opt)
{
   adornments = "";    % reset
   opt.list_regexp = &fsearch_heading;
   opt.fn_extract = &extract_heading;
}

#endif

% Folding
% -------
% ::

% hide section content and section titles above max_level
%
% * use with narrow() to fold a sub-tree
% * use with max_level=0 to unfold (show all lines)
%
static define fold_buffer(max_level)
{
   push_spot();
   % Undo previous hiding
   mark_buffer();
   set_region_hidden(0);
   bob();
   update_adornments();
   % Start below first heading
   if (fsearch_heading(max_level))
     go_down_1();
   else
     eob;
   % alternative next_heading(max_level); skips heading in line 1 :-(

   % Set section content hidden but skip headings and underlines
   while (not(eobp()))
     {
        push_mark();
        next_heading(max_level);
        !if (eobp())
          go_up_1();                % leave the next heading line visible
        set_region_hidden(1);
        go_down(3);                 % skip heading line and underline
     }
   pop_spot();
}

% Fold current section
% (Un)Hide section content. Toggle, if \var{max_level} is negative.
% Point must be in section heading or underline.
% (Un)hide also sub-headings below max_level.
% max_level is relative to section level:
%    0: unfold (show content)
%    1: hide all sub-headings
%    n: show n-1 levels of sub-headings
static define fold_section(max_level)
{
   push_spot();
   % goto top of section
   go_down(2);
   previous_heading();
   if (max_level < 0)
     {
        $1 = down(2);
        max_level *= -not(is_line_hidden());
        go_up($1);
     }
   % Narrow to section and fold
   push_mark();
   skip_section();
   go_up_1();
   narrow();
   fold_buffer(max_level);
   widen();
   pop_spot();
}

% Emacs outline mode bindings
% ---------------------------
% ::

% emulate emacs outline bindings
static define emacs_outline_bindings() % (pre = _Reserved_Key_Prefix)
{
   variable pre = push_defaults(_Reserved_Key_Prefix, _NARGS);
   local_unsetkey(pre);

   % Outline Motion Commands
   % """""""""""""""""""""""
   % :^C^n: (outline-next-visible-heading) moves down to the next heading line.
   % :^C^p: (outline-previous-visible-heading) moves similarly backward.
   % TODO
   % :^C^u: (outline-up-heading) Move point up to a lower-level (more
   %        inclusive) visible heading line.
   local_setkey("rst->up_section", pre+"^U");
   % :^C^f: (outline-forward-same-level) and
   % :^C^b: (outline-backward-same-level) move from one heading line to another
   %        visible heading at the same depth in the outline.
   local_setkey("rst->skip_section", pre+"^F");
   local_setkey("rst->bskip_section", pre+"^B");

   % Outline Visibility Commands
   % """""""""""""""""""""""""""
   % Global commands working on the whole buffer.
   %
   % :^C^t: (hide-body) you see just the outline.
   local_setkey("rst->fold_buffer(100)", pre+"^T");
   % :^C^a: (show-all) makes all lines visible.
   local_setkey("rst->fold_buffer(0)", pre+"^A");
   % :^C^q: (hide-sublevels) hides all but the top level headings.
   local_setkey("rst->fold_buffer(1)", pre+"^Q");
   %        TODO: With a numeric argument n, it hides everything except the
   %        top n levels of heading lines.
   % :^C^o: (hide-other) hides everything except the heading or body text that
   %        point is in, plus its parents (the headers leading up from there to top
   %        level in the outline).
   % TODO

   % Subtree commands that apply to all the lines of that heading's subtree:
   % its body, all its subheadings, both direct and indirect, and all of their
   % bodies. In other words, the subtree contains everything following this
   % heading line, up to and not including the next heading of the same or
   % higher rank.
   %
   % :^C^d: (hide-subtree) Make everything under this heading invisible.
   local_setkey("rst->fold_section(1)", pre+"^D");
   % :^C^s: (show-subtree). Make everything under this heading visible.
   local_setkey("rst->fold_section(0)", pre+"^C");

   % Intermediate between a visible subtree and an invisible one is having all
   % the subheadings visible but none of the body.
   % :^C^l: (hide-leaves) Hide the body of this section, including subheadings.
   local_setkey("rst->fold_section(1)", pre+"^L");
   % TODO: what is the difference to (hide-subtree)?
   % :^C^k: (show-branches) Make all subheadings of this heading line visible.
   local_setkey("rst->fold_section(100)", pre+"^K");
   % :^C^i: (show-children) Show immediate subheadings of this heading.
   local_setkey("rst->fold_section(2)", pre+"^I");
   %
   % Local commands: They are used with point on a heading line, and apply only
   % to the body lines of that heading. Subheadings and their bodies are not
   % affected.
   % :^C^c: (hide-entry) and
   % :^C^e: (show-entry).
   % :^C^q: Hide everything except the top n levels of heading lines (hide-sublevels).
   % :^C^o: Hide everything except for the heading or body that point is in, plus the headings leading up from there to the top level of the outline (hide-other).
   %
   % When incremental search finds text that is hidden by Outline mode, it makes
   % that part of the buffer visible. If you exit the search at that position,
   % the text remains visible.
   %
   % Structure editing.
   % """"""""""""""""""
   %
   % Using M-up, M-down, M-left, and M-right, you can easily move entries
   % around:
   %
   % |                            move up
   % |                               ^
   % |      (level up)   promote  <- + ->  demote (level down)
   % |                               v
   % |                           move down
   %
}

% bindings from outline.sl
% """"""""""""""""""""""""
%
% :^C^d: hide subtree
% :^C^s: show subtree
% :^C^c: hide body under this heading
% :^C^e: show body of this heading
% :^C^k: show all headings under this heading
% :^C^t: hide everything in buffer except headings
%           With prefix, hide headings with level > arg
% :^C^l: hide everything under this heading except headings
% :^C^o: hide other stuff except toplevel headings
% :^C^a: show everything in this buffer
%
% and from fold.txt (consistent with the Emacs bindings) ::

% :^C^W: fold_whole_buffer
% :^C^O: fold_open_buffer            % unfold-buffer
% :^C>:  fold_enter_fold
% :^C<:  fold_exit_fold
% :^C^F: fold_fold_region            % add fold marks and narrow
% :^C^S: fold_open_fold
% :^C^X: fold_close_fold
% :^Cf:  fold_search_forward
% :^Cb:  fold_search_backward
%
% Numerical Keypad bindings
% -------------------------
% ::

static define rst_fold_bindings()
{
   local_setkey("rst->bskip_section",    Key_KP_9);   % Bild ^
   local_setkey("rst->previous_heading", Key_KP_8);   % ^
   local_setkey("rst->next_heading",     Key_KP_2);   % v
   local_setkey("rst->skip_section",     Key_KP_3);   % Bild v
   % local_setkey("newline_or_unfold",     Key_Return);
   local_setkey("rst->fold_section(-1)", Key_KP_5);   % ·     no subheadings
   % local_setkey("rst->fold_section(-2)", Key_KP_5);   % ·   prime subheadings
   % local_setkey("rst->fold_section(-10)", Key_KP_5);   % ·  all subheadings
}

% Syntax Highlight
% ================
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
% Return a regexp pattern for inline markup with string `s'.
% Due to limitations in Jed's DFA syntax, only a part of the algorithm can
% be reproduced:
%    
% * 1 and 5 not implemented: 
%    
%   * matching char would be high-lit
%   * start|end of line or white (^|[ \t]) and ($|[ \t]) seems not to work
%    
% * 2 and 3 extended: must not be followed by char of the start- end string
%   so **strong emphasis** is not highlit as *emphasis*
% * 6 OK
% * 7 only implemented for end-string (cf. 1, 4, and 5).
% 
% Multi-line inline-markup will not be high-lit!
private define inline_rule(pat)
{
   variable ws = " \t";
   variable del = "$ws"$; % "$ws'\")\]}>\-/:\.,;!\\?"R$;
   return "$pat[^$ws$pat][^$pat]+($pat[^$del][^$pat]+)*[^$ws$pat]$pat"R$;
}

private define setup_dfa_callback(mode)
{
   dfa_enable_highlight_cache("rst.dfa", mode);
   $1 = mode; % used by dfa_rule()
   
   % Repeatedly used patterns:
   variable ws = "[ \t]";      % white space
   variable a  = "a-zA-Z";     % alphabetic characters
   variable an = "a-zA-Z0-9"$;     % alphanumeric characters
   %  simple reference names (alphanumeric + internal [.-_])
   variable label = "[$an]+([\.\-_][$an]+)*"R$; 
   
   % Inline Markup
   dfa_rule(inline_rule("\*"R), "italic");
   dfa_rule(inline_rule("\|"R), "rst_substitution");
   % dfa_rule(inline_rule(":", "rst_list_marker");
   dfa_rule(inline_rule("\*\*"R), "bold");
   dfa_rule(inline_rule("``"), "rst_literal");
   % interpreted text, maybe with a role
   variable role_re = ":$label:"$;
   dfa_rule(inline_rule("`")+role_re, "Qrst_interpreted");
   dfa_rule(role_re+inline_rule("`"), "Qrst_interpreted");
   dfa_rule(        inline_rule("`"),     "rst_interpreted");
   
   % Literal Block marker
   dfa_rule("::$ws*$"$, "rst_literal");
   % Doctest Block marker
   dfa_rule("^$ws*>>>"$, "rst_literal");

   % Reference Marks
   %  URLs and Email
   dfa_rule("(https?|ftp|file)://[^ \t>]+", "url");
   dfa_rule("(mailto:)?$label@$label"$, "url");
   %  simple crossreferences
   dfa_rule("${label}__?"R$, "rst_reference");
   %   revert false positives
   dfa_rule("${label}_${label}"R$, "normal");
   %  reference with backticks
   dfa_rule("`(\\`|[^`])*`__?", "rst_reference");
   %  footnotes and citations
   dfa_rule("\[([#\*]|#?$label)\]_"R$, "rst_reference");

   % Reference Targets
   %  inline target
   dfa_rule("_`[^`]+`"R, "rst_target");
   dfa_rule("_${label}"R$, "rst_target");
   %  named crosslinks
   dfa_rule("^\.\.$ws+_[^:]+:$ws"R$, "rst_target");
   dfa_rule("^\.\.$ws+_[^:]+:$"R$, "rst_target");
   %  anonymous
   dfa_rule("^__$ws"$, "rst_target");
   %  footnotes and citations
   dfa_rule("^\.\.$ws+\[([#\*]|#?$label)\]"R$, "rst_target");
   % substitution definitions
   dfa_rule("^\.\.$ws+\|.*\|$ws+$label::"R$, "rst_directive");

   % Comments
   dfa_rule("^\.\.$ws"R$, "Pcomment");
   dfa_rule("^\.\.$"R, "comment");

   % Directives
   dfa_rule("^\.\.$ws[^ ]+$ws?::"R$, "rst_directive");

   % Lists
   %  itemize
   dfa_rule("^$ws*[\-\*\+]$ws+"R$, "Qrst_list_marker");
   %  enumerate: number, single letter, roman or #; formatting: #. #) (#)
   variable enumerator = "([0-9]+|[a-zA-Z]|[ivxlcdmIVXLCDM]+|#)";
   dfa_rule("^$ws*$enumerator[\)\.]$ws+"R$, "rst_list_marker");
   dfa_rule("^$ws*\($enumerator\)$ws+"R$, "rst_list_marker");
   %  field list
   dfa_rule("^$ws*:[^ ].*[^ ]:$ws"R$, "Qrst_list_marker");
   dfa_rule("^$ws*:[^ ].*[^ ]:$$"R$, "Qrst_list_marker");
   %  option list
   variable option = "([\-/][a-zA-Z0-9]|--[a-zA-Z=]+)([\-= ][a-zA-Z0-9]+)*"R$;
   dfa_rule("^$ws*$option(, $option)*  "R$, "rst_list_marker");
   dfa_rule("^$ws*$option(, $option)* ?$$"R$, "rst_list_marker");
   % dfa_rule("^$ws*$option(, $option)*(  +|$$)"R$, "rst_list_marker");
   %  definition list
   % doesnot work as jed's DFA regexps span only one line
   
   % Line Block and Table VLines
   %  false positives (any `` | ``), as otherwise table vlines would not work
   dfa_rule("$ws\|$ws"R$, "rst_line");
   dfa_rule("^\|$ws"R$, "rst_line");
   dfa_rule("$ws\|$"R$, "rst_line");
   dfa_rule("^\|$"R$, "rst_line");

   % Tables
   %  simple tables
   dfa_rule("^$ws*=+( +=+)*$ws*$"$, "rst_line");
   dfa_rule("^$ws*-+( +-+)*$ws*$"$, "rst_line");
   %  grid tables
   dfa_rule("^$ws*\+-+\+"R$, "rst_line");
   dfa_rule("^$ws*\+-+\+(-+\+)*"R$, "rst_line");
   dfa_rule("^$ws*\+=+\+(=+\+)*"R$, "rst_line");

   % Hrules and Sections
   % dfa_rule(Underline_Regexp, "rst_transition");
   % doesnot work, as DFA regexps do not support "\( \) \1"-syntax.
   % So we have to resort to separate rules
   foreach $2 ("*=-~\"'`^:+#<>_") % Rst_Underline_Chars (verbatim, to enable cache generation)
       {
          $2 = str_quote_string(char($2), "^$[]*.+?", '\\');
          $2 = sprintf("^%s%s+$ws*$"$, $2, $2);
          dfa_rule($2, "rst_line");
       }

   dfa_build_highlight_table(mode);
}
dfa_set_init_callback(&setup_dfa_callback, "rst");
%%% DFA_CACHE_END %%%

!if (_slang_utf8_ok)  % DFA is broken in UTF-8 mode
  enable_dfa_syntax_for_mode(mode);

#else
% define_syntax( '`', '"', mode);              % strings
define_syntax ("..", "", '%', mode);         % Comments
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

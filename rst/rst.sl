% rst.sl
% ======
% 
% Mode for reStructured Text (from Python docutils__)
% 
% Copyright (c) 2004, 2006 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
% 
% `ReStructured Text`__ is a revision of Structured Text, a simple markup
% language that can be translated to Html and LaTeX (and more, if someone
% writes a converter)
% 
% __ http://docutils.sourceforge.net/
% __ http://docutils.sourceforge.net/docs/rst/quickref.html
% 
% Versions
% ========
% 
% ===== ========== ==============================================================
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
% ===== ========== ==============================================================
% 
% 
% TODO: directives functions (see /docutils/docs/ref/rst/directives.html)
% 
% 
% Requirements
% ============
% 
% standard modes::
% 
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

% jump to the error locations from output buffer::

#if (expand_jedlib_file("filelist.sl") != "")
autoload("filelist_mode", "filelist");
#endif

% browse the html rendering in a separate browser, browse documentation::

#if (expand_jedlib_file("browse_url.sl") != "")
autoload("browse_url", "browse_url");
#endif

% navigation buffer (navigable table of contents)::

#if (expand_jedlib_file("tokenlist.sl") != "")
autoload("list_routines", "tokenlist");
#endif
             
% Variables
% =========
% 
% ::

% --- name it
provide("rst");
implements("rst");
private variable mode = "rst";

% Custom Variables
% ----------------
% 
% ::

%!%+
%\variable{Rst2Html_Cmd}
%\synopsis{ReStructured Text to Html converter}
%\usage{String_Type Rst2Html_Cmd = "rst2html"}
%\description
% Shell command and options for the ReStructured Text to Html converter
% 
% The options can be changed from the Mode>Export>... menu popup. However,
% these changes are only valid for the current jed session. Permanent changes
% should be done by defining the variable in the jed.rc file.
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
% The options can be changed from the Mode>Export>... menu popup. However,
% these changes are only valid for the current jed session. Permanent changes
% should be done by defining the variable in the jed.rc file.
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
% The options can be changed from the Mode>Export>... menu popup. However,
% these changes are only valid for the current jed session. Permanent changes
% should be done by defining the variable in the jed.rc file.
%\notes
% The default works if the executable `rst2pdf.py` is installed in the
% PATH (e.g. with the Debian package python-docutils.deb).
%\seealso{rst_mode, Rst2Pdf_Cmd, Rst2Html_Cmd}
%!%-
custom_variable("Rst2Pdf_Cmd", "rst2pdf.py");

%!%+
%\variable{Rst_Documentation_Path}
%\synopsis{URL of the Docutils Project Documentation base directory}
%\usage{variable Rst_Documentation_Path = "/usr/share/doc/python-docutils/docs"}
%\description
%  Pointer to the Docutils Project Documentation 
%  which will be opened by the Mode>Help>Doc Overview menu entry.
%  
%  The default works with the Debian "python-docutils" package.
%  Set to your local documentation mirror or "http://docutils.sf.net/docs/"
%\seealso{rst_mode}
%!%-
custom_variable("Rst_Documentation_Path", 
   "/usr/share/doc/python-docutils/docs");

% Static Variables
% ----------------
% 
% ::

static variable Last_Underline_Char = "-";
static variable Underline_Chars = "*=-~\"'`^:+#<>_";
static variable Underline_Regexp = sprintf("^\\([%s]\\)\\1+[ \t]*$",
   str_quote_string(Underline_Chars, "\\^$[]*.+?", '\\')); 

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
Markup_Tags["hrule"]         = ["\n-------------\n", ""];  % alias transition
Markup_Tags["preformatted"] = ["::\n    ", "\n"];

% References (outgoing links, occure in the text)
Markup_Tags["hyperlink_ref"]           = ["`", "`_"];   % hyperlink, anchor
Markup_Tags["anonymous_hyperlink_ref"] = ["`", "`__"];
Markup_Tags["numeric_footnote_ref"]   = ["",  " [#]_"]; % automatic  numbering
Markup_Tags["symbolic_footnote_ref"]  = ["",  " [*]_"]; % automatic  numbering
Markup_Tags["citation_ref"]           = ["[", "]_"];    % also for footnotes
Markup_Tags["substitution_ref"]       = ["|", "|"];

% Reference Targets
Markup_Tags["hyperlink"]           = ["\n.. _", ":"];   % URL, crossreference
Markup_Tags["anonymous_hyperlink"] = ["__ ", ""];
Markup_Tags["numeric_footnote"]   = ["\n.. [#]", ""];   % automatic  numbering
Markup_Tags["symbolic_footnote"]  = ["\n.. [*]", ""];   % automatic  numbering
Markup_Tags["citation"]           = ["\n.. [", "]"];
Markup_Tags["directive"]          = ["\n.. ", "::"];   %
Markup_Tags["substitution"]       = ["\n.. |", "|"];


% Functions
% =========
% 
% Export
% ------
% 
% ::

% export the buffer/region to outfile using export_cmds[]
static define rst_export() % (to, outfile=path_sans_extname(whatbuf())+".html")
{
   variable to, outfile;
   (to, outfile) = 
     push_defaults( , path_sans_extname(whatbuf())+".html", _NARGS);
   
   if (to == NULL)
     to = read_with_completion(strjoin(assoc_get_keys(export_cmds), ","),
      "Export buffer to ", "html", "", 's'); 
   outfile = path_concat(buffer_dirname(), outfile);

   variable cmd = strjoin([@export_cmds[to], buffer_filename(), outfile], " ");
   % return show(cmd);
   save_buffer();
   flush("exporting to " + to); 
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
public  define rst_to_latex() % (outfile=path_sans_extname(whatbuf())+".tex") 
{
   rst_export("tex");
}

% export to PDF
public  define rst_to_pdf() % (outfile=path_sans_extname(whatbuf())+".pdf")
{
   rst_export("pdf");
}

% open popup-buffer with help for cmd 
static define command_help(cmd)
{
   popup_buffer(helpbuffer, 1.0);
   set_prefix_argument(1);
   do_shell_cmd(extract_element(cmd, 0, ' ') + " --help");
   fit_window(get_blocal("is_popup", 0));
   set_buffer_modified_flag(0);
   bob();
}

% set Rst2* (export command) options for export_type
static define set_export_options(export_type)
{
   variable cmd_var = export_cmds[export_type]; % variable reference
   variable options, cmd = strtok(@cmd_var);
   try
     {
      options = strjoin(cmd[[1:]], " ");
      cmd = cmd[0];
     }
   catch IndexError:
     throw RunTimeError, "empty command string: set the command first";
   % show(cmd, options);
   command_help(cmd);
   options = read_mini("export options:", "", options);
   @cmd_var = strcat(cmd, " ", options);
   close_buffer(helpbuffer);
}

#ifexists browse_url
% Browse the html conversion of the current buffer in an external browser
public  define rst_browse() % (browser=Browse_Url_Browser))
{
   variable browser = push_defaults(, _NARGS);
   variable outfile = path_sans_extname(whatbuf())+".html";
   outfile = path_concat(buffer_dirname(), outfile);
   % recreate the html file, if the buffer is newer
   save_buffer();
   if (file_time_compare(buffer_filename(), outfile) > 0)
     rst_to_html();
   % browse, pass optional browser argument
   variable url = "file:" + outfile;
   if (browser != NULL)
     browse_url(url, browser);
   else
     browse_url(url);
}
#endif

% Markup
% ------
% 
% ::

% insert a markup
static define markup(type)
{ 
   insert_markup(push_array(Markup_Tags[type])); 
}

static define block_markup(type)
{ 
   insert_block_markup(push_array(Markup_Tags[type])); 
}

% underline the current line
% if there is already underlining, adapt it to the lenght of the line
static define section_markup() % ([ch])
{
   variable len, old_char;
   
   Last_Underline_Char = 
     prompt_for_argument(&read_mini, sprintf("Underline char [%s]:", 
        Underline_Chars), Last_Underline_Char, "", _NARGS);
   
   % go up to the title line, if at the underline
   bol();
   if (re_looking_at(Underline_Regexp))
     go_up_1();
   
   % get the title length (trim by the way)
   eol_trim();
   len = what_column();
   if (len == 0) % transition
     len = WRAP;

   !if (right(1))
     newline();
   if (re_looking_at(Underline_Regexp))
       delete_line();
      
   insert(string_repeat(Last_Underline_Char, len-1) + "\n");
}

% Navigation
% ----------
% 
% Use Marko Mahnics tokenlist to create a navigation buffer with all section
% headings.
% 
% ::

#ifexists list_routines

% message("tokenlist present");
% 
% ::

% array of regular expressions matching routines
public  variable rst_list_routines_regexp = [Underline_Regexp];

private variable rst_levels = {}; % List_Type (requires SLang 2)
private define get_rst_level(ch)
{
   variable i;
   for (i = 0; i < length(rst_levels); i++)
      if (rst_levels[i] == ch) 
       return i;
   list_append(rst_levels, ch);
   return i;
}
% TODO: use wherefirst (how to convert a list to an array?)
% the following does not work
%    show(wherefirst( typecast(rst_levels, Array_Type) == ch));

public  define rst_list_routines_extract (nRegexp)
{
   variable ch, col, sec, fmt;
   ch = char(what_char());
   skip_chars(ch);
   col = what_column();
   !if (up(1)) 
     return "";
   eol(); bskip_white();
   if (what_column() > col) % underline too short
     return "";
   push_mark();
   bol_skip_white();
   sec = bufsubstr();
   if (sec == "") % empty header (transition or literal "::")
     return "";

   
% Variants of output formatting
% -----------------------------
% 
% ::
     
   % show(get_rst_level(ch), fmt);

   % do not indent at all (simple, missing information)
   % return(sprintf(fmt, "", sec));

   % indent by 1 space/level, precede with dot (the dot is unmotivated)
   % fmt = sprintf(".%%%ds%%s", -get_rst_level(ch));
   % return(sprintf(fmt, "", sec));

   % indent by 1 space/level, precede with underline char
   % fmt = sprintf("%s %%%ds%%s", ch, -get_rst_level(ch));
   % return(sprintf(fmt, "", sec));

   % indent by 1 underline char/level (too noisy)
   % return sprintf("%s %s", string_repeat(ch, get_rst_level(ch)+1), sec);

   % indetn by 2 underline chars/level (not better)
   % return sprintf("%s %s", string_repeat(ch, get_rst_level(ch)*2), sec);

   % indent by 1 dot/level (still ok)
   % return sprintf("%s %s", string_repeat(".", get_rst_level(ch)+1), sec);
   
   % indent by 2 dots/level (quite nice)
   % return sprintf("%s %s", string_repeat(".", get_rst_level(ch)*2), sec);

   % indent by 2 dots/level, precede with underline char (ugly)
   % return sprintf("%s %s %s", ch, string_repeat(".", get_rst_level(ch)*2), sec);
   
   % indent by 2 dots/level, underline char as marker  (quite nice, informative)
   % return sprintf(".%s %s %s", string_repeat(".", get_rst_level(ch)*2), ch, sec);

   % indent by 1 space/level, underline char as marker (best)
   % needs modified tokenlist that doesnot strip leading whitespace
   return sprintf("%s%s %s", string_repeat(" ", get_rst_level(ch)*2), ch, sec);

}

public  define rst_list_routines_done()
{
   rst_levels = {};    % reset
}

#endif


% Syntax Highlight
% ================
% 
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
%  * also, [-abc] must be written [\\-abc]
% 
% Therefore only a subset of inline markup will be highlighted correctly. ::

private define inline_rule(s)
{
   variable re = "%s([^ \t%s]|[^ \t%s]+[^%s]*[^ \t%s\\\\])%s";
   return sprintf(re, s, s, s, s, s, s);
}

static define setup_dfa_callback(mode)
{
   dfa_enable_highlight_cache(mode +".dfa", mode);
   
   variable color_strong = "error";
   variable color_emphasis = "string";
   variable color_literal = "preprocess";
   variable color_interpreted = "number";
   variable color_substitution = "keyword1";
   variable color_directive = "keyword1";
   %
   variable color_url = "keyword";
   variable color_email = "keyword";
   variable color_reference = "keyword";
   variable color_target = "keyword";
   variable color_list_marker = "delimiter";
   variable color_transition = "comment";


   % Inline Markup
   dfa_define_highlight_rule(inline_rule("\\*"), "Q"+color_emphasis, mode);
   dfa_define_highlight_rule(inline_rule("`"), color_interpreted, mode);
   % dfa_define_highlight_rule(":[a-zA-Z]+:"+inline_rule("`"), color_interpreted, mode);
   dfa_define_highlight_rule(inline_rule("\\|"), "Q"+color_substitution, mode);
   dfa_define_highlight_rule(inline_rule(":"), color_directive, mode);
   dfa_define_highlight_rule(inline_rule("\\*\\*"), "Q"+color_strong, mode);
   dfa_define_highlight_rule(inline_rule("``"), "Q"+color_literal, mode);
   
   % Literal Block marker
   dfa_define_highlight_rule("::[ \t]*$", color_literal, mode);
   % Doctest Block marker
   dfa_define_highlight_rule("^[ \t]*>>>.*", color_literal, mode);
   
   
   % Reference Marks
   %  URLs and Emails
   dfa_define_highlight_rule("(https?|ftp|file)://[^ \t>]+", color_url, mode);
   % dfa_define_highlight_rule ("[^ \t\n<]*@[^ \t\n>]+", color_email, mode);
   %  crossreferences             
   dfa_define_highlight_rule("[\\-a-zA-Z0-9_]*[a-zA-Z0-9]__?[^a-zA-Z0-9]", color_reference, mode);
   dfa_define_highlight_rule("[\\-a-zA-Z0-9_]*[a-zA-Z0-9]__?$", color_reference, mode);
   %  reference with backticks
   dfa_define_highlight_rule("`[^`]*`__?", color_reference, mode);
   %   footnotes and citations
   dfa_define_highlight_rule("\\[[a-zA-Z0-9#\\*\\.\\-_]+\\]+_", color_reference, mode); 

   % Reference Targets
   %  inline target
   dfa_define_highlight_rule("_`[^`]+`", color_target, mode);
   %  named crosslinks, footnotes and citations
   dfa_define_highlight_rule("^\\.\\. [_\\[].*", color_target, mode);
   % substitution definitions
   dfa_define_highlight_rule("^\\.\\. [|].*", color_target, mode);
   %  anonymous
   dfa_define_highlight_rule("^__ [^ \t]+.*$", color_target, mode); 
   %  footnotes and citations
   dfa_define_highlight_rule("^\\.\\. \\[[a-zA-Z#\\*]+\\].*", color_target, mode);

   % Comments
   dfa_define_highlight_rule("^\\.\\.", "Pcomment", mode);

   % Directives
   dfa_define_highlight_rule("^\\.\\. [^ \t]+.*::", color_directive, mode);
   
   % Lists
   %  itemize
   dfa_define_highlight_rule("^[ \t]*[\\-\\*\\+][ \t]+", "Q"+color_list_marker, mode);
   %  enumerate
   dfa_define_highlight_rule("^[ \t]*[0-9a-zA-Z][0-9a-zA-Z]?\\.[ \t]+", color_list_marker, mode);
   dfa_define_highlight_rule("^[ \t]*\\(?[0-9a-zA-Z][0-9]?\\)[ \t]+", color_list_marker, mode);
   dfa_define_highlight_rule("^[ \t]*#\\.[ \t]+", color_list_marker, mode);
   %  field list
   dfa_define_highlight_rule("^[ \t]*:.+:[ \t]+", "Q"+color_list_marker, mode);
   %  option list
   dfa_define_highlight_rule("^[ \t]*--?[a-zA-Z]+  +", color_list_marker, mode);
   %  definition list
   % doesnot work as jed's DFA regexps span only one line
   
   % Hrules and Sections
   % dfa_define_highlight_rule(Underline_Regexp, color_transition, mode);
   % doesnot work, as DFA regexps do not support "\( \) \1"-syntax.
   % So we have to resort to separate rules
   foreach (Underline_Chars)
       {
        $1 = ();
          $1 = str_quote_string(char($1), "\\^$[]*.+?", '\\');
          $1 = sprintf("^%s%s+[ \t]*$", $1, $1);
        dfa_define_highlight_rule($1, color_transition, mode);
       }
   
   dfa_build_highlight_table(mode);
}
dfa_set_init_callback(&setup_dfa_callback, mode);
%%% DFA_CACHE_END %%%
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
% 
% ::

!if (keymap_p(mode)) 
  make_keymap(mode);

% the backtick is is needed too often to be bound to quoted insert
definekey("self_insert_cmd", "`", mode);
% I recommend "°" but program only the save bet _Reserved_Key_Prefix+"`":
definekey_reserved("quoted_insert", "`", mode); % 

% "&Layout");                                                  "l", mode); 
definekey_reserved("rst->section_markup",                      "ls", mode); % "&Section"
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
definekey_reserved("rst_browse",                               "eb", mode); % &Browse Html"
definekey_reserved("rst->set_export_options(\"html\")",              "oh", mode); % "Set H&tml Export Options"
definekey_reserved("rst->set_export_options(\"tex\")",         "ol", mode); % "Set Late&x Export Options"
definekey_reserved("rst->set_export_options(\"pdf\")",         "op", mode); % "Set Late&x Export Options"
%                                                              "", mode); 
definekey_reserved("list_routines",                            "n", mode); % &Navigator"


% Mode Menu
% =========
% 
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
   menu_append_item(popup, "&Section", "rst->section_markup");
   menu_append_item(popup, "P&reformatted", &block_markup, "preformatted");
   menu_append_item(popup, "&Hrule", &markup, "hrule");    
   menu_append_item(popup, "&Directive", &markup, "directive");
   menu_append_item(popup, "&Comment", "comment_region_or_line");
   % References (outgoing links)
   popup = new_popup(menu, "&References (outgoing links)");
   menu_append_item(popup, "&Hyperlink", &markup, "hyperlink_ref");
   menu_append_item(popup, "&Anonymous Hyperlink", &markup, "anonymous_hyperlink_ref");
   menu_append_item(popup, "Numeric &Footnote", &markup, "numeric_footnote_ref");
   menu_append_item(popup, "&Symbolic Footnote", &markup, "symbolic_footnote_ref");
   menu_append_item(popup, "&Citation", &markup, "citation_ref");
   menu_append_item(popup, "&Substitution", &markup, "substitution_ref");
   % Reference Targets
   popup = new_popup(menu, "Reference &Targets");
   menu_append_item(popup, "&Hyperlink (URL)", &markup, "hyperlink");
   menu_append_item(popup, "&Anonymous Hyperlink", &markup, "anonymous_hyperlink");
   menu_append_item(popup, "Numeric &Footnote", &markup, "numeric_footnote");
   menu_append_item(popup, "&Symbolic Footnote", &markup, "symbolic_footnote");
   menu_append_item(popup, "&Citation", &markup, "citation");
   menu_append_item(popup, "&Substitution", &markup, "substitution");
   % ^CS...  Character styles (<em>, <strong>, <b>, <i>, etc.)
   popup = new_popup(menu, "&Inline Markup");
   menu_append_item(popup, "&Emphasis", &markup, "emphasis");
   menu_append_item(popup, "&Literal", &markup, "literal");
   menu_append_item(popup, "&Interpreted", &markup, "interpreted");
   menu_append_item(popup, "&Strong", &markup , "strong");
   menu_append_item(popup, "Su&bscript", &markup, "subscript");
   menu_append_item(popup, "Su&perscript", &markup, "superscript");
   % Directives
   popup = new_popup(menu, "&Directives");
   menu_append_item(popup, "&Number Sections", &insert, "\n.. sectnum::\n");
   menu_append_item(popup, "Table of &Contents", &insert, "\n.. contents::\n");
   menu_append_item(popup, "&Include", &insert, "\n.. include:: ");
   menu_append_separator(menu);
#ifexists list_routines
   menu_append_item(menu, "&Navigator", "list_routines");
   menu_append_separator(menu);
#endif
   % Export to a target file
   popup = new_popup(menu, "&Export");
   menu_append_item(popup, "&Html", "rst_to_html");
   menu_append_item(popup, "&Latex", "rst_to_latex");
   menu_append_item(popup, "&Pdf", "rst_to_pdf");
   popup = new_popup(menu, "Set Export &Options");
   menu_append_item(popup, "&Html", &set_export_options, "html");
   menu_append_item(popup, "&Latex", &set_export_options, "tex");
   menu_append_item(popup, "&Pdf", &set_export_options, "pdf");
   % Help commands
   menu_append_separator(menu);
   popup = new_popup(menu, "&Help");
   menu_append_item(popup, "Doc &Index", "browse_url", 
      path_concat(Rst_Documentation_Path, "index.html"));
   menu_append_item(popup, "&Quick Reference", "browse_url", 
      path_concat(Rst_Documentation_Path, "user/rst/quickref.html"));
   menu_append_item(popup, "&Directives", "browse_url", 
      path_concat(Rst_Documentation_Path, "ref/rst/directives.html"));
   menu_append_separator(popup);
   menu_append_item(popup, "Rst2&Html Help", &command_help, Rst2Html_Cmd);
   menu_append_item(popup, "Rst2&Latex Help", &command_help, Rst2Latex_Cmd);
   % Default conversion and browse
   menu_append_item(menu, "&Run Buffer", "run_buffer");
#ifexists browse_url   
   menu_append_item(menu, "&Browse Html", "rst_browse");
#endif
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
   % indent with structured_text_hook from structured_text.sl
   structured_text_hook();
   use_syntax_table(mode);
   % use_keymap (mode);
   mode_set_mode_info(mode, "fold_info", "..{{{\r..}}}\r\r");
   mode_set_mode_info(mode, "init_mode_menu", &rst_menu);
   mode_set_mode_info("run_buffer_hook", &rst_to_html);
   mode_set_mode_info("dabbrev_word_chars", get_word_chars());
   
   % define_blocal_var("Word_Chars", foo_word_chars);
   
   % define_blocal_var("help_for_word_hook", &rst_help);
   run_mode_hooks(mode + "_mode_hook");
}

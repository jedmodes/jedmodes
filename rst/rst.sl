% Mode for reStructured Text (from python-docutils)
% 
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
% 
% ReStructured Text is a revision of Structured Text, a simple markup language
% that can be translated to Html and LaTeX (and more, if someone writes 
% a converter)
% 
% References: http://docutils.sourceforge.net/
% 	      file:/usr/share/doc/python-docutils/rst/quickref.html
%
% Versions:
% 1.1 2004-10-18   initial attempt
% 1.2 2004-12-23   removed dependency on view mode (called by runhooks now)
% 1.2.1 2005-03-11 bugfix in Mode>Layout>Hrule
%                  bugfix remove spurious ":" from anonymous target markup

% For debugging purposes:
% _debug_info = 1;

% the modename
static variable mode = "rst";
implements(mode);

% --- Custom Variables
%!%+
%\variable{Rst2Html_Cmd}
%\synopsis{ReStructured Text to Html converter}
%\usage{String_Type Rst2Html_Cmd = "rst2html.py"}
%\description
%  Path to the ReStructured Text to Html converter
%\notes
%  The default works with the Debian package python-docutils.deb  
%\seealso{rst_mode}
%!%-
custom_variable("Rst2Html_Cmd", "rst2html.py");
% for a Debian default setup, choose
% custom_variable("Rst2Html_Cmd", "rst2latex.py");
% for simple Html without css stylesheets try the docarticle.py contribution
% custom_variable("Rst2Html_Cmd", "docarticle.py");

% custom_variable("Rst_Export_Options", "--output-encoding=latin-1");
custom_variable("Rst_Export_Options", "");

%!%+
%\variable{Rst2Latex_Cmd}
%\synopsis{ReStructured Text to Html converter}
%\usage{String_Type Rst2Latex_Cmd = "/usr/share/python-docutils/html.py"}
%\description
%  Path to the ReStructured Text to Html converter
%\notes
%  The default works with the Debian package python-docutils.deb  
%\seealso{rst_mode}
%!%-
custom_variable("Rst2Latex_Cmd", "rst2latex.py");

% --- Requirements (find them at http://jedmodes.sf.net/mode/)
require("structured_text");          % text_mode_hook for lists formatting
autoload("view_url", "browse_url");
autoload("browse_url", "browse_url");
autoload("bufsubfile", "bufutils");
autoload("insert_markup", "txtutils");   % >= 2.3
autoload("insert_block_markup", "txtutils");   % >= 2.3
autoload("string_repeat", "strutils");
autoload("save_buffer_as", "cuamisc");
autoload("shell_cmd_on_region", "ishell"); % >= 1.6
require("comments"); 

set_comment_info(mode, ".. ", "", 0);


% ---------------------------- static Variables --------------------------

static variable Markup_Tags = Assoc_Type[Array_Type];

% Layout Character
Markup_Tags["bold"]     = ["**", "**"];
Markup_Tags["emphasis"] = ["*",  "*"];
Markup_Tags["literal"]  = ["``", "``"];

% Layout Pragraph
Markup_Tags["hrule"]         = ["\n-------------\n", ""];  % alias transition
Markup_Tags["preformatted"] = ["::\n    ", "\n"];

% Marks (Links)
Markup_Tags["crossref_mark"]           = ["`", "`_"];   % hyperlink, anchor
Markup_Tags["anonymous_crossref_mark"] = ["`", "`__"];
Markup_Tags["numeric_footnote_mark"]   = ["",  " [#]_"]; % automatic  numbering
Markup_Tags["symbolic_footnote_mark"]  = ["",  " [*]_"]; % automatic  numbering
Markup_Tags["citation_mark"]           = ["[", "]_"];    % also for footnotes
Markup_Tags["substitution_mark"]       = ["|", "|"];

% Targets
Markup_Tags["crossref"]           = ["\n.. _", ":"];   % URL, crossreference
Markup_Tags["anonymous_crossref"] = ["__ ", ""];
Markup_Tags["numeric_footnote"]   = ["\n.. [#]", ""];   % automatic  numbering
Markup_Tags["symbolic_footnote"]  = ["\n.. [*]", ""];   % automatic  numbering
Markup_Tags["citation"]           = ["\n.. [", "]"];
Markup_Tags["directive"]          = ["\n.. ", "::"];   %
Markup_Tags["substitution"]       = ["\n.. |", "|"];


% ----------------------------- Functions --------------------------------

% export the buffer/region using cmd
public define rst_export(cmd)
{
   variable output_file, extension = "";
   switch (cmd)
     { case Rst2Html_Cmd: extension = ".html"; }
     { case Rst2Latex_Cmd: extension = ".tex"; }
   buffer_keystring(path_sans_extname(whatbuf())+extension);
   output_file = read_file_from_mini("Output File:");
   shell_cmd_on_region(cmd + " " + Rst_Export_Options, 
      "*rst_export output*", output_file);
   message("exported to " + output_file);
}

% export and view the buffer to html
public define rst_run()
{
   variable html_file = path_sans_extname(whatbuf())+".html";
   rst_export(Rst2Html_Cmd);
   find_file(html_file);
}

static define rst_export_help()
{
   do_shell_cmd(Rst2Html_Cmd + " --help");
   runhooks("view_mode");
}

static define set_rst_export_options()
{ Rst_Export_Options = read_mini("Rst_Export_Options:", "", Rst_Export_Options); }
  
% Browse the html conversion of the current buffer in an external browser
public define rst_browse() % (browser=NULL)
{ 
   variable args = __pop_args(_NARGS);
   rst_run();
   html_browse(__push_args(args));
   close_buffer();
}

% insert a markup
static define markup(type)
{ insert_markup(Markup_Tags[type][0], Markup_Tags[type][1]); }

static define block_markup(type)
{ insert_block_markup(Markup_Tags[type][0], Markup_Tags[type][1]); }

% underline the current line
% if there is already underlining, adapt it to the lenght of the line
static define section_markup()
{
   eol_trim();
   variable len = what_column(), ch, line_del=0, underline_chars="~'`=_-";
   
   if (len == 0)
     len = 20;   % transition
   !if(right(1))
     newline;
   foreach (underline_chars)
     {
	ch = char();
	if (looking_at(string_repeat(ch, 3)))
	  {
	     line_del = 1;
	     break;
	  }
     }
   ch = read_mini(sprintf("Underline character [%s]:", underline_chars),
      ch, "");
   if (line_del)
     delete_line();
   insert(string_repeat(ch, len-1)+ "\n");
}
     

% --- Create and initialize the syntax tables.
create_syntax_table (mode);
define_syntax( '\\', '\\', mode);               % escape character
set_syntax_flags (mode, 0);

% keywords
% admonitions
() = define_keywords_n(mode, "hintnote", 4, 0);
() = define_keywords_n(mode, "attention", 9, 0);

#ifdef HAS_DFA_SYNTAX
%%% DFA_CACHE_BEGIN %%%
static define setup_dfa_callback (mode)
{
   % dfa_enable_highlight_cache(mode +".dfa", mode);
   
   variable color_bold = "error";
   variable color_literal = "number";
   variable color_interpreted = "number";
   variable color_emphasis = "number";
   variable color_substitution = "number";
   variable color_directive = "number";
   %
   variable color_url = "keyword";
   variable color_email = "keyword";
   variable color_reference = "keyword";
   variable color_target = "preprocess";
   variable color_list_marker = "delimiter";
   variable color_transition = "comment";

   % variable color_from = "keyword1";
   % variable color_header = "...";
   % variable color_reply2 = "string";

   % Inline Markup
   % variable pre_i  = "(^|[-'\"\\(\\[{</: \t])"; % char before inline markup
   % variable post_i = "($|[-'\"\\)\\]}>/:\\.,;!?\\\\ \t])"; % char after ...
   % dfa_define_highlight_rule (pre_i+"\\*\\*[^ \t].*[^ \t]\\*\\*"+post_i, color_bold, mode);
   % doesnot work :-(
   dfa_define_highlight_rule ("\\*\\*[a-zA-Z0-9_\\-:!]+\\*\\*", color_bold, mode);
   dfa_define_highlight_rule ("\\*?\\*[a-zA-Z0-9_\\-:!]+\\*\\*?", color_emphasis, mode);
   dfa_define_highlight_rule ("`[a-zA-Z0-9_\\-:!]+`", color_interpreted, mode);
   dfa_define_highlight_rule ("``[a-zA-Z0-9_\\-:!]+``", color_literal, mode);
   dfa_define_highlight_rule ("\\|[a-zA-Z0-9_\\-:!]+\\|", color_substitution, mode);
   dfa_define_highlight_rule ("::$", color_literal, mode);
   dfa_define_highlight_rule (":[a-zA-Z0-9_\\-:!]+:", color_directive, mode);
   
   % Reference Marks
   %   URLs and Emails
   dfa_define_highlight_rule ("(http|ftp|file|https)://[^ \t\n>]+", color_url, mode);
   % dfa_define_highlight_rule ("[^ \t\n<]*@[^ \t\n>]+", color_email, mode);
   %   crosslinks
   dfa_define_highlight_rule ("[a-zA-Z0-9\\-_\\.]+_+[^a-zA-Z0-9]", color_reference, mode);
   dfa_define_highlight_rule ("[a-zA-Z0-9\\-_\\.]+_+$", color_reference, mode);
   dfa_define_highlight_rule ("`[^`]*`__?", color_reference, mode);
   %   footnotes and citations
   dfa_define_highlight_rule ("\\[[a-zA-Z0-9#\\*\\.\\-_]+\\]+_", color_reference, mode); 

   % Reference Targets
   %   named crosslinks, footnotes and citations, substitution definitions
   dfa_define_highlight_rule ("^\\.\\. [_\\[\\|].*", color_target, mode);
   % inline target
   dfa_define_highlight_rule ("_`[^`]*`", color_target, mode);
   % dfa_define_highlight_rule ("^\\.\\. _+`.+`:.*", color_target, mode);
   %   anonymous
   dfa_define_highlight_rule ("^__ .*", color_target, mode); 
   %   footnotes and citations
   dfa_define_highlight_rule ("^\\.\\. \\[[a-zA-Z#\\*]+\\].*", color_target, mode);

   % Comments
   dfa_define_highlight_rule ("^\\.\\..*$", "comment", mode);

   % Lists
   %   itemize
   dfa_define_highlight_rule ("^[ \t]*[\\-\\*\\+] ", color_list_marker, mode);
   %   enumerate
   dfa_define_highlight_rule ("^[ \t]*[0-9]+\\. ", color_list_marker, mode);
   dfa_define_highlight_rule ("^[ \t]*\\(?[a-zA-Z]+\\) ", color_list_marker, mode);
   %   field list
   dfa_define_highlight_rule ("^[ \t]*:.+: ", color_list_marker, mode);
   %   option list
   dfa_define_highlight_rule ("^[ \t]*--?[a-zA-Z]+  +", color_list_marker, mode);
   
   % hrules and Section underlining
   dfa_define_highlight_rule ("^(----|====|____|~~~~).*$",  color_transition, mode);

   dfa_build_highlight_table(mode);
}
dfa_set_init_callback(&setup_dfa_callback, mode);
%%% DFA_CACHE_END %%%
enable_dfa_syntax_for_mode(mode);
#else
% define_syntax( '`', '"', mode);               % strings
define_syntax ("..", "", '%', mode); % Comments
define_syntax ("[", "]", '(', mode);     % Delimiters
define_syntax ("0-9a-zA-Z", 'w', mode);      % Words
% define_syntax ("-+*=", '+', mode);           % Operators
% define_syntax ("-+0-9.", '0', mode);         % Numbers
% define_syntax (",", ',', mode);              % Delimiters
% define_syntax (";", ',', mode);              % Delimiters
#endif


% --- the mode dependend menu

% append a new popup to menu and return the handle
static define new_popup(menu, popup)
{
   menu_append_popup(menu, popup);
   return strcat(menu, ".", popup);
}

static define rst_menu(menu)
{
   variable popup;
   popup = new_popup(menu, "&Layout");
   % ^CP...  Paragraph styles, etc. (<p>, <br>, <hr>, <address>, etc.)
   menu_append_item(popup, "&Section", "rst->section_markup");
   menu_append_item(popup, "P&reformatted", &block_markup, "preformatted");
   % ^CS...  Character styles (<em>, <strong>, <b>, <i>, etc.)
   menu_append_item(popup, "&Emphasis", &markup, "emphasis");
   menu_append_item(popup, "&Bold", &markup , "bold");
   menu_append_item(popup, "&Literal", &markup, "literal");
   menu_append_item(popup, "&Hrule", &markup, "hrule");    
   % Crossref Marks (outgoing links)
   popup = new_popup(menu, "Crossref &Marks");
   menu_append_item(popup, "&Reference (link)", &markup, "crossref_mark");
   menu_append_item(popup, "&Anonymous Reference", &markup, "anonymous_crossref_mark");
   menu_append_item(popup, "&Footnote", &markup, "numeric_footnote_mark");
   menu_append_item(popup, "&Symbolic Footnote", &markup, "symbolic_footnote_mark");
   menu_append_item(popup, "&Citation", &markup, "citation_mark");
   menu_append_item(popup, "&Substitution", &markup, "substitution_mark");
   % Crossref Targets
   popup = new_popup(menu, "Crossref &Targets");
   menu_append_item(popup, "&Reference (link)", &markup, "crossref");
   menu_append_item(popup, "&Anonymous Reference", &markup, "anonymous_crossref");
   menu_append_item(popup, "&Footnote", &markup, "numeric_footnote");
   menu_append_item(popup, "&Symbolic Footnote", &markup, "symbolic_footnote");
   menu_append_item(popup, "&Citation", &markup, "citation");
   menu_append_item(popup, "&Directive", &markup, "directive");
   menu_append_item(popup, "&Substitution", &markup, "substitution");
   % Export to a target file
   popup = new_popup(menu, "&Export");
   menu_append_item(popup, "&Html", &rst_export, Rst2Html_Cmd);
   menu_append_item(popup, "&Latex", &rst_export, Rst2Latex_Cmd);
   menu_append_item(popup, "Set Rst Export &Options", "rst->set_rst_export_options");
   % Help commands
   popup = new_popup(menu, "&Help");
   menu_append_item(popup, "Rst2&Html Help", &rst_export_help, Rst2Html_Cmd);
   menu_append_item(popup, "Rst2&Latex Help", &rst_export_help, Rst2Latex_Cmd);

   menu_append_item(menu, "&Comment", "comment_region_or_line");
   
   menu_append_separator(menu);
   menu_append_item(menu, "&Run Buffer", "rst_run");
   menu_append_item(menu, "&Browse Html", "rst_browse");
}

public define rst_mode()
{
   text_mode();    % rst is an extended text mode
   set_mode(mode, 1);
   % make sure the text_mode_hook from structured_text gets loaded
   use_syntax_table(mode);
   % use_keymap (mode);
   mode_set_mode_info(mode, "fold_info", "..{{{\r..}}}\r\r");
   mode_set_mode_info(mode, "init_mode_menu", &rst_menu);
   % define_blocal_var("Word_Chars", foo_word_chars);
   % define_blocal_var("help_for_word_hook", &rst_help);
   define_blocal_var("run_buffer_hook", &rst_run);
   run_mode_hooks(mode + "_mode_hook");
}

provide(mode);

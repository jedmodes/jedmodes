% pymode.sl: Python editing mode for Jed
%
% For editing source code written in the Python programming language.
% Provides basic compatibility with Python mode under real Emacs
%
% Authors: Harri Pasanen <hpa@iki.fi>
%          Brien Barton <brien_barton@hotmail.com>
%          Guenter Milde <milde users.sourceforge.net>
%
% The following keys have python specific bindings:
% (assuming _Reserved_Key_Prefix == "^C")
%
%   Backspace   deletes to previous indent level
%   : (colon)   dedents appropriately
%   ^C#         comments region or current line
%   ^C>         shifts line or region right
%   ^C<         shifts line or region left
%   ^C^C        executes the region, or the buffer if region not marked.
%   ^C|         executes the region
%
% Use the python_mode_hook() for customization.
% See the online doc for python_mode() and python_mode_hook().
%
% Shortcomings: Does not highligt triple-quoted strings well:
%
%  * No highlight for multi-line string literals with DFA syntax highlight.
%  * It works OK with """ (but NOT with ''') if DFA syntax highlight is off.
%
% Versions
% --------
%
% 1.0 first public version (Harri Pasanen, Brien Barton)
% 1.1 Major improvements, mostly done by Brien Barton:
%      - execution of python code from JED
%      - DFA syntax support
%      - improved indent - dedent.
% 1.2 Minor fixes, by Tom Culliton
%      - corrected a syntax error
%      - fixed non-DFA syntax hilighting tables to work better
%      - added the new assert keyword
% 1.3  - autoindent correction
% 1.4  - Better indenting of function arguments and tuples
%      - New keywords and builtins added (TJC)
%      - An attempt to do pretty indenting of data structures and
%      	 parameter lists
%      - Try to keep the lines under 80 columns and make formatting consistent
% 1.5 (JED)
%      - discard return value from run_shell_cmd
%      - avoid use of create_array and explicit loop for initializing it.
% 2.0 2006-09-29 (Guenter Milde)
%       - detect use of Tabs or Spaces for indentation
%       - py_reindent() now honours continuation lines
%       - declared python_mode explicitely a public function
%       - new function py_help (needs the pydoc module)
%       - interactive python session with ishell
%       - py_line_starts_block(), py_line_starts_subblock(), py_endblock_cmd():
%         fix false positives with lines starting with e.g. "passport"
%         (words that start with a keyword). (modified patch by Peter Bengtson
%          and Jörg Sommer)
%       - use indent_hook instead of binding the TAB key
%       - various small twiddles
%       - use comments.sl instead of special commenting functions
%       - added mode menu
% 2.1 2006-11-23
%       - Auto-determine the indent-string from first indented code line
%     	  (as emacs does and PEP 0008 recommends)
%     	  The custom variable Py_Indent_Level is the fallback value, giving the
%     	  number of spaces per indent-level or 0 for "indent with tabs".
%     	- py_indent_line() honours continuation lines
%	- major code cleanup
% 	    named namespace "pymode" (reduces namespace pollution),
% 	    drop "py_" prefix of some static functions
% 	    made some static functions inline code
%	- many bugfixes after unit testing, e.g.
%	    electric_colon - return 0 if colon is in a comment
%	    dfa error flagging: allow imaginary numbers (1j or 1J)
%	- added and updated documentation
% 	- leave the TAB value as is (so hard-tabs will not show as '^I' if
% 	  indentation uses spaces)
% 2.1.1 2007-01-18
% 	- catch errors and widen in py_shift_region_left()
% 	- new function browse_pydoc_server()
% 	- added browse_url() autoload and require("keydefs")
% 	- replaced calculate_indent_col() with calculate_indent
% 	- define in_literal_string() without narrow_to_region, as this
% 	  does a "spurious" update.
% 	- added True and False keywords
% 	- py_indent_line() keeps point
% 	- bugfix in reindent_block()
% 2.1.2 2007-02-06
%       - use sprintf() instead of ""$ for `outbuf` string in py_exec()
% 2.1.3 2007-05-14
%       - simplified browse_pydoc_server()
%       - added info about DFA syntax highlight to pymode_hook doc
% 2.1.4 2007-05-25 - add StopIteration keyword, formatting
% 2.1.5 2007-06-21 - add autoload for fit_window() (report Michael Johnson)
% 2.1.6 2007-12-05 - implement Jörg Sommer's fix for DFA highlight under UTF-8
%                  - set_highlight_scheme() function and mode menu entry
%                  - Python_Use_DFA custom variable
%                  - cleanup and fix of DFA rules
% 2.2   2008-12-12 - Special modes for Python help and Python output,
% 		   - new mode-menu item "Fold by indentation",
%                  - added autoload for view_mode() (report P. Bengtson)
% 2.2.1 2010-12-08 - py_untab() restores point.
%                  - Adapt py_browse_module_doc() to 2.6 doc paths.
% 2.2.1 2015-09-25 - Fix quoting in python_help().
% 2.2.2 2015-09-28 - Add autoload for push_defaults().


% TODO
% ----
%
% Allow wrapping of continuation lines and in comments:
%
% "wrapok_hook"
%     This hook may be used to enable automatic wrapping on a
%     line-by-line basis.  Jed will call this hook prior to wrapping a
%     line, and if it returns a non-zero value, the line will be
%     wrapped.  See lib/slmode.sl for an example of its use.
%
% Wrapping of code: wrap point is ", " behind a "("

provide("pymode");

% Requirements
% ------------

% SLang 2 (`List_Type', `throw' keyword, and `foreach' loop with variable)
require("comments"); % (un-)commenting lines and regions
require("keydefs");  % symbolic constants for many function and arrow keys

% utilities from http://jedmodes.sf.net/
autoload("browse_url", "browse_url");
autoload("buffer_dirname", "bufutils");
autoload("fit_window", "bufutils");
autoload("popup_buffer", "bufutils");
autoload("untab_buffer", "bufutils");
autoload("run_local_hook", "bufutils");
autoload("ishell_mode", "ishell");
autoload("shell_command", "ishell");
autoload("ishell_send_input", "ishell");
autoload("ishell_set_output_placement", "ishell");
autoload("shell_cmd_on_region_or_buffer", "ishell");
autoload("get_blocal", "sl_utils");
autoload("push_defaults", "sl_utils");
autoload("string_get_match", "strutils");
autoload("str_re_replace_all", "strutils");
autoload("get_word", "txtutils");
autoload("bget_word", "txtutils");
autoload("view_mode", "view");

implements("python");
private variable mode = "python";

% Custom variables and settings
% =============================

%!%+
%\variable{Py_Indent_Level}
%\synopsis{Number of spaces to indent a code block}
%\usage{variable Py_Indent_Level = 4}
%\description
%  \sfun{python->get_indent_level} determines the buffer-local indentation
%  level from the first indented code line. \var{Py_Indent_Level} is the
%  default, used for the buffer-local indent-level, for a buffer
%  without indented code lines (e.g. a new one).
%
%  The pre-set value of 4 spaces corresponds to the "Style Guide for Python
%  Code" (http://www.python.org/dev/peps/pep-0008/)
%
%  The special value 0 means use hard tabs ("\\t") for indentation.
%\example
%  To have tab-indentation by default with visible tab-width of 3, write in
%  jed.rc something like
%#v+
%    Py_Indent_Level = 0;
%    TAB_DEFAULT = 3;
%#v-
%  If the global \var{TAB_DEFAULT} should not be touched, set the buffer local
%  TAB in a \sfun{python_mode_hook}.
%\seealso{python->get_indent_level, python->get_indent_width, TAB}
%!%-
custom_variable("Py_Indent_Level", 4);

%!%+
%\variable{Python_Doc_Root}
%\synopsis{Root directory of the Python html documentation.}
%\usage{variable Python_Doc_Root = "/usr/share/doc/python/html/"}
%\description
%  Path to the base dir of the Python html documentation.
%  The default setting works for a Debian installation.
%\seealso{py_browse_module_doc, py_help}
%!%-
custom_variable("Python_Doc_Root", "/usr/share/doc/python/html/");

%!%+
%\variable{Python_Use_DFA}
%\synopsis{Use DFA syntax highlight for \var{python_mode}?}
%\usage{variable Python_Use_DFA = 0}
%\description
%  Choose the syntax highlight scheme.
%
%  Syntax highlight could use either a DFA syntax highlight scheme or the
%  "traditional" one. Advantages are:
%
%  traditional: highlights muliti-line string literals (if enclosed in """)
%
%  dfa: highlights some syntax errors (e.g. invalid number formats,
%       mix of Spaces and Tab in code indention, or quote with trailing
%       whitespace at eol)
%\seealso{python->set_highlight_scheme, enable_dfa_syntax_for_mode}
%!%-
custom_variable("Python_Use_DFA", 0);

%!%+
%\function{python_mode_hook}
%\synopsis{Customization hook called by \sfun{python_mode}}
%\usage{Void python_mode_hook()}
%\description
%  If \sfun{python_mode_hook} is defined by the user, it will be called by
%  \sfun{python_mode}. This provides a very flexible way for user
%  customization. This can be used for e.g. setting of the TAB value, code
%  indentation check or fix, buffer reformatting, or customizing the
%  keybindings or syntax highlight scheme.
%\example
%  * Check the code indentation at startup:
%    - warn in minibuffer if tabs and spaces are mixed
%#v+
%        define python_mode_hook() { py_check_indentation() }
%#v-
%    - untab: replace all hard tabs if indentation uses spaces
%      This is more efficient than re-indenting to get rid of tabs.
%      (Not only in code indentation but in the whole buffer.)
%
%      (Conversion of spaces to tabs is possible with
%      a  \sfun{prefix_argument} and \sfun{py_untab}. However, this does not
%      guarantee a non-mixed indentation, as spaces remain in places where the
%      whitespace does not end at a multiple of TAB. This is why py_reindent()
%      is recommended in this case.)
%#v+
%        define python_mode_hook() {
%           if (python->get_indent_level())
%             py_untab();
%           % more customization...
%        }
%#v-
%    - ask: in case of mixed whitespace, ask for fixing by re-indentation
%#v+
%        define python_mode_hook() {
%           !if (python->check_indentation())
%              py_reindent();
%           % more customization...
%        }
%#v-
%    - auto: in case of mixed whitespace, reindent with global \var{Py_Indent_Level}
%#v+
%        define python_mode_hook() {
%           !if (python->check_indentation())
%              python->reindent_buffer(Py_Indent_Level);
%           % more customization...
%        }
%#v-
%\seealso{py_untab, py_reindent, python->check_indentation}
%!%-

% Custom colours (pre-defined since Jed 0-99.18)
% Make sure they have a different background as there is no foreground to see.
custom_color("trailing_whitespace", get_color("menu"));
custom_color("tab",                 get_color("menu"));

% Functions
% =========

% Get/Set/Check code indentation data
% -----------------------------------

% Skip literal string
%
% Skip literal string if point is at begin-quote.
% Needed in the test if the point is in a long literal
% string and hence in the test for continuation lines.
%
% Skips behind the literal string which is either
%   one place after the end-quote, or
%   end of buffer (unclosed long string), or
%   end of line  (unclosed short string)
%
% There are 4 kinds of quotes: ''',  """, ', and " which might be nested
% Return value:
%   0      no end quote found
%   1      skipped over short string (', ")
%   3      skipped over long string (''', """)
%
% If the point is not at a begin-quote, move right one place
% (to prevent e.g. an infinite `while' loop).
static define skip_string()
{
   variable quote, quotes = ["'''", "\"\"\"", "'", "\"", ""], quotelen,
     search_fun = [&ffind, &fsearch];

   % determine starting quote
   foreach quote (quotes)
     if (looking_at(quote))
       break;
   quotelen = strlen(quote);

   go_right_1();

   % search for matching quote, check escaping
   while (@search_fun[quotelen > 1](quote))
     {
	blooking_at("\\"); % check for quote (push on stack)
	go_right(quotelen);
	if () % quoted (get from stack)
	  continue;
	return quotelen;
     }
   % no end quote found, skip to "natural end"
   switch (quotelen)
     { case 1: eol(); }
     { case 3: eob(); }
   return 0;
}

% Test if point is "behind" the position saved in (col, line)
static define is_behind(line, col)
{
   return orelse{what_line() > line}
     {andelse{what_line() == line}
	  {what_column() > col}
     };
}

% Test if point is inside string literal
%
% parse_to_point() doesnot work, as Python allows long (i.e. line
% spanning) strings.
% Complicated, because there are 4 ways to mark literal strings:
% single and triple quotes or double-quotes, (', ", ''', or """) which might
% be nested. Therefore all string-literals before the point need to be
% searched and skipped.
%
% The optional start_mark is used to shortcut the search. It must point to a
% place known to be outside a string.
static define in_literal_string() % [Mark_Type start_mark]
{
   variable col = what_column(), line = what_line(), in_string = 0;

   push_spot();
   EXIT_BLOCK { pop_spot(); }

   % Scan for literal strings. If quotes are unbalanced, we are inside
   %
   %    % Alternative: Narrow the search space ...
   %      narrow_to_region() has the side-effect, that an undo() after
   %      any function that used it (directly or indirectly) will move the
   %      cursor to the beginning of the region (in this case bob or the
   %      start_mark())

   % start outside a literal string:
   if (_NARGS)
     goto_user_mark(()); % get arg from stack
   else
     bob();
   % the scanning loop
   while (re_fsearch("['\"]")) % find the next begin-quote
     {
	% skip if escaped or in a comment
	if (orelse{blooking_at("\\")}{parse_to_point() == -2})
	  {
	     skip_chars("'\"");
	     continue;
	  }
	% now at string-opening quote, abort if we passed the original point
	if (is_behind(line,col))
	  return 0;
	% skip to end of literal string
	() = skip_string(); % False, if no matching end-quote found
	% check if we passed the original point
	if (is_behind(line,col))
	  return 1;
     }
   return 0;
}

% Test if point is in a continuation line
% (after line ending with \, inside long string literals, (), [], and {})
% return zero or recommended indentation column
static define is_continuation_line()
{
   variable delim, line = what_line(), col;

   push_spot();
   EXIT_BLOCK { pop_spot(); }

   % goto previous line, determine indentation
   !if (up_1())
     return 0;  % first line cannot be a continuation
   bol_skip_white();
   col = what_column();

   % Check the various variants of continuation lines:
   %  explicit (previous line ending in \)
   eol(); go_left_1();
   if (looking_at_char('\\') and (parse_to_point() != -2)) % not in comment
     return col;
   %  long literal string (test for balance of """ """ and ''' ''')
   goto_spot();
   bol();
   if (in_literal_string)
     return col;
   %  parentheses, brackets and braces
   foreach delim (")]}")
     {
	goto_spot();
	bol();
	!if (find_matching_delimiter(delim) == 1) % goto (, [, or {
	  continue;
	col = what_column();
	switch (find_matching_delimiter(0))     % goto ), ], or }
	  { case 0: return col + 1; }     		% unbalanced
	  { case 1 and (what_line() > line):    % spans current line
	     return col + 1; }
	  { case 1 and (what_line() == line):   % ends at current line
	     bol_skip_white();
	     return col + not(looking_at_char(delim)); }
     }
   return 0;  % test negative
}

% Test if current line is an indented code line
%
% (use for detection, reindent,  fixing)
% The point is left at the first non-white space
static define is_indented_code_line()
{
   bol_skip_white();
   if (bolp())                % no indent
     return 0;
   if (eolp())         	      % empty line
     return 0;
   if (looking_at_char('#'))  % comment
     return 0;
   if (is_continuation_line())
     return 0;
   return 1;
}


%!%+
%\function{python->get_indent_level}
%\synopsis{Determine the buffer-local indentation level}
%\usage{python->get_indent_level()}
%\description
%  Return the buffer local indent level setting (number of spaces or 0 for
%  "use tabs"). The value is determined from
%     the cached value (blocal variable "Py_Indent_Level"),
%     the first indented code line, or
%     the custom variable \var{Py_Indent_Level}.
%  It is cached in the blocal variable "Py_Indent_Level"
%\seealso{py_indent_line, py_reindent, py_shift_right, py_shift_left}
%!%-
static define get_indent_level()
{
   variable name = "Py_Indent_Level", value = NULL;

   % use cached value
   if (blocal_var_exists(name))
     return get_blocal_var(name);

   push_spot_bob();
   % guess from indented code line
   while (re_fsearch("^[ \t]"))
     {
	if (is_indented_code_line()) % moves to first non-white char
	  {
	     if (blooking_at("\t"))
	       value = 0;
	     else
	       value = what_column - 1;
	     break;
	  }
     }
    % use default value
   if (value == NULL)
     value = Py_Indent_Level;
   pop_spot();
   define_blocal_var(name, value);
   return value;
}

% get the width of the expanded indent string (indent_level or TAB)
static define get_indent_width()
{
   variable indent = get_indent_level();
   if (indent)
	 return indent;
   else
	 return TAB;
}

%!%+
%\function{python->check_indentation}
%\synopsis{Check whitespace in code indentation}
%\usage{Int_Type|Char_Type = python->check_indentation()}
%\description
% Test whitespace in python code indentation and return:
%    0     mix of tabs and spaces
%    ' '   indent with spaces
%    '\t'  indent with tabs
%
% Doesnot keep the point! If a mix of tabs and spaces is found, it
% leaves the point at the first non-white char in the offending line.
% (This might also be a continuation line so no mix is reported.)
% Calling \sfun{py_indent_line} at this line (most simply by pressing Key_Tab),
% will fix this line indentation.
%\example
%%  Check whitespace before saving.
%%  In case of mixed whitespace, ask for fixing by re-indentation
%#v+
%   define python_save_buffer_hook(filename) {
%      !if ((what_mode(), pop) == "python")
%         return;
%      !if (python->check_indentation())
%         py_reindent();
%      }
%   append_to_hook("_jed_save_buffer_before_hooks", &python_save_buffer_hook);
%   }
%#v-
%\seealso{py_check_indentation, py_reindent, python_mode_hook}
%!%-
static define check_indentation()
{
   variable pattern, indent_level = get_indent_level();
   if (indent_level)     % indent with spaces
     pattern = "^ *\t";    % leading whitespace containing tab
   else                  % indent with tabs
     pattern = "^\t* ";    % leading whitespace containing space

   bob();
   % check for 'wrong' character in code indentation whitespace
   while (re_fsearch(pattern))
     if (is_indented_code_line()) % leaves point at first non-white char
       return 0;
   % no 'wrong' character found
   if (indent_level)
     return ' ';
   else
     return '\t';
}

%!%+
%\function{py_check_indentation}
%\synopsis{Check whitespace in code indentation}
%\usage{py_check_indentation()}
%\description
% Tell, whether code indentation uses tabs or spaces.
% Throw an error if it contains a mix of tabs and spaces.
%
% If a mix of tabs and spaces is found, the point is left at the first
% non-white char in the offending line.
%\example
%  Check whitespace before saving.
%#v+
%   define python_save_buffer_hook(filename) {
%      !if ((what_mode(), pop) == "python")
%         return;
%      py_check_indentation();
%      }
%   append_to_hook("_jed_save_buffer_before_hooks", &python_save_buffer_hook);
%   }
%#v-
%\seealso{py_check_indentation, py_reindent, python_mode_hook}
%!%-
public  define py_check_indentation()
{
   push_spot();
   switch (check_indentation())
     { case 0: throw RunTimeError, "Code indentation mixes spaces and tabs!"; }
     { case ' ': message("Code indent uses spaces."); }
     { case '\t': message("Code indent uses tabs."); }
   pop_spot();
}


% Calculate indent (parsing last line(s))
% ---------------------------------------

% this function moves the point to somewhere near eol!
static define line_ends_with_colon()
{
   eol();
   !if (bfind_char(':'))
     return 0;
   if (parse_to_point() == -2)   % in comment
     return 0;
   go_right_1();
   skip_white();
   if (eolp() or looking_at_char('#'))
     return 1;
   return 0;
}

% is the current line the last of a block? (should the next line unindent?)
static define endblock_cmd()
{
   % TODO: do we want empty lines to mark a block-end?
   %       no because this doesnot work well with trim_buffer() [GM]
   % if (bolp() and eolp())           % empty line (not even whitespace)
   %   return 1;
   bol_skip_white();
   return is_list_element("return,raise,break,pass,continue", get_word(), ',');
}

static define line_starts_subblock()
{
   bol_skip_white();
   return is_list_element("else,elif,except,finally", get_word(), ',');
}

static define line_starts_block()
{
   bol_skip_white();
   return (is_list_element("if,try", get_word(), ',')
      	   or line_starts_subblock());
}

% Parse last line(s) to estimate the correct indentation for the current line
%
% Used in py_indent_line, indent_line_hook (for indent_line() and
% newline_and_indent(), and electric_colon()
static define calculate_indent()
{
   variable col, new_subblock, has_colon, indent_width = get_indent_width();

   push_spot_bol();
   % Check for continuation line
   col = is_continuation_line();
   if (col > 0)
     {
	pop_spot();
	return col-1;
     }
   % Parse current and preceding lines for indentation clues
   new_subblock = line_starts_subblock();
   % go to preceding line
   !if (up_1)
     return 0;    % first column: do not indent
   has_colon = line_ends_with_colon();
   % bskip continuation lines
   while (is_continuation_line())
     go_up_1();    % no infinite recursion: line 1 is no continuation line
   % get indentation
   bol_skip_white();
   col = what_column();
   % modify according to parse result
   if (has_colon)
     col += indent_width;
   if (endblock_cmd() or (new_subblock and not line_starts_block()))
     col -= indent_width;
   pop_spot();
   return col-1;
}

% Indent current line
%
% Change the indentation of the current line using given or calculated amount
% of whitespace.
% Tab- or space-use is determined by get_indent_level() (0 -> use tabs)
public  define py_indent_line() % (width = calculate_indent())
{
   !if (_NARGS)
     calculate_indent();
   variable width = ();

   push_spot();
   bol_trim();
   if (get_indent_level())
     insert_spaces(width);
   else
     whitespace(width);
   pop_spot();
   if (bolp())
     skip_white();
}

%!%+
%\function{python->py_shift_line_right}
%\synopsis{Increase the indentation level of the current line}
%\usage{Void python->py_shift_line_right(levels)}
%\description
%  Increase the indentation of the current line to the next
%  indent level.
%
%  A \sfun{prefix_argument} can be used to repeat the action.
%\seealso{py_shift_right, py_shift_left, set_prefix_argument}
%!%-
static define py_shift_line_right()
{
   variable steps = prefix_argument(1);
   variable indent_width = get_indent_width();
   bol_skip_white();
   variable level = (what_column-1)/indent_width + steps;
   vmessage("old-indent=%d, old-level=%d, new-level=%d, new-indent=%d",
      what_column-1, (what_column-1)/indent_width, level, level*indent_width);

   py_indent_line(level * indent_width);
}

%!%+
%\function{python->py_shift_region_right}
%\synopsis{Increase the indentation level of the region}
%\usage{Void python->py_shift_region_right()}
%\description
%  Call \sfun{python->py_shift_line_right} for all lines in the current region.
%
%  A \sfun{prefix_argument} can be used to repeat the action.
%\seealso{py_shift_rigth, py_shift_left, set_prefix_argument}
%!%-
static define py_shift_region_right()
{
   variable prefix = prefix_argument(1);
   check_region(0);		%  push spot, point at end of region
   narrow();
   do
     {
	set_prefix_argument(prefix);
	py_shift_line_right();
     }
   while (up_1());
   widen();
}

%!%+
%\function{py_shift_right}
%\synopsis{Increase indentation level of current line or region}
%\usage{py_shift_right()}
%\description
%  Increase the indentation of the current line to the next indent level.
%  (Similar to a simulated tabbing).
%
%  The buffer local spacing of the indent levels is determined with
%  \sfun{python->get_indent_width}.
%
%  A \sfun{prefix_argument} can be used to repeat the action.
%\example
%  With default emacs keybindings,
%#v+
%     ESC 4  Ctrl-C >
%#v-
%  will indent the line or region by 4 levels.
%\notes
%  Calls \sfun{py_shift_line_right} or \sfun{py_shift_region_right},
%  depending on the outcome of \sfun{is_visible_mark}.
%\seealso{py_shift_left, set_prefix_argument}
%!%-
public define py_shift_right()
{
   if (is_visible_mark()) {
      py_shift_region_right();
   } else {
      py_shift_line_right();
   }
}

% decrease the indentation of the current line one level
static define py_shift_line_left()
{
   variable steps = prefix_argument(1);
   variable indent_width = get_indent_width();
   bol_skip_white();
   variable level = (what_column()-2+indent_width)/indent_width - steps;
   vmessage("old-indent=%d, old-level=%d, new-level=%d, new-indent=%d",
      what_column-1, (what_column-2+indent_width)/indent_width,
      level, level*indent_width);

   if (level < 0)
     {
	if (eolp)
	  return trim(); % empty line, trim and return
	else
	  throw RunTimeError,
	  sprintf("Line is indented less than %d level(s)", steps);
     }

   py_indent_line(level * indent_width);
}

static define py_shift_region_left()
{
   variable e, steps = prefix_argument(1);
   check_region(1);
   narrow();
   do
     {
	set_prefix_argument(steps);
	try (e)
	  {
	     py_shift_line_left();
	  }
	catch AnyError:
	  {
	     widen();
	     % show(e);
	     throw e.error, e.message;
	  }
     }
   while (up_1());
   widen();
   pop_spot();
}

%!%+
%\function{py_shift_left}
%\synopsis{Decrease indentation level of the current line or region}
%\usage{py_shift_left()}
%\description
%  Decrease the indentation of the current line or (visible) region
%  to the previous indent level. (Similar to a simulated tabbing).
%
%  The buffer local spacing of the indent levels is determined with
%  \sfun{python->get_indent_width}.
%
%  A \sfun{prefix_argument} can be used to repeat the action.
%
%  Abort if a line is less indented than it should be unindented.
%\example
%  With default emacs keybindings,
%#v+
%     ESC 4  Ctrl-C <
%#v-
%  will unindent the line or region by 4 * \var{Py_Indent_Level}.
%\notes
%  Calls \sfun{py_shift_line_left} or \sfun{py_shift_region_left},
%  depending on the outcome of \sfun{is_visible_mark}.
%\seealso{py_shift_right, set_prefix_argument}
%!%-
public define py_shift_left()
{
   push_spot();
   if (is_visible_mark()) {
      py_shift_region_left();
   } else {
      py_shift_line_left();
   }
   pop_spot();
}

%!%+
%\function{py_untab}
%\synopsis{Convert tabs to spaces or vice versa}
%\usage{py_untab()}
%\description
%  Replace all hard tabs ("\t") by one to eight spaces such that the total
%  number of characters up to and including the replacement is a multiple of
%  eight (this is also Python's TAB replacement rule).
%
%  With prefix argument, convert spaces to tabs and set \var{TAB} to the
%  buffer local Py_Indent_Level.
%\notes
%  Other than \sfun{untab}, \sfun{py_untab} acts on the whole buffer, not on a
%  region.
%\seealso{py_reindent, TAB, untab}
%!%-
public  define py_untab()
{
   variable indent, convert_to_tabs = prefix_argument(0);
   push_spot();
   mark_buffer();
   if (convert_to_tabs)
     {
	set_prefix_argument(1);
	TAB = get_indent_width();
     }
   else
     TAB = 8;

   untab();

   if (convert_to_tabs)
     {
        vmessage("Converted spaces to tabs.");
        define_blocal_var("Py_Indent_Level", 0);
     }
   else
     {
        vmessage("Converted all tabs to spaces.");
        define_blocal_var("Py_Indent_Level", TAB);
     }
   pop_spot();
}

%!%+
%\function{python->reindent_buffer}
%\synopsis{Reindent buffer using \var{Py_Indent_Level}}
%\usage{Void python->reindent_buffer(indent_level=get_indent_level())}
%\description
%  Normalize indentation based on the current relative indentation and
%  \var{indent_width}.
%\notes
%  In many computer languages (like C and SLang), indentation is redundant
%  (just a matter of style) and may therefore be completely automatized.
%  In Python, indentation bears information (defining blocks of code)
%  and can not always be determined automatically.
%
%  While \sfun{py_indent_line} parses the preceding lines to estimate the
%  indentation for the current (or new) line, \sfun{python->reindent_buffer}
%  reformats syntactically correct indented code and cannot extrapolate to a
%  new line. It will abort if the indentation violates the Python syntax.
%\seealso{py_indent_line, py_untab}
%!%-
static define reindent_buffer() % (indent_level=get_indent_level())
{
   if (_NARGS)
     {
	variable indent_level = ();
	define_blocal_var("Py_Indent_Level", indent_level);
     }
   variable col, offset, comment,
     indent_width = get_indent_width(),
     indent_levels = {1}; % list of distinct start columns

   if (indent_width == 0) % convert to tabs and TAB == 0
     {
	TAB = 8;
	indent_width = 8;
     }

   bob();
   while (re_fsearch("^[ \t]")) % leading whitespace
     {
	skip_white();
	if (eolp())    % empty line
	  continue;
	col = what_column();
	comment = looking_at_char('#');

	% continuation line: shift by the same amount as previous line
	if (is_continuation_line())
	  {
	     % get deviation from last non-continuation line
	     offset = col - indent_levels[0];
	     bol_trim();
	     % no problem, if the new indent is negative:
	     %   indent of continuation lines is redundant and
	     %   a negative value for py_indent_line() indents to column 1.
	     py_indent_line((length(indent_levels)-1)*indent_width + offset);
	     continue;
	  }
	% indent
	if (col > indent_levels[0])
	  list_insert(indent_levels, col);
	else
	  % no change or dedent
	  while (col < indent_levels[0])
	    list_delete(indent_levels, 0);
	% Test if indent value is wrong (dedent to non-previous level)
	if ((col != indent_levels[0]) and not comment)
	  throw RunTimeError,
	  "Inconsistent indention: unindent to non-matching level";
	% now re-indent
	bol_trim();
	py_indent_line((length(indent_levels)-1)*indent_width);
     }
}

% reindent the current block or all blocks that overlap with a visible region
%
% no provision for indent-level specification, as this would lead to
% inconsistent indents (you can of course still
%    define_blocal_var("Py_Indent_Level", <value>)
% before the call to python->reindent_block
static define reindent_block()
{
   % push spot at end of current line or last line of visible region
   if (is_visible_mark())
     () = check_region(0);
   eol(); % this way the current line is also found by the bsearch
   push_spot();
   if (is_visible_mark) % and go to beg of region
     pop_mark_1();

   % mark the start of current code block
   do
     !if (re_bsearch("^[^ \t]"))
       throw UsageError, "Start of code block not found";
   while (is_continuation_line());
   push_mark();
   % go to the end of current code block
   goto_spot();
   do
     !if (re_fsearch("^[^ \t]"))
       {  % code block ends at eob if no non-indented code line is found
	  eob();
	  break;
       }
   while (andelse{is_continuation_line()}{down_1()});
   % now narrow the buffer and reindent
   narrow();
   reindent_buffer();
   widen();
   pop_spot();
}


%!%+
%\function{py_reindent}
%\synopsis{Reindent buffer/region to uniform indent levels}
%\usage{Void py_reindent()}
%\description
%  Normalize indentation based on the current relative indentation.
%  Asks for the new indent level (0 for indenting with tabs).
%
%  Calls \sfun{python->reindent_buffer} or, if a visible region is defined,
%  \sfun{python->reindent_block}.
%\seealso{py_indent_line, py_untab}
%!%-
public  define py_reindent()
{
   variable new_indent
     = integer(read_mini("Reindent with indent-level (0 for tabs)",
			 string(python->get_indent_level), ""));
   if (is_visible_mark)
     reindent_block(new_indent);
   else
     reindent_buffer(new_indent);
}


% "Magic" keys
% ------------

% shift line right if we are at the first non-white space in an indented
% line,  normal action else
static define py_backspace_key()
{
   push_spot();
   bol_skip_white();
   variable first_non_white = what_column();
   pop_spot();

   if (first_non_white == what_column() and not bolp())
     py_shift_line_left();
   else
     call("backward_delete_char_untabify");
}

% insert a colon and fix indentation
static define electric_colon()
{
   variable indent;
   insert(":");
   push_spot();
   if (line_starts_subblock())  % else:, elif:, except:, finally:
     {
	bol_skip_white();
	indent = calculate_indent();
	if (indent < what_column()) % Ensure dedent only
	  py_indent_line(indent); % use already calculated value
     }
   pop_spot();
}

% TODO: what is the sens of an electric delim?.
% TODO: complains about spurious mismatches when fixing them.
static define electric_delim(ch)
{
   insert(char(ch));
   push_spot();
   py_indent_line();
   pop_spot();
   blink_match();
}

% Run python code
% ---------------

% search back for a Python error message and return file and line number
% return "" and 0 if no error found.
static define parse_error_message()
{
   variable file = "", line = 0;
   variable error_regexp = "^ *File \"\\([^\"]+\\)\", line \\(\\d+\\).*";
   if (re_bsearch(error_regexp) != 0) {
      file = regexp_nth_match(1);
      line = integer(regexp_nth_match(2));
   }
   return file, line;
}

% Search the current buffer backwards for a Python error message,
% open the source file and goto line
static define goto_error_source()
{
   variable file, line;
   eol(); % ... to let the backward search find an error at the current line
   (file, line) = parse_error_message();
   if (file_status(file)) {
      () = find_file(file);
      goto_line(line);
   }
}

% mode for python output
% Return tries to open the file where an error occured
% no need for own keymap, as newline_indent_hook is re-mapped
% TODO: "traditional" compiler output bindings?
public  define python_output_mode()
{
   view_mode();
   set_mode("python-output", 0);
   % navigating
   set_buffer_hook("newline_indent_hook", "python->goto_error_source");
   define_blocal_var("context_help_hook", "python_context_help_hook");
   if (is_defined("help_2click_hook"))
     set_buffer_hook( "mouse_2click", "help_2click_hook");
}


%!%+
%\function{py_exec}
%\synopsis{Run python on current region or buffer}
%\usage{py_exec(cmd="python")}
%\description
% Run python interpreter on current region or the whole buffer.
% Display output in *python output* buffer window.
% Parse for errors and goto foulty line.
%\seealso{python_shell}
%!%-
public  define py_exec() % (cmd="python")
{
   variable cmd = push_defaults("python", _NARGS);
   variable buf = whatbuf(), py_source = buffer_filename();
   variable outbuf = sprintf("*%s output*", cmd);
   variable exception_file, line, start_line = 1;

   % remove old output buffer
   if (bufferp(outbuf))
     delbuf(outbuf);

   if (is_visible_mark())
     {
		check_region(0);
		exchange_point_and_mark();
		start_line = what_line();
		% % Workaround in case block is indented
		% bol_skip_white();
		% if (what_column() > 1)
		%   {
		%      insert "if True:\n"
		%      start_line--;   % offset for this extra line
		%   }
		exchange_point_and_mark();
     }

   shell_cmd_on_region_or_buffer(cmd, outbuf);

   % no output? we are done
   if (buf == whatbuf())
     return;

   python_output_mode();

   % Check for error message
   eob();
   do {
      (exception_file, line) = parse_error_message();
   }
   while (exception_file != py_source and line != 0);

   pop2buf(buf);

   % Move to line in source that generated the error
   if (exception_file == py_source)
     {
	goto_line(line + start_line - 1);
     }
}

% output filter for use with ishell-mode
static define python_output_filter(str)
{
   % Remove the "poor man's bold" in python helptexts
   str = str_re_replace_all(str, ".", "");
   % Append a newline to the prompt if output goes to separate buffer
   if (str == ">>> "
       and get_blocal_var("Ishell_Handle").output_placement == "o")
      str += "\n";
   return str;
}

public define python_shell()
{
   define_blocal_var("Ishell_output_filter", &python_output_filter);
   define_blocal_var("Ishell_Wait", 10);  % wait up to 1 s/line for response
   ishell_mode("python");
   ishell_set_output_placement("l"); % log in separate-buffer
}


% Python help
% -----------

#ifdef MSWINDOWS
define py_help_on_word()
{
   variable tag = "0-9A-Z_a-z";

   push_spot();
   skip_white();
   bskip_chars(tag);
   push_mark();
   skip_chars(tag);
   tag = bufsubstr();		% leave on the stack
   pop_spot();
   message( strcat("Help on ", tag) );
   msw_help( getenv("PYLIBREF"), tag, 0);
}

#else
static define browse_pydoc_server()
{
   flush("starting Python Documentation Server");
   variable result = system("pydoc -p 1200 &");
   % sleep(0.5);
   browse_url("http://localhost:1200");
}

#endif

% find lines with global imports (import ... and  from ... import ...)
% (needed for python help on imported objects)
static define get_import_lines()
{
   variable tag, import_lines="", case_search_before=CASE_SEARCH;
   CASE_SEARCH = 1;  % python keywords are case sensitive
   foreach tag (["import", "from"]) {
      push_spot_bob();
      while (bol_fsearch(tag)) {
	 if (ffind("__future__")) {
	    eol();
	    continue;
	 }
	 !if (ffind("import")) {
	    eol();
	    continue;
	 }
	 if (in_literal_string)
	    continue;
	 do { % get line and continuation lines
	    import_lines += line_as_string()+"\n";
	    go_down_1();
	 }
	 while (is_continuation_line());
	 % while (bskip_white(), blooking_at("\\") and down_1());
      }
      pop_spot();
   }
   CASE_SEARCH = case_search_before;
   !if (import_lines == "") {
      import_lines = sprintf("import sys; sys.path.insert(0, \"%s\")\n",
			     buffer_dirname()) + import_lines;
   }
   return import_lines;
}

% mode for python help output
% no need for own keymap, as newline_indent_hook is re-mapped to bind Return
public  define python_help_mode()
{
   view_mode();
   set_mode("python-help", 0);
   % navigating
   set_buffer_hook("newline_indent_hook", "python_context_help_hook");
   define_blocal_var("context_help_hook", "python_context_help_hook");
   if (is_defined("help_2click_hook"))
     set_buffer_hook( "mouse_2click", "help_2click_hook");
}

%!%+
%\function{py_help}
%\synopsis{Run python's help feature on topic}
%\usage{Void py_help([String topic])}
%\description
%   Uses pythons own 'help' command to display a help text in a separate
%   window. If \var{topic} is not given, ask in the minibuffer.
%\notes
%   Only tested on UNIX
%\seealso{py_mode}
%!%-
public define py_help() %(topic=NULL)
{
   % get optional argument or ask
   !if (_NARGS)
     read_mini("Python Help for: ", "", "");
   variable topic = ();

   variable str, module, object_list, help_cmd;

   % % if interactive session is open, use it:
   % if (is_substr(get_mode_name(), "ishell"))
   %   {
   % 	variable handle = get_blocal_var("Ishell_Handle");
   % 	send_process(handle.id, sprintf("help(%s)\n", topic));
   % 	return;
   %   }

   % % prepend imported module + "." to names in a line like
   % %    from module import name, name2, name3
   % push_spot_bob();
   % while (bol_fsearch("from"), dup)
   %   {
   % 	go_right(()+1);
   % 	module = get_word("A-Za-z0-9_.");
   % 	go_right(ffind("import"));
   % 	push_mark_eol();
   % 	while (blooking_at("\\"))
   % 	  {
   % 	     go_down_1();
   % 	     eol();
   % 	  }
   % 	object_list = bufsubstr();
   % 	object_list = strchop(object_list, ',', 0);
   % 	object_list = array_map(String_Type, &strtrim, object_list, " \t\r\n\\");
   % 	if (length(where(object_list == topic)))
   % 	  topic = module + "." + topic;
   %   }
   % pop_spot();

   help_cmd = sprintf("python -c '%shelp(\"%s\")'",
	  get_import_lines(), topic);
   % show(help_cmd);
   popup_buffer("*python-help*");
   set_readonly(0);
   erase_buffer();

   set_prefix_argument(1);      % insert output at point
   % show(help_cmd);
   flush("Calling: " + help_cmd);
   do_shell_cmd(help_cmd);

   fit_window(get_blocal("is_popup", 0));
   python_help_mode();
}

% context help:
public  define python_context_help_hook()
{
   py_help(bget_word("A-Za-z0-9_."));
}

% we need a special help for word hook that includes the . in word_chars
static define python_help_for_word_hook(word)
{
   python_context_help_hook();
}

% Browse the html documentation for a specific module
public define py_browse_module_doc() % (module=NULL)
{
   variable module = push_defaults( , _NARGS);
   variable lib_doc_dir = path_concat(Python_Doc_Root, "library");
   if (module == NULL)
     module = read_mini("Browse doc for module (empty for index):", "", "");
   if (module == "")
     module = "index.html";
   else
     module = sprintf("%s.html", strlow(module));

   browse_url("file:" + path_concat(lib_doc_dir, module));
}


% Syntax highlighting
% -------------------

create_syntax_table(mode);
define_syntax("#", "", '%', mode);		% comments
define_syntax("([{", ")]}", '(', mode);		% delimiters
define_syntax('\'', '\'', mode);		% quoted strings
define_syntax('"', '"', mode);			% quoted strings
define_syntax('\'', '\'', mode);		% quoted characters
define_syntax('\\', '\\', mode);		% continuations
define_syntax("0-9a-zA-Z_", 'w', mode);		% words
define_syntax("-+0-9a-fA-FjJlLxX.", '0', mode);	% Numbers
define_syntax(",;.:", ',', mode);		% punctuation
define_syntax("%-+/&*=<>|!~^`", '+', mode);	% operators
set_syntax_flags(mode, 0);			% keywords ARE case-sensitive

() = define_keywords(mode, "asifinisor", 2); % all keywords of length 2
() = define_keywords(mode, "anddefdelfornottry", 3); % of length 3 ....
() = define_keywords(mode, "elifelseexecfrompass", 4);
() = define_keywords(mode, "breakclassprintraisewhileyield", 5);
() = define_keywords(mode, "assertexceptglobalimportlambdareturn", 6);
() = define_keywords(mode, "finally", 7);
() = define_keywords(mode, "continue", 8);

% Type 1 keywords (actually these are most of what is in __builtins__)
() = define_keywords_n(mode, "id", 2, 1);
() = define_keywords_n(mode, "abschrcmpdirhexintlenmapmaxminoctordpowstrzip",
   3, 1);
() = define_keywords_n(mode, "NoneTruedictevalfilehashiterlistlongopenrepr"
   + "typevars", 4, 1);
() = define_keywords_n(mode, "Falseapplyfloatinputrangeroundslicetuple", 5, 1);
() = define_keywords_n(mode, "buffercoercedivmodfilterinternlocalsreducereload"
   + "unichrxrange", 6, 1);
() = define_keywords_n(mode, "IOErrorOSError__doc__compilecomplexdelattr"
   + "getattrglobalshasattrsetattrunicode", 7, 1);
() = define_keywords_n(mode, "EOFErrorKeyErrorTabError__name__callable"
   + "execfile", 8, 1);
() = define_keywords_n(mode, "ExceptionNameErrorTypeErrorraw_input", 9, 1);
() = define_keywords_n(mode, "IndexErrorSystemExitValueError__import__"
   + "isinstanceissubclass", 10, 1);
() = define_keywords_n(mode, "ImportErrorLookupErrorMemoryErrorSyntaxError"
   + "SystemError", 11, 1);
() = define_keywords_n(mode, "RuntimeErrorUnicodeError", 12, 1);
() = define_keywords_n(mode, "ConflictErrorOverflowErrorStandardError"
   + "StopIteration", 13, 1);
() = define_keywords_n(mode, "AssertionErrorAttributeErrorReferenceError",
   14, 1);
() = define_keywords_n(mode, "ArithmeticError", 15, 1);
() = define_keywords_n(mode, "EnvironmentError", 16, 1);
() = define_keywords_n(mode, "KeyboardInterruptUnboundLocalError"
   + "ZeroDivisionError", 17, 1);
() = define_keywords_n(mode, "FloatingPointError", 18, 1);
() = define_keywords_n(mode, "NotImplementedError", 19, 1);

#ifdef HAS_DFA_SYNTAX

%%% DFA_CACHE_BEGIN %%%
private define dfa_rule(rule, color)
{
   dfa_define_highlight_rule(rule, color, $1);
}

private define setup_dfa_callback(mode)
{
   % dfa_enable_highlight_cache("pymode.dfa", mode);
   $1 = mode; % used by dfa_rule()

   % Strings
   %% "normal" string literals
   dfa_rule("\"[^\"]*\"", "string");
   dfa_rule("'[^']*'", "string");
   %% "long" string literals
   dfa_rule("\"\"\".+\"\"\"", "Qstring");
   dfa_rule("'''.+'''", "Qstring");
   %% string delimiters of multi-line string
   dfa_rule("\"\"\"|'''", "string");
   % Comments
   dfa_rule("#.*", "comment");
   % Keywords (identifier)
   dfa_rule("[A-Za-z_][A-Za-z_0-9]*", "Knormal");
   % Delimiters and operators
   dfa_rule("[\(\[{}\]\),:\.\"`'=;]"R, "delimiter");
   dfa_rule("[\+\-\*/%<>&\|\^~]"R, "operator");  % 1 char
   dfa_rule("<<|>>|==|<=|>=|<>|!=", "operator"); % 2 char
   dfa_rule("\\$"R, "operator");    		 % line continuation
   %% Flag line continuation with trailing whitespace
   dfa_rule("\\[ \t]+$"R, "Qtrailing_whitespace");
   % Numbers
   dfa_rule("[1-9][0-9]*[lLjJ]?", "number"); % decimal int/complex
   dfa_rule("0[0-7]*[lL]?", "number"); % octal int
   dfa_rule("0[xX][0-9a-fA-F]+[lL]?", "number");	% hex int
   dfa_rule("[1-9][0-9]*\.?[0-9]*([Ee][\+\-]?[0-9]+)?[jJ]?"R, "number"); % float/complex n.[n]
   dfa_rule("0?\.[0-9]+([Ee][\+\-]?[0-9]+)?[jJ]?"R, "number"); % float/complex n.[n]
   %% Flag badly formed numeric literals or identifiers.
   %% This is more effective if you change the error colors so they stand out.
   dfa_rule("[1-9][0-9]*[lL]?[0-9A-Za-z\.]+"R, "error");	% bad decimal
   dfa_rule("0[0-7]+[lL]?[0-9A-Za-z\.]+"R, "error"); % bad octal
   dfa_rule("0[xX][0-9a-fA-F]+[lL]?[0-9A-Za-z\.]+"R, "error"); % bad hex
   dfa_rule("\.[0-9]+([Ee][\+\-]?[0-9]+)?[A-Za-z]+"R, "error"); % bad float
   dfa_rule("[A-Za-z_][A-Za-z_0-9]*\.[0-9]+[A-Za-z]*"R, "error"); % bad identifier
   % Whitespace
   dfa_rule(" ", "normal");  % normal whitespace
   dfa_rule("\t", "tab");
   %% Flag mix of Spaces and Tab in code indention
   dfa_rule("^ +\t+[^ \t#]", "menu_selection"); % distinctive background colour
   dfa_rule("^\t+ +[^ \t#]", "menu_selection"); % distinctive background colour
   % Render non-ASCII chars as normal to fix a bug with high-bit chars in UTF-8
   dfa_rule("[^ -~]+", "normal");

   dfa_build_highlight_table(mode);
}
dfa_set_init_callback(&setup_dfa_callback, "python");
%%% DFA_CACHE_END %%%
#endif

static define set_highlight_scheme()
{
   if (_NARGS)
      Python_Use_DFA = ();
   else
      Python_Use_DFA = not(Python_Use_DFA);
   variable schemes = ["DFA", "traditional"];
   mode_set_mode_info (mode, "use_dfa_syntax", Python_Use_DFA);
   use_syntax_table("python"); % activate the DFA/non-DFA syntax
   vmessage("using %s highlight scheme", schemes[not(Python_Use_DFA)]);
}

% Folding
% -------
%
% by indention
% ~~~~~~~~~~~~
%
% On 21.04.08, John E. Davis wrote:
% > > Is there a possibility to autmatic fold any Python file, like many of
% > > the Python-IDE's do ?
%
% > You might try using the set_selective_display function, which is bound
% > to "Ctrl-X $" in emacs mode.  This will allow you to hide any lines
% > indented beyond the column containing the cursor.
%
% TODO: also hide comments if "#" at bol but comment indented?
%
% by pcre pattern
% ~~~~~~~~~~~~~~~
% see pcre-fold.sl
%
% by rst-section
% ~~~~~~~~~~~~~~
% see rst-fold.sl


% Keybindings
% -----------

!if (keymap_p(mode))
  make_keymap(mode);

definekey_reserved("py_shift_right", ">", mode);
definekey_reserved("py_shift_left", "<", mode);
definekey_reserved("set_selective_display", "f", mode);

definekey_reserved("py_exec", "^C", mode);    % Execute buffer, or region if defined

definekey("python->py_backspace_key", Key_BS, mode);
definekey("python->electric_colon", ":", mode);
% These work, but act a bit odd when rebalancing delimiters from the inside.
% Clues?
%definekey("python->electric_delim(')')", ")", mode);
%definekey("python->electric_delim(']')", "]", mode);
%definekey("python->electric_delim('}')", "}", mode);
#ifdef MSWINDOWS
definekey("py_help_on_word", "^@;", mode);
#endif

% --- the mode dependend menu
static define python_menu(menu)
{
   menu_append_item(menu, "Shift line|region &left", "py_shift_left");
   menu_append_item(menu, "Shift line|region &right", "py_shift_right");
   menu_append_separator(menu);
   menu_append_item(menu, "&Check indentation", "py_check_indentation");
   menu_append_item(menu, "Re&indent buffer|region", "py_reindent");
   menu_append_item(menu, "Reindent &block|region", "python->reindent_block");
   menu_append_item(menu, "&Untab buffer", "py_untab");
   menu_append_item(menu, "&Toggle syntax highlight scheme",
		    	  "python->set_highlight_scheme");
   menu_append_separator(menu);
   menu_append_item(menu, "&Fold by indentation", "set_selective_display");
   menu_append_separator(menu);
   menu_append_item(menu, "&Run Buffer", &run_local_hook, "run_buffer_hook");
   menu_append_item(menu, "Python &Shell", "python_shell");
   menu_append_separator(menu);
   menu_append_item(menu, "Python &Help", "py_help");
   menu_append_item(menu, "Python &Documentation Server",
      			  "python->browse_pydoc_server");
   menu_append_item(menu, "Browse Python &Module Doc", "py_browse_module_doc");
}

%!%+
%\function{python_mode}
%\synopsis{Mode for editing Python files.}
%\usage{Void python_mode()}
%\description
% A major mode for editing scripts written in Python (www.python.org).
%
% The following keys have python specific bindings:
% (assuming \var{_Reserved_Key_Prefix} == "^C")
%#v+
% Key_BS      deletes to previous indentation level if the
% 	      point is at the first non-white character of a line
% : (colon)   dedents appropriately
% ^C>         shifts line or region right
% ^C<         shifts line or region left
% ^C^C        executes the region, or the buffer if region not marked.
% ^C|         executes the region
%#v-
%\seealso{Py_Indent_Level, python_mode_hook, py_reindent, py_untab}
%!%-
public define python_mode()
{
   set_mode(mode, 0x4); % flag value of 4 is generic language mode
   use_keymap(mode);
   use_syntax_table(mode);
   C_BRA_NEWLINE = 0;
   set_buffer_hook("indent_hook", "py_indent_line");
   define_blocal_var("help_for_word_hook", "py_help_for_word_hook");
   mode_set_mode_info("run_buffer_hook", "py_exec");
   mode_set_mode_info(mode, "init_mode_menu", &python_menu);
   % set_buffer_hook("newline_indent_hook", "py_newline_and_indent");
   set_highlight_scheme(Python_Use_DFA);
   run_mode_hooks("python_mode_hook");
}

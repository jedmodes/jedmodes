% Python mode
% File: pymode.sl v1.4.1
%
% For editing source code written in the Python programming language.
% Provides basic compatibility with Python mode under real Emacs
%
% Authors: Harri Pasanen <hpa@iki.fi>
%          Brien Barton <brien_barton@hotmail.com>
%
% The following keys have python specific bindings:
%
% Backspace   deletes to previous indent level
% : (colon)   dedents appropriately
% (the next assume _Reserved_Key_Prefix == "^C")
% ^C#         comments region or current line
% ^C>         shifts line or region right
% ^C<         shifts line or region left
% ^C^C        executes the region, or the buffer if region not marked.
% ^C|         executes the region
%
% See python_mode function for available hooks
%
% Shortcomings: does not support triple-quoted strings well. It works
% OK with """ but NOT with '''.

% Changes from v1.0:
%
% Major improvements, mostly done by Brien Barton:
%
% - execution of python code from JED
% - DFA syntax support
% - improved indent - dedent.

% Changes from v1.1:
%
% Minor fixes, by Tom Culliton
%
% - corrected a syntax error
% - fixed non-DFA syntax hilighting tables to work better
% - added the new assert keyword

% Changes from v1.2:
%
% - autoindent correction

% Changes from v1.3:
%
% - Better indenting of function arguments and tuples
% - New keywords and builtins added (TJC)
% - An attempt to do pretty indenting of data structures and parameter lists
% - Try to keep the lines under 80 columns and make formatting consistent

% Changes from v1.4:
% (JED)
% - discard return value from run_shell_cmd
% - avoid use of create_array and explicit loop for initializing it.
% (Guenter Milde)
% - detect use of Tabs or Spaces for indentation
%   - new functions py_walk_indented_code_lines(), py_is_continuation_line()
% - py_reindent() now honours continuation lines
% - declared python_mode explicitely a public function
% - new function python_help (needs the pydoc module)
% - interactive python session with ishell
% - py_line_starts_block(), py_line_starts_subblock(), py_endblock_cmd():
%   fix false positives with lines starting with e.g. "passport" (words that
%   start with a keyword). (modified patch by Peter Bengtson and Jörg Sommer)
% - use indent_hook instead of \t binding
% - various small twiddles

provide("pymode");

% utilities from http://jedmodes.sf.net/
autoload("popup_buffer", "bufutils");
autoload("get_blocal", "sl_utils");
autoload("ishell_mode", "ishell");
autoload("ishell_set_output_placement", "ishell");
autoload("ishell_send_input", "ishell");
autoload("shell_cmd_on_region_or_buffer", "ishell");
autoload("shell_command", "ishell");
autoload("strwrap", "strutils");
autoload("str_re_replace_all", "strutils");
autoload("get_word", "txtutils");
autoload("bget_word", "txtutils");
autoload("untab_buffer", "bufutils");

% Custom variables and settings
% -----------------------------

% Set the following to your favourite indentation level
custom_variable("Py_Indent_Level", 4);

%!%+
%\variable{Py_Use_Tabs}
%\synopsis{Use Tabs for code indention?}
%\usage{variable Py_Use_Tabs = 0}
%\description
% Use Tabs for code indention:
%   -3 never       Use Spaces, convert existing files without asking
%   -2 no          Use Spaces, ask for conversion to Spaces in case of Tab-use
%   -1 not really  Use Spaces except when existing buffer uses Tabs
%                  in case of mixed use, convert to Spaces without asking
%    0 rather not  Use Spaces except when existing buffer uses Tabs
%      	      	   in case of mixed use, ask for conversion to Spaces 
%    1 rather yes  Use Tabs, except if existing buffer uses Spaces,
%                  in case of mixed use, ask for conversion to Tabs
%    2 yes please  Use Tabs, except if existing buffer uses Spaces,
%                  in case of mixed use, convert to Tabs without asking
%    3 yes         Use Tabs, ask for conversion to Tabs in case of Space-use
%    4 always 	   Use Tabs, convert existing files without asking
%\seealso{Py_Indent_Level, py_guess_tab_use, py_untab}
%!%-
custom_variable("Py_Use_Tabs", 0);

private variable mode = "python";

!if (keymap_p (mode))
  make_keymap (mode);

definekey_reserved ("py_shift_right", ">", mode);
definekey_reserved ("py_shift_left", "<", mode);
definekey_reserved ("py_exec", "^C", mode);    % Execute buffer, or region if defined

definekey ("py_backspace_key", Key_BS, mode);
definekey ("py_electric_colon", ":", mode);
% These work, but act a bit odd when rebalancing delimiters from the inside.
% Clues?
%definekey ("py_electric_paren", ")", mode);
%definekey ("py_electric_square", "]", mode);
%definekey ("py_electric_curly", "}", mode);
#ifdef MSWINDOWS
definekey ("py_help_on_word", "^@;", mode);
#endif

static define py_line_ends_with_colon()
{
   eol();
   if (bfind_char(':')) {
      go_right(1);
      skip_white();
      if (eolp() or looking_at_char('#'))
	return 1;
   }
   return 0;
}

% is the current line the last of a block? (should the next line unindent?)
% TODO: do we want empty lines to mark a block-end????
static define py_endblock_cmd()
{
   if (bolp() and eolp())           % empty line (not even whitespace)
     return 1;
   bol_skip_white();
   return is_list_element("return,raise,break,pass,continue",
      	  		  get_word(), ',');
}

static define py_line_starts_subblock()
{
   bol_skip_white();
   return is_list_element("else,elif,except,finally", get_word(), ',');
}

static define py_line_starts_block()
{
   bol_skip_white();
   return (is_list_element("if,try", get_word(), ',')
      	   or py_line_starts_subblock());
}

static define py_find_matching_delimiter_col()
{
   variable col = -1;
   variable line = -1;
   variable delim, closest_delim, fnd_col, fnd_line;

   push_spot ();
   foreach (")]}") {
      delim = ();
      bol ();
      if (1 == find_matching_delimiter (delim)) {
         fnd_col = what_column ();
         fnd_line = what_line ();
         if (fnd_line > line or (fnd_line == line and fnd_col > col)) {
            line = fnd_line;
            col = fnd_col;
            closest_delim = delim;
         }
      }
      goto_spot ();
   }
   goto_spot ();
   bol_skip_white ();
   if (0 <= col)
      if (looking_at_char(closest_delim))
         col -= 1;
   pop_spot ();
   return col;
}

static define py_indent_calculate()
{  % return the indentation of the previous python line
   variable col;
   variable subblock = 0;

   col = py_find_matching_delimiter_col();
   if (col >= 0)
     return col;

   push_spot();
   % check if current line starts a sub-block
   subblock = py_line_starts_subblock();
   % go to previous line
   go_up_1();
   bol_skip_white();
   col = what_column() - 1;

   if (py_line_ends_with_colon())
      col += Py_Indent_Level;
   if (py_endblock_cmd() or (subblock and not py_line_starts_block()))
      col -= Py_Indent_Level;
   pop_spot();
   return col;
}

define py_indent_line()
{
   variable col = py_indent_calculate();
   bol_trim();
   whitespace(col);
}

define py_electric_colon()
{
   insert(":");
   push_spot();
   if (py_line_starts_subblock())  % else:, elif:, except:, finally:
     {
	bol_skip_white();
	if (py_indent_calculate() < what_column()) % Ensure dedent only
	  py_indent_line();
     }
   pop_spot();
}

% These next four complain about about spurious mismatches when fixing them.
static define py_electric_delim(delim)
{
    insert(delim);
    push_spot();
    py_indent_line();
    pop_spot();
    blink_match();
}

define py_electric_paren()
{
    py_electric_delim(")");
}

define py_electric_square()
{
    py_electric_delim("]");
}

define py_electric_curly()
{
    py_electric_delim("}");
}

%!%+
%\function{py_shift_line_right}
%\synopsis{Increase the indentation level of the current line}
%\usage{Void py_shift_line_right()}
%\description
%  Increase the indentation of the current line by \var{Py_Indent_Level}
%  columns.
%
%  If a \sfun{prefix_argument} is set, indent the number of levels
%  given in the prefix argument.
%\seealso{py_shift_right, py_shift_region_right, py_shift_left, set_prefix_argument}
%!%-
define py_shift_line_right()
{
   bol_skip_white();
   loop (prefix_argument(1))
     whitespace(Py_Indent_Level);
}

%!%+
%\function{py_shift_region_right}
%\synopsis{Increase the indentation level of the region}
%\usage{Void py_shift_region_right()}
%\description
%  Call \sfun{py_shift_line_right} for all lines in the current region.
%
%  If a \sfun{prefix_argument} is set, indent the number of levels
%  given in the prefix argument.
%\seealso{py_shift_rigth, py_shift_left, set_prefix_argument}
%!%-
define py_shift_region_right()
{
   variable n;
   variable times = prefix_argument(1);
   check_region(1);		       %  spot_pushed, now at end of region
   n = what_line();
   pop_mark_1();
   loop (n - what_line ())
     {
	set_prefix_argument(times);
	py_shift_line_right();
	go_down_1();
     }
   pop_spot();
}

%!%+
%\function{py_shift_right}
%\synopsis{Increase code indentation level}
%\usage{py_shift_right()}
%\description
%  Increase the indentation level of the current line or (visible) region
%  (by \var{Py_Indent_Level} columns).
%
%  If a \sfun{prefix_argument} is set, indent the number of levels
%  given in the prefix argument.
%\example
%  With default emacs keybindings,
%#v+
%     ESC 4  Ctrl-C >
%#v-
%  will indent the line or region by 4 * \var{Py_Indent_Level}.
%\notes
%  Calls \sfun{py_shift_line_right} or \sfun{py_shift_region_right},
%  depending on the outcome of \sfun{is_visible_mark}.
%\seealso{py_shift_left, set_prefix_argument}
%!%-
define py_shift_right()
{
   push_spot();
   if (is_visible_mark()) {
      py_shift_region_right();
   } else {
      py_shift_line_right();
   }
   pop_spot();
}

define py_shift_line_left()
{
   variable times = prefix_argument(1);
   bol_skip_white();
   if (what_column() < times * Py_Indent_Level)
     verror("Line is less than %d columns indented", times * Py_Indent_Level);
   push_mark();
   goto_column(what_column() - times * Py_Indent_Level);
   del_region();
}

define py_shift_region_left()
{
   variable n, times = prefix_argument(1);

   check_region (1);
   n = what_line ();
   pop_mark_1 ();
   loop (n - what_line ())
     {
	set_prefix_argument(times);
	py_shift_line_left();
	go_down_1 ();
     }
   pop_spot();
}

%!%+
%\function{py_shift__left}
%\synopsis{Decrease code indentation level}
%\usage{py_shift_left()}
%\description
%  Decrease the indentation level of the current line or (visible) region
%  (by \var{Py_Indent_Level} columns).
%
%  If a \sfun{prefix_argument} is set, unindent the number of levels
%  given in the prefix argument.
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
define py_shift_left() {
   push_spot();
   if (is_visible_mark()) {
      py_shift_region_left();
   } else {
      py_shift_line_left();
   }
   pop_spot();
}

% shift line right if we are at the first non-white space in an indented
% line,  normal action else
define py_backspace_key()
{
   variable col;

   col = what_column();
   push_spot();
   bskip_white();
   if (bolp() and (col > 1)) {
      pop_spot();
      py_shift_line_left();
     }
   else {
      pop_spot();
      call("backward_delete_char_untabify");
   }
}

% Run python interpreter on current region or the whole buffer.
% Display output in *python-output* buffer window.
define py_exec()
{
   variable thisbuf = whatbuf(), outbuf = "*python-output*";
   variable error_regexp = "^  File \"\\([^\"]+\\)\", line \\(\\d+\\).*";
   variable file, line, start_line = 1, py_source = buffer_filename();

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
   shell_cmd_on_region_or_buffer("python", outbuf);

   %  Check for error message
   eob();
   while (re_bsearch(error_regexp) != 0) {
      %  Make sure error occurred in the file we were executing
      file = regexp_nth_match(1);
      line = integer(regexp_nth_match(2));
      if (file == py_source)
	{
	    %  Move to line in source that generated the error
	    pop2buf(thisbuf);
	    goto_line(line + start_line - 1);
	    return;
	}
   }
   pop2buf(thisbuf);
}

#ifdef MSWINDOWS
define py_help_on_word()
{
   variable tag = "0-9A-Z_a-z";

   push_spot ();
   skip_white ();
   bskip_chars (tag);
   push_mark ();
   skip_chars (tag);
   tag = bufsubstr ();		% leave on the stack
   pop_spot ();
   message( strcat("Help on ", tag) );
   msw_help( getenv("PYLIBREF"), tag, 0);
}

#endif

create_syntax_table (mode);
define_syntax ("#", "", '%', mode);		% comments
define_syntax ("([{", ")]}", '(', mode);		% delimiters
define_syntax ('\'', '\'', mode);			% quoted strings
define_syntax ('"', '"', mode);			% quoted strings
define_syntax ('\'', '\'', mode);			% quoted characters
define_syntax ('\\', '\\', mode);			% continuations
define_syntax ("0-9a-zA-Z_", 'w', mode);		% words
define_syntax ("-+0-9a-fA-FjJlLxX.", '0', mode);	% Numbers
define_syntax (",;.:", ',', mode);		% punctuation
define_syntax ("%-+/&*=<>|!~^`", '+', mode);	% operators
set_syntax_flags (mode, 0);			% keywords ARE case-sensitive

() = define_keywords (mode, "asifinisor", 2); % all keywords of length 2
() = define_keywords (mode, "anddefdelfornottry", 3); % of length 3 ....
() = define_keywords (mode, "elifelseexecfrompass", 4);
() = define_keywords (mode, "breakclassprintraisewhileyield", 5);
() = define_keywords (mode, "assertexceptglobalimportlambdareturn", 6);
() = define_keywords (mode, "finally", 7);
() = define_keywords (mode, "continue", 8);

% Type 1 keywords (actually these are most of what is in __builtins__)
() = define_keywords_n (mode, "id", 2, 1);
() = define_keywords_n (mode, "abschrcmpdirhexintlenmapmaxminoctordpowstrzip",
                        3, 1);
() = define_keywords_n (mode, "Nonedictevalfilehashiterlistlongopenreprtypevars",
                        4, 1);
() = define_keywords_n (mode, "applyfloatinputrangeroundslicetuple", 5, 1);
() = define_keywords_n (mode, "buffercoercedivmodfilterinternlocalsreducereload"
                          + "unichrxrange",
                        6, 1);
() = define_keywords_n (mode, "IOErrorOSError__doc__compilecomplexdelattr"
                          + "getattrglobalshasattrsetattrunicode",
                        7, 1);
() = define_keywords_n (mode, "EOFErrorKeyErrorTabError__name__callable"
                          + "execfile",
                        8, 1);
() = define_keywords_n (mode, "ExceptionNameErrorTypeErrorraw_input", 9, 1);
() = define_keywords_n (mode, "IndexErrorSystemExitValueError__import__"
                          + "isinstanceissubclass",
                        10, 1);
() = define_keywords_n (mode, "ImportErrorLookupErrorMemoryErrorSyntaxError"
                          + "SystemError",
                        11, 1);
() = define_keywords_n (mode, "RuntimeErrorUnicodeError", 12, 1);
() = define_keywords_n (mode, "ConflictErrorOverflowErrorStandardError", 13, 1);
() = define_keywords_n (mode, "AssertionErrorAttributeErrorReferenceError",
                        14, 1);
() = define_keywords_n (mode, "ArithmeticError", 15, 1);
() = define_keywords_n (mode, "EnvironmentError", 16, 1);
() = define_keywords_n (mode, "KeyboardInterruptUnboundLocalError"
                          + "ZeroDivisionError",
                        17, 1);
() = define_keywords_n (mode, "FloatingPointError", 18, 1);
() = define_keywords_n (mode, "NotImplementedError", 19, 1);

#ifdef HAS_DFA_SYNTAX
%%% DFA_CACHE_BEGIN %%%
static define setup_dfa_callback (mode)
{
   % dfa_enable_highlight_cache("python.dfa", mode);
   dfa_define_highlight_rule("\"\"\".+\"\"\"", "string", mode);	% long string (""")
   dfa_define_highlight_rule("'''.+'''", "string", mode);	% long string (''')
   dfa_define_highlight_rule("\"[^\"]*\"", "string", mode);	% normal string
   dfa_define_highlight_rule("'[^']*'", "string", mode);		% normal string
   dfa_define_highlight_rule("#.*", "comment", mode);		% comment
   dfa_define_highlight_rule("[A-Za-z_][A-Za-z_0-9]*", "Knormal", mode); % identifier
   dfa_define_highlight_rule("[1-9][0-9]*[lL]?", "number", mode);	% decimal int
   dfa_define_highlight_rule("0[0-7]*[lL]?", "number", mode);		% octal int
   dfa_define_highlight_rule("0[xX][0-9a-fA-F]+[lL]?", "number", mode);	% hex int
   dfa_define_highlight_rule("[1-9][0-9]*\\.[0-9]*([Ee][\\+\\-]?[0-9]+)?",
			 "number", mode);				% float n.[n]
   dfa_define_highlight_rule("0?\\.[0-9]+([Ee][\\+\\-]?[0-9]+)?",
			 "number", mode);				% float [n].n
   dfa_define_highlight_rule("[ \t]+", "normal", mode);
   dfa_define_highlight_rule("[\\(\\[{}\\]\\),:\\.\"`'=;]", "delimiter", mode);
   dfa_define_highlight_rule("[\\+\\-\\*/%<>&\\|\\^~]", "operator", mode); % 1 char
   dfa_define_highlight_rule("<<|>>|==|<=|>=|<>|!=", "operator", mode);	  % 2 char

   % Flag badly formed numeric literals or identifiers.  This is more effective
   % if you change the error colors so they stand out.
   dfa_define_highlight_rule("[1-9][0-9]*[lL]?[0-9A-Za-z\\.]+", "error", mode);	% bad decimal
   dfa_define_highlight_rule("0[0-7]+[lL]?[0-9A-Za-z\\.]+", "error", mode); % bad octal
   dfa_define_highlight_rule("0[xX][0-9a-fA-F]+[lL]?[0-9A-Za-z\\.]+", "error", mode); % bad hex
   dfa_define_highlight_rule("\\.[0-9]+([Ee][\\+\\-]?[0-9]+)?[A-Za-z]+", "error", mode);	% bad float
   dfa_define_highlight_rule("[A-Za-z_][A-Za-z_0-9]*\\.[0-9]+[A-Za-z]*", "error", mode); % bad identifier
   % Flag mix of Spaces and Tab in code indention
   dfa_define_highlight_rule("^ +\t+[^ \t#]", "error", mode);
   dfa_define_highlight_rule("^\t+ +[^ \t#]", "error", mode);
   dfa_build_highlight_table(mode);
}
dfa_set_init_callback (&setup_dfa_callback, mode);
%%% DFA_CACHE_END %%%
enable_dfa_syntax_for_mode(mode);
#endif

% ------------------- GM additions -----------------------------------

% find lines with global imports (import ... and  from ... import ...)
define py_get_import_lines()
{
   variable tag, import_lines="";
   foreach (["import", "from"])
     {
	tag = ();
	push_spot_bob();
	while (bol_fsearch(tag))
	  {
	     if (ffind("import"))
	       forever % look for continuations
	       {
		  import_lines += line_as_string()+"\n";
		  bskip_white();
		  !if (blooking_at("\\"))
		    break;
		  go_down_1();
	       }
	     else
	       eol();
	  }
	pop_spot();
     }
   return import_lines;
}

%!%+
%\function{py_help}
%\synopsis{Run python's help feature on topic}
%\usage{ Void py_help([String topic])}
%\description
%   Call python help on topic and display the help text in a window.
%   If the topic is not given, ask in the minibuffer.
%\notes
%   Only tested on UNIX
%\seealso{py_mode}
%!%-
define py_help() %([topic])
{
   % get optional argument or ask
   variable topic;
   if (_NARGS)
     topic = ();
   else
     topic = read_mini("Python Help for: ", "", "");

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

   help_cmd = sprintf("python -c \"%shelp('%s')\"",
		      py_get_import_lines(), topic);
   popup_buffer("*Python help*");
   set_readonly(0);
   erase_buffer();

   set_prefix_argument (1);      % insert output at point
   % show(help_cmd);
   flush("Calling: " + help_cmd);
   shell_command(help_cmd);

   fit_window(get_blocal("is_popup", 0));
   view_mode();
   define_blocal_var("help_for_word_hook", "py_help_for_word_hook");
   if (is_defined("help_2click_hook"))
     set_buffer_hook ( "mouse_2click", "help_2click_hook");
}

% we need a special help for word hook that includes the . in word_chars
define py_help_for_word_hook(word)
{
   py_help(bget_word("A-Za-z0-9_."));
}

% Browse the html documentation for a specific module
define py_browse_module_doc() % (module=NULL)
{
   variable module = push_defaults( , _NARGS);
   if (module == NULL)
     module = read_mini("Browse doc for module", "", "");
   browse_url(sprintf("file:/usr/share/doc/python/html/lib/module-%s.html",
      module));
}

% output filter for use with ishell-mode
% insert a newline after main prompt...
static define python_output_filter(str)
{
   if (str == ">>> ")
     str = "\n" + str;
   % Remove the "poor man's bold" in python helptexts
   if (is_substr(str, ""))
      str = str_re_replace_all(str, ".", "");
   return str;
}

public define python_shell()
{
   define_blocal_var("Ishell_output_filter", &python_output_filter);
   ishell_mode("python");
   ishell_set_output_placement("o"); % separate-buffer
}

% Indentation
% -----------

% test for continuation lines (after \, inside """ """, (), [], and {})
% TODO: also consider ''' ''' multiline strings
define py_is_continuation_line()
{
   variable delim, line = what_line(), col, in_string = 0;

   push_spot();
   EXIT_BLOCK { pop_spot(); }

   % explicit (previous line ending in \)
   !if (up_1())
     return 0;  % first line cannot be a continuation
   eol(); go_left_1();
   if (looking_at_char('\\') and (parse_to_point() != -2)) % not in comment
     return 1;

   % multi-line string: test for balance of """ """
   goto_spot();
   bol();
   while (bsearch("\"\"\""))
     {
	if (parse_to_point() != -2)
	  in_string = not(in_string);
     }
   if (in_string)
     return 1;
   % parentheses, brackets and braces
   foreach (")]}")
     {
	delim = ();
	goto_spot();
	bol();
	if (find_matching_delimiter(delim) == 1) % goto (, [, or {
	  col = what_column();
	else
	  continue;
	switch (find_matching_delimiter(0))     % goto ), ], or }
	  { case 0: return col; }     		% unbalanced
	  { case 1 and (what_line() >= line): return col; } % spans current line
	  { continue; }
     }
   return 0;  % test negative
}

% goto the next indented code line (use for detection, reindent,  fixing)
static define goto_next_indented_code_line(skip_continuations)
{
   while (down_1)
     {
	bol_skip_white();
	if (orelse {eolp()}          % empty line
	     {looking_at_char('#')}  % comment
	     {what_column() == 1})   % not indented
	  continue;
	if (andelse{skip_continuations}{py_is_continuation_line()})
	  continue;
	return 1;
     }
   return 0;   % last line
}

% Probe whether code indentation contains Tabs or Spaces
% Argument `ch': '\t' check for Tabs, ' ' check for Spaces
% Return the column of the first find
define py_check_indentation(ch)
{
   % use of spaces in continuation lines is allowed:
   variable skip_continuations = (ch == ' ');
   
   push_spot_bob();
   EXIT_BLOCK { pop_spot(); }

   % search for an occurence of ch in code line indentation
   do
     {
	bol_skip_white();
	if (bfind_char(ch))
	  return what_column();
     }
   while (goto_next_indented_code_line(skip_continuations));
   % not found
   return 0;
}

%!%+
%\function{py_untab}
%\synopsis{Convert tabs to \var{Py_Indent_Level} spaces}
%\usage{py_untab()}
%\description
%  Replace all hard tabs ("\t") with spaces and set \var{TAB} to 0
%\notes
%  Other than \sfun{untab}, \sfun{py_untab} acts on the whole buffer, not on a
%  region.
%\seealso{py_reindent, TAB, untab}
%!%-
define py_untab()
{
   TAB = Py_Indent_Level;
   mark_buffer();
   untab();
   TAB = 0;
   vmessage("Converted all tabs to spaces.");
}

%!%+
%\function{py_reindent}
%\synopsis{Reindent buffer using \var{Py_Indent_Level}}
%\usage{py_reindent()}
%\description
%  Reformat current buffer to consistent indentation levels. using the current
%  relative indentation and the value of \var{Py_Indent_Level}. Abort if the
%  indentation violates the Python syntax.
%\seealso{py_indent_line}
%!%-
define py_reindent()
{
   variable indent_levels = {1};
   variable col, offset;
   bob();
   do
     {
	bol_skip_white();
	col = what_column();
	% indent continuation line by the same amount as previous line
	if (py_is_continuation_line())
	  {
	     offset = col - indent_levels[-1];  % deviation from start line
	     bol_trim();
	     whitespace((length(indent_levels)-1) * Py_Indent_Level + offset);
	     continue;
	  }
	if (col > indent_levels[-1])            % indent
	  list_append(indent_levels, col, -1);
	else
	  while (col < indent_levels[-1]) 	% dedent
	    list_delete(indent_levels, -1);
	% Test if indent is wrong (detent to non-previous level)
	if (col - indent_levels[-1])
	  error("Indention error: detent to non-matching level");
	% not do the real re-indention (TAB determines use of Tabs or Spaces)
	bol_trim();
	whitespace((length(indent_levels)-1) * Py_Indent_Level);
     }
   while (goto_next_indented_code_line(0)); % do not skip continuations
}

% Set TAB according to the value of \var{use_tabs} and the result of
% running \sfun{py_check_indentation} on the buffer
define py_set_tab_use(use_tabs)
{
   variable prompt_mix = "Indentation mixed spaces and tabs. ";
   TAB = 0;
   switch (use_tabs)

     { case -3: % never    Use Spaces, convert existing files without asking
	py_untab();}
     { case -2: % Use Spaces, ask for conversion to Spaces in case of Tab-use
	if (andelse{py_check_indentation('\t')}
	     { get_y_or_n("File uses tabs for indenting code. Untab?")})
	  py_untab();
     }
     { case -1: % Use Spaces except when existing buffer uses Tabs
	    	% in case of mixed use, convert to Spaces without asking
	if (py_check_indentation('\t'))
	  {
	     if (py_check_indentation(' '))
	       {
		  py_untab();
		  message(prompt_mix + MESSAGE_BUFFER);
	       }
	     else
	       TAB = Py_Indent_Level;
	  }
     }
     { case 0: % Use Spaces except when existing buffer uses Tabs
	       % in case of mixed use, ask for conversion to Spaces
	if (py_check_indentation('\t'))
	  {
	     if (andelse{py_check_indentation(' ')}
		  {get_y_or_n(prompt_mix + " Untab?")})
	       py_untab();
	     else
	       TAB = Py_Indent_Level;
	  }
     }
     { case 1: % Use Tabs, except if existing buffer uses Spaces,
       	       % in case of mixed use, ask for conversion to Tabs
	if (py_check_indentation(' '))
	  {
	     if (andelse{py_check_indentation('\t')}
		  {get_y_or_n(prompt_mix + " Reindent with tabs?")})
	       {
		  TAB = Py_Indent_Level;
		  py_reindent();
	       }
	  }
	else
	  TAB = Py_Indent_Level;
     }
     { case 2: % Use Tabs, except if existing buffer uses Spaces,
	       % in case of mixed use, convert to Tabs without asking
	if (py_check_indentation(' '))
	  {
	     if (py_check_indentation('\t'))
	       {
		  TAB = Py_Indent_Level;
		  py_reindent();
		  message(prompt_mix + "Reindented using tabs");
	       }
	  }
	else
	  TAB = Py_Indent_Level;
     }
     { case 3: % Use Tabs, ask for conversion to Tabs in case of Space-use
	if (andelse{py_check_indentation(' ')}
	     { get_y_or_n("File uses spaces for indenting code. Convert to tabs?")}
	   )
	  {
	     TAB = Py_Indent_Level;
	     py_reindent();
	     message("Reindented using tabs");
	  }
	else
	  TAB = Py_Indent_Level;
     }
     { case 4: % Use Tabs, convert existing files without asking
	TAB = Py_Indent_Level;
	if (py_check_indentation(' '))
	  {
	     py_reindent();
	     message("Reindented using tabs");
	  }
     }
}

%!%+
%\function{python_mode}
%\synopsis{Mode for editing Python files.}
%\usage{Void python_mode()}
%\description
% A major mode for editing scripts written in Python (www.python.org).
%
% The following keys have python specific bindings:
%#v+
% Backspace   deletes to previous indentation level
% : (colon)   dedents appropriately
% (the next assume \var{_Reserved_Key_Prefix} == "^C")
% ^C#         comments region or current line
% ^C>         shifts line or region right
% ^C<         shifts line or region left
% ^C^C        executes the region, or the buffer if region not marked.
% ^C|         executes the region
%#v-
%\seealso{Py_Indent_Level, Py_Use_Tabs, py_reindent, py_untab}
%!%-
public define python_mode ()
{
   % indenting code according to "Style Guide for Python Code"
   % (http://www.python.org/dev/peps/pep-0008/)
   set_mode(mode, 0x4); % flag value of 4 is generic language mode
   use_keymap(mode);
   set_buffer_hook("indent_hook", "py_indent_line");
   % set_buffer_hook("newline_indent_hook", "py_newline_and_indent");
   use_syntax_table(mode);
   run_mode_hooks("python_mode_hook");
}

# ifexists test
% test goto_next_indented_code_line()
define py_walk_indented_code_lines() % (skip_ continuations = 1)
{
   variable skip = push_defaults(1, _NARGS);
   do
     {
	message("press any key to walk to next indented code line");
	update(1);
	if (getkey() == 7)  % ^G, the default abort char
	  return;
     }
   while (goto_next_indented_code_line(skip));
   message("last line");
}
#endif

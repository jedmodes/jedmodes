% pymode-test.sl:  Test pymode.sl
% 
% Copyright © 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1 2006-03-03 

require("unittest");

% test availability of public functions (comment to skip)
test_true(is_defined("python_shell"), "public fun python_shell undefined");
test_true(is_defined("python_mode"), "public fun python_mode undefined");

% Fixture
% -------

require("pymode");

private variable testbuf = "*pymode test*";
private variable teststring = strjoin(
   ["import sys",
    "from os.path import dirname, exists, \\",
    "                lexists",
    "# a comment",
    "def unindent(self,",
    "    indent=None):",
    "    \"\"\"Return unindented list of lines",
    "",   
    "    Unindents by the least (or given) indentation level\"\"\"",
    "    if indent is None:",
    "        indent = self.min_indent()",
    "    else:",
    "        indent = 0",
    "    par = [line[indent:] ",
    "           for line in self]",
    "    return PylitParagraph(par)",
    ""
    ], "\n");
% show_string(teststring);

private variable literal_strings__teststring = strjoin(
   ["''' 'in' ''' out",
    "\"\"\" \"in\" \"\"\" out",
    "''' in ",
    "in ''' out",
    "\"\"\" in ",
    "in \"\"\" out",
    "''' in \"\"\" in ''' out",
    "\"\"\" in ",
    "''' in",
    "\"\"\" out ''' in ''' out",
    "' in \"\"\" in \\\' in \" in ' out",
    "\" in ''' in \\\" in ' in \" out",
    "\" ' in",
    "out '''",
    " in \"\"\" in "], "\n");
% show_string(literal_strings__teststring);

static define setup()
{
   sw2buf(testbuf);
   insert(teststring);
}

static define teardown()
{
   sw2buf(testbuf);
   set_buffer_modified_flag(0);
   close_buffer(testbuf);
}

% Test functions
% --------------

% test whether the point is inside a long string literal (""" """ or ''' ''')
% static define in_literal_string()
static define test_in_literal_string()
{
   erase_buffer();
   insert(literal_strings__teststring);
   bob;
   while (fsearch("in"))
     {
        test_true(python->in_literal_string(),
           sprintf("inside string literal: %d %s", 
              what_line, line_as_string()));
        go_right(2);
     }
   bob;
   while (fsearch("out"))
     {
        test_true(not(python->in_literal_string()),
           sprintf("outside string literal: %d %s", 
              what_line, line_as_string()));
        go_right(3);
     }
}

% define py_is_continuation_line()
% recognize continuation lines (after \, inside """ """, (), [], and {})
static define test_py_is_continuation_line()
{
   variable continuation_lines = [3, 6, 8, 9, 15];
   bob();
   do
     {
        % vshow("line %d: continues at %d", 
        %    what_line, py_is_continuation_line());
        if (wherefirst(what_line() == continuation_lines) != NULL)
          test_true(python->is_continuation_line(),
             sprintf("line %d '%s' is a continuation line", 
                what_line(), line_as_string()));
        else
          test_true(not(python->is_continuation_line()),
             sprintf("line %d '%s' is no continuation line", 
                what_line(), line_as_string()));
     }
   while (down_1());
}

static define test_py_is_indented_code_line()
{
   % line-numbers of indented code lines in the teststring
   variable indented_code_lines = [7, 10, 11, 12, 13, 14, 16];
   
   bob();
   do
     {
        % testmessage(sprintf("\n  line %d: continues at %d", 
        %    what_line, python->is_continuation_line()));
        if (wherefirst(what_line() == indented_code_lines) != NULL)
          test_true(python->is_indented_code_line(),
             sprintf("line %d '%s' is an indented_code line", 
                what_line(), line_as_string()));
        else
          test_true(not(python->is_indented_code_line()),
             sprintf("line %d '%s' is no indented_code line", 
                what_line(), line_as_string()));
     }
   while (down_1());
}

% Determine the buffer-local indentation level
% 
% Try the blocal variable "Py_Indent_Level", 
%     the first indented code line, or
%     the global Py_Indent_Level.
% store in blocal variable
static define test_get_indent_level()
{
   test_equal(python->get_indent_level(), 4, "default is 4 spaces");
   goto_line(2);
   insert("\t");
   test_equal(python->get_indent_level(), 4, "value should be cached");
}

static define test_get_indent_level_tab()
{
   goto_line(2);
   insert("\t");
   % () = get_y_or_n("continue");
   test_equal(python->get_indent_level(), 0, "tab use should return 0");
   
}

static define test_get_indent_level_default()
{
   erase_buffer();
   test_equal(python->get_indent_level(), Py_Indent_Level , 
      "should return Py_Indent_Level if there are no indented code lines");
}

% get the width of the expanded indent string (indent_level or TAB)
static define test_get_indent_width()
{
   test_equal(python->get_indent_width(), 4, 
      "should return get_indent_level() if it is > 0");
   define_blocal_var("Py_Indent_Level", 0);
   test_equal(python->get_indent_width(), TAB,
      "should return TAB if indent-level is 0 (tab use)");
}

% static define check_indentation()
% Test whether code indentation mixes tabs and spaces
% Leave point at the first non-white char in the offending line
static define test_check_indentation()
{
   test_equal(' ', python->check_indentation(),
      "false alarm: is there really a tab in '" + line_as_string() + "' ?");
   % tab in continuation line
   goto_line(3); 
   bol();
   insert("\t");
   test_equal(' ', python->check_indentation(),
      "should ignore tab in continuation line");
   % tab in code line
   goto_line(7);
   insert("\t");
   eob();
   test_equal(0, python->check_indentation(),
      "should find tab in indented code line");
   test_equal(what_line(), 7, "should place point in first offending line");
   % convert spaces to tabs:
   bob();
   replace("    ", "\t");
   define_blocal_var("Py_Indent_Level", 0);
   test_equal('\t', python->check_indentation(),
      "false alarm: is there really a space in " + line_as_string());
}

% static define calculate_indent_col()
% Parse last line(s) to estimate the correct indentation for the current line
% 
% Used in py_indent_line, indent_line_hook (for indent_line() and
% newline_and_indent(), and electric_colon()
static define test_calculate_indent()
{
   variable i=1, indent, indents = [0,0,0,0,0,13,4,4,0,4,8,4,8,8,11,4,0];
   
   bob();
   foreach indent (indents)
     {
        test_equal(indent, python->calculate_indent(),
           sprintf("wrong estimate in line %d", i));
        go_down_1();
        i++;
     }
}

% define py_indent_line()
static define test_py_indent_line()
{
   bob();
   % indent by given amount
   py_indent_line(7);
   bol_skip_white();
   test_equal(what_column()-1, 7, "should indent to given amount");
   test_equal(bfind("\t"), 0, 
      "must not use tabs for indentation if indent-level != 0");

   % Indent to calculated column
   % no indent
   py_indent_line();
   bol_skip_white();
   test_equal(what_column()-1, 0, "should remove spurious indentation");
   % indented line (1 level)
   () = fsearch("if indent is None:");
   bol_trim();
   py_indent_line();
   bol_skip_white();
   test_equal(what_column()-1, Py_Indent_Level, "should indent to previous line");
   % more variants are tested via test_calculate_indent_col()
   
   % indent with tabs
   define_blocal_var("Py_Indent_Level", 0);
   py_indent_line(2*TAB);
   bol_skip_white();
   test_equal(what_column()-1, 2*TAB, 
      "should indent to given amount also if using tabs");
   test_equal(bfind(" "), 0, 
      "must not use spaces indentation if indent-level == 0 and width is multiple of TAB");
}


%\function{python->py_shift_line_right}
%Increase the indentation level of the current line
static define test_py_shift_line_right()
{
   % define_blocal_var("Py_Indent_Level", 4); % calculated from teststring
   TAB = 8;
   bob;
   % Indent one level
   variable i;
   foreach i ([0,1,2,3])
      {
         bol_trim();
         whitespace(i);
         python->py_shift_line_right();
         bol_skip_white();
         test_equal(what_column()-1, Py_Indent_Level,
            sprintf("should indent from %d to next Py_Indent_Level", i));
      }
   % Indent one more level
   foreach i ([4,5,6,7])
      {
         bol_trim();
         whitespace(i);
         python->py_shift_line_right();
         bol_skip_white();
         test_equal(what_column()-1, 2*Py_Indent_Level,
            sprintf("should indent from %d to next Py_Indent_Level", i));
      }
   % Indent with spaces (test now, as TAB is 2*Py_Indent_Level)
   test_equal(0, bfind("\t"), "should indent with spaces");
   
   % Indent several levels at once with prefix argument
   bol_trim(); 
   set_prefix_argument(3);
   python->py_shift_line_right();
   bol_skip_white();
   test_equal(what_column()-1, 3*Py_Indent_Level, 
      "should indent by prefix-arg * Py_Indent_Level");
}

static define test_py_shift_line_right_with_tabs()
{
   bob;
   % Indent with tabs if get_indent_level returns 0
   define_blocal_var("Py_Indent_Level", 0);
   python->py_shift_line_right();
   test_equal(what_column(), TAB+1,
      "should indent by TAB");
   test_true(blooking_at("\t"), "should indent with tabs");
}

% py_shift_region_right: undefined
%   Increase the indentation level of the region
static define test_py_shift_region_right()
{
   bob();
   push_mark();
   python->py_shift_region_right();
   bol_skip_white();
   test_equal(what_column()-1, Py_Indent_Level, 
      "should indent by Py_Indent_Level");
   test_equal(count_narrows(), 0, "still narrowed");
   test_equal(markp(), 0, "mark left");
}

% py_shift_right: undefined
%   Increase code indentation level
%   If a `prefix_argument' is set, indent the number of levels
%   given in the prefix argument.
static define test_py_shift_right()
{
   bob();
   set_prefix_argument(3);
   py_shift_right();
   bol_skip_white();
   test_equal(what_column()-1, 3*Py_Indent_Level, 
      "should indent by 3*Py_Indent_Level");
}

% define py_shift_line_left()
static define test_py_shift_line_left()
{
   % set indent leve because we fiddle with the teststring!
   define_blocal_var("Py_Indent_Level", 4); 
   TAB = 8;
   bob;
   % Unindent to bol
   variable i;
   foreach i ([1,2,3,4])
      {
         bol_trim();
         whitespace(i);
         python->py_shift_line_left();
         bol_skip_white();
         test_equal(what_column()-1, 0,
            sprintf("should unindent from %d to bol", i));
      }
   % Unindent to first level
   foreach i ([5,6,7,8])
      {
         bol_trim();
         whitespace(i);
         python->py_shift_line_left();
         bol_skip_white();
         test_equal(what_column()-1, 4,
            sprintf("should unindent from %d to first Py_Indent_Level", i));
      }
   % test the saveguard error
   bol_trim();
   variable err = test_for_exception("python->py_shift_line_left");
   if (orelse{err == NULL}{err.error != RunTimeError})
     throw AssertionError, 
     "should abort if there is not enough indentation";
}

% define py_shift_region_left()
static define test_py_shift_region_left()
{
   bol_trim();
   whitespace(Py_Indent_Level);
   push_mark();
   python->py_shift_region_left();
   bol_skip_white();
   test_equal(what_column()-1, 0, "should dedent by Py_Indent_Level");
   test_equal(count_narrows(), 0, "still narrowed");
   test_equal(markp(), 0, "mark left");
}

% define py_shift_left() {
%\synopsis{Decrease code indentation level}
static define test_py_shift_left()
{
   bol_trim();
   whitespace(Py_Indent_Level);
   py_shift_left();
   bol_skip_white();
   test_equal(what_column()-1, 0, "should dedent by Py_Indent_Level");
   bol_trim();
   whitespace(3*Py_Indent_Level);
   set_prefix_argument(3);
   py_shift_left();
   bol_skip_white();
   test_equal(what_column()-1, 0, "should dedent by 3*Py_Indent_Level");
}

% public  define py_untab()
%   Convert tabs to `Py_Indent_Level' spaces or
%   spaces to tabs (with prefix argument)
%   Replace all hard tabs ("\\t") with spaces 
%  NOTES
%   Other than `untab', `py_untab' acts on the whole buffer, not on a
%   region.
static define test_py_untab()
{
   % spaces to tabs (with prefix argument)
   set_prefix_argument(1);
   py_untab();
   bob();
   test_equal('\t', python->check_indentation(),
      "there should be only tabs in code indentation"
      +"(if the indents are a multipel of TAB)");
   test_equal(0, python->get_indent_level,
      "set local indent level to 0 (indent with tabs)");
   % tabs to spaces
   py_untab();
   bob();
   test_equal(0, fsearch("\t"), "there should be no tabs in the buffer");
   test_equal(TAB, python->get_indent_level,
      "set local indent level to TAB");
}

% static define reindent_buffer()
%   Reindent buffer using `Py_Indent_Level'
%  DESCRIPTION
%   Reformat current buffer to consistent indentation levels. using the current
%   relative indentation and the value of get_indent_width().
%   Abort if the current indentation violates the Python syntax.
static define test_reindent_buffer()
{
   define_blocal_var("Py_Indent_Level", 0);
   TAB=8;
   python->reindent_buffer();
   test_equal('\t', python->check_indentation(),
      "there should be only tabs in code indentation");
   % reindent with given value
   python->reindent_buffer(4);
   test_equal(4, python->get_indent_level,
      "should set local indent level to 4");
   test_equal(0, fsearch("\t"), "there should be no tabs in the buffer");
   % mark_buffer();
   % show(bufsubstr());
   % show(teststring);
   mark_buffer();
   test_equal(bufsubstr(), teststring, "should be back to original indent");
}

static define test_reindent_buffer_zero_TAB()
{
   TAB=0;
   % reindent_buffer should set TAB to 4 to prevent indent by 0 spaces!
   python->reindent_buffer(0);
   test_equal('\t', python->check_indentation(),
      "there should be only tabs in code indentation");
   % reindent with given value
   python->reindent_buffer(4);
   test_equal(4, python->get_indent_level,
      "should set local indent level to 4");
   test_equal(0, fsearch("\t"), "there should be no tabs in the buffer");
   mark_buffer();
   test_equal(bufsubstr(), teststring, "should be back to original indent");
}

% static define reindent_block()
% reindent the current block or all blocks that overlap with a visible region
static define test_reindent_block()
{
   eob();
   insert("def ulf():\n");
   insert("    quatsch()\n");
   insert("    batch()\n");
   insert("\n");
   insert("# last comment\n");
   
   define_blocal_var("Py_Indent_Level", 0);
   % call reindent_block on last line
   set_buffer_modified_flag(0);
   python->reindent_block();
   test_equal(0, buffer_modified(), 
      "should do nothing if on non-indented line that doesnot start a block");
   % call on last block
   () = bsearch("quatsch");
   python->reindent_block();
   bol();
   test_true(looking_at_char('\t'), "should indent block with tabs");
   % this should move the point into the first block
   test_equal(0, python->check_indentation(), "now tabs and spaces are mixed");
   python->reindent_block();
   % as there are only 2 blocks, indentation should be clean again
   test_equal('\t', python->check_indentation(), "should be only tabs");
}

% Magic keys
% ----------

% define electric_colon()
% dedent a line one level, if it is the start of a new block
static define test_electric_colon()
{
   insert("\n   else");
   python->electric_colon();
   bol_skip_white();
   test_equal(what_column(), 1);
   insert("\n   elise"); % not a subblock starter
   python->electric_colon();
   bol_skip_white();
   test_equal(what_column(), 4);
}


% define electric_delim(ch)
% Currently not used due to unsolved problems
static define test_electric_delim()
{
   python->electric_delim(')');
}

% define py_backspace_key()
% shift line right if we are at the first non-white space in an indented
% line,  normal action else
static define test_py_backspace_key()
{
   variable line, col;
   % inside code: just delete prev char
   bob;
   () = fsearch("self.min_indent");
   line = what_line(), col = what_column();
   python->py_backspace_key();
   test_equal(col-1, what_column(), "should delete prev char normally");
   % goto first non-white char
   bol_skip_white();
   col = what_column();
   python->py_backspace_key();
   test_equal(col-Py_Indent_Level, what_column, 
      "should dedent line if at first non-white space");
   bol;
   python->py_backspace_key();
   test_equal(line-1, what_line(), "should del prev newline if at bol");
}

% define py_exec()
% Run python interpreter on current region or the whole buffer.
% Display output in *python-output* buffer window.
static define test_py_exec()
{
   bob();
   insert("print 2 + 2 #");
   py_exec();
   % () = get_y_or_n("continue");
   test_true(bufferp("*python output*"), 
      "should open output buffer (if there is output from python)");
   close_buffer("*python output*");
}

% public define python_shell()
% attach python session to buffer
static define test_python_shell_interactive()
{
   python_shell();
   testmessage("test interactive!");
}

% define py_help_on_word()
% #ifdef MSWINDOWS
% static define test_py_help_on_word()
% {
%    py_help_on_word();
% }
% #endif

% define get_import_lines()
% find lines with global imports (import ... and  from ... import ...)
static define test_get_import_lines()
{
   % get the teststring up to the comment (minus the newline)
   variable import_lines = teststring[[:is_substr(teststring, "#")-2]];
   
   test_equal(import_lines, python->get_import_lines());
   erase_buffer();
   test_equal("", python->get_import_lines());
}

% py_help: undefined
% 
%  SYNOPSIS
%   Run python's help feature on topic
% 
%  USAGE
%    Void py_help([String topic])
% 
%  DESCRIPTION
%    Call python help on topic and display the help text in a window.
%    If the topic is not given, ask in the minibuffer.
% 
%  NOTES
%    Only tested on UNIX
% 
%  SEE ALSO
%   py_mode
static define test_py_help()
{
   py_help("string.whitespace");
   test_true(bufferp("*python-help*"), 
      "should open help buffer");
   test_true(fsearch("string.whitespace"),
      "should display help on 'string.whitespace'");
   close_buffer("*python-help*");
}


% define py_help_for_word_hook(word)
% (add "." to word chars);
static define test_python_help_for_word_hook()
{
   insert(" string.whitespace");
   python->python_help_for_word_hook("dummy");
   test_true(bufferp("*python-help*"), 
      "should open help buffer");
   setbuf("*python-help*");
   bob();
   test_true(fsearch("string.whitespace"),
      "should display help on 'string.whitespace'");
   % () = get_y_or_n("continue");
   close_buffer("*python-help*");
}

% define py_browse_module_doc() % (module=NULL)
static define test_py_browse_module_doc_interactive()
{
   message("should open help for module 'os' in browser");
   py_browse_module_doc("os");
   testmessage("needs interactive testing (opens external browser)");
}

% python_mode: library function
% 
%  SYNOPSIS
%   Mode for editing Python files.
% 
%  USAGE
%   Void python_mode()
% 
%  DESCRIPTION
%  A major mode for editing scripts written in Python (www.python.org).
% 
%  The following keys have python specific bindings:
% 
%   Backspace   deletes to previous indentation level
%   : (colon)   dedents appropriately
%   (the next assume `_Reserved_Key_Prefix' == "^C")
%   ^C#         comments region or current line
%   ^C>         shifts line or region right
%   ^C<         shifts line or region left
%   ^C^C        executes the region, or the buffer if region not marked.
%   ^C|         executes the region
% 
% 
%  SEE ALSO
%   Py_Indent_Level, Py_Use_Tabs, py_reindent, python->py_untab
static define test_python_mode()
{
   python_mode();
}

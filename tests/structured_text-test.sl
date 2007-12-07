% structured_text-test.sl:  Test structured_text.sl
% 
% Copyright (c) 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1 2006-03-03 

require("unittest");

% test availability of public functions (comment to skip)
test_true(is_defined("structured_text_hook"), "public fun structured_text_hook undefined");

% Fixture
% -------

require("structured_text");

private variable testbuf = "*bar*";
private variable teststring = "a test line";
private variable enumerated_list = ["1. das ist es",
                                    "2.  auch noch",
                                    " 3. drittens",
                                    "45.\tlast"];
private variable itemize_list = ["* so",
                                 "+ geht's",
                                 "*  auch",
                                 "-  nicht",
                                 "+\tbesser"];

private define insert_lists()
{
   insert(strjoin(enumerated_list, "\n")+"\n"+strjoin(itemize_list, "\n"));
}
  
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

% line_is_list: library function
% 
%  SYNOPSIS
%   Return length of a list marker
% 
%  USAGE
%    line_is_list()
% 
%  DESCRIPTION
%  Check if the current line starts with a list marker matching one of the
%  regular expressions defined in `Rst_List_Patterns'.
%  Return length of the list marker (excluding leading whitespace)
% 
%  Leaves the editing point at first non-whitespace or eol
% 
%  NOTES
%  Thanks to JED for the regular expressions variant
% 
%  SEE ALSO
%   line_is_empty, Text_List_Patterns
static define test_line_is_list()
{
   test_equal(line_is_list(), 0, "text line is no list");
   erase_buffer();
   insert_lists();
   bob();
   do
     test_true(line_is_list(), "should recognize list line");
   while (down_1());
   % should return the length of the list marker:
   bob();
   variable len, 
     marker_lengths = [3, %   "1. das ist es",
                       4, %   "2.  auch noch",
                       3, %   " 3. drittens",
                       4, %   "45.\tlast"
                       2, %   "* so",
                       2, %   "+ geht's",
                       3, %   "*  auch",
                       3, %   "-  nicht",
                       2]; %   "+\tbesser"              
   
   foreach len (marker_lengths)
     {
        test_equal(line_is_list(), len, 
           sprintf("should return list marker length (%d) '%s'",  
              len, get_line()));
        go_down_1();
     }
}

% define line_is_blank()
static define test_line_is_blank()
{
   test_equal(line_is_blank(), 0, "text is not blank");
   erase_buffer();
   insert("\n   \n\t\t\n\n  \t\n\n");
   bob();
   do
     test_true(line_is_blank(), sprintf("line %d is blank", what_line));
   while (down_1());
}

% TODO: the remainder is still raw testscript_wizard output
#stop

% st_is_paragraph_separator: library function
% 
%  SYNOPSIS
%   paragraph separator hook for structured text
% 
%  USAGE
%   st_is_paragraph_separator()
% 
%  DESCRIPTION
%  Return 1 if the current line separates a paragraph, i.e. it
%  is empty or a list item
% 
%  NOTES
%  Actually, this misses an important difference between empty lines and
%  first lines of a list item: While an empty line must not be filled
%  when reformatting, a list item should.
%  This is why Emacs has 2 Variables, paragraph-separator and paragraph-start.
% 
%  SEE ALSO
%   line_is_empty, line_is_list
static define test_st_is_paragraph_separator()
{
   st_is_paragraph_separator();
}

% define st_backward_paragraph()
static define test_st_backward_paragraph()
{
   st_backward_paragraph();
}

% define st_mark_paragraph()
static define test_st_mark_paragraph()
{
   st_mark_paragraph();
}

% st_indent: library function
% 
%  SYNOPSIS
%   indent-line for structured text
% 
%  USAGE
%   st_indent()
% 
%  DESCRIPTION
%  Indent the current line,  taking care of list markers as defined in
%  `Text_List_Patterns'.
% 
%  NOTES
%   Expanded from example in hooks.txt
% 
%  SEE ALSO
%   st_is_paragraph_separator, line_is_list, Text_List_Patterns
static define test_st_indent()
{
   st_indent();
}

% st_newline_and_indent: library function
% 
%  SYNOPSIS
%   newline_and_indent for structured text
% 
%  USAGE
%    st_newline_and_indent ()
% 
%  DESCRIPTION
%  Indent to level of preceding line
% 
%  NOTES
%  We need a separate definition, as by default newline_and_indent()  uses the
%  indent_hook (which structured_text.sl sets to st_indent (considering list
%  markers) while with Enter we want more likely to start a new list topic.
% 
%  SEE ALSO
%   st_indent, st_indent_relative
static define test_st_newline_and_indent()
{
   st_newline_and_indent();
}

% define st_format_paragraph();  % forward definition
static define test_st_format_paragraph()
{
   st_format_paragraph();
}

% define st_format_paragraph()
static define test_st_format_paragraph()
{
   st_format_paragraph();
}

% structured_text_hook: library function
% 
%  SYNOPSIS
%   Formatting hook for "ASCII markup"
% 
%  USAGE
%   structured_text_hook()
% 
%  DESCRIPTION
%   This function calls a list of buffer hooks (see Help>Browse-Docs>Hooks)
%   suitable for proper indenting and paragraph formatting of documents using
%   "ASCII markup".
%   
%   Paragraphs are separated by blank lines and indented to the same column
%   as the first line of the paragraph.
%   
%   List items that start with a special list marker (e.g. '* ' or '3.') are
%   considered paragraphs as well, even when not preceded by an empty line.
%   Continuation lines are indented to the column that matches the start of the
%   list text.%  
% 
%  EXAMPLE
%   To enable the structured text formatting in `text_mode', set an alias:
% 
%    define text_mode_hook() { structured_text_hook(); }
% 
% 
%  NOTES
%   `rst_mode' calls `structured_text_hook' by default.
% 
%  SEE ALSO
%   st_indent, st_backward_paragraph, st_mark_paragraph
static define test_structured_text_hook()
{
   structured_text_hook();
}

sw2buf("*test report*");
view_mode();

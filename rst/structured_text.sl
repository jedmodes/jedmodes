% structured_text: formatting hooks for "ASCII markup"
%
%  Copyright (c) 2006 Günter Milde
%  Released under the terms of the GNU General Public License (ver. 2 or later)
%
%  Versions:
%             0.1  first version published together with rst.sl
%  2006-01-20 0.2  including the regular expressions from JED
%                  documentation
%  2006-01-23 0.3  added st_backward_paragraph() and st_mark_paragraph()
%                  set "mark_paragraph_hook" to format first line of list item
%  2006-02-03 0.4  bugfix in the Text_List_Patterns (* needs to be escaped)
%  2006-05-17 0.4.1 code cleanup
%  2006-08-14 0.5  bugfix: rename text_mode_hook() to structured_text_hook() 
%                  to avoid name clashes. To activate the st functions in
%                  text mode, define an alias as described in the function doc.
%                  (report J. Sommmer)

provide("structured_text");

% the set of regular expressions matching a list mark
custom_variable("Text_List_Patterns",
   ["[0-9]+\\.[ \t]+ ", %  enumeration
    % "[a-z]+\\) ",     %  alpha enumeration
    "[\\*\\+\\-] "      %  itemize (bullet list)
    ]);

%!%+
%\function{line_is_list}
%\synopsis{Return length of a list marker}
%\usage{ line_is_list()}
%\description
% Check if the current line starts with a list marker matching one of the
% regular expressions defined in \var{Rst_List_Patterns}.
% Return length of the list marker (excluding leading whitespace)
%
% Leaves the editing point at first non-whitespace or eol
%\notes
% Thanks to JED for the regular expressions variant
%\seealso{line_is_empty, Text_List_Patterns}
%!%-
define line_is_list()
{
   variable len = 0, re;
   % get the current line without leading whitespace
   variable line = strtrim_beg(line_as_string());
   bol_skip_white();

   foreach (Text_List_Patterns)
     {
        re = ();
        if (1 != string_match(line, re, 1))
          continue;
        (,len) = string_match_nth(0);
     }
   return len;
}

%!%+
%\function{line_is_empty}
%\synopsis{Check if the line is empty (not counting whitespace)}
%\usage{ line_is_empty()}
%\description
%  This is the same as the default is_paragraph_separator test.
%  Leaves the editing point at first non-white space.
%\seealso{line_is_list}
%!%-
define line_is_empty()
{
   bol_skip_white();
   return eolp();
}

%
%!%+
%\function{st_is_paragraph_separator}
%\synopsis{paragraph separator hook for structured text}
%\usage{st_is_paragraph_separator()}
%\description
% Return 1 if the current line separates a paragraph, i.e. it
% is empty or a list item
%\notes
% Actually, this misses an important difference between empty lines and
% first lines of a list item: While an empty line must not be filled
% when reformatting, a list item should.
% This is why Emacs has 2 Variables, paragraph-separator and paragraph-start.
%\seealso{line_is_empty, line_is_list}
%!%-
define st_is_paragraph_separator()
{
   % show("line", what_line, "calling st_is_paragraph_separator");
   return orelse{line_is_empty()}{line_is_list()>0};
   % attention: there is a segfault if the paragraph_separator_hook returns
   % values higher than 1!
}

% go to the beginning of the current paragraph
define st_backward_paragraph()
{
   if (line_is_empty())
     go_up_1();
   do 
     {
        if (line_is_list())
          break;
        if (line_is_empty())
          {
             eol();
             go_right_1();
             break;
          }
     }
   while (up(1));
}

% Mark the current paragraph
% This can also be used for format_paragraph's
% "mark_paragraph_hook"
define st_mark_paragraph()
{
   st_backward_paragraph();
   push_visible_mark;
   forward_paragraph();
}

%!%+
%\function{st_indent}
%\synopsis{indent-line for structured text}
%\usage{st_indent()}
%\description
% Indent the current line,  taking care of list markers as defined in
% \var{Text_List_Patterns}.
%\notes
%  Expanded from example in hooks.txt
%\seealso{st_is_paragraph_separator, line_is_list, Text_List_Patterns}
%!%-
define st_indent()
{
   variable indent;
   % show("line", what_line, "calling st_indent");
   % get indendation of previous line
   push_spot();
   go_up_1;
   bol_skip_white();
   indent = what_column - 1 + line_is_list();
   go_down_1;
   indent -= line_is_list();  % de-dent the list marker
   bol_trim();
   whitespace(indent);
   pop_spot();
   if (bolp)
     skip_white();
}

%!%+
%\function{st_newline_and_indent}
%\synopsis{newline_and_indent for structured text}
%\usage{ st_newline_and_indent ()}
%\description
% Indent to level of preceding line
%\notes
% We need a separate definition, as by default newline_and_indent()  uses the
% indent_hook (which structured_text.sl sets to st_indent (considering list
% markers) while with Enter we want more likely to start a new list topic.
%\seealso{st_indent, st_indent_relative}
%!%-
define st_newline_and_indent()
{
   % show("line", what_line, "calling st_newline_and_indent");
   variable indent, col = what_column();
   % get number of leading spaces
   push_spot();
   bol_skip_white();
   indent = what_column();
   pop_spot();
   newline();
   if (indent > col)  % more whitespace than the calling points column
     indent = col;
   whitespace(indent-1);
}

% autoload("mark_paragraph", "txtutils");

%!%+
%\function{structured_text_hook}
%\synopsis{Formatting hook for "ASCII markup"}
%\usage{structured_text_hook()}
%\description
%  This function calls a list of buffer hooks (see Help>Browse-Docs>Hooks)
%  suitable for proper indenting and paragraph formatting of documents using
%  "ASCII markup".
%  
%  Paragraphs are separated by blank lines and indented to the same column
%  as the first line of the paragraph.
%  
%  List items that start with a special list marker (e.g. '* ' or '3.') are
%  considered paragraphs as well, even when not preceded by an empty line.
%  Continuation lines are indented to the column that matches the start of the
%  list text.%  
%\example
%  To enable the structured text formatting in \sfun{text_mode}, set an alias:
%#v+
%  define text_mode_hook() { structured_text_hook(); }
%#v-
%\notes
%  \sfun{rst_mode} calls \sfun{structured_text_hook} by default.
%\seealso{st_indent, st_backward_paragraph, st_mark_paragraph}
%!%-
public define structured_text_hook()
{
   set_buffer_hook("wrap_hook", &st_indent);
   set_buffer_hook("indent_hook", &st_indent);
   set_buffer_hook("backward_paragraph_hook", &st_backward_paragraph);
   set_buffer_hook("mark_paragraph_hook", "st_mark_paragraph");
   set_buffer_hook("newline_indent_hook", &st_newline_and_indent);
   set_buffer_hook("par_sep", &st_is_paragraph_separator);
}

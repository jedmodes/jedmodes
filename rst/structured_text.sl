% structured_text.sl: formatting hooks for "ASCII markup"
% =======================================================
%
% Copyright (c) 2006 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions
% --------
% 
%             0.1   first version published together with rst.sl
% 2006-01-20  0.2   including the regular expressions from JED
%                   documentation
% 2006-01-23  0.3   added st_backward_paragraph() and st_mark_paragraph()
%                   set "mark_paragraph_hook" to format first line of list item
% 2006-02-03  0.4   bugfix in the Text_List_Patterns (* needs to be escaped)
% 2006-05-17  0.4.1 code cleanup
% 2006-08-14  0.5   * bugfix: rename text_mode_hook() to structured_text_hook()
%                     to avoid name clashes. To activate the st formatting in
%                     text mode, define an  alias as described in the function
%                     doc. (report J. Sommmer)
% 2007-07-02  0.6   * rename line_is_empty() -> line_is_blank, as it may
%                     contain whitespace
%                   * new function st_format_paragraph() with correct
%                     formatting of multi-line list-items
%                   * relax match-requirement in line_is_list to allow
%                     UTF-8 multi-byte chars in Text_List_Patterns.
%                     (jed-extra bug #431418, Joerg Sommer)
% 2007-09-21  0.6.1 * fix Text_List_Patterns

% Usage
% -----
% 
% Place in the jed-library-path.
% 
% To enable the structured text formatting in e.g. text_mode(), define (or
% extend) the text_mode_hook in your jed.rc config file:
%  
%  autoload("structured_text_hook", "structured_text");
%  define text_mode_hook() 
%  { 
%    structured_text_hook();
%    % <other actions to perform when text_mode() is called>
%  }

% Requirements
% ------------
% 
% None

provide("structured_text");

% Customization
% -------------
 
% the set of regular expressions matching a list mark
% (leading whitespace is stripped from the line before matching)
custom_variable("Text_List_Patterns",
   {"^[0-9]+\\.[ \t]+",  %  enumeration
    %"^[a-z]+\\)[ \t]+", %  alpha enumeration (many false positives)
    "^[a-z]\\)[ \t]+",   %  alpha enumeration (just one small letter)
    "^[-*+][ \t]+",      %  itemize (bullet list)
    "^:[a-zA-Z]+:[ \t]+" %  field list (ReST syntax)
    });

% Functions
% ---------

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

   foreach re (Text_List_Patterns)
     {
        if (string_match(line, re, 1) < 1)
          continue;
        (,len) = string_match_nth(0);
     }
   return len;
}

%!%+
%\function{line_is_blank}
%\synopsis{Check if the line is blank (not counting whitespace)}
%\usage{ line_is_blank()}
%\description
%  This is the same as the default is_paragraph_separator test.
%  Leaves the editing point at first non-white space.
%\seealso{line_is_list}
%!%-
define line_is_blank()
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
% is blank or a list item
%\notes
% Actually, this misses an important difference between blank lines and
% first lines of a list item: While an blank line must not be filled
% when reformatting, a list item should.
% This is why Emacs has 2 Variables, paragraph-separator and paragraph-start.
%\seealso{line_is_blank, line_is_list}
%!%-
define st_is_paragraph_separator()
{
   % show("line", what_line, "calling st_is_paragraph_separator");
   return orelse{line_is_blank()}{line_is_list()>0};
   % attention: there is a segfault if the paragraph_separator_hook returns
   % values higher than 1!
}

% go to the beginning of the current paragraph
define st_backward_paragraph()
{
   if (line_is_blank())
     go_up_1();
   do 
     {
        if (line_is_list())
          break;
        if (line_is_blank())
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
   indent = what_column-1 + line_is_list();
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

define st_format_paragraph();  % forward definition

% Use the internal paragraph formatting function instead of the buffer local
% hook. (code from c_format_paragraph())
static define global_format_paragraph()
{
   unset_buffer_hook("format_paragraph_hook");
   call("format_paragraph");
   set_buffer_hook("format_paragraph_hook", &st_format_paragraph);
}

% format structured text, take care of list formatting
define st_format_paragraph()
{
   message("st_format");
   push_spot();
   global_format_paragraph();
   
   % Fix formatting of lines following a list-item
   forward_paragraph();
   variable line_no = what_line();
   backward_paragraph();
   if (line_is_list and line_no != what_line())
     {
        go_down_1();
        st_indent();
        global_format_paragraph();
     }
   pop_spot();
}



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
%  considered paragraphs as well, even when not preceded by an blank line.
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
   set_buffer_hook("format_paragraph_hook", "st_format_paragraph");
   set_buffer_hook("newline_indent_hook", &st_newline_and_indent);
   set_buffer_hook("par_sep", &st_is_paragraph_separator);
}

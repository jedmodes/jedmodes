% -*- mode: slang; mode: fold -*-
% 
%{{{ Documentation
%   
% Description
% 
%   This mode implements a syntax highlighting and indentation scheme for
%   JavaScript version 1.5 as described in "Core JavaScript Reference 1.5"
%   from Netscape Communications Corporation 2000. There are also some utility 
%   functions that can make life easier (i.e. save some typing effort) for the 
%   developer. These functions can be called directly or, preferably, be bound 
%   to some key combination or chosen from the mode menu. I made the menu 
%   stuff beacuse I wanted to see how it was done, therefore the commands 
%   provided by the mode menu are a bit lame - they are just there because I 
%   had to put _something_ there.
%   
%   N.B. C mode is used for fancy stuff like automatic indentation. This makes
%   it necessary to end lines with a semicolon, although it's not necessary by
%   the JavaScript standard.
%   
%   http://hem.fyristorg.com/e-gerell/johann/jed/javascript.sl
%
% Usage
% 
%   Put this file in your JED_LIBRARY path and add the following lines to your
%   startup file (.jedrc or jed.rc):
%
%     autoload("javascript_mode", "javascript");
%     add_mode_for_extension("javascript", "js");
%
%   Every time you open a file called something.js, javascript_mode will
%   automatically be loaded.
%  
% Changelog
% 
%   1.0 - 2002/01/16:
%     - First public release.
%     
% Author
% 
%   Johann Gerell <johann dot gerell at home dot se>
%   
%}}}

provide("javascript");

require("cmode");     % indentation and fancy stuff is handled by C mode

$0 = "JavaScript";

%{{{ Syntax definition
create_syntax_table($0);
define_syntax("/*", "*/", '%', $0);         % comment
define_syntax("//", "", '%', $0);           % comment
define_syntax("([{", ")]}", '(', $0);       % matched braces
define_syntax('"', '"', $0);                % string
define_syntax('\'', '"', $0);               % string
define_syntax('\\', '\\', $0);              % escape
define_syntax("0-9a-zA-Z_", 'w', $0);       % words
define_syntax("-+0-9a-fA-F.xXL", '0', $0);  % Numbers
define_syntax(",;.?:", ',', $0);            % delimiters
define_syntax("%-+/&*=<>|!~^", '+', $0);    % operators
set_syntax_flags($0, 0x4|0x40|0x80);
%}}}
%{{{ Keywords: statements
() = define_keywords_n($0, "doifin", 2, 0);
() = define_keywords_n($0, "fortryvar", 3, 0);
() = define_keywords_n($0, "elsewith", 4, 0);
() = define_keywords_n($0, "breakcatchconstlabelthrowwhile", 5, 0);
() = define_keywords_n($0, "exportimportreturnswitch", 6, 0);
() = define_keywords_n($0, "continuefunction", 8, 0);
%}}}
%{{{ Keywords: types, top-level stuff and other reserved words
() = define_keywords_n($0, "NaNintnew", 3, 1);
() = define_keywords_n($0, "bytecasecharenumevalgotolongnullthistruevoid", 4, 1);
() = define_keywords_n($0, "classfalsefinalfloatisNaNshortsuper", 5, 1);
() = define_keywords_n($0, "deletedoublenativepublicstaticthrowstypeof", 6, 1);
() = define_keywords_n($0, "booleandefaultextendsfinallypackageprivate", 7, 1);
() = define_keywords_n($0, "InfinityabstractdebuggerisFiniteparseIntvolatile", 8, 1);
() = define_keywords_n($0, "decodeURIencodeURIinterfaceprotectedtransientundefined", 9, 1);
() = define_keywords_n($0, "implementsinstanceofparseFloat", 10, 1);
() = define_keywords_n($0, "synchronized", 12, 1);
() = define_keywords_n($0, "decodeURIComponentencodeURIComponent", 18, 1);
%}}}
%{{{ Keywords: objects
() = define_keywords_n($0, "sun", 3, 2);
() = define_keywords_n($0, "AreaDateFormLinkMathTextjava", 4, 2);
() = define_keywords_n($0, "ArrayFrameImageLayerRadioResetStyleevent", 5, 2);
() = define_keywords_n($0, "AnchorAppletButtonHiddenNumberObjectOptionPluginRegExpSelectStringSubmitscreenwindow", 6, 2);
() = define_keywords_n($0, "BooleanHistory", 7, 2);
() = define_keywords_n($0, "CheckboxFunctionLocationMimeTypePackagesPasswordTextareadocumentnetscape", 8, 2);
() = define_keywords_n($0, "JavaArrayJavaClassnavigator", 9, 2);
() = define_keywords_n($0, "FileUploadJavaObject", 10, 2);
() = define_keywords_n($0, "JavaPackage", 11, 2);
%}}}

define javascript_menu(menu) { %{{{
  menu_append_item(menu, "Indent &buffer", "javascript_indent_buffer");
  menu_append_item(menu, "Indent &region", "javascript_indent_region_or_line");
  menu_append_separator( menu);
  menu_append_item(menu, "Insert &function", "javascript_insert_function");
  menu_append_item(menu, "Insert f&or", "javascript_insert_for");
  menu_append_item(menu, "Insert &switch", "javascript_insert_switch");
  menu_append_item(menu, "Insert &if", "javascript_insert_if");
  menu_append_separator( menu);
  menu_append_item(menu, "&Goto Match", "goto_match");
}
%}}}
define javascript_indent_buffer() { %{{{
  push_spot; bob;
  do
    indent_line;
  while(down_1);
  pop_spot;
}
%}}}
define javascript_indent_region_or_line() { %{{{
  !if(is_visible_mark) indent_line;
  else {
    check_region(1);                % make sure the mark comes first
    variable endline = what_line;
    exchange_point_and_mark();      % now point is at start of region
    while(what_line <= endline) { indent_line; down_1; }
    pop_mark(0); pop_spot;          % return to where we were before
  }
}
%}}}
define javascript_insert_function() { %{{{
  insert("function " + read_mini("function:", Null_String, Null_String) + "() {\n}");
  up_1; c_indent_line;
  down_1; c_indent_line;
  bsearch(")");	
}
%}}}
define javascript_insert_for() { %{{{
  insert("for(;;) {\n}");
  up_1; c_indent_line;
  down_1; c_indent_line;
  bsearch(";;");	
}
%}}}
define javascript_insert_switch() { %{{{
  insert("switch() {\ncase ONE:\ncase TWO:\ndefault:\n}");
  go_up(4); c_indent_line;
  down_1; c_indent_line;
  down_1; c_indent_line;
  down_1; c_indent_line;
  down_1; c_indent_line;
  bsearch(")");
}
%}}}
define javascript_insert_if() { %{{{
  insert("if() {\n}\nelse if() {\n}\nelse {\n}");
  go_up(5); c_indent_line;
  down_1; c_indent_line;
  down_1; c_indent_line;
  down_1; c_indent_line;
  down_1; c_indent_line;
  down_1; c_indent_line;
  go_up(5); bsearch(")");
}
%}}}

define javascript_mode() {
  c_mode();
  set_mode("JavaScript", 2);
  set_comment_info("JavaScript", "<!-- ", " -->", 0);
  use_syntax_table("JavaScript");
  mode_set_mode_info("JavaScript", "fold_info", "//{{{\r//}}}\r\r");
  mode_set_mode_info("JavaScript", "init_mode_menu", &javascript_menu);
  run_mode_hooks("javascript_mode_hook");
}

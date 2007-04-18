% -*- SLang -*-         ruby.sl

% Author:	MAEDA Shugo (shugo@po.aianet.ne.jp)

% Modification by Wild Karl-Heinz ( kh dot wild aet wicom point li )
% working with Jed Version 0.99.16 
% can be found at http://wicom.at/wild_karlheinz/downlaods/ruby.sl

% Version:	0.05

% `Ruby mode for Jed' is FREE SOFTWARE, released under the terms of the 
% GNU General Public License (version 2 or later)
% Please use AT YOUR OWN RISK.

% [What's ruby?]
%
%  Ruby is the interpreted scripting language for quick and
%  easy object-oriented programming.  It has many features to
%  process text files and to do system management tasks (as in
%  perl).  It is simple, straight-forward, and extensible.
%
%  The ruby distribution can be found on
% 
%    http://www.ruby-lang.org/

% [Install]
%
% Please add these lines to your `jed.rc' file 
% (e.g. ~/.jedrc or ~/.jed/jed.rc).
%
%     % Load ruby mode when openning `.rb' files.   
%     autoload("ruby_mode", "ruby");
%     add_mode_for_extension ("ruby", "rb");
%
% [Customization]
% 
%     % amount of space to indent within block.
%     variable ruby_indent_level = 2;


custom_variable("ruby_indent_level", 3);

define ruby_indent_to(n)
{
   variable step;
   
   step = what_column();
   bol_skip_white();
   step -= what_column();
   if (what_column != n) {
      bol_trim ();
      n--;
      whitespace (n);
   }
   if (step > 0) go_right(step);
}

define ruby_looking_keyword_at(keyword)
{
   push_spot;
   EXIT_BLOCK {
      pop_spot;
   }
   
   if (looking_at(keyword)) 
     {
	go_right(strlen(keyword));
	return( orelse
	   { looking_at(" ") }
	     { looking_at("\t") }
	     { looking_at(";") }
	     { eolp() }
	   );
     } else {
	return 0;
     }
}

define ruby_calculate_indent()
{
   variable indent = 0;
   variable extra_indent = 0;
   variable ch;
   variable par_level;
   
   CASE_SEARCH = 0;
   push_spot();
   EXIT_BLOCK {
      pop_spot();
   }
   
   bol_skip_white();
   indent = what_column();
   if (orelse
      { ruby_looking_keyword_at("end") }
	{ ruby_looking_keyword_at("else") }
	{ ruby_looking_keyword_at("elsif") }
	{ ruby_looking_keyword_at("rescue") }
	{ ruby_looking_keyword_at("ensure") }
	{ ruby_looking_keyword_at("when") }
	{ looking_at("}") }
      ) {
      extra_indent -= ruby_indent_level;
   }
   !if (up_1()) return indent;
   
   eol();
   par_level = 0;
   forever {
      if (eolp()) {
	 forever {
	    bol();
	    if (looking_at("#")) {
	       !if (up_1()) return indent;
	       eol();
	    } else {
	       eol();
	       break;
	    }
	 }
      }
      go_left_1();
      ch = what_char();
      if (ch == ')') {
	 par_level--;
      } else if (ch == '(') {
	 par_level++;
	 if (par_level == 1) return what_column() + 1;
      }
      
      if (bolp() and (par_level == 0)) {
	 skip_white();
	 indent = what_column();
	 break;
      }
   }
   
   if (looking_at("#")) return what_column();
   
   if (orelse
      { ruby_looking_keyword_at("class") }
	{ ruby_looking_keyword_at("module") }
	{ ruby_looking_keyword_at("def") }
	{ ruby_looking_keyword_at("if") }
	{ ruby_looking_keyword_at("else") }
	{ ruby_looking_keyword_at("elsif") }
	{ ruby_looking_keyword_at("unless") }
	{ ruby_looking_keyword_at("case") }
	{ ruby_looking_keyword_at("when") }
	{ ruby_looking_keyword_at("while") }
	{ ruby_looking_keyword_at("until") }
	{ ruby_looking_keyword_at("for") }
	{ ruby_looking_keyword_at("begin") }
	{ ruby_looking_keyword_at("rescue") }
	{ ruby_looking_keyword_at("ensure") }
      ) {
      eol();
      bskip_white();
      !if (orelse
	 { blooking_at(" end") }
	   { blooking_at("\tend") }
	 ) {
	 extra_indent += ruby_indent_level;
      }
   } else {
      eol();
      bskip_white();
      if (blooking_at("{"))
	extra_indent += ruby_indent_level;
      else if (blooking_at("|"))
	extra_indent += ruby_indent_level;
      else if (blooking_at(" do"))
	extra_indent += ruby_indent_level;
   }
   
   return indent + extra_indent;
}

define ruby_indent_line()
{
   ruby_indent_to(ruby_calculate_indent());
}

define ruby_newline_and_indent()
{
   variable step;
   step = what_column();
   bol_skip_white();
   step -= what_column();
   if (orelse
      { looking_at("end") }
	{ looking_at("else") }
	{ looking_at("elsif") }
	{ looking_at("rescue") }
	{ looking_at("ensure") }
	{ looking_at("when") }
	{ looking_at("}") }
      ) {
      ruby_indent_line();
   }
   go_right(step);
   newline();
   ruby_indent_line();
}

define ruby_self_insert_cmd()
{
   variable step;
   
   insert_char(LAST_CHAR);
   step = what_column();
   bol_skip_white();
   step -= what_column();
   if( orelse
      { looking_at("end") }
	{ looking_at("else") }
	{ looking_at("elsif") }
	{ looking_at("rescue") }
	{ looking_at("ensure") }
	{ looking_at("when") }
	{ looking_at("}") }
      ) 
     {
	ruby_indent_line();
     }
   go_right( step );
}

% Define keymap.
private variable mode = "ruby";
!if (keymap_p (mode)) make_keymap (mode);
definekey ("ruby_show_version", "^Cv", mode);
definekey ("ruby_self_insert_cmd", "0", mode);
definekey ("ruby_self_insert_cmd", "1", mode);
definekey ("ruby_self_insert_cmd", "2", mode);
definekey ("ruby_self_insert_cmd", "3", mode);
definekey ("ruby_self_insert_cmd", "4", mode);
definekey ("ruby_self_insert_cmd", "5", mode);
definekey ("ruby_self_insert_cmd", "6", mode);
definekey ("ruby_self_insert_cmd", "7", mode);
definekey ("ruby_self_insert_cmd", "8", mode);
definekey ("ruby_self_insert_cmd", "9", mode);
definekey ("ruby_self_insert_cmd", "a", mode);
definekey ("ruby_self_insert_cmd", "b", mode);
definekey ("ruby_self_insert_cmd", "c", mode);
definekey ("ruby_self_insert_cmd", "d", mode);
definekey ("ruby_self_insert_cmd", "e", mode);
definekey ("ruby_self_insert_cmd", "f", mode);
definekey ("ruby_self_insert_cmd", "g", mode);
definekey ("ruby_self_insert_cmd", "h", mode);
definekey ("ruby_self_insert_cmd", "i", mode);
definekey ("ruby_self_insert_cmd", "j", mode);
definekey ("ruby_self_insert_cmd", "k", mode);
definekey ("ruby_self_insert_cmd", "l", mode);
definekey ("ruby_self_insert_cmd", "m", mode);
definekey ("ruby_self_insert_cmd", "n", mode);
definekey ("ruby_self_insert_cmd", "o", mode);
definekey ("ruby_self_insert_cmd", "p", mode);
definekey ("ruby_self_insert_cmd", "q", mode);
definekey ("ruby_self_insert_cmd", "r", mode);
definekey ("ruby_self_insert_cmd", "s", mode);
definekey ("ruby_self_insert_cmd", "t", mode);
definekey ("ruby_self_insert_cmd", "u", mode);
definekey ("ruby_self_insert_cmd", "v", mode);
definekey ("ruby_self_insert_cmd", "w", mode);
definekey ("ruby_self_insert_cmd", "x", mode);
definekey ("ruby_self_insert_cmd", "y", mode);
definekey ("ruby_self_insert_cmd", "z", mode);
definekey ("ruby_self_insert_cmd", "A", mode);
definekey ("ruby_self_insert_cmd", "B", mode);
definekey ("ruby_self_insert_cmd", "C", mode);
definekey ("ruby_self_insert_cmd", "D", mode);
definekey ("ruby_self_insert_cmd", "E", mode);
definekey ("ruby_self_insert_cmd", "F", mode);
definekey ("ruby_self_insert_cmd", "G", mode);
definekey ("ruby_self_insert_cmd", "H", mode);
definekey ("ruby_self_insert_cmd", "I", mode);
definekey ("ruby_self_insert_cmd", "J", mode);
definekey ("ruby_self_insert_cmd", "K", mode);
definekey ("ruby_self_insert_cmd", "L", mode);
definekey ("ruby_self_insert_cmd", "M", mode);
definekey ("ruby_self_insert_cmd", "N", mode);
definekey ("ruby_self_insert_cmd", "O", mode);
definekey ("ruby_self_insert_cmd", "P", mode);
definekey ("ruby_self_insert_cmd", "Q", mode);
definekey ("ruby_self_insert_cmd", "R", mode);
definekey ("ruby_self_insert_cmd", "S", mode);
definekey ("ruby_self_insert_cmd", "T", mode);
definekey ("ruby_self_insert_cmd", "U", mode);
definekey ("ruby_self_insert_cmd", "V", mode);
definekey ("ruby_self_insert_cmd", "W", mode);
definekey ("ruby_self_insert_cmd", "X", mode);
definekey ("ruby_self_insert_cmd", "Y", mode);
definekey ("ruby_self_insert_cmd", "Z", mode);
definekey ("ruby_self_insert_cmd", "_", mode);
definekey ("ruby_self_insert_cmd", "{", mode);
definekey ("ruby_self_insert_cmd", "}", mode);
definekey ("ruby_self_insert_cmd", ";", mode);

% Create syntax table.
create_syntax_table (mode);
define_syntax ("#", Null_String, '%', mode);
define_syntax ("([{<", ")]}>", '(', mode);
define_syntax ('"', '"', mode);
define_syntax ('\'', '\'', mode);
define_syntax ('\\', '\\', mode);
define_syntax ("$0-9a-zA-Z_", 'w', mode);
define_syntax ("-+0-9a-fA-F.xXL", '0', mode);
define_syntax (",;.?:", ',', mode);
define_syntax ("%-+/&*=<>|!~^", '+', mode);
set_syntax_flags (mode, 4);

#ifdef HAS_DFA_SYNTAX
dfa_enable_highlight_cache("ruby.dfa", mode);
dfa_define_highlight_rule("#.*$", "comment", mode);
dfa_define_highlight_rule("([\\$%&@\\*]|\\$#)[A-Za-z_0-9]+", "normal", mode);
dfa_define_highlight_rule(strcat("\\$([_\\./,\"\\\\#\\*\\?\\]\\[;!@:\\$<>\\(\\)",
   "%=\\-~\\^\\|&`'\\+]|\\^[A-Z])"), "normal", mode);
dfa_define_highlight_rule("[A-Za-z_][A-Za-z_0-9]*", "Knormal", mode);
dfa_define_highlight_rule("[0-9]+(\\.[0-9]+)?([Ee][\\+\\-]?[0-9]*)?", "number",
   mode);
dfa_define_highlight_rule("0[xX][0-9A-Fa-f]*", "number", mode);
dfa_define_highlight_rule("[\\(\\[\\{\\<\\>\\}\\]\\),;\\.\\?:]", "delimiter", mode);
dfa_define_highlight_rule("[%\\-\\+/&\\*=<>\\|!~\\^]", "operator", mode);
dfa_define_highlight_rule("-[A-Za-z]", "keyword0", mode);
dfa_define_highlight_rule("'[^']*'", "string", mode);
dfa_define_highlight_rule("'[^']*$", "string", mode);
dfa_define_highlight_rule("\"([^\"\\\\]|\\\\.)*\"", "string", mode);
dfa_define_highlight_rule("\"([^\"\\\\]|\\\\.)*\\\\?$", "string", mode);
dfa_define_highlight_rule("m?/([^/\\\\]|\\\\.)*/[gio]*", "string", mode);
dfa_define_highlight_rule("m/([^/\\\\]|\\\\.)*\\\\?$", "string", mode);
dfa_define_highlight_rule("s/([^/\\\\]|\\\\.)*(/([^/\\\\]|\\\\.)*)?/[geio]*",
   "string", mode);
dfa_define_highlight_rule("s/([^/\\\\]|\\\\.)*(/([^/\\\\]|\\\\.)*)?\\\\?$",
   "string", mode);
dfa_define_highlight_rule("(tr|y)/([^/\\\\]|\\\\.)*(/([^/\\\\]|\\\\.)*)?/[cds]*",
   "string", mode);
dfa_define_highlight_rule("(tr|y)/([^/\\\\]|\\\\.)*(/([^/\\\\]|\\\\.)*)?\\\\?$",
   "string", mode);
dfa_define_highlight_rule(".", "normal", mode);
dfa_build_highlight_table (mode);
#endif

% Type 0 keywords
() = define_keywords_n(mode, "doifinor", 2, 0);
() = define_keywords_n(mode, "anddefendfornilnot", 3, 0);
() = define_keywords_n(mode, "caseelsefailloadloopnextredoselfthenwhen", 4, 0);
() = define_keywords_n(mode, "aliasbeginbreakclasselsifraiseretrysuperundefuntilwhileyield", 5, 0);
() = define_keywords_n(mode, "ensuremodulerescuereturnunless", 6, 0);
() = define_keywords_n(mode, "includerequire", 7, 0);
() = define_keywords_n(mode, "autoload", 8, 0);
% Type 1 keywords (commonly used libc functions)
() = define_keywords_n(mode, "TRUE", 4, 1);
() = define_keywords_n(mode, "FALSE", 5, 1);

public define ruby_mode()
{
   set_mode(mode, 2);
   use_keymap(mode);
   use_syntax_table(mode);
   set_buffer_hook("indent_hook", "ruby_indent_line");
   set_buffer_hook("newline_indent_hook", "ruby_newline_and_indent"); 
   runhooks("ruby_mode_hook");
}

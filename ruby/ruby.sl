% ruby.sl
% 
% $Id: ruby.sl,v 1.3 2007/11/02 17:16:33 paul Exp paul $
% 
% Copyright (c) ca.
%  2000 Shugo Maeda
%  2002 Johann Gerell
%  2003 Karl-Heinz Wild
%  2007 Guenter Milde
%  2007 Paul Boekholt
% Released under the terms of the GNU GPL (version 2 or later).
% 
% [Install]
%
% Please add these lines to your `jed.rc' file 
% (e.g. ~/.jedrc or ~/.jed/jed.rc).
%
%     % Load ruby mode when opening `.rb' files.   
%     autoload("ruby_mode", "ruby");
%     add_mode_for_extension ("ruby", "rb");
%
% [Customization]
% 
%     % amount of space to indent within block.
%     variable ruby_indent_level = 2;

require("comments");
require("pcre");

#ifnexists  __push_list
autoload("list2array", "datutils");
#endif

custom_variable("ruby_indent_level", 2);

private define ruby_indent_to(n)
{
   push_spot();
   try
     {
	bol_skip_white();
	if (what_column() != n)
	  {
	     bol_trim ();
	     whitespace (n - 1);
	  }
     }
   finally
     {
	pop_spot();
	if (bolp())
	  goto_column(n);
     }
}


private define looking_at_block_end ()
{
   return orelse
     { andelse
	  { looking_at_char('e') }
	  { orelse 
	       { looking_at("end") }
	       { looking_at("else") }
	       { looking_at("elsif") }
	       { looking_at("ensure") }}}
     { looking_at("}") }
     { looking_at("rescue") }
     { looking_at("when") };
}

private variable block_start_re=
  pcre_compile("^(?:(?:begin|case|class|def|else( if)?|elsif|ensure|for|if|module|rescue"
	       + "|unless|until|when|while)\b(?!.*\bend$))|(?:(?:\bdo|{|\|) *$)"R);


private define ruby_calculate_indent()
{
   variable indent = 0;
   variable extra_indent = 0;
   variable par_level;
   variable case_search = CASE_SEARCH;
   CASE_SEARCH = 1;
   
   push_spot();
   try
     {
	bol_skip_white();
	indent = what_column();
	if (looking_at_block_end())
	  {
	     extra_indent -= ruby_indent_level;
	  }
	!if (up_1()) return indent;
	
	eol();
	par_level = 0;
	forever
	  {
	     if (eolp())
	       {
		  forever
		    {
		       bol();
		       if (looking_at("#"))
			 {
			    !if (up_1()) return indent;
			    eol();
			 }
		       else
			 {
			    eol();
			    break;
			 }
		    }
	       }
	     !if(left(1)) break;
	     
	     if (0 == parse_to_point())
	       {
		  if (looking_at_char(')'))
		    {
		       par_level--;
		    }
		  else if (looking_at_char('('))
		    {
		       par_level++;
		       if (par_level == 1) return what_column() + 1;
		    }
	       }
	     bskip_chars("^()\n");
	     if (bolp() and (par_level == 0))
	       {
		  skip_white();
		  indent = what_column();
		  break;
	       }
	  }
	
	if (looking_at("#")) return what_column() + extra_indent;
	
	push_mark_eol();
	exchange_point_and_mark();

	return indent + extra_indent
	  + ruby_indent_level * pcre_exec(block_start_re, bufsubstr());
     }
   finally
     {
	pop_spot();
	CASE_SEARCH = case_search;
     }
}

private define ruby_indent_line()
{
   if (get_line_color()) return;
   ruby_indent_to(ruby_calculate_indent());
}

private define check_endblock();

private define check_endblock()
{
   remove_from_hook("_jed_after_key_hooks", &check_endblock);
   if (get_line_color()) return;
   push_spot();
   try
     {
	bskip_white();
	if (bolp()) return; % you may be trying to fix the indentation manually
	bol_skip_white();
	if (looking_at_block_end())
	  {
	     ruby_indent_line();
	     add_to_hook("_jed_after_key_hooks", &check_endblock);
	  }
     }
   finally
     {
	pop_spot();
     }
}

private define insert_ket()
{
   insert_char('}');
   ruby_indent_line();
}

define ruby_newline_and_indent()
{
   check_endblock();
   newline();
   ruby_indent_line();
}

define ruby_self_insert_cmd()
{
   insert_char(LAST_CHAR);
   check_endblock();
}

% Define keymap.
private variable mode = "ruby";
!if (keymap_p (mode)) make_keymap (mode);
definekey ("ruby_self_insert_cmd", "d", mode);
definekey ("ruby_self_insert_cmd", "e", mode);
definekey ("ruby_self_insert_cmd", "f", mode);
definekey ("ruby_self_insert_cmd", "n", mode);
definekey (&insert_ket, "}", mode);

% Create syntax table.
create_syntax_table (mode);
define_syntax ("#", Null_String, '%', mode);
define_syntax ("([{", ")]}", '(', mode);
define_syntax ('"', '"', mode);
define_syntax ('\'', '"', mode);
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
dfa_define_highlight_rule(strcat("\\$([_\\./,\"", "\\#\*\?\]\[;!@:\$<>\(\)"R,
				 "%=\-~\^\|&`'\+]|\^[A-Z])"R), "normal", mode);
dfa_define_highlight_rule("[A-Za-z_][A-Za-z_0-9]*[\?!]?"R, "Knormal", mode);
dfa_define_highlight_rule("[0-9]+(\.[0-9]+)?([Ee][\+\-]?[0-9]*)?"R, "number",
			  mode);
dfa_define_highlight_rule("0[xX][0-9A-Fa-f]*", "number", mode);
dfa_define_highlight_rule("\?[^ ]"R, "number", mode);
dfa_define_highlight_rule("[\(\[\{\<\>\}\]\),;\.\?:]"R, "delimiter", mode);
dfa_define_highlight_rule("[%\-\+/&\*=<>\|!~\^]"R, "operator", mode);
dfa_define_highlight_rule("-[A-Za-z]", "keyword0", mode);

dfa_define_highlight_rule("'([^'\\]|\\.)*'"R, "string", mode);
dfa_define_highlight_rule("`([^`\\]|\\.)*`"R, "string", mode);
dfa_define_highlight_rule("\"([^\"\\\\]|\\\\.)*\"", "string", mode);

% parse_to_point() doesn't take DFA rules into account so
% %r{...} can mess up the indentation - consider using %r'...'
% or Regexp.new("...") instead
dfa_define_highlight_rule("%[rwWqQx]?({.*}|<.*>|\(.*\)|\[.*\]|\$.*\$|\|.*\||!.*!|/.*/|#.*#|"R
			  + "'.*'|\".*\")",
			  "Qstring", mode);

dfa_define_highlight_rule("m?/([^/\\]|\\.)*/[gio]*"R, "string", mode);
dfa_define_highlight_rule("m/([^/\\]|\\.)*\\?$"R, "string", mode);
dfa_define_highlight_rule("s/([^/\\]|\\.)*(/([^/\\]|\\.)*)?/[geio]*"R,
			  "string", mode);
dfa_define_highlight_rule("s/([^/\\]|\\.)*(/([^/\\]|\\.)*)?\\?$"R,
			  "string", mode);
dfa_define_highlight_rule("(tr|y)/([^/\\]|\\.)*(/([^/\\]|\\.)*)?/[cds]*"R,
			  "string", mode);
dfa_define_highlight_rule("(tr|y)/([^/\\]|\\.)*(/([^/\\]|\\.)*)?\\?$"R,
			  "string", mode);
dfa_define_highlight_rule("[^ -~]+", "normal", mode);
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
% Type 1 keywords
() = define_keywords_n(mode, "TRUE", 4, 1);
() = define_keywords_n(mode, "FALSE", 5, 1);

set_comment_info(mode, "# ", "", 4);

private define last_line()
{
   push_spot();
   eob();
   what_line();
   pop_spot();
}

private define search_heredoc_end(indent, end)
{
   if (strlen(indent))
     return re_fsearch(sprintf("\\c^ *%s$", end));
   return re_fsearch(sprintf("\\c^%s$", end));
}

private define color_buffer(min_line, max_line)
{
   !if (max_line) return;
   if (is_visible_mark()) return;
   variable string_color = color_number("string");
   push_spot();
   try
     {
	variable begin = {};
	variable end = {};
	variable in_heredoc = 0;

	goto_line(min_line);
	while (re_bsearch("\c<<\(-?\)\([A-Z]+\)\>"R))
	  {
	     if (bfind_char('#'))
	       continue;
	     list_append(begin, what_line());
	     eol();
	     if (search_heredoc_end(regexp_nth_match(1), regexp_nth_match(2)))
	       {
		  list_append(end, what_line());
		  if (what_line() > max_line)
		    {
		       in_heredoc = 1;
		    }
	       }
	     else
	       {
		  list_append(end,  1 + last_line());
		  in_heredoc = 1;
	       }
	     break;
	  }
	
	!if (in_heredoc)
	  {     
	     while (re_fsearch("\c<<\(-?\)\([A-Z]+\)\>"R))
	       {
		  if (what_line() > max_line)
		    break;
		  
		  % parse_to_point doesn't work here for some reason
		  if (bfind_char('#'))
		    {
		       eol();
		       continue;
		    }
		  eol();
		  
		  list_append(begin, what_line());
		  if (andelse{search_heredoc_end(regexp_nth_match(1), regexp_nth_match(2))}
		       {what_line() < max_line})
		    {
		       list_append(end,  what_line());
		    }
		  else
		    {
		       list_append(end, last_line());
		       break;
		    }
	       }
	  }
	
	goto_line(min_line);
	if (length(begin))
	  {
#ifexists __push_list
	     begin = [__push_list(begin)];
	     end = [__push_list(end)];
#else
	     begin = list2array(begin, Integer_Type);
	     end = list2array(end, Integer_Type);
#endif
	     loop(max_line - min_line + 1)
	       {
		  if (wherefirst(begin < what_line() and end >= what_line()) != NULL)
		    set_line_color(string_color);
		  else
		    set_line_color(0);
		  go_down_1();
	       }
	  }
	else
	  {
	     loop(max_line - min_line + 1)
	       {
		  set_line_color(0);
		  go_down_1();
	       }
	  }
     }
   catch RunTimeError:
     {
	unset_buffer_hook("color_region_hook");
     }
   finally
     {
	pop_spot();
     }   
}

public define ruby_mode()
{
   set_mode(mode, 2);
   use_keymap(mode);
   use_syntax_table(mode);
   set_buffer_hook("color_region_hook", &color_buffer);
   set_buffer_hook("indent_hook", &ruby_indent_line);
   set_buffer_hook("newline_indent_hook", "ruby_newline_and_indent"); 
   runhooks("ruby_mode_hook");
}

provide("ruby");

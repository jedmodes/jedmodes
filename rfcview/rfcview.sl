% rfcview.sl	-*- mode: Slang; mode: Fold -*-
% RFC viewer
% 
% $Id: rfcview.sl,v 1.2 2004/01/18 09:55:57 paul Exp paul $
% Keywords: docs
%
% Copyright (c) 2003 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% Not as pretty as Emacs' rfcview, but more features.
% -Pick rfc's from the rfc-index
% -follow links to other rfc's
% -try to display ToC in separate buffer
% -pop up references with mouse
% -selectively display only headers, or sections matching any of a list
%  of regexps.
%  
% Some of this should go into an outline minor mode.

custom_variable ("Rfc_Path", "/usr/doc/rfc");
custom_variable ("Rfc_Index", "/usr/doc/rfc/rfc-index.txt.gz");

variable mode = "rfcview";
implements("rfcview");

require("view");
_autoload
  ("set_buffer_hidden", "filter-view",
   "set_matching_hidden", "filter_view",
   "string_get_match", "strutils", 3);

%{{{ syntax table

create_syntax_table(mode);
#ifdef HAS_DFA_SYNTAX
%%% DFA_CACHE_BEGIN %%%
static define setup_dfa_callback (mode)
{
   dfa_define_highlight_rule ("RFC ?[0-9]+", "keyword", mode);
   dfa_define_highlight_rule ("^[0-9\\.]+", "preprocess", mode);
   dfa_build_highlight_table(mode);
}
dfa_set_init_callback (&setup_dfa_callback, mode);
%%% DFA_CACHE_END %%%
enable_dfa_syntax_for_mode(mode);
#endif

%}}}

%{{{ find rfc by number
% todo:
% try different compression extensions (cf. info_find_file)
% wget rfc's from the net
public define rfc_mode();

define find_rfc(rfc)
{ 
   % if there are three digits, prepend a 0
   if (strlen(rfc) == 3) rfc = "0" + rfc;
   variable buf = whatbuf, 
     file = search_path_for_file(Rfc_Path, sprintf("rfc%s.txt.gz", rfc));
   if (file == NULL)
     file = search_path_for_file
     (Rfc_Path, sprintf("rfc%s.txt.gz", strtrim_beg(rfc, "0")));
   if (file == NULL)
     error ("file not found");
   ()=read_file(file);
   pop2buf(whatbuf);
   rfc_mode;
   pop2buf(buf);
}

%}}}

%{{{ index

% get RFC from rfc-index
define get_rfc_from_index()
{
   !if (re_bsearch("^[0-9]")) error ("not looking at rfc");
   push_mark;
   skip_chars("0-9");
   find_rfc(bufsubstr);
}

%}}}

%{{{ outline
#ifdef HAS_LINE_ATTR

define hide_body()
{
   set_buffer_hidden(1);
   set_matching_hidden(0, "^[0-9]");
   message("a: show all  s: show section  d: hide section");
}

% (un)hide a section, unhide the first line
define hide_section(hide)
{
   push_spot;
   eol;
   EXIT_BLOCK
     {
	pop_spot;
     }
   !if(re_bsearch("^[0-9]")) return;
   variable first_mark = create_user_mark;
   push_mark;
   go_down_1;
   if(re_fsearch("^[0-9]")) go_left_1; else eob;
   set_region_hidden(hide);
   goto_user_mark(first_mark);
   set_line_hidden(0);
}

variable last_pattern = "";

% rolo for a pattern, or a | separated list of patterns, in the index or
% in the rfc, if it's section headers begin with a number
define rolo()
{
   variable pattern, subpattern;
   !if (_NARGS) read_mini("pattern to rolo for", "", last_pattern);
   pattern = ();
   if (pattern == "") return set_buffer_hidden(0);
   last_pattern = pattern;

   push_spot_bob;
   !if (re_fsearch("^[0-9]")) 
     return pop_spot, message ("no section separators");
   push_spot;
   push_mark_eob;
   set_region_hidden(1);
   foreach (strchop(pattern, '|', '\\'))
     {
	subpattern = ();
	goto_spot;
	while (re_fsearch(subpattern))
	  {
	     set_line_hidden(0);
	     hide_section(0);
	     skip_hidden_lines_forward(0);
	  }
     }
   pop_spot;
   pop_spot;
   message("type 'a' to cancel selective display");
}
#endif

%}}}

%{{{ follow RFC link

define follow_rfc()
{ 
   bskip_chars("0-9");
   bskip_white;
   bskip_chars("RFC");
   push_mark;
   skip_chars("RFC 0-9");
   variable rfc = string_get_match(bufsubstr, "RFC ?\\([0-9]+\\)", 1, 1);
   if (strlen(rfc)) find_rfc(rfc);
   else if (is_substr(whatbuf, "index")) get_rfc_from_index;
}

%}}}

%{{{ ToC

% from toc or index window, scroll other window
define scroll_other(cmd)
{
   variable buf = whatbuf;
   otherwindow;
   ERROR_BLOCK
     {
	pop2buf(buf);
     }
   call(cmd);
   EXECUTE_ERROR_BLOCK;
}

% go to a page from the ToC
define goto_page()
{
   variable pages = get_blocal_var("pages"), mark, buf = whatbuf;
   eol;
   push_mark;
   bskip_chars("0-9");
   variable page = bufsubstr;
   if (andelse
       { strlen(page) }
	 { assoc_key_exists(pages, page)})
     {
	mark = pages[page];
	pop2buf(user_mark_buffer(mark));
	goto_user_mark(mark);
	recenter(1);
     }
   pop2buf(buf);
}

% kill other buffer
define rfc_close_buffer_hook(buf)
{
   variable obuf = get_blocal_var("otherbuffer");
   if (bufferp(obuf))
     delbuf(obuf);
}

%}}}

%{{{ show bibliographic reference

define show_reference(l,c,b,s)
{
   variable ref, ref_mark, first_line, lines = 10;
   push_spot;
   EXIT_BLOCK
     {
	pop_spot;
	1;
     }
   !if (bfind_char('[')) return;
   push_mark;
   !if (ffind_char(']'))
     return pop_mark_0;
   go_right_1;
   ref = bufsubstr;
   eob;
   !if (andelse
       { re_bsearch("^[0-9.]*[ \t]*references") }
	 { fsearch(ref) })
     return;
   ref_mark = create_user_mark;
   goto_spot;
   onewindow();
   splitwindow();
   if (window_info ('t') < 3) otherwindow();
   goto_user_mark(ref_mark);
   push_spot;
   push_mark;
   first_line = what_line;
   eol;
   if (re_fsearch("^[ \t]*\\["))
     lines = what_line - first_line;
   set_region_hidden(0);
   if (lines > 10) lines = 10;
   pop_spot;
   window_info('r') - lines;
   otherwindow;
   loop () enlargewin;
   otherwindow;
   recenter(1);
   otherwindow;
   message ("o: switch to reference window  1: close reference window  0: close this window");
}

%}}}

%{{{ mode for index and rfc

public define rfc_mode()
{
   variable line, page, pages = Assoc_Type[Mark_Type],
     body, toc;
   
   % remove linefeeds
   bob;
   while (bol_fsearch("\f"))
     {
	delete_line;
	bskip_chars("\n");
	line = line_as_string;
	delete_line;
	page = string_get_match(line, "Page +\\([0-9]+\\)", 1, 1);
	if (strlen(page)) pages[string(integer(page) + 1)] = create_user_mark;
	skip_chars("\n");
	if (looking_at("RFC")) delete_line;
	bskip_chars("\n");
	push_mark;
	skip_chars("\n");
	del_region;
	insert("\n\n\n");
     }
   set_buffer_modified_flag(0);

   view_mode;
   set_mode(mode, 0);
   use_syntax_table(mode);
   set_buffer_hook("newline_indent_hook", &follow_rfc);
   set_buffer_hook("mouse_up", &show_reference);

#ifdef HAS_DFA_SYNTAX
   % try to highlight references
   eob;
   if (re_bsearch("^[0-9\\.]*[ \t]*references"))
     {
	variable dfa_table = "rfc_" + whatbuf;
	create_syntax_table(dfa_table);
	dfa_define_highlight_rule ("RFC ?[0-9]+", "keyword", dfa_table);
	dfa_define_highlight_rule ("^[0-9\\.]+", "preprocess", dfa_table);
	while (re_fsearch("^[ \t]*\\(\\[[^\\]]+\\]\\)"))
	  {
	     dfa_define_highlight_rule
	       (str_quote_string(regexp_nth_match(1), "-.[]", '\\'),
		"comment", dfa_table);
	     eol;
	  }
	dfa_build_highlight_table(dfa_table);
	use_syntax_table(dfa_table);
     }
#endif

   % try to find the table of contents
   bob;
   !if (fsearch("table of contents"))
     return;
   push_mark;
   !if (re_fsearch("^[ \t]*\\(1[.0-9]*\\)"))
     return pop_mark_0, bob;
   % try to find end of ToC
   body = regexp_nth_match(1);
   eol;
   !if (bol_fsearch(body))
     return pop_mark_0, bob;
   go_left_1;
   toc = bufsubstr;
   bob;
   variable buffer = whatbuf,
     otherbuffer = sprintf("*ToC for %s*", whatbuf);
   define_blocal_var("otherbuffer", otherbuffer);
   define_blocal_var("close_buffer_hook", &rfc_close_buffer_hook);
   if (bufferp(otherbuffer)) delbuf(otherbuffer);
   sw2buf(otherbuffer);
   define_blocal_var("close_buffer_hook", &rfc_close_buffer_hook);
   define_blocal_var("otherbuffer", buffer);
   insert (toc);
   bob;
   define_blocal_var("pages", pages);
   view_mode;
   use_keymap("rfc_toc");
   set_buffer_hook("newline_indent_hook", &goto_page);
}

%}}}

%{{{ keymaps

$1= _stkdepth;

"delete_window", "0";
"one_window", "1";
"split_window", "2";
"enlarge_window", "^";
"other_window", "o";
". eol \"^[0-9]\" re_fsearch pop 2 recenter", "n";
". bol \"^[0-9]\" re_bsearch pop 2 recenter", "p";

#ifdef HAS_LINE_ATTR
"rfcview->rolo", "?";
% outline-like bindings
"rfcview->hide_body", "t";
"set_buffer_hidden(0)", "a";
"rfcview->hide_section(0)", "s";
"rfcview->hide_section(1)", "d";
#endif

loop ((_stkdepth - $1) /2)
  definekey ("view");

% keymap for ToC and index
!if (keymap_p("rfc_toc"))
  copy_keymap("rfc_toc", "view");
definekey("rfcview->scroll_other(\"page_down\")", " ", "rfc_toc");
definekey("rfcview->scroll_other(\"page_up\")", Key_BS, "rfc_toc");

Help_Message["rfcview"] =
  "Enter: follow link  n: next section  p: previous section  ? search sections";
%}}}

public define rfcview()
{
   () = find_file(Rfc_Index);
   rfc_mode;
   use_keymap("rfc_toc");
}

provide(mode);

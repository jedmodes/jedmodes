% rfcview.sl	-*- mode: Slang; mode: Fold -*-
% RFC viewer
% 
% $Id: rfcview.sl,v 1.7 2009/01/11 09:26:44 paul Exp paul $
% Keywords: docs
%
% Copyright (c) 2003-2009 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% Not as pretty as Emacs' rfcview, but more features.
% -Pick rfc's from the rfc-index
% -follow links to other rfc's
% -try to display ToC in separate buffer
% -pop up references with mouse
% -selectively display only headers, or sections matching any of a list
%  of regexps.

provide("rfcview");
require("curl");
require("view");

% A comma separated list of directories to search for RFC's
custom_variable ("Rfc_Path", "/usr/doc/rfc");

private variable mode = "rfcview";


%{{{ syntax table

create_syntax_table(mode);
#ifdef HAS_DFA_SYNTAX
%%% DFA_CACHE_BEGIN %%%
static define setup_dfa_callback (mode)
{
   dfa_define_highlight_rule ("RFC ?[0-9]+", "keyword1", mode);
   dfa_define_highlight_rule ("^[0-9\\.]+", "preprocess", mode);
   dfa_define_highlight_rule ("\\[RFC ?[0-9]+\\]", "QKkeyword1", mode);
   dfa_define_highlight_rule ("\\[.*\\]", "QKnormal", mode);
   dfa_build_highlight_table(mode);
}
dfa_set_init_callback (&setup_dfa_callback, mode);
%%% DFA_CACHE_END %%%
enable_dfa_syntax_for_mode(mode);
#endif

%}}}
%{{{ rfc fetcher

private define write_callback (v, data)
{
   insert(data);
   return 0;
}

private define get_rfc(rfc)
{
   rfc = strtrim_beg(rfc, "0");
   variable c = curl_new (sprintf("ftp://ftp@ftp.ietf.org/rfc/rfc%s.txt",
				  rfc));
   ()=read_file(sprintf("%s/rfc%s.txt",
			extract_element(Rfc_Path, 0, ','),
			rfc));
   variable v;
   curl_setopt(c, CURLOPT_WRITEFUNCTION, &write_callback, &v);
   curl_perform (c);
   save_buffer();
}
   
%}}}

%{{{ find rfc by number
public define rfc_mode();

private define open_rfc(rfc)
{
   variable file;
   foreach file ([sprintf("rfc%s.txt", rfc),
		 sprintf("rfc%s.txt.gz", rfc),
		 sprintf("rfc%s.txt", strtrim_beg(rfc, "0")),
		 sprintf("rfc%s.txt.gz", strtrim_beg(rfc, "0"))])
     {
	file = search_path_for_file(Rfc_Path, file, ',');
	if (file != NULL)
	  {
	     ()=read_file(file);
	     break;
	  }
     }
   then
     {
	get_rfc(rfc);
     }
   return whatbuf();
}

private define find_rfc(rfc)
{ 
   % if there are three digits, prepend a 0
   if (strlen(rfc) == 3) rfc = "0" + rfc;
   variable buf = whatbuf();
   pop2buf(open_rfc(rfc));
   rfc_mode;
   pop2buf(buf);
}

%}}}

%{{{ index

% get RFC from rfc-index
private define get_rfc_from_index()
{
   ifnot (re_bsearch("^[0-9]")) throw RunTimeError, "not looking at rfc";
   push_mark;
   skip_chars("0-9");
   find_rfc(bufsubstr);
}

%}}}

%{{{ outline
#ifdef HAS_LINE_ATTR

private define hide_body()
{
   set_matching_hidden(0, "^[0-9]");
   message("a: show all  s: show section  d: hide section");
}

% (un)hide a section, unhide the first line
private define hide_show_section(hide)
{
   push_spot;
   eol;
   EXIT_BLOCK
     {
	pop_spot;
     }
   ifnot(re_bsearch("^[0-9]")) return;
   variable first_mark = create_user_mark;
   push_mark;
   go_down_1;
   if(re_fsearch("^[0-9]")) go_left_1; else eob;
   set_region_hidden(hide);
   goto_user_mark(first_mark);
   set_line_hidden(0);
}

private define hide_section()
{
   hide_show_section(1);
}

private define show_section()
{
   hide_show_section(0);
}

private variable last_pattern = "";

% rolo for a pattern, or a | separated list of patterns, in the index or
% in the rfc, if its section headers begin with a number
private define rolo()
{
   variable pattern, subpattern;
   ifnot (_NARGS) read_mini("pattern to rolo for", "", last_pattern);
   pattern = ();
   if (pattern == "") return set_buffer_hidden(0);
   last_pattern = pattern;

   push_spot_bob;
   ifnot (re_fsearch("^[0-9]")) 
     return pop_spot, message ("no section separators");
   push_spot;
   push_mark_eob;
   set_region_hidden(1);
   foreach subpattern (strchop(pattern, '|', '\\'))
     {
	goto_spot;
	while (re_fsearch(subpattern))
	  {
	     set_line_hidden(0);
	     show_section();
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

private define follow_rfc()
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
private define scroll_other(cmd)
{
   variable buf = whatbuf;
   otherwindow;
   try
     {
	call(cmd);
     }
   finally
     {
	pop2buf(buf);
     }
}

private define scroll_other_down()
{
   scroll_other("page_down");
}

private define scroll_other_up()
{
   scroll_other("page_up");
}

% go to a page from the ToC
private define goto_page()
{
   variable pages = get_blocal_var("pages"), mark, buf = whatbuf;
   eol;
   push_mark;
   bskip_chars("0-9");
   variable page = bufsubstr;
   if (strlen(page) && assoc_key_exists(pages, page))
     {
	mark = pages[page];
	pop2buf(user_mark_buffer(mark));
	goto_user_mark(mark);
	recenter(1);
     }
   pop2buf(buf);
}

% kill other buffer
private define rfc_close_buffer_hook(buf)
{
   variable obuf = get_blocal_var("otherbuffer");
   if (bufferp(obuf))
     delbuf(obuf);
}

%}}}

%{{{ show bibliographic reference

private define show_reference(l,c,b,s)
{
   variable ref, ref_mark, first_line, lines = 10;
   push_spot;
   EXIT_BLOCK
     {
	pop_spot;
	1;
     }
   ifnot (bfind_char('[')) return;
   push_mark;
   ifnot (ffind_char(']'))
     return pop_mark_0;
   go_right_1;
   ref = bufsubstr;
   eob;
   ifnot (re_bsearch("^[0-9.]*[ \t]*references") && fsearch(ref))
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
   
   % remove form feeds
   bob;
   push_mark();
   while (bol_fsearch("\f"))
     {
	delete_line;
	bskip_chars("\n");
	line = line_as_string;
	delete_line;
	page = string_get_match(line, "Page +\\([0-9]+\\)", 1, 1);
	exchange_point_and_mark();
	if (strlen(page)) pages[page] = create_user_mark;
	pop_mark_1();
	push_mark();
	skip_chars("\n");
	if (looking_at("RFC")) delete_line;
	bskip_chars("\n");
	push_mark;
	skip_chars("\n");
	del_region;
	insert("\n\n\n");
     }
   pop_mark_0();
   set_buffer_modified_flag(0);

   view_mode;
   use_keymap("rfcview");
   set_mode(mode, 0);
   use_syntax_table(mode);
   set_buffer_hook("newline_indent_hook", &follow_rfc);
   set_buffer_hook("mouse_up", &show_reference);

#ifdef HAS_DFA_SYNTAX
   % try to highlight references
   eob;
   if (re_bsearch("^[0-9\\.]*[ \t]*references"))
     {
	while (re_fsearch("^[ \t]*\\(\\[[^\\]]{1,20}\\]\\)"))
	  {
	     add_keyword(mode, regexp_nth_match(1));
	     eol;
	  }
     }
#endif

   % try to find the table of contents
   bob;
   ifnot (fsearch("table of contents"))
     return;
   push_mark;
   ifnot (re_fsearch("^[ \t]*\\(1[.0-9]*\\)"))
     return pop_mark_0, bob;
   % try to find end of ToC
   body = regexp_nth_match(1);
   eol;
   ifnot (bol_fsearch(body))
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
ifnot (keymap_p("rfcview"))
  copy_keymap("rfcview", "view");

$1= _stkdepth;

"delete_window", "0";
"one_window", "1";
"split_window", "2";
"enlarge_window", "^";
"other_window", "o";
". eol \"^[0-9]\" re_fsearch pop 2 recenter", "n";
". bol \"^[0-9]\" re_bsearch pop 2 recenter", "p";
". \"Enter: follow link  n: next section  p: previous section  ? search sections\" message", "h";

#ifdef HAS_LINE_ATTR
&rolo, "?";
% outline-like bindings
&hide_body, "t";
"set_buffer_hidden(0)", "a";
&hide_section, "d";
&show_section, "s";
#endif

loop ((_stkdepth - $1) /2)
  definekey ("rfcview");

% keymap for ToC and index
ifnot (keymap_p("rfc_toc"))
  copy_keymap("rfc_toc", "rfcview");
definekey(&scroll_other_down, " ", "rfc_toc");
definekey(&scroll_other_up, Key_BS, "rfc_toc");

%}}}

public define rfcview()
{
   sw2buf(open_rfc("-index"));
   rfc_mode();
   use_keymap("rfc_toc");
}


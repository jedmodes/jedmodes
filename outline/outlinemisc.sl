% outlinemisc.sl
% autoloaded functions for outlines
%
% $Id: outlinemisc.sl,v 1.1.1.1 2004/10/28 08:16:24 milde Exp $
% 
% Copyright (c) 2003, 2004 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).

require("outline");
use_namespace("outline");


% convert to html
custom_variable("Outline2html_Begin_Level", 0);

%!%+
%\function{outline2html}
%\synopsis{convert an outline to html}
%\usage{outline2html()}
%\description
%  Converts an outline to html.  Headings are translated to html headings
%  and blank lines to paragraph marks.  It also translates tm-style
%  verbatum marks, hyperlinks and lists.  Nested lists are not supported.
%\seealso{outline_mode}
%!%-
public define outline2html()
{
   variable file, dir, string, level;
   (file, dir, , ) = getbuf_info;
   file = path_sans_extname(file);
   mark_buffer;
   variable contents = bufsubstr;
   ()=find_file(dircat(dir, file) + ".html");
   erase_buffer;
   insert(contents);
   trim_buffer;
   %%% get a list of hyperlinks
   variable links = "";
   bob;
   while (re_fsearch("\\[\\([^\\]]+\\)\\]"))
     {
	links += "\n" + regexp_nth_match(1);
	go_right_1;
     }
   %%% begin markup
   bob;
   variable list = "&,<,>", good_list = "&amp;,&lt;,&gt;", bad, good, n = 0;
   while (bad = extract_element (list, n, ','), bad != NULL)
     {
	good  = extract_element (good_list, n, ',');
	replace (bad, good);
	n++;
     }
   vinsert ("<HTML><HEAD>\n<META name = \"generator\" content = \"Boekholtsoft outline2html\">\n<TITLE>%s</TITLE>\n</HEAD>\n<BODY>\n", file);
   
   %%% code
   bob;
   while (re_fsearch("[ \t]*#v\\+$"))
     {
	del_eol;
	push_mark;
	insert("<pre>");
	if (re_fsearch("[ \t]*#v-$"))
	  {
	     del_eol;
	     insert("</pre>");
	  }
	else error ("unmatched #v+");
	set_region_hidden(1);
     }

   %%% headings
   bob;
   while (bol_fsearch ("*"))
     {
	if(is_line_hidden) 
	  {
	     skip_hidden_lines_forward(1);
	     continue;
	  }
	push_mark;
	skip_chars("*");
	level = POINT + Outline2html_Begin_Level;
	del_region;
	trim;
	string = line_as_string;
	delete_line;
	if (is_list_element(links, string, '\n'))
	  {
	     vinsert("<H%d><A name = \"%s\">%s</A></H%d>\n",
		     level, string, string, level);
	     push_spot_bob;
	     replace(strcat("[", string, "]"), 
		     strcat("<A href=\"#", string, "\">", string, "</A>"));
	     pop_spot;
	  }
	else
	  vinsert("<H%d>%s</H%d>\n", level, string, level);

     }

   %%% paragraphs
   bob;
   while (bol_fsearch("\n"))
     {
	if(is_line_hidden)
	  {
	     skip_hidden_lines_forward(1);
	     continue;
	  }
	insert("<p>");
     }

   %%% lists
   bob;
   variable indent;
   while (re_fsearch("^[ \t]*-"))
     {	
	if(is_line_hidden)
	  {
	     skip_hidden_lines_forward(1);
	     continue;
	  }

	insert ("<UL>\n");
	bol_skip_white;
	do
	  {
	     push_mark;
	     skip_chars("- ");
	     indent = what_column;
	     del_region;
	     insert ("<LI>");
	     while (down_1)
	       {
		  bol_skip_white;
		  if (indent != what_column) break;
	       }
	  }
	while (looking_at_char('-'));
	insert ("</UL>");
     }
   
   %%% end markup
   eob;
   insert("\n</BODY>\n</HTML>\n");
   bob;
   html_mode;
}

% remove "holes" in heading levels
public define normalize_outline()
{
   outline_show_all; % backward_delete_char won't work on hidden lines
   variable level = 1;
   bob;
   while (bol_fsearch("*"))
     {
	skip_chars("*");
	loop (POINT - level)
	  call ("backward_delete_char");
	level = POINT;
	level++;
     }
}

variable last_pattern = LAST_SEARCH;

%!%+
%\function{rolo_grep}
%\synopsis{search for a pattern in an outline}
%\usage{rolo_grep([pattern])}
%\description
%  Searches for regular expression \var{pattern} in an outline. This lets
%  you use an outline as a kind of hierarchical rolodex:
%#v+
%   *    Company
%   **     Manager
%   ***      Underlings
%#v-
%  Searching for Manager turns up all Underlings.  Searching for
%  Company retrieves all listed employees.
%
%\notes
%  The idea is from an Emacs rolo mode by Bob Weiner.
%\seealso{outline_mode}
%!%-
public define rolo_grep() % pattern
{
   variable pattern;
   !if (_NARGS) read_mini("pattern to rolo for", last_pattern, "");
   pattern = ();
   last_pattern = pattern;
   bob;
   !if (bol_fsearch("*")) return;
   push_spot;
   push_mark_eob;
   set_region_hidden(1);
   pop_spot;
   while (re_fsearch(pattern))
     {
	back_to_heading;
	set_line_hidden(0);
	outline_flag_subtree(0,0);
	skip_hidden_lines_forward(0);
     }
}

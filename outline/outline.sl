% outline.sl      -*- mode: SLang; mode: Fold -*-
%
% $Id: outline.sl,v 1.8 2004/03/07 13:06:04 paul Exp paul $
% Keywords: outlines, Emacs
% 
% Copyright (c) 2003 Paul Boekholt
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This file provides a simple outline mode a la Emacs.
if (_featurep("outline"))
  use_namespace("outline");
else
  implements("outline");
provide("outline");
% do you want outlines to be indented?
custom_variable("Outline_Indent", 1);

require ("keydefs");
_autoload("outline2html", "outlinemisc",
	  "normalize_outline", "outlinemisc",
	  "rolo_grep", "outlinemisc", 3);
_add_completion("outline2html", "normalize_outline", "rolo_grep", 3);

autoload("get_word", "txtutils");
static variable header; % the header level of interest
static variable stars = "*********************";

%{{{ hooks

static define outline_parsep_hook()
{
   bol;
   orelse
     {looking_at_char('*')}	% headings
     {skip_white, eolp}		% blank lines
     {looking_at_char('-')}	% listings
     {looking_at("#v+")}
     {looking_at("#v-")};
}

% This will indent continued headings like this
% ***this is a very long
%    heading
%
% It also takes care of lists
%  - item one bla bla ...
%    bla bla
static define outline_wrap_hook()
{
   push_spot;
   go_up_1;
   bol;
   if (looking_at_char('*')) skip_chars("* \t");
   else skip_chars("- \t");
   what_column - 1;
   go_down_1;
   bol_trim;
   whitespace;
   pop_spot;
}

% optional indent hook, indent bodies beyond the asterisks.
static define outline_indent_hook()
{
   go_up_1;
   bol;
   if (andelse {Outline_Indent} {looking_at_char('*')}) skip_chars("* \t");
   else skip_chars(" \t");
   what_column - 1;
   go_down_1;
   bol_trim;
   whitespace;
}

%}}}

%{{{ static functions

static define childp()
{
   looking_at(header + "*");
}

static define back_to_heading()
{
   eol;
   !if(re_bsearch("^\\(\\*+\\)"))
     error("before first heading");
   header = regexp_nth_match(1);
}

% search forward for any header, or a header <= the current level
static define fsearch_header(any)
{
   if (any) return bol_fsearch("*");
   while (bol_fsearch("*"))
     {
	!if(childp())
	  break;
	eol;
     }
   bol;
   return (looking_at_char('*') and not childp());
}

% search backward for a header <= current level, I assume there is at least
% a header there.
static define bsearch_header()
{
   while (bol_bsearch("*"))
     !if(childp())
       return 1;
   return 0;
}

%}}}

%{{{ moving

public define outline_next_heading()
{
   eol();
   if (bol_fsearch("*"))
     bol();
   else
     eob();
}

public define outline_prev_heading()
{
   !if (bol_bsearch("*"))
     bob();
}

public define outline_forward_same_level()
{
   back_to_heading;
   go_down_1;
   !if (fsearch_header(0))
     eob();
}

public define outline_backward_same_level()
{
   back_to_heading;
   () = bsearch_header;
}

public define outline_up_level()
{
   back_to_heading;
   if (strlen(header) < 2)
     error("Already at top level of the outline");
   header = header[[:-2]];
   ()=bsearch_header;
}
%}}}

%{{{ hiding


% This does show/hide tree/body
public define outline_flag_subtree(flag, any)
{
   push_spot;
   ERROR_BLOCK {pop_spot;}
   back_to_heading;
   go_down_1;
   if (looking_at_char('*') and not childp())
     return pop_spot;
   push_mark;
   if (fsearch_header(any))
   {
      go_up_1;
      eol;
   }
   else
     eob;
   if (eobp) 
     {
	!if (bolp) newline;
	go_up_1;
     }
   set_region_hidden(flag);
   pop_spot;
}


% This does show_children and show_branches.
public define show_headers(nograndchildren)
{
   push_spot;
   ERROR_BLOCK {pop_spot;}
   back_to_heading;
   go_down_1;
   while (bol_fsearch("*"))
     {
	!if (childp()) break;
	!if (nograndchildren and looking_at(header + "**"))
	  set_line_hidden(0);
	eol;
     }
   pop_spot;
}

public define hide_body() % (level)
{
   !if (_NARGS) prefix_argument(12);
   variable level = ();
   push_spot_bob;
   !if (bol_fsearch("*")) return pop_spot;
   push_mark_eob;
   set_region_hidden(1);
   bob;
   while(bol_fsearch("*"))
     {
	!if (looking_at(stars[[:level]]))
	  set_line_hidden(0);
	eol;
     }
   eob;
   !if (bolp) newline;
   set_line_hidden(0);
   pop_spot;
}

public define hide_leaves()
{
   outline_flag_subtree(1,0);
   show_headers(0);
}

public define outline_show_all()
{
   push_spot;
   mark_buffer;
   set_region_hidden(0);
   pop_spot;
}

public define outline_hide_other()
{
   push_spot;
   hide_body(1);
   outline_flag_subtree(0, 1);
   back_to_heading;
   set_line_hidden(0);
   pop_spot;
}

%}}}

%{{{ mouse

% right click should cycle nothing -> headings -> all
% [text] should work as a hyperlink
static define outline_mouse(line, col, button, shift)
{
   variable dir, word;
   push_mark;
   EXIT_BLOCK
     {
	pop_mark_1;
	0;
     }
   if (button == 1)
     {
	if (-2 == parse_to_point)
	  {
	     ()=bfind_char('[');
	     go_right_1;
	     push_mark;
	     ()=ffind_char(']');
	     variable str = str_quote_string(bufsubstr, "\\^$*.+?", '\\');
	     bob;
	     if (re_fsearch(strcat("^\\*+ *", str)))
	       {
		  pop_mark_0;
		  push_mark;
		  set_line_hidden(0);
	       }
	  }
	else
	  {
	     (,dir,,) = getbuf_info ();
	     word = strcat (dir, get_word(), ".otl");
	     if (1 == file_status (word))
	       ()=find_file(word);
	  }
	return;
     }
   go_right_1;
   if (is_line_hidden)
     {
	push_mark;
   	skip_hidden_lines_forward(1);
	go_up_1;
	narrow;
	bol_bsearch("*");
	widen;
	pop_mark_1;
	push_mark;
	if ()
	  show_headers(0);
	else
	  outline_flag_subtree(0,0);
     }
   else
     outline_flag_subtree(1,0);
}

%}}}

%{{{ writing

% Insert a heading at the same level as the previous heading
public define outline_heading()
{
   push_spot_bol;
   if (eolp or string_match(line_as_string, "^[ \t]*$", 1))
     {
	bol_trim;
	ERROR_BLOCK {header = "*"; _clear_error; }
	back_to_heading;
	pop_spot;
	insert(header);
     }
   else 
     {
	pop_spot;
	insert_char('*');
     }
}

static define mark_tree()
{
   back_to_heading;
   push_mark;
   outline_forward_same_level;
}

public define move_tree_up()
{
   mark_tree;
   variable tree = bufsubstr_delete;
   ()=bsearch_header;
   push_mark;
   insert(tree);
   exchange_point_and_mark;
   pop_mark_0;
}

public define move_tree_down()
{
   mark_tree;
   variable tree = bufsubstr_delete;
   eol;
   !if (fsearch_header(0)) eob;
   push_mark;
   insert(tree);
   exchange_point_and_mark;
   pop_mark_0;
}

static define slang_verbatim()
{
   insert("\n#v+\n\n#v-");
   go_up_1;
   push_mode("slang");
}

%}}}

%{{{ syntax table, keymap

create_syntax_table ("outline");
define_syntax('*', '#', "outline");
define_syntax("[", "]", '%', "outline");
% define_syntax("#v+", "#v-", '%', "outline");
set_syntax_flags("outline", 0x20 | 0x80);
define_syntax("-a-zA-z_.0-9", 'w', "outline");

% Asterisks are hotspots, you can just type "n" to move to the next
% heading, etc.  The idea is from Emacs' allout mode.
public define hotspot(fun, key)
{
   if (andelse
       {looking_at_char('*')}
	 {push_spot, bskip_chars("*"), bolp, pop_spot})
     eval(fun);
   else insert(key);
}
     
static define define_outline_key(fun, key)
{
   definekey (fun, strcat (_Reserved_Key_Prefix, "^", key), "Outline");
   definekey (sprintf (". \"%s\" \"%s\" hotspot", fun, key), key, "Outline");
}


!if(keymap_p("Outline"))
  make_keymap("Outline");

$1 = _stkdepth;
. ". 1  0 outline_flag_subtree" "d"
. ". 0  0 outline_flag_subtree" "s"
. ". 1  1 outline_flag_subtree" "c"
. ". 0  1 outline_flag_subtree" "e"
. ". 0 show_headers" "k"
. "hide_body" "t"
. "hide_leaves" "l"
. "outline_show_all" "a"
. "outline_hide_other" "o"

. "outline_forward_same_level" "f"
. "outline_backward_same_level" "b"
. "outline_next_heading" "n"
. "outline_prev_heading" "p"
. "outline_up_level" "u"

loop ((_stkdepth - $1) /2)
  define_outline_key();

definekey_reserved(". 1 show_headers", "\t", "Outline");
definekey("outline_heading", "*", "Outline");
definekey("move_tree_up", Key_Alt_Up, "Outline");
definekey("move_tree_down", Key_Alt_Down, "Outline");
definekey_reserved("outline->slang_verbatim", "s", "Outline");
%}}}

%!%+
%\function{outline_mode}
%\synopsis{mode for editing Emacs outlines}
%\description
% Outline mode like Emacs' outline.el, with some features from allout.el
% thrown in.  This is only for real outlines, no outline-minor-mode.
% 
% Headings are lines which start with asterisks: one for major headings,
% two for subheadings, etc.  Lines not starting with asterisks are body
% lines.
% 
% The custom variable \var{Outline_Indent} determines if bodies should
% be indented beyond the asterisks.  You can set this in the modeline:
%  -*- mode: outline; Outline_Indent: 0 -*-
% 
% Keys are exactly like in Emacs, substitute your value of 
% \var{_Reserved_Key_Prefix} for \var{C-c}.
% 
% \var{C-c C-d} hide subtree
% 
% \var{C-c C-s} show subtree
% 
% \var{C-c C-c} hide body under this heading
% 
% \var{C-c C-e} show body of this heading
% 
% \var{C-c C-k} show all headings under this heading
%
% \var{C-c C-t} hide everything in buffer except headings
% 	With prefix, hide headings with level > arg
% 
% \var{C-c C-l} hide everything under this heading except headings
% 
% \var{C-c C-o} hide other stuff except toplevel headings
% 
% \var{C-c C-a} show everything in this buffer
%  	
% \var{C-c C-n} next heading
% 
% \var{C-c C-p} previous heading
% 
% \var{C-c C-f} next heading this level
% 
% \var{C-c C-b} previous heading this level
% 
% \var{C-c C-u} up level
% 
% When the cursor is positioned directly on the bullet character of a
% heading, regular characters invoke the commands of the corresponding
% outline-mode keymap control chars.  For example, \var{f} would invoke
% \var{outline_forward_same_level}, etc.
% 
% \var{C-c TAB} show children of this heading
% 
% \var{M-Up} move tree up
%    moves the current topic and its offspring up over its ancestors to
%    the younger sibling of its parent, or something.
%
% \var{M-Down} move tree down
% 
% Right clicking cycles show nothing -> show headers -> show all
% 
% left clicking on [heading text] jumps to that heading
% 
% Names of other .otl files show up as keywords, left clicking opens them
%\seealso{outline2html, rolo_grep}
%!%-
public define outline_mode()
{
   variable keyword;
   set_buffer_hook("par_sep", &outline_parsep_hook);
   set_buffer_hook("wrap_hook", &outline_wrap_hook);
   run_mode_hooks("outline_mode_hook");
     set_buffer_hook("indent_hook", &outline_indent_hook);
   set_mode("outline", 1);
   use_keymap("Outline");
   loop(directory("*.otl"))	       %  highlighting for other outlines
     {				       %  see also ffap.sl
	keyword=();
	add_keyword("outline", keyword[[:-5]]);
     }
   use_syntax_table("outline");
   set_buffer_hook("mouse_up", &outline_mouse);
}

provide("outline");

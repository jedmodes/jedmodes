% Tree viewer for JED.
% Written by Dino Sangoi.
% Sane keybindings by Paul Boekholt.


require("keydefs");
require("view");
static variable mode = "treemode";

define tree_user()
{
   variable f = get_blocal_var("TreeUserFunc");
   if (f != NULL)
     @f();
}

define tree_goto_line_start()
{
   bol_skip_white();
}

define tree_state()
{
   push_spot();
   tree_goto_line_start();
   what_char(); % On Stack
   pop_spot();
   % returns what_char() result.
}

define tree_get_column()
{
   push_spot();
   tree_goto_line_start();
   what_column(); % On stack
   pop_spot();
   % Return value on stack
}

define _tree_set_mark(mark, first)
{
   variable col1, col2 = 0;

   col1 = tree_get_column();
   push_spot();
   if (down_1)
     {
	col2 = tree_get_column();
	go_up_1;
     }
   if (col2 <= col1)
     mark = ".";

   if (first)
     col1 -= 2;
   goto_column(col1);
   !if (eolp())
     {
	del();
	insert(mark);
     }
   pop_spot();
}

define tree_set_mark(mark)
{
   _tree_set_mark(mark, 0);
   set_buffer_modified_flag(0);
}

define tree_close_all(base)
{
   variable hide;
   bob();
   do
     {
	bol_skip_white();
	hide = (what_column > base);
	set_line_hidden(hide);
	!if (hide)
	  {
	     tree_set_mark("+");
	  }
     }
   while (down_1);
}

define tree_open()
{
   variable pos1, pos2, col;

   push_spot();
   pos1 = tree_get_column();
   if (down_1)
     {
	pos2 = tree_get_column();
	do
	  {
	     !if (is_line_hidden()) break;
	     col = tree_get_column();
	     if (col <= pos1) break;
	     if (col > pos2) continue;
	     set_line_hidden(0);
	     tree_set_mark("+");
	  }
	while (down_1);
     }
   pop_spot();
   tree_set_mark("-");
}

define tree_close()
{
   variable pos1, col;

   push_spot();
   pos1 = tree_get_column();
   if (down_1)
     {
	do
	  {
	     if (is_line_hidden()) continue;
	     col = tree_get_column();
	     if (col <= pos1) break;
	     set_line_hidden(1);
	  }
	while (down_1);
     }
   pop_spot();
   tree_set_mark("+");
}

define tree_close_inside()
{
   switch (tree_state())
     { case '-':
	% special case: we are on an open tree, close this.
	tree_close();
	return;
     }

   variable cur = tree_get_column();
   while (up_1)
     {
	if ((tree_state() == '-') and (tree_get_column() < cur))
	  {
	     tree_close();
	     return;
	  }
     }
   error("no opened tree.");
}

define tree_toggle()
{
   switch (tree_state())
     { case '+' : tree_open(); }
     { case '-' : tree_close(); }
}

!if (keymap_p(mode))
  copy_keymap(mode, "view");
definekey("tree_user", "", mode);
definekey("tree_toggle", " ", mode);
definekey("tree_open", "+", mode);
definekey("tree_close", "-", mode);
definekey("tree_close_inside", Key_Del, mode);

create_syntax_table(mode);
#ifdef HAS_DFA_SYNTAX
static define setup_dfa_callback (name)
{
   %%% Next line commented out for debugging
   % dfa_enable_highlight_cache("treemode.dfa", name);
   dfa_define_highlight_rule("^\\ *\\+\\ ", "keyword", name);
   dfa_define_highlight_rule("^\\ *\\-\\ ", "number", name);
   dfa_define_highlight_rule("^\\ *\\.\\ ", "comment", name);
   dfa_build_highlight_table(name);
}
dfa_set_init_callback (&setup_dfa_callback, mode);
%%% DFA_CACHE_END %%%
#endif

define tree_update_hook()
{
   tree_goto_line_start();
}

define tree_untab_buffer()
{
   push_spot();
   bob();
   push_mark();
   eob();
   untab();
   pop_spot();
}

define tree_mode()
{
   variable file, dir, name, flags;
   (file, dir, name, flags) = getbuf_info();
   file = "";
   name = "tree-"+name;
   setbuf_info(file, dir, name, flags);
   tree_untab_buffer();
   bob;
   push_mark;
   eob();
   if (what_column() == 1)
     go_up_1;
   goto_column(3);
   open_rect();
   bob();
   do
     {
	_tree_set_mark("-", 1);
     }
   while(down_1);
   tree_close_all(1);
   set_overwrite(1);
   set_buffer_modified_flag(0);
   use_keymap(mode);
#ifdef HAS_DFA_SYNTAX
   enable_dfa_syntax_for_mode(mode);
#endif
   set_mode(mode, 0);
   use_syntax_table(mode);
   set_buffer_hook("update_hook", &tree_update_hook);
   define_blocal_var("TreeUserFunc", NULL);
   bob;
}

define tree_user_func(f)
{
   set_blocal_var(f, "TreeUserFunc");
}

provide("mode");

define full_kbd (skey, uskey) {
   if (skey != &local_setkey and skey != &setkey) skey = &local_setkey;
   if (uskey != &local_unsetkey and uskey != &unsetkey) uskey = &local_unsetkey;
   @uskey("ZZ");
   @uskey(">>");
   @skey("self_insert_cmd", "I");
   @skey("self_insert_cmd", "u");
   @skey("self_insert_cmd", "C");
   @skey("self_insert_cmd", "S");
   @skey("self_insert_cmd", "i");
   @skey("self_insert_cmd", "a");
   @skey("self_insert_cmd", "A");
   @skey("self_insert_cmd", "d");
   @skey("self_insert_cmd", "D");
   @skey("self_insert_cmd", "y");
   @skey("self_insert_cmd", "Y");
   @skey("self_insert_cmd", "O");
   @skey("self_insert_cmd", "o");
   @skey("self_insert_cmd", "e");
   @skey("self_insert_cmd", "E");
   @skey("self_insert_cmd", "$");
   @skey("self_insert_cmd", "%");
   @skey("self_insert_cmd", "h");
   @skey("self_insert_cmd", "H");
   @skey("self_insert_cmd", "l");
   @skey("self_insert_cmd", "L");
   @skey("self_insert_cmd", "f");
   @skey("self_insert_cmd", "F");
   @skey("self_insert_cmd", "t");
   @skey("self_insert_cmd", "T");
   @skey("self_insert_cmd", "M");
   @skey("self_insert_cmd", "B");
   @skey("self_insert_cmd", "j");
   @skey("self_insert_cmd", "J");
   @skey("self_insert_cmd", "k");
   @skey("self_insert_cmd", "x");
   @skey("self_insert_cmd", "X");
   @skey("self_insert_cmd", "b");
   @skey("self_insert_cmd", "/");
   @skey("self_insert_cmd", "?");
   @skey("self_insert_cmd", "w");
   @skey("self_insert_cmd", "W");
   @skey("self_insert_cmd", "z");
   @skey("self_insert_cmd", "!");
   if (is_defined("c_insert_ket")) {
      @skey("c_insert_ket", "}");
      @skey("c_insert_bra", "{");
   } else {
      @skey("self_insert_cmd", "}");
      @skey("self_insert_cmd", "{");
   }
   @skey("self_insert_cmd", "G");
   @skey("self_insert_cmd", "n");
   @skey("self_insert_cmd", "N");
   if (is_defined("c_insert_colon"))
     @skey("c_insert_colon" , ":");
   else
     @skey("self_insert_cmd", ":");
   @skey("self_insert_cmd" , "^");
   @skey("self_insert_cmd" , "+");
   if (is_defined("tex_ldots"))
     @skey("tex_ldots",".");
   else
     @skey("self_insert_cmd" , ".");
   @skey("self_insert_cmd" , "-");
   @skey("self_insert_cmd" , "_");
   @skey("self_insert_cmd" , "|");
   @uskey("ggvG");
   @skey("message(\"JED does not support REPLACE mode\")", "\e[2~");
   @skey("self_insert_cmd", "^R");
   @skey("self_insert_cmd", "^L");
   @skey("self_insert_cmd", "^G");
   @skey("self_insert_cmd", "^B");
   @skey("self_insert_cmd", "^D");
   @skey("self_insert_cmd", "^E");
   @skey("self_insert_cmd", "^Y");
   @uskey("^Fb");
   @uskey("^Ff");
   @skey("self_insert_cmd", "^F");
   @skey("self_insert_cmd", "^H");
   @skey("self_insert_cmd", "^J");
   @skey("self_insert_cmd", "^N");
   @skey("self_insert_cmd", "^P");
   @skey("self_insert_cmd", "^U");
   @skey("newline", "^M");
   @skey("self_insert_cmd", "1");
   @skey("self_insert_cmd", "2");
   @skey("self_insert_cmd", "3");
   @skey("self_insert_cmd", "4");
   @skey("self_insert_cmd", "5");
   @skey("self_insert_cmd", "6");
   @skey("self_insert_cmd", "7");
   @skey("self_insert_cmd", "8");
   @skey("self_insert_cmd", "9");
   @skey("self_insert_cmd", "0");
   @skey("self_insert_cmd", "p");
   @skey("self_insert_cmd", "P");
   @skey("next_line_cmd", Key_Down);
   @skey("previous_line_cmd", Key_Up);
   @skey("next_char_cmd", Key_Right);
   @skey("previous_char_cmd", Key_Left);
   @skey("page_down", Key_PgDn);
   @skey("page_up", Key_PgUp);
   if (is_defined("tex_insert_quote")) 
     {
	@skey("tex_insert_quote" , "\"");
	@skey("tex_insert_quote", "'");
   } else 
     {
	@skey("self_insert_cmd", "'");
	@skey("self_insert_cmd", "\"");
     }

   % On some systems, the default keybindings are a little insane,
   % so this fixes some of it.
   @skey("newline_and_indent", "^M");
   
   % Until I figure out a way to let me intercept pure ESC hits, I have
   % to emulate it with the ` key - which means I can't insert it. So,
   % this is a stopgap measure. (I can't just undefine all other command
   % sequences that begin with ESC, because that involves a lot of the
   % menu commands (mousedown, that kind of thing).
   @skey("quoted_insert", "\e`");
}

define full_commandset (skey) {
   if (skey != &local_setkey and skey != &setkey) skey = &local_setkey;
   @skey("eol_cmd", "C");
   @skey("vi_down_endline", "$");
   @skey("vi_match()", "%");
   @skey("skip_white()", "^");
   @skey("down(1); bol(); skip_white()", "+");
   @skey("up(1); bol(); skip_white()", "-");
   @skey("bol(); skip_white()", "_");
   @skey("goto_top_of_window(); bol(); skip_white()", "H");
   @skey("goto_bottom_of_window(); bol(); skip_white()", "L");
   @skey("vi_goto_middle_of_window ();skip_white()", "M");
   @skey("redraw", "^L");
   
   % These are the basic editing commands in vi that
   % cannot happen multiple times
   @skey("if (readonly == 0) set_readonly(0); call(\"undo\"); set_readonly(1)", "u");
   @skey("message(\"JED does not support the REDO feature.\")", "^R");
   @skey("bob(); push_mark(); eob();", "ggvG");
   @skey("whatpos", "^G");
   @skey("vi_simple_search(1)", "n");
   @skey("vi_simple_search(0)", "N");
   @skey("indent_line", ">>");
   @skey("if (readonly == 0) set_readonly(0); call(\"kill_line\"); set_readonly(1)", "D");
   @skey("if (readonly == 0) set_readonly(0); call(\"backward_delete_char\"); set_readonly(1)", "X");
   @skey("bol();push_mark();eol();yp_copy_region_as_kill();pop_mark(0);copylines=1", "Y");
   @skey("vi_colon", ":");
   @skey("vi_redraw", "z");
   
   % These are the basic file manipulation commands
   % and cannot happen multiple times
   @skey("save_buffer; exit_jed", "ZZ");
 
   % These modify the number buffer for commands
   @skey("numbuf = (numbuf * 10) + 1", "1");
   @skey("numbuf = (numbuf * 10) + 2", "2");
   @skey("numbuf = (numbuf * 10) + 3", "3");
   @skey("numbuf = (numbuf * 10) + 4", "4");
   @skey("numbuf = (numbuf * 10) + 5", "5");
   @skey("numbuf = (numbuf * 10) + 6", "6");
   @skey("numbuf = (numbuf * 10) + 7", "7");
   @skey("numbuf = (numbuf * 10) + 8", "8");
   @skey("numbuf = (numbuf * 10) + 9", "9");
   % I'm not including the "move to first column" part of 0 for simplicity
   % There's more than enough ways to do that, and it's complicated
   % to implement. If anyone complains, I may change my mind, but...
   @skey("numbuf = (numbuf * 10)", "0");
   
   % These are commands that can be executed multiple times, or
   % are affected in some other way by the number buffer
   @skey("vi_kill_line", "d");
   @skey("vi_yank", "y");
   @skey("vi_push_line", "p");
   @skey("vi_push_line_before", "P");
   @skey("vi_goto_column", "|");
   @skey("vi_up", Key_Up);
   @skey("previous_line_cmd", "k");
   @skey("vi_up", "^P");
   @skey("vi_down", Key_Down);
   @skey("next_line_cmd", "j");
   @skey("vi_down", "^J");
   @skey("vi_down", "^N");
   @skey("down(1);bol()", "^M");
   @skey("vi_left", Key_Left);
   @skey("previous_char_cmd", "h");
   @skey("vi_left", "^H");
   @skey("vi_right", Key_Right);
   @skey("next_char_cmd", "l");
   @skey("vi_page_down", Key_PgDn);
   @skey("vi_page_down", "^F");
   @skey("vi_scroll_half_fwd", "^D");
   @skey("vi_page_up", Key_PgUp);
   @skey("vi_page_up", "^B");
   @skey("vi_scroll_half_bck", "^U");
   @skey("vi_search (\"/\", 1)", "/");
   @skey("vi_search (\"?\", 0)", "?");
   @skey("vi_c_search ('f')", "f");
   @skey("vi_c_search ('F')", "F");
   @skey("vi_c_search ('t')", "t");
   @skey("vi_c_search ('T')", "T");
   @skey("vi_bskip_word", "b");
   @skey("vi_bskip_word", "B"); % This isn't precisely correct, but there is no Jed equivalent.
   @skey("vi_skip_word", "w");
   @skey("vi_skip_word", "W"); % This isn't precisely correct
   @skey("vi_skip_word", "E"); % This isn't precisely correct either, but hey.
   @skey("vi_skip_word", "e"); % neither is this
   % I'm not implementing ( and ) because there's not Jed equivalent,
   % and it's a lot of work.
   @skey("vi_forward_paragraph", "}");
   @skey("vi_backward_paragraph", "{");
   @skey("vi_goto", "G");
   @skey("message(\"Filtering regions through external commands not yet supported.\")", "!");
   @skey("vi_fwd_del", "x");
   @skey("vi_scroll_fwd", "^E");
   @skey("vi_scroll_bck", "^Y");
   @skey("vi_join", "J");
   @skey("message(\"Keeping track of which commands modify the buffer is not supported.\")", ".");
}

define com_to_edit_modeswitchers (skey, uskey) {
   if (skey != &local_setkey and skey != &setkey) skey = &local_setkey;
   if (uskey != &local_unsetkey and uskey != &unsetkey) uskey = &local_unsetkey;
   @skey("edit_mode()", "i");
   @skey("edit_mode()", "S");
   @skey("edit_mode()", "\e[2~");
   @skey("next_char_cmd; edit_mode())", "a");
   @skey("bol(); edit_mode()", "I");
   @skey("eol(); edit_mode()", "A");
   @skey("bol();insert(\"\n\");up(1);edit_mode()", "O");
   @skey("eol();insert(\"\n\");edit_mode()", "o");
   @skey("quoted_insert", "`");
}

define edit_to_com_modeswitchers (skey, uskey) {
   if (skey != &local_setkey and skey != &setkey) skey = &local_setkey;
   if (uskey != &local_unsetkey and uskey != &unsetkey) uskey = &local_unsetkey;
   @skey("command_mode()", "`");
   @skey("self_insert_cmd", "i");
}

define command_mode () {
   set_status_line("(Jed %v) Vi: -COMMAND- : %b     (%m%a%n%o)  %p   %t", 1);
   % For switching between the two modes
   com_to_edit_modeswitchers(&local_setkey, &local_unsetkey);
   % Re-initialize the global variables
   numbuf = 0;
   commandbuf = "";
   readonly = is_readonly();
   % Lock it down to prevent keys that aren't commands
   set_readonly(1);
   % And pull up the command keys...
   full_commandset(&local_setkey);
}

define edit_mode () {
   set_status_line("(Jed %v) Vi: -INSERT-  : %b     (%m%a%n%o)  %p   %t", 1);
   % For switching between the two modes
   edit_to_com_modeswitchers(&local_setkey, &local_unsetkey);
   % Get the full keyboard
   full_kbd (&local_setkey, &local_unsetkey);
   local_setkey("newline_and_indent", "^M");
   % If the file is supposed to be readonly, let's not unset that - but
   % if it's ok to be written to, unlock it
   if (readonly == 0) {
	 set_readonly(0);
   }
}

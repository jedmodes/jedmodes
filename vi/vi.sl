Help_File = "vi.hlp";

% While starting off in command mode is more vi-like,
% because of the way JED does things, it's difficult to make perfect
% emulation (specifically, you can type while in command mode). So, to
% make it at least more logical, I have to have it start in INSERT mode.
variable BEGIN_IN_COMMAND = 0;

if (BEGIN_IN_COMMAND)
  set_status_line("(Jed %v) Vi: -COMMAND- : %b     (%m%a%n%o)  %p   %t", 1);
else
  set_status_line("(Jed %v) Vi: -INSERT-  : %b     (%m%a%n%o)  %p   %t", 1);

% Global variables
variable numbuf = 0;
variable copylines = 0;
variable commandbuf = "";
variable readonly = 0;
variable last_search = "";

% Standard defines
!if (is_defined ("Key_F1"))
  () = evalfile ("keydefs");
!if (is_defined ("mark_next_nchars"))
  () = evalfile ("search");
!if (is_defined ("full_kbd"))
  () = evalfile ("vimisc");

% For switching between the two modes
if (BEGIN_IN_COMMAND) {
   com_to_edit_modeswitchers(&setkey, &unsetkey);
} else {
   edit_to_com_modeswitchers(&setkey, &unsetkey);
}

% Prevent all the non-command keys in command mode
if (BEGIN_IN_COMMAND)
  set_readonly(1);

% The default binding for the quote keys (", ') is 'text_smart_quote'.
% Most users do not seem to like this so it is unset here.
setkey("self_insert_cmd", "\"");
setkey("self_insert_cmd", "'");

if (BEGIN_IN_COMMAND) {
   full_commandset(&setkey);
} else {
   full_kbd(&setkey, &unsetkey);
   setkey("newline_and_indent", "^M");
}

% This is for folding mode (I'm making the keybindings up, but they seem ok)
define fold_mode_hook ()
{
   local_setkey ("fold_whole_buffer", "w");
   local_setkey ("fold_enter_fold", "^Fl");
   local_setkey ("fold_exit_fold", "^Fj");
   local_setkey ("fold_open_buffer", "^Fp");
   local_setkey ("fold_fold_region", "^Fi");
   local_setkey ("fold_open_fold", "^Fo");
   local_setkey ("fold_close_fold", "^Fu");
   local_setkey ("fold_search_forward", "^Fs");
   local_setkey ("fold_search_backward", "^Fr");
}

% On some systems, the default keybindings are a little insane.
% Little? nay, VERY. This attempts to fix some of it.
setkey("delete_char_cmd", Key_Del);
setkey("backward_delete_char", Key_BS);
setkey("beg_of_line", Key_Home);
setkey("eol_cmd", Key_End);
setkey("newline_and_indent", "^M");
setkey("newline", "\eOM");
setkey("sys_spawn_cmd", "^Z");

% Why is the number pad not implemented properly?
setkey("insert(\".\")","\eOn");
setkey("insert(\"0\")","\eOp");
setkey("insert(\"1\")","\eOq");
setkey("insert(\"2\")","\eOr");
setkey("insert(\"3\")","\eOs");
setkey("insert(\"4\")","\eOt");
setkey("insert(\"5\")","\eOu");
setkey("insert(\"6\")","\eOv");
setkey("insert(\"7\")","\eOw");
setkey("insert(\"8\")","\eOx");
setkey("insert(\"9\")","\eOy");
setkey("insert(\"0\")","\eOz");

% These are the small functions associated with keydowns
define vi_colon () {
   numbuf = 0;
   variable str = "", ch = ' ', force = 0, go = 0, temp = "", i = 0;
   message (commandbuf);
   % This little while loop, however, is 100% mine - faults and all
   while (go != 1) {
	 vmessage (":%s", str);
	 call ("redraw");
	 ch = getkey ();
	 if (ch == '\r')
	   go = 1;
	 % There's gotta be an easier way than this to delete something
	 else if (sprintf("%c", ch) == Key_BS) {
	    if (strlen(str)) {
		  temp = "";
		  for (i=0;i<strlen(str)-1;i++) {
			temp = sprintf("%s%c", temp, str[i]);
		  }
		  str = temp;
	    } else return 1;
	 } else {
	    if (ch == '!') force = 1;
	    str = sprintf("%s%c", str, ch);
	 }
	    }
   !if (strlen(str)) return 1;

   if (str[0] != '%' and str[0] != '.' and str[0] != '$') {
	 variable savefile = 0, openfile = 0, quitjed = 0, insertfile = 0;
	 for (i=0; i<strlen(str); i++) {
	    if (str[i] == 'w') {
		  if (openfile or insertfile) return 1;
		  savefile = 1;
	    } else if (str[i] == 'q') {
		  if (openfile or insertfile) return 1;
		  quitjed = 1;
	    } else if (str[i] == 'e') {
		  if (savefile or quitjed or insertfile) return 1;
		  openfile = 1;
	    } else if (str[i] == 'x') {
		  if (insertfile or openfile) return 1;
	          savefile = 1;
	          quitjed = 1;
	    } else if (str[i] == 'r') {
		  if (savefile or quitjed or openfile) return 1;
		  insertfile = 1;
	    } else if (str[i] == ' ') {
		  temp = "";
		  for (i = i + 1;i<strlen(str);i++) {
			temp = sprintf("%s%c", temp, str[i]);
		  }
	    }
	 }
	 if (savefile) {
	    !if (strlen(temp)) {
		  save_buffer;
	    } else {
		  write_buffer (temp);
	    }
	 }
	 if (openfile) {
	    if (strlen(temp)) find_file (temp);
	    else error("Please specify a file name.");
	 }
	 if (quitjed) {
	    if (force) quit_jed;
	    else exit_jed;
	 }
	 if (insertfile) {
	    if (not(force)) {
		  if (strlen(temp)) insert_file (temp);
		  else error("Please specify a file name.");
	    } else {
		  !if (strlen(temp)) { error("Please provide a command."); return 1; }
		  if (readonly == 0) set_readonly(0);
		  shell_perform_cmd(temp, 1);
		  set_readonly(1);
	    }
	 }
   } else if (str[0] == '%' or str[0] == '.' or str[0] == '$') {
	 variable found = 1;
	 !if (readonly)
	   set_readonly(0);
	 if (str[1] != 's') return;
	 push_spot();
	 variable args = strchop(str, '/', '\\'), confirm = 0;
	 if (length(args) < 3 or length(args) > 4) {
	    args = strchop(str, ';', '\\');
	    if (length(args) < 3 or length(args) > 4) {
		  args = strchop(str, ':', '\\');
		  if (length(args) < 3 or length(args) > 4) {
			args = strchop(str, '*', '\\');
			if (length(args) < 3 or length(args) > 4) {
			   args = strchop(str, '%', '\\');
			   if (length(args) < 3 or length(args) > 4) {
				 args = strchop(str, '@');
				 if (length(args) < 3 or length(args) > 4) {
				    error("Malformed search/replace string.");
				    return 1;
				 }
			   }
			}
		  }
	    }
	 }
	 if (length(args) > 3) {
	    if (string_match(args[3], ".*g.*"))
		 bob();
	    if (string_match(args[3], ".*c.*"))
		 confirm = 1;
	 }
%	 vmessage ("here = %s", args[0]);
%	 return 1;
	 if (strcmp(args[0], "%s")) {
	    error("That search form is not supported yet.");
	    return 1;
	 }
	 variable replacements = 0, lines = 0, curline = 0, response = 0;
	 while (found) {
	    found = re_fsearch(args[1]);
	    if (found) {
		  if (curline != what_line()) {
		    lines++; curline = what_line(); 
		  }
		  if (confirm) {
			response = get_y_or_n ("Replace?");
			if (response == -1) return 1;
			if (response == 1) {
			   found = replace_match(args[2], 0);
			   replacements ++;
			}
		  } else {
			found = replace_match(args[2], 0);
			replacements++;
		  }
	    }
	 }
	 set_readonly(1);
	 pop_spot();
	 if (replacements > 2)
	   vmessage("%i substitutions on %i lines.", replacements, lines);
   }
}

% These are the functions associated with the number buffer
define vi_kill_line () {
   variable here = what_line (), bot = 0;
   variable ch = getkey();
   if (ch != '^' and ch != '$' and ch != 'w' and ch != 'd') return 1;
   if (ch == 'd') {
	 bol ();
	 push_mark ();
	 if (numbuf > 0)
	   down (numbuf - 1);
	 eol ();
   } else if (ch == '^') {
	 push_mark ();
	 if (numbuf > 0)
	   up (numbuf - 1);
	 bol ();
   } else if (ch == '$') {
	 push_mark ();
	 if (numbuf > 0)
	   down (numbuf - 1);
	 eol ();
   } else if (ch == 'w') {
	 push_mark ();
	 if (numbuf == 0) numbuf = 1;
	 for (;numbuf > 0; numbuf --)
	   skip_word ();
   } else {
      return;
   }
   if (readonly == 0) set_readonly(0);
   check_region (1);
   bot = what_line();
   yp_kill_region ();
   if (ch == '$' or ch == 'd') del ();
   if (here - bot > 0) numbuf = here - bot + 1;
   else numbuf = bot - here + 1;
   if (numbuf > 2)
	vmessage ("%i fewer lines.", numbuf);
   pop_mark(0);
   copylines = numbuf;
   numbuf = 0;
   set_readonly(1);
}

define vi_yank () {
   variable here = what_line (), bot = 0;
   variable ch = getkey();
   if (ch != '^' and ch != '$' and ch != 'w' and ch != 'y') return 1;
   push_spot();
   if (ch == 'y') {
	 bol ();
	 push_mark ();
	 if (numbuf > 0)
	   down (numbuf - 1);
	 eol ();
   } else if (ch == '^') {
	 push_mark ();
	 if (numbuf > 0)
	   up (numbuf - 1);
	 bol ();
   } else if (ch == '$') {
	 push_mark ();
	 if (numbuf > 0)
	   down (numbuf - 1);
	 eol ();
   } else if (ch == 'w') {
	 push_mark ();
	 if (numbuf == 0) numbuf = 1;
	 for (;numbuf > 0; numbuf --)
	   skip_word();
   }
%   check_region (1);
   bot = what_line();
   yp_copy_region_as_kill ();
   if (bot - here > 0) numbuf = bot - here + 1;
   else numbuf = here - bot + 1;
   if (numbuf > 2)
	vmessage ("%i lines yanked.", numbuf);
   pop_mark(0);
   pop_spot();
%   if (numbuf > 1) {
%	 up (numbuf - 1);
%	 bol();
%   }
   copylines = numbuf;
   numbuf = 0;
}

define vi_push_line () {
   if (readonly == 0) set_readonly(0);
   eol ();
   insert ("\n");
   yp_yank ();
   if (copylines > 2)
	vmessage ("%i more lines.", copylines);
   numbuf = 0;
   set_readonly(1);
}

define vi_push_line_before () {
   if (readonly == 0) set_readonly (0);
   bol ();
   yp_yank ();
   insert ("\n");
   if (numbuf > 2)
	vmessage ("%i more lines.", copylines);
   numbuf = 0;
   set_readonly(1);
}

define vi_fwd_del () {
   if (readonly != 0) set_readonly(0);
   if (numbuf == 0) numbuf = 1;
   for (; numbuf > 0; numbuf --) call ("delete_char_cmd");
   set_readonly(1);
}

define vi_down_endline () {
   if (numbuf > 1)
	down (numbuf - 1);
   eol();
}

define vi_down () {
   if (numbuf == 0) numbuf = 1;
   for (; numbuf > 0; numbuf --) call ("next_line_cmd");
}

define vi_up () {
   if (numbuf == 0) numbuf = 1;
   for (; numbuf > 0; numbuf --) call ("previous_line_cmd");
}

define vi_left () {
   if (numbuf == 0) numbuf = 1;
   for (; numbuf > 0; numbuf --) call ("previous_char_cmd");
}

define vi_right () {
   if (numbuf == 0) numbuf = 1;
   for (; numbuf > 0; numbuf --) call ("next_char_cmd");
}

define vi_bskip_word () {
   if (numbuf == 0) numbuf = 1;
   for (; numbuf > 0; numbuf --) bskip_word ();
}

define vi_skip_word () {
   if (numbuf == 0) numbuf = 1;
   for (; numbuf > 0; numbuf --) skip_word ();
}

define vi_forward_paragraph () {
   if (numbuf == 0) numbuf = 1;
   for (; numbuf > 0; numbuf --) call ("forward_paragraph");
}

define vi_backward_paragraph () {
   if (numbuf == 0) numbuf = 1;
   for (; numbuf > 0; numbuf --) call ("backward_paragraph");
}

define vi_page_down () {
   if (numbuf == 0) numbuf = 1;
   for (; numbuf > 0; numbuf --) call ("page_down");
}

define vi_page_up () {
   if (numbuf == 0) numbuf = 1;
   for (; numbuf > 0; numbuf --) call ("page_up");
}

define vi_goto () {
   if (numbuf == 0) {
	 eob();
	 return 1;
   }
   goto_line (numbuf);
   numbuf = 0;
}

% This is based on the search in search.sl
define vi_search_across_lines (str, dir) {
   variable n, s, s1, fun, len;
   len = strlen (str);
   fun = &re_fsearch;
   if (dir < 1) fun = &re_bsearch;
   n = is_substr (str, "\n");
   !if (n) {
	 if (@fun (str)) return len;
	 return -1;
   }
   s = substr (str, 1, n);
   s1 = substr (str, n + 1, strlen (str));
   n = strlen(s);
   push_mark ();
   while (@fun(s)) {
	 % we are matched at end of the line.
	 go_right (n);
	 if (looking_at(s1)) {
	    go_left(n);
	    pop_mark_0 ();
	    return len;
	 }
	 if (dir < 0) go_left (n);
   }
   pop_mark_1 ();
   -1;
}

% This is based on the search in srchmisc.sl
define vi_search_maybe_again (fun, str, match_ok_fun, stype) {
   variable ch, len, found = 1, mssg=0;
   if (stype != 0 and stype != 1) stype = 1;
   while (found > 0) {
	 while (len = @fun(str, stype), len >= 0) {
	    found = 3;
	    if (@match_ok_fun ()) {
		  if (EXECUTING_MACRO or DEFINING_MACRO) return 1;
		  if (mssg == 0)
		    message ("Press n or N to continue searching.");
		  else
		    mssg = 0;
		  mark_next_nchars (len, -1);
		  ch = getkey ();
		  if (ch != 'n' and ch != 'N') {
			ungetkey (ch);
			return 1;
		  } else if (ch == 'n') {
			stype = 1;
		  } else
		    stype = 0;
	    }
	    if (stype == 1)
		 go_right_1 ();
	    else
		 go_left_1 ();
	 }
	 if (found == 2)
	   found = 0;
	 if (found == 1)
	   found = 2;
	 if (found > 1) {
	    if (stype == 1) {
		  bob ();
		  message ("search hit BOTTOM, continuing at TOP");
	    } else {
		  eob ();
		  message ("search hit TOP, continuing at BOTTOM");
	    }
	    mssg = 1;
	 }
   }
   return 0;
}

define vi_simple_search (searchtype) {
   variable not_found = 1;
   if (searchtype != 0 and searchtype != 1) searchtype = 1;
   ERROR_BLOCK {
	 pop_mark (not_found);
   }
   if (looking_at (last_search)) go_right_1 ();
   
   not_found = not (vi_search_maybe_again (&vi_search_across_lines, last_search,
								   &_function_return_1, searchtype));
   if (not_found) verror ("%s: not found.", last_search);
   EXECUTE_ERROR_BLOCK;
}

% I found some of this function in the jed documentation
define vi_search (prompt, stype) {
   variable str = "", not_found = 1, ch = 0, go = 0, temp;
   if (stype != 1 and stype != 0) stype = 1;
   % This little while loop, however, is 100% mine - faults and all
   while (go != 1) {
	 vmessage ("%s%s", prompt, str);
	 call ("redraw");
	 ch = getkey ();
	 if (ch == '\r')
	   go = 1;
	 % There's gotta be an easier way than this
      else if (sprintf("%c", ch) == Key_BS) {
	    if (strlen(str)) {
		  variable i = 0;
		  temp = "";
		  for (;i<strlen(str)-1;i++) {
			temp = sprintf("%s%c", temp, str[i]);
		  }
		  str = temp;
	    } else return 1;
	 } else
	    str = sprintf("%s%c", str, ch);
   }

   !if (strlen (str)) return 1;
   
   last_search = str;
   push_mark ();
   ERROR_BLOCK {
	 pop_mark (not_found);
   }
   
   if (looking_at (str)) go_right_1 ();
   
   not_found = not (vi_search_maybe_again (&vi_search_across_lines, str,
								   &_function_return_1, stype));
   if (not_found) verror ("%s: not found.", str);
   EXECUTE_ERROR_BLOCK;
}

define vi_match () {
   variable retval = find_matching_delimiter (0);
   if (retval == 0)
	message ("Match not found.");
   else if (retval = -1)
	message ("A match was attempted from within a string.");
   else if (retval = -2)
	message ("A match was attempted from within a comment.");
   else if (retval = 2)
	message ("Very peculiar.");
}

define vi_goto_column () {
   goto_column(numbuf);
   numbuf = 0;
}

define vi_goto_middle_of_window () {
   goto_bottom_of_window ();
   up (window_info('r')/2);
   bol();
}

define vi_scroll_fwd () {
   variable m = window_line ();
   variable c = what_column ();
   if (numbuf == 0) numbuf = 1;
   if (down(numbuf)) recenter (m);
   goto_column_best_try (c);
}

define vi_scroll_bck () {
   variable m = window_line ();
   variable c = what_column ();
   if (numbuf == 0) numbuf = 1;
   if (up(numbuf)) recenter (m);
   goto_column_best_try (c);
}

define vi_scroll_half_fwd () {
   if (numbuf == 0) {
	 goto_bottom_of_window();
	 recenter(0);
	 bol();
   } else {
	 variable m = window_line ();
	 if (down(numbuf)) recenter(m);
	 bol();
   }
}

define vi_scroll_half_bck () {
   if (numbuf == 0) {
	 goto_top_of_window();
	 recenter(0);
	 bol();
   } else {
	 variable m = window_line ();
	 if (up(numbuf)) recenter(m);
	 bol();
   }
}

define vi_redraw () {
   variable str = "", ch;
   message ("z");
   call ("redraw");
   ch = getkey ();
   str = sprintf("%c", ch);
   if (numbuf) goto_line(numbuf);
   if (ch == '\r') {
	 recenter(1);
   } else if (ch == '.') {
	 recenter(0);
   } else if (ch == '-') {
	 recenter(window_info('r'));
   } else if (str == Key_BS) {
	 return 1;
   } else {
	 message ("Usage: z{<return>|.|-}");
   }
   numbuf = 0;
}

% This is not, technically, perfectly true to VI. I don't care. :-)
define vi_c_search (prompt) {
   variable ch, ch2, str, ret;
   vmessage("%c",prompt);
   call ("redraw");
   ch = getkey();
   str = sprintf ("%c", ch);
   if (prompt == 'f' or prompt == 't') ch2 = '1'; else ch2 = '0';
   if (ch == '\r' or str == Key_BS) return 1;
   else {
	 do {
	    if (ch2 == ',') {
		  left(1);
		  ret = bfind(str);
	    } else if (ch2 == ';') {
		  if (prompt == 't' or prompt == 'T') right(2);
		  else right(1);
		  ret = ffind(str);
	    } else if (ch2 == '1')
		    ret = ffind(str);
	    else
		 ret = bfind(str);
	    if (ret == 0) {
		  message("Not found.");
		  return 1;
	    } else {
		  if (prompt == 't' or prompt == 'T') left(1);
		  message("Press ';' (fwd) or ',' (bk) to continue searching.");
	    }
	    call ("redraw");
	    ch2 = getkey();
	 } while (ch2 == ',' or ch2 == ';');
	 ungetkey(ch2);
   }
}

define vi_join () {
   if (numbuf == 0) numbuf = 1;
   for(;numbuf>0;numbuf --) {
	 eol();
	 call("next_char_cmd");
	 call("backward_delete_char");
   }
}

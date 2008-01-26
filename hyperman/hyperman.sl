% hyperman.sl
%
% $Id: hyperman.sl,v 1.30 2008/01/26 10:48:36 paul Exp paul $
% Keywords: help, hypermedia, unix
%
% Copyright (c) 2000-2008 JED, Paul Boekholt, Günter Milde
% Released under the terms of the GNU GPL (version 2 or later).
% hypertextish man pager

provide ("hyperman");
provide ("man");
require("bufutils");
require("view");
implements("man");
%{{{ customvariables

%!%+
%\variable{Man_Clean_Headers}
%\synopsis{Set whether or not manpage headers are cleaned up}
%\usage{Int_Type Man_Clean_Headers = 0}
%\description
%   Set Man_Clean_Headers to 1, if you have an old man that gives you headers,
%   footers, and blank lines
%\seealso{unix_man}
%!%-
custom_variable("Man_Clean_Headers", 0);

%!%+
%\variable{Man_Use_Extensions}
%\synopsis{Set whether or not unix_man looks for extended section numbers}
%\usage{Int_Type Man_Use_Extensions = 1}
%\description
%   If a link looks like Tk::TList (3pm) we can try man -e pm Tk::Tlist
%   instead of man 3 Tk::Tklist, that may be more reliable.  This differs
%   from Emacs, where man xvidtune(1x) is translated to man 1x xvidtune,
%   but the latter means "man 1x and xvidtune" to my man.
%\seealso{unix_man}
%!%-
custom_variable("Man_Use_Extensions", 1);

%!%+
%\variable{Man_Complete_Whatis}
%\synopsis{Set whether or not unix_man should build a list of completions}
%\usage{Int_Type Man_Complete_Whatis = 1}
%\description
%   Set whether or not to complete in the man prompt.  The list of completions
%   is read in from the file \var{man_completions} in the \var{Jed_Home_Directory}.
%   If the file does not exist, it is generated from the output of "man -w '*'".
%\seealso{unix_man}
%!%-
custom_variable("Man_Complete_Whatis", 1);

%}}}


static variable mode = "man",
#ifnexists _slang_utf8_ok
  man_word_chars = "-A-Za-z0-9_.:+()",
  page_pattern = "\\([-A-Za-z0-9_][-A-Za-z0-9_.:+]*\\)",
  sec_pattern = "(\\([0-9no]\\)\\([a-zA-Z+]*\\))",
#else
  man_word_chars = "-A-Za-z0-9_.:+()\e[]",
  page_pattern = "\\([-A-Za-z0-9_\e\\[\\]][-A-Za-z0-9_.:+\e\\[\\]]*\\)",
  sec_pattern = "(\\([0-9no\e\\[\\]]\\)\\([a-zA-Z+\e\\[\\]]*\\))",
#endif
  man_pattern = sprintf("%s ?%s", page_pattern, sec_pattern);

static variable Man_History = String_Type[16],
  keep_history = 1,
  this_manpage;
% ---- Functions -----------------------------------------------------------

#ifexists _slang_utf8_ok
%{{{ escape sequences
define purge_escapes(str)
{
   variable beg, len;
   while(string_match(str, "\e\\[[0-9]+\\]", 1))
     {
	(beg, len) = string_match_nth(0);
	str = substr(str, 1, beg) + substr(str, beg+len+1, -1);
     }
   return str;
}

variable bold_marker = sprintf("\e[%d]", color_number("keyword")),
italic_marker = sprintf("\e[%d]", color_number("keyword1"));
%}}}

#endif
%{{{ parsing references

static define parse_ref(word)
{
   if (string_match(word, man_pattern, 1))   % e.g. man(5)
     {
        variable sec, page, ext;
        page = string_nth_match(word, 1);
        sec  = string_nth_match(word, 2);
        ext  = string_nth_match(word, 3);

        if (strlen(ext) and Man_Use_Extensions)
          sec = "-e " + ext;

        word = sec + " " + page;
     }
   else if (string_match(word, sprintf("%s(-k)", page_pattern), 1))
     word = "-k " + string_nth_match(word, 1);
   else
     word = strcompress(word, " ");
   return word;  % "5 man", "-e tcl list",
}

% transform:  "5 man"       to "man(5)"
%               "-e tcl exit" to "exit(3tcl)"
%               "man"         to "man"
static define make_ref(subj)
{
   if (string_match(subj, man_pattern, 1))
     return subj;
   subj = strtok(subj, " "); % ["5", "man"] , ["-e", "tcl", "exit"]
   switch (length(subj))
     { case 2: return  sprintf("%s(%s)",subj[1], subj[0]);}
     { case 3 and (subj[0] == "-e "):
        return  sprintf("%s(%s)",subj[2], subj[1]);
     }
     { return subj[-1];}
}
%}}}

%{{{ read a subject
% see below for initialization of this variable
variable man_completions="";

% Read a subject from the minibuffer.
% Can be in the n exit or exit(n) or exit(3tcl) format.
static define man_read_subject()
{
#ifnexists _slang_utf8_ok
   variable word= get_word(man_word_chars);
#else
   variable word= purge_escapes(get_word(man_word_chars));
#endif
   if (is_substr(word, "("))  % maybe it's a C function
     {
	!if (string_match(word, man_pattern, 1))
	  word = strchop(word, '(', 0)[0];
     }
   if (Man_Complete_Whatis)
     word= read_string_with_completion ("man", word, man_completions);
   else
     word = read_mini("man", word, "");
   return word;
}
%}}}

%{{{ clean the page
static define man_mode();
static define man_push_position();

static define man_clean_manpage ()
{
   variable clean = "Cleaning man page...";
   variable section_alist=String_Type[25, 2], sections = 0, line;
   bob ();
   flush (clean);
#ifnexists _slang_utf8_ok
   replace ("_\010", Null_String);	% remove _^H underscores
   while (fsearch ("\010"))	% remove overstrike
     deln (2);
#else
   % fix hyphens if in utf-8 mode
   if (_slang_utf8_ok)
     {
	while(fsearch_char(173))
	  {
	     del;
	     insert_char(173);
	  }
	bob();
     }
   variable ch;
   while(re_fsearch("[^_]\010"))
     {
	insert(bold_marker);
	ch = what_char();
	right(1);
	while(looking_at(sprintf("\010%c", ch)))
	  {
	     deln(2);
	     ch = what_char();
	     right;
	  }
	()=left;
	insert("\e[0]");
     }
   bob;
   while(fsearch("_\010"))
     {
	insert(italic_marker);
	1;
	while(looking_at("_\010"))
	  {
	     deln(2);
	     right;
	  }
	pop;
	insert("\e[0]");
     }
#endif
   if (Man_Clean_Headers)
     {
	variable header;
	% remove headers
	bob ();
	skip_chars ("\n");
	header = line_as_string ();
	go_down_1 ();
	bol ();
	while (bol_fsearch (header))
	  delete_line ();
	% remove footers
	eob ();
	bskip_chars ("\n");
	bol ();
	push_mark_eol ();
	bskip_chars ("1234567890");
	header = bufsubstr ();
	% get rid of spurious empty lines around headers and footers
	bol ();
	while (bol_bsearch (header))
	  {
	     delete_line ();
	     go_up (3);
	     loop (10)
	       {
		  bol();
		  !if (eolp) break;
		  delete_line ();
	       }
	  }
     }
   % remove multiple blank lines
   trim_buffer ();
   % build the sections-list
   bob();
   variable alist_index;
   while (sections <  25)
     {
#ifnexists _slang_utf8_ok
	!if (re_fsearch ("^[A-Z]")) break;
#else
	!if (re_fsearch ("^[\e0-9\\[\\]]*[A-Z]")) break;
#endif
	line = line_as_string;
	if (strlen(line) > 50) continue;   %  header or footer
#ifnexists _slang_utf8_ok
	section_alist[sections, 0] = line;
#else
	section_alist[sections, 0] = purge_escapes(line);
#endif
	section_alist[sections, 1] = string(what_line());
	sections++;
     }
   define_blocal_var("section_list", section_alist);
   define_blocal_var("sections", sections -1);
   bob();
   sw2buf(whatbuf());
   set_buffer_modified_flag (0);
   man_mode;
   man_push_position(this_manpage);
   define_blocal_var("generating_function",
		     ["unix_man", this_manpage]);
   flush (strcat (clean, "done"));
   update (1);
}

%}}}

%{{{ move in the page

public define man_next_section ()
{
   go_down_1 ();
#ifnexists _slang_utf8_ok
   () = re_fsearch ("^[A-Z]");
#else
   () = re_fsearch ("^[\e0-9\\[\\]]*[A-Z]");
#endif
   recenter (1);
}

public define man_previous_section ()
{
#ifnexists _slang_utf8_ok
   () = re_bsearch ("^[A-Z]");
#else
   () = re_bsearch ("^[\e0-9\\[\\]]*[A-Z]");
#endif
   recenter (1);
}

% Go to a section.  In Emacs this is on 'g' but I use that key for
% going to another page like in lynx, so it's on 's'
public define man_goto_section ()
{
   variable section_list = get_blocal_var("section_list"),
   sections = get_blocal_var("sections");
   section_list = section_list[[:sections],*];
   variable names = section_list[*,0], lines = section_list[*,1];
   variable section = read_with_completion
     (strjoin(names, ","), "Go to section", "SEE ALSO", "", 's');
   names = where(section == names);
   if (length(names))
     {
	goto_line(integer(lines[names[0]]));
	recenter(1);
     }
}

public define man_next_reference ()
{
   skip_chars (man_word_chars);
#ifexists _slang_utf8_ok
   go_right_1; % weirdness in searching w/ escape sequences
#endif
   () = re_fsearch (man_pattern);
}

public define man_previous_reference ()
{
   bskip_chars (man_word_chars);
#ifnexists _slang_utf8_ok
   () = re_bsearch (man_pattern);
#else
   if (re_bsearch (man_pattern))
     {
	bskip_chars("\e[]0-9");
	bskip_chars("-a-zA-Z0-9");
     }
   
#endif
}
%}}}

%{{{ Close all man-Buffers
public define man_cleanup()
{
   variable buf;
   loop (buffer_list ())
     {
	buf = ();
	if (is_substr(buf, "*Man"))
	  delbuf(buf);
     }
}
%}}}

%{{{ get the page

static variable man_stack_depth = -1, this_manpage;


static define man(subj)
{
   subj = parse_ref(subj);              % ["man(3)"|"3 man"] -> "3 man"
   this_manpage = subj;
   variable buf = "*Man " + subj + "*";
   if (bufferp (buf))
     return sw2buf (buf);
   % get the manpage
   setbuf (buf);
   set_readonly (0);
   erase_buffer ();
   flush ("Getting man page "+ subj);
   variable man_cmd;
#ifdef OS2
   man_cmd = sprintf("man %s 2> nul", subj);
#else
   man_cmd = sprintf("MANWIDTH=%d man %s 2> /dev/null", SCREEN_WIDTH, subj);
#endif
   variable return_status;
   return_status = run_shell_cmd (man_cmd);
   if (0 != return_status and bobp and eobp)
     {
	delbuf(whatbuf);
	if (16 == return_status)
	  verror("manpage \"%s\" not found", subj);
	else
	  verror("man returned an error (return status %d)",
		 return_status);
     }
   man_clean_manpage;

}
%}}}

%{{{ jump to another page

%{{{ history stack

variable man_history_rotator = [[1:15],0],
  forward_stack_depth = 0;

static define man_push_position(subj)
{
   !if (keep_history)
     return;

   ++man_stack_depth;
   if (man_stack_depth == 16)
     {
        --man_stack_depth;
	Man_History  = Man_History [man_history_rotator];
     }

   Man_History [man_stack_depth] = make_ref(subj);

   forward_stack_depth = 0;
}

public define man_go_back ()
{
   !if (man_stack_depth) return message("Can't go back");
   --man_stack_depth;
   ++forward_stack_depth;
   keep_history = 0;
   man(Man_History[man_stack_depth]);
}

public define man_go_forward()
{
   !if (forward_stack_depth) return message("Can't go forward");
   ++man_stack_depth;
   --forward_stack_depth;
   keep_history = 0;
   man(Man_History[man_stack_depth]);
}

%}}}

% get: page(sec) or page (sec)
static define man_get_ref ()
{
   variable word = "";

   % get word under cursor and neighbours too (to catch page (sec))
   push_spot ();
   push_mark();
   bskip_chars(man_word_chars);
   go_left_1; % maybe this is a " "
   bskip_chars(man_word_chars);
   % get beginning of hyphenated link
   push_spot;
   bskip_white;
   if (bolp)
     {
	go_left(2);
#ifexists _slang_utf8_ok
	if(looking_at_char(']')) {bskip_chars("\e[]0-9"); go_left_1;}
#endif
	if (looking_at_char('­'))
	  {
	     push_mark;
	     bskip_chars(man_word_chars);
	     word = bufsubstr;
	  }
     }
   pop_spot;
   exchange_point_and_mark();
   skip_chars(man_word_chars);
   go_right_1; % maybe this is a " "
   skip_chars(man_word_chars);
   word += strtrim (bufsubstr());
   pop_spot ();

   !if (string_match(word, man_pattern, 1))
     {
	message (word + " is not a man-page");
	return "";
     }
#ifnexists _slang_utf8_ok
   return parse_ref(word); % extract and normalize reference
#else
   return parse_ref(purge_escapes(word)); % extract and normalize reference
#endif
}

public define man_follow()
{
   variable ref = man_get_ref();
   if (ref == "") return;
   keep_history = 1;
   man(ref);
}

%}}}

%{{{ start reading manpages

%!%+
%\function{unix_man}
%\synopsis{Display a man page entry}
%\usage{unix_man([subject])}
%\description
%  Retrieve a man page entry, use clean_manpage to clean it up and
%  display in a buffer in man_mode.  
%  
%\seealso{man_mode, unix_apropos, Man_Clean_Headers, Man_Use_Extensions, Man_Complete_Whatis}
%
%!%-
public define unix_man ()
{
   variable subj;
   if (_NARGS)
     subj = ();
   else
     subj = man_read_subject();
   !if (strlen (subj))
     return;
   keep_history = 1;
   man (subj);
}

%}}}

%{{{ apropos, whatis

%!%+
%\function{unix_apropos}
%\synopsis{search the manual page names and descriptions}
%\usage{unix_apropos([subject])}
%\description
%   Runs "man -k" to get a list of manpages whose names match \var{subject}
%   and display the result in a buffer in \sfun{man_mode}
%\seealso{unix_man}
%!%-
public define unix_apropos()
{
   variable subj;
   if (1 == _NARGS)
     subj = ();
   else
     subj = read_mini ("apropos", "", "");
   subj = "-k " + subj;
   keep_history = 1;
   man (subj);
}

public define unix_whatis()
{
   push_spot;
#ifnexists _slang_utf8_ok
   variable ro = is_readonly(), mo = buffer_modified(), word = get_word("-A-Za-z0-9_.:");
#else
   variable ro = is_readonly(), mo = buffer_modified(),
   word = purge_escapes(get_word("-A-Za-z0-9_.:\e[]0-9"));
#endif
   eol;
   set_readonly(0);
   push_visible_mark;
   newline;
   word = strtrim_beg(word, "-"); % strip '-' from options
   () = run_shell_cmd(strcat("whatis ", word));
   message("hit any key to continue");
   update_sans_update_hook(0);
   % wait for any key and discard the key sequence
   ( , ) = get_key_binding();
   % getkey;
   % if (dup == 'w') pop;
   % else ungetkey;
   del_region;
   set_readonly(ro);
   set_buffer_modified_flag(mo);
   pop_spot;
}

%}}}

%{{{ keybindings & menu

!if (keymap_p (mode))
{
   copy_keymap (mode, "view");
   definekey ("man_follow", "^M", mode);
   definekey ("man_go_back", "l", mode);
   definekey ("man_go_forward", ";", mode);
   definekey ("unix_man", "g", mode);
   definekey ("unix_man", "m", mode);
   definekey ("unix_man", "u", mode);
   definekey ("unix_apropos", "i", mode);
   definekey ("unix_apropos", "a", mode);
   definekey ("unix_whatis", "w", mode);

   definekey ("man_next_section", "n", mode);
   definekey ("man_previous_section", "p", mode);
   definekey ("man_next_reference", "\t", mode);
   definekey ("man_previous_reference", Key_Shift_Tab, mode);
   definekey ("man_next_reference", "f", mode);
   definekey ("man_previous_reference", "b", mode);
   definekey ("man_goto_section", "s", mode);
}

set_help_message("(M)anpage, (A)propos, (W)hatis, (L)ast page, (N)ext section, (P)revious section",
		 "man");

static variable numbers = "123456789abcdefghijklmnop";

static define man_jump_callback(popup)
{
   variable section_list= get_blocal_var("section_list"),
   sections = get_blocal_var("sections"), number;
   _for (0, sections, 1)
     {
	number = ();
	menu_append_item
	  (popup, strlow
	   (sprintf("&%c %s", numbers[number], section_list[number,0])),
	   &goto_line, integer(section_list[number,1]));
     }
   pop_spot();
}

static define man_page_callback(popup)
{
   variable buf;
   loop (buffer_list ())
     {
	buf = ();
	if (is_substr(buf, "*Man"))
	  menu_append_item(popup, buf[[5:]][[:-2]], &sw2buf, buf);
     }
}

static define man_menu(menu)
{
   menu_append_popup (menu, "man pages");
   menu_set_select_popup_callback (menu + ".man pages", &man_page_callback);
   menu_append_popup (menu, "&section");
   menu_set_select_popup_callback(menu+".&section", &man_jump_callback);
   menu_append_item (menu, "&go to page", "unix_man");
   menu_append_item (menu, "&apropos", "unix_apropos");
   menu_append_item (menu, "&what is", "unix_whatis");
   menu_append_item (menu, "&close man buffers", "man_cleanup");
}

%}}}

#ifnexists _slang_utf8_ok
%{{{ Syntax Highlighting

#ifdef HAS_DFA_SYNTAX
create_syntax_table (mode);
%%% DFA_CACHE_BEGIN %%%
static define setup_dfa_callback (mode)
{
   variable word_ch = "A-Za-z0-9:_\\.\\+\\-";
   variable page_pat = sprintf("[A-Za-z0-9_][%s]*",word_ch);
   variable sec_pat = "\\([0-9no][a-zA-Z\\+\\-]*\\)";
   variable man_pat = sprintf("%s%s", page_pat, sec_pat);
   dfa_enable_highlight_cache(mode +".dfa", mode);
   dfa_define_highlight_rule (man_pat, "Qkeyword0", mode);
   man_pat = sprintf("^%s ?%s", page_pat, sec_pat);
   dfa_define_highlight_rule (man_pat, "Qkeyword0", mode);
   dfa_build_highlight_table(mode);
}
dfa_set_init_callback (&setup_dfa_callback, mode);
%%% DFA_CACHE_END %%%
enable_dfa_syntax_for_mode(mode);
#endif

%}}}

#endif
%{{{ mouse support

static define man_mouse(line, col, but, shift)
{
   switch (but)
     { case 1:
	if (re_looking_at (man_pattern)) man_follow;
     }
     { case 4: unix_whatis; }
     { return -1; } % pass wheel scrolling events to the default hook
   1;
}

%}}}

%!%+
%\function{man_mode}
%\synopsis{Mode for reading man pages}
%\usage{man->man_mode()}
%\description
%  The following man commands are available in the buffer.
%  \var{TAB}     move to next manpage reference
%  \var{ENTER}   follow a manpage reference
%  \var{g}       Prompt to retrieve a new manpage.
%  \var{l}       Go back to last visited manpage in history.
%  \var{;}       Go forward in history.
%  \var{p}       Jump to previous manpage section.
%  \var{n}       Jump to next manpage section.
%  \var{s}       Go to a manpage section.
%  \var{w}       Run \sfun{whatis} on the word at point
%  \var{a}       Call \sfun{unix_apropos}
%  \var{q}       Deletes the manpage window, kill its buffer.
%  \var{h}       Give help for man_mode
%\seealso{unix_man}
%!%-
static define man_mode()
{
   view_mode ();
   use_keymap (mode);
#ifnexists _slang_utf8_ok
#ifdef HAS_DFA_SYNTAX
   use_syntax_table(mode);
   use_dfa_syntax(1);
#endif
#else
   _set_buffer_flag(0x1000);
#endif
   set_mode(mode, 0);
   set_buffer_hook("mouse_up", &man_mouse);
   mode_set_mode_info(mode, "init_mode_menu", &man_menu);
   runhooks("man_mode_hook");
}

%{{{ completions initialisation

static define man_read_completions()
{
   variable fp = fopen(dircat(Jed_Home_Directory, "man_completions"), "r");
   if (fp == NULL) return;
#ifnexists _slang_utf8_ok
   () = fread (&man_completions, Char_Type, 1000000, fp);
#else
   () = fread_bytes(&man_completions, 1000000, fp);
#endif
   () = fclose(fp);
}

public define man_make_completions()
{
   flush("initializing completions");
   variable fp = popen
     ("(whatis -w '*' | sed -e 's/).*/),/' | tr -d '\n') 2> /dev/null", "r");
   if (fp == NULL) return;
#ifnexists _slang_utf8_ok
   () = fread (&man_completions, Char_Type, 1000000, fp);
#else
   () = fread_bytes(&man_completions, 1000000, fp);
#endif
   () = pclose(fp);
   fp = fopen(dircat(Jed_Home_Directory, "man_completions"), "w");
   if (fp == NULL) return;
   ()=fputs(man_completions, fp);
   () = fclose(fp);
}

runhooks("man_init_hook");
if(Man_Complete_Whatis)
{
   if(1 != file_status (dircat(Jed_Home_Directory, "man_completions")))
     man_make_completions();
   else
     man_read_completions();
}

%}}}

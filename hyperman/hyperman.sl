% File:          hyperman.sl      -*- mode: SLang; mode: fold -*-
%
% $Id: hyperman.sl,v 1.23 2004/03/26 12:11:05 paul Exp paul $
% Keywords: help, hypermedia, unix
%
% Copyright (c) 2000-2004 JED, Paul Boekholt, Günter Milde
% Released under the terms of the GNU GPL (version 2 or later).
% hypertextish man pager

if (_featurep("man"))
  use_namespace("man");
else
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
%   Set whether or not to build a list of completions from the output
%   of "man -w '*'".
%\notes
%   Building a list of completions every time you run \var{unix_man} for
%   the first time in a JED session is a waste of time - you should
%   use \var{man_save_completions} to save the list of completions to a
%   file and read them in with this hook in your .jedrc:
%#v+
% define man_init_hook()
%  {
%     man_read_completions;
%  }
%#v-
%\seealso{unix_man, man_save_completions, man_read_completions}
%!%-
custom_variable("Man_Complete_Whatis", 1);

%}}}

autoload("get_word", "txtutils");
autoload("string_nth_match", "strutils");
require("bufutils");
require("view");

static variable mode = "man",
  man_word_chars = "-A-Za-z0-9_.:+()",
  page_pattern = "\\([-A-Za-z0-9_][-A-Za-z0-9_.:+]*\\)",
  sec_pattern = "(\\([0-9no]\\)\\([a-zA-Z+]*\\))",
  man_pattern = sprintf("%s ?%s", page_pattern, sec_pattern);

static variable Man_History = String_Type[16],
  keep_history = 1,
  this_manpage;
% ---- Functions -----------------------------------------------------------

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
   variable word= get_word(man_word_chars);
   if (is_substr(word, "("))  % maybe it's a C function
     {
	!if (string_match(word, man_pattern, 1))
	  word = strchop(word, '(', 0)[0];
     }
   
   definekey ("self_insert_cmd", " ", "Mini_Map");
   ERROR_BLOCK 
     {
	definekey ("mini_complete", " ", "Mini_Map");
     }
   word= read_string_with_completion ("man", word, man_completions);
   EXECUTE_ERROR_BLOCK;
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
   replace ("_\010", Null_String);	% remove _^H underscores
   while (fsearch ("\010"))	% remove overstrike
     deln (2);
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
	!if (re_fsearch ("^[A-Z]")) break;
	line = line_as_string;
	if (strlen(line) > 50) continue;   %  header or footer
	section_alist[sections, 0] = line;
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
   () = re_fsearch ("^[A-Z]");
   recenter (1);
}

public define man_previous_section ()
{
   () = re_bsearch ("^[A-Z]");
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
   () = re_fsearch (man_pattern);
}

public define man_previous_reference ()
{
   bskip_chars (man_word_chars);
   () = re_bsearch (man_pattern);
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
   man_cmd = sprintf("man %s 2> /dev/null", subj);
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
   return parse_ref(word); % extract and normalize reference
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
%  The following man commands are available in the buffer.
%  \var{TAB}     move to next manpage reference
%  \var{ENTER}   follow a manpage reference
%  \var{g}       Prompt to retrieve a new manpage.
%  \var{l}       Go back to last visited manpage in history.
%  \var{;}       Go forward in history.
%  \var{p}       Jump to previous manpage section.
%  \var{n}       Jump to next manpage section.
%  \var{s}       Go to a manpage section.
%  \var{w}       Run \var{whatis} on the word at point
%  \var{a}       Call \var{unix_apropos}
%  \var{q}       Deletes the manpage window, kill its buffer.
%  \var{h}       Give help for man_mode
%\seealso{unix_apropos, Man_Clean_Headers, Man_Use_Extensions, Man_Complete_Whatis}
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
%   and display the result in a buffer in \var{man_mode}
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
   variable ro = is_readonly(), word = get_word("-A-Za-z0-9_.:");
   eol;
   set_readonly(0);
   push_visible_mark;
   newline;
   () = run_shell_cmd(strcat("whatis ", word));
   message("hit w to continue");
   update_sans_update_hook(0);
   getkey;
   if (dup == 'w') pop;
   else ungetkey;
   del_region;
   set_readonly(ro);
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
   definekey ("man_goto_section", "s", mode);
}

Help_Message["man"] =
  "(M)anpage, (A)propos, (W)hatis, (L)ast page, (N)ext section, (P)revious section";
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
	  menu_append_item(popup, buf[[5:-2]], &sw2buf, buf);
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
   menu_append_item (menu, "&close man buffers", "man_cleanup");
}

%}}}

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

%{{{ mouse support

static define man_mouse(line, col, but, shift)
{
   if (but == 1)
     {
	if (re_looking_at (man_pattern)) man_follow;
     }
   else unix_whatis;
   1;
}

%}}}

static define man_mode()
{
   view_mode ();
   use_keymap (mode);
#ifdef HAS_DFA_SYNTAX
   use_syntax_table(mode);
   use_dfa_syntax(1);
#endif
   set_mode(mode, 0);
   set_buffer_hook("mouse_up", &man_mouse);
   mode_set_mode_info(mode, "init_mode_menu", &man_menu);
   runhooks("man_mode_hook");
}

%{{{ completions initialisation

%!%+
%\function{man_save_completions}
%\synopsis{save the man_completions list to a file}
%\usage{man_save_completions()}
%\description
%  Save the completions list for \var{unix_man} to a file "man_completions"
%  in the \var{Jed_Home_Directory}.
%\seealso{Man_Complete_Whatis, man_read_completions, unix_man}
%!%-
public define man_save_completions()
{
   variable fp = fopen(dircat(Jed_Home_Directory, "man_completions"), "w");
   if (fp == NULL) return;
   ()=fputs(man_completions, fp);
   () = fclose(fp);
}

%!%+
%\function{man_read_completions}
%\synopsis{read the man_completions from a file}
%\usage{man_read_completions()}
%\description
%   Tries to read the man_completions from the file "man_completions"
%   in the \var{Jed_Home_Directory}
%\seealso{Man_Complete_Whatis, man_save_completions, unix_man}
%!%-
public define man_read_completions()
{
   variable fp = fopen(dircat(Jed_Home_Directory, "man_completions"), "r");
   if (fp == NULL) return;
   () = fread (&man_completions, Char_Type, 1000000, fp);
   () = fclose(fp);
}

static define man_init()
{
   runhooks("man_init_hook");
   if(Man_Complete_Whatis and man_completions == "")
     {
	flush("initializing completions");
	variable str="", fp = popen("(whatis -w '*' | cut -f1 -d ')') 2>/dev/null", "r");
	if (fp == NULL) return;
	() = fread (&str, Char_Type, 1000000, fp);
	() = pclose(fp);
	man_completions = str_replace_all(str, "\n", "),");
     }
}

% initialization
!if (_featurep(mode))
  man_init;

%}}}

provide ("hyperman");
provide (mode);

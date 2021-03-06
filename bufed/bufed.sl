% bufed.sl
%
% $Id: bufed.sl,v 1.5 2007/05/13 08:25:55 paul Exp paul $
%
% Copyright (c) Mark Olesen; (c) 2003-2007 Paul Boekholt
% Released under the terms of the GNU GPL (version 2 or later).
%
% Bufed is a simple buffer manager -- patterned somewhat after dired.
% Provides easy, interactive switching, saving and killing of buffers.
%
% To invoke Bufed, do `M-x bufed'.
% Or re-bind to the key sequence which is normally bound to the
% `list_buffers' function `C-x C-b' (emacs)
%
% Modified by Paul Boekholt to use listing.sl.  Now  you can tag buffers,
% kill, save, and search or replace through tagged  buffers.  The search and
% replacement functions are in bufed_srch.sl.
require("listing");
require("bufutils");


implements("bufed");
autoload ("search_tagged", "bufed_srch");
autoload ("replace_tagged", "bufed_srch");

variable Bufed_buf = "*BufferList*";	% as used by `list_buffers' (buf.sl)

%{{{ extract buffername

% extract the buffer name associated with the current line
% Note: The details of this routine will depend upon how buf.sl formats
%       the line.  Currently, this looks like:
% ----------- 0000    "*scratch*"		    /aluche/h1/davis/src/jed/lib/

define bufed_get ()
{
   variable buf;

   push_spot_bol ();
   try
     {
	!if (ffind_char ('"'))
	  return Null_String;

	go_right_1 ();
	push_mark ();
	!if (ffind_char ('"'))
	  {
	     pop_mark_1 ();
	     return Null_String;
	  }

	buf = bufsubstr ();
	!if (bufferp (buf))
	  {
	     set_readonly(0);
	     delete_line();
	     set_readonly(1);
	     set_buffer_modified_flag(0);
	     buf = "";
	  }
	return buf;
     }
   finally
     {
	pop_spot();
     }
}

%}}}

%{{{ listing buffers

public define list_buffers ()
{
   variable i, j, tmp, this, name, flags, flag_chars, skip;
   variable umask;
   variable name_col, dir_col, mode_col;

   name_col = 21;
   mode_col = 13;
   dir_col = 45;

   skip = 0;
   if (prefix_argument(-1) == -1) skip = 1;
   tmp = "*BufferList*";
   this = whatbuf();
   pop2buf(tmp);
   set_readonly(0);
   erase_buffer();
   TAB = 8;

   flag_chars = "CBKN-UORDAM";
   insert ("  Flags");
   goto_column (mode_col);
   insert ("umask");
   goto_column (name_col);
   insert ("Buffer Name");
   goto_column(dir_col); insert("Dir/File\n");

   loop (buffer_list())
     {
	name = ();
	if (skip and (int(name) == ' ')) continue;   %% internal buffers begin with a space
	flags = getbuf_info (name);    % more on stack
	setbuf(name);
	umask = set_buffer_umask (-1);
	setbuf(tmp);
	bol();
	i = 0x400; j = 0;
	while (i)
	  {
	     if (flags & i) flag_chars[j]; else '-';
	     insert_char (());
	     i = i shr 1; j++;
	  }
	goto_column (mode_col);
	vinsert (" %03o", umask);
	goto_column (name_col);

	% Since the buffername may contain whitespace, enclose it in quotes
	insert_char ('"');
	insert(()); %% buffer name
	insert_char ('"');

	goto_column(dir_col);
	!if (eolp())
	  {
	     eol(); insert_single_space();
	  }

	insert(()); insert(());               %% dir/file
	newline();
     }

   insert("\nU:Undo O:Overwrite R:Readonly D:Disk File Changed, A:Autosave, M:Modified\n");
   insert("C:CRmode, B:Binary File, K:Not backed up, N:No autosave");

   bob ();
   set_buffer_modified_flag (0);
   set_readonly (1);
   pop2buf(this);
}

define bufed_list ()
{
   check_buffers ();
   list_buffers ();
   pop2buf (Bufed_buf);
   set_readonly (0);
   bob();
   insert ("Press '?' for help.  Press ENTER to select a buffer.\n\n");
   set_readonly (0);
   set_buffer_modified_flag(0);
   go_down (1);
   %goto_column (21);
}

%}}}

%{{{ killing buffers

% kill a buffer, if it has been modified then pop to it so it's obvious
define bufed_kill (line)
{
   variable flags, buf = extract_element (line, 1, '"');

   if (buf == NULL) return 0;
   !if (bufferp (buf)) return 2;
   (,,,flags) = getbuf_info (buf);

   if (flags & 1)		% modified
     {
	pop2buf (buf);
	pop2buf (Bufed_buf);
	update (1);
     }
   try
     {
	delbuf (buf);
     }
   catch AnyError:
     {
	pop2buf (Bufed_buf);
	return 1;		       %  untag line
     }
   return 2;			       %  kill line
}

define kill_line ()
{
   listing_map(0, &bufed_kill);
}

define kill_tagged ()
{
   listing_map(2, &bufed_kill);
}

%}}}

%{{{ saving buffers

% save the buffer
define bufed_save (line)
{
   variable file, dir, ch, this_buf;
   variable flags, buf = extract_element (line, 1, '"');

   !if (bufferp (buf)) return 2;

   ch = int (buf);
   if ((ch == 32) or (ch == '*')) return 1;	% internal buffer or special

   (file,dir,,flags) = getbuf_info (buf);

   if (strlen (file) and (flags & 1))	% file associated with it
     {
	setbuf (buf);
	save_buffer();
	setbuf (Bufed_buf);
	return 1;
     }
}

define save_tagged ()
{
   listing_map(1, &bufed_save);
}

%}}}

%{{{ switching to a buffer

% try to re-load the file from disk
define bufed_update ()
{
   variable file, dir, flags;
   (file,dir,,flags) = getbuf_info ();
   if (flags & 2)		% file on disk modified?
     {
	!if (find_file (dircat (dir, file)))
	  throw RunTimeError, "Error reading file";
     }
}

define bufed_pop2buf ()
{
   variable buf = bufed_get ();

   !if (int (buf)) return;

   % if the buffer is already visible, scroll down
   buffer_visible (buf);	% leave on the stack
   pop2buf (buf);
   if (() and not(eobp ()))
     call ("page_down");

   bufed_update ();
   pop2buf (Bufed_buf);
}

define bufed_sw2buf (one)
{
   variable buf = bufed_get ();
   !if (int (buf)) return;
   sw2buf (buf);
   bufed_update ();
   if (one) onewindow ();
}

%}}}

%{{{ change flags
% to do: we might as well update the flags in the bufferlist
define bufed_toggle_flag(line, flag, value)
{
   variable buf = extract_element(line, 1, '"');
   !if (bufferp (buf)) return 2;
   switch (value)
     {case -1: setbuf_info (buf, getbuf_info(buf) xor flag);}
     {case 0: setbuf_info (buf, getbuf_info(buf) & ~flag);}
     {setbuf_info (buf, getbuf_info(buf) | flag);}
   return 0;
}

define change_flag_map()
{
   variable prefix = prefix_argument(-1),
   flagstring="CBKN-UORDAM",
     flag, flagindex;
   message ("Cr, Binary, no bacKup, Undo, Ovwrt, Rdonly, Disk changed, Autosave, Modified?");
   update_sans_update_hook(0);
   flagindex = wherefirst(toupper(getkey()) == bstring_to_array(flagstring));
   if (flagindex != NULL)
     {
	flag = 0x400 shr flagindex;
	listing_map(1, &bufed_toggle_flag, flag, prefix);
     }
}

define bury_tagged ()
{
   listing_map(1, &bufed_toggle_flag, 0x040, 1);
}

%}}}

%{{{ keybindings

variable Bufed_help = "k:kill, s:save, g:refresh, SPC,f:pop2buf, CR,TAB:sw2buf, q:quit, h:help, ?:this help";

define help ()
{
   message (Bufed_help);
}

$1 = "bufed";
!if (keymap_p ($1))   copy_keymap($1, "listing");
definekey ("listing->tag_all(0); bufed_list",	"g",	$1);
definekey ("describe_mode",	"h",	$1);
definekey ("bufed->kill_line",	"k",	$1);
definekey ("bufed->kill_tagged",	"x",	$1);
definekey ("bufed->save_tagged",	"s",	$1);
definekey ("bufed->bufed_pop2buf",	"f",	$1);
definekey ("bufed->bufed_pop2buf",	" ",	$1);
definekey ("bufed->bufed_sw2buf(0)",	"\r",	$1);
definekey ("bufed->bufed_sw2buf(1)",	"\t",	$1);
definekey ("bufed->help",	"?",	$1);
definekey ("bufed->bury_tagged", "b",	$1);
definekey_reserved ("bufed->change_flag_map", "f", $1);
% Analogous to Emacs' dired-do-search.
definekey ("bufed->search_tagged","A",	$1);
definekey ("bufed->replace_tagged", "Q", $1);
rebind_reserved("search_forward", "bufed->search_tagged", $1);
% Emacs has no binding for search_forward, so bind ^c^s too
rebind_reserved("isearch_forward", "bufed->search_tagged", $1);
rebind_reserved("replace_cmd", "bufed->replace_tagged", $1);

%}}}

%{{{ menu

define bufed_menu(menu)
{
   listing->listing_menu(menu);
   menu_append_separator(menu);
   menu_append_item (menu, "&Kill Buffer",  "bufed->kill_line");
   menu_append_item (menu, "Kill Tagged", "bufed->kill_tagged");
   menu_append_item (menu, "&Save", "bufed->save_tagged");
   menu_append_item (menu, "&Bury", "bufed->bury_tagged");
   menu_append_separator(menu);
   menu_append_item (menu, "Search &Forward", 	 "bufed->search_tagged");
   menu_append_item (menu, "R&egexp Search", 	 ". 1 set_prefix_argument bufed_search_tagged");
   menu_append_item (menu, "&Replace", 	 "bufed->replace_tagged");
   menu_append_item (menu, "Regexp Re&place", ". 1 set_prefix_argument bufed_replace_tagged");
}

%}}}

%!%+
%\function{bufed}
%\synopsis{bufed}
%\description
% Mode designed to aid in navigating through multiple buffers
% patterned somewhat after dired.
%
% To invoke Bufed, do \var{M-x bufed} or bind to \var{C-x C-b} (emacs)
%
% \var{g}	Update the buffer listing.
% \var{d}	Tag a buffer
% \var{u}	Untag a buffer
% \var{k} 	Kill the buffer described on the current
% 	line, like typing \var{M-x kill_buffer} and supplying that
% 	buffer name.
%
% \var{x}	Kill the tagged buffers.
% \var{s} 	Save the tagged buffers or the buffer described on the current line.
% \var{b} 	Bury buffers.
% \var{C-c f}
% 	Change buffer flags. Without prefix, toggle.
% 	With prefix 0, turn flag off.  Other prefix, turn on.
% \var{A} 	Search across tagged buffers.  With prefix, do a regexp search.
% \var{Q} 	Replace across tagged buffers.  With prefix, do a regexp replace.
%
% \var{f}, \var{SPC}, \var{CR}, \var{TAB}
% 	Visit the buffer described on the current line.
% 	\var{f} and \var{SPC} will create a new window if required.
% 	\var{CR} will use the current window.
% 	\var{TAB} will revert to a single window.
% \var{q}	Quit bufed mode.
%!%-
public define bufed ()
{
   variable mode = "bufed";
   variable this_buf = sprintf ("\"%s\"", whatbuf ());
   bufed_list ();
   () = fsearch (this_buf);

   help ();
   listing_mode();
   set_mode (mode, 0);
   use_keymap (mode);
   mode_set_mode_info(mode, "init_mode_menu", &bufed_menu);
   run_mode_hooks ("bufed_hook");
}
provide ("bufed");

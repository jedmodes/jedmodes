% turbo.sl  -*- mode: SLang; mode: Fold -*-
% dynamic word completion
% 
% $Id: turbo.sl,v 1.1.1.1 2004/10/28 08:16:27 milde Exp $
% Keywords: abbrev, convenience
% 
% Copyright (c) 2003 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% Another word-completion mode. More proactive than dabbrev - if there is
% a completion it is automatically inserted, like in some IDEs, just
% press TAB to confirm. This uses the keyhook, so you need JED 0.99-16.
% 
% install:
% autoload("turbo_mode", "turbo");
% define text_mode_hook()
% {
%   turbo_mode;
% }

require ("keydefs");
static variable begin = "", completion = "", wordchars = 
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", otherchars = "-'",
  nomatch = 0;

static variable buf, tbuf = "*turbotext*";

static variable turbofile = dircat(Jed_Home_Directory, ".turbotext");

%{{{ turbotext buffer


% switch to the turbotext buffer
static define load_turbo ()
{
   !if (bufferp (tbuf))
     {
	buf;
	() = read_file (turbofile);
	buf = ();		       %  read_file has caused a switch_buffer_hook?
	rename_buffer (tbuf);
     }
   else
     setbuf (tbuf);
}

% add a word to the turbotext list
static define add_turbo()
{
   if (strlen(begin) < 6) return;
   load_turbo;
   eob;
   insert (strtrim_end(begin, otherchars) + "\n");
   begin = "";
   setbuf(buf);
}

% save the turbotext file
static define save_turbo()
{
   !if (bufferp(tbuf)) return 1;
   setbuf(tbuf);
   eob;
   go_up(100);			       %  we only save the last 100 words
   bol;
   push_mark;
   bob;
   del_region;
   () = write_buffer(turbofile);
   1;
}

% look backwards in the turbotext buffer 
static define find_completion()
{
   load_turbo;
   if (bol_bsearch(begin))
     {
	go_right(strlen(begin));
	push_mark_eol;
	completion = bufsubstr;
	setbuf(buf);
	push_visible_mark;
	insert(completion);
	exchange_point_and_mark;
	update_sans_update_hook(0);
	return 1;
     }
   else 
     {
	setbuf(buf);
	nomatch = 1;
	return 0;
     }  
}


%}}}

%{{{ turbotext completion


% read commands while looking at a completion
static define turbo_loop()
{
   variable key;
   EXIT_BLOCK
     {
	setbuf(tbuf);
	eob;
	setbuf(buf);
     }
   forever
     {
	key = getkey;
	% complete this word
	if (key == '\t')
	  {
	     begin += completion;
	     pop_mark_1;
	     return 0;
	  }
	% type more wordchars
	if (is_substr (otherchars + wordchars, char(key)))
	  {
	     % same word
	     if (key == completion[0])
	       {
		  go_right_1;
		  update_sans_update_hook(0);
		  begin += char(key);
		  completion = completion[[1:]];
		  !if (strlen(completion))
		    {
		       pop_mark_0;
		       return 0;
		    }
	       }
	     % maybe earlier word
	     else
	       {
		  del_region;
		  begin += char(key);
		  insert_char(key);
		  !if (find_completion)
		    return 1;
	       }
	  }
	% other command
	else
	  {
	     begin = "";
	     del_region;
	     add_turbo;
	     ungetkey(key);
	     return 0;
	  }
	
     }
}


static define after_key_hook ()
{
   if (orelse
       {is_substr(wordchars, LASTKEY)}
	 {strlen(begin) and is_substr(otherchars, LASTKEY)})
     {
	begin += LASTKEY;
	if (nomatch) return;
	if (strlen(begin) > 3)
	  {
	     if (find_completion) 
	       nomatch = turbo_loop;
	  }
     }
   else if (LASTKEY == Key_BS)
     {
	if (strlen(begin) < 2) begin = "";   %  there should be an easier way
	else begin = begin[[:-2]];
     }
   else
     {
	add_turbo;
	begin = "";
	nomatch = 0;
     }
}


%}}}

%{{{ Turning turbo mode on/off
% Straight from flyspell.sl

static define turbo_switch_active_buffer_hook(oldbuf)
{
   if (get_blocal("turbo", 0))
     {
	buf = whatbuf;
	add_to_hook ("_jed_after_key_hooks", &after_key_hook);
	message ("Turbo is ON");
     }
   else
     remove_from_hook ("_jed_after_key_hooks", &after_key_hook);
}

static define toggle_local_turbo()
{
   variable turbo = not get_blocal("turbo", 0);
   define_blocal_var("turbo", turbo);
   if (turbo)
     set_status_line(str_replace_all(Status_Line_String, "%m", "%m turbo"), 0);
   else
     {
	set_status_line(Status_Line_String, 0);
     }
   turbo_switch_active_buffer_hook("");  % hook expects an argument
}

public define turbo_mode()
{
   toggle_local_turbo();
   add_to_hook("_jed_switch_active_buffer_hooks",
	       &turbo_switch_active_buffer_hook);
}


%}}}

append_to_hook("_jed_exit_hooks", &save_turbo);

provide("turbo");

% File:          hyperman.sl      -*- mode: SLang; mode: fold -*-
%
% Author:        Paul Boekholt <p.boekholt@hetnet.nl>
% 
% $Id: hyperman.sl,v 1.1.1.1 2004/10/28 08:16:21 milde Exp $
%
% hypertextish man pager
% based on man.sl from jed 0.99.15
% to install this add
% 
% autoload("unix_man", "hyperman");
% 
% to .jedrc, or simply rename this file to man.sl
% then edit the function man_clean_manpage if you have an old
% man that gives you headers footers and blank lines
% and add
% 
% variable Man_New_Buffer = 1;
% 
% if you want man pages to get their own buffers, like in Emacs

() = evalfile("most.sl");
custom_variable ("Man_New_Buffer", 0);
static variable this_manpage = "";
static variable manstack = "";
static variable manhistory = "";
static variable word_chars = "-A-Za-z0-9_.:+";

%{{{ clean the page

%!%+
%\function{man_clean_manpage}
%\synopsis{man_clean_manpage}
%\description
% remove _^H and ^H combinations, headers, footers
% and multiple blank lines (man page)
%!%-
static define man_clean_manpage ()
{
   variable clean = "Cleaning man page...";
   variable header;
   bob ();
   flush (clean);
   replace ("_\010", Null_String);	% remove _^H underscores

   while (fsearch ("\010"))	% remove overstrike
     deln (2);	
   
   flush (strcat (clean, "done"));
   return;
   % If your manpages come without headers and superfluous
   % blank lines you don't need the rest.
   
   bob ();			% remove headers  
   skip_chars ("\n");
   header = line_as_string ();
   go_down_1 ();
   bol ();
   while (bol_fsearch (header))
     delete_line ();
 
   eob ();			% remove footers
   bskip_chars ("\n");
   bol ();
   push_mark_eol ();
   bskip_chars ("1234567890");
   header = bufsubstr ();
   bol ();
   while (bol_bsearch (header))	% this gets rid of most of the empty lines around headers and footers
     {
	delete_line ();
	go_up (3);
	loop (10)
	  {
	     bol();
	     if (eolp) delete_line ();
	  }
     }

   trim_buffer ();		% remove multiple blank lines
   flush (strcat (clean, "done"));
}
%}}}

%{{{ move in the page

define man_next_section ()
{
   go_down_1 ();
   () = re_fsearch ("^[A-Z]");
   recenter (1);
}

define man_previous_section ()
{
   () = re_bsearch ("^[A-Z]");
   recenter (1);
}

define man_see_also  ()
{
   !if (bol_fsearch ("SEE ALSO"))
     () = bol_bsearch ("SEE ALSO");
   recenter (1);
}

define man_next_reference ()
{
   skip_chars (word_chars);
   () = re_fsearch (strcat ("[-a-zA-Z0-9_][", word_chars, "]* ?([0-9][a-zA-Z+]*)"));
}
%}}}

%{{{ get the page

static define man (subj)
{
   variable buf;
   this_manpage = subj;

   if (Man_New_Buffer)		% make the buffer
     {
	buf = "*Man " + subj + "*";
	if (bufferp (buf)) 
	  {
	     sw2buf (buf);
	     return;
	  }
     }
   else buf = "*manual-entry*";
   sw2buf (buf);

   set_readonly (0);		% get the manpage
   erase_buffer ();
   flush ("Getting man page");
   variable return_status;
#ifdef OS2
   return_status = run_shell_cmd (sprintf ("man %s 2> nul", subj));
#else
   return_status = run_shell_cmd (sprintf ("man %s 2> /dev/null", subj));
   % this will freeze xjed if run in background from rxvt
#endif
   if (16 == return_status)
     {
	message(sprintf("manpage \"%s\" not found", subj));
	delbuf(whatbuf);
	return;
     }
   if (0 != return_status)
     {
	message ("man returned an error");
	return;
     }
   man_clean_manpage ();
   bob ();
   set_buffer_modified_flag (0);
   most_mode ();
   use_keymap ("Man");
   emacs_recenter (); 		%  this seems to redraw the screen
}
%}}}

%{{{ jump to another page

static define man_get_ref ()
{
   variable subj, section;
   skip_chars (word_chars);
   if (looking_at_char (173))	       %  hyphen  
     {
	skip_chars (" \t\n");
	skip_chars (word_chars);
     }
   push_spot ();		       % spot is at end of page name 

   skip_white ();		       %  get section name
   !if (looking_at_char ('('))
     {
	pop_spot ();
	return 0;
     }
   go_right_1 ();
   push_mark ();
   skip_chars("LNln");
   skip_chars ("0-9");
   skip_chars("A-Z");
   !if (looking_at_char (')'))
     {
	pop_mark_0 ();
	pop_spot ();
	return 0;
     }
   section = bufsubstr ();

   pop_spot ();			       %  get manpage name  
   push_mark ();
   bskip_chars (word_chars);
   subj = bufsubstr ();

   bskip_white();		       %  get first part of name if split
   if (bolp)
     {
	() = left (2);
	if (looking_at_char (173))     %  hyphen  
	  {
	     push_mark ();
	     bskip_chars (word_chars);
	     subj = bufsubstr () + subj;
	  }
     }
   return subj, section, 1;
}

define man_follow ()
{
   variable subj, section;
   push_spot ();
   man_get_ref ();
   pop_spot ();
   !if () return;
   (subj, section) = ();
   manhistory += subj + ",";
   manstack = this_manpage + "," + manstack;

   man (section + " " + subj);
}

define man_last_page ()
{
   if (manstack == "")
     return;
   extract_element (manstack, 0, ',');
   manstack = strjoin (strchop (manstack, ',', 0)[[1:]], ",");
   man ();
}
%}}}

%{{{ start reading manpages 

%!%+
%\function{unix_man}
%\synopsis{unix_man}
%\description
% retrieve a man page entry and use clean_manpage to clean it up
% No apropos, to get apropos enter `-k foo'
% or, if your man doesn't have a -k, enter `;apropos foo' (weird)
%!%-
define unix_man ()
{
   variable subj;
   push_spot ();
   bskip_chars (word_chars);
   push_mark ();
   skip_chars (word_chars);
   subj = bufsubstr ();
   pop_spot ();
   definekey ("self_insert_cmd", " ", "Mini_Map");
   subj = read_string_with_completion ("man", subj, manhistory);
   definekey ("mini_complete", " ", "Mini_Map");
   !if (strlen (subj)) return;
   !if (this_manpage == "")
     manstack = this_manpage + "," + manstack;
   manhistory += subj + ",";
   runhooks("man_mode_hook");
   man (subj);
}
%}}}
   
!if (keymap_p ("Man"))
{
   copy_keymap ("Man", "Most");
   definekey ("man_follow", "^M", "Man");
   definekey ("man_next_section", "n", "Man");
   definekey ("man_previous_section", "p", "Man");
   definekey ("man_next_reference", "\t", "Man");
   definekey ("man_last_page", "l", "Man");
   definekey ("unix_man", "g", "Man");
   definekey ("unix_man", "m", "Man");
   definekey ("man_see_also", "s", "Man");
}

provide ("hyperman");
provide ("man");

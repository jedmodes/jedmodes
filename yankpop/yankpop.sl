% electric yank_pop functions -*- mode: slang; mode: fold -*-
% 
%  $Id: yankpop.sl,v 1.1.1.1 2004/10/28 08:16:27 milde Exp $
%  
%  - yp_yank does the same as standard yp_yank and yp_yank_pop, 
%    but is electric (pops in S-lang loop)
%     + yanked text is highlighted. This is confusing at first, but
%       clearer.
%     + undo stack does not fill up with kill-ring items
%  - yp_yank_repop: pop other way
%  - iyank: incrementally search and yank kill-ring
% 
% Install: put in your path before standard yankpop.sl and think of a
% keybinding for yp_yank_repop. The rest should be self-configuring (the
% new yp_yank_pop calls iyank, iyank and yp_yank use whatever keys
% yp_yank_pop and yp_yank_repop are bound to)

% Note the functions used here are not available on 16 bit systems.
static variable Kill_Buffer_Number = -1;
static variable Kill_Buffer_Yank_Number = -1;
static variable Kill_Buffer_Max_Number = -1;

%{{{ killing

static define append_or_prepend_copy_as_kill (fun)
{
   variable kill_fun = "%kill%";
   if (strcmp (LAST_KBD_COMMAND, kill_fun))
     {
	Kill_Buffer_Number++;
	if (Kill_Buffer_Number == KILL_ARRAY_SIZE)
	  {
	     Kill_Buffer_Number = 0;
	  }

	if (Kill_Buffer_Number > Kill_Buffer_Max_Number)
	  Kill_Buffer_Max_Number = Kill_Buffer_Number;

	copy_region_to_kill_array (Kill_Buffer_Number);
	Kill_Buffer_Yank_Number = Kill_Buffer_Number;
     }
   else
     {
	@fun (Kill_Buffer_Number);
     }

   set_current_kbd_command (kill_fun);
}

define yp_copy_region_as_kill ()
{
   append_or_prepend_copy_as_kill (&append_region_to_kill_array);
}

define yp_kill_region ()
{
   () = dupmark ();
   yp_copy_region_as_kill ();
   del_region ();
}

define yp_prepend_copy_region_as_kill ()
{
   append_or_prepend_copy_as_kill (&prepend_region_to_kill_array);
}

define yp_prepend_kill_region ()
{
   () = dupmark ();
   yp_prepend_copy_region_as_kill ();
   del_region ();
}

define yp_kill_line ()
{
   variable one;
   variable kill_fun = "%kill%";

   one = eolp () or (KILL_LINE_FEATURE and bolp ());

   mark_to_visible_eol ();
   go_right (one);
   yp_kill_region ();
}

define yp_kill_word ()
{
   push_mark(); skip_word();
   yp_kill_region ();
}

define yp_bkill_word ()
{
   push_mark(); bskip_word();
   yp_prepend_kill_region ();
}

%}}}

%{{{ yanking

define yp_yank ()
{
   variable fun_type, fun, i = 0;
   push_visible_mark ();
   
   forever
     {
	insert_from_kill_array (Kill_Buffer_Yank_Number);
	update_sans_update_hook(0);
	ERROR_BLOCK
	  {
	     _clear_error;
	     % this is inside the loop where the error occurs
	  }
	(fun_type, fun) = get_key_binding();
	if (fun == "yp_yank_pop")
	  {
	     
	     Kill_Buffer_Yank_Number--;
	     if (Kill_Buffer_Yank_Number < 0)
	       Kill_Buffer_Yank_Number = Kill_Buffer_Max_Number;
	  }
	else if (fun == "yp_yank_repop")
	  { 
	     Kill_Buffer_Yank_Number++;
	     if (Kill_Buffer_Yank_Number > Kill_Buffer_Max_Number)
	       Kill_Buffer_Yank_Number = 0;
	  }
	else if (fun == "kbd_quit")
	  {
	     del_region;
	     return;
	  }
	else
	  break; 
	del_region();
	push_visible_mark();
     }
   pop_mark_0();
   if(fun_type) call(fun); else eval(fun);

}
%}}}

% see also emacs' substitute-command-keys()
define help_command_key(fun, name)
{
   variable n = which_key(fun);
   !if(n) return "";
   _pop_n(n-1);
   variable key = ();
   (key, )=strreplace(key, "^[", " M-", 10);
   return strcompress(sprintf ("%s : %s", name, key), " ");
}


%{{{ iyank
% incremental kill-ring yanker.
variable last_iyank = "";

% incremental yank
% start yanking with M-y
% type some letters
% type M-y again to find the next match
% type whatever yp_yank_repop is bound to to go back
% hit enter when you're finished, any other key is executed
% type C-g to cancel
static define iyank ()
{
   variable c, s = "", n=Kill_Buffer_Max_Number,
     msg= sprintf ("iyank `%%s'\t  %s  %s  enter: quit   ^G: cancel",
		   help_command_key("yp_yank_pop", "next"),
		   help_command_key("yp_yank_repop", "previous")),
     msg2 = msg, direction = -1,
     fun_type, fun;

   USER_BLOCK0
     {
	()=dupmark;
	forever
	  {
	     del_region;
	     push_mark;
	     if (n < 0 or n > Kill_Buffer_Max_Number)
	       {
		  msg2= "failing " + msg;
		  break;
	       }
	     push_mark;
	     insert_from_kill_array(n);
	     if (is_substr(bufsubstr(), s)) 
	       break;
	     n += direction;
	  }
	pop_mark_0;
     }
   push_visible_mark;
   ERROR_BLOCK
     {
	_clear_error;
	pop;
	% when the error block is outside the scope where the error
	% occurred, whatever the error-generating function pushed, is
	% left. In this case getkey() left a 7 (C-g).
	del_region();
	return;
     }

   forever
     {
	vmessage(msg2, s);
	msg2=msg;
	update(0);
	c =getkey();
	switch (c)

	  { case  127:	% backspace
	     n = Kill_Buffer_Max_Number;
	     if (strlen(s) > 1)
	       {
		  s = s[[:-2]];
		  X_USER_BLOCK0;
	       }
	     else
	       {
		  s = "";
		  del_region();
		  push_visible_mark;
	       }
	  }

	  { case 13 : % enter key
	     last_iyank = s;
	     return pop_mark_0;
	  }

	  { (c <32):
	     ungetkey(c);
	     (fun_type, fun) = get_key_binding();
	     if (fun == "yp_yank_pop")
	       {
		  direction = -1;
		    {
		       if (s == "") % last saved iyank
			 s = last_iyank;
		       else
			 n--;
		       X_USER_BLOCK0;
		    }
	       }
	     else if (fun == "yp_yank_repop")
	       {
		  direction = 1;
		  n++;
		  X_USER_BLOCK0;
	       }
	     else
	       {
		  last_iyank = s;
		  break;
	       }
	  }
	     
	  {		% add to search string
	     s += char(c);
	     X_USER_BLOCK0;
	  }
     }
   pop_mark_0;
   if(fun_type) call(fun); else eval(fun);
}

%}}}

define yp_yank_pop()
{
   iyank();
}

define yp_yank_repop ()
{
   error ("The last command must be a yank one.");
}

provide ("yankpop");

% rimini.sl
% 
% $Id: rimini.sl,v 1.7 2006/10/03 10:31:34 paul Exp paul $
% 
% Copyright (c) 2003,2006 Paul Boekholt
% Released under the terms of the GNU GPL (version 2 or later).
% 
% Bash-like reverse-isearch function for the minibuffer.
% To install add the following to .jedrc:
% autoload ("mini_isearch", "rimini");
% !if (keymap_p ("Mini_Map"))
%   make_keymap ("Mini_Map");
% definekey ("mini_isearch", "^r","Mini_Map");

static variable last_isearch = "";
variable rimini_array=NULL;

% 
%!%+
%\function{mini_isearch}
%\synopsis{Reverse incremental search the minibuffer history}
%\usage{ mini_isearch ()}
%\description
%  Does a reverse incremental search in the minibuffer history, like
%  the Bash shell's \var{^R} command. It can also search in some other
%  array, depending on what keyboard command is being executed. If you
%  have recent.sl, \var{find_file()} will reverse isearch the recent file
%  history.  \var{Switch_to_buffer()} will search the buffer list, a
%  bit like Emacs' iswitchb.  This uses the LAST_KBD_COMMAND, so
%  \var{^R} must be the first thing you type in the minibuffer. You must
%  set \var{switch_buffer_binding} to the keystring \var{switch_to_buffer()}
%  is bound to, if this is not \var{^X b}
%  
%  If a command sets the variable \var{rimini_array}, that will be used
%  instead.  Make sure it gets set to NULL again.  You can give a
%  reference to a function too, this is used in ffap.sl since it's
%  not necessary to run \var{recent_get_files()} until you press \var{^R}.
%  This file redefines \var{read_string_with_completion()}  to set the
%  rimini_array to the list of completions.
%  
%  Press \var{^R} and type some characters to do i-searching.
%  Press \var{^R} twice to search for the last saved search.
%  Press \var{backspace} to backspace over your search string.
%  Press \var{^R} again to search next occurrence.
%  Press \var{^S} to go back to previous occurrence.
%  Press \var{^G} to abort.
%  Any other key is stuffed back into the keystroke buffer and puts the
%  found entry in the minibuffer (so \var{^M} will enter it immediately).
%   
%\seealso{ffap}
%!%-
public define mini_isearch ()
{
   variable lines, c, s = "", n;
   if (rimini_array != NULL)
     {
	ERROR_BLOCK
	  {
	     rimini_array = NULL;
	  }
	if (Array_Type == typeof(rimini_array))
	  lines = rimini_array;
	else if (Ref_Type == typeof(rimini_array))
	  lines = @rimini_array;
	else lines = mini_get_lines(NULL);
	EXECUTE_ERROR_BLOCK;
     }
   else if (andelse
	    {is_defined("recent_get_files")}	
	    % get a version of recent with recent_get_files!
	      {is_list_element("find_file insert_file",
			       get_key_binding(LAST_KBD_COMMAND), exch, pop, ' ')})
     {
	lines = @__get_reference("recent_get_files");
	lines = lines[[::-1]];
     }
   else if (get_key_binding(LAST_KBD_COMMAND), exch, pop == "switch_to_buffer")
     lines = [buffer_list(), pop];
   else lines = mini_get_lines(NULL);
   variable matches = NULL;
   variable default="";
   bol;
   push_mark_eol;
   default = bufsubstr;
   erase_buffer();
   insert ("isearch `':");
   update(0);
   USER_BLOCK0
     {
	n = 0;
	matches = lines[where(array_map(Integer_Type, &is_substr, lines, s))];
	if (length(matches))
	  {
	     erase_buffer();
	     insert(strcat ("isearch `", s, "': ", matches[-1]));
	     bol;
	     () = ffind (":");
	     () = ffind (s);
	     update(1);
	  }
	else
	  {
	     erase_buffer();
	     insert(strcat ("isearch `", s, "': no match"));
	     update(1);
	  }
     }
   ERROR_BLOCK
     {
   	pop; % C-g left on stack
   	_clear_error;
   	erase_buffer();
   	insert(default);
     }

   forever
     {
	c = getkey();
	switch (c)
	  { case 18:	% ^r - search next occurrence
	     if (s == "")
	       {	% pressing ^r twice gives you the last saved isearch
		  s = last_isearch;
		  X_USER_BLOCK0;
	       }
	     else if (length (matches) == 1 + n)
	       beep();
	     else
	       {
		  n++;
		  erase_buffer();
		  insert(strcat ("isearch `", s, "': ", matches[-1 -n]));
		  bol;
		  () = ffind (":");
		  () = ffind (s);
		  update(1);
	       }
	  }
	  { case 19:	% ^s - previous occurrence
	     if (n == 0)
	       beep();
	     else
	       {
		  n--;
		  erase_buffer();
		  insert(strcat ("isearch `", s, "': ", matches[-1 -n]));
		  bol;
		  () = ffind (":");
		  () = ffind (s);
		  update(1);
	       }
	  }
	  { case  127 :	% backspace
	     if (strlen(s) > 1)
	       {
		  s = s[[:-2]];
		  X_USER_BLOCK0;
	       }
	     else
	       {
		  s = "";
		  matches = NULL;
		  erase_buffer();
		  insert ("isearch `':");
		  update(0);
	       }
	  }

	% Do we need something for '\e'? (See isearch.sl)

	  {
#ifdef IBMPC_SYSTEM 	% This OK?  I don't have an IBM.
	    case 0xE0 or	% \224: prefix for cursor keys on IBM
#endif
	     (c < 32) :	% stop searching, ungetkey (if you pressed 
			% enter it will be entered immediately)
	     erase_buffer();
	     if (andelse { matches != NULL} {length(matches)})
	       {
		  last_isearch = s;
		  insert(matches[-1 -n]);
	       }
	     else insert(default);
	     ungetkey(c);
	     break;
	  }
	  {		% add to search string
	     s += char(c);
	     X_USER_BLOCK0;
	  }
     }
}

define read_string_with_completion (prompt, dflt, list)
{
   rimini_array=strchop(list, ',', 0);
   ERROR_BLOCK
     {
	rimini_array = NULL;
     }
   read_with_completion (list, prompt, dflt, Null_String, 's');
   EXECUTE_ERROR_BLOCK;
}

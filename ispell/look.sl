% look.sl
%
% Author:        Paul Boekholt
%
% $Id: look.sl,v 1.9 2005/09/18 07:21:31 paul Exp paul $
% 
% Copyright (c) 2003,2005 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
%
% This file provides completion of words from the system dictionary.  This
% was adapted from the BSD look program.
provide ("look");

require("ispell_common");
use_namespace("ispell");
private variable fp, word, l;
private variable keys_string = "0123456789abcdefghijklmnopqrstuvwxyz";
private variable look_max_hits = strlen(keys_string);
private variable keys = Char_Type[look_max_hits];
init_char_array(keys, keys_string);

private define skip_past_newline(p)
{
   variable ch, s;
   ()=fseek(fp, p, SEEK_SET);
   ()=fgets(&s, fp);
   return ftell(fp);
}

private define compare(p)
{
   variable s2;
   ()=fseek(fp, p, SEEK_SET);
   ()=fgets(&s2, fp);
   return strncmp(word, strlow(s2), l);
}

private define binary_search(front, back)
{
   ()=fseek(fp, front, SEEK_SET);
   variable p = (back - front) / 2;
   p = skip_past_newline(p);

   while (p < back and back > front) 
     {
	if (compare(p) > 0) front = p;
	else back = p;
	p = front + (back - front) / 2;
	p=skip_past_newline(p);
     }
   return front;
}

private define linear_search(front)
{
   variable c, s, result = 0;
   ()=fseek(fp, front, SEEK_SET);
   loop (look_max_hits)
     {
	if (-1 == fgets(&s, fp)) break;
	c =  (strncmp(word, strlow(s), l));
	if (c > 0) continue;
	if (c < 0) break;
	s;
     }
}

% Case insensitive binary search dictionary lookup. Returns matches as an
% array of words.
define look(w, file)
{
   word=w;
   l=strlen(w);
   fp = fopen(file, "r");
   if (fp == NULL) verror ("could not open file %s", file);
   variable front, back, result;
   ()=fseek(fp, 0, SEEK_SET);
   front = ftell(fp);
   ()=fseek(fp, 0, SEEK_END);
   back = ftell(fp);
   front = binary_search(front, back);
   result = [w, linear_search(front)];
   result = result[[1:]];
   ()=fclose(fp);
   return result;
}


% Complete word by looking it up in the system dictionary.
% Has little to do with ispell, but in Emacs it's called ispell-complete.

public define ispell_complete()
{
   variable word, new_word, buf = whatbuf, cbuf = "*completions*",
     num_win = nwindows, obuf, n, completions, num,
     wordlen, lookfun;
   _pop_n(_NARGS);
   push_spot;
   push_mark;
   ispell_beginning_of_word;	       %  The Dutch dictionary does have
   				       %  "-'" chars in words
   word = bufsubstr;
   wordlen = strlen(word);
   pop_spot;
   word = strlow(word);
   if (ispell_wordlist == "") return message ("no wordlist");
   completions = look(word, ispell_wordlist);
   !if (length(completions)) return message ("no completions");
   % try to complete a part
   variable first_completion = completions[0];
   variable last_completion = completions[-1];
   if (length(completions) < look_max_hits - 1
       and not strncmp (first_completion, last_completion, 1 + strlen (word)))
     {
	% is there a simple way to find a common beginning of two strings?
	variable len = strlen (first_completion);
	% Either first_completion is a substring of last_completion,
	% or they differ somewhere, so this won't give an array range error
	variable i;
	for (i = 0; i < len; i++)
	  if (first_completion[i] != last_completion[i])
	    break;
	i--;

	insert (strtrim_end(first_completion[[wordlen:i]], "\n"));
	return;
     }

   obuf = pop2buf_whatbuf(cbuf);
   erase_buffer;
   for (i = 0; i < length (completions); i++)
      {
    	vinsert ("(%c)  %s", keys[i], completions[i]);
      }

   buffer_format_in_columns;
   bob;
   insert ("completions for " + word + "\n");

   ERROR_BLOCK
     {
	sw2buf(obuf);
	pop2buf(buf);
	if (num_win == 1) onewindow();
	bury_buffer(cbuf);
     }

   set_buffer_modified_flag(0);
   message ("Enter choice (SPACE to leave unchanged)");

   update_sans_update_hook(0);
   variable c = getkey();
   if (c == ' ')
     {
	sw2buf(obuf);
	pop2buf(buf);
	if (num_win == 1) onewindow();
	bury_buffer(cbuf);
	return;
     }
   sw2buf(obuf);
   pop2buf(buf);
   num = where (c == keys);
   if (length(num))
     insert (strtrim_end(completions[num[0]][[wordlen:]]));
   if (num_win == 1) onewindow();
   bury_buffer(cbuf);
}


% look.sl
%
% Author:        Paul Boekholt
%
% $Id: look.sl,v 1.7 2003/09/23 09:41:47 paul Exp $
% 
% Copyright (c) 2003 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
%
% This file provides dictionary lookup and completion of words from the
% system dictionary.  This is a list of words in case insensitive
% lexicographic order separated by newlines.
require("ispell_common");
require("bufutils");
use_namespace("ispell");

% use look program or internal function to lookup words? Internal function
% is slow to start and uses huge amount of memory, but may be better for
% looking up words with non-alphanumeric characters or doing 100s of
% lookups.
custom_variable("ispell_lookup_fun", "lookup_words");
static variable dict_array = NULL, look_list = NULL;
% If I remove the newlines at the ends, it takes forever
static variable dict_length;

% Case insensitive binary search dictionary lookup. Returns matches as an
% array of words. If you change the list, the old one is forgotten, so
% don't switch to and fro between wordlists.
public define look(word, list)
{
   if (dict_array == NULL or list != look_list)
     {
	dict_array = arrayread_file(list);
	dict_length = length(dict_array) - 1;
	look_list = list;
     }
   variable word_length, this_word,
     first_line = 0, this_line, second_line;
   word = strlow(word);
   word_length = strlen(word);
   second_line = dict_length;
   this_line = second_line / 2;
   forever
     {
	this_word = strlow(substr(dict_array[this_line], 1, word_length));
	if (this_word < word)
	  {
	     this_line;
	     this_line = (second_line + this_line) / 2;
	     first_line = ();
	  }
	else if (this_word > word)
	  {
	     this_line;
	     this_line = (first_line + this_line) / 2;
	     second_line = ();
	  }
	else
	  break;
	if (second_line - first_line < 2) break;
     }
   while (strlow(substr(dict_array[first_line], 1, word_length)) < word) first_line++;
   while (strlow(substr(dict_array[second_line], 1, word_length)) > word) second_line--;
   % If there was no match, second_line will now be one less than first_line
   if (second_line < first_line) return NULL;
   return array_map(String_Type, &strtrim_end,
		    dict_array[[first_line:second_line]], "\n");
}

% same as look, but use the external look program
public define lookup_words(word, list)
{
   variable buf = whatbuf;
   setbuf("*look*");
   erase_buffer;
   variable command = sprintf("look -df %s %s", word, list);
   shell_cmd(command);
   mark_buffer;
   strchop(strtrim(bufsubstr(), "\n"), '\n', 0);
   setbuf(buf);
}


% Complete word by looking it up in the system dictionary.
% Has little to do with ispell, but in Emacs it's called ispell-complete.

public define ispell_complete()
{
   variable word, new_word, buf = whatbuf, cbuf = "*completions*",
     num_win = nwindows, obuf, n, completions, num,
     wordlen, lookfun;
   lookfun = __get_reference(ispell_lookup_fun);

   push_spot;
   push_mark;
   ispell_beginning_of_word;	       %  The Dutch dictionary does have
   				       %  "-'" chars in words
   word = bufsubstr;
   wordlen = strlen(word);
   pop_spot;
   word = strlow(word);
   if (ispell_wordlist == "") return message ("no wordlist");
   completions = @lookfun(word, ispell_wordlist);
   if (completions == NULL) return message ("no completions");

   % try to complete a part
   variable first_completion = completions[0];
   variable last_completion = completions[-1];
   !if (strncmp (first_completion, last_completion, 1 + strlen (word)))
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
    	vinsert ("(%d)  %s\n", i, completions[i]);
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
   message ("Enter choice");

   update_sans_update_hook(0);
   variable c = getkey();
   ungetkey(c);
   !if ('0' <= c and c <= '9')
     {
	sw2buf(obuf);
	pop2buf(buf);
	if (num_win == 1) onewindow();
	bury_buffer(cbuf);
	return;
     }
   num = integer (read_mini ("Enter choice. (^G to abort)", "0", Null_String));
   sw2buf(obuf);
   pop2buf(buf);
   if (num >= 0 and num < length (completions))
     insert (completions[num][[wordlen:]]); 
   if (num_win == 1) onewindow();
   bury_buffer(cbuf);
}

provide ("look");

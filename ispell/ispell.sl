% ispell.sl	-*- mode: SLang; mode: fold -*-
% 
% $Id: ispell.sl,v 1.18 2005/06/16 08:40:18 paul Exp paul $
% 
% Copyright (c) 2001-2004 Guido Gonzato, John Davis, Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% Thanks to Günter Milde.
provide("ispell");
require("ispell_common");
require("bufutils");
use_namespace("ispell");
!if (is_defined("ispell_process"))
  public variable ispell_process = -1;

static variable buf, obuf, num_win;
static variable ibuf = " *ispell*", corbuf = "*corrections*";

%{{{ ispell process

public define kill_ispell()
{
   if (-1 != ispell_process)
     kill_process(ispell_process);
   ispell_process = -1;
}

static define wait_for_ispell_output (secs)
{
   variable max_time = _time () + secs;
   variable this_line = what_line (), line;
   do
     {
	get_process_input(1);
	line = what_line;
        if (line > this_line )
	  {
	     if (bolp and eolp) % last line of output is empty
	       {
		  go_up_1;
	     	  if (bolp and eolp)
	     	    return 0;
		  eob;
	       }
	     this_line = line;
	  }
     }
   while (max_time > _time ());
   return -1;
}

static define start_ispell_process ()
{
   variable cbuf = whatbuf ();
   variable args = strtok (ispell_command + " -a");
   setbuf(ibuf);
   erase_buffer;
   message ("starting ispell process....");

   foreach (args)
     ;
   length (args) - 1;
   ispell_process = open_process ();
   if (ispell_process == -1)
     verror ("Unable to open ispell process");

   % () = wait_for_ispell_output (5); 
   % The header is NOT followed by a blank line...
   sleep(1);
   get_process_input(2);
   bob ();
   if (looking_at_char ('@'))     %  ispell header
     del_through_eol ();
   else
     {
	pop2buf(whatbuf);
	ispell_process = -1;
	pop2buf(buf);
	verror ("Ispell crashed!");
     }
   send_process(ispell_process, "!\n");
   process_query_at_exit (ispell_process, 0);
   setbuf (cbuf);
}


%}}}

%{{{ checking a word

static define send_string_to_ispell_process (word)
{

   setbuf (ibuf);
   if (ispell_process == -1)
     start_ispell_process ();

   erase_buffer ();
   send_process (ispell_process, strcat ("^", word, "\n"));

   if (wait_for_ispell_output (5) == -1)
     verror ("ispell process is not responding");
}

define get_ispell_command(word, key_array, corrections)
{
   variable n, num;
   forever
     {
	num = get_mini_response("Enter choice. ");
	switch (num)
	  {case 'r': return read_mini("correct word:", "", word);}
	  {case ' ': return NULL;}
	  {case 'a': send_process (ispell_process, strcat ("@", word, "\n"));
	     return NULL;}
	  {case 'i': send_process (ispell_process, strcat ("*", word, "\n#\n"));
	     return NULL;}
	  {case 'u': send_process (ispell_process, strcat ("*", strlow(word), "\n#\n"));
	     return NULL;}
	  {case 'n': return -1;}
	if (corrections != NULL)
	  {
	     if (num == '')  return corrections[0];
	     n = where (key_array == num);
	     if (length(n))
	       return corrections[n[0]];
	  }
     }
}

static variable start_column;

static define ispell_line();

% check a word
% is_auto =	0: called from ispell() 
% 		1: called from autoispell() - gone
% 		2: called from ispell_region()
define ispell_parse_output (is_auto)
{
   variable num_win, old_buf, corrections = NULL;
   variable word, n, new_word;
   variable keys = "0123456789!@#$%^&*()", key_array = Char_Type[20];
   variable ispell_offset;
   %%
   %% parse output
   %%
   bob();
   if (looking_at_char('@'))   % ispell header
     {
        del_through_eol ();
     }

   EXIT_BLOCK
     {
        setbuf (buf);
     }

   if (bolp and eolp)
     {
        !if (is_auto)
          message ("Correct");
        return;
     }
   
   variable line = line_as_string;
   
     
   if (line[0] == '&')
     {
	ispell_offset = integer (strtok (line, " :")[3]);
	corrections = strchop(extract_element(line, 1, ':'), ',', 0);
	if (length(corrections) > 20)
	  corrections = corrections[[:19]];
	corrections = array_map (String_Type, &strtrim, corrections);
    
	erase_buffer();
	
	init_char_array (key_array, keys);
	n = length(corrections);
	key_array = key_array[[:n - 1]];
	variable i = 0;
        setbuf (corbuf);
	erase_buffer();
	loop (n)
	  {
	     vinsert("(%c) %s\n", key_array[i], corrections[i]);
	     ++i;
	  }
	buffer_format_in_columns();
     }
   else % there was no '&' so it was a '#'
     {
	ispell_offset = integer (extract_element(line, 2, ' '));
        setbuf (corbuf);
	erase_buffer();
	insert ("no suggestions");
     }
   word = extract_element(line, 1, ' ');
   bob();
   insert(strcat 
	  ("Misspelled: ", word,
	   "\tKey: select correction\t r: enter correction\n",
	   "space: skip\t a: accept this session\t n: next line\n", 
	   "i: insert into dictionary\tu: uncapitalized insert\t^G: quit\n"));
   pop2buf(buf);
   % start_column expands tabs, but ispell_offset is the column info from
   % ispell, which counts tabs as one character (we gave ispell the line
   % starting at start_column).  This is all right as long as we don't
   % confuse the two.  We can use what_column() and goto_column() for
   % start_column, and POINT and go_right() for ispell_offset.
   goto_column(start_column);
   go_right(ispell_offset - 1); % we prepended a '^' to keep ispell
   % from interpreting the line as a command, this is included in
   % ispell's column info (at least in my version)
   push_visible_mark();
   go_right(strlen(word));
   num_win = nwindows() - MINIBUFFER_ACTIVE;
   if (num_win == 1)
     {
	old_buf = buf;
	sw2buf(corbuf);
	pop2buf(buf);
	otherwindow;
     }
   else
     old_buf = pop2buf_whatbuf (corbuf);
   bob;
   if (num_win == 1) window_set_rows(8);
   
   set_buffer_modified_flag(0);

   ERROR_BLOCK
     {
	sw2buf(old_buf);
	pop2buf(buf);
        if (num_win == 1) onewindow();
	pop_mark_0();
     }
   new_word = get_ispell_command(word, key_array, corrections);
   sw2buf(old_buf);
   pop2buf(buf);
   if (num_win == 1) onewindow();
   if (andelse {typeof(new_word) == Integer_Type}{new_word == -1})
     return pop_mark_0;
   if (new_word != NULL)
     {  
	del_region();
	insert(new_word);
	if (is_auto == 2)
	  go_left(strlen(new_word));	% new word is doublechecked
     }
   else
     pop_mark_0();
   if (is_auto == 2)
     {
	ispell_line();			% check rest of line
     }
   
}

%!%+
%\function{ispell}
%\synopsis{spell-check a word}
%\usage{ispell ()}
%\description
%   Spell-check the word at point. If the word is misspelled, pop up a
%   buffer with suggestions for correction and wait for a command.
%   Commands:
%     \var{DIGIT} Select a correction
%     \var{i}     Insert into private dictionary
%     \var{u}     Insert into private dictionary in lowercase
%     \var{a}     Accept for this session
%     \var{SPC}   Skip this time
%     \var{r}     Replace with one or more words
%   These commands apply when checking a region:
%     \var{n}     Skip this line
%     \var{^G}    Stop spell-checking
%\seealso{ispell_region, flyspell_mode, ispell_change_dictionary}
%!%-
public define ispell ()
{
   skip_chars(ispell_letters);
   variable n = POINT;
   ispell_beginning_of_word();
   if (POINT == n)
     return;
   start_column = what_column;
   push_mark();
   ispell_end_of_word();
   
   buf = whatbuf();
   variable word = bufsubstr();
   send_string_to_ispell_process (word);
   ispell_parse_output(0);
}

%}}}

%{{{ checking a region

% If I check
% 
% get it at http://jedmodes.sourceforge.net!
% 
% ispell_region will stop at "jedmodes", but skip "sourceforge.net". The
% reason is that after "jedmodes" is accepted, ispell sees
% ".sourceforge.net", interprets it as a troff command, and skips it.
% Since internet addresses should not be checked anyway, that's OK.
define ispell_line()
{
   start_column = what_column;
   push_spot;
   push_mark_eol; bufsubstr; pop_spot;
   send_string_to_ispell_process();
   ispell_parse_output(2);
}

%!%+
%\function{ispell_region}
%\synopsis{spell-check a region}
%\usage{ispell_region()}
%\description
%   If there is a visible mark, spell-check the region.  Otherwise,
%   spell-check the entire buffer.
%\notes
%   For checking html, it's better to use vispell or flyspell
%\seealso{ispell, flyspell_region}
%!%-
public define ispell_region()
{
   buf = whatbuf;
   if (ispell_process == -1)
     {
	start_ispell_process ();
	update_sans_update_hook(1);
	get_process_input(10);
     }
   push_narrow();
   ERROR_BLOCK
     {
	pop_narrow():
     }
   if (is_visible_mark) narrow();
   bob();
   if (is_list_element("TeX,LaTeX", get_mode_name(), ','))
     send_process (ispell_process,  "+\n");
   else
     send_process (ispell_process,  "-\n");
   if (blocal_var_exists("ispell_region_hook"))
       {
	  variable ispell_hook = get_blocal_var("ispell_region_hook");
	  forever
	    {
	       if (@ispell_hook)
		 ispell_line;
	       !if (down_1) break;
	       skip_chars("\n");
	    }
       }
   else
     {
	forever
	  {
	     ispell_line;
	     !if (down_1) break;
	     skip_chars("\n");
	  }
     }
   pop_narrow();
   if (bufferp(corbuf))
     delbuf(corbuf);
}

%}}}

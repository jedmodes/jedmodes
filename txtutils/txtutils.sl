% Tools for text processing (marking, string processing, formatting)
% Günter Milde <g.milde at web.de>
%
% Version 2.0  * get_word(), bget_word() now "region aware"
%              * new functions mark_line(), get_line(), autoinsert()
%              * bugfix for indent_region_or_line() (used to leave stuff
%                on stack)
%         2.1  * mark_word(), bmark_word() test for buffer local variable
%                "Word_Chars" (using get_blocal from sl_utils.sl)
%         2.2  May 2003
%              * removed indent_region_or_line() (now in cuamisc.sl)
%              * changed mark_/get_word: added 2nd opt arg skip
%                           -1 skip backward, if not in a word
%                            0 don't skip
%                            1 skip forward, if not in a word
%                Attention: get_word now returns last word, if the point is
%                just behind a word (that is the normal way jed treats 
%                word boundaries)

% debug information, comment these out when ready
_debug_info = 1;
_traceback=1;


% --- Requirements ---

autoload("get_blocal", "sl_utils");
autoload("push_defaults", "sl_utils");

%--- marking and regions ---------------------------------------------

% Mark a word.
% Get the idea of what a word is made of from
%   the optional argument,
%   the blocal variable "Word_Chars" or
%   get_word_chars().
% If the second argument defaults to zero, it means
%   -1 skip backward, if not in a word
%    0 don't skip
%    1 skip forward, if not in a word
public define mark_word() % ([word_chars], skip=0)
{
   variable word_chars, skip;
   (word_chars, skip) = push_defaults(NULL, 0, _NARGS);
   if (word_chars == NULL)
     word_chars = get_blocal("Word_Chars", get_word_chars());
   switch (skip)
     { case -1: skip_chars(word_chars);
	bskip_chars("^"+word_chars); 
     }
     { case  1: skip_chars("^"+word_chars);
	if(eolp()) return push_visible_mark();
     }
   % Find word boundaries
   bskip_chars(word_chars);
   push_visible_mark();
   skip_chars(word_chars);
}

% % mark a word (skip forward if between two words)
% public define fmark_word() % fmark_word([word_chars])
% {
%    variable args = __pop_args (_NARGS);
%    mark_word(__push_args(args), 1);
% }

% % mark a word (skip backward if not in a word)
% public define bmark_word () % ([word_chars])
% {
%    variable args = __pop_args (_NARGS);
%    mark_word(__push_args(args), -1);
% }

% return the word at point as string
% if a visible region is defined, return it instead
public define get_word() % ([word_chars], skip=0)
{
   % pass on optional arguments
   variable args = __pop_args (_NARGS);
   push_spot;
   !if (is_visible_mark)
     mark_word (__push_args (args));
   bufsubstr();
   pop_spot();
}

% % return the word at point as string (skip forward if between two words)
% public define fget_word() %  ([word_chars])
% {
%    variable word_chars = push_defaults( , _NARGS);
%    get_word(word_chars(args), 1);
% }

% return the word at point as string (skip back if between two words)
public define bget_word() %  ([word_chars])
{
   variable word_chars = push_defaults( , _NARGS);
   get_word(word_chars, -1);
}

% Mark the current line
public define mark_line()
{
   bol();
   push_mark_eol();
}

% Return the current line as string (keeping the point at place)
public define get_line()
{
   push_spot();
   line_as_string();  % leave return value on stack
   pop_spot();
}

% Return buffer (or region, if defined) as string
%  The optional argument kill tells, whether the buffer/region should be
%  deleted after reading.
public define get_buffer() % (kill=0)
{
   variable  kill;
   kill = push_defaults(0,_NARGS);

   push_spot();
   !if(is_visible_mark())
     mark_buffer();
   if (kill)
     bufsubstr_delete(); % leave return value on stack
   else
     bufsubstr(); % leave return value on stack
   pop_spot();
   return; % (str)
}

% --- formatting -----------------------------------------------------

public define indent_buffer()
{
   push_spot;
   bob;
   do
     indent_line;
   while (down_1);
   pop_spot;
}

public define number_lines ()
{
   push_spot;
   if(is_visible_mark, dup) % leave return-value on stack
     narrow;
   eob;
   variable i = 1,
     format = "%"+string(strlen(string(what_line())))+"d ";
   bob;
   do
     { bol;
        insert(sprintf(format, i));
	i++;
     }
   while (down_1);
   if (()) % was_visible_mark
     widen;
   pop_spot;
}

% Insert the content of the first line into a rectangle defined by point and mark
public define autoinsert()
{
   () = dupmark();
   narrow;
   % get string to insert
   check_region(0);
   variable end_col = what_column();
   bob();
   goto_column(end_col);
   variable str = bufsubstr();
   variable beg_col = end_col - strlen(str);
   while (down_1)
     {
	goto_column(beg_col);
        insert(str);
     }
   widen;
}

provide("txtutils");

% subpar.sl
% paragraph reformatter
% 
% $Id: subpar.sl,v 1.1 2004/05/27 21:24:49 paul Exp paul $
% Keywords: wp
%
% Copyright (c) 2004 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% Uses a dynamic programming algorithm like Adam Costello's "par" program.  It
% chooses linebreaks so that the paragraph satisfies the following properties:
%
%         1) No line contains more than <L> characters.
%
%         2) The sum of the squares of the differences between <L>
%	     and the lengths of the lines is as small as possible.

%!%+
%\variable{Par_Bullets}
%\synopsis{Bullet characters}
%\usage{String_Type Par_Bullets = "*\\-"}
%\description
%  The \var{par} paragraph formatter will avoid breaking a line at a bullet
%  character.  The '-' is escaped because this is used in a regexp character
%  list.
%\seealso{par}
%!%-
custom_variable("Par_Bullets", "*\\-");

require("comments");

% Get the spaces on this line, and return their positions on the stack,
% skipping double spaces.  Avoid possible line breaks at comment characters.
static define get_spaces(comment_chars)
{
   variable line = line_as_string, pos = 0, len;

   % Skip indentation of first line
   if (string_match(line, "^ +", 1))
     (,pos) = string_match_nth(0);
   pos++;

   variable re = sprintf("\\( +\\)[^ %s%s]", Par_Bullets, comment_chars);
   while (string_match(line, re, pos))
     {
	(pos ,len) = string_match_nth(1);
	if (len == 1)
	  pos;
	pos += len + 1;
     }
   strlen(line);
}

static variable indent;

% Chooses line breaks in a list of words which maximize the sum of squares
% of differences between line lengths and the maximum line length.  Pushes
% the locations of linebreaks on the stack and returns the number of
% linebreaks.  This is actually more like Costello's simplebreaks() than his
% normalbreaks().
static define normalbreaks(s)
{
   variable i = length(s), j;
   variable L = WRAP - indent;
   if (i < 2) return 0;
   variable wordlengths = s - [indent-1, s[[0:i-2]]]; % these are actually wordlengths + 1
   variable linelen, score, scores = Integer_Type[i], next = Integer_Type[i];

   next[*] = -1;
   
   for (i--, linelen = wordlengths[i] - 1;
	i !=-1 and linelen <= L;
	i--, linelen += wordlengths[i])  ;
   
   variable scores_i, next_i;
   for ( ;  i != -1;  i--)
     {
	scores_i = 0;
	for (linelen = wordlengths[i] - 1, j = i, j++;
	   linelen <= L;
	   linelen += wordlengths[j],  j++)
	  {
	     score = scores[j] + sqr(L - linelen);
	     if (orelse {score < scores_i}{not scores_i} )
	       {
		  next_i = j;
		  scores_i = score;
	       }
	  }
	scores[i] = scores_i;
	next[i] = next_i;
     }

   variable n = 0;
   for (i = next[0]; i != -1; i = next[i])
     n++, s[i-1];
   n;
}


%!%+
%\function{par}
%\synopsis{paragraph reformatter}
%\usage{ par()}
%\description
%   A S-Lang paragraph reformatter.  Unlike \var{format_paragraph} it leaves
%   double spaces alone.  It can reformat newline-terminated commments in
%   S-Lang, C++, and SH using the mode's comment_info.
%\seealso{Par_Bullets, set_comment_info}
%!%-
define par()
{
   variable is_comment = 0, comment_chars = "";
   push_spot;
   % get indentation
   bol;
   push_mark;
   skip_white;
   variable comment = get_comment_info;
   if (andelse
       {comment != NULL}
	 {comment.cend == ""}
	 {comment_chars = str_quote_string(comment.cbeg, "[]^\\-", '\\'),
	    re_looking_at(sprintf ("[%s]", comment_chars))})
     {
	skip_chars(comment.cbeg);
	is_comment = 1;
	skip_white;
     }
   
   indent = what_column -1;
   variable prefix = bufsubstr, prefix_length = strlen(prefix);
   
   if (is_comment)	% narrow to the comment
     {
	variable re = sprintf("^%s[^%s]", prefix, comment_chars);
	while (up_1)
	  {
	     bol;
	     if (not re_looking_at(re))
	       {
		  go_down_1;
		  break;
	       }
	  }
	push_mark;
	while (down_1)
	  {
	     if (not re_looking_at(re))
	       {
		  go_up_1;
		  break;
	       }
	  }
	narrow;
     }
   else 	      % narrow to the paragraph
     {	
	backward_paragraph;
	!if (bobp) go_down_1;
	push_mark;
	forward_paragraph;
	!if (eobp) go_up_1;
	narrow;
     }
   
   bob;
   eol;
   while (not eobp)
     {
	del;
	if(is_comment) deln(prefix_length);
	trim;
	insert_char(' ');
	eol;
     }
   
   % paragraph is one line now, look for spaces
   bol;
   [get_spaces(comment_chars)];
   
   % get linebreaks
   variable newlines = normalbreaks();
   
   % insert linebreaks backwards
   loop (newlines)
     {
	_set_point();
	del;
	newline;
	insert(prefix);
	go_up_1;
     }

   widen;
   pop_spot;
}

provide ("subpar");

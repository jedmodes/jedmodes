% Utilities for processing of strings
% 
% Copyright (c) 2005 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
% 
% Version     0.9 first public version
%             1.0 moved here string_repeat(), string_reverse() from datutils
%                 new: strwrap(), strbreak(), string_get_last_match() 
%                 (the latter suggested as string_nth_match() by PB)
%             1.1 new functions get_keystring() and unget_string()
%             1.2 removed unget_string() after learning about 
%             	  buffer_keystring() (standard fun, which does the same)
%             1.3 new function str_re_replace_all()
% 2005-01-01  1.4 removed the string_get_last_match() alias, call
% 	      	  string_nth_match() instead.
% 	      	  added tm documentation
% 2005-11-21  1.4.1 removed the public from define str_repeat() and 
%                   define get_keystring()
%
% (projects for further functions in projects/str_utils.sl)

autoload("array_append", "datutils");

% debug information, uncomment to locate errors
 % _debug_info = 1;


%!%+
%\function{string_nth_match}
%\synopsis{Return the (nth) substring of the last call to string_match}
%\usage{ string_nth_match(str, n)}
%\description
%  After matching a string against a regular expression with 
%  string_match(), string_nth_match can be used to extract the
%  exact match.
%    
%  By convention, \var{nth} equal to zero means the entire match.
%  Otherwise, \var{nth} must be an integer with a value 1 through 9,
%  and refers to the set of characters matched by the \var{nth} regular
%  expression enclosed by the pairs \var{\(, \)}.
%\notes
%  There was an alias string_get_last_match() for this function 
%  in earlier versions of bufutils.sl
%\seealso{string_match, string_match_nth, string_get_match, str_re_replace}
%!%-
define string_nth_match(str, n)
{
   variable pos, len;
   ERROR_BLOCK { _clear_error(); pop; return ""; }
   (pos, len) = string_match_nth(n);
   return substr(str, pos+1, len);
}

%!%+
%\function{string_get_match}
%\synopsis{Return a substring matching a regexp pattern}
%\usage{String string_get_match(String str, String pattern, pos=1, nth=0)}
%\description
%  Use string_match() to do a regexp matching on a string and return 
%  the matching substring
%  
%  Performs the match starting at position \var{pos} (numbered from 1)
%  
%  By convention, \var{nth} equal to zero means the entire match.
%  Otherwise, \var{nth} must be an integer with a value 1 through 9,
%  and refers to the set of characters matched by the \var{nth} regular
%  expression enclosed by the pairs \var{\(, \)}.
%\seealso{string_match, string_nth_match, str_re_replace, substr}
%!%-
define string_get_match() % (str, pattern, pos=1, nth=0)
{
   variable str, pattern, pos, nth;
   (str, pattern, pos, nth) = push_defaults( , , 1, 0, _NARGS);

   if (string_match (str, pattern, pos))
     return string_nth_match(str, nth);
   else
     return "";
}

%!%+
%\function{str_re_replace}
%\synopsis{Regexp replace max_n occurences of \var{pattern} with \var{rep}}
%\usage{(String, Integer) str_re_replace(str, pattern, rep, max_n)}
%\description
%  Regexp equivalent to \var{strreplace}. Replaces up to max_n occurences
%  of \var{pattern} with \var{rep}.
%  
%  Returns the string with replacements and the number of replacements done.
%\notes
%  Currently, rep may contain 1 backref '\1'
%  TODO: allow up to 9 expansions
%\seealso{str_re_replace_all, strreplace, string_get_match}
%!%-
define str_re_replace(str, pattern, rep, max_n)
{
   variable n, pos, len, outstr="", match, backref, x_rep;
   
   for(n = 0; n < max_n; n++)
     {
	!if (string_match(str, pattern, 1))
	  break;
	% get the backref, i.e. the part matching pattern in \( \)
	backref = string_nth_match(str, 1);
	% split the string in 3 parts (outstr, match, str)
	(pos, len) = string_match_nth(0);
	outstr += substr(str, 1, pos);
	pos++;
	match = substr(str, pos, len);
	str = substr(str, pos+len, -1);
	% expand replacement pattern
	(x_rep, ) = strreplace(rep, "\\1", backref, 1);
	% append expanded replacement
	outstr += x_rep;
     }
   return (outstr+str, n);
}


%!%+
%\function{str_re_replace_all}
%\synopsis{Regexp replace all occurences of \var{pattern} with \var{rep}}
%\usage{String str_re_replace_all(str, pattern, rep)}
%\description
%  Regexp equivalent to \var{str_replace_all}. Replaces all occurences
%  of \var{pattern} with \var{rep} and returns the resulting string.
%\seealso{str_re_replace, str_replace_all, string_get_match}
%!%-
define str_re_replace_all(str, pattern, rep)
{
   (str, ) = str_re_replace(str, pattern, rep, strlen(str));
   return str;
}


%!%+
%\function{strcap}
%\synopsis{Capitalize a string}
%\usage{String strcap(String str)}
%\description
%  Convert a string to a capitalized  version (first character upper case, 
%  other characters lower case) and return the result.
%\seealso{strlow, strup, xform_region, capitalize_word, define_case}
%!%-
define strcap(str)
{
   return strup(substr(str, 1, 1)) + strlow(substr(str, 2, strlen(str)));
}


%!%+
%\function{string_reverse}
%\synopsis{Reverse the order of characters in a string}
%\usage{String string_reverse(String s)}
%\description
%  Reverse the order of characters in a string
%\example
%#v+
%  string_reverse("abcd") == "dcba"
%#v-
%\seealso{array_reverse}
%!%-
define string_reverse(s)
{
   variable i = strlen (s) - 1;
   if (i < 1)
     return s;
   __tmp(s)[[i:0:-1]];
}


%!%+
%\function{string_repeat}
%\synopsis{Repeat a string n times}
%\usage{String string_repeat(String str, Integer n)}
%\description
%  Concatenate \var{n} replicas of string \var{str} and return the result.
%\example
%#v+
%  string_repeat("+-", 4) == "+-+-+-+-"
%#v-
%\notes
%  This is equivalent to str*n in Python
%\seealso{array_repeat}
%!%-
define string_repeat(str, n)
{
   variable strings = String_Type[n];
   strings[*] = str;
   return strjoin(strings, "");
}

%!%+
%\function{strwrap}
%\synopsis{Split a string into lines of maximal \var{wrap} chars}
%\usage{Array strwrap(String str, wrap=WRAP, delim=' ', quote = 0)}
%\description
%  Line wrapping for strings: Split a string into substrings of maximal 
%  \var{wrap} chars, breaking at \var{delim} (if not quoted, cv. \var{strchop}).
%  Return array of strings.
%\seealso{strbreak, strtok, WRAP}
%!%-
define strwrap() % (str, wrap=WRAP, delim=' ', quote = 0)
{
   variable str, wrap, delim, quote;
   (str, wrap, delim, quote) = push_defaults( , WRAP, ' ', 0, _NARGS);

   variable word, words= strchop(strtrim(str, char(delim)), delim, quote),
   line, lines;
   !if (length(words))
     return words;
   lines = words[[0]];
   foreach (words[[1:]])
     {
	word = ();
	if ( strlen(lines[-1]) + strlen(word) < wrap)
	  lines[-1] += char(delim) + word;
	else
	  lines = array_append(lines, word);
     }
   return lines;
}

%!%+
%\function{strbreak}
%\synopsis{}
%\usage{(String, String) strbreak(String str, wrap=WRAP, delim=' ')}
%\description
% One-time string wrapping: Split a string at a breakpoint defined by delim, 
% so that the first part is no longer than \var{wrap} characters.
% Return two strings.
% 
% The delimiter is left at the end of the first return string.
%\seealso{strwrap, WRAP}
%!%-
define strbreak() % (str, wrap=WRAP, delim=' ')
{
   variable str, wrap, delim;
   (str, wrap, delim) = push_defaults( , WRAP, ' ', _NARGS);

   if (strlen(str) <= wrap)
     return (str, "");

   variable breakpoints, i;
   % Get breakpoint
   breakpoints = where(bstring_to_array(str[[:wrap]]) == delim); % try within allowed range
   i = length(where(breakpoints <= wrap)) - 1;
   if (i<0) % no breakpoint in allowed range, take first possible breakpoint
     {
	breakpoints = where(bstring_to_array(str) == delim);
	i = 0;
	!if (length(breakpoints)) % no breakpoint at all
	  return (str, "");
     }
   return (str[[:breakpoints[i]]], str[[breakpoints[i]+1:]]);
}


%!%+
%\function{get_keystring}
%\synopsis{Get the keystring of the next keypress event}
%\usage{ get_keystring()}
%\description
%  Wait for the next keypress and return all waiting input.
%  This is the opposite of buffer_keystring.
%\example
%#v+
%  define showkey_literal()
%  {
%     flush ("Press key:");
%     variable key = get_keystring();
%     if (prefix_argument(0))
%       insert (key);
%     else
%       {
%  #ifdef XWINDOWS
%  	key += sprintf(" X-Keysym: %X", X_LAST_KEYSYM);
%  #endif
%  	message ("Key sends " + key);
%       }
%  }
%#v-
%
%\notes
%  This may err for fast typing on slow terminals.
%\seealso{getkey, ungetkey, input_pending, buffer_keystring}
%!%-
define get_keystring()
{
   variable ch, key = "";
   do
     {
	ch = char(getkey());
	!if (strlen(ch)) % Null character \000
	  ch = "^@";
	key = strcat(key, ch);
     }
   while (input_pending(0));
   return key;
}

% Utilities for processing of strings
% 
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
% 
% Version 0.9   first public version
%         1.0   added string_repeat, string_reverse from datutils
%               new: strwrap, strbreak,
%               string_get_last_match (suggested as string_nth_match by PB)
%         1.1   new functions get_keystring() and unget_string(str)
%         1.2   removed unget_string() after learning about buffer_keystring()
%         1.3   new function str_re_replace_all()
%
% (projects for further functions in projects/str_utils.sl)

autoload("array_append", "datutils");

% debug information, comment these out when ready
 % _debug_info = 1;

% Return the (nth) substring of the last call to string_match
define string_get_last_match(str, n)
{
   variable pos, len;
   ERROR_BLOCK { _clear_error(); pop; return ""; }
   (pos, len) = string_match_nth(n);
   return substr(str, pos+1, len);
}
% alias
define string_nth_match(str, n) { string_get_last_match(str, n); }

% Return a substring matching the regexp pat
% String string_get_match(String str, String pat, Integer pos)
% (see string_match, string_match_nth)
define string_get_match() % (str, pat, start=1, n=0)
{
   variable str, pat, start, n;
   (str, pat, start, n) = push_defaults( , , 1, 0, _NARGS);

   if (string_match (str, pat, start))
     return string_get_last_match(str, n);
   else
     return "";
}

% Regexp replace max_n occurences of 'pattern' with 'rep'
% Currently, rep may contain 1 backref '\1'
% TODO: allow up to 9 expansions
define str_re_replace(str, pattern, rep, max_n)
{
   variable n, pos, len, outstr="", match, backref, x_rep;
   
   for(n = 0; n < max_n; n++)
     {
	!if (string_match(str, pattern, 1))
	  break;
	% get the backref, i.e. the part matching pattern in \( \)
	backref = string_get_last_match(str, 1);
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

% Regexp replace all occurences of 'pattern' with 'rep'
define str_re_replace_all(str, pattern, rep)
{
   (str, ) = str_re_replace(str, pattern, rep, strlen(str));
   return str;
}

% Capitalize a string
% seealso{strlow, strup, xform_region, capitalize_word}
define strcap(str)
{
   return strup(substr(str, 1, 1)) + strlow(substr(str, 2, strlen(str)));
}

% reverse the order of characters in a string
define string_reverse(s)
{
   variable i = strlen (s) - 1;
   if (i < 1)
     return s;
   __tmp(s)[[i:0:-1]];
}

% repeat a string n times (s*n in python)
public define string_repeat(s, n)
{
   variable s2 = "";
   loop(n)
     s2 += s;
   return s2;
}

% Split a string into pieces of maximal 'wrap' chars,
% breaking at delim (cmp. strchop). Return array of "lines"
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

% Break a string at a breakpoint defined by delim, so that the first
% part is no longer than wrap chars
% The delimiter is left at the end of the first return string
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

% get the keystring of the next keypress event
% seealso {getkey, ungetkey, buffer_keystring}
public define get_keystring()
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

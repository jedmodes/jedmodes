% Utilities for processing of strings
%
% Copyright (c) 2005 Günter Milde (milde@users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Version     0.9 first public version
%             1.0 moved here string_repeat(), string_reverse() from datutils
%                 new: strwrap(), strbreak(), string_get_last_match()
%                 (the latter suggested as string_nth_match() by PB)
%             1.1 new functions get_keystring() and unget_string()
%             1.2 removed unget_string() after learning about
%                 buffer_keystring() (standard fun, which does the same)
%             1.3 new function str_re_replace_all()
% 2005-01-01  1.4 removed the string_get_last_match() alias, call
%                 string_nth_match() instead.
%                 added tm documentation
% 2005-11-21  1.4.1 removed the public from define str_repeat() and
%                   define get_keystring()
% 2006-03-01  1.4.2 added provide()
%                   added autoload for push_defaults()
% 2007-01-15  1.5   added str_re_replace_by_line() after a report by
%                   Morten Bo Johansen that str_re_replace_all is dead slow
%                   for large strings.
%             1.5.1 bugfix in str_re_replace_all() by M. Johansen
% 2007-05-09  1.6   new function strsplit()
% 2007-05-25  1.6.1 optimized str_re_replace() by Paul Boekholt
% 2008-01-04  1.6.2 docu fix in strsplit(), max_n not functional yet
%                   bugfix for n_max=0 in str_re_replace()
% 2008-12-16  1.6.3 bugfix: regexp search uses byte semantics (P. Boekholt)
% 2009-10-05  1.7   new: str_unicode_escape().
%
% (projects for further functions in projects/str_utils.sl)

autoload("array_append", "datutils");
autoload("push_defaults", "sl_utils");

provide("strutils");

%!%+
%\function{string_nth_match}
%\synopsis{Return the (nth) substring of the last call to string_match}
%\usage{String = string_nth_match(str, n)}
%\description
%  After matching a string against a regular expression with
%  \sfun{string_match}, \sfun{string_nth_match} can be used to extract
%  the exact match.
%
%  By convention, \var{nth} equal to zero means the entire match.
%  Otherwise, \var{nth} must be an integer with a value 1 through 9,
%  and refers to the set of characters matched by the \var{nth} regular
%  expression enclosed by the pairs \var{\(, \)}.
%\notes
%  Calls \sfun{substr} on \var{str} using the (adapted) result of
%  \sfun{string_match_nth} as offsets.
%\seealso{string_match, string_match_nth, string_get_match, str_re_replace}
%!%-
define string_nth_match(str, n)
{
   variable pos, len;
   try {
      (pos, len) = string_match_nth(n);
   }
   catch RunTimeError: {
      return "";
   }
   return substrbytes(str, pos+1, len);
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
%  Regexp equivalent to \sfun{strreplace}. Replaces up to max_n occurences
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
   variable n, pos = 1, next_pos, len, outstr=String_Type[1],
     match, backref, x_rep;

   % do replacements one-by-one, caching results in array
   for(n = 0; n < max_n; n++)
     {
        % add 100 elements to cache if it is full
        !if (n mod 100)
          outstr = [outstr, String_Type[100]];
        % Match against regexp `pattern' starting at `pos'
        !if (string_match(str, pattern, pos))
          break;
        % get the backref, i.e. the part matching pattern in \( \)
        backref = string_nth_match(str, 1);
        % expand replacement pattern
        (x_rep, ) = strreplace(rep, "\\1", backref, 1);
        % get position of next match
        (next_pos, len) = string_match_nth(0);
        next_pos++;
        % cache the string-part with replacement in an array
        outstr[n] = strcat(substrbytes(str, pos, next_pos - pos), x_rep);
        % advance position
        pos = next_pos + len;
     }
   outstr[n] = substrbytes(str, pos, -1);
   return (strjoin(outstr[[:n]], ""), n);
}

%!%+
%\function{str_re_replace_all}
%\synopsis{Regexp replace all occurences of \var{pattern} with \var{rep}}
%\usage{String str_re_replace_all(str, pattern, rep)}
%\description
%  Regexp equivalent to \sfun{str_replace_all}. Replaces all occurences
%  of \var{pattern} with \var{rep} and returns the resulting string.
%
%  Other than using \sfun{query_replace_match}, this function
%  will find and replace across line boundaries.
%\notes
%  As the whole string is searched as one piece, \sfun{str_re_replace_all}
%  will become *very* slow for larger strings. If there is no need to find
%  matches across lines, \sfun{str_re_replace_by_line} should be used.
%\seealso{str_re_replace, str_replace_all, str_re_replace_by_line}
%!%-
define str_re_replace_all(str, pattern, rep)
{
   (str, ) = str_re_replace(str, pattern, rep, strlen(str));
   return str;
}

%!%+
%\function{str_re_replace_by_line}
%\synopsis{Regexp replace \var{pattern} with \var{rep}}
%\usage{str_re_replace_by_line(str, pattern, rep)}
%\description
%  Replace all occurences of the regular expression \var{pattern} with
%  \var{rep}. In contrast to \sfun{str_re_replace_all}, this function
%  will not find matches across lines (similar to a regexp replace in a
%  buffer).
%\notes
%  This function splits \var{str} into an array of lines, calls
%  \sfun{str_re_replace_all} on them and joins the result. As result, it
%  takes 4 seconds to make 15000 replacements in a 10 MB string on a 2 GHz
%  cpu/1 GB ram computer (where str_re_replace_all took hours).
%\seealso{str_re_replace, str_re_replace_all}
%!%-
public define str_re_replace_by_line(str, pattern, rep)
{
   variable lines = strchop(str, '\n', 0);
   lines = array_map(String_Type, &str_re_replace_all, lines, pattern, rep);
   return strjoin(lines, "\n");
}


%!%+
%\function{str_unicode_escape}
%\synopsis{Convert escape sequence "\uHHHH" to the S-Lang syntax}
%\usage{str_unicode_escape(str)}
%\description
%  Many programs use the escape sequence "\uHHHH" for a Unicode character
%  with the hexadecimal number 0xHHHH. Therefore, some drag-and-drop of 
%  text from another application might result in strings like
%  "the program\u2019s \u201cweb-like\u201d structure".
%  
%  The corresponding S-Lang syntax is "\x{HHHH}". This function returns
%  a string where all occurences of "\uHHHH" are converted to the S-Lang
%  equivalent. No conversion to unicode characters takes place unless the
%  result is interpreted as a string literal by S-Lang.
%\seealso{str_re_replace_all}
%!%-
public define str_unicode_escape(str)
{
   str = str_re_replace_all(str, 
			    "\\u\([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]\)"R,
			    "\x{\1}"R);
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
%\synopsis{Split a string into chunks of maximal \var{wrap} chars}
%\usage{Array strwrap(String str, wrap=WRAP, delim=' ', quote = 0)}
%\description
%  Line wrapping for strings: Split a string into chunks of maximal
%  \var{wrap} chars, breaking at \var{delim} (if not quoted, cv. \sfun{strchop}).
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
   foreach word (words[[1:]])
     {
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
%       key += sprintf(" X-Keysym: %X", X_LAST_KEYSYM);
%  #endif
%       message ("Key sends " + key);
%       }
%  }
%#v-
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

%!%+
%\function{strsplit}
%\synopsis{Split a string in tokens.}
%\usage{strsplit(str, sep, max_n=0)}
%\description
%  Return a list of the words in the string \var{str}, using \var{sep} as the
%  delimiter string.
%\seealso{strchop, strtok, strreplace, is_substr}
%!%-
define strsplit() % (str, sep, max_n=0)
{
   variable str, sep, max_n;
   (str, sep, max_n) = push_defaults( , , 0, _NARGS);
   if (max_n == 0)
     max_n = strlen(str);

   variable sep_char;
   if (strlen(sep) == 1)
     sep_char = sep[0];
   else
     {  % find an unused character -> use it as delimiter
        sep_char = 0;
        while (is_substr(str, char(sep_char)))
          {
             sep_char++;
             if (sep_char > 255)
               error ("strsplit: did not find unique replacement for multichar sep");
          }
        (str, ) = strreplace(str, sep, char(sep_char), max_n);
     }
   return strchop(str, sep_char, 0);
   % TODO
   %  If \var{max_n} is given, at most \var{max_n} splits are
   %  done. (Counting from the end, if \var{max_n} is negative.)
   %\example
   %#v+
   %  strsplit("1, 2, 3,5, 4  5. 6", ", ")     == ["1", "2", "3,5", "4  5. 6"]
   %  strsplit("1, 2, 3,5, 4  5. 6", ", ", 1)  == ["1", "2, 3,5, 4  5. 6"]
   %  strsplit("1, 2, 3,5, 4  5. 6", ", ", -1) == ["1, 2, 3,5", "4  5. 6"]
   %#v-
}

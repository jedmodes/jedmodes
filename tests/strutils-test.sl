% :  Test strutils.sl
% 
% Copyright © 2007 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)

% Usage
% -----
% Place in the jed library path.
%
% Versions
% --------
% 0.1 2008-12-15

require("unittest");

% test availability of public functions (comment to skip)
test_true(is_defined("str_re_replace_by_line"), 
	  "public fun str_re_replace_by_line undefined");

% Fixture
% -------

require("strutils");

private variable testbuf = "*bar*";
private variable teststring = "a test line";

static define setup()
{
   sw2buf(testbuf);
   insert(teststring);
}

static define teardown()
{
   sw2buf(testbuf);
   set_buffer_modified_flag(0);
   close_buffer(testbuf);
}

% Test functions
% --------------

% string_nth_match: library function
%   Return the (nth) substring of the last call to string_match
static define test_string_nth_match()
{
   variable str = "affenstark";
   test_equal(3, string_match(str, "f\\(.n\\)" , 1));
   test_equal("fen", string_nth_match(str, 0));
   test_equal("en", string_nth_match(str, 1));
}

static define test_string_nth_match_unicode()
{  
   variable str = "Wärmebrücke";
   % string_match uses byte semantics, so match is at byte 4
   test_equal(4, string_match(str, "r\\(.e\\)" , 1));
   test_equal("rme", string_nth_match(str, 0));
   test_equal("me", string_nth_match(str, 1));
}

static define test_string_nth_match_unicode2()
{  
   variable str = "Wärmebrücke";
   test_equal(2, string_match(str, "är\\(.e\\)" , 1));
   test_equal("ärme", string_nth_match(str, 0));
   test_equal("me", string_nth_match(str, 1));
}

% string_get_match: library function
%   Return a substring matching a regexp pattern
%   String string_get_match(String str, String pattern, pos=1, nth=0)
static define test_string_get_match()
{
   variable str = "Wärmebrücke", pat = "är\\(.e\\)";
   test_equal("ärme", string_get_match(str, pat, 1, 0));
   test_equal("ärme", string_get_match(str, pat));
   test_equal("me", string_get_match(str, pat, 1, 1));
}

#stop

% TODO: add tests for the remaining functions

% str_re_replace: library function
% 
%  SYNOPSIS
%   Regexp replace max_n occurences of `pattern' with `rep'
% 
%  USAGE
%   (String, Integer) str_re_replace(str, pattern, rep, max_n)
% 
%  DESCRIPTION
%   Regexp equivalent to `strreplace'. Replaces up to max_n occurences
%   of `pattern' with `rep'.
% 
%   Returns the string with replacements and the number of replacements done.
% 
%  NOTES
%   Currently, rep may contain 1 backref '\1'
%   TODO: allow up to 9 expansions
% 
%  SEE ALSO
%   str_re_replace_all, strreplace, string_get_match
static define test_str_re_replace()
{
   (Str, = i) str_re_replace(str, pattern, rep, max_n);
}

% str_re_replace_all: library function
% 
%  SYNOPSIS
%   Regexp replace all occurences of `pattern' with `rep'
% 
%  USAGE
%   String str_re_replace_all(str, pattern, rep)
% 
%  DESCRIPTION
%   Regexp equivalent to `str_replace_all'. Replaces all occurences
%   of `pattern' with `rep' and returns the resulting string.
% 
%   Other than using `query_replace_match', this function
%   will find and replace across line boundaries.
% 
%  NOTES
%   As the whole string is searched as one piece, `str_re_replace_all'
%   will become *very* slow for larger strings. If there is no need to find
%   matches across lines, `str_re_replace_by_line' should be used.
% 
%  SEE ALSO
%   str_re_replace, str_replace_all, str_re_replace_by_line
static define test_str_re_replace_all()
{
   Str = str_re_replace_all(str, pattern, rep);
}

% str_re_replace_by_line: library function
% 
%  SYNOPSIS
%   Regexp replace `pattern' with `rep'
% 
%  USAGE
%   str_re_replace_by_line(str, pattern, rep)
% 
%  DESCRIPTION
%   Replace all occurences of the regular expression `pattern' with
%   `rep'. In contrast to `str_re_replace_all', this function
%   will not find matches across lines (similar to a regexp replace in a
%   buffer).
% 
%  NOTES
%   This function splits `str' into an array of lines, calls
%   `str_re_replace_all' on them and joins the result. As result, it
%   takes 4 seconds to make 15000 replacements in a 10 MB string on a 2 GHz
%   cpu/1 GB ram computer (where str_re_replace_all took hours).
% 
%  SEE ALSO
%   str_re_replace, str_re_replace_all
static define test_str_re_replace_by_line()
{
   str_re_replace_by_line(str, = pattern, rep);
}

% strcap: library function
% 
%  SYNOPSIS
%   Capitalize a string
% 
%  USAGE
%   String strcap(String str)
% 
%  DESCRIPTION
%   Convert a string to a capitalized  version (first character upper case,
%   other characters lower case) and return the result.
% 
%  SEE ALSO
%   strlow, strup, xform_region, capitalize_word, define_case
static define test_strcap()
{
   Str = strcap(Str str);
}

% string_reverse: library function
% 
%  SYNOPSIS
%   Reverse the order of characters in a string
% 
%  USAGE
%   String string_reverse(String s)
% 
%  DESCRIPTION
%   Reverse the order of characters in a string
% 
%  EXAMPLE
% 
%    string_reverse("abcd") == "dcba"
% 
% 
%  SEE ALSO
%   array_reverse
static define test_string_reverse()
{
   Str = string_reverse(Str s);
}

% string_repeat: library function
% 
%  SYNOPSIS
%   Repeat a string n times
% 
%  USAGE
%   String string_repeat(String str, Integer n)
% 
%  DESCRIPTION
%   Concatenate `n' replicas of string `str' and return the result.
% 
%  EXAMPLE
% 
%    string_repeat("+-", 4) == "+-+-+-+-"
% 
% 
%  NOTES
%   This is equivalent to str*n in Python
% 
%  SEE ALSO
%   array_repeat
static define test_string_repeat()
{
   Str = string_repeat(Str str, i n);
}

% strwrap: library function
% 
%  SYNOPSIS
%   Split a string into chunks of maximal `wrap' chars
% 
%  USAGE
%   Array strwrap(String str, wrap=WRAP, delim=' ', quote = 0)
% 
%  DESCRIPTION
%   Line wrapping for strings: Split a string into chunks of maximal
%   `wrap' chars, breaking at `delim' (if not quoted, cv. `strchop').
%   Return array of strings.
% 
%  SEE ALSO
%   strbreak, strtok, WRAP
static define test_strwrap()
{
   Arr strwrap(Str str, wrap=WRAP, delim=' ', quote = 0);
}

% strbreak: library function
% 
%  USAGE
%   (String, String) strbreak(String str, wrap=WRAP, delim=' ')
% 
%  DESCRIPTION
%  One-time string wrapping: Split a string at a breakpoint defined by delim,
%  so that the first part is no longer than `wrap' characters.
%  Return two strings.
% 
%  The delimiter is left at the end of the first return string.
% 
%  SEE ALSO
%   strwrap, WRAP
static define test_strbreak()
{
   (Str, Str) strbreak(Str str, wrap=WRAP, delim=' ');
}

% get_keystring: library function
% 
%  SYNOPSIS
%   Get the keystring of the next keypress event
% 
%  USAGE
%    get_keystring()
% 
%  DESCRIPTION
%   Wait for the next keypress and return all waiting input.
%   This is the opposite of buffer_keystring.
% 
%  EXAMPLE
% 
%    define showkey_literal()
%    {
%       flush ("Press key:");
%       variable key = get_keystring();
%       if (prefix_argument(0))
%         insert (key);
%       else
%         {
%    #ifdef XWINDOWS
%         key += sprintf(" X-Keysym: %X", X_LAST_KEYSYM);
%    #endif
%         message ("Key sends " + key);
%         }
%    }
% 
% 
%  NOTES
%   This may err for fast typing on slow terminals.
% 
%  SEE ALSO
%   getkey, ungetkey, input_pending, buffer_keystring
static define test_get_keystring()
{
   get_keystring();
}

% strsplit: library function
% 
%  SYNOPSIS
%   Split a string in tokens.
% 
%  USAGE
%   strsplit(str, sep, max_n=0)
% 
%  DESCRIPTION
%   Return a list of the words in the string `str', using `sep' as the
%   delimiter string.  
% 
%  SEE ALSO
%   strchop, strtok, strreplace, is_substr
static define test_strsplit()
{
   strsplit(str, sep, max_n=0);
}

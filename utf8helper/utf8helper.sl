% utf8-helper.sl: converting latin1 <-> utf8.
%
% Copyright (c) 2007 John E. Davis, Joerg Sommer, Guenter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Code based on examples in Help>Browse Docs>utf8 by JED and a posting
% by Joerg Sommer to the jed-users list.
%
% The functions in this mode require slang2 to work properly but
% should also work without UTF-8 support.
%
% Currently, only utf8 and latin1 encodings are supported.
% Other encodings need an external recoding tool (e.g. `recode` or `iconv`
% (see `recode --list` or `iconv --list` for a list of supported encodings)).
%
% Auto-detection of the character encoding is possible with e.g. the
% Python chardet module (python-chardet Debian package).
%
%
% Usage
% -----
%
% Place in the jed library path.
%
% To activate the auto-conversion, set the custom variables (see  online
% help for UTF8Helper_Read_Autoconvert and UTF8Helper_Write_Autoconvert)
% and require the mode in your jed.rc file.
%
% A nontrivial customization would be::
%
%    % convert all files to active encoding
%    variable UTF8Helper_Read_Autoconvert = 1;
%    % reconvert auto-converted files, ask if Jed runs in UTF-8 mode
%    if (_slang_utf8_ok)
%      variable UTF8Helper_Write_Autoconvert = -1;
%    else
%      variable UTF8Helper_Write_Autoconvert = 1;
%    require("utf8helper");
%
% Versions
% --------
%
% 1.1   2007-06-01 first public version
% 1.2   2007-07-25 customizable activation of hooks,
%       	   renamed *lat1* to *latin1*,
% 1.2.1 2007-07-26 utf8helper_read_hook(): reset buffer_modified_flag
% 1.2.2 2007-09-20 convert region instead of buffer if visible region is
% 		   defined
% 1.2.3 2007-09-24 bugfix in utf8_to_latin1(): did not convert two (or more)
% 		   high-bit chars in a row  in UTF8 mode (report P. Boekholt)
% 		   and latin1_to_utf8(): similar problem in non-UTF8 mode.
% 1.2.4 2008-01-22 helper fun register_autoconvert_hooks()
% 		   (called at end of script if evaluated first time).
% 1.2.5 2008-01-25 remove dependency on datutils.sl and sl_utils.sl
% 1.2.6 2008-05-05 no more dependencies
% 		   patches by Paul Boekholt:
% 		     reset CASE_SEARCH also after failure,
% 		     strtrans_utf8_to_latin1("") now works,
% 		     has_invalid_chars(): initialize return value.
% 1.2.7 2008-05-13 Convert Python (and Emacs) special encoding comment.
% 1.2.8 2008-05-20 Fix encoding comment conversion.
% 1.2.9 2008-08-25 name has_invalid_chars() -> utf8helper_find_invalid_char()
% 		   and make it public,
% 		   UTF8Helper_Read_Autoconvert == -2 (warn) setting
% 		   

% TODO: use the iconv module (which is unfortunately undocumented)

% Customisation
% -------------

%!%+
%\variable{UTF8Helper_Read_Autoconvert}
%\synopsis{Convert new-found file to active encoding?}
%\usage{variable UTF8Helper_Read_Autoconvert = 0}
%\description
%  Should a file be converted to the active encoding after opening?
%  (in a "_jed_find_file_after_hooks" hook)
%
%  Possible values:
%    0  -- never
%    1  -- always
%   -1  -- ask user if file contains invalid chars
%   -2  -- warn user if file contains invalid chars
%\notes
%  The "native encoding" is utf8 if Jed runs in UTF-8 mode.
%  It is assumed to be latin1 else.
%  
%  If this variable has a non-zero value when utf8helper is evaluated,
%  a hook is added to _jed_find_file_after_hooks (see Help>Browse Docs>hooks)
%\seealso{UTF8Helper_Write_Autoconvert, latin1_to_utf8, utf8_to_latin1, _slang_utf8_ok}
%!%-
custom_variable("UTF8Helper_Read_Autoconvert", 0);

%!%+
%\variable{UTF8Helper_Write_Autoconvert}
%\synopsis{Reconvert file to original encoding before writing?}
%\usage{variable UTF8Helper_Write_Autoconvert = 0}
%\description
%  Should a file be reconverted in a "_jed_save_buffer_before_hooks" hook,
%  if it was auto-converted after reading?
%
%  Possible values:
%    0  -- never
%    1  -- always
%   -1  -- ask user
%
%\seealso{UTF8Helper_Read_Autoconvert, latin1_to_utf8, utf8_to_latin1}
%!%-
custom_variable("UTF8Helper_Write_Autoconvert", 0);

% Namespace
% ---------

% provide("utf8helper"); % put at end, to enable the idempotent behaviour of 
% hook-setting
implements("utf8helper");

% Functions
% ---------

%!%+
%\function{latin1_to_utf8}
%\synopsis{Convert a buffer from latin-1 to UTF-8 encoding}
%\usage{latin1_to_utf8()}
%\description
%  Scan the active buffer or visible region and convert latin1 encoded
%  characters into their utf8 encoded unicode equivalent.
%
%  If no visible region is defined, set the buffer local variable "encoding"
%  to "utf8".
%\notes
%  To prevent to overshoot the mark, no conversion is done if the "encoding"
%  blocal var is already "utf8". This check is skipped if a visible region
%  is defined: take care for yourself!
%\seealso{utf8_to_latin1}
%!%-
public define latin1_to_utf8()
{
   variable ch, convert_region = is_visible_mark();

   if (convert_region)
     narrow_to_region();
   else if (get_blocal_var("encoding", "") == "utf8")
     {
	message("Buffer is already UTF-8 encoded");
	return;
     }

   push_spot_bob();
   if (_slang_utf8_ok)
     {
	do
	  {
	     skip_chars("[[:print:][:cntrl:]]");
	     ch = what_char();
	     if (ch < 0)
	       {
		  del();
		  insert_char(-ch);
		  go_left_1();
	       }
	  } while (right(1));
     }
   else
     {
	do
	  {
	     skip_chars("\d001-\d127");
	     ch = what_char();
	     if (andelse{ch >= 128}{ch < 192})
	       {
		  del();
		  insert_char(194);
		  insert_char(ch);
		  go_left_1();
	       }
	     else if (andelse{ch >= 192}{ch < 256})
	       {
		  del();
		  insert_char(195);
		  insert_char(ch-64);
		  go_left_1();
	       }
	  } while (right(1));
     }
   % Python code comment pattern: "coding[=:]\s*([-\w.]+)"
   % aliases: iso-8859-1, iso8859-1, 8859, cp819, latin, latin_1, latin1, L1
   bob();
   if (orelse {re_fsearch("coding[:=] *iso-?8859-1")}
	 {re_fsearch("coding[:=] *8859")}
	 {re_fsearch("coding[:=] *cp819")} 
	 {re_fsearch("coding[:=] *latin[-_]?1")} 
	 {re_fsearch("coding[:=] *latin")} 
	 {re_fsearch("coding[:=] *L1")} 
      )
      () = replace_match("coding: utf8", 1);

   pop_spot();
   if (convert_region)
     widen_region();
   else
     define_blocal_var("encoding", "utf8");
}

%!%+
%\function{utf8_to_latin1}
%\synopsis{Convert a buffer from utf8 to latin1 encoding}
%\usage{utf8_to_latin1()}
%\description
%  Scan the active buffer or visible region and convert latin1 encoded
%  characters into their utf8 equivalent.
%
%  Set the buffer-local variable "encoding" to "latin1".
%\notes
%  If Jed is not in utf8 mode, data loss can occure if the buffer or region is
%  not in utf8 encoding (and the buffer-local variable "encoding" is not set):
%  characters '\d194' and '\d195' are deleted.
%\seealso{latin1_to_utf8}
%!%-
public define utf8_to_latin1 ()
{
   variable ch, convert_region = is_visible_mark();

   if (convert_region)
     narrow_to_region();
   else if (get_blocal_var("encoding", "utf8") != "utf8")
     throw RunTimeError, "Buffer is not utf8 encoded";

   push_spot_bob();
   if (_slang_utf8_ok) {
      do {
	 ch = what_char();
	 if ((ch >= 128) and (ch < 256)) {
	    del();
	    insert_byte(ch);
	    go_left_1();
	 }
      } while ( right(1) );
   } else {
      variable old_case_search = CASE_SEARCH;
      CASE_SEARCH = 1;
      try
	{
	   while (fsearch_char(194)) % ''
	     del();
	   bob();
	   while (fsearch_char(195)) {  % ''
	      del();
	      ch = what_char();
	      del();
	      insert_byte(ch+64);
	   }
	}
      finally
	{
	   CASE_SEARCH = old_case_search;
	}
   }

   % Python code comment pattern: "coding[=:]\s*([-\w.]+)"
   % aliases: utf_8, U8, UTF, utf8
   % we support just the most frequently used:
   bob();
   if (orelse {re_fsearch("coding[:=] *utf_?8")}
	 {re_fsearch("coding[:=] *UTF")}
	 {re_fsearch("coding[:=] *U8")} 
      )
      () = replace_match("coding: utf8", 1);

   pop_spot ();
   if (convert_region)
     widen_region();
   else
     define_blocal_var("encoding", "latin1");
}

% String conversion
% -----------------

% Taken from digraph.sl (where it is private), renamed and generalized by GM
% It now works also outside utf8 mode
public define strtrans_latin1_to_utf8(str)
{
   variable ch, new_str = "", charlist = {};
   % simpler and faster implementation if UTF-8 support is active:
   if (_slang_utf8_ok)
     {
	foreach ch (str)
	  new_str += char(ch);
	return new_str;
     }
   % failsave version else:
   foreach ch (str)
     {
	if (andelse{ch >= 128}{ch < 192})
	  new_str += char(194) + char(ch);
	else if (andelse{ch >= 192}{ch < 256})
	  new_str += char(195) + char(ch-64);
	else
	  new_str += char(ch);
     }
   return new_str;
}

public define strtrans_utf8_to_latin1(str)
{
   if (str == "") return "";
   variable ch, shift = 0, charlist = {};
   foreach ch (str)
     {
        switch (ch)
          { case 194: continue; }
          { case 195: shift = 64; continue; }
        list_append(charlist, ch+shift);
        shift = 0;
     }
   return array_to_bstring(typecast([__push_list(charlist)], UChar_Type));
}

% Hooks for automatic conversion
% ------------------------------

% From David Goodger in http://www.pycheesecake.org/wiki/ZenOfUnicode:
%
% - The first byte of a non-ASCII character encoded in UTF-8 is
%   always in the range 0xC0 to 0xFD, and all subsequent bytes are in
%   the range 0x80 to 0xBF.  The bytes 0xFE and 0xFF are never used.

%!%+
%\function{utf8helper_find_invalid_char}
%\synopsis{Check for non-printable characters in current buffer}
%\usage{utf8helper_find_invalid_char()}
%\description
% Check the current buffer for "invalid" (wrong encoded) characters.
% 
% Can be used to test if a file is valid UTF8 (in utf8-mode) or
% if it is (most likely) UTF8 encoded when Jed is not in utf8-mode.
% 
% Leaves the point at the first "invalid" char or bob.
%\seealso{latin1_to_utf8, utf8_to_latin1, _slang_utf8_ok}
%!%-
public define utf8helper_find_invalid_char()
{
   variable ch, result = 0;
   if (_slang_utf8_ok)
     {
	% bob();
	skip_chars("[[:print:][:cntrl:]]");
	result = not(eobp());
	% bob();
	return result;
     }
   % Jed with latin-* encoding:
   %  poor mans test: '\194' == '\x82' == 'Â' or '\195' == '\x83' == 'Ã'
   %    	      followed by high-bit character (ch >= 128).
   % While this is a completely valid string sequence in latin-1 encoding,
   % is is highly indicative of utf8 encoded strings.
   foreach ch ([194, 195])
     {
	bob();
	if (fsearch_char(ch) and right(1))
	  {
	     result = what_char() >= 128;
	     break;
	  }
     }
   return result;
}

% convert encoding to native encoding (or vice versa)
static define autoconvert(to_native)
{
   % unset readonly flag and file binding,
   % so that we can edit without further questions.
   variable file, dir, name, flags;
   (file, dir, name, flags) = getbuf_info();
   setbuf_info("", dir, name, flags & ~0x8);

   if (to_native) {
      if (_slang_utf8_ok)
	 latin1_to_utf8();
      else
	 utf8_to_latin1();
   }
   else { % convert from native encoding to alternative
      if (_slang_utf8_ok)
	 utf8_to_latin1();
      else
	 latin1_to_utf8();
   }

   % reset the buffer info
   setbuf_info(file, dir, name, flags);
}

static define utf8helper_read_hook()
{
   variable msg,
      read_autoconvert = get_blocal_var("utf8helper_read_autoconvert",
					UTF8Helper_Read_Autoconvert);
   % show("utf8helper_read_hook() called. read_autoconvert == ", read_autoconvert);
   
   % read_autoconvert == 0 means "do not convert":
   !if (read_autoconvert)
     return;

   % Check for out of place encoding - no need to convert if there is no
   % invalid character.

   % utf8helper_find_invalid_char() moves point to first invalid char 
   push_spot_bob(); 

   !if (utf8helper_find_invalid_char()) {
      % message("no offending chars");
      read_autoconvert = 0;
   }

   % ask user if read_autoconvert is -1, warn if it is -2
   if (read_autoconvert == -1) {
      msg = ["Buffer seems to contain UTF-8 chars. Convert to iso-latin-1",
	     "Buffer contains high-bit chars. Convert to UTF-8"];
      read_autoconvert = get_y_or_n(msg[_slang_utf8_ok]);
      % and store the answer
      define_blocal_var("utf8helper_read_autoconvert", read_autoconvert);
   }
   else if (read_autoconvert == -2) {
      msg = ["Buffer seems to contain UTF-8 char",
	     "Buffer contains high-bit char"];
      vmessage(msg[_slang_utf8_ok] + " in line %d! (and maybe more)", 
	       what_line());
      read_autoconvert = 0;
   }

   pop_spot();

   % abort if no invalid chars or user decided to skip autoconversion
   !if (read_autoconvert)
     return;

   % convert encoding (to_native = 1)
   autoconvert(1);

   % mark for re-conversion before writing:
   if (not(blocal_var_exists("utf8helper_write_autoconvert")))
     define_blocal_var("utf8helper_write_autoconvert",
	UTF8Helper_Write_Autoconvert);
}

static define utf8helper_write_hook(file)
{
   % Get autoconvert option:
   % Default is 0, so do not convert if it is not autoconverted
   % TODO: consider the case where the user always wants a definite encoding.
   variable write_autoconvert = get_blocal_var("utf8helper_write_autoconvert", 0);

   % ask user if default is -1
   if (write_autoconvert == -1) {
      write_autoconvert = get_y_or_n("Re-convert buffer encoding before saving");
      % and store the result
      define_blocal_var("utf8helper_write_autoconvert", write_autoconvert);
   }
   if (write_autoconvert)
      autoconvert(0);
}

static define utf8helper_restore_hook(file)
{
   if (get_blocal_var("utf8helper_write_autoconvert", 0))
      autoconvert(1);
}

% register the autoconvert hooks
% ------------------------------
% 
% If
% * this file is evaluated the first time and
% * the custom variables are non-zero
% ::

!if (_featurep("utf8helper")) {
   if (UTF8Helper_Read_Autoconvert)
      append_to_hook("_jed_find_file_after_hooks", &utf8helper_read_hook);
   if (UTF8Helper_Write_Autoconvert) {
      append_to_hook("_jed_save_buffer_before_hooks", &utf8helper_write_hook);
      append_to_hook("_jed_save_buffer_after_hooks", &utf8helper_restore_hook);
   }
}
% announce the feature now
provide("utf8helper");


% Joerg Sommer also wrote:
%   And I've written some functions for UTF-8 features. Maybe they get a menu
%   entry "Edit->UTF-8 specials".
%
% Suggestion: (place them under Edit>Re&gion Ops, as they act on regions)
%
static define insert_after_char(char)
{
   narrow_to_region();
   try
     {
        bob();
        while (right(1))
          insert_char(char);
     }
   finally
     {
        widen_region();
     }
}

% http://www.utf8-zeichentabelle.de/unicode-utf8-table.pl
static define stroke() { insert_after_char(0x336); }
static define underline() { insert_after_char(0x332); }
static define double_underline() { insert_after_char(0x333); }
static define overline() { insert_after_char(0x305); }
static define double_overline() { insert_after_char(0x33f); }



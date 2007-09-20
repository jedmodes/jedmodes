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
% 1.2.2 2007-09-20 vert region instead of buffer if visible region is defined

implements("utf8helper");

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
%\notes
%  The "native encoding" is utf8 if Jed runs in UTF-8 mode.
%  It is assumed to be latin1 else.
%\seealso{UTF8Helper_Write_Autoconvert, latin1_to_utf8, utf8_to_latin1, _slang_utf8_ok}
%!%-
custom_variable("UTF8Helper_Read_Autoconvert", 0);

%!%+
%\variable{UTF8Helper_Write_Autoconvert}
%\synopsis{Reconvert file to original encoding before writing?}
%\usage{variable UTF8Helper_Read_Autoconvert = 0}
%\description
%  Should a file be reconverted in a "_jed_save_buffer_before_hooks" hook,
%  if it was auto-converted after reading?
%
%  Possible values:
%    0  -- never
%    1  -- always
%   -1  -- ask user
%
%\seealso{UTF8Helper_Write_Autoconvert, latin1_to_utf8, utf8_to_latin1}
%!%-
custom_variable("UTF8Helper_Write_Autoconvert", 0);

% Requirements
% ------------

% modes from http://jedmodes.sf.net
autoload("get_blocal", "sl_utils");
autoload("list2array", "datutils");
	   
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
   variable ch, act_on_region = is_visible_mark();
   if (act_on_region)
     narrow_to_region();
   else if (get_blocal("encoding") == "utf8")
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
	       }
	  } while (not eobp());
     }
   else
     {
	do
	  {
	     ch = what_char();
	     if (andelse{ch >= 128}{ch < 192})
	       {
		  del();
		  insert_char(194);
		  insert_char(ch);
	       }
	     else if (andelse{ch >= 192}{ch < 256})
	       {
		  del();
		  insert_char(195);
		  insert_char(ch-64);
	       }
	  } while (right(1));
     }
   pop_spot();
   if (act_on_region)
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
   variable ch, act_on_region = is_visible_mark();

   if (act_on_region)
     narrow_to_region();
   else if (get_blocal("encoding", "utf8") != "utf8")
     error("Buffer is not utf8 encoded");

   push_spot_bob();
   if (_slang_utf8_ok)
     {
	do
	  {
	     ch = what_char();
	     if ((ch >= 128) and (ch < 256))
	       {
		  del();
		  insert_byte(ch);
	       }
	  } while ( right(1) );
     }
   else
     {
	variable old_case_search = CASE_SEARCH;
	CASE_SEARCH = 1;
	while (fsearch_char(194)) % '‚'
	  del();
	bob();
	while (fsearch_char(195))  % 'ƒ'
	   {
	      del();
	      ch = what_char();
	      del();
	      insert_byte(ch+64);
	   }
	CASE_SEARCH = old_case_search;
     }
   pop_spot ();
   if (act_on_region)
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
   variable ch, shift = 0, charlist = {};
   foreach ch (str)
     {
        switch (ch)
          { case 194: continue; }
          { case 195: shift = 64; continue; }
        list_append(charlist, ch+shift);
        shift = 0;
     }
   return array_to_bstring(list2array(charlist, UChar_Type));
}



% Hooks for automatic conversion
% ------------------------------

% scan for non-printable characters in current buffer
% leaves the point at the first invalid char or bob
static define has_invalid_chars()
{
   variable ch, result;
   bob();
   if (_slang_utf8_ok)
     {
	skip_chars("[[:print:][:cntrl:]]");
	result = not(eobp());
	bob();
     }
   else % Jed with latin-* encoding
     {
	% poor mans test: '\194' == '\x82' == 'Â' or '\195' == '\x83' == 'Ã'
	%      	    	  followed by high-bit character (ch >= 128).
	% While this is a completely valid string sequence in latin-1 encoding,
	% is is highly indicative of utf8 encoded strings.
	foreach ch ([194, 195])
	  {
	     if (fsearch_char(ch) and right(1))
	       {
		  result = what_char() >= 128;
		  break;
	       }
	  }
     }
   return result;
}

private define utf8helper_read_hook()
{
   variable msg, do_convert = get_blocal("utf8helper_read_autoconvert",
      UTF8Helper_Read_Autoconvert);
   % ask user if default is -1
   if (do_convert == -1)
     {
	push_spot();
	% has_invalid_chars() moves point to first invalid char to give the
	% user a chance to examine the situation
	!if (has_invalid_chars())
	  {  % no need to bother the user with questions in this case
	     % message("no offending chars");
	     return;
	  }
	update_sans_update_hook(1); % repaint to show "invalid" char
	if (_slang_utf8_ok)
	  msg = "Buffer contains high-bit chars. Convert to UTF-8";
	else
	  msg = "Buffer seems to contain UTF-8 chars. Convert to iso-latin-1";
	do_convert = get_y_or_n(msg);
	pop_spot();
     }
   % and store the result
   define_blocal_var("utf8helper_read_autoconvert", do_convert);

   % abort if do_convert == 0 ("do not convert")
   !if (do_convert)
     return;

   % convert encoding
   if (_slang_utf8_ok)
     latin1_to_utf8();
   else
     utf8_to_latin1();

   % reset the buffer modified flag as we did not change content
   % (prevents questions when the buffer is closed without further changes).
   set_buffer_modified_flag(0);

   % mark for re-conversion before writing:
   if (not(blocal_var_exists("utf8helper_write_autoconvert")))
     define_blocal_var("utf8helper_write_autoconvert",
	UTF8Helper_Write_Autoconvert);
}

static define utf8helper_write_hook(file)
{
   variable do_convert = get_blocal("utf8helper_write_autoconvert", 0);
   % Default is 0, so do not convert if it is not autoconverted
   % TODO: consider the case where the user always wants a definite encoding.

   !if (do_convert)
     return;

   % ask user if default is -1
   if (do_convert == -1)
     do_convert = get_y_or_n("Re-convert buffer encoding before saving");
   % and store the result
   define_blocal_var("utf8helper_write_autoconvert", do_convert);

   % convert encoding
   if (_slang_utf8_ok)
     utf8_to_latin1();
   else
     latin1_to_utf8();
}

static define utf8helper_restore_hook(file)
{
   if (_slang_utf8_ok)
     if (get_blocal("encoding", "") == "latin1")
       latin1_to_utf8();
   else
     if (get_blocal("encoding", "") == "utf8")
       utf8_to_latin1();
}

!if (_featurep("utf8helper"))
{
   if (UTF8Helper_Read_Autoconvert)
     append_to_hook("_jed_find_file_after_hooks", &utf8helper_read_hook);
   if (UTF8Helper_Write_Autoconvert)
     {
	append_to_hook("_jed_save_buffer_before_hooks", &utf8helper_write_hook);
	append_to_hook("_jed_save_buffer_after_hooks", &utf8helper_restore_hook);
     }
}
provide("utf8helper");

% Joerg Sommer also wrote:
%   And I've written some functions for UTF-8 features. Maybe they get a menu
%   entry "Edit->UTF-8 specials".
#if (_slang_utf8_ok)
define insert_after_char(char)
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
define stroke() { insert_after_char(0x336); }
define underline() { insert_after_char(0x332); }
define double_underline() { insert_after_char(0x333); }
define overline() { insert_after_char(0x305); }
define double_overline() { insert_after_char(0x33f); }

#endif


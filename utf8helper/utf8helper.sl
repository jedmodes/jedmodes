% utf8-helper.sl: converting latin-1 <-> uft8.
% 
% Copyright (c) 2006 John E. Davis, Joerg Sommer, Guenter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 1.1 2007-06-01 

% Code based on examples in Help>Browse Docs>utf8 by JED and a posting
% by Joerg Sommer to the jed-users list.

% The functions in this mode require slang2 to work properly but
% should also work without UTF-8 support.

provide("utf8helper");
autoload("list2array", "datutils");

% The "high-bit" characters::

%  in latin-1::

%    0 1 2 3 4 5 6 7 8 9 A B C D E F 
% A0   ¡ ¢ £ ¤ ¥ ¦ § ¨ © ª « ¬ ­ ® ¯
% B0 ° ± ² ³ ´ µ ¶ · ¸ ¹ º » ¼ ½ ¾ ¿
% C0 À Á Â Ã Ä Å Æ Ç È É Ê Ë Ì Í Î Ï
% D0 Ğ Ñ Ò Ó Ô Õ Ö × Ø Ù Ú Û Ü İ Ş ß
% E0 à á â ã ä å æ ç è é ê ë ì í î ï
% F0 ğ ñ ò ó ô õ ö ÷ ø ù ú û ü ı ş ÿ

% and UTF-8::

%    0 1 2 3 4 5 6 7 8 9 A B C D E F 
% A0 Â  Â¡ Â¢ Â£ Â¤ Â¥ Â¦ Â§ Â¨ Â© Âª Â« Â¬ Â­ Â® Â¯
% B0 Â° Â± Â² Â³ Â´ Âµ Â¶ Â· Â¸ Â¹ Âº Â» Â¼ Â½ Â¾ Â¿
% C0 Ã€ Ã Ã‚ Ãƒ Ã„ Ã… Ã† Ã‡ Ãˆ Ã‰ ÃŠ Ã‹ ÃŒ Ã Ã Ã
% D0 Ã Ã‘ Ã’ Ã“ Ã” Ã• Ã– Ã— Ã˜ Ã™ Ãš Ã› Ãœ Ã Ã ÃŸ
% E0 Ã  Ã¡ Ã¢ Ã£ Ã¤ Ã¥ Ã¦ Ã§ Ã¨ Ã© Ãª Ã« Ã¬ Ã­ Ã® Ã¯
% F0 Ã° Ã± Ã² Ã³ Ã´ Ãµ Ã¶ Ã· Ã¸ Ã¹ Ãº Ã» Ã¼ Ã½ Ã¾ Ã¿

%!%+
%\function{lat1_to_utf8}
%\synopsis{Convert a buffer from latin-1 to UTF-8 encoding}
%\usage{lat1_to_utf8()}
%\description
%  Scan the active buffer and convert iso-latin-1 encoded characters into
%  their UTF-8 encoded unicode equivalent.
%\seealso{utf8_to_lat1}
%!%-
public define lat1_to_utf8()
{
   variable ch;
   push_spot();
   bob();
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
	     if ((ch >= 128) and (ch < 192))
	       {
		  del();
		  insert_char(194);
		  insert_char(ch);
	       }
	     else if ((ch >= 192) and (ch < 256))
	       {
		  del();
		  insert_char(195);
		  insert_char(ch-64);
	       }
	  } while (right(1));
     }
   pop_spot();
}


%!%+
%\function{utf8_to_lat1}
%\synopsis{Convert a buffer from latin-1 to UTF-8 encoding}
%\usage{utf8_to_lat1()}
%\description
%  Scan the active buffer and convert UTF-8 encoded characters into their
%  iso-latin-1 equivalent.
%\notes
%  If used from a non-UTF-8 enabled jed, data loss can occure if the buffer is
%  not in utf8 encoding (characters '\d194' and '\d195' are deleted).
%\seealso{lat1_to_utf8}
%!%-
public define utf8_to_lat1 ()
{
   variable ch;
   push_spot();
   bob();
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
}

% String conversion
% -----------------

% This function has the effect of converting an ISO-Latin string UTF-8 if in
% UTF-8 mode.  It does not work on DOS/Windows.
% 
% Taken from digraph.sl where it is private, renamed and generalized by GM
% It now works also in a non-utf8 aware Jed instance
public define strtrans_lat1_to_utf8(str)
{
   variable ch, new_str = "", charlist = {};
   % simpler and faster implementation if UTF-8 support is active:
   if (_slang_utf8_ok)
     {
	foreach ch (str)
	new_str = strcat (new_str, char(ch));
	return new_str;
     }
   % failsave version else:
   foreach ch (str)
     {
	if ((ch >= 128) and (ch < 192))
	  {
	     list_append(charlist, 194);
	     list_append(charlist, ch);
	  }
	else if ((ch >= 192) and (ch < 256))
	  {
	     list_append(charlist, 195);
	     list_append(charlist, ch-64);
	  }
	else
	  list_append(charlist, ch);
     }
   return array_to_bstring(list2array(charlist, UChar_Type));
}


public define strtrans_utf8_to_lat1(str)
{
   variable ch, shift = 0, charlist = {};
   foreach ch (str)
     {
	switch (ch)
	  { case 194: shift = 0; continue; }
	  { case 195: shift = 64; continue; }
	list_append(charlist, ch+shift);
	shift = 0;
     }
   return array_to_bstring(list2array(charlist, UChar_Type));
}


% Hooks for automatic conversion
% ------------------------------

define lat1_to_utf8_hook()
{
   if (_NARGS == 1)
     pop();
   
   if (andelse {blocal_var_exists("do_utf8_to_lat1")}
	{not get_blocal_var("do_utf8_to_lat1")})
     return;
   
   push_spot();
   try
     {
        bob();
        skip_chars("[[:print:][:cntrl:]]");
	
        if ( eobp() )
	  {
	     create_blocal_var("do_utf8_to_lat1");
	     set_blocal_var(0, "do_utf8_to_lat1");
	     return;
	  }
	
        !if ( blocal_var_exists("do_utf8_to_lat1") )
	  {
	     create_blocal_var("do_utf8_to_lat1");
	     set_blocal_var(0, "do_utf8_to_lat1");
	     update(1);
	     flush("This buffer contains non-UTF-8 chars. Convert them UTF-8? y/n ");
	     if ( getkey() != 'y' )
	       return;
	     flush("Should this buffer be converted back upon save? y/n ");
	     set_blocal_var(getkey() == 'y', "do_utf8_to_lat1");
	  }
	
        do
	  {
	     variable ch = what_char();
	     if (ch < 0)
	       {
		  del();
		  insert_char(-ch);
	       }
	     skip_chars("[[:print:][:cntrl:]]");
	  } while ( not eobp() );
        set_buffer_modified_flag(0);
     }
   catch UserBreakError:
   ;
   finally
     {
        pop_spot();
        flush("");
     }
}

define utf8_to_lat1_hook(file)
{
   !if (andelse {blocal_var_exists("do_utf8_to_lat1")}
	{get_blocal_var("do_utf8_to_lat1")})
     return;
   
   push_spot();
   bob();
   do
     {
        variable ch = what_char();
        if (ch >= 128 and ch < 256)
	  {
	     del();
	     insert_byte(ch);
	  }
     } while ( right(1) );
   pop_spot();
}

append_to_hook("_jed_find_file_after_hooks", &lat1_to_utf8_hook());
append_to_hook("_jed_save_buffer_after_hooks", &lat1_to_utf8_hook());
append_to_hook("_jed_save_buffer_before_hooks", &utf8_to_lat1_hook());

% #endif

% And I've written some functions for UTF-8 features. Maybe they get a menu
% entry "Edit->UTF-8 specials".

#if (_slang_utf8_ok)
define insert_after_char(char)
{
   !if (markp())
     throw UsageError, "You must define a region";
   
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
% #endif


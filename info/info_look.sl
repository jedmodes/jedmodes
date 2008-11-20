% info_look.sl
% mode-sensitive Info index lookup facility.
% 
% $Id: info_look.sl,v 1.4 2008/11/20 16:27:09 paul Exp paul $
% Keywords: help languages
% 
% Copyright (c) 2003-2008 Paul Boekholt
% Released under the terms of the GNU GPL (version 2 or later).
% 
% Some functions to use hyperhelp's help_for_word_hook with
% hyperman and info.

autoload("unix_apropos", "hyperman");
require("info");
use_namespace("info");
% Look up word in manpage in mode-dependent section
public define manpage_lookup(word)
{
   try
     {
	ifnot (blocal_var_exists("man_section"))
	  unix_man(word);
	else
	  unix_man(sprintf("%s(%s)", word, get_blocal_var("man_section")));
     }
   catch RunTimeError:
     {
	unix_apropos(word);
     }
}

% Look up word in info in index if it exists, as node otherwise
public define info_lookup()	       %  word
{
   ifnot (_NARGS) get_word();
   variable word = ();
   ifnot (blocal_var_exists("info_page"))
     throw RunTimeError, "Don't know what info page to look in";
   variable buf = whatbuf(), page = get_blocal_var("info_page");
   variable e;
   try (e)
     {
	info_reader();
	info_find_node(sprintf("(%s)Top", page));
	if(re_fsearch("^* \\(.*[Ii]ndex\\):"))
	  info_index(word);
	else
	  info_find_node(word);
	pop2buf(buf);
     }
   catch RunTimeError:
     {
	sw2buf(buf);
	throw;
     }
}

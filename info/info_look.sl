% info_look.sl
% mode-sensitive Info index lookup facility.
% 
% $Id: info_look.sl,v 1.1 2003/08/03 20:08:13 paul Exp paul $
% Keywords: help languages
% 
% Copyright (c) 2003 Paul Boekholt <p.boekholt@hetnet.nl>
% Released under the terms of the GNU GPL (version 2 or later).
% 
% Some functions to use hyperhelp's help_for_word_hook with
% hyperman and info.

require("infospace");
use_namespace("info");
autoload("unix_apropos", "hyperman");
% Look up word in manpage in mode-dependent section
public define manpage_lookup(word)
{
   ERROR_BLOCK
     {
	_clear_error;
	unix_apropos(word);
     }
   !if (blocal_var_exists("man_section"))
     unix_man(word);
   else
     unix_man(sprintf("%s(%s)", word, get_blocal_var("man_section")));
}


% Look up word as info page, or man page if not found
% This works more or less like the stand alone info browser.
% You can bind this to C-h i if you want.
public define info()
{
   !if (_NARGS)
     read_mini("info", get_word(), "");
   variable word = ();
   info_mode;
   find_dir;
   if (bol_fsearch("* " + word))
     follow_current_xref;
   else
     manpage_lookup(word);
}

% Look up word in info in index if it exists, as node otherwise
public define info_lookup()	       %  word
{
   !if (_NARGS) get_word;
   variable word = ();
   !if (blocal_var_exists("info_page"))
     error("Don't know what info page to look in");
   variable page = get_blocal_var("info_page");
   variable buf = whatbuf;
   push_spot; % for some reason point moves in calling buffer
   info_mode;
   ERROR_BLOCK
     {
	sw2buf(buf);
	pop_spot;
     }
   info_find_node(sprintf("(%s)Top", page));

   if(re_fsearch("^* \\(.*[Ii]ndex\\):"))
     info_index(word);
   else
     info_find_node(word);
   pop2buf(buf);
   pop_spot;
}

% howto.sl
% 
% $Id: howto.sl,v 1.1.1.1 2004/10/28 08:16:21 milde Exp $
% Keyword: docs, outlines
% 
% Copyright (c) 2003 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This is a mode for reading Linux-HOWTOS in a tree view like MS-Word's
% online reading mode.  It works well if the HOWTO is conventionally
% formatted, if it isn't it tries to do the job but not very hard.  It
% should also work with the S-Lang guide, if it's ToC is correct by now. 
% Look for treemode.sl and walk.sl at www.paneura.com/~dino
% 
% Since version 1.4, we use usermarks.  It should now be possible to use
% howto_mode on an editable file, as long as the ToC is up to date.  See
% also the document outline function in Guido's Latex mode.  If you don't
% use navigate.sl, you have to find a key for walk_backward().  I use the
% howto_hook:
% define howto_hook()
% {
%    view_mode;
%    local_setkey("walk_backward", "l");
% }

require("treemode");
require("walk");

% from diffmode
define howto_goto_pos()
{
   variable l = what_line, mode;
   variable LineInfo, li;;

   !if (blocal_var_exists("TreeInfo"))
      error("No Tree info!");
   LineInfo = get_blocal_var("TreeInfo");

   if (l >= length(LineInfo))
      error("no info for this line!");

   li = LineInfo[l];

   if (li == NULL)
      error("cannot show this item.");

   walk_mark_current_position();
   
   setbuf(user_mark_buffer(li));
   widen();  % just in case...
   goto_user_mark(li);
   walk_goto_current_position();
   walk_store_marked_position();
   recenter(1);
}

define howto_mode()
{
   variable section, line, content, hbuf, tbuf;
   hbuf = whatbuf;
   tbuf = " " + hbuf + " ToC";
   bob();
   !if (re_fsearch("^[ \t]*[-_]+")) error("could not find beginning of ToC");
   go_down_1;
   push_mark;
   !if(re_fsearch("^[ \t]*[-_]+")) error("could not find end of ToC");
   content = bufsubstr;

   % narrow the ToC away so it can't be matched
   push_mark_eob;
   narrow;
   bob;

   sw2buf(tbuf);
   onewindow;
   erase_buffer;
   insert(content);
   
   % get rid of lines that don't look like ToC items
   bob;
   while (not eobp())
     {
   	if (string_match(line_as_string(), "^ *[0-9\.]+", 1))
   	  go_down_1;
   	else
   	  delete_line;
     }

   if (bobp and eobp)
     error ("could not find ToC");
   variable LineData = Mark_Type[1 + what_line];
   bob;
   insert ("contents of " + hbuf + "\n");
   
   % try to find lines that match ToC items
   while (not eobp())
     {
	bol_skip_white;
	push_mark;
	skip_chars("0-9.");
	section = bufsubstr;
	setbuf (hbuf);
	!if (re_fsearch("^[ \t]*" + section))
	  !if(re_bsearch("^[ \t]*" + section))
	    {
	       setbuf(tbuf);
	       go_down_1;
	       continue;
	    }
	create_user_mark;
	setbuf(tbuf);
	LineData[what_line()] = ();
	go_down_1;
     }
   define_blocal_var("TreeInfo", LineData);

   tree_mode();
   tree_user_func(&howto_goto_pos);
   local_setkey("tree_user", "^M");
   setbuf(hbuf);
   runhooks("howto_hook");
}

% Filter buffer: show/hide lines that match a pattern
%
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% 2005-04-01 first public version
%
% USAGE:
% put in the jed_library_path and make available e.g. by a keybinding or
% via the following menu entry in your .jedrc 
% (make-ini >= 2.2 will do this for you)
% 
#iffalse %<INITIALIZATION>
define filter_view_load_popup_hook(menubar)
{
   menu_insert_item (5, "Global.&Buffers", "&Hide Matching Lines", "set_matching_hidden");
   menu_insert_item (6, "Global.&Buffers", "Show &Only Matching Lines", "set_matching_hidden(0)");
   menu_insert_item (7, "Global.&Buffers", "Show &All Lines", "set_buffer_hidden(0)");
}
append_to_hook ("load_popup_hooks", &filter_view_load_popup_hook);

"set_buffer_hidden", "filter-view.sl";
"set_matching_hidden", "filter-view.sl";
"toggle_hidden_lines", "filter-view.sl";
"set_comments_hidden", "filter-view.sl";
_autoload(4);
#endif %</INITIALIZATION>
 
% requirements
autoload("get_comment_info", "comments");
autoload("push_defaults", "sl_utils");

% Hide/unhide the whole buffer
public define set_buffer_hidden() % (hide=1)
{
   variable hide = 1;
   if (_NARGS)
     hide = ();
   push_spot();
   !if (is_visible_mark())
     mark_buffer();
   set_region_hidden(hide);
   pop_spot();
}

% Filter: hide all lines that match the regexp pat   
public define set_matching_hidden() %(hide=1, [pat])
{
   variable hide, pat;
   (hide, pat) = push_defaults(1, NULL, _NARGS);
   
   variable prompt = ["Show only", "Hide all"];
   prompt = prompt[hide] + " lines containing regexp:";
   if (pat == NULL)
     pat = read_mini(prompt, "", ".*");
   
   push_spot_bob();
   % speadup for "matchall"
   if (pat == ".*")
     {
	set_buffer_hidden(hide);
	pop_spot();
	return;
     }
   !if (hide) 
     set_buffer_hidden();
   while (andelse{not(eobp())}{re_fsearch(pat)})
     {
	set_line_hidden(hide);
	eol;
     }
   
   pop_spot();
}

public define toggle_hidden_lines()
{
   push_spot_bob();
   do
     set_line_hidden(not(is_line_hidden()));
   while (down_1);
   pop_spot();
}

public define set_comments_hidden() % (hide=1)
{
   variable hide;
   (hide) = push_defaults(1, _NARGS);
   variable cinfo = get_comment_info();
   variable white = "[ \\t]*";
   variable pat = "^" + white + cinfo.cbeg + ".*" + cinfo.cend + white + "$";
   set_matching_hidden(hide, pat);
}

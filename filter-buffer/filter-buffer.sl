% Filter buffer: show/hide lines that match a pattern
%
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% 2005-04-01 0.1 first public version
% 2005-05-31 0.2 bugfix in <INITIALIZATION> block and set_comments_hidden()
%                (escaping special chars in regexp pattern) report P. Boekholt
%		 added tm documentation
%		 
% USAGE:
% put in the jed_library_path and make available by a keybinding or
% via the following menu entry in your .jedrc 
% (make-ini >= 2.2 will do this for you)
% 
% Beware: hidden lines are still part of a defined region, thus
%         copying a region will copy the hidden lines as well. (And
%         evaluating a region will evaluate the hidden lines.)
% 
#iffalse %<INITIALIZATION>
define filter_buffer_load_popup_hook(menubar)
{
   menu_insert_item (5, "Global.&Buffers", "&Hide Matching Lines", "set_matching_hidden");
   menu_insert_item (6, "Global.&Buffers", "Show &Only Matching Lines", "set_matching_hidden(0)");
   menu_insert_item (7, "Global.&Buffers", "Show &All Lines", "set_buffer_hidden(0)");
}
append_to_hook ("load_popup_hooks", &filter_buffer_load_popup_hook);

"set_buffer_hidden", "filter-buffer.sl";
"set_matching_hidden", "filter-buffer.sl";
"toggle_hidden_lines", "filter-buffer.sl";
"set_comments_hidden", "filter-buffer.sl";
_autoload(4);
#endif %</INITIALIZATION>
 
% requirements
autoload("get_comment_info", "comments");
autoload("push_defaults", "sl_utils");


%!%+
%\function{set_buffer_hidden}
%\synopsis{Hide/unhide the whole buffer}
%\usage{Void set_buffer_hidden(hide=1)}
%\description
%  Set or remove the "hidden line" flag for the whole buffer.
%  If a visible region is defined, act on it instead.
%\notes
%  set_buffer_hidden is called by set_matching_hidden(".*")
%  for performace reasons
%\seealso{set_region_hidden, set_matching_hidden, toggle_hidden_lines}
%!%-
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

%!%+
%\function{set_matching_hidden}
%\synopsis{Hide all lines that match the regexp \var{pat}}
%\usage{Void set_matching_hidden() %(hide=1, [pat])}
%\description
%  Filter the buffer, hiding all lines matching the regular expression
%  \var{pat}. 
%  If \var{hide} == 0, make visible the matching lines instead.
%  
%  If called without optional argument \var{pat}, ask for a pattern in
%  the minibuffer.
%\example
%#v+
%  set_matching_hidden()         % ask for pattern, hide matching lines
%  set_matching_hidden(1)        % ask for pattern, unhide matching lines
%  set_matching_hidden(0, "$%")  % hide lines starting with "%"
%#v-
%\notes
%  Beware: hidden lines are still part of a defined region, thus
%  copying a region will copy the hidden lines as well. (And
%  evaluating a region will evaluate the hidden lines.)
%\seealso{set_buffer_hidden, toggle_hidden_lines, set_line_hidden}
%!%-
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

%!%+
%\function{toggle_hidden_lines}
%\synopsis{Toggle the hidden attribute of all lines}
%\usage{Void toggle_hidden_lines()}
%\description
%  Toggle the hidden attribute of all lines in a buffer, i.e.
%  inverse the visibility of the lines.
%\seealso{set_line_hidden, set_buffer_hidden, set_matching_hidden}
%!%-
public define toggle_hidden_lines()
{
   push_spot_bob();
   do
     set_line_hidden(not(is_line_hidden()));
   while (down_1);
   pop_spot();
}

%!%+
%\function{set_comments_hidden}
%\synopsis{Set hidden attribute for all comment lines}
%\usage{Void set_comments_hidden(hide=1)}
%\description
%  Hide (or make visible) all comment lines in a buffer by setting the
%  hidden attribute.
%  
%  Calls \var{set_matching_hidden} with a regular expression derived from 
%  the cbeg and cend strings obtained with \var{get_comment_info}.
%\notes
%  A comment line is a line that contains only commented out text 
%  and optional whitespace.
%  
%  \var{set_comments_hidden} doesnot work for multiline comments.
%  
%  Beware: hidden lines are still part of a defined region, thus
%  copying a region will copy the hidden lines as well. (And
%  evaluating a region will evaluate the hidden lines.)
%\seealso{set_matching_hidden, get_comment_info, comment_line}
%!%-
public define set_comments_hidden() % (hide=1)
{
   variable hide = push_defaults(1, _NARGS);    % optional argument
   
   variable cbeg, cend, pattern, 
     white = "[ \\t]*", re_chars = "\\^$[]*.+?",
     cinfo = get_comment_info();
   
   % prepare regexp pattern
   if (cinfo == NULL)
     verror("no comments defined for mode %s", get_mode_name());
   cbeg = str_quote_string (strtrim(cinfo.cbeg), re_chars, '\\');
   cend = str_quote_string (strtrim(cinfo.cend), re_chars, '\\');
   pattern = "^" + white + cbeg + ".*" + cend + white + "$";
   
   set_matching_hidden(hide, pattern);
}

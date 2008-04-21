% Filter buffer: show/hide lines that match a pattern
% ===================================================
%
% Copyright (c) 2006 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% 2005-04-01 0.1   first public version
% 2005-05-31 0.2   bugfix in INITIALIZATION block and set_comments_hidden()
%                  (escaping special chars in regexp pattern) report P. Boekholt
%		   added tm documentation
% 2005-09-11 0.3   added delete_hidden_lines() and copy_visible_lines()
% 2006-06-09 0.3.1 INITIALIZATION: moved the menu entries to a popup
% 2007-08-31 0.3.2 bugfix in delete_hidden_lines() (J. Sommer, GM)
% 2007-09-20 0.3.3 copy_visible_lines() now works also for readonly buffers
% 2007-12-20 0.4   generic (un)folding of blocks; use PCRE regexps;
% 	     	   re_fold_buffer()
% 2008-04-21 0.4.1 do not load unfinished code from pcre-fold project
%
% Usage
% -----
%
% put in the jed_library_path and make available by a keybinding or
% via the following menu entry in your .jedrc
% (make-ini >= 2.2 will do this for you)
%
% Beware: hidden lines are still part of a defined region, thus
%         copying a region will copy the hidden lines as well.
%         (And evaluating a region will evaluate the hidden lines.)
%         Use copy_visible_lines() to exclude hidden lines.

#<INITIALIZATION>
define filter_buffer_load_popup_hook(menubar)
{
   variable menu = "Global.&Buffers";
   menu_insert_popup(5, menu, "F&ilter Buffer");
   menu += ".F&ilter Buffer";
   menu_append_item(menu, "&Hide Matching Lines", "set_matching_hidden");
   % menu_append_item(menu, "&Show Matching Lines", "set_matching_hidden(0)");
   menu_append_item(menu, "Show &Only Matching Lines",
      "set_buffer_hidden(1); set_matching_hidden(0)");
   menu_append_item(menu, "Show &All Lines",      "set_buffer_hidden(0)");
   menu_append_item(menu, "&Toggle Line Hiding",  "toggle_hidden_lines");
   menu_append_item(menu, "&Copy Hidden Lines",   "copy_hidden_lines");
   menu_append_item(menu, "&Delete Hidden Lines", "delete_hidden_lines");

}
append_to_hook ("load_popup_hooks", &filter_buffer_load_popup_hook);

"set_buffer_hidden", "filter-buffer.sl";
"set_matching_hidden", "filter-buffer.sl";
"toggle_hidden_lines", "filter-buffer.sl";
"set_comments_hidden", "filter-buffer.sl";
_autoload(4);
#</INITIALIZATION>

% Requirements
% ------------

% standard modes
require("pcre");
autoload("get_comment_info", "comments");

% modes from http://jedmodes.sf.net/
autoload("push_defaults", "sl_utils");

% Functions
% =========

% PCRE regexp matching
% --------------------------------

% Search forward for compiled PCRE regular expression \var{pat}
% (use \sfun{pcre_compile} to compile a pattern)
% Place point at bol of first matching line
% Return whether a match is found
define pcre_fsearch_line(re) {
    push_mark();
    do {
	push_mark_eol();
	if (pcre_exec(re, bufsubstr())) {
	    pop_mark_0();
	    bol();
	    return 1;
	}
    } while (down_1());
    pop_mark_1();
    return 0;
}

% Search forward for PCRE regular expression \var{pat}
% Place point at begin of the match
% Return whether a match is found
% Other than the variant in jedpcre.sl by Paul Boekholt, this function does
% not find matches across line. OTOH, it works correct with the '^' bol
% anchor.
public define pcre_fsearch(pat)
{
   variable re = pcre_compile(pat);
   !if (pcre_fsearch_line(re))
      return 0;
   variable match_pos = pcre_nth_match(re, 0);
   go_right(match_pos[0]);
   return 1;
}

% Search backward for compiled PCRE regular expression \var{pat}
% Place point at bol of first matching line
% Return whether a match is found
public define pcre_bsearch_line(re) {
    push_mark();
    do {
	push_mark();
	bol();
	if (pcre_exec(re, bufsubstr())) {
	    pop_mark_0();
	    return 1;
	}
    } while (up_1());
    pop_mark_1();
    return 0;
}

% Hide and show lines
% --------------------

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
   variable hide = push_defaults(1, (_NARGS));
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
%  Filter all lines matching the PCRE regular expression (pcre)
%  \var{pat}. The argument \var{hide} decides what to do with matching
%  lines:
%    1: hide
%    0: unhide (make visible) matching lines.
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
%  copying a region will copy the hidden lines as well.
%  Use \sfun{copy_visible_lines} instead.
%\seealso{set_line_hidden, toggle_hidden_lines, delete_hidden_lines}
%!%-
public define set_matching_hidden() %(hide=1, [pat])
{
   variable hide, pat;
   (hide, pat) = push_defaults(1, NULL, _NARGS);

   variable prompt = ["Show only", "Hide all"];
   prompt = prompt[hide] + " lines containing (pcre) regexp:";
   if (pat == NULL)
     pat = read_mini(prompt, "", "");

   push_spot_bob();
   % speadup for "matchall"
   if (pat == ".*" or pat == "")
     {
	set_buffer_hidden(hide);
	pop_spot();
	return;
     }
   variable re = pcre_compile(pat);
   while (andelse{not(eobp())}{pcre_fsearch_line(re)})
     {
	set_line_hidden(hide);
	eol();
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

% Handle hidden lines
% -------------------

%!%+
%\function{delete_hidden_lines}
%\synopsis{Delete lines with the hidden attribute}
%\usage{Void delete_hidden_lines()}
%\description
%  Scan the entire buffer for hidden lines and delete these.
%\seealso{set_line_hidden, set_matching_hidden, toggle_hidden_lines}
%!%-
public define delete_hidden_lines()
{
   push_spot_bob();
   do
     while (is_line_hidden() and not(eobp()))
	  delete_line();
   while (down_1);
   pop_spot();
}

%!%+
%\function{copy_visible_lines}
%\synopsis{Copy only visible lines of the region/buffer}
%\usage{ copy_visible_lines()}
%\description
%  Normal (yp) copy does not distinguish hidden lines from visible ones but
%  copies everything in the region.
%  Use copy_visible_lines if you want to permanently separate visible and
%  hidden lines (without deleting the hidden ones).
%\seealso{yp_copy_region_as_kill, set_matching_hidden, toggle_hidden_lines}
%!%-
public define copy_visible_lines()
{
   variable str = "";
   push_spot();
   !if (is_visible_mark())
     mark_buffer();
   narrow();
   bob();
   % collect in string
   do
     if (not(is_line_hidden()))
       str += line_as_string() + "\n";
   while (down_1);
   widen();
   pop_spot();
   % move string to kill-ring
   % (use tmp buffer as the current one might be read-only)
   sw2buf(make_tmp_buffer_name("visible_lines"));
   push_mark();
   insert(str);
   yp_kill_region();
   set_buffer_modified_flag(0);
   delbuf(whatbuf);
}

% TODO: search in visible lines

% Hide Comments
% -------------

%!%+
%\function{set_comments_hidden}
%\synopsis{Set hidden attribute for all comment lines}
%\usage{Void set_comments_hidden(hide=1)}
%\description
%  Hide (or make visible) all comment lines in a buffer by setting the
%  hidden attribute.
%
%  Calls \sfun{set_matching_hidden} with a regular expression derived from
%  the cbeg and cend strings obtained with \sfun{get_comment_info}.
%\notes
%  A comment line is a line that contains only commented out text
%  and optional whitespace.
%
%  \sfun{set_comments_hidden} doesnot work for multiline comments.
%
%  Beware: hidden lines are still part of a defined region, thus
%
%  * copying a region will copy the hidden lines as well,
%  * evaluating a region will evaluate the hidden lines,
%  * search and replace will replace in the hidden lines, ...
%
%  Use \sfun{copy_visible_lines} or \sfun{delete_hidden_lines}.
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

#stop

% Work in progress:

% PCRE-Fold
% -------------

% Fold the buffer according to mode-dependent tokens.

% The token_pcre is an array or a list of regular expressions matching
% with language "tokens" with increasing verbosity.
%
mode_set_mode_info("SLang", "token_pcre",
		   ["^(public define|custom_variable)",
		    "^((public )define|(public |custom_)variable)",
		    "^((public |static )define|"
		    +"(public |static |custom_)variable)",
		   ]);

% fold buffer, leaving only lines matching the token regexp for the current
% mode visible
public define fold_by_token(level)
{
   variable token, tokens = mode_get_mode_info("token_pcre");
   level = min([level, length(tokens)]);
   token = tokens[level-1];
   return level, token;
}

% rst-outline.sl: Outline with `reStructured Text` section markup 
% ===============================================================
% Copyright (c) 2007 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
% 
% Usage
% -----
% 
% Place in the jed library path. 
% 
% * rst.sl will require() this file,  
% * other modes can use it for outlining according to reStructured Text
%   section markup in comments.
% 
% TODO: describe activation and bindings.
% 
% Versions
% --------
% 0.1   2007-11-20 * split from rst.sl
%                  * allow for overline chars
% 0.1.1 2008-01-16 * bugfix in heading()
% 		     (for numerical arg without existing adornments)
% 0.1.2 2008-01-22 * KP keybindings require x-keydefs
% 
% Requirements
% ------------
% 
% standard modes::

require("comments");

% extra modes (from http://jedmodes.sf.net/mode/)::

autoload("string_repeat", "strutils");
require("x-keydefs");

% Navigation buffer (navigable table of contents) with
% http://jedmodes.sf.net/mode/tokenlist ::

#if (expand_jedlib_file("tokenlist.sl") != "")
autoload("list_routines", "tokenlist"); % >= 2006-12-19
#endif

% Initialization
% ==============
% 
% Name and Namespace
% ------------------
% ::
  
provide("rst-outline");
implements("rst");
   
   
% Customizable Defaults
% ---------------------
% ::

%!%+
%\variable{Rst_Underline_Chars}
%\synopsis{Characters used for underlinign of section titles}
%\usage{variable Rst_Underline_Chars = "*=-~\"'`^:+#<>_"}
%\description
%  String of non-alphanumeric characters that serve as underlining chars
%  (adornments) for section titles.
%  Order is important - as default oder for the section level (overwritten
%  by existing use of adornment chars in the current buffer).
%\seealso{rst->heading}
%!%-
custom_variable("Rst_Underline_Chars", "*=-~\"'`^:+#<>_");

% Internal Variables
% ------------------
% ::

private variable Last_Adornment = "=";
private variable blank = " \t";
private variable uchars = str_replace_all(Rst_Underline_Chars, "-", "\\-");
static variable Underline_Regexp = "^\([$uchars]\)\1+[$blank]*$"R$;
% static variable Underline_PcRegexp = "^([$uchars])\1+$blank*$"R$;

% Auxiliary functions
% ~~~~~~~~~~~~~~~~~~~
% ::

% String of sorted adornment codes, e.g. "** * = - ~ _"
% An adornment code is a 2-char string with "<overline ch><underline ch>"
% Used and amended with section_level()
% (re)set from existing section titles with update_adornments()
private variable adornments = "";

% Return the length of the line (excluding whitespace).
% auxiliary fun for is_heading_underline() and heading():
private define get_line_len()
{
   eol(); bskip_white();
   what_column() - 1; % push return value on stack
   bol();
}

% Go down exactly n lines, appending newlines if reaching end of buffer.
% Point is left at bol.
static define go_down_exactly(n)
{
   loop (n - down(n))
     {
        eol();
        newline();
     }
}

% Go to the title line of a heading if on either title line or adornment lines
% 
% Used by heading(), so there could be
% * no adornment or "wrong" adornment when called.
% * blank title line (transition)
% * underline only or under and overline
static define goto_heading_title()
{
   bol();
   !if (re_looking_at(Underline_Regexp))
     return; % assume we are at title line (or blank line)
   
   % Try if there is a title line above
   variable n = up_1(); 
   bol();
   if (re_looking_at(".*[a-zA-Z0-9]"))
     return; % there is some text, assume this is the title
   % Try if there is a title line below the adornment line
   push_mark();
   go_down(n+1);
   % go back to line over start-line if there is no title here
   pop_mark(not(re_looking_at(".*[a-zA-Z0-9]")));
}

% Check whether the point is in a line underlining a section title.
% (underline is equal or longer than previous line and previous line is
% no adornment line and non-blank).
% Leave point at bol of underline.
define is_heading_underline()
{
   !if (up(1)) % already on first line 
      return 0;
   % Get length of heading
   variable heading_len = get_line_len();
   if (not(re_looking_at(".*[a-zA-Z0-9]")))
       heading_len = 0;
   go_down_1();
   !if (heading_len) % blank line, no heading
      return 0;
   % Compare to length of adornment
   return get_line_len() >= heading_len;
}

% Test whether the current heading has a valid overline adornment
% Call with point at underline.
static define has_overline() 
{
   push_spot();
   EXIT_BLOCK { pop_spot(); }
   variable underline = strtrim_end(line_as_string());
   if (underline == "")
      return 0; % no adornment at all
   if (up(2) < 2)
      return 0; % bob reached, no overline
   !if (bol(), looking_at(underline))
      return 0; % line is not identic (fails to detect a longer overline)
   return not(is_heading_underline());
}

% Return symbol for current section heading adornment, e.g.
%   " *" underlined with "*",
%   "**" over- and underlined with "*"
% Point must be at bol of underline and will stay there.
private define what_adornment()
{
   if (has_overline())
     return string_repeat(char(what_char()), 2);
   else
     return " " + char(what_char());
}

% Return level of section heading adorned with `adornment'
% (starting with level 1 == H1)
% Add adornment to list of adornments if not found there.
static define section_level(adornment)
{
   variable i = is_substr(adornments, adornment);
   if (i)
     return (i+1)/2;
   adornments += adornment;
   return strlen(adornments)/2;
}

% Search next section title, return section level or 0.
% Point is placed at the bol of the underline.
% Skip current line. (This way, repeating the command will find next heading.)
% Skip sections titles with a level higher than \var{max_level} if != 0. 
% Skip hidden headings if \var{skip_hidden} is TRUE.
static define fsearch_heading() % (max_level=0, skip_hidden=0)
{
   variable level, max_level, skip_hidden;
   (max_level, skip_hidden) = push_defaults(0, 0, _NARGS);
   !if (max_level) max_level = 1000;
   
   while (eol(), re_fsearch(Underline_Regexp))
     {
        if (skip_hidden and is_line_hidden())
          continue;
        !if (is_heading_underline)
          continue;
        % get adornment and compute section level
        level = section_level(what_adornment());
        if (level <= max_level)
          return level;
     }
   return 0;
}

% search previous section title, return level or 0
static define bsearch_heading() % (max_level=0, skip_hidden=0)
{
   variable level, max_level, skip_hidden;
   (max_level, skip_hidden) = push_defaults(0, 0, _NARGS);
   !if (max_level) max_level = 1000;
   
   while (re_bsearch(Underline_Regexp))
     {
        if (skip_hidden and is_line_hidden())
          continue;
        !if (is_heading_underline)
          continue;
        level = section_level(what_adornment());
        if (level <= max_level)
          return level;
     }
   return 0;
}

% update the sorted listing of section title adornment codes,
% An adornment code is a 2-char string with "<overline ch><underline ch>"
static define update_adornments()
{
   variable l_max, ch;
   adornments = "";      % reset private var
   % List underline characters used for sections in the document
   push_spot_bob();
   while (fsearch_heading())
     !if (down_1())
       break;
   pop_spot();
   % show("adornments", adornments);
}

% extract adornment code for given level from the static var adornments 
% or the next unused one from Rst_Underline_Chars that follows adornment of
% heading level-1
private define get_adornment_code(level) ; % forward declaration
private define get_adornment_code(level)
{
   % Look in already defined heading adornments
   variable adornment = strtrim(substr(adornments, level*2-1, 2));
   if (adornment != "") 
      return adornment;
   % New level: get a new adornment code
   if (level == 1) % no headings in present document
      return Rst_Underline_Chars[[0]];
   % Return "best choice" for next level adornment
   %   get a sorted tuple of all "canonical" adornments, 
   %   starting with the one that follows the adornment of level-1 heading
   variable ads = Rst_Underline_Chars+Rst_Underline_Chars; 
   variable current_ad = get_adornment_code(level-1)[[0]];
   variable ch, start = is_substr(ads, current_ad);
   ads = substr(ads, start, -1);
   % return the first un-used
   foreach ch (ads) {
      adornment = char(ch);
      !if (is_substr(adornments, adornment)) {
	 return adornment;
      }
   }
}



% Navigation
% ~~~~~~~~~~
% ::

% Go to the next section title.
% Skip headings with level above max_level and hidden headings
% Place point at bol of title line.
static define next_heading()  % (max_level=100)
{
   variable max_level = push_defaults(100, _NARGS);
   go_down_1();
   if (fsearch_heading(max_level, 1))
     {
        go_up_1();
        bol();
     }
   else
     eob;
}

% Go to the previous section title.
% Skip headings with level above max_level and hidden headings
% Place point at bol of title line.
static define previous_heading() % (max_level=100)
{
   variable max_level = push_defaults(100, _NARGS);
   if (bsearch_heading(max_level, 1))
     {
        go_up_1();
        bol();
     }
   else
     bob;
}

%!%+
%\function{rst->skip_section}
%\synopsis{Go to the next heading of same level or above}
%\usage{skip_section()}
%\description
% Skip content, hidden headings and sub-headings.
%\notes
% Point is placed at bol of heading line or eob
%\seealso{rst_mode; rst->heading}
%!%-
static define skip_section()
{
   update_adornments();
   go_down(2);
   variable level = bsearch_heading();
   if (level == 0)
      next_heading();
   else
      next_heading(level);
}

% Go to the previous section title of same level or above,
% skip content and sub-sections.
static define bskip_section()
{
   update_adornments();
   go_down(2);
   previous_heading(bsearch_heading());
}

% Go to section title of containing section (one level up)
static define up_section()
{
   update_adornments();
   go_down(2);
   previous_heading(bsearch_heading()-1);
}

static define mark_section()
{
   update_adornments();
   go_down(2);
   variable level = bsearch_heading();
   if (level == 0)
      error("there is no section to mark");
   push_visible_mark();
   next_heading(level);
}

% Editing
% ~~~~~~~
% ::

%!%+
%\function{rst->heading}
%\synopsis{Mark up current line as section title}
%\usage{heading([level])}
%\description
% Mark up current line as section title by adorning it with underline (and
% possibly overline) according to \var{level}. Replace existing adornments.
%
% If \var{level} is an Integer (or a String convertible to an Integer), use
% the adornment for this section level. Valid levels range from 1 to `level
% of the previous heading` + 1 (this is a restriction of reStructured Text
% syntax).
% 
% Otherwise, \var{level} must be a String containing the adornment code, e.g.
%   "*", " *", or "* ": underline with "*",
%   "**"              : over- and underline with "*"
%
%\notes
% If the argument is not supplied, it is read from the minbuffer:
%   * "canonical" adornments are listed starting with already used ones
%      sorted by level.
% 
%     "Canonical" adornment characters are defined in Rst_Underline_Chars.
%     Only these are highlited and only these work with the section visibility
%     and movement functions.
%      
%\seealso{rst_mode, Rst_Underline_Chars}
%!%-
static define heading() % ([level])
{
   % Get and convert optional argument
   % ---------------------------------
   variable level = push_defaults( , _NARGS);
   variable ch, adornment, l_max=0;
   % Update defaults
   if (typeof(level) == Integer_Type or level == NULL) {
      % update the listing of adornment characters used in the document
      update_adornments();
      % get level of previous heading, as rst-headings cannot skip levels
      push_spot();
      l_max = bsearch_heading() + 1;
      pop_spot();
   }
   % Read from minibuffer
   if (level == NULL)
     {
        level = read_mini(sprintf("Specify adornment [%s] or level [1-%d]:",
           Rst_Underline_Chars, l_max), Last_Adornment, "");
     }
   % Convert numeral to Integer
   if (andelse{typeof(level) == String_Type}
        {string_match(level,"^[0-9]+$" , 1)})
     level = integer(level);
   % Convert level to adornment code:
   if (typeof(level) == Integer_Type) { 
      % check if level is allowed
      if (level < 1)
	 verror("Top level is 1. Level %d must be >= 1", level);
      if (level > l_max)
	 verror("Level %d outside of allowed levels for this heading [1,%d]", 
		level, l_max);
      % Get adornment code for given level 
      adornment = get_adornment_code(level);
   }
   else
      adornment = strtrim(level);
   % Store as default
   Last_Adornment = adornment;
   
   % Replace adornments
   % ------------------
   
   % Go to bol of the (maybe blank) underline. Append line if necessary.
   % Point can be at any of: overline, heading line, underline
   goto_heading_title();
   go_down_exactly(1);
   % Delete matching overline
   if (has_overline())
     {
        go_up(2);
        delete_line();
        go_down_1();
     }
   % Delete underline
   if (re_looking_at(Underline_Regexp))
     delete_line();
   % Get the title length
   go_up_1();
   variable len = get_line_len(); % point is left at bol
   !if (len) % transition
     len = WRAP;
   % New overline
   if (strlen(adornment) == 2)
     insert(string_repeat(substr(adornment, 1, 1), len) + "\n");
   % New underline
   go_down_1();
   insert(string_repeat(substr(adornment, 1, 1), len) + "\n");
}

% increase (or decrease) section level by `n'
static define promote_heading(n)
{
   % get current level, add n
   update_adornments();
   go_down(2);
   variable level = bsearch_heading() + n;
   if (level < 1)
      error("Cannot promote above top-level");
   heading(level);
}

% Rewrite heading adornments to follow the level-ordering given in a sample
% string (default Rst_Underline_Chars)
static define normalize_headings()
{
   update_adornments();
   variable chars = read_mini("New adornment list", "", Rst_Underline_Chars[[:strlen(adornments)/2]]);
   push_spot_bob();
   variable level = fsearch_heading();
   while (level)
     {
        heading(substr(chars, level, 1));
        level = fsearch_heading;
     }
   pop_spot();
}

% Navigator (outline buffer)
% ==========================
%   
% Use Marko Mahnics tokenlist.sl to create a navigation buffer with all section
% titles. 
% 
% TODO: navigator mode with bindings for re-ordering of sections
% ::

#ifexists list_routines
% message("tokenlist present");

% rst mode's hook for tkl_list_tokens():
% 
% tkl_list_tokens searches for a set of regular expressions defined
% by an array of strings arr_regexp. For every match tkl_list_tokens
% calls the function defined in the string fn_extract with an integer
% parameter that is the index of the matched regexp. At the time of the
% call, the point is at the beginning of the match.
% 
% The called function should return a string that it extracts from
% the current line.
% 
% ::

% extract section title and format for tokenlist
static define extract_heading(regexp_index)
{
   variable adornment, title, level, indent;
   % point is, where fsearch_heading() leaves it
   % (at first matching adornment character)
   % Get adornment code
   adornment = what_adornment();
   % Get section title
   go_up_1();
   title = strtrim(line_as_string());
   go_down_1();
   % show(what_line, adornment, title);
   % Format
   % do not indent at all (simple, missing information)
   % return(sprintf("%s %s", adornment, title));
   level = section_level(adornment);
   % indent = string_repeat(" ", (level-1)*2);
   indent = string_repeat(" ", (level-1));
   % indent by 2 spaces/level, adornment as marker (best)
   return sprintf("%s%s %s", indent, adornment, title);
}

% Set up list_routines for rst mode
public  define rst_list_routines_setup(opt)
{
   adornments = "";    % reset, will be updated by fsearch_heading
   opt.list_regexp = &fsearch_heading;
   opt.fn_extract = &extract_heading;
}

#endif

% Folding
% =======
% ::

% hide section content and headings with a level above max_level
%
% * use with narrow() to fold a sub-tree
% * use with max_level=0 to unfold (show all lines)
% * a prefix argument will override \var{max_level}
static define fold_buffer(max_level)
{
   max_level = prefix_argument(max_level);
   push_spot();
   % Undo previous hiding
   mark_buffer();
   set_region_hidden(0);
   update_adornments();
   % Start: place point below first heading
   % (we cannot use next_heading() as this skips heading in line)
   bob();
   if (fsearch_heading(max_level))
     go_down_1();
   else
     eob;
   % Set section content hidden, 
   % Leave headings and underlines with a level below max-level visible
   while (not(eobp()))
     {
        push_mark();
        next_heading(max_level);
        !if (eobp())
          go_up_1();                % leave the next heading line visible
        set_region_hidden(1);
        go_down(3);                 % skip heading line and underline
     }
   pop_spot();
}

% Fold current section
% (Un)Hide section content. Toggle, if \var{max_level} is negative.
% Point must be in section heading or underline.
% (Un)hide also sub-headings below max_level.
% max_level is relative to section level:
%    0: unfold (show content)
%    1: hide all sub-headings
%    n: show n-1 levels of sub-headings
static define fold_section(max_level)
{
   push_spot();
   % goto top of section
   go_down(2);
   previous_heading();
   if (max_level < 0)
     {
        $1 = down(2);
        max_level *= -not(is_line_hidden());
        go_up($1);
     }
   % Narrow to section and fold
   push_mark();
   skip_section();
   go_up_1();
   narrow();
   fold_buffer(max_level);
   widen();
   pop_spot();
}

% Keybindings
% ===========
%   
% Emacs outline mode bindings
% ---------------------------
% ::

% emulate emacs outline bindings
static define emacs_outline_bindings() % (pre = _Reserved_Key_Prefix)
{
   variable pre = push_defaults(_Reserved_Key_Prefix, _NARGS);
   local_unsetkey(pre);

% Outline Motion Commands
% ~~~~~~~~~~~~~~~~~~~~~~~
% :^C^n: (outline-next-visible-heading) moves down to the next heading line.
% :^C^p: (outline-previous-visible-heading) moves similarly backward.
% :^C^u: (outline-up-heading) Move point up to a lower-level (more
%        inclusive) visible heading line.
% :^C^f: (outline-forward-same-level) and
% :^C^b: (outline-backward-same-level) move from one heading line to another
%        visible heading at the same depth in the outline.
%    
% ::

   local_setkey("rst->next_heading", pre+"^N");
   local_setkey("rst->previous_heading", pre+"^P");
   local_setkey("rst->up_section", pre+"^U");
   local_setkey("rst->skip_section", pre+"^F");
   local_setkey("rst->bskip_section", pre+"^B");
 
% Outline Visibility Commands
% ~~~~~~~~~~~~~~~~~~~~~~~~~~~
% Global commands
% """""""""""""""
% folding the whole buffer.
% With a numeric argument n, they hide everything except the
% top n levels of heading lines.
% 
% :^C^t: (hide-body) you see just the outline. (fold.txt: ^C^W)
% :^C^a: (show-all) makes all lines visible.   (fold.txt: ^C^O)
% :^C^q: (hide-sublevels) hides all but the top level headings.
% 
% ::

   local_setkey("rst->fold_buffer(100)", pre+"^T");
   local_setkey("rst->fold_buffer(0)", pre+"^A");
   local_setkey("rst->fold_buffer(1)", pre+"^Q");
   
% TODO
% 
% :^C^o: (hide-other) hides everything except the heading or body text that
%        point is in, plus its parents (the headers leading up from there to top
%        level in the outline).
% 
% Subtree commands
% """"""""""""""""
% that apply to all the lines of that heading's subtree
% its body, all its subheadings, both direct and indirect, and all of their
% bodies. In other words, the subtree contains everything following this
% heading line, up to and not including the next heading of the same or
% higher rank.
% ::

   % :^C^d: (hide-subtree) Make everything under this heading invisible.
   local_setkey("rst->fold_section(1)", pre+"^D");
   % :^C^s: (show-subtree). Make everything under this heading visible.
   local_setkey("rst->fold_section(0)", pre+"^C");

   % Intermediate between a visible subtree and an invisible one is having all
   % the subheadings visible but none of the body.
   % :^C^l: (hide-leaves) Hide the body of this section, including subheadings.
   local_setkey("rst->fold_section(1)", pre+"^L");
   % TODO: what is the difference to (hide-subtree)?
   % :^C^k: (show-branches) Make all subheadings of this heading line visible.
   local_setkey("rst->fold_section(100)", pre+"^K");
   % :^C^i: (show-children) Show immediate subheadings of this heading.
   local_setkey("rst->fold_section(2)", pre+"^I");

% Local commands
% """"""""""""""
% 
% Used with point on a heading line, and apply only to the body lines of that
% heading. Subheadings and their bodies are not affected.
% 
% :^C^c: (hide-entry) hide body under this heading and
% :^C^e: (show-entry) show body of this heading.
% :^C^q: Hide everything except the top n levels of heading lines (hide-sublevels).
% :^C^o: Hide everything except for the heading or body that point is in, plus the headings leading up from there to the top level of the outline (hide-other).
% 
% When incremental search finds text that is hidden by Outline mode, it makes
% that part of the buffer visible. If you exit the search at that position,
% the text remains visible.
% 
% Structure editing.
% ~~~~~~~~~~~~~~~~~~
% 
% Using M-up, M-down, M-left, and M-right, you can easily move entries
% around:
% 
% |                            move up
% |                               ^
% |      (level up)   promote  <- + ->  demote (level down)
% |                               v
% |                           move down
%       
% ::

}
 
% Emacs fold mode bindings
% ------------------------
% from fold.txt (consistent with the Emacs bindings)
% 
% :^C^W: fold_whole_buffer
% :^C^O: fold_open_buffer            % unfold-buffer
% :^C>:  fold_enter_fold
% :^C<:  fold_exit_fold
% :^C^F: fold_fold_region            % add fold marks and narrow
% :^C^S: fold_open_fold
% :^C^X: fold_close_fold
% :^Cf:  fold_search_forward
% :^Cb:  fold_search_backward
% 
% Numerical Keypad bindings
% -------------------------
% ::

static define rst_outline_bindings()
{
   local_setkey("rst->bskip_section",         Key_KP_9);  % Bild ^
   local_setkey("rst->previous_heading",      Key_KP_8);  % ^
   local_setkey("rst->promote_heading(-1)",   Key_KP_4);  % < promote
   local_setkey("rst->mark_section",          Key_KP_5);  % .
   local_setkey("rst->promote_heading(1)",    Key_KP_6);  % > demote
   local_setkey("rst->next_heading",          Key_KP_2);  % v
   local_setkey("rst->skip_section",          Key_KP_3);  % Bild v
   % local_setkey("rst->promote_heading(1)",  Key_KP_Add);      % + demote
   % local_setkey("rst->promote_heading(-1)", Key_KP_Subtract); % - promote
   local_setkey("rst->fold_section(-1)",      Key_KP_Enter); % no subheadings
   % local_setkey("rst->fold_section(-2)",    Key_KP_Enter);   % prime subheadings
   % local_setkey("rst->fold_section(-10)",   Key_KP_Enter);  % all subheadings
}

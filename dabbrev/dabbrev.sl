% Complete the current word looking for similar word-beginnings
%
% Versions
%   1 May 1994       Adrian Savage (afs@jumper.mcc.ac.uk)
%              	     Extensively modified by JED
%   2.0 2003-05-01   rewrite by G.Milde <g.milde web.de>
%        	     added support for scanning in a list of buffers
%   2.1 	     added customizability
%   2.2      	     look at last finding first
%   		     (as emacs does, tip P. Boekholt)
%   2.2.1    	     bugfix: invalid mark when buffer of last
%                    expansion killed (P. Boekholt)
%   2.3   2003-12-01 prevent flooding the undo-buffer (using getkey for
%                	   subsequent invocations)
%   2.3.1 2003-12-05 replaced unget_keystring with buffer_keystring
%   2.4   2004-03-15 dabbrev() takes a prefix argument for the
%                    buflist-scope (this is checked in dab_reset())
%                    clearer documentation (open_buffers -> all buffers)
%                    (hints by J. E. Davis)
%   2.4.1 2004-03-30 new custom var Dabbrev_Case_Search
%   	  	     added documentation for custom vars and get_buflist
%   2.4.2 2004-04-05 bugfix (code cleanup) in check_mark.
%   	  	     dabbrev accepts integer argument and uses get_buflist
%   	  	     to convert to a buffer list. (actual change in dab_reset)
%   	  	     get_buflist becomes static
%
% USAGE:
% Put in path und bind to a key, e.g.
% setkey("dabbrev", "^A");          % expand from Dabbrev_Default_Buflist
% setkey("dabbrev(get_buflist(1))", "\ea"); % expand from visible buffers
%
% You can use any function that returns a list of buffers as argument,
% make sure it is declared, e.g. with autoload("get_buflist", "dabbrev");
%
% You could even define your own metafunction that does something usefull
% (e.g. open a buffer) and then calls dabbrev("buf1\nbuf2\n ...") to expand
% from listed buffers.
%
% CUSTOMIZATION
%
% Some custom variables can be used to tune the behaviour of dabbrev:
% (The defaults are set to make dabbrev work as version 1)
%
% "Dabbrev_delete_tail", 0      % replace the existing completion
% "Dabbrev_Default_Buflist", 0  % default to whatbuf()
% "Dabbrev_Look_in_Folds", 1    % open folds when scanning for completions

% ---------------------------------------------------------------------------

% debug info, uncomment to trace down bugs
% _traceback = 1;
% _debug_info = 1;

% --- Variables

%
%!%+
%\variable{Dabbrev_delete_tail}
%\synopsis{Let completion replace word tail?}
%\usage{Int_Type Dabbrev_delete_tail = 0}
%\description
%  Should the completion replace the part of the word behind the cursor?
%\seealso{dabbrev}
%!%-
custom_variable("Dabbrev_delete_tail", 0);

%!%+
%\variable{Dabbrev_Default_Buflist}
%\synopsis{Which buffers should dabbrev expand from?}
%\usage{Int_Type Dabbrev_Default_Buflist = 0}
%\description
% The buffer-list when dabbrev is called without argument
%     0 = current buffer,
%     1 = visible buffers (including the current),
%     2 = all buffers of same mode,
%     3 = all buffers,
%     4 = other visible buffers (excluding the current),
%     5 = all other buffers of same mode  (excluding the current),
%     6 = all other buffers  (excluding the current)
%\seealso{dabbrev, get_buflist}
%!%-
custom_variable("Dabbrev_Default_Buflist", 0);

%!%+
%\variable{Dabbrev_Look_in_Folds}
%\synopsis{Scan folds for expansions}
%\usage{Int_Type Dabbrev_Look_in_Folds = 1}
%\description
% Should dabbrev scan folded parts of the source buffer(s)
% for expansions too?
%\seealso{dabbrev}
%!%-
custom_variable("Dabbrev_Look_in_Folds", 1);

%!%+
%\variable{Dabbrev_Case_Search}
%\synopsis{Let dabbrev stick to case}
%\usage{Int_Type Dabbrev_Case_Search = 1}
%\description
%  Should dabbrev consider the case of words when looking for expansions?
%\seealso{dabbrev}
%!%-
custom_variable("Dabbrev_Case_Search", 1);

static variable
  BufList = NULL, BufList_Index, % list of source buffers
  Word_Chars,  % characters that make up a word (for dabbrev)
  Core_Pattern, % the actual word to complete
  Pattern = "", % preceding word + non-word-chars + Core_Pattern
  Completion_List = "", % list of already suggested completions
  Scan_Mark = create_user_mark(), % position of last hit,
  Scan_Direction = 0; % 0 backward, 1 forward

% --- Functions

%!%+
%\function{get_buflist}
%\synopsis{Return a newline-delimited list of buffers.}
%\usage{String get_buflist(Integer scope)}
%\description
%  Return a list of buffers suited as (optional) argument for the
%  \var{dabbrev} function.
%  The argument \var{scope} means:
%     0 = current buffer,
%     1 = visible buffers (including the current),
%     2 = all buffers of same mode,
%     3 = all buffers,
%     4 = other visible buffers (excluding the current),
%     5 = all other buffers of same mode  (excluding the current),
%     6 = all other buffers  (excluding the current)
%\example
%  You can use get_buflist to have keybindings to different
%  "flavours" of dabbrev
%#v+
% setkey("dabbrev", "^A");          % expand from Dabbrev_Default_Buflist
% setkey("dabbrev(get_buflist(1))", "\ea"); % expand from visible buffers
%#v-
%\seealso{dabbrev, Dabbrev_Default_Buflist}
%!%-
static define get_buflist(scope)
{
   !if(scope)
     return whatbuf;
   variable buf, buflist = "", curbuf = whatbuf(), mode = get_mode_name();
   variable exclude_whatbuf = scope > 3;
   if (exclude_whatbuf)
     scope -= 3;
   loop (buffer_list() - exclude_whatbuf)
     {
	buf = ();
	% skip hidden buffers
	!if (strncmp(buf, " <", 2)) % strncmp returns 0 if equal!
	  continue;
	% filter
	switch (scope)
	  {case 1: !if (buffer_visible(buf)) continue;}
	  {case 2: sw2buf(buf); !if (get_mode_name() == mode) continue;}
	buflist = strcat(buf, "\n", buflist);
     }
   _pop_n(exclude_whatbuf);
   sw2buf(curbuf);
   return strtrim_end(buflist);
}

% replace an invalid mark with a mark at current point
static define check_mark(markp)
{
   ERROR_BLOCK
     {
	@markp = create_user_mark();
	_clear_error;
	return;
     }
   () = (@markp).buffer_name; % dummy call to test mark validity
}

% get the word tail
static define dab_get_word_tail(kill)
{
   push_mark;
   skip_chars(Word_Chars);
   exchange_point_and_mark();
   if (kill)
     return bufsubstr_delete();
   else
     return bufsubstr();
}

% Switch to buf, mark position, widen if narrowed
% TODO: How about hidden lines?
static define dab_sw2buf(buf)
{
   % show("switching to ", buf);
   !if (bufferp(buf))
     return;
   sw2buf(buf);
   push_spot();
   if (count_narrows() and Dabbrev_Look_in_Folds)
     {
	push_narrow ();
	widen_buffer ();
     }
}

% Save position for next completion-search, return to position and
% restore previous narrow-state, return to buf
static define dab_return2buf(buf)
{
   Scan_Mark = create_user_mark(); % update
   pop_spot();
   pop_narrow(); % does nothing if not narrowed before
   sw2buf(buf);
}

% reset the static variables
static define dab_reset() % (buflist = whatbuf())
{
   % List of buffers to scan for completions
   if (_NARGS)
     {
	BufList = ();
	if (typeof(BufList) != String_Type)
	  BufList = get_buflist(BufList);
     }
   else
     {
	variable buflist_scope = prefix_argument(-1);
	if (buflist_scope == -1)
	  buflist_scope = Dabbrev_Default_Buflist;
	% buflist_scope = get_blocal("Dabbrev_Default_Buflist",
	% 		  	      Dabbrev_Default_Buflist;
	BufList = get_buflist(buflist_scope);
     }
   BufList = strchop(BufList, '\n', 0);
   BufList_Index = -2;
   % get word_chars from: 1. mode_info, 2. blocal_var, 3. get_word_chars
   Word_Chars = mode_get_mode_info("dabbrev_word_chars");
   if (Word_Chars == NULL)
     {
	if (blocal_var_exists("Word_Chars"))
	  Word_Chars = get_blocal_var("Word_Chars");
	else
	  Word_Chars = "_" + get_word_chars();
     }
   % Get patterns to expand from (keep cursor position)
   push_mark();
   push_mark();
   bskip_chars(Word_Chars);
   Core_Pattern = bufsubstr();         % current word
   bskip_chars("^" + Word_Chars);
   bskip_chars(Word_Chars);
   exchange_point_and_mark();
   Pattern = bufsubstr();         % current + previous word
   !if (strlen(Pattern))
     error("nothing to expand");
   % Exclude current completion and empty string
   Completion_List = dab_get_word_tail(Dabbrev_delete_tail) + "\n";
   % create a new scan-mark if it is invalid or nonexistent.
   check_mark(&Scan_Mark);
}

% search in Scan_Direction for Pattern, return success
static define dab_search()
{
   variable found;
   variable old_case_search = CASE_SEARCH;
   CASE_SEARCH = Dabbrev_Case_Search;
   ERROR_BLOCK {CASE_SEARCH = old_case_search;}
   do
     {
	if (Scan_Direction)
	  {
	     go_right_1();
	     found = fsearch(Pattern);
	  }
	else
	  found = bsearch(Pattern);
	!if (found)
	  return 0;
	% test whether at begin of a word
	push_spot();
	bskip_chars(Word_Chars);
	POINT;  % push current column-position on stack
	pop_spot();
     }
   while (POINT != ());
   CASE_SEARCH = old_case_search;
   return found;
}

static define dab_expand()
{
   variable heureka = 0, completion,
     return_mark = create_user_mark();
   % if reset, find completion at place of last hit
   dab_sw2buf(Scan_Mark.buffer_name);
   goto_user_mark(Scan_Mark);
   if (BufList_Index == -2) % first call after reset
     {
	heureka = looking_at(Pattern) * strlen(Pattern);
	BufList_Index++;
     }
   % Find completion in BufList[BufList_Index]
   forever
     {
	if (BufList_Index >= 0)
	  heureka = dab_search();
	else
	  heureka = 0;
	% Pattern found, get completion
	if (heureka)
	  {
	     push_spot();
	     go_right(heureka); % heureka contains strlen of Pattern
	     completion = dab_get_word_tail(0);
	     pop_spot();
	     % is it new?
	     !if(is_list_element(Completion_List, completion, '\n'))
	       {
		  Completion_List += "\n" + completion;
		  break;
	       }
	     else
	       continue;
	  }
	% look forwards
	else if(BufList_Index >= 0 and not(Scan_Direction))
	  {
	     % show("switch to forward scan in buffer Nr", BufList_Index);
	     Scan_Direction = 1;
	     goto_spot(); % goto initial position in Scan-Buffer
	  }
	% try next buffer from list
	else if (BufList_Index < length(BufList)-1)
	  {
	     pop_spot();
	     pop_narrow();
	     BufList_Index++;
	     % show("switching to", BufList[BufList_Index]);
	     dab_sw2buf(BufList[BufList_Index]);
	     Scan_Direction = 0;
	  }
	% all given buffers scanned
	else
	  {
	     % try again with only core pattern
	     if (strlen(Pattern) > strlen(Core_Pattern)
		 and strlen(Core_Pattern))
	       {
		  % show(Pattern, " not found, look for ", Core_Pattern);
		  Pattern = Core_Pattern;
		  BufList_Index = -1;
		  Scan_Direction = 1;
	       }
	     % give up
	     else
	       {
		  vmessage("No more completions for \"%s\" in [%s]",
		     Pattern, strjoin(BufList, ", "));
		  % insert original completion, if deleted
		  if (Dabbrev_delete_tail)
		    {
		       dab_return2buf(return_mark.buffer_name);
		       goto_user_mark(return_mark);
		       insert(extract_element(Completion_List, 0, '\n'));
		    }
		  Completion_List = "";
		  break;
	       }
	  }
     }
   % save position for next completion-search,
   % restore scan-buffer to previous state and return to calling buffer
   dab_return2buf(return_mark.buffer_name);
   goto_user_mark(return_mark);
   % Insert completion
   % show("inserting last of ", Completion_List);
   insert(strchop(Completion_List, '\n', 0)[-1]);
}

% ----- main function --------------------------------------------------

%!%+
%\function{dabbrev}
%\synopsis{Complete the current word looking for similar words}
%\usage{dabbrev(String buflist=get_buflist(Dabbrev_Default_Buflist))}
%\description
%   Takes the current stem (part of word before the cursor)
%   and scans the buffers given in the newline-delimited String buflist
%   for words that begin with this stem. The current word is expanded by
%   the non-stem part of the finding. Subsequent calls to dabbrev replace
%   the last completion with the next guess.
%
%   The scan proceeds
%     foreach buffer in buflist
%       from cursor backwards to bob
%       from cursor forwards to eob
%\example
%   The current buffer contains the line
%#v+
%   foo is better than foobar, foobase or foo
%#v-
%   with the cursor at eol.
%   dabbrev completes foo with foobase.
%   If called again (immediately) foobase is changed to foobar
%   If called once again, foobase is changed to foo and a message is
%   given: No more completions.
%
%\notes
% You can use any function that returns a list of buffers as argument,
% make sure it is declared, e.g. with autoload("get_buflist", "dabbrev");
%
%\seealso{get_buflist, Dabbrev_Default_Buflist, Dabbrev_delete_tail, Dabbrev_Look_in_Folds}
%!%-
public define dabbrev()  %(buflist=whatbuf())
{
   variable type, fun, key, args = __pop_args(_NARGS);
   Completion_List = "";

   do
     {
	% Reset static variables
	if (strchop(Completion_List, '\n', 0)[-1] == "")
	  dab_reset(__push_args(args));
	else % delete old completion
	  {
	     push_mark();
	     go_left(strlen(strchop(Completion_List, '\n', 0)[-1]));
	     del_region();
	  }

	% find (next) completion
	dab_expand();
	update_sans_update_hook(1);   %  force update (show insertion)

	% Check next keypress:
	(type, fun) = get_key_binding();
	% show(fun, _function_name, LASTKEY);
     }
   while (andelse {type >= 0}                    % key bound ...
	{is_substr(fun, _function_name) == 1});  % ... to "dabbrev.*"

   % Last keypress was no call to dabbrev -> Push back the keystring
   buffer_keystring(LASTKEY);
}

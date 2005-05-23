% JED interface to the grep command
%
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions
% 0.9.1  2003/01/15
%   * A total remake of Dino Sangois jedgrep under use of the new listing
%     and filelist modes. (Which are inspired by the old jedgrep by Dino!)
%   * grep_replace_command: Replace in the grep results
%     (both, result display and source files!)
% 0.9.2 2003/07/09
%   * bugfix contract_filename did not work properly (needs chdir() first)
% 0.9.3 2004-01-30
%   * solved bug with only one file (using -H option) [Peter Bengtson]
%   * recursive grep with special filename bang (!) (analog to kpathsea)
%     -> grep("pat" "dir/!") gets translated to `grep -r "pat" "dir/"`
% 0.9.4 2004-04-28
%   * close grep buffer, if the return value of the grep cmd is not 0
%
% USAGE
%
% From jed:              M-x grep
% From the command line: fgrep -nH "sometext" * | jed -f grep_mode
% (You should have grep_mode in your autoload list for this to work.)
% The second approach doesnot work for xjed, use
%   xjed -f "grep(\"sometext\", \"*\")"
%
% Go to a line looking promising and press ENTER or double click on
% the line.
%
% CUSTOMIZATION
%
% You can set the grep command with e.g in your .jedrc
%   variable GrepCommand = "rgrep -nH";
%
% Optionally customize the jedgrep_mode using the "grep_mode_hook", e.g.
%   % give the result-buffer a number
%   autoload("number_buffer", "numbuf"); % look for numbuf at jedmodes.sf.net
%   define grep_mode_hook(mode)
%   {
%      number_buffer();
%   }
%
% TODO: use search_file and list_dir if grep is not available
%       take current word as default (optional)
%       make it Windows-secure (filename might contain ":")

% debug info, comment out once ready
% _debug_info=1;

% --- Requirements --------------------------------------------- %{{{
% standard modes
require("keydefs");
autoload("replace_with_query", "srchmisc");
% nonstandard modes (from jedmodes.sf.net)
require("filelist"); % which does require "listing" and "datutils"
autoload("popup_buffer", "bufutils");
autoload("close_buffer", "bufutils");
autoload("buffer_dirname", "bufutils");
autoload("rebind", "bufutils");
autoload("contract_filename", "sl_utils");
autoload("_implements", "sl_utils");
autoload("get_word", "txtutils");
%}}}

% --- name it
provide("grep");
_implements("grep");
private variable mode = "grep";


% --- Variables -------------------------------------------------%{{{

% the grep command
custom_variable("GrepCommand", "grep -nH"); % print filename and linenumbers

% remember the string to grep (as default for the next run) (cf. LAST_SEARCH)
static variable LAST_GREP = "";

% Buffer opened by grep_replace
private variable Replace_Buffer = "";

%}}}

% --- Replace across files ------------------------------------- %{{{

% Compute the length of the statistical data in the current line
% (... as we have to skip spurious search results in this area)
static define grep_prefix_length()
{
   push_spot_bol();
   loop(2)
     {
	() = ffind_char(get_blocal("delimiter", ':'));
	go_right_1();
     }
   what_column()-1;  % leave on stack as return value
   pop_spot();
}

% fsearch in the grep results, skipping grep's statistical data
static define grep_fsearch(pat)
{
   variable pat_len;
   do
     {
	pat_len = fsearch(pat);
	!if(pat_len)
	  return -1;
	if (what_column > grep_prefix_length())
	  return pat_len;
     }
   while(right(1));
}

% save and close a buffer, make sure to come back to current buffer
static define save_and_close_buf(buf)
{
   variable cbuf = whatbuf();
   if (bufferp(buf))
     {
	sw2buf(buf);
	save_buffer();
	delbuf(buf);
     }
   if(cbuf != buf)
     sw2buf(cbuf);
}

% The actual replace function (replace in both, the grep output and the file)
define grep_replace(new, pat_len)
{
   variable old, nbuf_before, nbuf_after,
     buf = whatbuf(),
     col = what_column() - grep_prefix_length();

   % get the pattern to be replaced
   push_mark();
   () = right(pat_len);
   old = bufsubstr_delete();

   ERROR_BLOCK
     {
	sw2buf(buf);
	insert(old);
     }

   % get the number of opened buffers
   nbuf_before = buffer_list(); _pop_n(nbuf_before); % pop the buffer names

   % open the file pointed to and goto the right line and col
   filelist_open_file();
   () = goto_column_best_try(col);

   nbuf_after = buffer_list(); _pop_n(nbuf_after); % pop the buffer names

   if (nbuf_after > nbuf_before)
     {
	save_and_close_buf(Replace_Buffer);
	Replace_Buffer = whatbuf();
     }

   % replace (if everything is ok)
   !if (looking_at(old))
     verror("File differs from grep output (looking at %s)", get_word);
   replace_chars(pat_len, new); % leave strlen(new) on stack
   sw2buf(buf);
   insert(new);
   return; % (strlen(new));
}

% Replace across files found by grep (interactive function)
define grep_replace_cmd()
{
   variable old, new, prompt;

   % find default value: region or word under cursor
   if (is_visible_mark)
     check_region(0);
   else
     mark_word ();
   exchange_point_and_mark; % set point to begin of region

   old = read_mini("Grep-Replace:", "", bufsubstr());
   !if (strlen (old)) return;
   prompt = strcat("Grep-Replace '", old, "' with:");
   new = read_mini(prompt, "", "");

   ERROR_BLOCK
     {
	REPLACE_PRESERVE_CASE_INTERNAL = 0;
	set_readonly(1);
	set_buffer_modified_flag(0);
	save_and_close_buf(Replace_Buffer);
	Replace_Buffer = "";
     }

   set_readonly(0);
   REPLACE_PRESERVE_CASE_INTERNAL = REPLACE_PRESERVE_CASE;
   replace_with_query (&grep_fsearch, old, new, 1, &grep_replace);

   EXECUTE_ERROR_BLOCK;
   message ("done.");
}
%}}}

% --- The grep-mode ----------------------------------------------- %{{{

create_syntax_table(mode);

#ifdef HAS_DFA_SYNTAX
%%% DFA_CACHE_BEGIN %%%
static define setup_dfa_callback(mode)
{
   dfa_enable_highlight_cache("grep.dfa", mode);
   dfa_define_highlight_rule("^[^:]*", "keyword", mode);
   dfa_define_highlight_rule(":[0-9]+:", "number", mode);
   % Uhm, this matches numbers enclosed by ':' anywhere. If this really
   % annoys you, either:
   % 1 - disable dfa highlighting
   % 2 - comment the two dfa_define_highlight_rule above and use instead:
   %       dfa_define_highlight_rule("^[^:]*:[0-9]+:", "keyword", mode);

   dfa_build_highlight_table(mode);
}
dfa_set_init_callback (&setup_dfa_callback, mode);
%%% DFA_CACHE_END %%%
enable_dfa_syntax_for_mode(mode);
#endif

!if(keymap_p(mode))
{
   copy_keymap(mode, "filelist");
   rebind("replace_cmd", "grep->grep_replace_cmd", mode);
}
%}}}

% Interface: %{{{


%!%+
%\function{grep_mode}
%\synopsis{Mode for results of the grep command}
%\usage{ grep_mode()}
%\description
%   A mode for the file listing as returned by the "grep -Hn" command.
%   Provides highlighting and convenience functions.
%   Open the file(s) and go to the hit(s) pressing Enter. Do a 
%   find-and-replace accross the files.
%\seealso{grep, grep_replace}
%!%-
public define grep_mode()
{
   define_blocal_var("delimiter", ':');
   define_blocal_var("line_no_position", 1);
   filelist_mode();
   set_mode(mode, 0);
   use_syntax_table (mode);
   use_keymap(mode);
   run_mode_hooks("grep_mode_hook");
}


% TODO: What does gnu grep expect on DOS, What should this be on VMS and OS2 ?
%!%+
%\function{grep}
%\synopsis{Grep wizard}
%\usage{grep(String what=NULL, String files=NULL)}
%\description
%  Grep for "what" in the file(s) "files" (use shell wildcards).
%  If the optional arguments are missing, they will be asked for in the 
%  minibuffer. The grep command can be set with the custom variable 
%  \var{GrepCommand}.
%  
%  The buffer is set to grep_mode, so you can go to the matching lines 
%  or find-and-replace accross the matches.
%  
%  grep adds one extension to the shell pattern replacement mechanism
%  the special filename bang (!) indicates a recursive grep in subdirs
%  (analog to kpathsea), i.e. grep("pat" "dir/!") translates to 
%  `grep -r "pat" "dir/"`
%\notes
%  In order to go to the file and line-number, grep_mode assumes the 
%  -n and -H argument set.
%\seealso{grep_mode, grep_replace, GrepCommand}
%!%-
public define grep() % ([what], [files])
{
   % optional arguments, ask if not given
   variable what, files;
   (what, files) = push_defaults( , , _NARGS);
   if (what == NULL)
     {
	what = read_mini("(Flags and) String to grep: ", LAST_GREP, "");
	LAST_GREP = what;
     }
   if (files == NULL)
     files = read_with_completion ("Where to grep: ", "", "", 'f');

   variable cmd, dir = buffer_dirname(), allfiles = "", status;

   % set the working directory
   () = chdir(dir);

   % Build the command string:

   % The output buffer will be set to the active buffer's dir
   % If the path starts with dir, we can strip it.
   % (Note: this maight fail on case insensitive filesystems).
   files = contract_filename(files);

   % recursive grep with special filename bang (!) (analog to kpathsea)
   if (path_basename(files) == "!")
     {
	what = "-r " + what;
	files = path_dirname(files);
     }
   % append wildcard, if no filename (or pattern) is given
#ifdef UNIX
   allfiles = "*";
#elifdef IBMPC_SYSTEM
   allfiles = "*.*";
#endif
   if (path_basename(files) == "")
     files = path_concat(files, allfiles);

   cmd = GrepCommand + " " + what + " " + files;

   % Prepare the output buffer
   popup_buffer("*grep_output*", FileList_max_window_size);
   setbuf_info("", dir, "*grep_output*", 0);
   erase_buffer();
   set_buffer_modified_flag(0);

   % call the grep command
   flush("calling " + cmd);
   status = run_shell_cmd(cmd);

   % handle result
   switch (status)
     { case 1:
	close_buffer();
	message("No results for " + cmd);
	return;
     }
     { case 2:
	message("Error (or file not found) in " + cmd);
     }
   % remove empty last line (if present)
   if (bolp() and eolp())
     call("backward_delete_char");
   fit_window(get_blocal("is_popup", 0));
   bob();
   set_status_line("Grep: " + cmd + " (%p)", 0);
   grep_mode();
}

%}}}

provide(mode);


% file grep.sl
% -*- mode: SLang; mode: fold -*-
%
% Tries to open a file from the current line in current buffer. 
% This was created to follow grep-output lines
% 
% a powerful example of how to use this is doing:
% fgrep -n "sometext" * | jed -f grep_mode
% go to a line looking promising and press ENTER. (or double click on
% the line)
% You should have grep_mode in your autoload list for this to work.
%
% If you are already running jed, start a grep-search with the grep()
% command.
%
% Additionally to the custom variable "GrepCommand",
% you can customize the jedgrep_mode by the use of "grep_mode_hook".
% 
% Version 2.0  * A total remake of Dino Sangois jedgrep under use of
%                the new listing and filelist modes.
%                (Which by themselves are inspired by the old jedgrep by Dino)
%              * grep_replace_command: Replace in the grep results
%                (both, result display and source files!)
%              
% TODO: use search_file and list_dir if grep is not available

% Give it a name:
static variable GrepMode = "Grep";
% set up namespace, enable reevaluation
if (_featurep(GrepMode))
  use_namespace(GrepMode);
else
  implements(GrepMode);

% --- Requirements --------------------------------------------- %{{{
require("keydefs");
autoload("replace_with_query", "srchmisc");
   
require("filelist"); % which does require "listing" and "datutils"
autoload("popup_buffer", "bufutils");
autoload("buffer_dirname", "bufutils");
%}}}

% --- Variables -------------------------------------------------%{{{

% the grep command
custom_variable ("GrepCommand", "grep -H -n"); % print filename and linenumbers
% remember the string to grep (as default for the next run) (cf. LAST_SEARCH)
static variable LAST_GREP = "";
% quasi constants
%}}}


% Internal helpers %{{{
static define homedir_to_tilde()
{
   variable HomeLen, Home = getenv("HOME");
   if (Home == NULL)
     return;
   HomeLen = strlen(Home);
   if (HomeLen == 0)
     return;
   bob();
   while (bol_fsearch(Home)) 
     {
	replace_chars(HomeLen, "~");
     }
}

% Compute the length of the grep-prefix in the current line
define grep_prefix_length()
{
   push_spot_bol();
   () = ffind_char(get_blocal("delimiter", ':'));
   go_right_1();
   () = ffind_char(get_blocal("delimiter", ':'));
   what_column();  % leave on stack as return value
   pop_spot();
}
%}}}


% --- Replace across files ------------------------------------- %{{{

static variable Buffers_to_Close = String_Type[0];

define grep_fsearch(pat)
{
   variable pat_len;
   forever
     {
	pat_len = fsearch(pat);
	!if(pat_len)
	  return -1;
	if (what_column > grep_prefix_length())
	  return pat_len;
	go_right_1;
     }
   
}

% The actual replace function (replace in both, the grep output and the file)
define grep_replace(new, pat_len)
{
   variable nbuf, nbuf_after;
   variable curbuf = whatbuf();
   variable col = what_column() - grep_prefix_length();
   
   % get the pattern to be replaced
   push_mark();
   () = right(pat_len);
   variable pat = bufsubstr_delete();
   ERROR_BLOCK 
     {
	sw2buf(curbuf);
	insert(pat);
     }
   
   % remember the number of opened buffers
   nbuf = buffer_list();
   _pop_n(nbuf); % remove the buffer names from stack
     
   % open the file pointed to and goto the right line and col
   filelist_open_file();
   () = goto_column_best_try(col);
   
   nbuf_after = buffer_list();
   _pop_n(nbuf_after); % remove the buffer names from stack
   
   if (nbuf_after > nbuf)
     Buffers_to_Close = array_append(Buffers_to_Close, whatbuf());

   % replace, if everything is ok
   !if (looking_at(pat))
	error("File differs from grep output");
   replace_chars(pat_len, new); % leave strlen(new) on stack
   sw2buf(curbuf);
   insert(new);
   return; % (strlen(new));
}

public define grep_replace_cmd ()
{
   variable pat, prompt, rep, default;
   
   ERROR_BLOCK
     {
	REPLACE_PRESERVE_CASE_INTERNAL = 0;
	set_readonly(1);
	set_buffer_modified_flag(0);
     }
   
   % find default value: region or word under cursor
   if(is_visible_mark)  % region marked: set point to beg of region
     { 
	check_region(0);
	exchange_point_and_mark();
     }
   else % mark current word
     {
	skip_word_chars();
	push_mark;
	bskip_word_chars();
     }
   default = bufsubstr();
   pat = read_mini("Grep-Replace:", "", default);
   !if (strlen (pat)) return;
   
   prompt = strcat("Grep-Replace '", pat, "' with:");
   rep = read_mini(prompt, "", "");
   
   set_readonly(0);   
   REPLACE_PRESERVE_CASE_INTERNAL = REPLACE_PRESERVE_CASE;
   replace_with_query (&grep_fsearch, pat, rep, 1, &grep_replace);

   EXECUTE_ERROR_BLOCK;
   foreach (Buffers_to_Close)
     {
	setbuf(());
	save_buffer();
	delbuf(whatbuf());
     }
   Buffers_to_Close = String_Type[0];
   message ("done.");   
}
%}}}


% --- The grep-mode ----------------------------------------------- %{{{

create_syntax_table(GrepMode);

#ifdef HAS_DFA_SYNTAX
%%% DFA_CACHE_BEGIN %%%
static define setup_dfa_callback(name)
{
   dfa_enable_highlight_cache("grep.dfa", name);
   dfa_define_highlight_rule("^[^:]*", "keyword", name);
   dfa_define_highlight_rule(":[0-9]+:", "number", name);
   % Uhm, this matches numbers enclosed by ':' anywhere. If this really
   % annoys you, either:
   % 1 - disable dfa highlighting
   % 2 - comment the two dfa_define_highlight_rule above and use instead:
   %       dfa_define_highlight_rule("^[^:]*:[0-9]+:", "keyword", name);
   
   dfa_build_highlight_table(name);
}
dfa_set_init_callback (&setup_dfa_callback, GrepMode);
%%% DFA_CACHE_END %%%
enable_dfa_syntax_for_mode(GrepMode);
#endif

!if(keymap_p(GrepMode))
{
   copy_keymap(GrepMode, "filelist");
   rebind("replace_cmd", "grep_replace_cmd", GrepMode);
}
%}}}

% Interface: %{{{

% a mode dedicated to the grep command
public define grep_mode ()
{
   homedir_to_tilde();
   define_blocal_var("delimiter", ':');
   define_blocal_var("line_no_position", 1);
   filelist_mode();
   set_mode(GrepMode, 0);
   use_syntax_table (GrepMode);
   use_keymap(GrepMode);
   run_mode_hooks("grep_mode_hook");
}

% Grep for "what" in the file(s) "where" (use shell wildcards)
% TODO: What does gnu grep expect on DOS, What should this be on VMS and OS2 ?
public define grep() % ([what], [where]);
{
   % optional arguments, ask if not given
   variable what, where;
   (what, where) = push_defaults( , , _NARGS);

   if (what == NULL)
     {
	what = read_mini("(Flags and) String to grep: ", LAST_GREP, "");
	LAST_GREP = what;
     }
   if (where == NULL)
     where = read_with_completion ("Where to grep: ", "", "", 'f');
   

   % Build the command string:
   variable full_cmd, dir = buffer_dirname(), allfiles = "";
   
   % The output buffer will be set to the active buffer's dir
   % So the dir-part of where is redundant and we can strip it. 
   % (Note: this maight fail on case insensitive filesystems).
   (where, ) = strreplace(where, dir, "", strlen(where));
   
   % append wildcard, if no filename (or pattern) is given
#ifdef UNIX
   allfiles = "*";
#elifdef IBMPC_SYSTEM
   allfiles = "*.*";
#endif
   if (path_basename(where) == "")
     where = path_concat(where, allfiles);
   
   full_cmd = GrepCommand + " " + what + " " + where;
   
   % Prepare the output buffer
   setbuf("*grep_output*");
   setbuf_info("", dir, "*grep_output*", 0);
   () = chdir(dir);
   erase_buffer();
   
   % call the grep command
   flush("calling " + full_cmd);
   shell_perform_cmd(full_cmd, 1);
   if (bobp and eobp)
     insert("No results for " + full_cmd);
   % insert("% Command: " + full_cmd + "\n");
   set_status_line("Grep: " + full_cmd + " (%p)", 0);

   grep_mode();
   popup_buffer(whatbuf(), 1.0);  % max popup size is full screen
}

%}}}

provide(GrepMode);


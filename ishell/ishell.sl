% Interactive shell mode (based on ashell.sl by J. E. Davis)
%
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Run interactive programs (e.g. mupad/python/gnuplot) in a "workbook".
% Keep in/output easy editable, great for experimenting with scripts.
% Features not present in ashell:
%     * a region (if defined) is sent to shell at one stroke
%     * _Reserved_Key_Prefix+<Return> starts evaluation of line/region
%     * <Return> behaves as normal
%     * undo is enabled
%     * ishell_mode: start interactive shell for active buffer
%     * optional argument to ishell_mode: start any process
%     * Adjustable output via function ishell_set_output_placement(key)
%     * blocal hook "Ishell_output_filter" -> format process output
%
% Supplement (belongs rather to shell.sl)
%     * shell_cmd_on_region
%
% !!! Beta Code. Only tested with Linux. !!!
% There are known problems with ishell under Windows. If you want to use
% ishell with windows, and are ready to help in bugfixing, get in contact
% with the author.
%
% Versions
% 1.0 * first public version
% 1.1 * new option for IShell_Output_Placement: "o" separate output buffer
%     * keybindings go to an own map with push/pop_keymap
%     * default keybindings use definekey_reserved(...)
%     * Under UNIX: bg-process creates one buffer for all bg-processes
% 1.2 * Cleanup, do_shell_cmd_on_region -> shell_cmd_on_region(cmd, output=0)
% 1.3 May 2003
%     * minor-Mode menu,
%     * IShell_output_placement: changed "end of buffer from "" to "_",
%     * replaced bg_process with terminal() after learning about
%       run_program() and system(cmd + "&")
%     * new: blocal hook "Ishell_output_filter" (the hook should take a
%       string, process it and return.
% 1.4 * Large input (>4090 bytes) went missing
%       an input cache tries to solve this (see also cached-process.sl)
%     * New blocal var Process_Handle holds "metadata" for the attached
%       process, replacing most "IShell_*" blocal vars
% 1.4.1 (2003-12-08)
%     * ishell-version of process_region() deleted (was buggy)
%       (take the original one from pipe.sl or use shell_cmd_on_region(cmd, 2)
%     * shell_cmd_on_region: new output option 4: message
%     * ishell_mode sets the blocal run_buffer_hook
%     * new function bufsubfile (might rather go to bufutils?)
%     * renamed custom variables IShell_* to Ishell_*
% 1.5 (2004-04-17)
%     * moved bufsubfile() to bufutils
%     * filter_region() convenience-function equal to shell_cmd_on_region(,2)
% 1.5.1 (2004-05-07)
%     * shell_cmd_on_region: code cleanup; added a sw2buf(buf);
% 1.5.2 (2004-06-03)
%     * added ^M-Filter in ishell_insert_output() (tip P. Boekholt)
% 1.5.3 2004-09-17
%     * bugfix: do not set blocal_var run_buffer, as this will not work with
%               push_mode()/pop_mode()
% 1.6   20004-11-30
%     * added new optional argument "postfile_args" to shell_cmd_on_region
%
% USAGE ishell()              opens a shell in a buffer on its own
%  	ishell_mode([cmd])    attaches an interactive process to the
% 		    	      current buffer (defaults to shell)
%	shell_cmd_on_region() non-interactive cmd with region as argument
%
% CUSTOMIZATION
%     * custom variables
%          Ishell_default_output_placement  >
% 	   Ishell_logout_string             
% 	   Shell_Default_Shell              OS-specific
% 	   Ishell_Default_Shell  Shell_Default_Shell+" -i" (UNIX)
%     * ishell_mode_hook, e.g. for nicer keybindings
%     * blocal hook "Ishell_output_filter" -> format process output
%
% Examples for output filters:
%
%    % Some programs put out ^M-s. We don't want them on Unix
%         define mupad_ishell_output_filter(str)
%           { return str_delete_chars (str, "\r"); }
%    % Output commenting:
%         define ishell_comment_output(str)
%           {
%              return strreplace_all (str, "\n", "\n"+"% ");
%           }
%    define_blocal_var("Ishell_output_filter", "ishell_comment_output")
%    % Give a message instead of inserting anything:
%         define ispell_output_message(str)
%           {
%              vmessage("%d bytes of output", strlen(str));
%              return ""; % empty string
%           }

% For debugging purposes:
% _debug_info = 1;

% --- requirements ----------------------------------------------------
autoload("push_keymap", "bufutils");
autoload("pop_keymap", "bufutils");
autoload("rebind", "bufutils");
autoload("buffer_dirname", "bufutils");
autoload("popup_buffer", "bufutils");
autoload("close_buffer", "bufutils");
autoload("get_blocal", "sl_utils");
autoload("push_defaults", "sl_utils");
autoload("run_blocal_hook", "bufutils");
autoload("bufsubfile", "bufutils");
% autoload("strbreak", "strutils");

% ------------------ custom variables ---------------------------------

% Where is output from the process placed: (see also help for set_process())
%    "_"           end of buffer
%    "@"           end of buffer (return to point)
%    ">"           below corresponding input (on an own line)
%    "o"           output buffer
%    "."           point (also the default for not listed strings)
custom_variable("Ishell_default_output_placement", ">");

% the string sent to the process for logout
custom_variable("Ishell_logout_string", ""); % default is Ctrl-D

% maximal size for resizing the ishell output buffer (if external)
custom_variable("Ishell_Max_Popup_Size", 5);

% the default shell and interactive-shell:
%
% (in ashell.sl, Ishell_Default_Shell is misleadingly named and
% contains just the flag for interactivity)
#ifdef WIN32
custom_variable("Shell_Default_Shell", getenv ("COMSPEC"));
if (Shell_Default_Shell == NULL)
  Shell_Default_Shell = "cmd.exe";
% in windoof these are the same
custom_variable("Ishell_Default_Shell", Shell_Default_Shell);
#else
% in UNIX, the interactive shell has the interacitve flag but might also be a
% completely different one (say sh for normal but bash -i for interactive
% if you want this, set the variable Ishell_Default_Shell
custom_variable("Shell_Default_Shell", getenv ("SHELL"));
if (Shell_Default_Shell == NULL)
  Shell_Default_Shell = "sh";
custom_variable("Ishell_Default_Shell", Shell_Default_Shell+" -i");
#endif

% --- static variables

% There is a restriction on the length of the string that can be fed
% to an attached process at once as well as on the length of the return-string
% these are the testresults with xjed 0.99.16 on a PC running Linux
% Output: string of 512 characters
% static variable Process_Output_Size = 512; % maximum - 1 (for savety)
% Input: string of 4096 chars
static variable Process_Input_Size = 4096;

% --- Functions ------------------------------------------------------

% (Re)set process handle to default values
static define initialize_process_handle()
{
   variable handle = struct{id, name,
	input, output_placement,
	prompt, mark};
   handle.id = -1;
   handle.name = "";    % process name (+ arguments)
   handle.input = "";   % cache for input data
   handle.output_placement = Ishell_default_output_placement;
   handle.prompt = "";
   handle.mark = create_user_mark(); %for output positioning
   define_blocal_var("Ishell_Handle", handle);
}

% send region or current line to attached process
define ishell_send_input ()
{
   variable str, handle = get_blocal_var("Ishell_Handle");
   push_spot();
   if (is_visible_mark)  % if there is a region defined, take it as input
     {
	check_region(0);
	str = bufsubstr();
     }
   else
     str = line_as_string();
   if (handle.output_placement == ">") % below corresponding input
     newline();
     % {
     % 	insert("\n\n"); % separate from input by newlines
     % 	go_left_1();
     % }
   move_user_mark(handle.mark);
   pop_spot();
   % remove prompt if present
   if (is_substr(str, handle.prompt) == 1)
     str = str[[strlen(handle.prompt):]];
   % make sure there is a newline at the end (prompting input processing)
   % (cannot use strtrim_end("\n"), as this kills also several \n-s)
   if (str[-1] != '\n')
     str += "\n";
   % show("ishell_input:", str);
   % show("prompt:", handle.prompt);
   % send to attached process (via handle.input fifo cache)
   handle.input += str; % FI
   while (strlen(handle.input))
     {
	str = substr(handle.input, 1, Process_Input_Size);           % FO
	handle.input = substr(handle.input, Process_Input_Size+1, -1); %
	% (str, handle.input) =
	%   strbreak(handle.input, Process_Input_Size, '\n'); % FO
	send_process(handle.id, str);
	get_process_input(1);
     }
}

% insertion of output
define ishell_insert_output (pid, str)
{
   variable buf = whatbuf(), handle = get_blocal_var("Ishell_Handle");

   % Some programs (especially under Windooof) put out ^M-s,
   % jed does not expect them (regardless of the crmode).
   str = str_delete_chars (str, "\r");

   % find out what the prompt is (normally the last line of output)
   handle.prompt = strchop (str, '\n', 0)[-1];

   % show("ispell_output:", str);
   % filter the output string (call a filter-output-hook)
   if (blocal_var_exists("Ishell_output_filter"))
     str = run_blocal_hook("Ishell_output_filter", str);
   % abort, if filter returns empty string
   !if (strlen(str))
     return;

   % where shall the output go?
   switch(handle.output_placement)
     { case "_" :  eob;}
     { case "@" : push_spot; eob;}
     { case ">" : goto_user_mark(handle.mark);}
     { case "o" : % output-buffer
	popup_buffer(buf + "-output", Ishell_Max_Popup_Size);
	eob();
	set_readonly(0);
	insert(str);
	eob();
	fit_window(get_blocal("is_popup", 0));
	view_mode();
	pop2buf(buf);
	return;
     }
     % Default: output will go to the current buffer position.

   insert(str);
   move_user_mark(handle.mark);

   if (handle.output_placement == "@")
     pop_spot();       % return to previous position
   %make the insertion visible
   update_sans_update_hook(0);
}

% abort process (keybord abort)
define ishell_send_intr ()
{
   signal_process (get_blocal_var("Ishell_Handle").id, 2);
}

% abort process (send Ishell_logout_string default(Ctrl-D))
define ishell_logout ()
{
   send_process (get_blocal_var("Ishell_Handle").id, Ishell_logout_string);
}

% feedback on signals, tidy up after exit
define ishell_signal_handler (pid, flags, status)
{
   variable handle = get_blocal_var("Ishell_Handle");
   variable msg = aprocess_stringify_status(pid, flags, status);
   flush(handle.name + ": " + msg);
   if (flags > 2) % Process Exited
     {
	initialize_process_handle();
	pop_keymap(); % pop ishell minor mode
     }
}

define ishell_open_process(command_line)
{
   !if (blocal_var_exists("Ishell_Handle"))
     initialize_process_handle();
   variable handle = get_blocal_var("Ishell_Handle");

   handle.name = command_line;
   flush ("starting " + command_line + " ...");
   command_line = strtok (command_line);
   foreach (command_line)
     ; % push on stack
   handle.id = open_process (length(command_line) - 1);

   set_process (handle.id, "signal", &ishell_signal_handler);
   set_process (handle.id, "output", &ishell_insert_output);
}

define ishell_set_output_placement(key)
{
   get_blocal_var("Ishell_Handle").output_placement = key;
}

% ishell menu, appended to an existing mode menu
static define ishell_menu(menu)
{
   variable init_menu = get_blocal_var("init_mode_menu");
   if (init_menu != NULL)
     {
	@init_menu(menu);
	menu_append_separator(menu);
     }
   variable submenu = "Set Output &Placement";
   menu_append_item(menu, "&Logout (quit ishell)", "ishell_logout");
   menu_append_item(menu, "&Enter input",          "ishell_send_input");
   menu_append_item(menu, "&Interrupt",            "ishell_send_intr");
   menu_append_popup(menu, submenu);
   menu += "." + submenu;
   menu_append_item(menu, "&_ End of buffer",         "ishell_set_output_placement", "_");
   menu_append_item(menu, "&@ eob (return to point)", "ishell_set_output_placement", "@");
   menu_append_item(menu, "&. Point",		      "ishell_set_output_placement", ".");
   menu_append_item(menu, "&> Line below input",      "ishell_set_output_placement", ">");
   menu_append_item(menu, "&o Output buffer",         "ishell_set_output_placement", "o");
}

% ishell_mode: open a process and attach it to the current buffer.
% by default, the process is Ishell_Default_Shell,
% the optional argument String "command_line" overrides this.
% Void ishell_mode(String command_line=Ishell_Default_Shell)
public define ishell_mode() % (command_line=Ishell_Default_Shell)
{
   variable command_line = push_defaults(Ishell_Default_Shell, _NARGS);

   % set the working dir to the active buffers dir
   () = chdir(buffer_dirname());
#ifdef UNIX
   putenv("PAGER=cat"); % jed has more or less problems otherwise ;-)
#endif

   % start the process
   ishell_open_process(command_line);

   define_blocal_var("init_mode_menu", mode_get_mode_info("init_mode_menu"));

   % modifiy keybindings (use an own keymap):
   variable ishell_map = what_keymap()+" ishell";
   !if (keymap_p(ishell_map))
     {
	copy_keymap(ishell_map, what_keymap());
	definekey_reserved("ishell_send_intr",  "G",  ishell_map);
	definekey_reserved("ishell_logout",     "D",  ishell_map);
	definekey_reserved("ishell_send_input", "^M", ishell_map); % Enter
	rebind("run_buffer", "ishell_send_input", ishell_map);
     }

   push_keymap(ishell_map); %this also changes the modename

   % set/modify the mode-menu
   mode_set_mode_info(get_mode_name(), "init_mode_menu", &ishell_menu);
   run_mode_hooks ("ishell_mode_hook");
}

% open an interactive shell in buffer *ishell* and set to ishell_mode
public define ishell()
{
   variable buf = "*ishell*";
   pop2buf (buf);
   !if(blocal_var_exists("Ishell_Handle"))
     initialize_process_handle();
   if (get_blocal_var("Ishell_Handle").id < 0)
     {
	set_buffer_undo (1);
	sh_mode();           % syntax highlight, keybindings
	ishell_mode();
     }
}

% Run "cmd" in a terminal in the current buffers dir.
% terminal is the one jed runs on or (with xjed) given by variable XTerm_Pgm
% (see run_program)
public define terminal() % (cmd = Ishell_Default_Shell)
{
   variable cmd = push_defaults(Ishell_Default_Shell, _NARGS);
   () = chdir(buffer_dirname);
   () = run_program(cmd);
}

% --- run a command with the buffer/region as argument ---------------------
%
% (This section should rather go to shell.sl.)

% the last command as default for the next call, also used by shell.sl,
% so we use custom_variable to not overwrite it when evaluating ishell
custom_variable("Shell_Last_Shell_Command", "");

%!%+
%\function{shell_cmd_on_region}
%\synopsis{Save region to a temp file and run a command on it}
%\usage{Void shell_cmd_on_region (cmd="", output_handling=0, postfile_args="")}
%\usage{Void shell_cmd_on_region (cmd="", String output_buffer, postfile_args="")}
%\description
% The \var{shell_cmd_on_region} function starts cmd in a shell.
% If no argument is given, the user will be prompted for a command to execute.
% The region will be saved to a temporary file and its name appended to the
% arguments. If no region is defined, the whole buffer is taken instead.
% Output handling is controled by the second argument (defaults to 0)
%          -1   ignore the output,
%           0   a new buffer is opened for the output (if there is output).
%           1   output will be inserted on the edition point,
%           2   output replaces the region/buffer.
%           3   return output as string
%           4   message output
% or
%    "<name>"   name of a new buffer for the output
%
% The third argument \var{postfile_args} will be % inserted in the command 
% string after the filename argument. Use it e.g. for the outfile in commands 
% like "rst2html infile outfile".
% \seealso{filter_region, shell_cmd, do_shell_cmd}
%!%-
public define shell_cmd_on_region () % (cmd="", output_handling=0, postfile_args=)
{
   variable cmd, output_handling, postfile_args;
   (cmd, output_handling, postfile_args) = push_defaults("", 0, "", _NARGS);
   % read command from minibuffer if not given as optional argument
   if (orelse {cmd == NULL}{cmd == ""}) % NULL test for backup compatibility
     {
	cmd = read_mini (sprintf ("Shell Cmd on Region:"),
			 "", Shell_Last_Shell_Command);
	if (cmd == "")
	  return;
	Shell_Last_Shell_Command = cmd;
     }

   variable status, file,
     buf = whatbuf(), % current buffer
     outbuf = "*shell-output*";

   % second arg can also be the name of the output buffer
   if (typeof(output_handling) == String_Type)
     {
	outbuf = output_handling;
	output_handling = 0;
     }

   % save region/buffer to file (delete if output_handling == 2)
   file = bufsubfile(output_handling==2);

   % set output buffer
   if (output_handling == 0)
     {
	popup_buffer(outbuf);
	set_readonly(0);
	eob;
	!if(bobp())
	  insert("\n------------------------------------\n\n");
     }
   else if (output_handling < 0 or output_handling > 2)
     {
	outbuf = "*scratch*";
	sw2buf(outbuf);
	push_mark();
     }

   % redirect output/error
# ifdef OS2
   postfile_args += " 2>&1";
# elifdef UNIX
   postfile_args += " 2>&1 < /dev/null";
# endif

   % Run the command on the file
   flush ("Running " + cmd);
   status = run_shell_cmd(sprintf("%s %s %s", cmd, file, postfile_args));
   vmessage("%s exited with %d", cmd, status);

   % Output processing/cleanup
   switch (output_handling)
     % { case -1: } % nothing to do
     { case 0:
	if(bobp and eobp)
	  {
	     close_buffer();
	     message(MESSAGE_BUFFER + ": no output");
	  }
	else
	  view_mode();
	return;
     }
     { case 1 or case 2: return; }
     { case 3: bufsubstr(); }          % push return value on stack
     { case 4: message(strtrim(bufsubstr_delete)); }
   set_buffer_modified_flag(0);
   delbuf(outbuf);
   sw2buf(buf);     % make sure we return to the current buffer
}

%!%+
%\function{filter_region}
%\synopsis{Filter the region through a shell command}
%\usage{filter_region(cmd=NULL)}
%\description
% Start cmd in a sub-shell. If no argument is given, the user will be
% prompted for one.
% The region will be saved to a temporary file and its name appended to the
% arguments. If no region is defined, the whole buffer is taken instead.
% The command output will replace the region/buffer.
%\seealso{shell_cmd_on_region, do_shell_cmd}
%!%-
public define filter_region() % (cmd=NULL)
{
   !if(_NARGS)
     NULL;
   shell_cmd_on_region(2);
}

public define shell_cmd2string(cmd)
{
   variable status, output, buf = whatbuf(), outbuf = "*scratch*";

   sw2buf(outbuf);
   push_mark();
   flush ("Running " + cmd);
   status = run_shell_cmd(cmd);
   vmessage("%s exited with %d", cmd, status);
   output = strtrim(bufsubstr_delete());
   sw2buf(buf);
   return output;
}

provide("ishell");

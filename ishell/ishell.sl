% Interactive shell mode (based on ashell.sl by J. E. Davis)
%
% Copyright (c) 2006 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Features
% --------
% 
% Run interactive programs (e.g. mupad/python/gnuplot) in a "workbook mode".
% Keep in- and output easy editable, great for experimenting with scripts.
% 
%   ishell([cmd])         open a shell in a buffer on its own
%   ishell_mode([cmd])    attach an interactive process (default
% 			`Shell_Default_Shell') to the current buffer 
% 
% Features not present in ashell:
%     * a region (if defined) is sent to the command at one stroke
%     * _Reserved_Key_Prefix+<Return> starts evaluation of line/region
%     * <Return> behaves as normal
%     * undo is enabled
%     * optional argument to ishell_mode: start any process
%     * Adjustable output via function ishell_set_output_placement(key)
%     * blocal hook "Ishell_output_filter" -> format process output
%
% Supplement (belongs rather to shell.sl):
%
%   shell_cmd_on_region()  non-interactive cmd with region as argument
%
% !!! Beta Code. Only tested with Linux. !!!
% There are known problems with ishell under Windows. If you want to use
% ishell with windows, and are ready to help in bugfixing, get in contact
% with the author.
%
% Versions
% --------
% 
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
% 1.4.1 2003-12-08 * ishell-version of process_region() deleted (was buggy)
%                    (take the original one from pipe.sl or use
%                    shell_cmd_on_region(cmd, 2)
%                  * shell_cmd_on_region: new output option 4: message
%                  * ishell_mode sets the blocal run_buffer_hook
%                  * new function bufsubfile (might rather go to bufutils?)
%                  * renamed custom variables IShell_* to Ishell_*
% 1.5   2004-04-17 * moved bufsubfile() to bufutils
%                  * filter_region() convenience-function equal to
%                    shell_cmd_on_region(,2)
% 1.5.1 2004-05-07 shell_cmd_on_region: code cleanup; added a sw2buf(buf);
% 1.5.2 2004-06-03 added ^M-Filter in ishell_insert_output() (tip P. Boekholt)
% 1.5.3 2004-09-17 bugfix: do not set blocal_var run_buffer,
%                  as this will not work with push_mode()|pop_mode()
% 1.6   2004-11-30 optional argument "postfile_args" to shell_cmd_on_region()
% 1.6.1 2005-04-07 bugfix: autoload for view_mode
% 1.7   2005-04-14 new command do_shell_cmd() replacing the one from shell.sl
%                  with a more configurable one by using code
%                  from shell_cmd_on_region()
% 1.7.1 2005-07-08 as the reuse of the do_shell_cmd() name lead to conflicts,
%                  ishell's version is renamed to shell_command().
% 1.8   2005-07-28 new function shell_cmd_on_region_or_buffer():
%                  Doesnot save to a temporary file if no region is defined
% 1.8.1 2005-11-18 added documentation for custom variables and all
%                  public functions
% 1.8.2 2006-05-10 bugfix: added missing autoload for normalized_modename()
% 1.8.3 2006-05-19 better cursor placement in shell_command(cmd, 0)
% 1.8.4 2006-05-26 fixed autoloads (J. Sommer)
% 1.8.5 2006-10-04 shell_cmd_on_region_or_buffer: use bufsubfile() only if
%                  *visible* mark is set
% 1.8.6 2006-10-09 bugfix in shell_command (did set the current buffer to
% 		   view-mode if there was no output from the command)
% 1.9   2006-11-10 shell_cmd_on_region_or_buffer() now saves the buffer to a
% 		   temporary file (instead of asking for a filename) if there 
% 		   is no file associated to the buffer (and no visible region)
% 1.9.1 2006-11-23 bugfix in shell_cmd_on_region_or_buffer()
% 		   (`output_handling' can be string or integer)
% 1.9.2 2007-05-14 cleanup in ishell()
% 1.10  2007-12-11 new output_placement "l": Log (input and output) in outbuf
% 		   fix autoloads
%
% Customisation
% -------------
% 
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
%    % Output commenting:
%       define ishell_comment_output(str)
%         {
%            variable c = get_comment_info()
%            return strreplace_all (str, "\n", \n"+c.cbeg);
%         }
%       define_blocal_var("Ishell_output_filter", "ishell_comment_output")
%
%    % Give a message instead of inserting anything:
%       define ishell_output_message(str)
%         {
%           vmessage("%d bytes of output", strlen(str));
%           return ""; % empty string
%         }
%       define_blocal_var("Ishell_output_filter", "ishell_output_message")

% _debug_info = 1;

% Requirements
% ------------

autoload("push_keymap", "bufutils");
autoload("pop_keymap", "bufutils");
autoload("rebind", "bufutils");
autoload("buffer_dirname", "bufutils");
autoload("popup_buffer", "bufutils");
autoload("close_buffer", "bufutils");
autoload("normalized_modename", "bufutils");
autoload("fit_window", "bufutils");
autoload("get_blocal", "sl_utils");
autoload("push_defaults", "sl_utils");
autoload("run_local_function", "bufutils");
autoload("bufsubfile", "bufutils");
autoload("view_mode", "view");
autoload("get_buffer", "txtutils");

% autoload("strbreak", "strutils");

% ------------------ custom variables ---------------------------------

%!%+
%\variable{Ishell_default_output_placement}
%\synopsis{Customize output placement of interactive shell commands}
%\usage{String_Type Ishell_default_output_placement = ">"}
%\description
% Where is output from the process placed:
%    "_" or ""     end of buffer
%    "@"           end of buffer (return to point)
%    ">"           new line below corresponding input
%    "."           current point position
%    "o"           separate output buffer
%    "log"         log input and output in a separate buffer
% The default for not listed strings is "."
%\notes
% This is an extended version of the options for \sfun{set_process}
%\seealso{ishell, ishell_mode, set_process}
%!%-
custom_variable("Ishell_default_output_placement", ">");

%!%+
%\variable{Ishell_logout_string}
%\synopsis{interactive shell logout string}
%\usage{String_Type Ishell_logout_string = ""}
%\description
% The string sent to the process for logout.
%\seealso{ishell, ishell_mode}
%!%-
custom_variable("Ishell_logout_string", ""); % default is Ctrl-D

%!%+
%\variable{Ishell_Max_Popup_Size}
%\synopsis{Size of ishell output buffer}
%\usage{Int_Type Ishell_Max_Popup_Size = 0.3}
%\description
%  Maximal size for resizing the ishell output buffer
%\seealso{ishell, ishell_mode, Ishell_default_output_placement}
%!%-
custom_variable("Ishell_Max_Popup_Size", 0.3);

%!%+
%\variable{Ishell_Default_Shell}
%\synopsis{Default interactive shell}
%\usage{Int_Type Ishell_Default_Shell = getenv ("SHELL")}
%\description
% The default process started by \sfun{ishell_mode}.
%
% In UNIX, the interactive shell has the interacitve flag but might also be a
% completely different one (say `sh` for normal but `bash -i` for interactive.
% If you want this, set the variable Ishell_Default_Shell
%\notes
% in ashell.sl, \var{Shell_Default_Interactive_Shell} is misleadingly named
% as it contains just the 'interactive' flag)
%\seealso{Shell_Default_Shell, ishell, ishell_mode}
%!%-
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

% append str to the corresponding output buffer of buffer `buf'
static define append_to_outbuf(buf, str)
{
   variable outbuf = sprintf("*%s Output*", buf);
   popup_buffer(outbuf, Ishell_Max_Popup_Size);
   eob();
   set_readonly(0);
   insert(str);
   eob();
   fit_window(get_blocal("is_popup", 0));
   view_mode();
   pop2buf(buf);
   return;
}


% send region or current line to attached process
define ishell_send_input()
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
   if (handle.output_placement == "l") % log
      append_to_outbuf(whatbuf(), str);
   % show("prompt:", handle.prompt);
   
   % Send to attached process 
   % (use handle.input fifo cache to send in chunks not larger than
   %  Process_Input_Size)
   handle.input += str; % first-in
   while (strlen(handle.input))
     {
	str = substr(handle.input, 1, Process_Input_Size);  % first-out
	handle.input = substr(handle.input, Process_Input_Size+1, -1); %
	% (str, handle.input) =
	%   strbreak(handle.input, Process_Input_Size, '\n'); % FO
	send_process(handle.id, str);
	get_process_input(1);
     }
}

% insertion of output
define ishell_insert_output(pid, str)
{
   variable buf = whatbuf(), handle = get_blocal_var("Ishell_Handle");
   % Some programs put out ^M-s also in their UNIX version,
   % Jed does not expect them (regardless of the crmode).
   % (Please mail if this poses problems on Windows, so that it can be made
   % conditional.)
   str = str_delete_chars (str, "\r");
   
   % find out what the prompt is (normally the last line of output)
   handle.prompt = strchop(str, '\n', 0)[-1];

   % Filter the output string (call a filter-output-hook)
   % show("ispell_output:", str);
   if (run_local_function("Ishell_output_filter", str))
      str = ();
   % abort, if filter returns empty string
   !if (strlen(str))
     return;
   
   % Insert output string
   %  go to the right place
   switch(handle.output_placement)
     { case "_": eob; }
     { case "@": push_spot; eob; }
     { case ">": goto_user_mark(handle.mark); }
     { case "o" or case "l": append_to_outbuf(buf, str); return; }
     % { case "m" : message(strtrim(str)); } % does this work at all?
     % { case "." : ; } % (insert at current buffer position, default) 
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
   variable init_menu =
     mode_get_mode_info(normalized_modename(), "init_mode_menu");
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
   menu_append_item(menu, "&l Log buffer",            "ishell_set_output_placement", "l");
}

%!%+
%\function{ishell_mode}
%\synopsis{Open a process and attach it to the current buffer.}
%\usage{ ishell_mode(cmd=Ishell_Default_Shell)}
%\description
% Open an interactive process and attach to the current buffer.
% By default, the process is \var{Ishell_Default_Shell},
% the optional argument String "cmd" overrides this.
%\example
% Open an interactive python session in a new buffer:
%#v+
%  sw2buf("*python*");
%  ishell_mode("python");
%#v-
%\seealso{ishell, Ishell_default_output_placement, Ishell_Max_Popup_Size}
%!%-
public define ishell_mode() % (cmd=Ishell_Default_Shell)
{
   variable cmd = push_defaults(Ishell_Default_Shell, _NARGS);

   % set the working dir to the active buffers dir
   () = chdir(buffer_dirname());
#ifdef UNIX
   putenv("PAGER=cat"); % jed has more or less problems otherwise ;-)
#endif

   % start the process
   ishell_open_process(cmd);

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
   run_mode_hooks("ishell_mode_hook");
}

%!%+
%\function{ishell}
%\synopsis{Interactive shell}
%\usage{ ishell()}
%\description
% Open an interactive shell in buffer *ishell* and set to \sfun{ishell_mode}.
%\seealso{ishell_mode, Ishell_Default_Shell}
%!%-
public define ishell()
{
   variable buf = "*ishell*";
   pop2buf (buf);
   set_buffer_undo(1);
   !if(blocal_var_exists("Ishell_Handle"))
     {
	sh_mode();           % syntax highlight, keybindings
	ishell_mode();
     }
}

%!%+
%\function{terminal}
%\synopsis{Run a command in a terminal}
%\usage{terminal(cmd = Ishell_Default_Shell)}
%\description
% Run \var{cmd} in a terminal with the current buffers dir as pwd.
% The terminal is the one jed runs on or (with xjed) given by variable
% \var{XTerm_Pgm}
%\seealso{run_program, ishell_mode, Ishell_Default_Shell}
%!%-
public define terminal() % (cmd = Ishell_Default_Shell)
{
   variable cmd = push_defaults(Ishell_Default_Shell, _NARGS);
   () = chdir(buffer_dirname);
   () = run_program(cmd);
}

% --- run a shell command (with flexible output setting) ---------------------
%
% (This section should rather go to shell.sl.)

% the last command as default for the next call, also used by shell.sl,
% so we use custom_variable to not overwrite it when evaluating ishell
 custom_variable("Shell_Last_Shell_Command", "");

%!%+
%\function{shell_command}
%\synopsis{Run a shell command}
%\usage{Void shell_command(cmd="", output_handling=0)}
%\usage{Void shell_command(cmd="", String output_buffer)}
%\description
% Executes \var{cmd} in a shell.
% If no argument is given, the user will be prompted for a command to execute.
%
% Output handling is controled by the second argument
%      -1   ignore the output,
%       0   a new buffer is opened for the output (if there is output).
%       1   output will be inserted on the edition point,
%       2   output replaces the region/buffer.
%       3   return output as string
%       4   message output
%  "<name>" name of a new buffer for the output
%\notes
% The default is set using prefix_argument(0), i.e. you can set the output 
% handling tag via \sfun{set_prefix_argument}, too.
%\seealso{run_shell_cmd, shell_cmd, filter_region, shell_cmd_on_region}
%!%-
public define shell_command() % (cmd="", output_handling=0)
{
   % optional arguments
   variable cmd, output_handling;
   (cmd, output_handling) = push_defaults("", prefix_argument(0), _NARGS);

   variable status, buf = whatbuf(), outbuf = "*shell-output*", output = "";
   variable file, dir= buffer_dirname(), name, flags;

   % change working dir to buffer dir
   if ( change_default_dir(dir) )
     error ("Unable to chdir!");

   % ask for command in minibuffer
   if (cmd == "")
     {
	cmd = read_mini(sprintf ("(%s) Shell Cmd:", dir),
			 "", Shell_Last_Shell_Command);
	if (cmd == "") 
	  return;
	Shell_Last_Shell_Command = cmd;
     }
   

   % if second arg is a String, it is the name of the output buffer
   if (typeof(output_handling) == String_Type)
     {
	outbuf = output_handling;
	output_handling = 0;
     }

   if (output_handling == 2) % replace region or buffer
     {
	if(is_visible_mark())
	  del_region();
	else
	  erase_buffer();
     }
   % open the output buffer with popup_buffer()
   !if (output_handling == 1 or output_handling == 2) % insert in same buffer
     {
	popup_buffer(outbuf);
	(file, ,name, flags) = getbuf_info();
	setbuf_info (file, dir,name, flags);
	set_readonly(0);
	eob;
     }
     set_prefix_argument(1);

   % Run the command
   do_shell_cmd(cmd);

   % Output processing
   
   % not needed, if output inserted in same buffer
   if (output_handling == 1 or output_handling == 2)
     return;
   
   if (output_handling != 0)
     {
	push_mark(); % point is at start of output after do_shell_cmd()
	eob();
	output = bufsubstr_delete();
     }

   % close empty output buffer
   set_buffer_modified_flag(0);
   if(bobp and eobp)
     {
	close_buffer();
	sw2buf(buf);
	if(output == "")
	  message(MESSAGE_BUFFER + ": no output");
     }

   switch (output_handling)
     % { case -1 } % ignore
     { case 0:  % open in new buffer (if there is output)
	if (bufferp(outbuf))
	  {
	     !if (bobp())
	       insert("\n------------------------------------\n\n");
	     if (eobp)
	       insert(cmd + ": no output");
	     fit_window(get_blocal("is_popup", 0));
	     view_mode();
	  }
     }
     % { case 1 or case 2: }    % insert in same buf: already returned
     { case 3: return output; } % return as string
     { case 4: if (output != "") message(output); }
}

public define shell_cmd_on_region_or_buffer() % (cmd="", output_handling=0, postfile_args="")
{
   variable cmd, output_handling, postfile_args;
   (cmd, output_handling, postfile_args) = push_defaults("", 0, "", _NARGS);
   % read command from minibuffer if not given as optional argument
   if (cmd == NULL or cmd == "") % NULL test for backwards compatibility
     {
	cmd = read_mini(sprintf("(%s) Shell Cmd:", getcwd()), "",
                        Shell_Last_Shell_Command);
	Shell_Last_Shell_Command = cmd;
     }
   if (cmd == "")
     return;

   variable file = buffer_filename();
   if (file == "" or is_visible_mark())
     % save region/buffer to file (delete if output_handling == 2)
     file = bufsubfile(typecast(output_handling, Integer_Type) == 2);
   else
     {
	save_buffer();
	if (_eqs(2, output_handling))  % can be a string or integer
	   erase_buffer();
     }
   % Run the command on the file
   shell_command(strjoin([cmd, file, postfile_args], " "), output_handling);
}

%!%+
%\function{shell_cmd_on_region}
%\synopsis{Save region to a temp file and run a command on it}
%\usage{Void shell_cmd_on_region(cmd="", output_handling=0, postfile_args="")}
%\usage{Void shell_cmd_on_region(cmd="", String output_buffer, postfile_args="")}
%\description
% Run \var{cmd} in a shell. (If \var{cmd}=="", the user will be prompted for
% a command to execute.)
%
% Output handling is controlled by the second argument (see \var{shell_command})
%
% The region will be saved to a temporary file and the filename appended to
% the arguments. If no region is defined, the whole buffer is saved.
%
% The third argument \var{postfile_args} will be appended to the command
% string after the filename argument. Use it e.g. for the outfile in commands
% like "rst2html infile outfile".
% \seealso{shell_command, filter_region, run_shell_cmd}
%!%-
public define shell_cmd_on_region() % (*args)
{
   variable args = __pop_args(_NARGS);
   !if (is_visible_mark())
     {
        !if (markp())
          mark_buffer();
        % replace mark by a visible mark
        push_spot();
        pop_mark_1();
        push_visible_mark();
        pop_spot();
     }
   shell_cmd_on_region_or_buffer(__push_args(args));
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
%\seealso{shell_cmd_on_region, shell_command}
%!%-
public define filter_region() % (cmd=NULL)
{
   variable cmd = push_defaults(, _NARGS);
   shell_cmd_on_region(cmd, 2);
}

%!%+
%\function{shell_cmd2string}
%\synopsis{Run a shell cmd and return the output}
%\usage{String shell_cmd2string(String cmd)}
%\description
%   Run a shell cmd and return the output as a string.
%   This is an alias for shell_command(cmd, 3)
%\example
%#v+
%   insert(shell_cmd2string(date));
%#v-
%   would insert the current date as returned by the `date` command
%\seealso{shell_command, shell_cmd_on_region}
%!%-
define shell_cmd2string(cmd)
{
   return shell_command(cmd, 3);
}

provide("ishell");

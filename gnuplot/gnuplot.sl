% Editing mode for the Gnuplot plotting program
%
% Copyright (c) 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% based on a gnuplot highligting mode by Michele Dondi <bik.mido@tiscalinet.it>
%
%  version    1.0   gnuplot_run: run gnuplot on skripts
%                   gnuplot_shell: interactive use
%                   invoce info(gnuplot) as online help
%                   comments with comments.sl
%  version    1.1   interface for gnuplot online help (on UNIX)
%  	            keybindings via definekey_reserved
%  	      1.1.1 gnuplot-help uses view-mode (from bufutils)
%  2004-05-06 1.1.2 Added doc for custom variables
%  	            code cleanup after getting version 1.5 of ishell
%  2005-11-02 1.1.3 fixed the "public" statements
%  2006-05-26 1.1.4 fixed autoloads (J. Sommer)
%
%
%  TODO
%  * gnuplot_print
%     * set Terminal via read_with_completion if prefix_argument given,
%       otherwise use default/last choice.
%       Then, invokation from menu can be with asking, via ^P without asking.
%     * set extension according to terminal
%  * add some more keywords, sort keywords (basic vs. extensions)
%
%  To use gnuplot mode automatically for gnuplot files put the lines
%      autoload ("gnuplot_mode", "gnuplot.sl");
%  and (depending on your use)
%      add_mode_for_extension ("gnuplot", "gnuplot");
%      add_mode_for_extension ("gnuplot", "gp");
%      ...
%  in your .jedrc.
%
%  To customize the terminal and output setting for printing,
%  define the custom variables
%     Gnuplot_Print_Terminal,
%     Gnuplot_Output_Extension.
%  The actual command called for invocing gnuplot is set by
%     Gnuplot_Command
%
%  You can change keybindings with the gnuplot_mode_hook.
%  I recommend:
%
% define gnuplot_mode_hook()
% {
%    local_setkey ("gnuplot_help",  "^H");  % Help
%    local_setkey ("gnuplot_print", "^P");  % Print plot
%    local_setkey ("gnuplot_plot",  "^D");  % Display plot
% }

% ---- Requirements ---

% from jed's standard library
require("comments");
require("keydefs");
autoload("info_find_dir", "info");
autoload("info_find_node", "info");

% Extensions from http://jedmodes.sourceforge.net/
autoload("popup_buffer", "bufutils");
autoload("close_buffer", "bufutils");
autoload("get_blocal", "sl_utils");
autoload("fit_window", "bufutils");
autoload("view_mode", "bufutils");
autoload("ishell_mode", "ishell");
autoload("shell_cmd_on_region", "ishell");

% --- user adjustable settings ------------------------------------

% _debug_info = 1;

% -- Variables
% As printout I prefer *.eps files to include in LaTeX
%!%+
%\variable{Gnuplot_Print_Terminal}
%\synopsis{Terminal option used by the gnuplot_print command}
%\usage{String_Type Gnuplot_Print_Terminal = "postscript eps enhanced"}
%\description
%  The terminal option handed to gnuplot by the gnuplot_print command.
%  The default value will print an eps file suited for inlcusion in a
%  LaTeX document.
%\seealso{gnuplot_mode, gnuplot_run, Gnuplot_Output_Extension}
%!%-
custom_variable ("Gnuplot_Print_Terminal",  "postscript eps enhanced");
%!%+
%\variable{Gnuplot_Output_Extension}
%\synopsis{Extension to add to gnuplot print files}
%\usage{String_Type Gnuplot_Output_Extension = ".eps"}
%\description
%  When gnuplot prints to a file, the default filename is the buffer-files
%  basename + "." + Gnuplot_Output_Extension.
%\seealso{gnuplot_print, Gnuplot_Print_Terminal, gnuplot_mode}
%!%-
custom_variable ("Gnuplot_Output_Extension", ".eps");
%!%+
%\variable{Gnuplot_Command}
%\synopsis{Command for running gnuplot.}
%\usage{String_Type Gnuplot_Command = "gnuplot -persist"}
%\description
%  Command for running gnuplot. You might need to add a path or switches.
%\seealso{gnuplot_mode, gnuplot_run, gnuplot_shell, gnuplot_plot, gnuplot_print}
%!%-
custom_variable ("Gnuplot_Command", "gnuplot -persist");

% ----------------------------------------------------------------------------

private variable mode = "gnuplot";
private variable tmp_buf = "gnuplot_tmp";

% do commenting with comments.sl
set_comment_info (mode, "# ", "", 7);

% --- Keybindings (change with gnuplot_mode_hook)
!if (keymap_p (mode)) make_keymap (mode);
definekey_reserved("gnuplot_help",  "H", mode);  % Help
definekey_reserved("gnuplot_run",   "R", mode);  % Run buffer/region
definekey_reserved("gnuplot_run",   "^M",mode);  % Return: Run buffer/region
definekey_reserved("gnuplot_print", "P", mode);  % Print plot
definekey_reserved("gnuplot_plot",  "D", mode);  % Display plot

% --- Functions ------------------------------------

%!%+
%\function{gnuplot_info }
%\synopsis{gnuplot help via info file }
%\usage{Void gnuplot_info (); }
%\description
% open info and goto node (gnuplot), an optional argument is subnode
%\seealso{info_find_dir, info_find_node, gnuplot_mode}
%!%-
define gnuplot_info ()
{
   info_find_dir();
   info_find_node("(gnuplot)");
   if (_NARGS)                  % optional argument present
     {
	info_find_node( () ); % recurse further down
     }
   pop2buf("*Info*");
}

%!%+
%\function{gnuplot_help}
%\synopsis{Run gnoplots help feature on topic}
%\usage{ Void gnuplot_help(topic=Ask)}
%\description
%   Call gnuplot with "help topic" and display the help text in a window.
%   If the topic is not given, ask in the minibuffer.
%\notes
%   Only tested on UNIX
%\seealso{gnuplot_mode, gnuplot_info}
%!%-
define gnuplot_help() %([topic])
{
   variable topic;
   if (_NARGS)
     topic = ();
   else
     topic = read_mini("Gnuplot Help for: ", "", "");

   popup_buffer("*gnuplot help*");
   set_readonly(0);
   erase_buffer();
   insert("help " + topic + "\n");

   shell_cmd_on_region (Gnuplot_Command, 2); % output replaces input

   % do highlighting of keywords
   view_mode();
   use_syntax_table(mode);
   % primitive sort of linking
   define_blocal_var("help_for_word_hook", "gnuplot_help");
   if (is_defined("help_for_word_at_point"))
       set_buffer_hook("newline_indent_hook", "help_for_word_at_point");
   if (is_defined("help_2click_hook"))
     set_buffer_hook ( "mouse_2click", "help_2click_hook");
   fit_window(get_blocal("is_popup", 0));
}

% ---Run Gnuplot with the buffer/region as argument -------------------------

%!%+
%\function{gnuplot_run}
%\synopsis{Runs the gnuplot plotting program}
%\usage{Void gnuplot_run()}
%\description
% The \sfun{gnuplot_run} function starts gnuplot in a subshell. The region
% will be handed over as skript-file.
% if no region is defined, the whole buffer is taken instead. By default,
% a new buffer *gnuplot-output* is opened for the output (if there is any).
%!%-
define gnuplot_run()
{
   % variable cbuf = whatbuf();
   shell_cmd_on_region(Gnuplot_Command, "*gnuplot-output*");
   recenter(window_info('r'));
   % pop2buf(cbuf);
}

%!%+
%\function{gnuplot_shell}
%\synopsis{open an interactive gnuplot session in the current buffer }
%\usage{Void gnuplot_shell()}
%\description
%   This command calls ishell_mode with gnuplot as argument
%\seealso{ishell, ishell_mode}
%!%-
public define gnuplot_shell()
{
   ishell_mode(Gnuplot_Command);
}

%!%+
%\function{gnuplot_plot}
%\synopsis{Plots a gnuplot skript to the display}
%\usage{Void gnuplot_plot(hardcopy=0)}
%\description
% The \sfun{gnuplot_plot} function uses gnuplot to plot a skript to
% gnuplots default display. To achive this, the buffer is copied to a temporal
% buffer and the lines
%    set terminal ...
%    set output ...
% are deleted before invocation of gnuplot_run.
% If the optional argument hardcopy is non-zero, the plot
% will be printed: The terminal defined in the variable
% "Gnuplot_Print_Terminal" will be used and the output file has the
% same basename as the skript and the extension "Gnuplot_Output_Extension",
% overriding the values in the skript (actually, you will be asked for the
% output filename with the above default).
% If you want other output options either change the custom variables or set
% terminal and output in the skript and use \sfun{gnuplot_run}
%\seealso{gnuplot_mode, gnuplot_run, Gnuplot_Print_Terminal, Gnuplot_Output_Extension}
%!%-
define gnuplot_plot () % (hardcopy = 0)
{
   variable hardcopy = 0;
   if (_NARGS)
     hardcopy = ();
   variable buf = whatbuf();
   variable file_exists = 0;
   variable output_name;
   if (hardcopy) do
     {
	output_name = read_with_completion("Output file:",
	   "", path_sans_extname(buf)+Gnuplot_Output_Extension, 'f');
	if (file_status(output_name) == 1)
	  file_exists = not(get_y_or_n("File exists, overwrite?"));
	else
	  file_exists = 0;
     }
   while (file_exists);

   % copy to temporal buffer and delete set terminal and set output
   sw2buf(tmp_buf);
   erase_buffer();
   insbuf (buf);
   bob;
   if (bol_fsearch("set terminal"))
     call("kill_line");
   bob;
   if (bol_fsearch("set output"))
     call("kill_line");

   if (hardcopy)
     {  insert ("set terminal " + Gnuplot_Print_Terminal + "\n");
	insert ("set output '" + output_name + "'\n");
     }
   % run gnuplot
   shell_cmd_on_region(Gnuplot_Command, -1); % ignore output

   % clean up
   sw2buf(tmp_buf);
   set_buffer_modified_flag(0); % so delbuf doesnot ask whether to save first
   delbuf(tmp_buf);
   if (hardcopy)
     flush ("Plot written to " + output_name);
}

%!%+
%\function{gnuplot_print}
%\synopsis{Prints a gnuplot skript}
%\usage{Void gnuplot_print()}
%\description
% Run the buffer/region. The terminal is set to
% "Gnuplot_Print_Terminal", the output file has the same
% basename as the skript and the extension "Gnuplot_Output_Extension",
% overriding the values in the skript.
% If you want other output options either change these variables or set
% terminal and output in the skript and use \sfun{gnuplot_run}.
%\seealso{gnuplot_mode, gnuplot_run, gnuplot_plot, Gnuplot_Print_Terminal, Gnuplot_Output_Extension}
%!%-
define gnuplot_print()
{
   gnuplot_plot (1);
}

%!%+
%\function{gnuplot_get_defaults}
%\synopsis{opens a new buffer with the default values of gnuplot}
%\usage{Void gnuplot_get_defaults()}
%\description
%   opens a new buffer *gnuplot_defaults* with the default values
%   as returned by a run of gnuplot's save command.
%   Good to see what options there are.
%!%-
define gnuplot_get_defaults()
{
   variable buf = whatbuf;
   variable gnuplot_defaults_file= make_tmp_file("gp_defaults");
   variable tmp_buf = make_tmp_buffer_name ("*gnuplot-tmp*");
   variable flags; % for setbuf_info

   % copy to temporal buffer and delete set terminal and set output
   sw2buf( tmp_buf );
   insert ("save \"" + gnuplot_defaults_file + "\"");

   % run gnuplot, ignore output
   shell_cmd_on_region (Gnuplot_Command, -1);

   % clean up
   set_buffer_modified_flag (0); % so delbuf doesnot ask whether to save first
   delbuf (tmp_buf);

   () = find_file (gnuplot_defaults_file);
   () = delete_file (gnuplot_defaults_file);

   % rename_buffer("*gnuplot-defaults*"); % set also file and dir to ""
   (,,, flags) = getbuf_info ();
   setbuf_info ("", "","*gnuplot-defaults*", flags);
}

% * function that removes all default values from the script:
%      insert default file to buffer,
%      del_dup_lines_unsorted () from Marco Mahnics mmutils
define gnuplot_strip_defaults ()
{
   variable buf = whatbuf;
   variable line = Null_String;
   push_spot ();
   trim_buffer ();         % trim both to make them compatible
   %get default values
   gnuplot_get_defaults ();
   trim_buffer ();
   bob ();
   do
     {
      bol; push_mark_eol;  % mark line
      line = bufsubstr ();
	!if (line == Null_String) {
	   setbuf(buf);
	   bob;
	   % regexp does not work if line contains special characters
	   % if (re_fsearch ("^" + line + "$"))
	   if (bol_fsearch (line))
	     {
		right(strlen(line));
		if (eolp)
		  delete_line ();
	     }
	   setbuf("*gnuplot-defaults*");
	}
     }
   while (down_1);
   set_buffer_modified_flag(0); % so delbuf doesnot ask whether to save first
   delbuf(whatbuf);
   sw2buf(buf);
   pop_spot();
}

% --- Create and initialize the syntax tables.
create_syntax_table (mode);
define_syntax ("#", "", '%', mode);             % Comments
define_syntax ("([{", ")]}", '(', mode);        % Delimiters
define_syntax ("0-9a-zA-Z", 'w', mode);         % Words
define_syntax ("-+0-9.", '0', mode);            % Numbers
define_syntax (",", ',', mode);                 % Delimiters
define_syntax (";", ',', mode);                 % Delimiters
define_syntax ("-+/&*=<>|!~^", '+', mode);      % Operators
define_syntax ('\'', '"', mode);                % Strings
define_syntax ('\"', '"', mode);                % Strings

set_syntax_flags (mode, 0);

%
% Type 0 keywords
%
() = define_keywords_n(mode, "allbarkeyvarvia", 3, 0);
() = define_keywords_n(mode, "axesclipdatagridsizethruticsviewwithzero", 4, 0);
() = define_keywords_n(mode,
"arrowdummyeveryindexlabelnokeypolarstyletitleusingxdataxticsydatayticszdataztics",
5, 0);
() = define_keywords_n(mode,
"anglesbinaryborderclabelformatlocalemarginmatrixmxticsmyticsmzticsnoclipnogridoriginoutputrrangesmoothtrangeurangevrangex2datax2ticsxdticsxlabelxmticsxrangey2datay2ticsydticsylabelymticsyrangezdticszlabelzmticszrange",
6, 0);
() = define_keywords_n(mode,
"bmargincontourdgrid3dlmarginmappingmissingmx2ticsmy2ticsnoarrownolabelnopolarnotitlenoxticsnoyticsnozticsoffsetsrmarginsamplessurfacetimefmttmarginversionx2dticsx2labelx2mticsx2rangey2dticsy2labely2mticsy2range",
7, 0);
() = define_keywords_n(mode,
"boxwidthencodingfunctionhidden3dlogscalenobordernoclabelnomxticsnomyticsnomzticsnox2ticsnoxdticsnoxmticsnoy2ticsnoydticsnoymticsnozdticsnozmticsterminalticscalezeroaxis",
8, 0);
() = define_keywords_n(mode,
"autoscalecntrparamfunctionslinestylemultiplotnocontournodgrid3dnomx2ticsnomy2ticsnosurfacenox2dticsnox2mticsnoy2dticsnoy2mticspointsizeticsleveltimestampvariablesxzeroaxisyzeroaxis",
9, 0);
() = define_keywords_n(mode,
"isosamplesnohidden3dnologscalenozeroaxisparametricx2zeroaxisy2zeroaxis",
10, 0);
() = define_keywords_n(mode,
"noautoscalenolinestylenomultiplotnotimestampnoxzeroaxisnoyzeroaxis", 11, 0);
() = define_keywords_n(mode, "noparametricnox2zeroaxisnoy2zeroaxis", 12, 0);

%
% Type 1 keywords
%
() = define_keywords_n(mode, "!", 1, 1);
() = define_keywords_n(mode, "cdif", 2, 1);
() = define_keywords_n(mode, "fitpwdset", 3, 1);
() = define_keywords_n(mode, "callexithelploadplotquitsaveshowtest", 4, 1);
() = define_keywords_n(mode, "clearprintpauseresetshellsplot", 5, 1);
() = define_keywords_n(mode, "replotrereadupdate", 6, 1);

% --- the mode dependend menu
static define gnuplot_menu(menu)
{
   menu_append_item (menu, "&Gnuplot Region/Buffer", "gnuplot_run");
   menu_append_item (menu, "Gnuplot &Shell", "gnuplot_shell");
   menu_append_item (menu, "&Display Plot", "gnuplot_plot");
   menu_append_item (menu, "&Print Plot", "gnuplot_print");
   menu_append_item (menu, "&New File(defaults)", "gnuplot_get_defaults");
   menu_append_item (menu, "&Strip Defaults", "gnuplot_strip_defaults");
   menu_append_item (menu, "Gnuplot &Help", "gnuplot_help");
}

% --- now define the mode ---------------------------------------------
public define gnuplot_mode ()
{
   set_mode(mode, 4);
   use_syntax_table(mode);
   use_keymap(mode);
   mode_set_mode_info(mode, "fold_info", "#{{{\r#}}}\r\r");
   mode_set_mode_info(mode, "init_mode_menu", &gnuplot_menu);
   define_blocal_var("help_for_word_hook", &gnuplot_help);
   define_blocal_var("run_buffer_hook", &gnuplot_run);
   run_mode_hooks("gnuplot_mode_hook");
}

provide(mode);

% ------ begin of gnuplot.sl ---------------------------------------------
%  a highlighting and editing mode for the Gnuplot plotting program
%  by Michele Dondi <bik.mido@tiscalinet.it>
%  extended by Guenter Milde <g.milde@physik.tu-dresden.de>
%  
%  version 1.0 gnuplot_run: run gnuplot on skripts
%              gnuplot_shell: interactive use
%              invoce info(gnuplot) as online help
%              comments with comments.sl
%  version 1.1 interface for gnuplot online help (on UNIX)
%  	       keybindings via definekey_reserved
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
%    local_setkey ("gnuplot_help",  "^H",     $2);  % Help
%    local_setkey ("gnuplot_run",   "^[^M",   $2);  % Alt-Return: Run buffer/region
%    local_setkey ("gnuplot_print", Key_F9,   $2);  % Print plot
%    local_setkey ("gnuplot_print", "^P",     $2);  % Print plot
%    local_setkey ("gnuplot_plot",  "^D",     $2);  % Display plot
% }



% requirements
require("comments");  % from jed's standard library
autoload ("do_shell_cmd_on_region", "ishell.sl");
autoload ("ishell_mode", "ishell.sl");
!if (is_defined ("info_find_dir")) 
  () = evalfile("info.sl");       % has no provides command :-(

    
% --- user adjustable settings ------------------------------------

% -- Variables
static variable modename = "Gnuplot";
% As printout I prefer *.eps files to include in LaTeX
custom_variable ("Gnuplot_Print_Terminal",  "postscript eps enhanced");
custom_variable ("Gnuplot_Output_Extension", ".eps");
% Command for running gnuplot. You might need to add a path or switches.
custom_variable ("Gnuplot_Command", "gnuplot -persist");

% do commenting with comments.sl
set_comment_info (modename, "# ", "", 7);


% --- Keybindings 
!if (is_defined ("Key_F1")) () = evalfile ("keydefs");

$2 = "GnuplotMap";
!if (keymap_p ($2)) make_keymap ($2);
definekey_reserved ("gnuplot_help",  "H",     $2);  % Help
definekey_reserved ("gnuplot_run",   "R",   $2);  % Alt-Return: Run buffer/region
definekey_reserved ("gnuplot_print", "P",     $2);  % Print plot
definekey_reserved ("gnuplot_plot",  "D",     $2);  % Display plot

% --- end of user adjustable stuff: from here on everything should be ok

% --- Create and initialize the syntax tables.
$1 = modename;
create_syntax_table ($1);
define_syntax ("#", "", '%', $1);             % Comments
define_syntax ("([{", ")]}", '(', $1);        % Delimiters
define_syntax ("0-9a-zA-Z", 'w', $1);         % Words
define_syntax ("-+0-9.", '0', $1);          % Numbers - too messy
define_syntax (",", ',', $1);                 % Delimiters
define_syntax (";", ',', $1);
define_syntax ("-+/&*=<>|!~^", '+', $1);    % Operators - too messy
define_syntax ('\'', '"', $1);                % Strings
define_syntax ('\"', '"', $1);

set_syntax_flags ($1, 0);

%
% Type 0 keywords
%
() = define_keywords_n($1, "allbarkeyvarvia", 3, 0);
() = define_keywords_n($1, "axesclipdatagridsizethruticsviewwithzero", 4, 0);
() = define_keywords_n($1, 
"arrowdummyeveryindexlabelnokeypolarstyletitleusingxdataxticsydatayticszdataztics", 
5, 0);
() = define_keywords_n($1, 
"anglesbinaryborderclabelformatlocalemarginmatrixmxticsmyticsmzticsnoclipnogridoriginoutputrrangesmoothtrangeurangevrangex2datax2ticsxdticsxlabelxmticsxrangey2datay2ticsydticsylabelymticsyrangezdticszlabelzmticszrange", 
6, 0);
() = define_keywords_n($1, 
"bmargincontourdgrid3dlmarginmappingmissingmx2ticsmy2ticsnoarrownolabelnopolarnotitlenoxticsnoyticsnozticsoffsetsrmarginsamplessurfacetimefmttmarginversionx2dticsx2labelx2mticsx2rangey2dticsy2labely2mticsy2range", 
7, 0);
() = define_keywords_n($1, 
"boxwidthencodingfunctionhidden3dlogscalenobordernoclabelnomxticsnomyticsnomzticsnox2ticsnoxdticsnoxmticsnoy2ticsnoydticsnoymticsnozdticsnozmticsterminalticscalezeroaxis", 
8, 0);
() = define_keywords_n($1, 
"autoscalecntrparamfunctionslinestylemultiplotnocontournodgrid3dnomx2ticsnomy2ticsnosurfacenox2dticsnox2mticsnoy2dticsnoy2mticspointsizeticsleveltimestampvariablesxzeroaxisyzeroaxis", 
9, 0);
() = define_keywords_n($1, 
"isosamplesnohidden3dnologscalenozeroaxisparametricx2zeroaxisy2zeroaxis", 
10, 0);
() = define_keywords_n($1, 
"noautoscalenolinestylenomultiplotnotimestampnoxzeroaxisnoyzeroaxis", 11, 0);
() = define_keywords_n($1, "noparametricnox2zeroaxisnoy2zeroaxis", 12, 0);

%
% Type 1 keywords
%
() = define_keywords_n($1, "!", 1, 1);
() = define_keywords_n($1, "cdif", 2, 1);
() = define_keywords_n($1, "fitpwdset", 3, 1);
() = define_keywords_n($1, "callexithelploadplotquitsaveshowtest", 4, 1);
() = define_keywords_n($1, "clearprintpauseresetshellsplot", 5, 1);
() = define_keywords_n($1, "replotrereadupdate", 6, 1);

% --- the mode dependend menu

static define init_menu (menu)
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
define gnuplot_mode ()
{
   set_mode(modename, 4);
   use_syntax_table (modename);
   use_keymap ("GnuplotMap");
   mode_set_mode_info (modename, "fold_info", "#{{{\r#}}}\r\r");
   mode_set_mode_info (modename, "init_mode_menu", &init_menu);
   run_mode_hooks("gnuplot_mode_hook");
}


% --- help ------------------------------------

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
define gnuplot_help() %(topic=Ask)
{
   variable topic;
   if (_NARGS)
     topic = ();
   else
     topic = read_mini("Gnuplot Help for: ", "", "");
#ifndef UNIX
   return gnuplot_info(topic);
#endif   
   pop2buf("*gnuplot help*");
   set_readonly(0);
   erase_buffer();
   
   set_prefix_argument (1);      % insert output at point
   do_shell_cmd(sprintf("echo help %s | %s -", topic, Gnuplot_Command));

   gnuplot_mode();
   set_readonly(1);
   set_buffer_modified_flag(0);
   if (is_defined("help_2click_hook"))
     set_buffer_hook ( "mouse_2click", "help_2click_hook");
}

define gnuplot_help_for_word_hook(topic) {gnuplot_help(topic);}

% redefine help_prefix to include the gnuplot-help option
 
define gnuplot_help_prefix()
{
   variable c;
 variable gnuplot_help_for_help_string =
#ifdef VMS
 "-> Gnuplot:G Help:H Menu:? Info:I Apropos:A Key:K Where:W Fnct:F VMSHELP:M Var:V";
#elifdef IBMPC_SYSTEM
 "-> Gnuplot:G Help:H Menu:? Info:I Apropos:A Key:K Where:W Fnct:F Var:V Mem:M";
#else
 "-> Gnuplot:G Help:H Menu:? Info:I Apropos:A Key:K Where:W Fnct:F Var:V Man:M";
#endif  
  
   !if (input_pending(7)) flush (help_for_help_string);
   c = toupper (getkey());
   switch (c)
     { case  8 or case 'H': help (); }
     { case  'A' : apropos (); }
     { case  'I' : info_mode (); }
     { case  '?' : call ("select_menubar");}
     { case  'F' : describe_function ();}
     { case  'G' : gnuplot_help ();}
     { case  'V' : describe_variable ();}
     { case  'W' : where_is ();}
     { case  'C' or case 'K': showkey ();}
     { case  'M' :
#ifdef UNIX OS2
        unix_man();
#elifdef VMS
        vms_help ();
#elifdef MSDOS MSWINDOWS
        call("coreleft");
#endif
     }
     { beep(); clear_message ();}
} 
% ---Run Gnuplot with the buffer/region as argument -------------------------


%!%+
%\function{gnuplot_run}
%\synopsis{Runs the gnuplot plotting program}
%\usage{Void gnuplot_run ()}
%\description
% The \var{gnuplot_run} function starts gnuplot in a subshell. The region 
% will be handed over as skript-file.
% if no region is defined, the whole buffer is taken instead. By default, 
% a new buffer *gnuplot-output* is opened for the output (if there is any).
%!%-
public define gnuplot_run ()
{  
   do_shell_cmd_on_region (Gnuplot_Command);
   set_buffer_modified_flag (0); % so delbuf doesnot ask whether to save first
   % now we are in the "*shell-output*" buffer
   !if (bobp and eobp)  % if there is any output
     {
	pop2buf("*gnuplot-output*");
	eob;
	!if (bobp())
	  insert("   --------------------------------------------------\n\n");
	insbuf("*shell-output*");
	set_buffer_modified_flag (0);
     }
   delbuf("*shell-output*");
}

define gnuplot_execute_hook()
{
   gnuplot_run();
}

%!%+
%\function{gnuplot_shell}
%\synopsis{open an interactive gnuplot session in the current buffer }
%\usage{Void gnuplot_shell ()}
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
%\usage{gnuplot_plot ()}
%\description
% The \var{gnuplot_plot} function uses gnuplot to plot a skript to 
% gnuplots default display. To achive this, the buffer is copied to a temporal
% buffer and the lines set terminal ... and set output ... are deleted before
% invocation of gnuplot_run. If a nonzero prefix argument exists, the plot 
% will be printed: The terminal defined in the variable 
% "Gnuplot_Print_Terminal" will be used and the output file has the same 
% basename as the skript and the extension "Gnuplot_Output_Extension", 
% overriding the values in the skript. 
% If you want other output options either change these variables or set 
% terminal and output in the skript and use \var{gnuplot_run}
%!%-
public define gnuplot_plot () 
{  
   variable oldbuf = whatbuf;
   variable tmp_buffer = ("gnuplot_tmp");
   variable print = prefix_argument(0);
   variable file_exists = 0;
   variable Gnuplot_Output = path_sans_extname(whatbuf)
                             + Gnuplot_Output_Extension; 
   if (print) do
     {
	Gnuplot_Output = read_with_completion("Output file:", 
					      "", Gnuplot_Output, 'f');
	if (file_status(Gnuplot_Output) == 1)
	  file_exists = not(get_y_or_n("File exists, overwrite?"));
	else
	  file_exists = 0;
     }
   while (file_exists);
   
   % copy to temporal buffer and delete set terminal and set output
   sw2buf( tmp_buffer );
   erase_buffer();
   insbuf (oldbuf);
   bob; 
   if (bol_fsearch("set terminal"))
     call("kill_line");
   bob; 
   if (bol_fsearch("set output"))
     call("kill_line");
   
   if (print)
     {  insert ("set terminal " + Gnuplot_Print_Terminal + "\n");
	insert ("set output '" + Gnuplot_Output + "'\n"); 
     }   
   % run gnuplot
   set_prefix_argument(2);       % ignore output
   do_shell_cmd_on_region(Gnuplot_Command);

   % clean up
   set_buffer_modified_flag(0); % so delbuf doesnot ask whether to save first
   delbuf(tmp_buffer);
   if (print)
     flush ("Plot written to " + Gnuplot_Output);
} % end of gnuplot_plot ()

%!%+
%\function{gnuplot_print}
%\synopsis{Prints a gnuplot skript}
%\usage{Void gnuplot_print ()}
%\description
% The \var{gnuplot_print} function calles \var{gnuplot_plot} with a 
% prefix argument, i.e. the plot 
% will be printed: The terminal defined in the variable 
% "Gnuplot_Print_Terminal" will be used and the output file has the same 
% basename as the skript and the extension "Gnuplot_Output_Extension", 
% overriding the values in the skript. 
% If you want other output options either change these variables or set 
% terminal and output in the skript and use \var{gnuplot_run}.
%!%-
public define gnuplot_print ()
{
   set_prefix_argument(1);
   gnuplot_plot ();
}

%!%+
%\function{gnuplot_get_defaults}
%\synopsis{opens a new buffer with the default values of gnuplot}
%\usage{Void gnuplot_get_defaults ()}
%\description
%   opens a new buffer *gnuplot_defaults* with the default values 
%   as returned by a run of gnuplot's save command.
%   Good to see what options there are.
%!%-
define gnuplot_get_defaults ()
{
   variable oldbuf = whatbuf;
   variable gnuplot_defaults_file= make_tmp_file("gplotdef");
   variable tmp_buffer = make_tmp_buffer_name ("*gnuplot-tmp*");
   variable flags; % for setbuf_info

   % copy to temporal buffer and delete set terminal and set output
   sw2buf( tmp_buffer );
   insert ("save \"" + gnuplot_defaults_file + "\"");

   % run gnuplot
   set_prefix_argument(2);       % ignore output
   do_shell_cmd_on_region (Gnuplot_Command);
   
   % clean up
   set_buffer_modified_flag (0); % so delbuf doesnot ask whether to save first
   delbuf (tmp_buffer);

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
   variable oldbuf = whatbuf;
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
	   setbuf(oldbuf);
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
   sw2buf(oldbuf);
   pop_spot();
}

% --- end of gnuplot.sl ---------------------------------------- 

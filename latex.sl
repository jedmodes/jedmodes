% File:          latex.sl      -*- SLang -*-
%
% Authors:       J\o rgen Larsen <jl@dirac.ruc.dk>,
%                Guido Gonzato <ggonza@tin.it>
%
% Description:   a souped-up latex mode that aims at making LaTeX a
%                bit easier to use.
%
% Version:       0.9.12.
%
% Last updated:	 18 April 2001

% -----

% TO DO: implement "texify"

static variable LaTeX_Mode_Name = "LaTeX";

% required stuff
() = evalfile ("texcom");
autoload ("latex_toggle_math_mode", "ltx-math");
autoload ("latex_insert_math", "ltx-math");
autoload ("latex_math_mode", "ltx-math");

WRAP_INDENTS = 1; % you really want this

% set this variable to 0 if you don't want indented environments
custom_variable ("LaTeX_Indent", 2);
custom_variable ("LaTeX_Article_Default_Options", "a4paper,12pt");
custom_variable ("LaTeX_Book_Default_Options",    "twoside,11pt");
custom_variable ("LaTeX_Letter_Default_Options",  "a4paper,12pt");
custom_variable ("LaTeX_Report_Default_Options",  "twoside,12pt");
custom_variable ("LaTeX_Slides_Default_Options",  "a4paper,landscape");
custom_variable ("LaTeX_Default_Language", "english"); % for Babel

static variable TRUE         = 1;
static variable FALSE        = 0;
static variable NO_PUSH_SPOT = FALSE;
static variable PUSH_SPOT    = TRUE;
static variable NO_POP_SPOT  = FALSE;
static variable POP_SPOT     = TRUE;
static variable ITEM_LABEL   = FALSE;

% DOS/Windows users: make sure helper programs are in the PATH
#ifdef IBMPC_SYSTEM
custom_variable ("LaTeX_Compose_Command", "latex -interaction=nonstopmode");
custom_variable ("LaTeX_View_Dvi_Command", "yap");
custom_variable ("LaTeX_View_Ps_Command",  "gsview32");
custom_variable ("LaTeX_Dvips_Command", "dvips");
custom_variable ("LaTeX_Bibtex_Command", "bibtex");
custom_variable ("LaTeX_Makeindex_Command", "makeindex");
#else
custom_variable ("LaTeX_Compose_Command",  "latex -interaction=nonstopmode");
custom_variable ("LaTeX_View_Dvi_Command", "xdvi");
custom_variable ("LaTeX_View_Ps_Command",  "gv");
custom_variable ("LaTeX_Dvips_Command", "dvips");
custom_variable ("LaTeX_Bibtex_Command", "bibtex");
custom_variable ("LaTeX_Makeindex_Command", "makeindex");
custom_variable ("LaTeX_Psdev", "lpr");  % ps-output device
#endif

% if non-zero, load support for IMFUFA LaTeX
custom_variable ("LaTeX_Imfufa_Support", 0);
% if non-zero, report Warnings (as well as Errors)
custom_variable ("LaTeX_Warnings", 1);

%  Load some other modules:
if (LaTeX_Imfufa_Support)
  () = evalfile ("imflatex"); % load the IMFUFA LaTeX support

#ifdef UNIX
% Fix preview variables:
LaTeX_View_Dvi_Command = LaTeX_View_Dvi_Command + " >/dev/null 2>&1";
LaTeX_View_Ps_Command  = LaTeX_View_Ps_Command  + " >/dev/null 2>&1";
LaTeX_Dvips_Command   = LaTeX_Dvips_Command   + " >/dev/null 2>&1";
#endif

% --- J\o rgen's routines ---

%% ---------------------------------------------------------
%% Defining the LaTeX log parser:

static variable Out_Buf = "*LaTeX-parse*";
static variable Current_Line, Log_Pipe;

% read a line from `Log_Pipe' into `Current_Line' and trim it
% (if the line has leading spaces then keep one!);
% return length of resulting string
static define read_trimmed_line ()
{
   if (-1 == fgets (&Current_Line, Log_Pipe)) return -1;

   if (strncmp (Current_Line, "  ", 2))
     Current_Line = strtrim (Current_Line);
   else
     Current_Line = " " + strtrim (Current_Line);

   return (strlen (Current_Line));
}

% `Current_Line' becomes the next non-empty line:
static define skip_empty_lines ()
{
   variable nr;
   forever
     {
	nr = read_trimmed_line ();
	if (nr) break;
     }
   nr; % return length of new `Current_Line', or -1 at eof.
}

% Write a line of the form FILENAME(lno)MESSAGE
% (the filename is taken from the stack).
static define write_msg (lno,msg)
{
   dup ();
   variable fn = ();
   insert (strcat (fn, "(", lno, ")", msg,"\n"));
}

% and tell the compile module how to parse these messages:
compile_add_compiler ("jltex", "^\\(.+\\)(\\(\\d+\\)");
compile_select_compiler ("jltex");

% Test if the string `str' has a substring matching the regular
% expression `pat' and starting exactly at position `pos' :
static define string_match_at_pos (str,pat,pos)
{
   return (1 == string_match (str,pat,pos));
}

%  Here are two auxiliary functions used in `error_line' to handle
%  certain emergency cases:

static define emergency_msg ()
{
   % When this function is being used there need not be a filename
   % on the stack, therefore we have to put something on the stack first.
   "TEX-ERROR";
   write_msg ("", Current_Line);
   pop ();
}

static define emergency_case (match)
{
   if (strncmp (Current_Line, match, 15)) return 0; else
     {
	emergency_msg ();
	return 1;
     }
}

%  The function `error_line' test whether `Current_Line' is a line with
%  an Error message.
%  In that case an error message is issued and the value 1 is returned.
%  Otherwise the value 0 is returned.
static define error_line ()
{
    % Error message lines always start with "!"
   if ('!' != Current_Line[0]) return 0;

   % Test for certain emergency cases:
   if (emergency_case ("! I can't find file")) return 1;
   if (emergency_case ("! Emergency stop")) return 1;
   if (emergency_case ("! File ended while")) return 1;

   variable not_eof, msg = "";

   do % keep reading until we find the line with the line number
     {
	msg += Current_Line;
	not_eof = (-1 < read_trimmed_line ());
     }
   while (not_eof and (strncmp (Current_Line, "l.", 2)));

   if (not_eof)
     {
	variable lno = "", pos,len;
	if (string_match_at_pos (Current_Line, "\\([0-9]+\\)", 3))
	  {
	     (pos,len) = string_match_nth (1);
	     lno = substr (Current_Line, pos+1, len);
	     msg += Current_Line[[pos+len:]];
	  }
	write_msg (lno,msg);
     }
   else emergency_msg ();

   return 1;
}

%  The function `warning_line' test whether `Current_Line' is a line with
%  a Warning message.
%  In that case an error message is issued and the value 1 is returned.
%  Otherwise the value 0 is returned.
static define warning_line ()
{
   % warning lines  begin with "LaTeX ... Warning:" or "Package ... Warning:"
   !if (orelse
       {string_match_at_pos (Current_Line,
			     "^LaTeX [0-9A-Za-z]*[ ]?Warning:", 1)}
       {string_match_at_pos (Current_Line,
			     "^Package [0-9A-Za-z]*[ ]?Warning:", 1)})
    return 0;

   !if (LaTeX_Warnings) return 1;

   variable msg = "", lno = "", pos, len;

   % A Warning consists of one or more non-empty lines followed by an
   % empty line. If the warning refers to a line number, then this number
   % comes right before the dot which finishes the error message.
   % Apparently TeX tries to format its output into lines of max.
   % length 80, and while doing that it doesn't hesitate to break the
   % line right before the  concluding dot (!)
   do
     {
	msg += Current_Line;
	if (string_match (msg, "\\([0-9]+\\)\\.$", 1))
	  {
	     (pos,len) = string_match_nth (1);
	     lno = substr (msg, pos+1, len);
	  }
     } while (0 < read_trimmed_line ());

   write_msg (lno, msg);
   return 1;
}

%  The function `filename_line' test whether `Current_Line' is a line with
%  information about TeX opening or closing an input file.
%
%  When a file is opened, the file name is pushed onto the stack,
%  and when a file is closed, its name is removed from the stack.
static define filename_line ()
{
   % if the line doesn't start with one of the four characters ()[]
   % then it is of no interest for `filename_line', but maybe for
   % `error_line' or `warning_line'.  Hence exit and return 0.
   !if (string_match_at_pos (Current_Line, "[][()]", 1)) return 0;

   % exit if the line begins with "[]" :
   !if (strncmp (Current_Line, "[]", 2)) return 1;

   variable q, p = 0;
   Current_Line += " "; % to make things easier ...

   while (p < strlen (Current_Line))
     {
	if ('(' == Current_Line[p]) % opening of a file
	    {
	       % position after the end of the file name:
	       q = p + string_match (Current_Line, "[ ()]", p+2);
	       % push filename onto the stack (unless the file is being
	       % closed again in the same line):
	       !if (')' == Current_Line[q]) Current_Line[[p+1:q-1]];
	       p = q;
	    }
	else
	if (')' == Current_Line[p]) pop (); % remove filename from stack
	p++;
     }
   return 1;
}

% The LaTeX log parser
static define latex_parse_log ()
{
   pop2buf (Out_Buf);
   erase_buffer ();

   while (0 < skip_empty_lines ())
     () = orelse
            {filename_line ()}
            {error_line ()}
            {warning_line ()};

   compile_parse_buf ();
  if (0 == down (1)) {
    call ("other_window");
    call ("one_window");
  }
    
}

%% (end of log parser section)
%% --------------------------------------------------------

%% ------------------------------------------------------
%%  The main file mechanism:

static variable LaTeX_Mainfile = "";

% don't put a `static' in front of this `define' :
define latex_set_mainfile ();  % preliminary definition

% `latex_read_mainfile' is basically `read_file (LaTeX_Mainfile)' .
% It also changes the default directory to the directory of the mainfile
% in order that the various tex programs (and the error parsing functions)
% can find their input files.
static define latex_read_mainfile ()
{
   if (strlen (LaTeX_Mainfile))
     {
	variable rv = read_file (LaTeX_Mainfile);
	message (strcat ("Main file: ", LaTeX_Mainfile));
        if (change_default_dir (path_dirname (buffer_filename ())))
	 error ("Cannot chdir !");
	return rv;
     }
   else latex_set_mainfile ();
}

% `latex_set_mainfile'  sets/resets the value of `LaTeX_Mainfile' .
public define latex_set_mainfile ()
{
   if (strlen (LaTeX_Mainfile)) () = read_file (LaTeX_Mainfile);
   else
     {
	LaTeX_Mainfile = read_file_from_mini ("Give the file a name:");
	() = write_buffer (LaTeX_Mainfile);
      }

   if (get_y_or_n (strcat ("Current mainfile is ",
			   path_basename (LaTeX_Mainfile), ". Change")))
	LaTeX_Mainfile =
    read_with_completion ("Set main file:", "",
			  path_basename (buffer_filename ()), 'f');
   !if (latex_read_mainfile ()) error ("Non-existing file " + LaTeX_Mainfile);
}

%% (end of main file section)
%% ----------------------------------------------------------------

%% ------------------------------------------------------------------
%% The public functions that run various applications on the main file:

% The function `latex_compose' runs LaTeX on the main file
% and then calls the log parser.
% The most elegant way to code `latex_compose' is based on the
% `popen' function.  However, in the DOS versions of jed (i.e.
% jed386.exe and jed.exe) `popen' is not defined, so we have to
% treat that situation differently.
public define latex_compose ()
{
   % Save all modified buffers.
   if (_jed_version < 9912) call ("save_buffers"); else save_buffers ();

   % Read the mainfile,
   !if (latex_read_mainfile ())
     error ("Non-existing file " + LaTeX_Mainfile + " - cannot run LaTeX.");
   % and get its basename. This must be done immediately after reading
   % the mainfile:
   variable fn = path_basename (whatbuf ());
   !if (strlen (fn)) error ("There is no file associated with the buffer.");

   flush ("Running LaTeX ... [" + fn + "]");

#ifdef IBMPC_SYSTEM
   variable tmp = "_jltex_.log";
   () = system (strcat (LaTeX_Compose_Command, " ", fn, " > ", tmp));

   flush ("Analyzing the log ... [" + fn + "]");
   Log_Pipe = fopen (tmp, "r");
   if (Log_Pipe == NULL) error ("Cannot open " + tmp);

   latex_parse_log ();
   () = fclose (Log_Pipe);
#else
   Log_Pipe = popen (strcat (LaTeX_Compose_Command, " ", fn), "r");
   if (Log_Pipe == NULL) error ("Cannot open pipe");

   flush ("Running LaTeX and analyzing the log ... [" + fn+ "]");
   latex_parse_log ();
   () = pclose (Log_Pipe);
#endif

   flush ("LaTeX done [" + fn + "]");
}

public define latex_preview ()
{
   !if (latex_read_mainfile ())
     error ("Main-file " + LaTeX_Mainfile + " does not exist");

   variable fn = path_sans_extname (whatbuf ()) + ".dvi";
   if (1 != file_status (fn)) error ("No file "+fn);
   flush ("Viewing " + fn);

#ifdef MSDOS
   () = system ("cls");
   () = system (strcat (LaTeX_View_Dvi_Command, " ", fn));
   call ("redraw");
#else
#ifdef WIN32
   compile (strcat (LaTeX_View_Dvi_Command, " ", fn));
#else
   () = system (strcat (LaTeX_View_Dvi_Command, " ", fn, " &"));
#endif
#endif

   flush ("Viewer launched.");
}

public define latex_convert_dvi ()
{
   !if (latex_read_mainfile ())
    verror ("Non-existing file - cannot run %s", LaTeX_Dvips_Command);

   variable fn = path_sans_extname (whatbuf ());
   flush ("Converting " + fn);

   compile (strcat (LaTeX_Dvips_Command, " ", fn));
   flush ("Done.");
}

public define latex_gsview ()
{
   !if (latex_read_mainfile ())
    error ("Main-file " + LaTeX_Mainfile + " does not exist");

   variable fn = path_sans_extname (whatbuf ());

   if ((1 != file_status (fn + ".ps")) and (1 != file_status (fn + ".dvi")))
     error ("No file "+fn + ".dvi");
   flush ("Viewing " + fn);

#ifdef IBMPC_SYSTEM
   compile (strcat (LaTeX_Dvips_Command, " ", fn));
   () = system (strcat (LaTeX_View_Ps_Command, " ", fn, ".ps"));
#else
  () = system (strcat (LaTeX_Dvips_Command, " ", fn, "; ",
		   LaTeX_View_Ps_Command, " ", fn, " &"));
#endif

   flush ("Viewer launched.");
}

public define latex_psprint ()
{
   !if (latex_read_mainfile ())
    error ("Non-existing file - cannot run the ps printer");

   variable fn = path_sans_extname (whatbuf ());
   flush ("Printing " + fn);

#ifdef UNIX
   () = system (strcat (LaTeX_Dvips_Command, " -f ", fn, " |", LaTeX_Psdev));
#else
#ifndef IBMPC_SYSTEM
   () = compile (strcat (LaTeX_Dvips_Command, " -o ", LaTeX_Psdev, " ", fn));
#endif
#endif

   flush ("Done (printing).");
}

public define latex_bibtex ()
{
   !if (latex_read_mainfile ())
    error ("Non-existing file - cannot run BibTeX");

   variable fn = path_sans_extname (whatbuf ());
   flush ("BibTeX'ing " + fn);

   compile (strcat (LaTeX_Bibtex_Command, " ", fn));
   flush ("Done.");
}

public define latex_makeindex ()
{
   !if (latex_read_mainfile ())
    error ("Non-existing file - cannot run makeindex");

   variable fn = path_sans_extname (whatbuf ());
   flush ("Processing the index...");

   compile (strcat (LaTeX_Makeindex_Command, " ", fn));
   flush ("Done.");
}

%%--------------------------------------------------

static define menu_append_item_if (menu, name, fun, s)
{
  if (strlen (s))
    menu_append_item (menu, name, fun);
}

% --- Guido's routines ---

static define latex_insert_pair_around_region (left, right)
{
  check_region (1);
  exchange_point_and_mark ();
  insert (left);
  exchange_point_and_mark ();
  insert (right);
  pop_spot ();
  pop_mark_0 ();
}

define latex_insert_tags (tag1, tag2, do_push_spot, do_pop_spot)
{
  % if a region is defined, insert the tags around it
  if (markp () ) {
    latex_insert_pair_around_region (tag1, tag2);
    return;
  }
  insert (tag1);
  if (do_push_spot)
    push_spot ();
  insert (tag2);
  if (do_pop_spot)
    pop_spot ();
}

% utility routines

define latex_begin_end (param1, param2, do_push_spot, do_pop_spot)
{
  variable col = what_column () - 1;
  variable env1, env2;

  env1 = sprintf ("\\begin{%s}%s\n", param1, param2);
  env2 = sprintf ("\\end{%s}\n", param1);
  if (markp () ) {
    latex_insert_pair_around_region (env1, env2);
    return;
  }
  insert (env1);
  insert_spaces (col + LaTeX_Indent);
  if (do_push_spot)
    push_spot ();
  insert ("\n");
  insert_spaces (col);
  insert (env2);
  if (do_pop_spot)
    pop_spot ();
}

define latex_cmd (cmd, do_push_spot)
{
  variable tmp;

  tmp = sprintf ("\\%s{", cmd);
  if (markp () ) {
    latex_insert_pair_around_region (tmp, "}");
    return;
  }
  insert (tmp);
  if (do_push_spot)
    push_spot ();
  insert ("}");
  if (do_push_spot)
    pop_spot ();
}

static define latex_cmd_with_arg (cmd, arg, do_push_spot)
{
  variable tmp, strarg;

  !if (strlen (arg))
    strarg = "";
  else
    strarg = "{" + arg;

  tmp = sprintf ("\\%s%s", cmd, strarg);
  if (markp () ) {
    latex_insert_pair_around_region (tmp, "}");
    return;
  }
  insert (tmp);
  if (do_push_spot)
    push_spot ();
  !if (strlen (arg))
    insert ("}");
  if (do_push_spot)
    pop_spot ();
}

define latex_insert (cmd)
{ vinsert ("\\%s ", cmd); }

define latex_insert_nospace (cmd)
{ vinsert ("\\%s", cmd); }

define latex_insert_newline (cmd)
{ vinsert ("\\%s\n", cmd); }

% let's start

% Templates

define latex_article ()
{
  vinsert ("\\documentclass[%s]{article}\n\n",
	   LaTeX_Article_Default_Options);
  insert ("\\begin{document}\n\n");
  insert ("\\title{");
  push_spot ();
  insert ("}\n\n");
  insert ("\\author{}\n\n");
  insert ("\\date{}\n\n");
  insert ("\\maketitle\n\n");
  insert ("\\begin{abstract}\n");
  insert ("\\end{abstract}\n\n");
  insert ("\\tableofcontents\n");
  insert ("\\listoftables\n");
  insert ("\\listoffigures\n\n");
  insert ("\\section{}\n\n");
  insert ("\\end{document}");
  pop_spot ();
}

define latex_book ()
{
  vinsert ("\\documentclass[%s]{book}\n\n",
	   LaTeX_Book_Default_Options);
  insert ("\\begin{document}\n\n");
  insert ("\\frontmatter\n");
  insert ("\\title{");
  push_spot ();
  insert ("}\n\n");
  insert ("\\author{}\n\n");
  insert ("\\date{}\n\n");
  insert ("\\maketitle\n\n");
  insert ("\\tableofcontents\n");
  insert ("\\listoftables\n");
  insert ("\\listoffigures\n\n");
  insert ("\\mainmatter\n\n");
  insert ("\\part{}\n\n");
  insert ("\\chapter{}\n\n");
  insert ("\\section{}\n\n");
  insert ("\\end{document}");
  pop_spot ();
}

define latex_letter ()
{
  vinsert ("\\documentclass[%s]{letter}\n\n",
	   LaTeX_Letter_Default_Options);
  insert ("\\begin{document}\n\n");
  insert ("\\address{(return address)}\n");
  insert ("\\signature{");
  push_spot ();
  insert ("}\n");
  insert ("\\begin{letter}{(recipient's address)}\n");
  insert ("\\opening{}\n\n");
  insert ("\\closing{}\n");
  insert ("\\ps{}\n");
  insert ("\\cc{}\n");
  insert ("\\encl{}\n");
  insert ("\\end{letter}\n");
  insert ("\\end{document}\n");
  pop_spot ();
}

define latex_report ()
{
  vinsert ("\\documentclass[%s]{report}\n\n",
	   LaTeX_Report_Default_Options);
  insert ("\\begin{document}\n\n");
  insert ("\\frontmatter\n");
  insert ("\\title{}");
  push_spot ();
  insert ("\\author{}\n\n");
  insert ("\\date{}\n\n");
  insert ("\\maketitle\n\n");
  insert ("\\begin{abstract}\n");
  insert ("\\end{abstract}\n\n");
  insert ("\\tableofcontents\n");
  insert ("\\listoftables\n");
  insert ("\\listoffigures\n\n");
  insert ("\\mainmatter\n\n");
  insert ("\\part{}\n\n");
  insert ("\\section{}\n\n");
  insert ("\\end{document}");
  pop_spot ();
}

define latex_slides ()
{
  vinsert ("\\documentclass[%s]{slides}\n\n",
	   LaTeX_Slides_Default_Options);
  insert ("\\begin{document}\n\n");
  insert ("\\title{");
  push_spot ();
  insert ("\\author{}\n\n");
  insert ("\\date{}\n\n");
  insert ("\\maketitle\n\n");
  insert ("\\begin{abstract}\n");
  insert ("\\end{abstract}\n\n");
  insert ("}\n\n");
  insert ("\\section{}\n\n");
  insert ("\\end{document}");
  pop_spot ();
}

% Environments

define latex_env_item ()
{
  variable tmp;

  if (1 == ITEM_LABEL)
    tmp = "item []";
  else
    tmp = "item";

  latex_insert (tmp);
}

define latex_env_description ()
{
  latex_begin_end ("description", "", PUSH_SPOT, POP_SPOT);
  ITEM_LABEL = TRUE;
}

define latex_env_figure ()
{
  variable col = what_column () - 1;
  insert ("\\begin{figure}[htbp]\n");
  insert_spaces (col + LaTeX_Indent);
  push_spot ();
  insert ("%\\includegraphics[width=5cm,height=5cm]{file.ps}\n");
  insert_spaces (col + LaTeX_Indent);
  latex_cmd ("caption", NO_PUSH_SPOT);
  insert ("\n");
  insert_spaces (col + LaTeX_Indent);
  latex_cmd ("label", NO_PUSH_SPOT);
  insert ("\n");
  insert_spaces (col);
  insert ("\\end{figure}");
  pop_spot ();
}

define latex_env_itemize ()
{
  variable col = what_column () - 1;
  ITEM_LABEL = FALSE;
  insert ("\\begin{itemize}\n");
  insert_spaces (col + LaTeX_Indent);
  latex_env_item ();
  push_spot ();
  insert ("\n");
  insert_spaces (col);
  insert ("\\end{itemize}\n");
  pop_spot ();
}

define latex_env_picture ()
{ latex_begin_end ("picture", "(width,height)(x offset,y offset)",
		     PUSH_SPOT, POP_SPOT); }

define latex_env_custom ()
{
  variable custom = read_mini ("What environment?", Null_String, "");
  latex_begin_end (custom, "", PUSH_SPOT, POP_SPOT);
}

% tables

static variable table_columns = 3;

define latex_table_row (do_push_spot)
{
  variable i, col;

  col = what_column () - 1;
  if (do_push_spot)
    push_spot ();
  loop (table_columns - 1) {
    insert (" &");
  }
  insert (" \\\\");
  if (do_push_spot)
    pop_spot ();
}

define is_integer (str)
{
  if (Integer_Type == _slang_guess_type (str))
    return (integer (str));
  else
    return -1;
}

define latex_table_template ()
{
  variable col = what_column () - 1;
  variable i, align, table_col_str, ok;

  do {
    table_col_str = read_mini ("Columns?", Null_String, "4");
    table_columns = is_integer (table_col_str);
    if (-1 == table_columns) {
      ok = FALSE;
      beep ();
      message ("Wrong value! ");
    }
    else
      ok = TRUE;
  } while (FALSE == ok);

  align = "{|";
  loop (table_columns)
    align = align + "l|";
  align = align + "}";

  insert ("\\begin{table}\n");
  insert_spaces (col + LaTeX_Indent);
  vinsert ("\\begin{tabular}%s\n", align);
  insert_spaces (col + LaTeX_Indent);
  insert ("\\hline\n");
  insert_spaces (col + LaTeX_Indent);
  push_spot ();
  latex_table_row (NO_PUSH_SPOT);
  insert ("\n");
  insert_spaces (col + LaTeX_Indent);
  insert ("\\hline\n");
  insert_spaces (col + LaTeX_Indent);
  insert ("\\end{tabular}\n");
  insert_spaces (col + LaTeX_Indent);
  latex_cmd ("caption", NO_PUSH_SPOT);
  insert ("\n");
  insert_spaces (col + LaTeX_Indent);
  latex_cmd ("label", NO_PUSH_SPOT);
  insert ("\n");
  insert_spaces (col);
  insert ("\\end{table}");
  pop_spot ();
}

define latex_note (msg)
{
  variable tmp = sprintf ("Note: you need the '%s' package.", msg);
  flush (tmp);
}

% Paragraph

define latex_par_frame ()
{
  variable str;
  str = "\\begin{boxedminipage}[c]{\\linewidth}\n";
  latex_insert_tags (str, "\\end{boxedminipage}}\n", PUSH_SPOT, POP_SPOT);
  latex_note ("boxedminipage");
}

define latex_par_bgcolour ()
{
  variable str;
  variable colour = read_mini ("What colour?", Null_String, "");
  str = sprintf ("\\colorbox{%s}{\\begin{minipage}{\\linewidth}", colour);
  latex_insert_tags (str, "\\end{minipage}}\n", PUSH_SPOT, POP_SPOT);
  latex_note ("color");
}

define latex_par_fgcolour ()
{
  variable str;
  variable colour = read_mini ("What colour?", Null_String, "");
  str = sprintf ("\\textcolor{%s}{", colour);
  latex_insert_tags (str, "}", PUSH_SPOT, POP_SPOT);
  latex_note ("color");
}

% misc

define latex_insert_braces ()
{
  insert ("{}");
  go_left_1 ();
}

define latex_insert_dollar ()
{
  insert ("$$");
  go_left_1 ();
}

define latex_search_braces ()
{
  () = fsearch ("{"); % FIXME
  go_right_1 ();
}

define latex_greek_letter ()
{
  variable tmp = expand_keystring (_Reserved_Key_Prefix);
  flush (sprintf ("Press %sm + letter (e.g. %sma = \\alpha)", 
		  tmp, tmp));
}

% let's finish

% this function is for the Template/Packages menu

define latex_babel ()
{
  variable tmp = sprintf ("\\usepackage[%s]{babel}\n", 
			  LaTeX_Default_Language); 
  insert (tmp);
}

define init_menu (menu)
{
  variable tmp;
  % templates
  menu_append_popup (menu, "&Templates");
  $1 = sprintf ("%s.&Templates", menu);
  menu_append_item ($1, "<&Article>", "latex_article ()");
  menu_append_item ($1, "<&Book>", "latex_book ()");
  menu_append_item ($1, "<&Letter>", "latex_letter ()");
  menu_append_item ($1, "<&Report>", "latex_report ()");
  menu_append_item ($1, "<&Slides>", "latex_slides ()");
  % templates/packages
  % these aren't bound to any key
  menu_append_popup ($1, "&Packages");
  $1 = sprintf ("%s.&Templates.&Packages", menu);
  menu_append_item ($1, "&babel", "latex_babel ()");
  menu_append_item ($1, "&color", 
		    "latex_insert_newline (\"usepackage\{color\}\")");
  tmp = "latex_insert_newline (\"usepackage\{epic\}\");";
  tmp = tmp + "latex_insert_newline (\"usepackage\{eepic\}\")";
  menu_append_item ($1, "&eepic", tmp);
  menu_append_item ($1, "&fancyvrb", 
		    "latex_insert_newline (\"usepackage\{fancyvrb\}\")");
  tmp = "latex_insert_newline (\"usepackage\{fancyhdr\}\");";
  tmp = tmp + "latex_insert_newline (\"pagestyle\{fancy\}\")";
  menu_append_item ($1, "fancy&hdr", tmp);
  menu_append_item ($1, "&graphicx", 
		    "latex_insert_newline (\"usepackage\{graphicx\}\")");
  menu_append_item ($1, "&hyperref", 
		    "latex_insert_newline (\"usepackage\{hyperref\}\")");
  menu_append_item ($1, "&isolatin1", 
		    "latex_insert_newline (\"usepackage\{isolatin1\}\")");
  menu_append_item ($1, "&moreverb", 
		    "latex_insert_newline (\"usepackage\{moreverb\}\")");
  menu_append_item ($1, "makeinde&x", 
		    "latex_insert_newline (\"usepackage\{makeindex\}\")");
  menu_append_item ($1, "&psfrag", 
		    "latex_insert_newline (\"usepackage\{psfrag\}\")");
  menu_append_item ($1, "&rotating", 
		    "latex_insert_newline (\"usepackage\{rotating\}\")");
  menu_append_item ($1, "&url", 
		    "latex_insert_newline (\"usepackage\{url\}\")");
  % environments
  menu_append_popup (menu, "&Environments");
  $1 = sprintf ("%s.&Environments", menu);
  menu_append_item ($1, "&array", 
		    "latex_begin_end (\"array\", \"{ll}\", 1, 1)");
  menu_append_item ($1, "&center", 
		    "latex_begin_end (\"center\", \"\", 1, 1)");
  menu_append_item ($1, "&description", 
		    "latex_begin_end (\"description\", \"\", 1, 1)");
  menu_append_item ($1, "displaymat&h", 
		    "latex_begin_end (\"displaymath\", \"\", 1, 1)");
  menu_append_item ($1, "&enumerate", 
		    "latex_begin_end (\"enumerate\", \"\", 1, 1)");
  menu_append_item ($1, "eq&narray", 
		    "latex_begin_end (\"eqnarray\", \"\", 1, 1)");
  menu_append_item ($1, "e&quation", 
		    "latex_begin_end (\"equation\", \"\", 1, 1)");
  menu_append_item ($1, "&figure", "latex_env_figure ()");
  menu_append_item ($1, "flush&left", 
		    "latex_begin_end (\"flushleft\", \"\", 1, 1)");
  menu_append_item ($1, "flush&Right", 
		    "latex_begin_end (\"flushright\", \"\", 1, 1)");
  menu_append_item ($1, "&Itemize", "latex_env_itemize ()");
  menu_append_item ($1, "\\&item", "latex_env_item ()");
  menu_append_item ($1, "&Letter", "latex_env_letter ()");
  menu_append_item ($1, "list", "latex_begin_end (\"list\", \"\", 1, 1)");
  menu_append_item ($1, "&minipage", 
		    "latex_begin_end (\"minipage\", \"[c]{\\\\linewidth}\", 1, 1)");
  menu_append_item ($1, "&picture", 
		    "latex_begin_end (\"picture\", \"\", 1, 1)");
  menu_append_item ($1, "quotation", 
		    "latex_begin_end (\"quotation\", \"\", 1, 1)");
  menu_append_item ($1, "qu&ote", "latex_begin_end (\"quote\", \"\", 1, 1)");
  menu_append_item ($1, "ta&bbing", 
		    "latex_begin_end (\"tabbing\", \"\", 1, 1)");
  menu_append_item ($1, "&table", "latex_table_template ()");
  menu_append_item ($1, "table &row", "latex_table_row (1)");
  % more environments
  menu_append_popup ($1, "&More");
  $1 = sprintf ("%s.&Environments.&More", menu);
  menu_append_item ($1, "tab&ular", "latex_env_tabular (\"[htbp]\", 1, 1)");
  menu_append_item ($1, "thebibliograph&y", 
		    "latex_begin_end (\"thebibliography\", \"\", 1, 1)");
  menu_append_item ($1, "t&Heorem", 
		    "latex_begin_end (\"theorem\", \"\", 1, 1)");
  menu_append_item ($1, "titlepa&ge", 
		    "latex_begin_end (\"titlepage\", \"\", 1, 1)");
  menu_append_item ($1, "&verbatim", 
		    "latex_begin_end (\"verbatim\", \"\", 1, 1)");
  menu_append_item ($1, "ver&se", "latex_begin_end (\"verse\", \"\", 1, 1)");
  % font
  menu_append_popup (menu, "&Font");
  $1 = sprintf ("%s.&Font", menu);
  menu_append_item ($1, "\\text&rm", "latex_cmd (\"textrm\", 1)");
  menu_append_item ($1, "\\text&it", "latex_cmd (\"textit\", 1)");
  menu_append_item ($1, "\\&emph",   "latex_cmd (\"emph\", 1)");
  menu_append_item ($1, "\\text&md", "latex_cmd (\"textmd\", 1)");
  menu_append_item ($1, "\\text&bf", "latex_cmd (\"textmd\", 1)");
  menu_append_item ($1, "\\text&up", "latex_cmd (\"textup\", 1)");
  menu_append_item ($1, "\\text&sl", "latex_cmd (\"textsl\", 1)");
  menu_append_item ($1, "\\texts&f", "latex_cmd (\"textsf\", 1)");
  menu_append_item ($1, "\\texts&c", "latex_cmd (\"textsc\", 1)");
  menu_append_item ($1, "\\text&tt", "latex_cmd (\"texttt\", 1)");
  menu_append_item ($1, "\\text&normal", "latex_cmd (\"textnormal\", 1)");
  % Font popups:
  % font/size, font/environment, font/math
  menu_append_popup ($1, "&Size");
  menu_append_popup ($1, "As &Environment");
  menu_append_popup ($1, "&Math");
  $1 = sprintf ("%s.&Font.&Size", menu);
  menu_append_item ($1, "\\&tiny", "latex_cmd (\"tiny\", 1)");
  menu_append_item ($1, "\\s&criptsize", 
		    "latex_cmd (\"scriptsize\", 1)");
  menu_append_item ($1, "\\&footnotesize", 
		    "latex_cmd (\"footnotesize\", 1)");
  menu_append_item ($1, "\\&small", "latex_cmd (\"small\", 1)");
  menu_append_item ($1, "\\&normalsize", "latex_cmd (\"normalsize\", 1)");
  menu_append_item ($1, "\\&large", "latex_cmd (\"large\", 1)");
  menu_append_item ($1, "\\&Large", "latex_cmd (\"Large\", 1)");
  menu_append_item ($1, "\\L&ARGE", "latex_cmd (\"LARGE\", 1)");
  menu_append_item ($1, "\\&huge", "latex_cmd (\"huge\", 1)");
  menu_append_item ($1, "\\&Huge", "latex_cmd (\"Huge\", 1)");
  % font/environment
  $1 = sprintf ("%s.&Font.As &Environment", menu);
  menu_append_item ($1, "\\&rmfamily", 
		    "latex_begin_end (\"rmfamily\", \"\", 1, 1)");
  menu_append_item ($1, "\\&itshape", 
		    "latex_begin_end (\"itshape\", \"\", 1, 1)");
  menu_append_item ($1, "\\&mdseries", 
		    "latex_begin_end (\"mdseries\", \"\", 1, 1)");
  menu_append_item ($1, "\\&bfseries", 
		    "latex_begin_end (\"bfseries\", \"\", 1, 1)");
  menu_append_item ($1, "\\&upshape", 
		    "latex_begin_end (\"upshape\", \"\", 1, 1)");
  menu_append_item ($1, "\\&slshape", 
		    "latex_begin_end (\"slshape\", \"\", 1, 1)");
  menu_append_item ($1, "\\s&ffamily", 
		    "latex_begin_end (\"sffamily\", \"\", 1, 1)");
  menu_append_item ($1, "\\s&cshape", 
		    "latex_begin_end (\"scshape\", \"\", 1, 1)");
  menu_append_item ($1, "\\&ttfamily", 
		    "latex_begin_end (\"ttfamily\", \"\", 1, 1)");
  menu_append_item ($1, "\\&normalfont", 
		    "latex_begin_end (\"normalfont\", \"\", 1, 1)");
  % font/math
  $1 = sprintf ("%s.&Font.&Math", menu);
  menu_append_item ($1, "\\mathr&m", "latex_cmd (\"mathrm\", 1)");
  menu_append_item ($1, "\\math&bf", "latex_cmd (\"mathbf\", 1)");
  menu_append_item ($1, "\\math&sf", "latex_cmd (\"mathsf\", 1)");
  menu_append_item ($1, "\\math&tt", "latex_cmd (\"mathtt\", 1)");
  menu_append_item ($1, "\\math&it", "latex_font_mathit ()");
  menu_append_item ($1, "\\math&normal", "latex_cmd (\"mathnormal\", 1)");
  % sections
  menu_append_popup (menu, "&Sections");
  $1 = sprintf ("%s.&Sections", menu);
  menu_append_item ($1, "\\&chapter", "latex_cmd (\"chapter\", 1)");
  menu_append_item ($1, "\\&section", "latex_cmd (\"section\", 1)");
  menu_append_item ($1, "\\s&ubsection", "latex_cmd (\"subsection\", 1)");
  menu_append_item ($1, "\\su&bsubsection", 
		    "latex_cmd (\"subsubsection\", 1)");
  menu_append_item ($1, "\\&paragraph", "latex_cmd (\"paragraph\", 1)");
  menu_append_item ($1, "\\subparagrap&h", 
		    "latex_cmd (\"subparagraph\", 1)");
  menu_append_item ($1, "\\p&art", "latex_cmd (\"part\", 1)");
  % paragraph
  menu_append_popup (menu, "&Paragraph");
  $1 = sprintf ("%s.&Paragraph", menu);
  menu_append_item ($1, "&Framed Paragraph", "latex_par_frame ()");
  menu_append_item ($1, "Back&ground Colour", "latex_par_bgcolour ()");
  menu_append_item ($1, "Foreground &Colour", "latex_par_fgcolour ()");
  menu_append_item ($1, "&Margin Paragraph", 
		    "latex_cmd (\"marginpar\", 1)");
  menu_append_item ($1, "Foot&note", 
		    "latex_cmd (\"footnote\", 1)");
  % paragraph popups:
  % paragraph/breaks, paragraph/boxes, paragraph/spaces
  menu_append_popup ($1, "&Breaks");
  menu_append_popup ($1, "&Spaces");
  menu_append_popup ($1, "Bo&xes");
  $1 = sprintf ("%s.&Paragraph.&Breaks", menu);
  menu_append_item ($1, "\\new&line", "insert (\"\\\\newline\\n\")");
  menu_append_item ($1, "\\line&break", "insert (\"\\\\linebreak[1]\\n\")");
  menu_append_item ($1, "\\new&page", "insert (\"\\\\newpage\\n\")");
  menu_append_item ($1, "\\&clearpage", "insert (\"\\\\clearpage\\n\")");
  menu_append_item ($1, "\\clear&doublepage",
		    "insert (\"\\\\cleardoublepage\\n\")");
  menu_append_item ($1, "\\pageb&reak", "insert (\"\\\\pagebreak\\n\")");
  menu_append_item ($1, "\\&nolinebreak",
		    "insert (\"\\\\nolinebreak[1]\\n\")");
  menu_append_item ($1, "\\n&opagebreak", "insert (\"\\\\nopagebreak\\n\")");
  menu_append_item ($1, "\\&enlargethispage",
		    "insert (\"\\\\enlargethispage\\n\")");
  % paragraph/spaces
  $1 = sprintf ("%s.&Paragraph.&Spaces", menu);
  menu_append_item ($1, "\\&dotfill", "insert (\"\\\\dotfill\\n\")");
  menu_append_item ($1, "\\&hfill", "insert (\"\\\\hfill\\n\")");
  menu_append_item ($1, "\\h&rulefill", "insert (\"\\\\hrulefill\\n\")");
  menu_append_item ($1, "\\&smallskip", "insert (\"\\\\smallskip\\n\")");
  menu_append_item ($1, "\\&medskip", "insert (\"\\\\medskip\\n\")");
  menu_append_item ($1, "\\&bigskip", "insert (\"\\\\bigskip\\n\")");
  menu_append_item ($1, "\\&vfill", "insert (\"\\\\vfill\\n\")");
  menu_append_item ($1, "\\vs&pace", "insert (\"\\\\vspace\\n\")");
  % paragraph/boxes
  $1 = sprintf ("%s.&Paragraph.Bo&xes", menu);
  menu_append_item ($1, "\\&fbox", "latex_cmd (\"fbox\", 1)");
  menu_append_item ($1, "\\f&ramebox", 
		    "latex_cmd (\"framebox[\\\\width][c]\", 1)");
  menu_append_item ($1, "\\&mbox", "latex_cmd (\"mbox\", 1)");
  menu_append_item ($1, "\\ma&kebox", 
		    "latex_cmd (\"makebox[\\\\width][c]\", 1)");
  menu_append_item ($1, "\\&newsavebox", "latex_cmd (\"newsavebox\", 1)");
  menu_append_item ($1, "\\ru&le", 
		    "latex_cmd (\"rule{\\\\linewidth}\", 1)");
  menu_append_item ($1, "\\save&box", 
		    "latex_cmd (\"savebox{}[\\\\linewidth][c]\", 1)");
  menu_append_item ($1, "\\&sbox", 
		    "latex_cmd (\"sbox{}\", 1)");
  menu_append_item ($1, "\\&usebox", 
		    "latex_cmd (\"usebox\", 1)");
  % links
  menu_append_popup (menu, "&Links");
  $1 = sprintf ("%s.&Links", menu);
  menu_append_item ($1, "\\&label", "latex_cmd (\"label\", 1)");
  menu_append_item ($1, "\\&xref", "latex_cmd (\"xref\", 1)");
  menu_append_item ($1, "\\&cite", "latex_cmd (\"cite\", 1)");
  menu_append_item ($1, "\\&pageref", "latex_cmd (\"pageref\", 1)");
  % math
  menu_append_popup (menu, "&Math");
  $1 = sprintf ("%s.&Math", menu);
  % Math popups:
  % math/greek letter, math/accents, math/binary relations,
  % math/operators, math/arrows, math/misc
  menu_append_item ($1, "&Greek Letter...", "latex_greek_letter ()");
  menu_append_item ($1, "&Subscript", 
		    "latex_insert_tags (\"_{\", \"}\", 1, 1)");
  menu_append_item ($1, "S&uperscript",
		    "latex_insert_tags (\"^{\", \"}\", 1, 1)");
  menu_append_popup ($1, "&Accents");
  menu_append_popup ($1, "&Delimiters");
  menu_append_popup ($1, "Binary &Relations");
  menu_append_popup ($1, "Binary &Operators");
  menu_append_popup ($1, "Arro&ws");
  menu_append_popup ($1, "&Misc");
  % math/accents
  $1 = sprintf ("%s.&Math.&Accents", menu);
  menu_append_item ($1, "\\&bar", "latex_cmd (\"bar\", 1)");
  menu_append_item ($1, "\\&dot", "latex_cmd (\"dot\", 1)");
  menu_append_item ($1, "\\dd&ot", "latex_cmd (\"ddot\", 1)");
  menu_append_item ($1, "\\&hat", "latex_cmd (\"hat\", 1)");
  menu_append_item ($1, "\\&tilde", "latex_cmd (\"tilde\", 1)");
  menu_append_item ($1, "\\&vec", "latex_cmd (\"vec\", 1)");
  menu_append_item ($1, "\\&widehat",
		    "latex_cmd (\"widehat\", 1)");
  menu_append_item ($1, "\\wid&etilde",
		    "latex_cmd (\"widetilde\", 1)");
  % math/delimiters
  $1 = sprintf ("%s.&Math.&Delimiters", menu);
  menu_append_item ($1, "\\left&(", "latex_insert (\"left(\")");
  menu_append_item ($1, "\\right&)", "latex_insert (\"right)\")");
  menu_append_item ($1, "\\left&[", "latex_insert (\"left[\")");
  menu_append_item ($1, "\\right&]", "latex_insert (\"right[\")");
  menu_append_item ($1, "\\left&{", "latex_insert (\"left\\\\{\")");
  menu_append_item ($1, "\\right&}", "latex_insert (\"right\\\\}\")");
  % math/binary relations
  $1 = sprintf ("%s.&Math.Binary &Relations", menu);
  menu_append_item ($1, "\\&approx", "latex_insert (\"approx\")");
  menu_append_item ($1, "\\&cong", "latex_insert (\"cong\")");
  menu_append_item ($1, "\\&geq", "latex_insert (\"geq\")");
  menu_append_item ($1, "\\&in", "latex_insert (\"in\")");
  menu_append_item ($1, "\\notin", "latex_insert (\"notin\")");
  menu_append_item ($1, "\\&leq", "latex_insert (\"leq\")");
  menu_append_item ($1, "\\&neq", "latex_insert (\"neq\")");
  menu_append_item ($1, "\\ll", "latex_insert (\"ll\")");
  menu_append_item ($1, "\\gg", "latex_insert (\"gg\")");
  menu_append_item ($1, "\\&equiv", "latex_insert (\"equiv\")");
  menu_append_item ($1, "\\&sim", "latex_insert (\"sim\")");
  menu_append_item ($1, "\\sime&q", "latex_insert (\"simeq\")");
  menu_append_item ($1, "\\&propto", "latex_insert (\"propto\")");
  % math/binary operators
  $1 = sprintf ("%s.&Math.Binary &Operators", menu);
  menu_append_item ($1, "\\&ast", "latex_insert (\"ast\")");
  menu_append_item ($1, "\\&dagger", "latex_insert (\"dagger\")");
  menu_append_item ($1, "\\dda&ger", "latex_insert (\"ddagger\")");
  menu_append_item ($1, "\\&mp", "latex_insert (\"mp\")");
  menu_append_item ($1, "\\&pm", "latex_insert (\"pm\")");
  menu_append_item ($1, "\\&star", "latex_insert (\"star\")");
  menu_append_item ($1, "\\&times", "latex_insert (\"times\")");
  % math/arrows
  $1 = sprintf ("%s.&Math.Arro&ws", menu);
  menu_append_item ($1, "\\&leftarrow", "latex_insert (\"leftarrow\")");
  menu_append_item ($1, "\\&rightarrow", "latex_insert (\"rightarrow\")");
  menu_append_item ($1, "\\&uparrow", "latex_insert (\"uparrow\")");
  menu_append_item ($1, "\\&downarrow", "latex_insert (\"downarrow\")");
  menu_append_item ($1, "\\&leftrightarrow",
		    "latex_insert (\"leftrightarrow\")");
  % math/misc
  $1 = sprintf ("%s.&Math.&Misc", menu);
  menu_append_item ($1, "\\&exists", "latex_insert (\"exists\")");
  menu_append_item ($1, "\\&forall", "latex_insert (\"forall\")");
  menu_append_item ($1, "\\f&rac", "latex_insert (\"frac{}{}\")");
  menu_append_item ($1, "\\in&fty", "latex_insert (\"infty\")");
  menu_append_item ($1, "\\&int", "latex_insert_nospace (\"int\")");
  menu_append_item ($1, "\\&nabla", "latex_insert (\"nabla\")");
  menu_append_item ($1, "\\&oint", "latex_insert (\"oint\")");
  menu_append_item ($1, "\\p&artial", "latex_insert (\"partial\")");
  menu_append_item ($1, "\\&prod", "latex_insert (\"prod\")");
  menu_append_item ($1, "\\&sum", "latex_insert (\"sum\")");
  menu_append_item ($1, "\\s&qrt", "latex_insert (\"sqrt[]{}\")");
  % separator
  $1 = sprintf ("%s", menu);
  menu_append_separator ($1);
  menu_append_item ($1, "&Compose (LaTeX)", "latex_compose");
  menu_append_item_if ($1, "View .&dvi", "latex_preview", 
		       LaTeX_View_Dvi_Command);
  menu_append_item_if ($1, "C&onvert .dvi", "latex_convert_dvi", 
		       LaTeX_Dvips_Command);
  menu_append_item_if ($1, "&View PostScript", "latex_gsview",
		       LaTeX_View_Ps_Command);
#ifndef IBMPC_SYSTEM
  menu_append_item_if ($1, "P&rint", "latex_psprint", 
		       LaTeX_Psdev);
#endif
  menu_append_item_if ($1, "&BibTeX", "latex_bibtex", 
		       LaTeX_Bibtex_Command);
  menu_append_item_if ($1, "Makei&ndex", "latex_makeindex", 
		       LaTeX_Makeindex_Command);
  menu_append_item ($1, "Set &main file", "latex_set_mainfile");
}

define latex_keymap ()
{
  $1 = "LaTeX-Mode";
  !if (keymap_p ($1))
    make_keymap ($1);
  use_keymap ($1);

  % templates
  definekey_reserved ("latex_article ()", "ta", $1);
  definekey_reserved ("latex_book ()",    "tb", $1);
  definekey_reserved ("latex_letter ()",  "tl", $1);
  definekey_reserved ("latex_report ()",  "tr", $1);
  definekey_reserved ("latex_slides ()",  "ts", $1);
  % environments
  definekey_reserved ("latex_begin_end (\"array\", \"{ll}\", 1, 1)", "ea", $1);
  definekey_reserved ("latex_begin_end (\"center\", \"\", 1, 1)", "ec", $1);
  definekey_reserved ("latex_begin_end (\"description\", \"\", 1, 1)", "ed", $1);
  definekey_reserved ("latex_begin_end (\"displaymath\", \"\", 1, 1)", "eh", $1);
  definekey_reserved ("latex_begin_end (\"enumerate\", \"\", 1, 1)", "ee", $1);
  definekey_reserved ("latex_begin_end (\"eqnarray\", \"\", 1, 1)", "en", $1);
  definekey_reserved ("latex_begin_end (\"equation\", \"\", 1, 1)", "eq", $1);
  definekey_reserved ("latex_env_figure ()", "ef", $1);
  definekey_reserved ("latex_begin_end (\"flushleft\", \"\", 1, 1)", "el", $1);
  definekey_reserved ("latex_begin_end (\"flushright\", \"\", 1, 1)", "eR", $1);
  definekey_reserved ("latex_env_item ()", "ei", $1);
  definekey_reserved ("latex_env_itemize ()", "eI", $1);
  definekey_reserved ("latex_env_letter ()", "eL", $1);
  % latex_env_list () is not bound
  definekey_reserved ("latex_begin_end (\"minipage\", \"[c]{\\\\linewidth}\", 1, 1)", "em", $1);
  definekey_reserved ("latex_begin_end (\"picture\", \"\", 1, 1)", "ep", $1);
  definekey_reserved ("latex_begin_end (\"quotation\", \"\", 1, 1)", "eQ", $1);
  definekey_reserved ("latex_begin_end (\"quote\", \"\", 1, 1)", "eo", $1);
  definekey_reserved ("latex_begin_end (\"tabbing\", \"\", 1, 1)", "eb", $1);
  definekey_reserved ("latex_env_tabular (\"[htbp]\", 1, 1)", "eu", $1);
  definekey_reserved ("latex_table_template ()", "et", $1);
  definekey_reserved ("latex_table_row (1)", "er", $1);
  definekey_reserved ("latex_begin_end (\"thebibliography\", \"\", 1, 1)", "ey", $1);
  definekey_reserved ("latex_begin_end (\"theorem\", \"\", 1, 1)", "eH", $1);
  definekey_reserved ("latex_begin_end (\"titlepage\", \"\", 1, 1)", "eg", $1);
  definekey_reserved ("latex_begin_end (\"verbatim\", \"\", 1, 1)", "ev", $1);
  definekey_reserved ("latex_begin_end (\"verse\", \"\", 1, 1)", "es", $1);
  definekey_reserved ("latex_env_custom ()", "eC", $1);
  % fonts - only basic commands for now
  definekey_reserved ("latex_cmd (\"textrm\", 1)", "fr", $1);
  definekey_reserved ("latex_cmd (\"textit\", 1)", "fi", $1);
  definekey_reserved ("latex_cmd (\"emph\", 1)", "fe", $1);
  definekey_reserved ("latex_cmd (\"textmd\", 1)", "fm", $1);
  definekey_reserved ("latex_cmd (\"textmd\", 1)", "fb", $1);
  definekey_reserved ("latex_cmd (\"textup\", 1)", "fu", $1);
  definekey_reserved ("latex_cmd (\"textsl\", 1)", "fs", $1);
  definekey_reserved ("latex_cmd (\"textsf\", 1)", "ff", $1);
  definekey_reserved ("latex_cmd (\"textsc\", 1)", "fc", $1);
  definekey_reserved ("latex_cmd (\"texttt\", 1)", "ft", $1);
  definekey_reserved ("latex_cmd (\"textnormal\", 1)", "fn", $1);
  definekey_reserved ("latex_cmd (\"underline\", 1)", "fd", $1);
  % font size
  definekey_reserved ("latex_cmd (\"tiny\", 1)", "zt", $1);
  definekey_reserved ("latex_cmd (\"scriptsize\", 1)", "zc", $1);
  definekey_reserved ("latex_cmd (\"footnotesize\", 1)", "zf", $1);
  definekey_reserved ("latex_cmd (\"small\", 1)", "zs", $1);
  definekey_reserved ("latex_cmd (\"normalsize\", 1)", "zn", $1);
  definekey_reserved ("latex_cmd (\"large\", 1)", "zl", $1);
  definekey_reserved ("latex_cmd (\"Large\", 1)", "zL", $1);
  definekey_reserved ("latex_cmd (\"LARGE\", 1)", "zA", $1);
  definekey_reserved ("latex_cmd (\"huge\", 1)", "zh", $1);
  definekey_reserved ("latex_cmd (\"Huge\", 1)", "zH", $1);
  % sections
  definekey_reserved ("latex_cmd (\"chapter\", 1)", "sc", $1);
  definekey_reserved ("latex_cmd (\"section\", 1)", "ss", $1);
  definekey_reserved ("latex_cmd (\"subsection\", 1)", "su", $1);
  definekey_reserved ("latex_cmd (\"subsubsection\", 1)", "sb", $1);
  definekey_reserved ("latex_cmd (\"paragraph\", 1)", "sp", $1);
  definekey_reserved ("latex_cmd (\"subparagraph\", 1)", "sh", $1);
  definekey_reserved ("latex_cmd (\"part\", 1)", "sa", $1);
  % links
  definekey_reserved ("latex_cmd (\"label\", 1)", "ll", $1);
  definekey_reserved ("latex_cmd (\"xref\", 1)", "lx", $1);
  definekey_reserved ("latex_cmd (\"cite\", 1)", "lc", $1);
  definekey_reserved ("latex_cmd (\"pageref\", 1)", "lp", $1);
  % breaks
  definekey_reserved ("insert (\"\\\\newline\\n\")", "bl", $1);
  definekey_reserved ("insert (\"\\\\linebreak[1]\\n\")", "bb", $1);
  definekey_reserved ("insert (\"\\\\newpage\\n\")", "bp", $1);
  definekey_reserved ("insert (\"\\\\clearpage\\n\")", "bc", $1);
  definekey_reserved ("insert (\"\\\\cleardoublepage\\n\")", "bd", $1);
  definekey_reserved ("insert (\"\\\\pagebreak\\n\")", "br", $1);
  definekey_reserved ("insert (\"\\\\nolinebreak[1]\\n\")", "bn", $1);
  definekey_reserved ("insert (\"\\\\nopagebreak\\n\")", "bo", $1);
  definekey_reserved ("insert (\"\\\\enlargethispage\\n\")", "be", $1);
  % misc
  definekey_reserved ("latex_insert_tags (\"{\", \"}\", 1, 1)", "{", $1);
  % definekey_reserved ("latex_search_braces ()", "B", $1);
  definekey_reserved ("latex_insert_math ()", "m", $1);
  % from tex.sl
  definekey ("tex_insert_quote", "\"", $1);
  definekey ("tex_insert_quote", "'",  $1);
  definekey ("tex_blink_dollar", "$",  $1);
  definekey ("tex_ldots",        ".",  $1);
  % special characters
  definekey_reserved (" \\#", "#", $1);
  definekey_reserved (" \\$", "$", $1);
  definekey_reserved (" \\%", "%", $1);
  definekey_reserved (" \\&", "&", $1);
  definekey_reserved (" $\\sim$", "~", $1);
  definekey_reserved (" \\_", "_", $1);
  definekey_reserved (" \\^", "^", $1);
  definekey_reserved (" $\\backslash$", "\\", $1);
  definekey_reserved (" \\{", "(", $1);
  definekey_reserved (" \\}", ")", $1);
  % final stuff
  definekey_reserved ("latex_compose", "cl", $1);
  definekey_reserved ("latex_preview", "vd", $1);
  definekey_reserved ("latex_gsview", "vp", $1);
}

%!%+
%\function{latex_mode}
%\synopsis{latex_mode}
%\usage{Void latex_mode ();}
%\description
% This mode is designed to facilitate the task of editing latex files.
% It calls the function \var{latex_mode_hook} if it is defined.  In addition,
% if the abbreviation table \var{"TeX"} is defined, that table is used.
%
% The default key-bindings for this mode include:
%#v+
%    "tex_insert_braces"       "^C{"
%    "tex_font"                "^C^F"
%    "latex_begin_end"         "^C^E"
%    "latex_section"           "^C^S"
%    "latex_close_environment" "^C]"
%    "tex_mark_environment"    "^C."
%    "tex_mark_section"        "^C*"
%    "latex_toggle_math_mode"  "^C~"
%#v-
%!%-
define latex_mode ()
{
  set_mode ("LaTeX", 0x1 | 0x20);
  latex_keymap ();

  set_buffer_hook ("par_sep", "tex_paragraph_separator");
  set_buffer_hook ("wrap_hook", "tex_wrap_hook");
  % set_buffer_hook ("indent_hook", "latex_indent_line");
  % set_buffer_hook ("newline_indent_hook", "latex_newline_indent_line");

  % latex math mode will map this to something else.
  local_unsetkey ("`");
  local_setkey ("quoted_insert", "`");
  
  mode_set_mode_info ("LaTeX", "init_mode_menu", &init_menu);
  mode_set_mode_info ("LaTeX", "fold_info", "%{{{\r%}}}\r\r");

  run_mode_hooks("latex_mode_hook");
  use_syntax_table ("TeX-Mode");

  % This is called after the hook to give the hook a chance to load the
  % abbrev table.
  if (abbrev_table_p ("TeX"))
    use_abbrev_table ("TeX");
}

%% -------------------------------------------------------------
%% Initializations:


% The initial value of LaTeX_Mainfile is the name of the file
% that for the first time activates LaTeX mode.
% If the initial value of `LaTeX_Mainfile' is empty, then call
% `latex_set_mainfile'
LaTeX_Mainfile = buffer_filename ();
!if (strlen (LaTeX_Mainfile))
  latex_set_mainfile ();

provide ("latex");

% --- End of file latex.sl

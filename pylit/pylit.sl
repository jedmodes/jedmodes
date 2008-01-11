% pylit.sl: Helper functions for literal programming with PyLit
%
% Copyright (c) 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
%
% ===== ========== ==========================================================
% 0.1   2006-03-03 as part of gmisc.sl (2008-01-11 )
% 0.2   2007-01-23 added pylit_check, public release as pylit.sl
% 0.2.1 2007-01-24 bugfix in pylit_check(): do nothing if both files are of
%                  same age
% 0.2.2 2007-03-09 call rst_mode() if the output buffer is text
%                  literate version
% 0.3   2008-01-11 set matching mode in pylit_diff and pylit_doctest
% ===== ========== ==========================================================
%
%
% Requirements
% ------------
% helper modes from http://jedmodes.sf.net/ ::

autoload("push_defaults", "sl_utils");
autoload("shell_cmd_on_region_or_buffer", "ishell");
autoload("python_output_mode", "pymode");

% Customization
% -------------
%
% the `pylit` command
%
% * give a full path if pylit is not in your PATH
% * specify as ``python pylit.py`` (with needed paths) if it does not self-exec
%
% ::

custom_variable("Pylit_Cmd", "pylit");

% Functions
% ---------
%
% ::

private variable output_buffer = "*PyLit output*";
private variable doctest_buffer = "*doctest output*";

% switch to `outfile` and place cursor in the corresponding line
private define pylit_switch_to_output(outfile)
{
   variable line = what_line();
   close_buffer();
   () = find_file(outfile);
   goto_line(line);
   if (path_extname(outfile) == ".txt")
     call_function("rst_mode"); % if it exists
}

%!%+
%\function{pylit_check}
%\synopsis{Check for a more recent version of the current file}
%\usage{pylit_check()}
%\description
%  PyLit (http://pylit.berlios.de/) converts between text and code format
%  of a source file.
%
%  There is the possibility of data loss, if edits are done in parallel on
%  both versions.
%
%  \sfun{pylit_check} checks, if there is a more recent (text or code)
%  source  version of the current buffer's associated file and recommends to
%  load this instead.
%\example
%  To check for newer versions in the not-openend format add to your jed.rc
%#v+
%  define rst_mode_hook() { pylit_check(); }
%  define python_mode_hook() {pylit_check(); }
%#v-
%  (or extend the mode hooks if they already exist). Repeat this for all
%  programming languages where you do literate programming in.
%\notes
%  \sfun{pylit_check} handles only the case with default filename extensions
%  (".txt" added for the text source and stripped for the code source).
%\seealso{pylit_buffer, pylit_view, pylit_diff}
%!%-
public define pylit_check()
{
   variable outfile, file = buffer_filename();
   if (file == "")
     return;

   % mimic PyLit's outfile name generation
   if (path_extname(file) == ".txt")
     outfile = path_sans_extname(file);
   else
     outfile = file + ".txt";

   if (file_time_compare(file, outfile) >= 0)
     return; % buffer-file is newer or same age (e.g. both nonexistant)

   if (get_y_or_n(path_basename(outfile) + " is more recent. Load it instead?"))
     pylit_switch_to_output(outfile);
}

%!%+
%\function{pylit_buffer}
%\synopsis{Convert the current buffer with PyLit}
%\usage{pylit_buffer()}
%\description
%  PyLit (http://pylit.berlios.de/) converts between text and code format
%  of a source file.
%
%  \sfun{pylit_buffer} calls `pylit` on the current buffer, closes it
%  (if successfull) and opens the output file instead.
%\seealso{pylit_check, pylit_view, pylit_diff}
%!%-
public define pylit_buffer()
{
   variable buf = whatbuf();

   shell_cmd_on_region_or_buffer(Pylit_Cmd, output_buffer);

   % switch to converted version
   !if (re_fsearch("extract written to \\(.*\\)"))
     return;
   variable outfile = regexp_nth_match(1);

   close_buffer(output_buffer);
   sw2buf(buf);

   pylit_switch_to_output(outfile);
}

% call pylit to convert buffer, do not produce a file, view result in a buffer
public define pylit_view()
{
   variable line = what_line();
   shell_cmd_on_region_or_buffer(Pylit_Cmd + " -o -", output_buffer);
   goto_line(line);
}

% view the differences introduced by a PyLit round-trip
public define pylit_diff()
{
   shell_cmd_on_region_or_buffer(Pylit_Cmd + " --diff ", output_buffer);
   bob();
   call_function("diff_mode");
}

% do a doctest of the buffer (using the text format to get test in comments)
public define pylit_doctest()
{
   shell_cmd_on_region_or_buffer(Pylit_Cmd + " --doctest ", doctest_buffer);
   !if (bsearch("------------------------------"))
      bob();
   recenter(1);

   python_output_mode();
}

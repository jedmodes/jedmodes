% pylit.sl: Helper functions for literal programming with PyLit
% Copyright (c) 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1 2006-03-03 as part of gmisc.sl (unpublished)
% 0.2 2007-01-23 added pylit_check, public release as pylit.sl

% Requirements
% http://jedmodes.sf.net/mode/sl_utils/
autoload("push_defaults", "sl_utils");
% http://jedmodes.sf.net/mode/ishell/
autoload("shell_cmd_on_region_or_buffer", "ishell");

% Customization
custom_variable("Pylit_Cmd", "pylit");

%---------------------------------------------------------------------------

private variable output_buffer = "*PyLit output*";

% switch to `outfile` and place cursor in the corresponding line
private define pylit_switch_to_output(outfile)
{
   variable line = what_line();
   close_buffer();
   () = find_file(outfile);
   goto_line(line);
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
%  (or extend the mode hooks if they already exist).
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
   
   if (file_time_compare(file, outfile) > 0)
     return; % buffer-file is newer
     
   if (get_y_or_n(path_basename(outfile) + " is more recent. Load it instead?"))
     pylit_switch_to_output(outfile);
}

%!%+
%\function{pylit_buffer}
%\synopsis{}
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

% call pylit to convert buffer, view result
public define pylit_view()
{
   shell_cmd_on_region_or_buffer(Pylit_Cmd + " -o -", output_buffer);
}

% view the differences introduced by a PyLit round-trip
public define pylit_diff()
{
   shell_cmd_on_region_or_buffer(Pylit_Cmd + " --diff ", output_buffer);
}


% check for a newer version of the buffer-file

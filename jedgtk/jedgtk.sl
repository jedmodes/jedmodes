% jedgtk.sl
% slgtk dialogs for JED
% 
% $Id: jedgtk.sl,v 1.2 2004/06/28 10:45:11 paul Exp $
% Keywords: gtk, ui
%
% Copyright (c) 2004 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).

import("gtk");

if (_featurep("jedgtk"))
  use_namespace("jedgtk");
else
  implements("jedgtk");
provide("jedgtk");

static define file_ok_sel(w, fs, callback, file)
{
   @file = gtk_file_selection_get_filename (fs);
   gtk_widget_destroy(fs);
   if (callback != NULL)
     {
	variable sd = _stkdepth();
	@callback(@file);
	_pop_n(_stkdepth() - sd);
     }   
}


%!%+
%\function{jedgtk_select_file}
%\synopsis{select a file in a gtk dialog}
%\usage{ jedgtk_select_file() [Ref callback, String default]}
%\description
%   Pops up a gtk file selection dialog.  If a default argument is given, it
%   is set as default. If a callback argument is given. the function it refers
%   to is executed with the selected file.  Otherwise the selected file or
%   NULL if cancelled is returned.
%\notes
%   Any return values of the callback are popped.
%\seealso{jedgtk_find_file, jedgtk_select_file, jedgtk_write_buffer, jedgtk_insert_file}
%!%-
public define jedgtk_select_file() %(callback, default)
{
   variable callback, default, file = NULL;
   (callback, default) = push_defaults(,buffer_dirname(),_NARGS);
   variable filew;
   % Create a new file selection widget 
   filew = gtk_file_selection_new ("File selection");
   gtk_file_selection_hide_fileop_buttons (filew);

   () = g_signal_connect (filew, "destroy",
			  &gtk_main_quit, NULL);

   % Connect the ok_button to file_ok_sel function 
   () = g_signal_connect (gtk_file_selection_get_ok_button(filew),
			  "clicked",
			  &file_ok_sel, filew, callback, &file);
   
   % Connect the cancel_button to destroy the widget 
   () = g_signal_connect_swapped (gtk_file_selection_get_cancel_button(filew),"clicked",
				  &gtk_widget_destroy, filew);
   

   % set default filename
   if (default != NULL)
     gtk_file_selection_set_filename (filew,
				      default);

   gtk_widget_show (filew);
   gtk_main ();
   if (callback == NULL) return file;
}


%!%+
%\function{jedgtk_find_file}
%\synopsis{find a file in gtk dialog}
%\usage{ jedgtk_find_file()}
%\description
%   pops up a gtk file selection dialog and opens the selected file
%\seealso{jedgtk_select_file}
%!%-
public define jedgtk_find_file()
{
   jedgtk_select_file(&find_file);
}

%!%+
%\function{jedgtk_write_buffer}
%\synopsis{write a file in gtk dialog}
%\usage{ jedgtk_write_buffer()}
%\description
%   pops up a gtk file selection dialog and writes the buffer to the selected
%   file
%\notes
%   If the file exists, it is silently overwritten.  But it seems JED's
%   internal write_buffer does this as well.
%\seealso{jedgtk_select_file}
%!%-
public define jedgtk_write_buffer()
{
   jedgtk_select_file(&write_buffer, buffer_filename());
}

%!%+
%\function{jedgtk_insert_file}
%\synopsis{insert a file in gtk dialog}
%\usage{ jedgtk_insert_file()}
%\description
%   pops up a gtk file selection dialog and inserts the selected file
%\seealso{jedgtk_select_file}
%!%-
public define jedgtk_insert_file()
{
   jedgtk_select_file(&insert_file);
}
%!%+
%\function{jedgtk_write_region}
%\synopsis{write a region to a file in gtk dialog}
%\usage{ jedgtk_write_region()}
%\description
%   pops up a gtk file selection dialog and saves the region to the selected file
%\seealso{jedgtk_select_file}
%!%-
public define jedgtk_write_region()
{
   jedgtk_select_file(&write_region_to_file);
}

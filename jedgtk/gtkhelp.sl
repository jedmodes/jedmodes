% gtkhelp.sl
% online help for gtk
% 
% $Id: gtkhelp.sl,v 1.2 2004/06/28 11:04:02 paul Exp paul $
% Keywords: help
%
% Copyright (c) 2004 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This provides two forms of on-line help for developing slgtk scripts in
% JED.  With some tweaking it could be used for other APIs.  Here's how to
% use it:
% - install hyperhelp
% - bind the function  help_for_word_at_point() to a key, say F1.
% - put the file gtk_usage.txt in your JED library path
% - set the customvariables below
% - add this to .jedrc:
%   define slang_mode_hook()
%   {
%      define_blocal_var("help_for_word_hook", &maybe_gtk_help);
%   }
% 
% To get help for a slang function, press F1.  If it's a gtk function,
% you'll see a usage message in the minibuffer.  Press F1 again to get
% the full documentation for the corresponding gtk function (requires
% browse_url.sl).

if (_featurep("gtkhelp"))
  use_namespace("gtkhelp");
else
  implements("gtkhelp");
provide("gtkhelp");

custom_variable("Gtk_Help_Prefixes", "gtk,gdkpixbuf,gdk,g,pango");
custom_variable("Gtk_Help_Indexes", 
		"/usr/share/doc/libgtk2.0-doc/gtk/index.sgml.gz,/usr/share/doc/libgtk2.0-doc/gdk-pixbuf/index.sgml.gz,/usr/share/doc/libgtk2.0-doc/gdk/index.sgml.gz,/usr/share/doc/libglib2.0-doc/glib/index.sgml.gz,/usr/share/doc/libpango1.0-doc/pango/index.sgml.gz");
custom_variable("Gtk_Help_Dirs",
		"/usr/share/doc/libgtk2.0-doc,/usr/share/doc/libgtk2.0-doc,/usr/share/doc/libgtk2.0-doc,/usr/share/doc/libgtk2.0,/usr/share/doc/libglib2.0-doc,/usr/share/doc/libpango1.0-doc");
% The idea is that you set this to http://gtk.org (or wherever on the net your
% documentation is).  Dircat does not know how to concat urls.  You still need
% to store the index.sgml files locally, if they still have them (actually I
% think they now use ix01.html files)
custom_variable("Gtk_Help_Host", Null_String);

define gtk_help_for_word(word)
{
   variable prefix = extract_element(word, 0, '_');
   variable i = is_list_element(Gtk_Help_Prefixes, prefix, ',');
   !if (i) return;
   i--;
   () = read_file(extract_element(Gtk_Help_Indexes, i, ','));
   rename_buffer(sprintf (" *%s-help-index*", prefix));
   word = strtrans(strup(word), "_", "-");
   bob;
   if (re_fsearch(sprintf("^<ANCHOR id =\\\"%s\\\" href=\\\"\\(.*\\)\\\">", word)))
     browse_url(strcat(Gtk_Help_Host,dircat(extract_element(Gtk_Help_Dirs, i, ','), regexp_nth_match(1))));
   else message ("no help");
}

% Show usage information.
static variable gtk_usage_file = expand_jedlib_file("gtk_usage.txt");

define gtk_usage(word)
{
   !if (search_file(gtk_usage_file, sprintf("^%s(", word), 1))
     "no usage information";
   message(strtrim());
}

   
% help_for_word_hook for S-Lang mode
public define maybe_gtk_help(word)
{
   variable prefix = extract_element(word, 0, '_');
   variable i = is_list_element(Gtk_Help_Prefixes, prefix, ',');
   !if (i) return describe_function(word);
   if(LAST_KBD_COMMAND == "%gtk_short_help%")
     gtk_help_for_word(word);
   else
     {
	set_current_kbd_command("%gtk_short_help%");
	gtk_usage(word);
     }
}

% jedscapemisc.sl	-*- mode: Slang; mode: Fold -*-
% 
% $Id: jedscapemisc.sl,v 1.1.1.1 2004/10/28 08:16:23 milde Exp $
% Keywords: www, help, hypermedia
%
% Copyright (c) 2003 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
use_namespace("jedscape");

% Search function for jedscape, uses search++.  If you want to read the
% search++ manpage in jedscape, type /cgi-bin/man2html?search%2b%2b,
% since +'es are turned into spaces. Maybe I should urlencode everything
% after the ?

define index_get_url()
{
   variable href = extract_element(line_as_string, 1, ' ');
   pop2buf("*jedscape*");
   jedscape_get_url(expand_filename(path_concat(url_root,href)));
   pop2buf("*index search*");
}

public define jedscape_index_search()
{
   variable index =dircat(url_root, "swish++.index");
   if (1 != file_status(index))
     error ("Make a swish++ index first");
   variable line, word = read_mini("Search for", "", "");
   setbuf("*index search*");
   set_readonly(0);
   bob;
   erase_buffer;
   variable return_code =run_shell_cmd(sprintf ("search++ --index-file=%s %s", index, word));
   switch(return_code)
     { case 0: }
     { case 2: error ("Error in command-line options."); }
     { case 40: error ("Could not find index"); }
     { case 50: error ("Malformed query"); }
     { verror ("search++ returned error: %d", return_code);}
   bob;
   if (looking_at("# results: 0")) error ("No matches");
   popup_buffer(whatbuf);
   fit_window(10);
   view_mode;
   set_buffer_hook("newline_indent_hook", &index_get_url);
}

public define jedscape_add_bookmark()
{
   variable bookmark_title = read_mini("bookmark name", title, "");
   if (-1 == append_string_to_file (sprintf("%s\t%s\n", bookmark_title, url_file), Jedscape_Bookmark_File))
     message ("could not add bookmark");
   else
     message ("bookmark added");
}

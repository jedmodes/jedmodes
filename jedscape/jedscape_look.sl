% jedscape_look.sl	-*- mode: Slang; mode: Fold -*-
% 
% $Id: jedscape_look.sl,v 1.1.1.1 2004/10/28 08:16:23 milde Exp $
% Keywords: www, help, hypermedia
%
% Copyright (c) 2003 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% Functions for using the help_for_word_hook with jedscape.
% Define 2 or 3 blocals in your mode-hook:
% -help_for_word_hook: set to jedscape_lookup
% -jedscape_look_path: set to the path where the html files are
%  The hook will try to open "word.html"
% -jedscape_look_hook: set this when the word needs some more processing
%  to match a help file, as in the case of PHP (see below). Set it to
%  a function that gets a reference to the word.

define jedscape_lookup(word)
{
   variable path = get_blocal("jedscape_look_path", "");
   if (path == "") error ("no look path set");
   run_blocal_hook("jedscape_look_hook", &word);
   variable url = search_path_for_file(path, word + ".html");
   if (url == NULL) error ("no help found");
   jedscape_get_url(url);
}


% examples for HTML and PHP

% You can get the HTML 4.0 reference at
% http://www.htmlhelp.com/distribution/wdghtml40.tar.gz
define html_mode_hook()
{
   define_blocal_var("jedscape_look_path", strjoin
		     ("/usr/share/doc/wdg-html-reference/html40/" +
		      ["block,","fontstyle,","forms,","frames,","head,",
		       "html,","lists","phrase","special","tables"], ","));
   define_blocal_var("help_for_word_hook", "jedscape_lookup");
}

% get the php documentation at http://www.php.net/download-docs.php
define php_help_translate(word)
{
   @word = strreplace(@word, "_", "-", 100), pop;
   % why is (@word, ) = ... illegal?
   @word="function." + @word; 
}

define php_mode_hook()
{
   define_blocal_var("jedscape_look_path", "/usr/share/doc/phpdoc/html");
   define_blocal_var("jedscape_look_hook", "php_help_translate");
   define_blocal_var("help_for_word_hook", "jedscape_lookup");
}
   

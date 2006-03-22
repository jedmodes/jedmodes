% ffap.sl
% 
% $Id: ffap.sl,v 1.6 2006/03/22 09:08:38 paul Exp paul $
% 
% Copyright (c) 2003-2006 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% Find File At Point, something like Emacs' ffap.  You can use this as a
% replacement for find_file() by adding
% require("ffap");
% setkey("ffap", "^x^f); or whatever you use for find_file
% to .jedrc


%!%+
%\variable{Ffap_URL_Reader}
%\synopsis{Function to open a URL}
%\usage{variable Ffap_URL_Reader = "find_url"}
%\description
% "browse_url"  open the URL in an external browser
% "find_url"    open the URL in a jed buffer (as is)
% "view_url"    open an ASCII rendering of the URL in a jed buffer
%\seealso{ffap}
%!%-
custom_variable("Ffap_URL_Reader", "find_url");


%!%+
%\variable{Ffap_Prompt_Level}
%\synopsis{Should a file|dir|URL be opened with prompt?}
%\usage{variable Ffap_Prompt_Level = 3}
%\description
%    0: no (if file|dir|URL could be guessed from the word-at-point)
%    1: only when the extension is added from the Ext-list
%    2: always except for an URL
%    3: always (even for an URL)
%\seealso{ffap}
%!%-
custom_variable("Ffap_Prompt_Level", 3);

autoload("get_word", "txtutils");
autoload("dired_read_dir", "dired");

variable rimini_array;
%{{{ helper fun

%!%+
%\function{add_list_element}
%\synopsis{prepend an element to a string with delimiters}
%\usage{String_Type add_list_element(String_Type list, String_Type elem,Integer_Type delim)}
%\description
%   If \var{elem} is not an element of \var{list}, return the concatenation
%   of \var{elem} and \var{list} with delimiter \var{delim}, otherwise
%   return \var{list}.
%   
%\seealso{is_list_element, extract_element, create_delimited_string}
%!%-
public  define add_list_element(list, elem, delim)
{
   if (strlen(elem) and not is_list_element(list, elem, delim))
     {
	if (strlen(list))
	  return sprintf("%s%c%s", elem, delim, list);
	else
	  return elem;
     }
   return list;
}

%}}}

%{{{ ffap data

% This struct holds the mode-specific info
!if (is_defined("ffapvars"))
  typedef struct
{
   ext, path, always
} ffapvars;

variable ffap_info = Assoc_Type [ffapvars];

%!%+
%\function{ffap_set_info}
%\synopsis{set the ffap custom variables for a mode}
%\usage{ ffap_set_info(mode, ext, path, always)}
%\description
%   Use \sfun{ffap_set_info} to customize the behavior of \sfun{ffap} when the buffer
%   is in mode \sfun{mode}.
%   \var{ext}: a list of extensions that may have been left out 
%              e.g. in SLang ".sl" as in
%#v+
% autoload("get_word", "txtutils");	%  -> txtutils.sl
% autoload("dired_read_dir","dired");
% autoload("recent_get_files", "recent");
%#v-
%  \var{Path}: the search path (I always look in the buffer dir at least,
%   but not in subdirectories).  For SLang: your library path.
%  \var{Always}: determines if you want a new file if the file doesn't
%   exist.
%   0: no
%   1: yes  
%   2: only if word ends in one of the exts.  May make sense in html mode.
%   3: Open a new file appending the extension listed first in exts to word.
%\example
%  for C mode, you'll use something like
%#v+
% ffap_set_info("C",".h,.c,.C", "/usr/include,/usr/local/include/", 2);
%#v-
%   
%\seealso{ffap}
%!%-
public  define ffap_set_info(mode, ext, path, always)
{
   ffap_info[mode] = @ffapvars;
   ffap_info[mode].ext = ext;
   ffap_info[mode].path = path;
   ffap_info[mode].always = always;
}

ffap_set_info("SLang", ".sl", get_jed_library_path, 2);

%}}}

%{{{ finding the file at point

% Get the word at point and try to match it to a valid file|dir|URL
% Return the guess and a status indicator 
% USAGE (file, status) = ffap_find()
%   status: -1  no valid file found
%   	     0  file is found after some guessing
%            1  'file' is a valid file
%            2  'file' is a directory
%            3  'file' is a URL
static define ffap_find()
{
   variable mode, path = "", exts= "", always = 0, 
     word, file, this_file, dir, ext;
   (mode, ) = what_mode;
   if (assoc_key_exists(ffap_info, mode))
     {
	exts = ffap_info[mode].ext;
	path = ffap_info[mode].path;
	always = ffap_info[mode].always;
     }
   % Simple scheme to separate a path or URL from context
   % will not work for filenames|URLs with spaces or "strange" characters.
   word = get_word("-a-zA-z_.0-9~/+:?=&\\");
   word = strtrim_end(word, ".+:?");
   !if (strlen(word)) 
     return("", -1);
   % check for URI
   if ((is_substr(word, "http://")==1) or (is_substr(word, "ftp://")==1))
     return(word, 3);
   
   (this_file, dir, ,) = getbuf_info;
   switch (file_status(dircat(dir, word)))
     { case 1: return (word, 1); } % file in buffer-dir or absolute filename
     { case 2: return(word, 2); }  % dir in buffer-dir or absolute dirname

   if(path_is_absolute(word))
     {
	path = path_dirname(word);
	word = path_basename(word);
     }
   else
     {
	path = add_list_element(path, strtrim_end(dir, "/"), ',');
	if (strncmp(word, ".", 1)) % this is to look for dotfile in HOME
	  path = add_list_element(path, getenv("HOME"), ',');
     }
   !if (strlen(word)) 
     return ("", -1);

   % exts = add_list_element(exts, path_extname(this_file), ',');
   file = search_path_for_file(path, word);   %  try file 'as is'
   if (file != NULL)
        return (file, 1);  % found with original extension
   foreach (strchop(exts, ',', 0))     %  try with ext
     {
	ext = ();
	file = search_path_for_file(path, word + ext);
	if (file != NULL)
	  break;
	if (path_extname(word) == ext)
	  {
	     if (always > 1)
	       always = 1;
	     break;
	  }
     }
   if (file != NULL)		       
     return (file, 0);
   
   % eventually open a new (empty) file
   switch (always)
     { case 1: file = word; }
     { case 3: file = word + extract_element(exts, 0, ','); }
     { file = ""; }
   return (file, -1);
}

%!%+
%\function{ffap}
%\synopsis{Find File At Point}
%\usage{ffap()}
%\description
%   \sfun{ffap} is meant as an extension of \sfun{find_file}. It checks if
%   the word at point is a filename, or can be expanded to a filename.  It
%   then prompts for a filename, with the expanded filename if any as default,
%   and opens the file using the intrinsic \sfun{find_file}, not the internal
%   one.  The difference is that when the user enters a directory, the internal
%   \sfun{find_file} will expand it to the filename of the working buffer in
%   the directory entered, with the intrinsic \sfun{find_file} you can set
%   your own handling of directories in the _jed_find_file_before_hooks.
%\seealso{ffap_set_info, Ffap_Prompt_Level, Ffap_URL_Reader, filelist_list_dir}
%!%-
public define ffap()
{
   variable file, status;
   (file, status) = ffap_find;
   if (status == 3) % URL
     {
	if (is_defined(Ffap_URL_Reader))
	  {
	     if (Ffap_Prompt_Level >= 3)
	       file = read_mini("Find URL:", "", file);
	     runhooks(Ffap_URL_Reader, file);
	     return;
	  }
	file = "";
	status = -1;
     }
   if (Ffap_Prompt_Level - status > 0)
     {
	if (is_defined("recent_get_files"))
	  rimini_array=runhooks("recent_get_files");
	ERROR_BLOCK { rimini_array = NULL; }
	file = read_with_completion("Find file:", "", file, 'f');
	EXECUTE_ERROR_BLOCK;
     }
   () = find_file(file);
}

%}}}

provide("ffap");

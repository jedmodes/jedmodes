% ffap.sl  -*- mode: SLang; mode: fold -*-
% 
% $Id: ffap.sl,v 1.4 2003/09/15 07:00:18 paul Exp paul $
% Keywords: files, hypermedia, convenience
% 
% Copyright (c) 2003 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% Find File At Point, something like Emacs' ffap.  Install by adding 
% 
% require("ffap");
% setkey("ffap", "^x^f); or whatever you use for find_file
% 
% to your .jedrc, then add
% ffap_set_info(mode, ext, path, always)
% 
% for every mode for which you want some custom settings.
%  -Ext: a list of extensions that may have been left out 
%   e.g. in SLang ".sl" as in
autoload("get_word", "txtutils");	%  -> txtutils.sl
autoload("dired_read_dir", "dired");
autoload("recent_get_files", "recent");
%  -Path: the search path (I always look in the buffer dir at least,
%   but not in subdirectories).  For SLang: your library path.
%  -Always: determines if you want a new file if the file doesn't
%   exist.
%   0: no  
%   1: yes  
%   2: only if word ends in one of the exts.  May make sense in html mode.
%   3: Open a new file appending the extension listed first in exts to word.
%      This may make sense in outline mode - define an extension:
%      add_mode_for_extension("outline", "outline");
%      ffap_set_info("outline", ".outline", "", 3);
%      and do hierarchical and non-hierarchical outlining in one mode.
%
% For SLang I have a setting, for C add something like
% ffap_set_info("C", ".h,.c,.C", "/usr/include,/usr/share/include/,/usr/X11R6/include/", 2);
% 
% Using: Just move the cursor to "txtutils", hit ^x^f and enter!  If the 
% file "txtutils" is in the path it should now be opened.  If the word at
% point is a directory (absolute or relative to the buffer dir) it will be
% opened in dired without prompt.  If you prefer filelist-mode add
% define dired_read_dir(dir)
% {
%    filelist_list_dir(dir);
% }

variable rimini_array;
%{{{ helper fun

%!%+
%\function{add_list_element}
%\synopsis{prepend an element to a string with delimiters}
%\usage{String_Type add_list_element(String_Type list, String_Type elem, Integer_Type delim)}
%\description
%   If \var{elem} is not an element of \var{list}, return the 
%   concatenation of \var{elem} and \var{list} with delimiter 
%   \var{delim}, otherwise return \var{list}.
%   
%\seealso{is_list_element, extract_element, create_delimited_string}
%!%-
public define add_list_element(list, elem, delim)
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

public define ffap_set_info(mode, ext, path, always)
{
   ffap_info[mode] = @ffapvars;
   ffap_info[mode].ext = ext;
   ffap_info[mode].path = path;
   ffap_info[mode].always = always;
}

ffap_set_info("SLang", ".sl", get_jed_library_path, 2);

%}}}

%{{{ finding the file at point

% Try to match dir/word*
% I know about directory() but it beeps.
static define file_complete (dir, word)
{
   variable pathname, basename, dirname, n, dirlist, matches;
   pathname = expand_filename(dircat(dir, word));
   dirname = path_dirname(pathname);
   if (2 != file_status(dirname)) return NULL;
   basename = path_basename(pathname);
   n = strlen(basename);
   dirlist = listdir(dirname);
   matches = dirlist[where(not array_map(Integer_Type, 
					 &strncmp, dirlist, basename, n))];
   if (1 == length(matches)) return dircat(dirname, matches[0]);
   return NULL;
}

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
   word = strtrim_end(get_word("-a-zA-z_.0-9~/\\"), ".");
   
   !if (strlen(word)) return "";
   (this_file, dir, ,) = getbuf_info;
   if (2 == file_status(dircat(dir, word)))
     return word;  % search_path_for_file doesn't do dirs

#ifdef IBMPC_SYSTEM
   if (word[0] == '\\')
#else
   if (word[0] == '/')
#endif
     {
	path = path_dirname(word);
	word = path_basename(word);
     }
   else
     {
	path = add_list_element(path, dir[[:-2]], ',');
	if (word[0] == '.')	       %  ^ dir ends in '/'
	  path = add_list_element(path, getenv("HOME"), ',');
     }
   !if (strlen(word)) return "";

   exts = add_list_element(exts, path_extname(this_file), ',');
   file = search_path_for_file(path, word);   %  try file
   foreach (strchop(exts, ',', 0))     %  try with ext
     {
	ext = ();
	if (file != NULL)
	  break;
	if (word[[-strlen(ext) : ]] == ext)
	  {
	     if (always > 1)
	       always = 1;
	     break;
	  }
	file = search_path_for_file(path, word + ext);
     }
   if (file == NULL)		       %  try globbing
     file = file_complete(dir, word);
   if (file == NULL)		       % nothing worked!  
     {
	if (always == 3)
	  return word + extract_element(exts, 0, ',');
	if (always == 1) return word;
     }
   if (file == NULL) return "";
   return file + " "; % the space should cause JED to shorten the path
}

public define ffap()
{
   variable file = ffap_find;
   if (2 == file_status(file))
     dired_read_dir(file);
   else
     {
	if (is_defined("recent_get_files"))
	  rimini_array = &recent_get_files;
	buffer_keystring(file);
	ERROR_BLOCK
	  {
	     rimini_array = NULL;
	  }
	call("find_file");
	EXECUTE_ERROR_BLOCK;
     }
}

%}}}

provide("ffap");

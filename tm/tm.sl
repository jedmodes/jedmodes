% tm.sl
% tm documentation parser
%
% $Id$
% Keywords: slang, doc, tools
%
% Copyright (c) 2004 Paul Boekholt, Guenter Milde
% Released under the terms of the GNU GPL (version 2 or later).
%
% This extracts tm documentation from S-Lang sources the *hard* way. It
% uses string operations, so it should be easy to port to slrn and slsh.
% The tm.sed sed-script is *much* simpler and probably much faster, but
% this may be useful for:
%
%  - windows users who don't have sed
%  - jed hackers who want to preview their tm documentation.
%  - incorporating into other slang scripts (make_ini)
%
%  2005-03-18  added tm documentation
%              new function tm_make_ascii_doc (transfered from make_ini())
%  2005-03-21  rework of tm_make_ascii_doc, tm2ascii called file-wise
%              -> speedup by factor 3...6 (PB)
%  2005-03-22  tm_extract with array_map instead of regexp parsing (GM)
%  2005-03-23  block-wise tm2ascii conversion in tm_get_block()
%              replaced tm_parse() with parse-argument in tm_extract (GM)
%  2005-03-31  restructuring code: (avoid temp file for tm-preview)
%                tm_get_blocks()  -- return array of tm-documentation blocks
%                tm_parse()       -- reintroduced
%  	         tm_make_ascii_doc() and tm_preview() united to
%  	         tm_view([args])  -- args are filenames to extract doc from
%  	                             no arg: extract from current buffer/region
%
%  TODO: let this work for tm-documented C-code too

_debug_info=1;

autoload("str_re_replace_all", "strutils");
autoload("arrayread_file", "bufutils");
autoload("get_lines", "csvutils");
autoload("view_mode", "view");
autoload("_implements", "sl_utils");

% set up namespace
_implements("tm");

static variable Tm_Doc_Buffer = "*tm doc*";

% convert a string with tm-markup to ASCII representation
static define tm2ascii(str)
{
   % indent by 2 spaces. Usually there are already some spaces.
   % Maybe this should be a regexp replace.
   % str = str_replace_all(str, "\n", "\n  ");

   variable pos, len;

   % Blocks (function or variable descriptions)
   str = str_replace_all(str, "\\done", "-----------------------------------");

   %  \function or \variable
   str = str_re_replace_all
     (str, "\\\\function{\\([^\}]+\\)}", "\\1");
   str = str_re_replace_all
     (str, "\\\\variable{\\([^\}]+\\)}", "\\1");
   % \var, \em
   str = str_re_replace_all
     (str, "\\\\var\{\\([^\}]+\\)\}", "`\\1'");
     % this breaks generated doc and tm_preview in jed <= 99.17
     % (str, "\\\\var\{\\([^\}]+\\)\}", "\e[1m\\1\e[0m");
   str = str_re_replace_all
     (str, "\\\\em{\\([^\}]+\\)}", "_\\1_");
   % sections
   str = str_re_replace_all
     (str, "\\\\synopsis{\\([^\}]+\\)}", "\n SYNOPSIS\n  \\1");
   str = str_replace_all(str, "\n\\synopsis{}", "");
   str = str_re_replace_all
     (str, "\\\\usage{\\([^\}]+\\)}", "\n USAGE\n  \\1");
   str = str_replace_all(str, "\n\\usage{}", "");
   str = str_re_replace_all
     (str, "\\\\seealso{\\([^\}]+\\)}", "\n SEE ALSO\n  \\1");
   str = str_replace_all(str, "\n\\seealso{}", "");
   str = str_replace_all(str, "\\example", "\n EXAMPLE");
   str = str_replace_all(str, "\\description", "\n DESCRIPTION");
   str = str_replace_all(str, "\\notes", "\n NOTES");

   % verbatim - it's not likely that there's tm markup in verbatim sections,
   % otherwise we'd have to split and parse the tm verbatim-wise.
   variable pos2, len2;
   while(string_match(str, "\n[ \t]*#v+", 1))
     {
	(pos, len) = string_match_nth(0);
	!if (string_match(str, "\n[ \t]*#v-", pos + len)) break;
	(pos2, len2) = string_match_nth(0);
	variable v_str = str[[pos + len + 1: pos2 - 1]];
	v_str = str_replace_all(v_str, "\n", "\n ");
	v_str = str_replace_all(v_str, "\\", "\\\\");
	str = strcat(str[[:pos]], "\n",
	       v_str,
	       "\n", str[[pos2+len2:]]);
     }
   str = str_replace_all(str, "\\\\", "\\");
   return str;
}

% extract a tm-documentation block from an array of lines 
% the lines-array is given as pointer, so that the function will work in
% an array_map (it would fail else because of the different size of lines 
% and beg_index/end_index).
static define tm_get_block(beg_index, end_index, linesref)
{
   variable lines = @linesref;
   % show(length(@lines), beg_index, end_index);
   % show(lines[[beg_index:end_index]]);
   variable block = lines[[beg_index+1:end_index-1]];
   % remove comments
   block = array_map(String_Type, &strtrim_beg, block, "%");
   block = strjoin(block, "") + "\\done\n\n";
   return block;
}

% Extract tm-documentation blocks from an array of lines
% Return as String-array of blocks
static define tm_get_blocks(lines)
{
   variable tmmarks, beg_marks, end_marks, blocks;

   % get the line numbers of all tm-marks
   tmmarks = array_map(Int_Type, &strncmp, lines, "%!%", 3);
   tmmarks = where(tmmarks == 0);
   % show(tmmarks, lines[[tmmarks]]);
   !if (length(tmmarks))
     return String_Type[0];
   
   % get the line-numbers of beg and end tmmarks
   beg_marks = array_map(Integer_Type, &strncmp, lines[[tmmarks]], "%!%+", 4);
   beg_marks = tmmarks[[where(beg_marks == 0)]];
   end_marks = array_map(Integer_Type, &strncmp, lines[[tmmarks]], "%!%-", 4);
   end_marks = tmmarks[[where(end_marks == 0)]];
   if (length(beg_marks) == 0 or length(end_marks) == 0)
     return String_Type[0];
   if (length(beg_marks) != length(end_marks))
     error("tm-block marks don't match");
   % show(beg_marks, end_marks);
   
   return array_map(String_Type, &tm_get_block, beg_marks, end_marks, &lines);
}
  
  
%!%+
%\function{tm_extract}
%\synopsis{Extract tm documentation blocks from a file}
%\usage{String tm_extract(String filename)}
%\description
%  Return a string with the tm documentation contained in file
%  \var{filename} in the \var{tm} format used by the *.tm files
%  of jed and slang documentation.
%\example
%  To get the tm-doc of a file, do e.g.
%#v+
%      variable tm_doc_str = tm_extract("tm.sl", 0);
%#v-
%\notes
%  Currently, this only works with SLang files.
%  TODO: let it work for tm blocks in C files too.
%\seealso{tm_parse, tm_mode, tm_make_doc, tm->tm2ascii}
%!%-
public define tm_extract(filename)
{
   variable blocks = tm_get_blocks(arrayread_file(filename));
   return strjoin(blocks, "");
}


%!%+
%\function{tm_parse}
%\synopsis{Return ASCII-version of a files tm-documentation blocks}
%\usage{String tm_parse(String filename)}
%\description
%  Parse a file for tm-documentation blocks and convert them to
%  ASCII with tm2ascii.
%\example
%#v+
%   variable doc_str = tm_parse("tm.sl");
%#v-
%\seealso{tm_view, tm_extract}
%!%-
public define tm_parse(filename)
{
   % extract documentation blocks
   variable blocks = tm_get_blocks(arrayread_file(filename));
   !if (length(blocks))
     return "";
   % convert to ASCII
   blocks = array_map(String_Type, &tm2ascii, blocks);
   % return as string
   return strjoin(blocks, "");
}
   
   
%!%+
%\function{tm_view}
%\synopsis{Extract tm documentation, convert to ASCII and show in a buffer}
%\usage{tm_view([args])}
%\description
%  Extract tm documentation from given files or (with emty argument list)
%  the current buffer or (if defined) region.
%  Convert to ASCII and show in a buffer.
%\example
%  View tm-documentation from current buffer (or region):
%#v+
%    tm_view();
%#v-
%  View tm-documentation from all Slang files in the current directory:
%#v+
%    tm_view(directory("*.sl"), pop());
%#v-
%\seealso{tm_parse, tm_extract, tm->tm2ascii}
%!%-
public define tm_view() % ([args])
{
   variable filename, str="";
   
   flush("extracting documentation");
   !if (_NARGS)
     {
	% extract documentation blocks
	variable blocks = tm_get_blocks(get_lines()+"\n");
	% convert to ASCII
	if (length(blocks))
	  blocks = array_map(String_Type, &tm2ascii, blocks);
	% insert
	str = strjoin(blocks, "");
     }
   else
     loop(_NARGS)
       {
	  filename = ();
	  str += tm_parse(filename);
       }
   vmessage("extracted documentation from %d files", _NARGS);
   
   if (str == "")
     return message("no tm-documentation found");
     
   sw2buf(Tm_Doc_Buffer);
   set_readonly(0);
   erase_buffer();
   insert(str);
   % bob();
   view_mode();
}


_add_completion("tm_parse", "tm_view", 2);

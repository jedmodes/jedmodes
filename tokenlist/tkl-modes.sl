% tkl-modes.sl: Customization for the list_routines() function 
%               from tokenlist.sl
%               
% Copyright (c) 2006 Marko Mahnic
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
%   2006-03-29  outsourced from tokenlist.sl
%   2006-11-17  G. Milde
%               removed rst definitions (in rst.sl since version 1.4)
%               added php definitions
%               use raw strings for latex definitions
%   2006-12-19  Marko Mahnic
%               changed the interface to use _list_routines_setup
%               (the old interface still works)
%   2007-05-09  Marko Mahnic
%               renamed list_regex -> list_regexp
%               fixed PHP and Python setup

autoload("tkl_sort_by_value", "tokenlist");
autoload("tkl_sort_by_line", "tokenlist");
provide("tkl-modes");


%%  
%%        C
%%  
private define c_list_routines_extract (nRegexp)
{
   push_spot();
   if (ffind_char(';')) {
      pop_spot();
      return Null_String;
   }
   pop_spot();
   if (nRegexp == 0) {
      () = ffind_char ('(');         % Extract function name
      bskip_chars (" \t");
      () = bfind ("::");             % Skip operator header
      bskip_chars ("a-zA-Z0-9_:");

      push_mark();
      eol();
      return (bufsubstr());
   }
   else if (nRegexp == 1) {
      push_mark();
      eol();
      return (bufsubstr());
   }
   else return (line_as_string());
   
   return Null_String;
}

define c_list_routines_setup (opt)
{
   opt.list_regexp = { 
      "^[a-zA-Z_][a-zA-Z0-9_]*[ \t*&].*(",  % Ordinary function or method
      "^[a-zA-Z_][a-zA-Z0-9_]*::~.+("       % Destructor
   };
   opt.fn_extract = &c_list_routines_extract;
   opt.onlistcreated = &tkl_sort_by_value;
}

%%  
%%        SLang
%%  

% Discard the public|static|private part of the definition
private define slang_list_routines_extract (nRegexp)
{
   bol();
   % skip static, public
   if (nRegexp >= 2) {
      skip_chars ("a-z");
      skip_chars (" ");
   }
   push_mark();
   eol();
   return (strtrim(bufsubstr()));
}

define slang_list_routines_setup(opt)
{
   opt.list_regexp = { 
      "^define[ \t]",
      "^variable[ \t]",
      "^public[ \t]+[dv]",
      "^private[ \t]+[dv]",
      "^static[ \t]+[dv]"
   };
   opt.fn_extract = &slang_list_routines_extract;
   opt.onlistcreated = &tkl_sort_by_value;
}


%%  
%%        HTML
%% 
define html_list_routines_setup(opt)
{
   opt.list_regexp = { 
    "^[ \t]*<H[1-9][ \t>]",
    "^[ \t]*<TABLE[ \t>]",
    "^[ \t]*<FORM[ \t>]"
   };
}

%%  
%%        LaTeX
%%  
define latex_list_routines_setup(opt)
{
   opt.list_regexp = { 
    "\\section"R,
    "\\\(sub\)*section"R,
    "\\subsubsection"R
   };
}

%%
%% PHP
%%
define php_list_routines_setup(opt)
{
   opt.list_regexp = { 
      "^class[ \t]",
      "^function[ \t]"
   };
}

%%  
%%        Python
%%  
define python_list_routines_setup(opt)
{
   opt.list_regexp = { 
      "^[ \t]*def[ \t]",
       "^[ \t]*class[ \t]"
   };
   opt.onlistcreated = &tkl_sort_by_line;
}

#iffalse
%%  
%%  New C
%%  Might work better for C
%%  Works worse for C++      
%%

autoload("c_bskip_over_comment", "cmode");

private define do_c_find_candidate(i)
{
   return bol_fsearch("{");
}

variable c_list_routines_regexp = 
{
   &do_c_find_candidate
};

define c_list_routines_extract (nRegexp)
{
   if (0 != parse_to_point ()) return Null_String;
   c_bskip_over_comment (1);
   if (blooking_at (")"))
   {
      go_left_1 ();
      if (1 == find_matching_delimiter (')'))
      {
         c_bskip_over_comment (1);
         bskip_white();
         if (bolp()) go_up(1);
         return line_as_string();
      }
   }
   return Null_String;
}
#endif

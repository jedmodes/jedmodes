require("tokenlist");

%%%%%%%%%%%%%%%%%%%%%%%%%%%  MODES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%  
%%        C
%%  
variable c_list_routines_regexp = 
{     "^[a-zA-Z_][a-zA-Z0-9_]*[ \t*&].*(",  % Ordinary function or method
      "^[a-zA-Z_][a-zA-Z0-9_]*::~.+("       % Destructor
};

define c_list_routines_extract (nRegexp)
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

define c_list_routines_done()
{
   tkl_sort_by_value();
}

%%  
%%        SLang
%%  
variable slang_list_routines_regexp =
{     "^define[ \t]",
      "^variable[ \t]",
      "^public[ \t]+[dv]",
      "^private[ \t]+[dv]",
      "^static[ \t]+[dv]"
};

define slang_list_routines_extract (nRegexp)
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

define slang_list_routines_done()
{
   tkl_sort_by_value();
}

provide("tokenlist");

%%  
%%        HTML
%%  
variable html_list_routines_regexp =
   [
    "^[ \t]*<H[1-9][ \t>]",
    "^[ \t]*<TABLE[ \t>]",
    "^[ \t]*<FORM[ \t>]"
    ];

%%  
%%        LaTeX
%%  
variable latex_list_routines_regexp =
   [
    "\\\\section",
    "\\\\\\(sub\\)*section",
    "\\\\subsubsection"
    ];

%%  
%%        Python
%%  
variable python_list_routines_regexp =
   ["^[ \t]*def[ \t]",
    "^[ \t]*class[ \t]"
    ];

define python_list_routines_extract (nRegexp)
{
   bol();
   push_mark();
   eol();
   return (bufsubstr());
}

define python_list_routines_done()
{
   tkl_sort_by_line();
}

%%  
%%        reStructuredText
%%  
private variable rst_levels = NULL;
variable rst_list_routines_regexp =
{
   "^[!-/:-@\\[-`{-~]+"
};

private define get_rst_level(ch)
{
   variable lev, N;
   if (rst_levels == NULL) rst_levels = {};
   N = length(rst_levels);
   for (lev = 0; lev < N; lev++)
      if (rst_levels[lev] == ch) return lev;
   
   list_append(rst_levels, ch);
   return N;
}

define rst_list_routines_extract (nRegexp)
{
   variable ch, col, sec, fmt;
   ch = what_char();
   skip_chars(sprintf("%c", ch));
   col = what_column();
   skip_white();
   !if (eolp()) return Null_String;

   if (1 == up(1))
   {
      eol();
      bskip_white();
      if ( not bolp() and what_column() <= col)
      {
         push_mark();
         bol_skip_white();
         sec = bufsubstr();
         fmt = sprintf(".%%%ds%%s", -get_rst_level(ch));
         return(sprintf(fmt, "", sec));
      }
   }
   
   return Null_String;
}

define rst_list_routines_done()
{
   rst_levels = NULL;
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

provide("tkl-modes");

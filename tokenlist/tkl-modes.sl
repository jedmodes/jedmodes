require("tokenlist");

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

define latex_list_routines_hook()
{
   % tkl_sort_by_line();
}

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
   return ("." + bufsubstr());
}

define python_list_routines_hook()
{
   tkl_sort_by_line();
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

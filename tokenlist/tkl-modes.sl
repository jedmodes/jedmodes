require("tokenlist");
provide("tkl-modes");

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

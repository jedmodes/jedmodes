% -*- mode:SLang; mode:fold; -*-
%
% file: tokenlist.sl    v1.00
% Author: Marko Mahnic
%

%% Installation:
%%  
%%    Put on your jed_library_path and in .jedrc: 
%%    AUTOLOAD: 
%%      list_routines                          for routine searching
%%      occur                                  overrides the default occur
%%      (tkl_list_tokens, tkl_display_results  for further extensions)
%%    OR:
%%      require("tokenlist");
%% 
%%    Example keybindings:
%%      setkey("list_routines", "^R");
%%      setkey("occur", "^O");
%% 
%%    To add more language definitions for list_routines:
%%      reqiure("tkl-modes");
%%      
%% When the results are displayed in token list:
%%    f, SPACE:   display selected line in other buffer
%%    g, RETURN:  goto selected line, close tokel list
%%    i, s:       isearch_forward
%%    r, /:       filter the displayed results (hides nonmatching lines)
%%    
%% Extending:
%%    To use list_routines in a new mode MODENAME:
%% 
%%    for mode MODENAME write:
%%       variable MODENAME_list_routines_regexp = ["regexp0", "regexp1",...];
%%          A set of regular expressions.
%% 
%%       String   MODENAME_list_routines_extract  (Integer I)
%%          Extractor function to extract the match from the currnet
%%          buffer. I is the index of the regexp in the array.
%%          If it is not defined, the default _list_routines_extract
%%          extracts the whole current line.
%% 
%%       Void MODENAME_list_routines_hook (Void)
%%          Optional. When this hook is called, the buffer with
%%          the extracted lines is the current buffer.
%% 
%% See tkl_list_tokens().
%% 
%% Changes:
%%   2006-03-08 Marko Mahnic
%%     - added isearch and filter commands
%%     - documented
%%     

private variable tkl_TokenBuffer = "*TokenList*";
private variable tkl_ExtractMacro = "_list_routines_extract";

%% Function: tkl_list_tokens
%% \usage{Void tkl_list_tokens (String[] arr_regexp, String fn_extract)}
%% Parameters:
%%    arr_regexp: a string or an array of strings representing regular expression(s)
%%                to search for
%%    fn_extract: a string with the name of a function which takes one integer parameter 
%%                and returns a string (usually the extracted line).
%% 
%% tkl_list_tokens searches for a set of regular expressions defined
%% by an array of strings arr_regexp. For every match tkl_list_tokens
%% calls the function defined in the string fn_extract with an integer
%% parameter that is the index of the matched regexp. At the time of the
%% call, the point is at the beginning of the match.
%% 
%% The called function should return a string that it extracts from 
%% the current line.
%% 
define tkl_list_tokens (arr_regexp, fn_extract) %{{{
{
   variable buf = whatbuf(), line, token;
   setbuf (tkl_TokenBuffer);
   set_readonly (0);
   erase_buffer ();
   vinsert ("Buffer: %s\n", buf);
   setbuf (buf);

   if (String_Type == typeof(arr_regexp)) arr_regexp = [arr_regexp];
   if (fn_extract == Null_String or fn_extract == NULL) 
      fn_extract = tkl_ExtractMacro;
   
   push_spot();
   bob();

   variable i;
   for (i = 0; i < length(arr_regexp); i++)
   { 
      % The array may be larger than the number of needed regular expressions.
      % We can end the search with a Null_String.
      if (arr_regexp[i] == Null_String) break;
      
      while (re_fsearch (arr_regexp[i]))
      {
	 push_spot();
	 eval (sprintf ("%s(%ld)", fn_extract, i));
	 token = ();
	 pop_spot();
	 while (str_replace(token, "\n", " ")) token = ();
	 token = strtrim(token);

	 !if (token == Null_String)
	 {
	    line = what_line();
	    setbuf (tkl_TokenBuffer);
	    vinsert ("%6d: %s\n", line, token);
	    setbuf (buf);
	 }
	 
	 go_down(1);
	 bol();
      }
      
      bob ();
   }

   pop_spot();
   
   setbuf (tkl_TokenBuffer);
   bob ();
   set_buffer_modified_flag (0);
   set_readonly (1);

   setbuf (buf);
}

%}}}


%% #######################################################################
%% #####################  DISPLAY OF RESULTS #############################
%% #######################################################################
%{{{

$1 = "tokenlist";
!if (keymap_p ($1))
{
   make_keymap ($1);
}

definekey ("tkl_display_token", " ", $1);
definekey ("tkl_display_token", "f", $1);
definekey ("tkl_goto_token", "\r", $1);
definekey ("tkl_goto_token", "g", $1);
definekey ("isearch_forward", "s", $1);
definekey ("isearch_forward", "i", $1);
definekey ("tkl_filter_list", "r", $1);
definekey ("tkl_filter_list", "/", $1);

% \usage{(String, Int) tkl_get_token_info()}
private define tkl_get_token_info()
{
   variable line, buf;
   
   setbuf (tkl_TokenBuffer);
   push_spot();
   bob ();
   () = ffind_char (':');
   go_right (2);
   push_mark();
   eol ();
   buf = bufsubstr();
   
   pop_spot(); bol ();
   if (re_looking_at (" *[0-9]*:"))
   {
      push_mark();
      () = ffind_char (':');
      line = integer (bufsubstr());
   }
   else
   {
      setbuf (buf);
      line = what_line();
      setbuf (tkl_TokenBuffer);
      beep ();
   }
   
   return (buf, line);
}

define tkl_filter_list()
{
   variable flt;
   flt = read_mini("Filter: ", "", "");
   push_spot();
   bob();
   if (flt == "") 
      while (down_1) set_line_hidden(0);
   else while (down_1)
   {
      bol(); 
      if (ffind(flt)) set_line_hidden(0);
      else set_line_hidden(1);
   }
   pop_spot();
   if (is_line_hidden())
   {
      do {} while (up_1 and is_line_hidden());
   }
}

% \usage{Void tkl_display_token()}
define tkl_display_token()
{
   variable line, buf;
   (buf, line) = tkl_get_token_info();
   
   pop2buf (buf);
   goto_line (line);
   pop2buf (tkl_TokenBuffer);
}

% \usage{Void tkl_goto_token()}
define tkl_goto_token()
{
   variable line, buf;
   (buf, line) = tkl_get_token_info();
   
   onewindow();
   sw2buf (buf);
   goto_line (line);
}

private variable Line_Mark;
% \usage{Void tkl_update_token_hook ()}
private define tkl_update_token_hook ()
{
   Line_Mark = create_line_mark (color_number ("menu_selection"));
}

% \usage{Void tkl_two_windows (Int bottom_size)}
%% Splits the screen into two windows with the bottom one having
%% bottom_size lines.
%% Bottom window becomes current.
private define tkl_two_windows (bottom_size)
{
   if (bottom_size < 0) bottom_size = 0;
   if (bottom_size > SCREEN_HEIGHT) bottom_size = SCREEN_HEIGHT;

   onewindow();
   splitwindow();
   variable scrtop = window_info ('t');
   if (scrtop < 3) otherwindow();

   %% we are in the bottom window
   variable cursize = window_info ('r');
   variable nenlarge = bottom_size - cursize;

   if (nenlarge >= 0) {
      loop (nenlarge) enlargewin();
   }
   else {
      otherwindow();
      loop (-nenlarge) enlargewin();
      otherwindow();
   }  
}

% \usage{Void tkl_display_results()}
define tkl_display_results()
{
   Line_Mark = NULL;
   tkl_two_windows (SCREEN_HEIGHT / 2);
   sw2buf (tkl_TokenBuffer);
   set_buffer_hook ("update_hook", &tkl_update_token_hook);
   use_keymap ("tokenlist");
}

define tkl_sort_by_value ()
{
   !if (bufferp(tkl_TokenBuffer)) return;
   
   variable buf = whatbuf();
   setbuf (tkl_TokenBuffer);
   set_readonly (0);
   push_spot();
   eob();
   if (re_bsearch ("^ *[0-9]*:")) {
      () = ffind_char (':');
      push_mark();
      bob (); go_down (1); eol();
      if (what_column() < 60) insert_spaces (60 - what_column());
      sort ();
   }
   pop_spot();
   set_buffer_modified_flag (0);
   set_readonly (1);
   setbuf(buf);
}

define tkl_sort_by_line ()
{
   !if (bufferp(tkl_TokenBuffer)) return;
   
   variable buf = whatbuf();
   setbuf (tkl_TokenBuffer);
   set_readonly (0);
   push_spot();
   
   bob();
   go_down(1);
   push_mark();
   eob();
   if (bolp()) go_up(1);
   eol();
   sort();
 
   pop_spot();
   set_buffer_modified_flag (0);
   set_readonly (1);
   setbuf(buf);
}
%}}}

%% #######################################################################
%% ##############  override the default occur ############################
%% #######################################################################
#iftrue
% \usage{Void occur ()}
define occur ()
{
   variable sRegexp;
   if (_NARGS == 0)
      sRegexp = read_mini("Find All (Regexp):", LAST_SEARCH, Null_String);
   else
      sRegexp = ();
 
   tkl_list_tokens(sRegexp, Null_String);
   tkl_display_results();
}
#endif

%% #######################################################################
%% #####################  LIST ROUTINES ##################################
%% #######################################################################

% \usage{Void list_routines()}
define list_routines()
{
   variable mode, arr_regexp = String_Type[1], fn_extract;
   
   (mode,) = what_mode();
   mode = strlow(mode);
   mode = strtrans(mode, "-", "_");
   
   if (-2 == is_defined (sprintf ("%s_list_routines_regexp", mode))) {
      eval (sprintf ("%s_list_routines_regexp;", mode));
      arr_regexp = ();
   }
   else arr_regexp = "^[a-zA-Z].*(";
   
   fn_extract = sprintf ("%s%s", mode, tkl_ExtractMacro);
   !if (+2 == is_defined (fn_extract)) fn_extract = tkl_ExtractMacro;
   
   tkl_list_tokens (arr_regexp, fn_extract);
   tkl_display_results();
   
   set_readonly(0);
   runhooks (sprintf ("%s_list_routines_hook", mode));
   set_buffer_modified_flag(0);
   set_readonly(1);
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%  MODES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%  
%%        Default
%%  
define _list_routines_extract (nRegexp)
{
   return (line_as_string());
}


%%  
%%        C
%%  
variable c_list_routines_regexp = 
   ["^[a-zA-Z_][a-zA-Z0-9_]*[ \t*&].*(",  % Ordinary function or method
    "^[a-zA-Z_][a-zA-Z0-9_]*::~.+("];     % Destructor

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

define c_list_routines_hook()
{
   tkl_sort_by_value();
}

%%  
%%        SLang
%%  
variable slang_list_routines_regexp =
   ["^define[ \t]",
    "^variable[ \t]",
    "^public[ \t]+[dv]",
    "^private[ \t]+[dv]",
    "^static[ \t]+[dv]"
    ];

define slang_list_routines_extract (nRegexp)
{
   bol();
   if (nRegexp >= 2) { % skip static, public
      skip_chars ("a-z");
      skip_chars (" ");
   }
   push_mark();
   eol();
   return (bufsubstr());
}

define slang_list_routines_hook()
{
   tkl_sort_by_value();
}

provide("tokenlist");


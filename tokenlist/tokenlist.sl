% -*- mode:SLang; mode:fold; -*-
%
% file: tokenlist.sl    v1.10
% Author: Marko Mahnic
%
% Copyright (c) 2006 Marko Mahnic
% Released under the terms of the GNU General Public License (ver. 2 or later)

%% INSTALLATION
%%  
%%    Put on your jed_library_path.
%%    
%%    Insert the content of the INITIALIZATION block (see below) or just
%%      require("tokenlist");                  % evaluate at startup
%%    into your jed.rc (or .jedrc) file.
%%    (or use the "make_ini" and  "home-lib" modes from jedmodes.sf.net)
%% 
%%    Optionally add some keybindings, e.g.:
%%      setkey("list_routines", "^R");
%%      setkey("occur", "^O");
%%   
%% USAGE
%%    
%%    Use your keybindings, M-x occure or M-x list_routines, or the Search
%%    menu entries to open a tokenlist buffer with search results.
%%    
%%    Keybindings in the tokenlist buffer:
%% 
%%       d, SPACE:   display selected line in other buffer
%%       g, RETURN:  goto selected line, close token list
%%       /, s:       isearch_forward
%%       :, f:       filter the displayed results (hides nonmatching lines)
%%       q:          hide results
%%       w:          other window
%%    
%% CUSTOMIZATION
%%    
%%    Custom Variables: 
%%       TokenList_Startup_Mode -- Initial mode of the tokenlist
%%          0 - normal mode
%%          1 - start in isearch mode
%%          2 - start in filter mode
%%
%%    Hooks:
%%       tokenlist_hook() -- called after this file is evaluated. 
%%       
%%       The default is defined in the INITALIZATION block. It loads 
%%       mode definitions for list_routines() from tkl-modes.sl.
%%       
%%       Users of make_ini (e.g. via the jed-extra Debian package) can
%%       also overwrite the tokenlist_hook in their jed.rc file, e.g.
%%        
%%          define tokenlist_hook()
%%          {
%%             % load prepared definitions
%%             require("tkl-modes"); 
%%             % overwrite some definitons with custom version
%%             eval("define slang_list_routines_extract(nRegexp)" 
%%                + "{ return line_as_string(); }");
%%             eval("define slang_list_routines_done()"
%%                + "{ tkl_sort_by_line; }");
%%             % customize keybindings
%%             definekey ("tkl_quit", "^W", "tokenlist");
%%          }
%%
%% EXTENSION
%%    
%%    A set of mode definitions for list_routines is defined in the file
%%    tkl-modes.sl. They are loaded by the default tokenlist_hook().
%%    
%%    To use list_routines in a new mode MODENAME, define a function
%%
%%      Void  MODENAME_list_routines_setup(Tokenlist_Operation_Type opt)
%%      
%%    and fill the fields of the structure opt:
%%    
%%    opt.list_regexp = {"regexp0", "regexp1", &search_fn};
%%       A set of regular expressions or references to function like:
%%          
%%          % Int_Type searc_fn(Int_Type array_index)
%%          % returns 0 when no more matches
%%          define searc_fn(idx)
%%          {
%%             return fsearch("something");
%%          }
%%             
%%    opt.fn_extract = &MODENAME_list_routines_extract;
%%       A reference to a (private) function like:
%%       
%%          String   MODENAME_list_routines_extract  (Integer I)
%%             Extractor function to extract the match from the currnet
%%             buffer. I is the index of the regexp in the array.
%%             When the function is called the point in the buffer
%%             is at the current match. When the function returns
%%             the point should be restored.
%%             Optional. If it is not defined, the default 
%%             _list_routines_extract extracts the whole current line.
%% 
%%    opt.onlistcreated = &MODENAME_list_routines_done;
%%       A reference to a (private) function like:
%%       
%%          Void   MODENAME_list_routines_done (Void)
%%             When this hook is called, the buffer with
%%             the extracted lines is the current buffer.
%%             You can use tkl_sort_by_value or tkl_sort_by_line 
%%             instead of a custom function.
%%             Optional. Default is NULL.
%%    
%%    These definitions can be done in
%%      jed.rc, 
%%      (a private copy of) tkl-modes.sl,
%%      a second mode-definition file (modify tokenlist_hook() to require it),
%%    or by modifying the tokenlist_hook(), using eval() as you normally
%%    cannot define functions or global variables in a function.
%% 
%% CHANGES:
%%   2000: Marko Mahnic
%%     First version
%%   2006-03-08: Marko Mahnic
%%     - added isearch and filter commands
%%     - documented
%%     - _list_routines_regexp can also be a list
%%      and it may contain references to functions
%%     - TokenList_Startup_Mode custom variable
%%     - keybindings slightly changed
%%   2006-03-10: Guenter Milde, Marko Mahnic
%%     - prepared for make_ini()
%%   2006-03-13: Marko Mahnic
%%     - filter command is now interactive
%%   2006-03-29: Marko Mahnic
%%     - tokenlist_routine_setup_hook
%%     - Tokenlist_Operation_Type structure
%%     - definitions moved to tkl-modes.sl
%%     - HTML documentation added
%%   2006-03-30 Marko Mahnic
%%     - tokenlist menu
%%     - moccur; prepared for mlist_routines
%%     - simple syntax coloring
%%   2006-11-17 Guenter Milde
%%     - hook for delayed and customizable loading of tkl-modes.sl
%%     - INITIALIZATION section (for make_ini() or manual copy to .jedrc)
%%     - tm documentation for TokenList_Startup_Mode  
%%   2006-12-19  Marko Mahnic
%%     - changed the interface to use _list_routines_setup 
%%       (the old interface still works)
%%   2007-04-18 G. Milde
%%     - bugfix in tkl_list_tokens() preventing an infinite loop if there is a
%%       match on the last line of a buffer
%%   2007-05-09  Marko Mahnic
%%     - renamed list_regex -> list_regexp
%%     - removed the old list_routines interface. Use _list_routines_setup.
%%     - added "construcotr" New_Tokenlist_Operation_Type
%%   2007-10-01 G. Milde
%%     - autoload bufutils.sl if present
%%   2007-10-18 G. M.
%%     - help text for public functions

#<INITIALIZATION>

autoload("list_routines", "tokenlist");
autoload("occur", "tokenlist");
autoload("moccur", "tokenlist");
add_completion("list_routines");

% Add menu entry
define tokenlist_load_popup_hook(menubar)
{
   menu_insert_item("Se&t Bookmark", "Global.&Search", 
      "&List Routines", "list_routines");
}
append_to_hook("load_popup_hooks", &tokenlist_load_popup_hook);


% default hook to add prepared mode definitions for list_routines:
define tokenlist_hook()
{
   if (expand_jedlib_file("tkl-modes") != "")
     require("tkl-modes");
}

#</INITIALIZATION>

%!%+
%\variable{TokenList_Startup_Mode}
%\synopsis{Initial mode of the tokenlist}
%\usage{variable TokenList_Startup_Mode = 0}
%\description
%  Controls what happens right after the list is displayed:
%    0 - normal mode
%    1 - start in isearch mode
%    2 - start in filter mode
%\seealso{occur, moccur, list_routines}
%!%-
custom_variable ("TokenList_Startup_Mode", 0);

private variable tkl_TokenBuffer  = "*TokenList*";
private variable tkl_ExtractMacro = "_list_routines_extract";
private variable tkl_DoneMacro    = "_list_routines_done";
private variable tkl_SetupMacro   = "_list_routines_setup";
private variable tkl_mode = "tokenlist";
private variable tkl_BufferMark = "[Buffer]:";

%% Default extraction routine
define _list_routines_extract (nRegexp)
{
   return line_as_string();
}

!if (is_defined("Tokenlist_Operation_Type")) %{{{
{
   typedef struct
   {
      mode,           % mode identifier
      list_regexp,    % list of regex / search function pointers
      fn_extract,     % a function to extract what was found
      onlistcreated   % a function that is run when the list is created
   } Tokenlist_Operation_Type;
}

define New_Tokenlist_Operation_Type()
{
   variable tkopt = @Tokenlist_Operation_Type;
   tkopt.mode = NULL;
   tkopt.list_regexp = NULL;
   tkopt.fn_extract = NULL;
   tkopt.onlistcreated = NULL;
   return tkopt;
}

%}}}

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
define tkl_list_tokens (opt) %{{{
{
   variable buf = whatbuf(), line, token;
   variable found = 0;

   if (List_Type != typeof(opt.list_regexp) and Array_Type != typeof(opt.list_regexp))
      opt.list_regexp = { opt.list_regexp };
   if (opt.fn_extract == NULL) 
      opt.fn_extract = &_list_routines_extract;
   
   variable i, rv, rtype, extype;
   extype = typeof(opt.fn_extract);
   if (extype != Ref_Type and extype != String_Type) return;
   
   if (extype == String_Type) if (opt.fn_extract == Null_String)
   {
      extype = Ref_Type;
      opt.fn_extract = &_list_routines_extract;
   }
      
   setbuf (tkl_TokenBuffer);
   set_readonly (0);
   setbuf (buf);
   push_spot();
   for (i = 0; i < length(opt.list_regexp); i++)
   { 
      % The array may be larger than the number of needed regular expressions.
      % We can end the search with a Null_String or NULL.
      if (opt.list_regexp[i] == NULL) break;
      
      rtype = typeof(opt.list_regexp[i]);
      if (rtype != Ref_Type and rtype != String_Type) continue;
      if (rtype == String_Type) if (opt.list_regexp[i] == Null_String) break;

      bob();
      do
      {
         bol();
         if (rtype == Ref_Type) rv = (@opt.list_regexp[i])(i);
         else rv = re_fsearch (opt.list_regexp[i]);
         
         if (not rv) break;
         
         push_spot();
         if (extype == Ref_Type) (@opt.fn_extract)(i);
         else eval (sprintf ("%s(%ld)", opt.fn_extract, i));
         token = ();
         pop_spot();
         while (str_replace(token, "\n", " ")) token = ();

         if (strtrim(token) != Null_String)
         {
            line = what_line();
            setbuf (tkl_TokenBuffer);
            if ( not found)
            {
               found = 1;
               vinsert ("%s %s\n", tkl_BufferMark, buf);
            }
            vinsert ("%7d: %s\n", line, token);
            setbuf (buf);
         }
      }
      while (down(1));
   }
   
   pop_spot();
   
   setbuf (tkl_TokenBuffer);
   
   if (opt.onlistcreated != NULL)
   {
      try
         call_function(opt.onlistcreated);
      catch AnyError:;
   }
   
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

!if (keymap_p (tkl_mode))
{
   make_keymap (tkl_mode);
   definekey ("tkl_display_token", " ", tkl_mode);
   definekey ("tkl_display_token", "d", tkl_mode);
   definekey ("tkl_goto_token", "\r", tkl_mode);
   definekey ("tkl_goto_token", "g", tkl_mode);
   definekey ("isearch_forward", "s", tkl_mode);
   definekey ("isearch_forward", "/", tkl_mode);
   definekey ("tkl_filter_list", "f", tkl_mode);
   definekey ("tkl_filter_list", ":", tkl_mode);
   definekey ("tkl_quit", "q", tkl_mode);
   definekey ("other_window", "w", tkl_mode);
}

create_syntax_table(tkl_mode);
define_syntax(tkl_BufferMark, "", '%', tkl_mode);

private define tkl_menu(menu)
{
   menu_append_item (menu, "&Display", "tkl_display_token");
   menu_append_item (menu, "&Go To", "tkl_goto_token");
   menu_append_item (menu, "Incremental &search", "isearch_forward");
   menu_append_item (menu, "&Filter buffer", "tkl_filter_list");
   menu_append_item (menu, "Other &window", "other_window");
   menu_append_item (menu, "&Quit", "tkl_quit");
}

private define tkl_erase_buffer()
{
   variable buf = whatbuf();
   setbuf (tkl_TokenBuffer);
   set_readonly (0);
   erase_buffer ();
   set_readonly (1);
   setbuf(buf);
}

% \usage{(String, Int) tkl_get_token_info()}
private define tkl_get_token_info()
{
   variable line, buf;
   
   setbuf (tkl_TokenBuffer);
   push_spot();
   if (not bol_bsearch(tkl_BufferMark)) bob();
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
   variable c, curflt, flt = "";
   push_spot();
   bob();
   while (down_1) set_line_hidden(0);
   pop_spot();
   message("Filter buffer (Esc to exit):");
   while(input_pending(0)) () = getkey();
   update_sans_update_hook (0);
   forever
   {
      c = getkey();
      
      curflt = flt;
      switch(c)
      { case 0x08 or case 0x7F: 
         if (flt != "") flt = substr(flt, 1, strlen(flt)-1);
      }
      { case '\e':
         if (input_pending (3))
            ungetkey (c);
         break;
      }
#ifdef IBMPC_SYSTEM
      { case 0xE0:
         if (input_pending (3))
         {
            ungetkey(c);
            break;
         }
      }
#endif 
      { c < 32 and c >= 0:
         ungetkey (c);
         break;
      }
      { flt += char(c); }
      
      vmessage("Filter buffer (Esc to exit): %s", flt);
      if (curflt != flt)
      {
         push_spot();
         bob();
         if (flt == "") 
         {
            while (down_1)
               set_line_hidden(0);
         }
         else
         {
            while (down_1)
            {
               bol(); 
               if (looking_at(tkl_BufferMark)) continue;
               else if (ffind(flt)) set_line_hidden(0);
               else set_line_hidden(1);
               if (input_pending(0)) break;
            }
         }
         pop_spot();
         try if (is_line_hidden()) call("previous_line_cmd");
         catch AnyError: ;
         try if (what_line() <= 1) call("next_line_cmd");
         catch AnyError: ;
         update(0);
      }
   }

   message("");
}

private define tkl_make_line_visible()
{
   if (is_line_hidden())
   {
      if (2 == is_defined("fold_open_fold"))
      {
         try
         {
            variable n = 5; % foldnig depth
            do
            {
               push_spot();
               eval("fold_open_fold");
               pop_spot();
               n--;
            } while (n > 0 and is_line_hidden());
            
            if (is_line_hidden())
            {
               if (2 == is_defined("fold_open_buffer")) eval("fold_open_buffer");
            }
         }
         catch AnyError:
         {
         }
      }
      else set_line_hidden(0);
   }
}

% \usage{Void tkl_display_token()}
define tkl_display_token()
{
   variable line, buf;
   (buf, line) = tkl_get_token_info();
   
   pop2buf (buf);
   goto_line (line);
   tkl_make_line_visible();
#if (expand_jedlib_file("bufutils.sl") != "")
   autoload("popup_buffer", "bufutils");
   popup_buffer(tkl_TokenBuffer);
#else   
   pop2buf (tkl_TokenBuffer);
#endif
}

% \usage{Void tkl_goto_token()}
define tkl_goto_token()
{
   variable line, buf;
   (buf, line) = tkl_get_token_info();
   
   onewindow();
   sw2buf (buf);
   goto_line (line);
   tkl_make_line_visible();
}

define tkl_quit()
{
   otherwindow();
   onewindow();
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

define tkl_display_results()
{
   Line_Mark = NULL;
   tkl_two_windows (SCREEN_HEIGHT / 2);
   sw2buf (tkl_TokenBuffer);
   set_mode(tkl_mode, 0);
   set_buffer_hook ("update_hook", &tkl_update_token_hook);
   mode_set_mode_info (tkl_mode, "init_mode_menu", &tkl_menu);
   use_keymap (tkl_mode);
   use_syntax_table(tkl_mode);
   
   switch (TokenList_Startup_Mode)
   { case 0: return; }
   { case 1: isearch_forward(); }
   { case 2: tkl_filter_list(); }
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
%% Function: occur
%% \usage{Void occur ([regexp])}
%% Search for a regexp in current buffer.
%% 
%% If the parameter regexp is not supplied the value can
%% be entered interactively.
%% 
%% tokenlist_occur_setup_hook(tkopt) is called before the search
%% is started so the user has a chance to modify the search
%% parameters and display. tkopt.mode is set to "@occur".
public define occur ()
{
   variable tkopt = New_Tokenlist_Operation_Type();
   if (_NARGS == 0)
      tkopt.list_regexp = read_mini("Find All (Regexp):", LAST_SEARCH, Null_String);
   else
      tkopt.list_regexp = ();
  
   tkopt.mode = "@occur";
   runhooks("tokenlist_occur_setup_hook", tkopt);

   tkl_erase_buffer();
   tkl_list_tokens(tkopt);
   tkl_display_results();
}

%!%+
%\function{moccur}
%\synopsis{Search for a regexp in all loaded buffers.}
%\usage{Void moccur ([regexp])}
%\description
%  Search for \var{regexp} in all loaded buffers and display all hits
%  in a *Tokenlist* buffer.
%  
%  Does not search in internal and temporary buffers.
%  
%  If the parameter regexp is not supplied the value can
%  be entered interactively.
%\notes  
%  tokenlist_occur_setup_hook(tkopt) is called before the search
%  is started so the user has a chance to modify the search
%  parameters and display. tkopt.mode is set to "@moccur".
%\seealso{occur, list_routines, TokenList_Startup_Mode}
%!%-
public define moccur ()
{
   variable buf;
   variable tkopt = New_Tokenlist_Operation_Type();
   if (_NARGS == 0)
      tkopt.list_regexp = read_mini("Find All (Regexp):", LAST_SEARCH, Null_String);
   else
      tkopt.list_regexp = ();

   tkopt.mode = "@moccur";
   runhooks("tokenlist_occur_setup_hook", tkopt);

   tkl_erase_buffer();
   loop(buffer_list())
   {
      buf = ();
      if (buf == tkl_TokenBuffer) continue;
      if (is_substr("* ", buf[[0]])) continue;
      setbuf(buf);
      tkl_list_tokens(tkopt);
   }
   tkl_display_results();
}
#endif

%% #######################################################################
%% #####################  LIST ROUTINES ##################################
%% #######################################################################

%!%+
%\function{list_routines}
%\synopsis{List routines defined in the current buffer}
%\usage{Void list_routines()}
%\description
%  Perform a regexp search depending on the current mode and list
%  'tokens' or 'routine definitions' in a *TokenList* buffer.
%  
%  A typical use is to list function, variable, and class definitions in
%  a  source code file. But, e.g.,  section headers in reStructuredText 
%  or another markup language can be found too.
%  
%  Keybindings in the tokenlist buffer:
% 
%       d, SPACE:   display selected line in other buffer
%       g, RETURN:  goto selected line, close token list
%       /, s:       isearch_forward
%       :, f:       filter the displayed results (hides nonmatching lines)
%       q:          hide results
%       w:          other window
%\notes
%  For configuration, see the documentation in tokenlist.sl
%\seealso{occur, moccur, TokenList_Startup_Mode}
%!%-
public define list_routines()
{
   variable buf, mode, fn;
   variable tkopt = New_Tokenlist_Operation_Type();

   (mode,) = what_mode();
   mode = strlow(mode);
   
   tkopt.mode = strtrans(mode, "-", "_");
   tkopt.list_regexp = {"^[a-zA-Z].*("};
   tkopt.fn_extract = &_list_routines_extract;
   
   fn = sprintf ("%s%s", tkopt.mode, tkl_SetupMacro);
   if (+2 == is_defined (fn)) 
      call_function (fn, tkopt);
#iffalse
   else
   {  % the old interface
      if (-2 == is_defined (sprintf ("%s_list_routines_regexp", tkopt.mode))) {
         eval (sprintf ("%s_list_routines_regexp;", tkopt.mode));
         tkopt.list_regexp = ();
      }
   
      fn = sprintf ("%s%s", tkopt.mode, tkl_ExtractMacro);
      if (+2 == is_defined (fn)) tkopt.fn_extract = __get_reference(fn);
   
      fn = sprintf ("%s%s", tkopt.mode, tkl_DoneMacro);
      if (+2 == is_defined (fn)) tkopt.onlistcreated = __get_reference(fn);
   }
#endif

   % Setup routine for current mode,
   % give the user a chance to modify default behaviour.
   runhooks("tokenlist_routine_setup_hook", tkopt);
   
   tkl_erase_buffer();
   tkl_list_tokens (tkopt);
   tkl_display_results();
}

%% Run the tokenlist_hook hook 
%% (for delayed and customizable loading of tkl-modes.sl)

runhooks("tokenlist_hook");

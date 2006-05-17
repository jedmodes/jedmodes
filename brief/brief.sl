% brief.sl:    Brief editor emulation
% 
% This will not work well on konsole or in an x-terminal
% because of the heavy dependence on "exotic" keys.
% Try with DOS, MS-Windows, or X-Windows and an IBMPC keyboard
% 
% Copyright (c) 2005 John E Davis, Günter Milde, Marko Mahnic
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% 2003-08-18 Guenter Milde 
%   - work with X-windows and a IBMPC keyboard using keydefs.sl
%   
% 2005-10-11 Marko Mahnic
%   - double/triple home/end handling
%   - more Brief keybindings (based on emacs brief.el)
%   - more Brief-like region marking, copying, yanking
%   - page up/dn (mostly) leaves cursor on same screen line
%   - Brief-like macro recording (F7)
%   
% 2005-10-12 Guenter Milde
%   - fixed dependency on x-keydefs (kp_keydefs is obsolete)
%   
% 2006-03-07 Marko Mahnic
%   - added support for named scraps with region type info in blocal vars
%   
% 2006-03-15 Marko Mahnic
%   - disabled the "\em" keybinding that prevented menu access
%   - disabled the "\es" keybinding (Search menu)
%   
_Jed_Emulation = "brief";

% load the extended set of symbolic key definitions (variables Key_*)
require("x-keydefs");

set_status_line("(Jed %v) Brief: %b    (%m%a%n%o)  %p   %t", 1);
Help_File = Null_String;

autoload ("scroll_up_in_place",		"emacsmsc");
autoload ("scroll_down_in_place",	"emacsmsc");

private variable Brief_HomeEnd_Count = 0;
define brief_home ()
{
   if (LAST_KBD_COMMAND != "brief_home") {
      Brief_HomeEnd_Count = 0;
      bol ();
   }
   else {
      Brief_HomeEnd_Count++;
      
      switch (Brief_HomeEnd_Count)
	{case 1: goto_top_of_window (); }
	{case 2: bob (); }
	{bol (); }
   }
}

define brief_end ()
{
   if (LAST_KBD_COMMAND != "brief_end") {
      Brief_HomeEnd_Count = 0;
      eol ();
   }
   else {
      Brief_HomeEnd_Count++;
      
      switch (Brief_HomeEnd_Count)
	{case 1: goto_bottom_of_window (); eol (); }
	{case 2: eob (); }
	{eol (); }
   }   
}

define brief_line_to_eow ()
{
   recenter (window_info ('r'));
}

define brief_line_to_bow ()
{
   recenter (1);
}

define brief_line_to_mow ()
{
   recenter (window_info ('r') / 2);
}

define brief_set_bkmrk_cmd (n)
{
   ungetkey (n + '0');
   bkmrk_set_mark ();
}

define brief_delete_to_bol ()
{
   push_mark ();
   bol();
   del_region ();
}

define brief_open_line ()
{
   eol ();
   newline ();
   indent_line ();
}

private define onoff(val)
{ 
   if (val) return "on"; 
   else return "off";
}

define brief_toggle_case_search ()
{
   CASE_SEARCH = not (CASE_SEARCH);
   vmessage ("Case sensitive search is %s.", onoff(CASE_SEARCH));
}

variable Brief_Regexp_Search = 1;
define brief_toggle_regexp ()
{
   Brief_Regexp_Search = not (Brief_Regexp_Search);
   vmessage ("Regular expression search is %s.", onoff(Brief_Regexp_Search));
}

variable Brief_Search_Forward = 1;
define brief_search_cmd ()
{
   if (Brief_Search_Forward) {
      if (Brief_Regexp_Search) re_search_forward ();
      else search_forward ();
   }
   else {
      if (Brief_Regexp_Search) re_search_backward ();
      else search_backward ();
   }
}

define brief_reverse_search ()
{
   Brief_Search_Forward = not (Brief_Search_Forward);
   brief_search_cmd ();
}

define brief_replace_cmd()
{
   variable bWiden = 0;
   if (markp()) {
      push_spot ();
      narrow_to_region();
      bob();
      bWiden = 1;
   }
   if (Brief_Regexp_Search) query_replace_match ();
   else replace_cmd();
   
   if (bWiden) {
      widen_region ();
      pop_spot();
   }
}

%%  0 - No mark
%%  1 - Normal    3 - Line
%%  2 - Column    4 - Noninclusive
variable Brief_Mark_Type = 0;

#ifdef HAS_BLOCAL_VAR

private variable Brief_Scrap_Type = "Brief_Scrap_Type";
private define brief_get_scrap_type(scbuf)
{
   variable b, v = 1;
   !if (bufferp(scbuf)) return 1;
   b = whatbuf();
   setbuf(scbuf);
   if (blocal_var_exists(Brief_Scrap_Type))
      v = get_blocal_var(Brief_Scrap_Type);
   setbuf(b);
   return v;
}

private define brief_set_scrap_type(scbuf, sctype)
{
   variable b;
   !if (bufferp(scbuf)) return;
   b = whatbuf();
   setbuf(scbuf);
   create_blocal_var(Brief_Scrap_Type);
   set_blocal_var(sctype, Brief_Scrap_Type);
   setbuf(b);
}

#else

private variable Brief_Scrap_Type = 0;
private define brief_get_scrap_type(scbuf)
{
   return Brief_Scrap_Type;
}

private define brief_set_scrap_type(scbuf, sctype)
{
   Brief_Scrap_Type = sctype;
}

#endif %% HAS_BLOCAL_VAR

private variable Brief_Scrap_Buf_Format = " <scrap-%s>";
private define brief_get_scrap_name ()
{
   variable b, scrps;
   scrps = "";
   loop (buffer_list ())
   {
      b = ();
      if (1 == is_substr(b, " <scrap-"))
      {
         b = strtrim(b[[8:]], ">");
         if (scrps == "") scrps = b;
         else scrps = scrps + "," + b;
      }
   }
   variable name = read_with_completion (scrps, "Scrap name:", "", "", 's');
   name = strtrim (name);
   if (name == "") name = NULL;
   return name;
}

define brief_yank_lines ()
{
   call ("mark_spot");
   bol (); 
   call ("yank"); 
   pop_spot ();
}

define brief_yank ()
{
   switch (brief_get_scrap_type(" <paste>"))
     { case 2: insert_rect (); message ("Columns inserted."); }
     { case 3: brief_yank_lines (); message ("Lines inserted."); }
     { call ("yank"); message ("Scrap inserted.");}
}

define brief_yank_named ()
{
   variable sctype, scbuf, b;
   variable scrapname = brief_get_scrap_name();
   
   if (scrapname == NULL) return;
   scbuf = sprintf(Brief_Scrap_Buf_Format, scrapname);
   !if (bufferp(scbuf))
   {
      message ("No such scrap.");
      return;
   }
   b = whatbuf();
   
   sctype = brief_get_scrap_type(scbuf);
   if (sctype == 2) setbuf(" <rect>");
   else setbuf(" <paste>");
   erase_buffer();
   insbuf(scbuf);
   setbuf(b);

   switch (sctype)
     { case 2: insert_rect (); vmessage ("Columns from scrap '%s' inserted.", scrapname); }
     { case 3: brief_yank_lines (); vmessage ("Lines from scrap '%s' inserted.", scrapname);}
     { call ("yank"); vmessage ("Scrap '%s' inserted.", scrapname);}
}

% Prototype: brief_complete_line_region ()
% Makes a line region complete including whole first line
% and whole last line (with newline character).
define brief_complete_line_region ()
{
   check_region (0);           %% region is canonical
   exchange_point_and_mark (); %% mark entire first line
   bol ();
   check_region (0);
   eol();
   !if (eobp ()) {
      go_down_1 (); 
      bol ();
   }
}

% Returns 1 if the region was automarked, 0 otherwise.
define brief_check_marked_automark ()
{
   if (markp() == 0) {                % not marked --> copy line
      if (eobp() and bolp()) return (0);
      set_mark_cmd ();
      Brief_Mark_Type = 3;
      return (1);
   }
   else if (Brief_Mark_Type == 0) {   % marked, but wrong type --> copy region
      Brief_Mark_Type = 1;
   }
   
   return (0);
}

private define brief_region_to_scrap(opinfo, macro, rectmacro, namedscrap)
{
   variable b, what = NULL;   

   if (brief_check_marked_automark()) what = "Line";
   
   if (Brief_Mark_Type == 2) {
      if (is_internal(rectmacro)) call (rectmacro);
      else eval(rectmacro);
      what = "Columns";
   }
   else if (Brief_Mark_Type == 3) {
      push_spot ();
      brief_complete_line_region ();
      if (is_internal(macro)) call (macro);
      else eval(macro);
      pop_spot ();
      if (what == NULL) what = "Lines";
   }
   else {
      if (is_internal(macro)) call (macro);
      else eval(macro);
      what = "Region";
   }
   
   if (namedscrap == NULL or namedscrap == "")
   {
      vmessage ("%s %s to scrap.", what, opinfo);
      brief_set_scrap_type(" <paste>", Brief_Mark_Type);
   }
   else
   {
      vmessage ("%s %s to scrap '%s'.", what, opinfo, namedscrap);
      
      b = whatbuf();
      what = sprintf(Brief_Scrap_Buf_Format, namedscrap);
      setbuf(what);
      erase_buffer();
      if (Brief_Mark_Type == 2) insbuf(" <rect>");
      else insbuf(" <paste>");
      brief_set_scrap_type(what, Brief_Mark_Type);
      setbuf(b);
   }
   
   Brief_Mark_Type = 0;
}

define brief_copy_region ()
{
   brief_region_to_scrap("copied", "copy_region", "copy_rect", NULL);
}

define brief_kill_region ()
{
   brief_region_to_scrap("cut", "kill_region", "kill_rect", NULL);
}

define brief_copy_region_named ()
{
   variable name = brief_get_scrap_name();
   if (name != NULL)
      brief_region_to_scrap("copied", "copy_region", "copy_rect", name);
}

define brief_kill_region_named ()
{
   variable name = brief_get_scrap_name();
   if (name != NULL)
      brief_region_to_scrap("cut", "kill_region", "kill_rect", name);
}

define brief_delete ()
{
   if (markp ()) {
      if (Brief_Mark_Type == 2)  {
	 kill_rect ();
      } 
      else if (Brief_Mark_Type == 3) {
	 brief_complete_line_region ();
	 del_region ();
      }
      else {
	 del_region ();
      }
      Brief_Mark_Type = 0;
      return;
   }
   del ();
   Brief_Mark_Type = 0;
}

% int brief_unmark (int MarkType)
% If a region is marked and it is of type MarkType,
% the region is unmarked, 1 is returned. It returns
% 0 otherwise.
define brief_unmark (n)
{
   if (markp ()) {
      if (Brief_Mark_Type == n) {
	 smart_set_mark_cmd ();
	 message ("Mark unset");
	 Brief_Mark_Type = 0;
	 return (1);
      }
   }
   
   return (0);
}

define brief_line_mark ()
{
   !if (brief_unmark (3)) {
      Brief_Mark_Type = 3;
      push_spot ();
      eol (); goto_column (what_column () / 2);
      set_mark_cmd ();
      pop_spot ();
      message ("Line mark set.");
   }
}

% void brief_set_mark_cmd (int MarkType)
define brief_set_mark_cmd (n)
{
   !if (brief_unmark (n)) {
      Brief_Mark_Type = n;
      if (Brief_Mark_Type == 1) {
	 set_mark_cmd ();
      }
      else {
	 smart_set_mark_cmd ();
      }
   }
}

define brief_set_column_mark ()
{
   !if (brief_unmark (2)) {
      Brief_Mark_Type = 2;
      set_mark_cmd ();
      message ("Column mark set.");
   }
}

define brief_record_kbdmacro ()
{
   if (DEFINING_MACRO) {
      call ("end_macro");
   }
   else !if (EXECUTING_MACRO or DEFINING_MACRO) {
      call ("begin_macro");
   }
}

% Prototype: brief_next_buffer (int direction)
% This function changes the current buffer depending on value of
% direction:
%    if direction >= 0 ==> next buffer
%    if direction  < 0 ==> prev buffer
% It skips system buffers and buffers with names beginning with '*'. 
define brief_next_buffer (direction)
{
   variable n, buf;
   
   if (MINIBUFFER_ACTIVE) return;

   n = buffer_list ();		       %/* buffers on stack */
   
   if (direction < 0) {
      _stk_roll (-n);
      pop ();
      n--;  
   }
   loop (n) {
      if (direction < 0) _stk_roll (-n);
      buf = ();
      n--;
      if (buf[0] == ' ') continue;
      if (buf[0] == '*' and buf != "*scratch*") continue;
      sw2buf (buf);
      loop (n) pop ();
      return;
   }   
}

% int Brief_Last_Column
% Records the last column position before PageUp/PageDown commands.
% Used in brief_pageup () and brief_page_down () to restore the 
% column position after movement.
private variable Brief_Last_Column = 0;
private define brief_store_last_column ()
{
   if (LAST_KBD_COMMAND == "brief_pagedown" or
       LAST_KBD_COMMAND == "brief_pageup")
      return;
   Brief_Last_Column = what_column ();
}

% Prototype: brief_pageup ()
% Moves one page up leaving the cursor on the same position in the
% window.
define brief_pageup ()
{
   variable woffs;
   
   if (MINIBUFFER_ACTIVE) {
      call ("page_up");
      return;
   }
   brief_store_last_column ();
   woffs = window_line ();
   go_up (window_info ('r'));
   while (is_line_hidden() and not bobp()) go_up_1();
   recenter (woffs);
   () = goto_column_best_try (Brief_Last_Column);
}

% Prototype: brief_pagedown ()
% Moves one page down leaving the cursor on the same position in the
% window.
define brief_pagedown ()
{
   variable woffs;
     
   if (MINIBUFFER_ACTIVE) {
      call ("page_down");
      return;
   }
   brief_store_last_column ();
   woffs = window_line ();
   go_down (window_info ('r'));
   while (is_line_hidden() and not eobp()) go_down_1();
   recenter (woffs);   
   () = goto_column_best_try (Brief_Last_Column);   
}

% Prototype: brief_delete_buffer ()
% Deletes the current buffer if it is not the minibuffer.
define brief_delete_buffer ()
{
   if (MINIBUFFER_ACTIVE) return;
   delbuf (whatbuf ());
   brief_next_buffer (1);
}

unsetkey ("^F");
unsetkey ("^K");
unsetkey ("^R");
unsetkey ("^X");
unsetkey ("^W");
setkey ("scroll_up_in_place",    "^D"   );
setkey ("scroll_down_in_place",  "^E"   );
setkey ("brief_delete_to_bol",   "^K"   );
setkey ("goto_match",            "^Q["  );
setkey ("goto_match",            "^Q\e" );
setkey ("goto_match",            "^Q]"  );
setkey ("goto_match",            "^Q^]" );
setkey ("isearch_forward",       "^S"   );
setkey ("brief_line_to_bow",     "^T"   );
setkey ("brief_line_to_mow",     "^C"   );
setkey ("brief_line_to_eow",     "^B"   );
%setkey ("brief_next_error",     "^N"   );
%setkey ("brief_error_window",   "^P"   );
_for (0, 9, 1) { $0 = (); setkey("digit_arg", "^R" + string($0)); }
%setkey ("redo",                 "^U"   );
%setkey ("brief_toggle_backup",  "^W"   );
%setkey ("save_buffers_and_exit","^X"   );
%setkey ("one_window",           "^Z"   );

setkey ("brief_yank",            Key_Ins        );
setkey ("brief_delete",          Key_Del        );
setkey ("brief_home",            Key_Home       );
setkey ("brief_end",             Key_End        );
setkey ("brief_pagedown",        Key_PgDn       );
setkey ("brief_pageup",          Key_PgUp       );
setkey ("scroll_left",           Key_Shift_End  ); % should be: right of window
setkey ("scroll_right",          Key_Shift_Home ); % should be: left of window
setkey ("bskip_word",            Key_Ctrl_Left  );
setkey ("skip_word",             Key_Ctrl_Right );
setkey ("bob",                   Key_Ctrl_PgUp  );
setkey ("eob",                   Key_Ctrl_PgDn  );
setkey ("goto_top_of_window",    Key_Ctrl_Home  );
setkey ("goto_bottom_of_window", Key_Ctrl_End   );
setkey ("bdelete_word",          Key_Ctrl_BS    );
setkey ("delete_word",           Key_Alt_BS     );
setkey ("brief_open_line",       Key_Ctrl_Return);

setkey ("undo",                  Key_KP_Multiply );
setkey ("brief_copy_region",     Key_KP_Add      );
setkey ("brief_kill_region",     Key_KP_Subtract );

% setkey ("brief_copy_region_named",     Key_Ctrl_KP_Add);
% setkey ("brief_kill_region_named",     Key_Ctrl_KP_Subtract);
% setkey ("brief_yank_named",            Key_Ctrl_Ins);

setkey  ("other_window",             Key_F1         );
setkey  ("one_window",               Key_Alt_F2     );
setkey  ("split_window",             Key_F3         );
setkey  ("delete_window",            Key_F4         );
setkey  ("brief_search_cmd",         Key_F5         );
setkey  ("brief_reverse_search",     Key_Alt_F5     );
setkey  ("brief_search_cmd",         Key_Shift_F5   );
setkey  ("brief_toggle_case_search", Key_Ctrl_F5    );
setkey  ("brief_replace_cmd",        Key_F6         );
setkey  ("brief_toggle_regexp",      Key_Ctrl_F6    );
setkey  ("brief_record_kbdmacro",    Key_F7         );
%setkey  ("brief_pause_kbdmacro",     Key_Shift_F7   );
setkey  ("execute_macro",            Key_F8         );
setkey  ("emacs_escape_x",           Key_F10        );
setkey  ("compile",                  Key_Alt_F10    );

setkey  (". 4 brief_set_mark_cmd","\ea" ); % Alt A
%setkey ("list_buffers",          "\eb" ); % Alt B Buffers menu
setkey  ("brief_set_column_mark", "\ec" ); % Alt C
setkey  ("delete_line",           "\ed" ); % Alt D
%setkey ("find_file",             "\ee" ); % Alt E Edit    menu
%setkey ("display_file_name",     "\ef" ); % Alt F File    menu
setkey  ("goto_line_cmd",         "\eg" ); % Alt G
%setkey ("help_prefix",           "\eh" ); % Alt H Help    menu
%setkey ("toggle_overwrite",      "\ei" ); % Alt I Windows menu
setkey  ("bkmrk_goto_mark",       "\ej" ); % Alt J
setkey  ("kill_line",             "\ek" ); % Alt K
setkey  ("brief_line_mark",       "\el" ); % Alt L
%setkey  (". 1 brief_set_mark_cmd","\em" ); % Alt M Menu access prefix
setkey  ("brief_next_buffer(1)",  "\en" ); % Alt N
%setkey ("write_buffer",          "\eo" ); % Alt O Mode    menu
setkey  ("brief_next_buffer(-1)", "\ep" ); % Alt P; should be: print region
%setkey ("quote_next_key",        "\eq" ); % Alt Q
setkey  ("insert_file",           "\er" ); % Alt R
%setkey  ("brief_search_cmd",      "\es" ); % Alt S Search  menu
setkey  ("brief_replace_cmd",     "\et" ); % Alt T
setkey  ("undo",                  "\eu" ); % Alt U
%setkey ("brief_show_version",    "\ev" ); % Alt V
setkey  ("save_buffer",           "\ew" ); % Alt W
setkey  ("exit_jed",              "\ex" ); % Alt X
%
setkey (".0 brief_set_bkmrk_cmd", "\e0" ); % Alt 0
setkey (".1 brief_set_bkmrk_cmd", "\e1" ); % Alt 1
setkey (".2 brief_set_bkmrk_cmd", "\e2" ); % Alt 2
setkey (".3 brief_set_bkmrk_cmd", "\e3" ); % Alt 3
setkey (".4 brief_set_bkmrk_cmd", "\e4" ); % Alt 4
setkey (".5 brief_set_bkmrk_cmd", "\e5" ); % Alt 5
setkey (".6 brief_set_bkmrk_cmd", "\e6" ); % Alt 6
setkey (".7 brief_set_bkmrk_cmd", "\e7" ); % Alt 7
setkey (".8 brief_set_bkmrk_cmd", "\e8" ); % Alt 8
setkey (".9 brief_set_bkmrk_cmd", "\e9" ); % Alt 9

runhooks ("keybindings_hook", _Jed_Emulation);

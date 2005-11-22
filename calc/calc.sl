%------------------calc.sl-------------------------------------
%% Simple SLang calculator
%% Version: 1.35
%% Author:  Marko Mahnic <marko.mahnic@....si>
%%
%%-------------------------------------------------------------
%% History:
%%   1.35 Nov 2003
%%     * Switch between "Calculator" and "*calcres*" in single-wnidow mode
%%   1.3 Nov 2003
%%     * Changed by Guenter Milde to use definekey_reserved 
%%     * Added "calc" namespace (GM)
%%   1.25 Oct 2002
%%     * Added integer display mode
%%     * Menu updated
%%   1.2 May 2001
%%     * 1-D and 2-D array dump
%%     * "SLangCalc" mode, keymap
%%     * SLangCalc mode menu (text version only)
%%     * a call to calc_mode_hook() 
%%   1.1 May 2001
%%     * Single and double window mode
%%   1.0 May 2001
%%     * First release to the public at jed-users@yahoogroups.com
%%-------------------------------------------------------------
%%
%% To install put in .jedrc:  
%%     autoload ("calc", "calc.sl");
%%     autoload ("calc2", "calc.sl");
%%     
%% Usage:
%%     M-x calc
%%       or   
%%     M-x calc2
%%       for two-window mode.
%%
%% To get a Calc menu entry insert in your .jedrc:
%% 
%% if you have jed 99.13:
%%
%%      static define load_popups_hook (menubar)
%%      {
%%         %
%%         menu_insert_item (3, "Global.S&ystem", "Ca&lculate", "calc");
%%      }            
%%      variable Menu_Load_Popups_Hook = &load_popups_hook;
%%     
%% if you have a newer version than jed 99.13:
%% 
%%      define calc_load_popup_hook (menubar)
%%      {
%%         menu_insert_item (7, "Global.S&ystem", "Ca&lculate", "calc");
%%      }
%%      append_to_hook ("load_popup_hooks", &calc_load_popup_hook);
%% 
%% or insert the menu_insert_item() function to an already defined
%% *_load_popup_hook.
%%
%%
%% A simple calculator that takes a SLang expression, evaluates
%% it and prints the result in the form of a comment after the
%% expression.
%% 
%% If you use it with two windows, one window (Calculator) is used
%% to edit expressions, in the other one (*calcres*) the results 
%% are displayed.
%% 
%% The evaluation is started with calc_make_calculation() (^C^A if ^C is 
%% your _Reserved_Key_Prefix).
%% Use the calc_mode_hook to define your own bindings e.g. in your .jedrc:
%% 
%% define calc_mode_hook ()
%% {
%%    local_setkey ("calc_make_calculation", "^[^M");  % Alt-Return
%% }
%% 
%%   
%% The result of an expression is everything that is left on the
%% SLang stack after the expression is evaluated. 
%% The result of evaluation of
%%    1+1; 2+2;
%% would be
%%    2
%%    4,
%% but only 4 is written into the expression buffer. The other
%% results can be found in the result buffer using calc_result_window() (^C^W).
%% 
%% 
%% An expression can be any valid SLang code. Multiple expressions
%% can be divided by a tag with calc_next_expression() (^C^N).
%% 
%% There are 25 predefined variables ([a-z]) that can be used without 
%% declaration and displayed with calc_display_variables() (^C^V).
%% 
%% Use calc_help (^C^H) (or look at the mode menu) for help on keys.

#<INITIALIZATION>
_autoload("calc", "calc", "calc2", "calc", 2);
_add_completion("calc", "calc2", 2);
#</INITIALIZATION>

% set up a named namespace
implements("calc");

static variable buf_expr = "Calculator";
static variable buf_result = "*calcres*";
static variable history_tag = "%-------------- :-)";
static variable history_file = "";
static variable format = "%.6f";
static variable exprid = 0;
static variable kmp_calc = "SLangCalc";
static variable use_result_win = 0;
static variable use_result_comment = 1; % 0 never, 1 not for arrays, 2 always
static variable int_mode = 0; % 0 = dec, 1 = hex, 2 = oct, 3 = bin, 9 = all

static variable 
  a = 0, b = 0, c = 0, d = 0, e = 0, 
  f = 0, g = 0, h = 0, i = 0, j = 0, 
  k = 0, l = 0, m = 0, n = 0, o = 0, 
  p = 0, q = 0, r = 0, s = 0, t = 0, 
  u = 0, v = 0, w = 0, x = 0, y = 0, 
  z = 0;

static define calc_select_expression_buf ()
{
   pop2buf (buf_expr);
}

static define history_next ()
{
   re_fsearch ("^" + history_tag);
}

static define history_prev ()
{
   re_bsearch ("^" + history_tag);
}

public define calc_next_expression ()
{
   eob();
   !if (bobp()) 
   {
      variable empty = 0;
      
      while (not empty)
      {
	 go_up(1);
	 bol();
	 empty = (re_looking_at("^[ \t]*$"));
	 eob();
	 !if (empty) insert ("\n");
      }
   }
   
   exprid++;
   vinsert ("%s   E%d\n", history_tag, exprid);
}

static define calc_format_binary (val)
{
   variable hex = strup(sprintf("%x", val));
   variable len = strlen(hex);
   variable ch, i, bin = "";
   
   for (i = 0; i < len; i++)
   {
      ch = hex[i];
      if (ch < '8')
      {
         if (ch < '4')
         {
            if      (ch == '0') bin = bin + "0000";
            else if (ch == '1') bin = bin + "0001";
            else if (ch == '2') bin = bin + "0010";
            else if (ch == '3') bin = bin + "0011";
         }
         else
         {
            if      (ch == '4') bin = bin + "0100";
            else if (ch == '5') bin = bin + "0101";
            else if (ch == '6') bin = bin + "0110";
            else if (ch == '7') bin = bin + "0111";
         }
      }
      else
      {
         if (ch < 'C')
         {
            if      (ch == '8') bin = bin + "1000";
            else if (ch == '9') bin = bin + "1001";
            else if (ch == 'A') bin = bin + "1010";
            else if (ch == 'B') bin = bin + "1011";
         }
         else
         {
            if      (ch == 'C') bin = bin + "1100";
            else if (ch == 'D') bin = bin + "1101";
            else if (ch == 'E') bin = bin + "1110";
            else if (ch == 'F') bin = bin + "1111";
         }
      }
      
      if (i < len - 1) bin = bin + " ";
   }
   
   return bin;
}

static define calc_display_value(val, linepref);
static define calc_display_value(val, linepref)
{
   if (typeof (val) == String_Type)
   {
      vinsert ("%s\"%s\"", linepref, string (val));
      return;
   }
   else if (typeof (val) != Array_Type)
   {
      if (int_mode != 0 and typeof (val) == Integer_Type)
      {
         if      (int_mode == 1) vinsert ("%s0x%02x hex", linepref, val);
         else if (int_mode == 2) vinsert ("%s0%o oct", linepref, val);
         else if (int_mode == 3) vinsert ("%s%s bin", linepref, calc_format_binary(val));
         else if (int_mode == 9) 
            vinsert ("%s%d dec,  0%o oct,  0x%02x hex,  %s bin", 
                     linepref, val, val, val, calc_format_binary(val));
         return;
      }
      
      vinsert ("%s%s", linepref, string (val));
      return;
   }
   
   variable i, j;
   variable dims, num_dims, data_type;
   (dims, num_dims, data_type) = array_info (val);
   
   vinsert ("%sArray: %s\n", linepref, string (val));
   if (num_dims == 1)
   {
      calc_display_value (val[0], linepref);
      for (i = 1; i < dims[0]; i++)
      {
	 calc_display_value (val[i], ", ");
      }
   }
   else if (num_dims == 2)
   {
      for (i = 0; i < dims[0]; i++)
      {
	 calc_display_value (val[i, 0], linepref + "> ");
	 for (j = 1; j < dims[1]; j++)
	 {
	    calc_display_value (val[i, j], ", ");
	 }
	 if (i < dims[0]-1) insert("\n");
      }
   }
   else if (num_dims > 2)
   {
      calc_display_value (sprintf (" :( %d-D array ", num_dims), linepref);
   }
}

static define calc_display_stack ()
{
   variable res;
   
   if (_stkdepth () < 1) 
   {
      insert ("\t---\n");
      res = "---";
   }
   else
   {
      _stk_reverse (_stkdepth());
      while (_stkdepth ())
      {
         % res = string (());
         % insert ("\t" + res + "\n");
	 res = ();
	 calc_display_value (res, "\t");
	 insert ("\n");
      }
   }
   
   insert("\n");
   recenter (window_info ('r'));
   
   return (res);
}

public define calc_display_variables ()
{
   pop2buf (buf_result);
   eob ();
   variable iii, sss, ccc, www = SCREEN_WIDTH / 2 + 2;
   insert ("Variables:\n");
   for (iii = 'a'; iii <= 'm'; iii++)
   {
      insert(sprintf("    %c: %s", 
            iii, 
            string(eval(sprintf("use_namespace(\"calc\"); %c",iii)))));
      ccc = what_column();
      if (ccc < www) 
         insert_spaces (www - ccc);
      else
         insert (" | ");
      
      insert (sprintf ("%c: %s\n", 
            iii+13, 
            string(eval(sprintf("use_namespace(\"calc\"); %c",iii+13)))));
   }

   insert("\n");
   recenter (window_info ('r'));

   calc_select_expression_buf();
}

public define calc_result_window ()
{
   if (use_result_win)
   {
      pop2buf (buf_result);
      eob();
      recenter (window_info ('r'));
      calc_select_expression_buf();
   }
   else
   {
      if (whatbuf() != buf_result)
      {
         sw2buf (buf_result);
         recenter (window_info ('r'));
         use_keymap (kmp_calc);
      }
      else
      {
         sw2buf (buf_expr);
      }
   }
   
}

public define calc_make_calculation ()
{
   variable expr, id = "";
   
   _pop_n (_stkdepth());
   
   sw2buf (buf_expr);
   
   push_spot();
   eol ();
   !if (history_prev()) bob();
   else 
   {
      go_right (strlen(history_tag));
      skip_white();
      !if (eolp())
      {
	 push_mark();
	 eol();
	 id = strtrim (bufsubstr());
      }
      bol();
   }
   push_mark();
   eol ();
   !if (history_next()) eob();
   expr = bufsubstr();
   pop_spot();
   
   eval ("use_namespace(\"calc\");" + expr);

   if (use_result_win) pop2buf (buf_result);
   else setbuf (buf_result);
   
   eob ();
   
   if (id == "") insert ("R:\n");
   else vinsert ("R(%s):\n" ,id);

   variable nResults = _stkdepth();
   variable lastres = calc_display_stack();
   
   calc_select_expression_buf();
   
   %% Display the last result in expression buffer
   if (not use_result_win or use_result_comment)
   {
      push_spot();
      !if (history_next())
      {
	 pop_spot();
	 calc_next_expression();
	 push_spot();
	 history_prev();
      }

      go_up(1); bol();
      while (not bobp() and (re_looking_at("^[ \t]*$")))
      {
	 go_up(1); bol();
      }
      eol();

      % vinsert ("\n\t%%R:  %s", lastres);
      insert ("\n");

      if (use_result_comment < 2 and typeof(lastres) == Array_Type)
	 calc_display_value ("Array...", "\t%R:  ");
      else 
	 calc_display_value (lastres, "\t%R:  ");

      if (not use_result_win and nResults > 1) 
         vinsert ("  ...  (%d results)", nResults);
         
      pop_spot();
   }
}


static define calc_find_max_id ()
{
   variable id = 0;
   
   setbuf (buf_expr);
   push_spot();
   bob();
   exprid = 0;
   
   while (history_next())
   {
      go_right (strlen(history_tag));
      skip_white();
      !if (eolp())
      {
	 push_mark();
	 eol();
	 if (1 == sscanf (strtrim (bufsubstr()), "E%d", &id))
	    if (id > exprid) exprid = id;
      }
   }

   pop_spot();
}


public define calc_read_file ()
{
   setbuf (buf_expr);
   history_file = read_with_completion("Read file:", "", history_file, 'f');

   erase_buffer();
   () = insert_file (history_file);
   set_buffer_modified_flag (0);
   bob();
   calc_find_max_id();
}

public define calc_write_file ()
{
   setbuf (buf_expr);
   history_file = read_with_completion("Write to file:", "", history_file, 'f');
   
   push_spot();
   mark_buffer();
   () = write_region_to_file (history_file);
   pop_spot();
}

public define calc_float_format ()
{
   if (_NARGS > 0) format = ();
   else format = read_mini ("Float format:", format, "");
   
   set_float_format (format);
}

public define calc_help ()
{
   variable RKP = _Reserved_Key_Prefix;
   variable shlp = "Alt-Enter Evaluate  $rkp$F Format  $rkp$V Variables  $rkp$N New  $rkp$S Save  $rkp$R Read";
   
   !if (use_result_win) 
      shlp = shlp + "  $rkp$^W Results";
   
   shlp = str_replace_all(shlp, "$rkp$", RKP);
   message (shlp);
}

% changed by GM to use definekey_reserved 
% so it doesnot break existing keybindings
% The actual bindings are a concatenation of the variable 
% _Reserved_Key_Prefix [RKP] and what is defined here
static define calc_prepare_keymap ()
{
   !if (keymap_p (kmp_calc))
   {
      $1 = kmp_calc;
      copy_keymap ($1, "C");
      definekey_reserved ("calc_make_calculation", "^A", $1);
      definekey_reserved ("calc_make_calculation", "A", $1);
      definekey_reserved ("calc_make_calculation", "^M", $1);   % Return
      definekey_reserved ("calc_float_format", "^F", $1);
      definekey_reserved ("calc_float_format", "F", $1);
      definekey_reserved ("calc_help", "^H", $1);
      definekey_reserved ("calc_help", "H", $1);
      definekey_reserved ("calc_next_expression", "^N", $1);
      definekey_reserved ("calc_next_expression", "N", $1);
      definekey_reserved ("calc_read_file", "^R", $1);
      definekey_reserved ("calc_read_file", "R", $1);
      definekey_reserved ("calc_write_file", "^S", $1);
      definekey_reserved ("calc_write_file", "S", $1);
      definekey_reserved ("calc_display_variables", "^V", $1);
      definekey_reserved ("calc_display_variables", "V", $1);
      definekey_reserved ("calc_result_window", "^W", $1);
      definekey_reserved ("calc_result_window", "W", $1);
   }
   
   use_keymap (kmp_calc);
}

public define calc_reset_buffer()
{
   erase_buffer();
   exprid = 0;
   calc_next_expression();
}

static define init_menu (menu)
{
   variable menu_mode;
   menu_append_item (menu, "&Evalute", "calc_make_calculation");
   menu_append_item (menu, "&Variables", "calc_display_variables");
   menu_append_item (menu, "Result &window", "calc_result_window");
   menu_append_item (menu, "&New expression", "calc_next_expression");
   menu_append_item (menu, "&Read expressions", "calc_read_file");
   menu_append_item (menu, "&Save expressions", "calc_write_file");
   menu_append_item (menu, "&Y - Reset buffer", "calc_reset_buffer");
   menu_append_separator(menu);
   menu_append_popup(menu, "&Integer format");
   menu_append_item (menu, "&Float format", "calc_float_format");
   
   menu_mode = menu + ".&Integer format";
   menu_append_item (menu_mode, "&Bin mode", "calc_mode_bin");
   menu_append_item (menu_mode, "&Oct mode", "calc_mode_oct");
   menu_append_item (menu_mode, "&Dec mode", "calc_mode_dec");
   menu_append_item (menu_mode, "&Hex mode", "calc_mode_hex");
   menu_append_item (menu_mode, "&Combined mode", "calc_mode_all");
}

static define calc_start ()
{
   if (_NARGS > 0) use_result_win = ();
   
   if (use_result_win)
   {
      onewindow();
      splitwindow();
   
      % Bottom window: results
      if (window_info('t') == 1) otherwindow();
      sw2buf (buf_result);
   
      % Top window: expressions
   }
   
   pop2buf (buf_expr);
   slang_mode();
   
   set_mode ("SLangCalc", 2 |8);
   mode_set_mode_info ("SLangCalc", "init_mode_menu", &init_menu);
   calc_prepare_keymap();
   
   run_mode_hooks ("calc_mode_hook");
   
   set_float_format (format);
   if (bobp() and eobp())
   {
      calc_next_expression();
   }
}

public define calc_mode_dec()
{
   int_mode = 0;
}

public define calc_mode_hex()
{
   int_mode = 1;
}

public define calc_mode_oct()
{
   int_mode = 2;
}

public define calc_mode_bin()
{
   int_mode = 3;
}

public define calc_mode_all()
{
   int_mode = 9;
}

public define calc ()
{  
   calc_start (0);
}

public define calc2 ()
{
   calc_start (1);
}


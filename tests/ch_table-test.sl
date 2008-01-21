% ch_table-test.sl: 
% 
% Copyright (c) 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1 2006-03-03 

% Test ch_table.sl

% private namespace: `ch_table'

% set fixture:
require("unittest");

private variable teststring = "bar\n";
private variable testbuf = "*bar*";
static define setup()
{
   popup_buffer(testbuf);
   insert(teststring);
}
       
static define teardown()
{
   sw2buf(testbuf);
   set_buffer_modified_flag(0);
   close_buffer(testbuf);
}


% test the public defined functions:
test_equal(is_defined("ch_table"), 2, "ch_table() should be defined");
test_equal(is_defined("special_chars"), 2, "special_chars() should be defined");

require("ch_table");

% ch_table: library function  Undocumented
%  public define ch_table () % ch_table(StartChar = 0)
static define test_ch_table()
{
   ch_table();
   test_equal(whatbuf(), "*ch_table*");
   close_buffer("*ch_table*");
}

% special_chars: library function  Undocumented
%  public define special_chars ()
static define test_special_chars()
{
   special_chars();
   test_equal(whatbuf(), "*ch_table*");
   close_buffer("*ch_table*");
}

% ct_load_popup_hook: library function  Undocumented
%  define ct_load_popup_hook (menubar)
% test_function("ct_load_popup_hook");

% int2string: undefined  Undocumented
%  static define int2string(i, base)
test_function("ch_table->int2string", 32, 10);
test_last_result("32");
test_function("ch_table->int2string", 32, 16);
test_last_result("20");
test_function("ch_table->int2string", 32, 8);
test_last_result("40");
test_function("ch_table->int2string", 32, 2);
test_last_result("100000");

% string2int: undefined  Undocumented
%  static define string2int(s, base)
test_function("ch_table->string2int", "32", 10);
test_last_result(32);
test_function("ch_table->string2int", "20", 16);
test_last_result(32);
test_function("ch_table->string2int", "40", 8);
test_last_result(32);
test_function("ch_table->string2int", "100000", 2);
test_last_result(32);

% ct_status_line: undefined  Undocumented
%  static define ct_status_line()
% test_function("ch_table->ct_status_line");

% ct_update: undefined  Undocumented
%  static define ct_update ()
% test_function("ch_table->ct_update");

% ct_up: undefined  Undocumented
%  static define ct_up ()
% test_function("ch_table->ct_up");

% ct_down: undefined  Undocumented
%  static define ct_down ()
static define test_ct_down()
{
   variable cc;
   special_chars();
   ch_table->ct_down();
   test_equal(170, what_char(), 
	      "special_chars(); ct_down() should set point to char 170");
   close_buffer("*ch_table*");
}

% ct_right: undefined  Undocumented
%  static define ct_right ()
% test_function("ch_table->ct_right");

% ct_left: undefined  Undocumented
%  static define ct_left ()
% test_function("ch_table->ct_left");

% ct_bol: undefined  Undocumented
%  static define ct_bol ()   { bol; ct_right;}
% test_function("ch_table->ct_bol");

% ct_eol: undefined  Undocumented
%  static define ct_eol ()   { eol; ct_update;}
% test_function("ch_table->ct_eol");

% ct_bob: undefined  Undocumented
%  static define ct_bob ()   { goto_line(3); ct_right;}
% test_function("ch_table->ct_bob");

% ct_eob: undefined  Undocumented
%  static define ct_eob ()   { eob; ct_update;}
% test_function("ch_table->ct_eob");

% ct_mouse_up_hook: undefined  Undocumented
%  static define ct_mouse_up_hook (line, col, but, shift)
% test_function("ch_table->ct_mouse_up_hook");

% ct_mouse_2click_hook: undefined  Undocumented
%  static define ct_mouse_2click_hook (line, col, but, shift)
% test_function("ch_table->ct_mouse_2click_hook");

% ct_goto_char: undefined  Undocumented
%  static define ct_goto_char ()
% test_function("ch_table->ct_goto_char");

% insert_ch_table: undefined  Undocumented
%  static define insert_ch_table ()
% test_function("ch_table->insert_ch_table");

% use_base: undefined  Undocumented
%  static define use_base (numbase)
% test_function("ch_table->use_base");

% ct_change_base: undefined  Undocumented
%  static define ct_change_base ()
% test_function("ch_table->ct_change_base");

% setup_dfa_callback: undefined  Undocumented
%  static define setup_dfa_callback (mode)
% test_function("ch_table->setup_dfa_callback");

% ct_insert_and_close: undefined  Undocumented
%  static define ct_insert_and_close ()
static define test_ct_insert_and_close()
{
   % open char-table, go to second line, insert-and-close
   special_chars();
   ch_table->ct_down();
   ch_table->ct_insert_and_close();
   % get inserted char
   push_mark();
   go_left_1();
   test_equal(bufsubstr(), char(170), "should insert char nr 170");
}


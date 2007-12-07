% test-calc.sl: % Test calc.sl
% 
% Copyright (c) 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1 2006-03-03 basic test for errors with call of public functions


require("unittest");
% private namespace: `calc'

% Open the calc buffer


% calc: library function  Undocumented
%  public define calc ()
test_function("calc");
test_last_result();
test_equal(whatbuf(), "Calculator");


% calc2: library function  Undocumented
%  public define calc2 ()
test_function("calc2");
test_last_result();

% clean up and abort (TODO test remaining functions)
sw2buf("Calculator");
set_buffer_modified_flag(0);
delbuf("Calculator");
delbuf("*calcres*");
#stop

% calc_select_expression_buf: undefined  Undocumented
%  static define calc_select_expression_buf ()
test_function("calc->calc_select_expression_buf");
test_last_result();

% history_next: undefined  Undocumented
%  static define history_next ()
test_function("calc->history_next");
test_last_result();

% history_prev: undefined  Undocumented
%  static define history_prev ()
test_function("calc->history_prev");
test_last_result();

% calc_next_expression: undefined  Undocumented
%  public define calc_next_expression ()
test_function("calc_next_expression");
test_last_result();

% calc_format_binary: undefined  Undocumented
%  static define calc_format_binary (val)
test_function("calc->calc_format_binary");
test_last_result();

% calc_display_value: undefined  Undocumented
%  static define calc_display_value(val, linepref);
test_function("calc->calc_display_value");
test_last_result();

% calc_display_value: undefined  Undocumented
%  static define calc_display_value(val, linepref)
test_function("calc->calc_display_value");
test_last_result();

% calc_display_stack: undefined  Undocumented
%  static define calc_display_stack ()
test_function("calc->calc_display_stack");
test_last_result();

% calc_display_variables: undefined  Undocumented
%  public define calc_display_variables ()
test_function("calc_display_variables");
test_last_result();

% calc_result_window: undefined  Undocumented
%  public define calc_result_window ()
test_function("calc_result_window");
test_last_result();

% calc_make_calculation: undefined  Undocumented
%  public define calc_make_calculation ()
test_function("calc_make_calculation");
test_last_result();

% calc_find_max_id: undefined  Undocumented
%  static define calc_find_max_id ()
test_function("calc->calc_find_max_id");
test_last_result();

% calc_read_file: undefined  Undocumented
%  public define calc_read_file ()
test_function("calc_read_file");
test_last_result();

% calc_write_file: undefined  Undocumented
%  public define calc_write_file ()
test_function("calc_write_file");
test_last_result();

% calc_float_format: undefined  Undocumented
%  public define calc_float_format ()
test_function("calc_float_format");
test_last_result();

% calc_help: undefined  Undocumented
%  public define calc_help ()
test_function("calc_help");
test_last_result();

% calc_prepare_keymap: undefined  Undocumented
%  static define calc_prepare_keymap ()
test_function("calc->calc_prepare_keymap");
test_last_result();

% calc_reset_buffer: undefined  Undocumented
%  public define calc_reset_buffer()
test_function("calc_reset_buffer");
test_last_result();

% init_menu: undefined  Undocumented
%  static define init_menu (menu)
test_function("calc->init_menu");
test_last_result();

% calc_start: undefined  Undocumented
%  static define calc_start ()
test_function("calc->calc_start");
test_last_result();

% calc_mode_dec: undefined  Undocumented
%  public define calc_mode_dec()
test_function("calc_mode_dec");
test_last_result();

% calc_mode_hex: undefined  Undocumented
%  public define calc_mode_hex()
test_function("calc_mode_hex");
test_last_result();

% calc_mode_oct: undefined  Undocumented
%  public define calc_mode_oct()
test_function("calc_mode_oct");
test_last_result();

% calc_mode_bin: undefined  Undocumented
%  public define calc_mode_bin()
test_function("calc_mode_bin");
test_last_result();

% calc_mode_all: undefined  Undocumented
%  public define calc_mode_all()
test_function("calc_mode_all");
test_last_result();

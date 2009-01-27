% test-console_keys.sl:  Test console_keys.sl
% 
% Copyright © 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1 2006-03-03 just test evaluating the file


require("unittest");




test_function("evalfile", "console_keys");
test_last_result(1);

testmessage("\n  console_keys.sl needs interactive testing in a Linux console");
#stop

% define set_console_keys()
% set_console_keys: undefined  Undocumented
test_function("set_console_keys");
test_last_result();

% define restore_console_keys()
% restore_console_keys: undefined  Undocumented
test_function("restore_console_keys");
test_last_result();


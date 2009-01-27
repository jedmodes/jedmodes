% test-css1.sl:  Test css1.sl
% 
% Copyright Â© 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1 2006-03-03 


require("unittest");


sw2buf("*scratch*");


% public define css1_mode() {
% css1_mode: library function  Undocumented
test_function("css1_mode");
test_last_result();
test_equal(get_mode_name(), "css1");

no_mode();

% test the automatic mode setting at loading a file
test_function("find_file", "test.css"); % new file, empty buffer
test_equal(get_mode_name(), "css1");
if (bufferp("test.css"))
  delbuf("test.css");

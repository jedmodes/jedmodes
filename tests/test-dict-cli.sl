% test-dict-cli.sl:  Test dict-cli.sl
% 
% Copyright © 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1 2006-03-03 

% This test requires an internet connection (to reach "dict.org") or a running
% dictd on localhost (customize by (un)commenting the right host variable).
% 
% Is there a way to test the returned results?

require("unittest");
require("dict-cli");

% fixture
private variable word = "line";
private variable host = "dict.org";    % public dict server
% private variable host = "localhost"; % local dict server
private variable database = "!";       % server default
private variable strategy = ".";       % server default
private variable what = "db";

sw2buf("*scratch*");
erase_buffer();
while(markp())
  pop_mark_0();

% define dict_define(word, database, host)
% dict_define: library function  Undocumented
test_function("dict_define", word, database, host);
test_last_result();
erase_buffer();

% define dict_match(word, strategy, database, host)
% dict_match: library function  Undocumented
test_function("dict_match", word, strategy, database, host);
test_last_result();
erase_buffer();

% define dict_show(what, host)
% dict_show: library function  Undocumented
test_function("dict_show", what, host);
test_last_result();
erase_buffer();

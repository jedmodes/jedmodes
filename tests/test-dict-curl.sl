% test-dict-curl.sl:  Test dict-curl.sl
% 
% Copyright (c) 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1 2006-03-03 

% This test requires the curl slang module as well as
% an internet connection (to reach "dict.org") or a running
% dictd on localhost (don't forget to customize the host variable).
% 
% Is there a way to test the inserted results?

require("unittest");

% testmessage("at my site, dict-curl crashs ('Speicherzugriffsfehler') Jed" +
%    "Jed Version: 0.99.18, S-Lang Version: 2.0.6, slang-curl 0.1.1-5");
% throw AssertionError, "() = evalfile(\"dict-curl\"); crashs Jed";

() = evalfile("dict-curl");

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
test_function("dict_define", word, database, host);test_last_result();
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

sw2buf("*test report*");
view_mode();

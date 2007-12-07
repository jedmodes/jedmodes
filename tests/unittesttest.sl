% unittesttest.sl: test the SLang unittest framework
% 
% This self-testing is quite verbose and out of line with the remaining unit
% tests so it deliberately named not to match the "-test"
% Unittest_File_Pattern.
% 
% Copyright (c) 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1 2006-03-03 
% 0.3 2006-09-25  * adapted to unittest version 0.3
%                 * undo Error_Count increase in case of correct behaviour
%                   of the test functions

require("unittest");
require("sprint_var");

static variable results, err, a=1, b=3, last_error_count;


testmessage("\n\nAssertions");
% ----------

% here, we put the AssertionError in a try-catch phrase to keep on
% evaluating the unittest test script
try (err)
{
   if (a != b)
     throw AssertionError, "$a != $b"$;
   % this code should not be reached:
   testmessage("E: AssertionError not thrown ");
   unittest->Error_Count++;
}
catch AssertionError:
{
   testmessage("OK: wrong assertion threw AssertionError.");
}



testmessage("\n\nTruth and Equality\n");
% ------------------------------------

testmessage("\ntest_true(): true args must not show in the report");
test_true(1+1 == 2, "# 1+1 should be 2, test_true failed");

last_error_count = unittest->Error_Count;
test_true(1+1 == 3);
if (unittest->Error_Count == last_error_count + 1)
{
   testmessage("\n OK: 1+1 == 3 is FALSE, so test_true() works fine");
   unittest->Error_Count--;
}

testmessage("\ntest_equal(): this should not show in the report");
test_equal(1+1, 2, "# test_equal failed: 1+1 should be 2");

last_error_count = unittest->Error_Count;
test_equal(1+1, 3);
if (unittest->Error_Count == last_error_count + 1)
{
   testmessage("\n OK: 1+1 != 3, so test_equal() works fine");
   unittest->Error_Count--;
}


testmessage("\n\nStack hygiene\n");
% -------------------------------

testmessage("\n empty stack, so there should be no response");
test_stack();
testmessage("\n now push 2 values on stack");
42, "baa";

last_error_count = unittest->Error_Count;
test_stack();
if (unittest->Error_Count == last_error_count + 1)
{
   testmessage("\n OK: garbage on stack detected");
   unittest->Error_Count--;
}

testmessage("\n\ntest for exceptions:\n");
% ----------------------------------------

private define zero_division()
{
   return 23/0;
}

testmessage("\n non defined function:");
err = test_for_exception("foo");
testmessage("\n  result: %S %s", typeof(err), sprint_variable(err));

testmessage("\n no exception:");
err = test_for_exception("what_line");
testmessage("\n  result: " + sprint_variable(err));

testmessage("\n zero division:");
err = test_for_exception(&zero_division);
testmessage("\n  result: " + sprint_error(err));


testmessage("\n\nFunction testing:\n");
% -------------------------------------

testmessage(" working cases");
test_function("sprintf", "%d", 8);
test_last_result("8");
test_function("eval", "3+4");
test_last_result(7);
test_function(&bol);
test_last_result();

testmessage(" catching bugs");
last_error_count = unittest->Error_Count;
test_function("sprintf", "%d", 8);
test_last_result("8");
if (unittest->Error_Count == last_error_count + 1)
{
   testmessage("\n OK: catched wrong return value");
   unittest->Error_Count--;
}

last_error_count = unittest->Error_Count;
test_function("non_defined");
if (unittest->Error_Count == last_error_count + 1)
{
   testmessage("\n OK: catched non defined function");
   unittest->Error_Count--;
}

last_error_count = unittest->Error_Count;
test_function("message", NULL);
if (unittest->Error_Count == last_error_count + 1)
{
   testmessage("\n OK: catched wrong usage");
   unittest->Error_Count--;
}

last_error_count = unittest->Error_Count;
test_function("zero_division");
if (unittest->Error_Count == last_error_count + 1)
{
   testmessage("\n OK: catched buggy function");
   unittest->Error_Count--;
}

last_error_count = unittest->Error_Count;
test_function(&what_line);
test_last_result();
if (unittest->Error_Count == last_error_count + 1)
{
   testmessage("\n OK: catched unexpected return value");
   unittest->Error_Count--;
}


testmessage("\n\nRun a test script:\n");
% ------------------------------------

% () = test_file(path_concat(path_dirname(__FILE__), "datutils-test.sl"));
% () = test_file("uffe.sl");  % not present

testmessage("\n\nRun a test suite:\n");
% ------------------------------------

() = test_files("fooli/"); % invalid dir
() = test_files("/home/milde/.jed/lib/test/*datutils*.sl");

testmessage("\n\nRun a test suite and exit Jed:\n");
% --------------------------------------------------

testmessage("\n skipped");
% () = test_files_and_exit("/home/milde/.jed/lib/test/*datutils*.sl");

message("Done");

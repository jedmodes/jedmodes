% unittest.sl: Framework for testing jed extensions
%
% Copyright (c) 2006 G�nter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% This script needs SLang 2
%
% Versions:
% 0.1   2006-07-12 first experimental release
% 0.2   2006-09-19 test_function() now saves the result in unittest->Last_Result
% 0.3   2006-09-29 test discovery analogue to the python nose test framework
%                  (http://somethingaboutorange.com/mrl/projects/nose/) and
%                  py.test (http://codespeak.net/py/current/doc/test.html)
%                  find and evaluate all functions matching 
%                  Unittest_Function_Pattern
% 0.3.1 2006-10-05 added requirements
% 0.4   2007-02-06 removed _lists_equal() and is_equal(), using _eqs() instead
% 0.4.1 2007-07-25 added test_unequal()

require("sl_utils");  % push_defaults, ...
require("datutils");  % push_list, pop2list, ...
autoload("popup_buffer", "bufutils");
autoload("buffer_dirname", "bufutils");
autoload("sprint_variable", "sprint_var");

implements("unittest");

% Customization
% -------------


custom_variable("Unittest_Reportfile", "testreport.txt");

% The regexp pattern for test-file detection
% % Test or test as word in a file with ".sl" extension
custom_variable("Unittest_File_Pattern", "\C\<test\>.*\.sl$"R);

% The regexp pattern for test-function detection (Test_ or test_ as substring)
custom_variable("Unittest_Function_Pattern", "\Ctest_"R); 


%!%+
%\variable{Unittest_Skip_Patterns}
%\synopsis{Skip test considered "long"?}
%\usage{variable Unittest_Skip_Patterns = ["interactive"]}
%\description
%  To save time or ressources, tests matching one of this
%  array of regexp patterns are skipped, even if they match the
%  \var{Unittest_Function_Pattern}.
%  
%  The default will skip tests that have the string "interactive" somewhere
%  in their name.
%\seealso{test_buffer, test_file, test_files, test_files_and_exit}
%!%-
custom_variable("Unittest_Skip_Patterns", ["interactive"]);



static variable reportbuf = "*test report*";
% number of errors in one file
static variable Error_Count = 0;
% list of return value(s) of the last function tested with test_function
static variable Last_Result = {};

% plural 's' or not? usage: sprintf("%d noun%s", num, plurals(num!=1));
private variable plurals = ["", "s"]; 

%!%+
%\variable{AssertionError}
%\synopsis{Exception class for failed assertions}
%\usage{throw AssertionError, "message"}
%\description
%  Exception class to mark the failure of an assertion.
%  Based on RunTimeError.
%
%  Use this for critical assertions where it doesnot make sense to continue
%  evaluating the script (because of follow-on errors).
%\example
%  Make an assertion that \var{a} is true:
%#v+
%   !if (a)
%     throw AssertionError, "$a not TRUE"$;
%#v-
%\notes
%  One could be tempted to put the example code in an \sfun{assert}
%  definition. However, the error message would then give the function
%  definition as place where the error occured. Therefore it is better to
%  throw the AssertionError directly in the test script.
%\seealso{test_equal, test_true, try, catch, new_exception, RunTimeError}
%!%-
!if (is_defined("AssertionError"))
  new_exception("AssertionError", RunTimeError, "False Assertion");

% Auxiliary functions
% -------------------

% Print a list to a string (simple version, see sprint_variable.sl for full)
% (Also, this version doesnot add the {} around the elements)
private define _sprint_list(lst)
{
   variable element, str = "";
   foreach (lst)
     {
        element = ();
        if (NULL != wherefirst(typeof(element) == [String_Type, BString_Type]))
          str += ", " + make_printable_string(element);
        else
          str += ", " + string(element);
     }
   return str[[2:]];
}

% _sprint_list({1,2,"3", NULL});
% _sprint_list({});
% _sprint_list({{8}});

public define sprint_error(err)
{
   return sprintf("'%s' in %s:%d %s ", 
      err.descr, err.file, err.line, err.message);
}

% The test functions
% ------------------

%!%+
%\function{testmessage}
%\synopsis{Show a message string and log it in the "*test report*" buffer}
%\usage{testmessage(fmt, ...)}
%\description
%  Show a message (with \var{vmessage}) and insert a copy into a "*test
%  report*" buffer using \sfun{vinsert}. Return to the previous buffer.
%\example
%  Report if a function is defined:
%#v+
%    !if (is_defined(fun))
%       testmessage("%s E: not defined!\n", fun);
%#v-
%\notes
%  This test for existence is part of \sfun{test_function}.
%\seealso{vmessage, vinsert, test_function}
%!%-
public  define testmessage() % (fmt, ...)
{
   variable buf = whatbuf(), args = pop2list(_NARGS);
   sw2buf(reportbuf);
   set_readonly(0);
   eob;
   vinsert(push_list(args));
   set_buffer_modified_flag(0);
   % view_mode();
   sw2buf(buf);
   args[0] = str_replace_all(args[0], "\n", " ");
   vmessage(push_list(args));
}

%!%+
%\function{test_true}
%\synopsis{Test if \var{a} is true}
%\usage{test_true(a, comment="")}
%\description
%  Test if \var{a} is true, report if not.
%\seealso{_eqs, test_equal}
%!%-
public  define test_true() % (a, comment="")
{
   variable a, comment;
   (a, comment) = push_defaults( , "", _NARGS);

   if (a)
     return;
   testmessage("\n  E: '%s' is not true. %s", sprint_variable(a), comment);
   Error_Count++;
}


%!%+
%\function{test_equal}
%\synopsis{Test if \var{a} equals \var{b}}
%\usage{ test_equal(a, b, comment="")}
%\description
%  Test if \var{a} equals \var{b}, report if not.
%\seealso{_eqs, test_unequal, test_true}
%!%-
public  define test_equal() % (a, b, comment="")
{
   variable a, b, comment;
   (a, b, comment) = push_defaults( , , "", _NARGS);
   
   !if (_eqs(a, b))
     {
        testmessage("\n  E: %s==%s failed. %s", 
           sprint_variable(a), sprint_variable(b), comment);
        Error_Count++;
     }
}

%!%+
%\function{test_unequal}
%\synopsis{Test if \var{a} differs from \var{b}}
%\usage{ test_unequal(a, b, comment="")}
%\description
%  Compare \var{a} and \var{b}, fail if they are equal.
%\seealso{_eqs, test_equal, test_true}
%!%-
public  define test_unequal() % (a, b, comment="")
{
   variable a, b, comment;
   (a, b, comment) = push_defaults( , , "", _NARGS);
   
   if (_eqs(a, b))
     {
        testmessage("\n  E: %s!=%s failed. %s", 
           sprint_variable(a), sprint_variable(b), comment);
        Error_Count++;
     }
}

% test the stack for leftovers
public  define test_stack() % (comment="")
{
   variable comment = push_defaults("", _NARGS);
   variable leftovers = pop2list();
   if (length(leftovers) > 0)
     {
        testmessage("\n  E: garbage on stack: %s, %s", 
           _sprint_list(leftovers), comment);
        Error_Count++;
     }
}

% try a function and return exception or NULL
% store list of return value(s) in Last_Result
public define test_for_exception() % (fun, [args])
{
   variable args = pop2list(_NARGS-1);
   variable fun = ();
   
   variable err = NULL, stack_before = _stkdepth();
   
   % convert string to function reference
   if (typeof(fun) == String_Type)
     fun = __get_reference(fun);
   
   % test-run the function
   try (err)
     {
        if (fun == NULL)
          throw UndefinedNameError, "tested function not defined";
        @fun(push_list(args));
     }
   catch AnyError: {}
   % store return value(s)
   Last_Result = pop2list(_stkdepth()-stack_before);
   return err;
}


%!%+
%\function{test_function}
%\synopsis{Test a SLang function}
%\usage{Void test_function(fun, [args])}
%\description
%  Test a function in a try-catch environment and report success.
%
%  The return value(s) of the function is saved as a list in
%  \var{unittest->Last_Result} and reported in the report buffer.
%\example
%#v+
%    test_function("eval", "3+4");
%#v-
%  reports
%#v+
%    eval(3+4): OK (7)
%#v-
%  and sets \var{unittest->Last_Result} to {7}, while
%#v+
%    test_function("message", NULL);
%#v+
%  reports
%#v+
%     message(NULL): 'Type Mismatch' in /home/milde/.jed/lib/unittest.sl:-1, Unable to typecast Null_Type to String_Type
%#v-
%  and sets \var{unittest->Last_Result} to {}.
%\notes
%  If execution of the function throws an exeption, \var{unittest->Error_Count}
%  is increased by 1.
%\seealso{run_function, testmessage, test_file, test_files}
%!%-
public define test_function() % (fun, [args])
{
   variable args = pop2list(_NARGS-1);
   variable fun = ();
   variable err, error_count_before = Error_Count;
   
   % test-run the function
   testmessage("\n  %S(%s): ", fun, _sprint_list(args));
   err = test_for_exception(fun, push_list(args));
   if (err != NULL)
     {
        testmessage("E: %s", sprint_error(err));
        Error_Count++;
     }
   % report return value(s)
   if (length(Last_Result))
     testmessage(" => (%s)", 
        str_replace_all(_sprint_list(Last_Result), "\n", "\\n"));
   if (Error_Count == error_count_before)
     testmessage(" OK");
}

% Test if the return value of a tested function equals the expected
% result (This is basically a list comparision of pop2list(args) with
% unittest->Last_Result and with special report settings)
public  define test_last_result() % args
{
   variable expected_result = pop2list(_NARGS);
   % silently pass if Last_Result meets expectations
   if (_eqs(Last_Result, expected_result))
     return;
   testmessage("\n  E: return value is not (%s) ",
      _sprint_list(expected_result));
   Error_Count++;
}

%!%+
%\function{test_file}
%\synopsis{Evaluate \var{file}, report exceptions, return their number}
%\usage{test_file(file)}
%\description
%  * Evaluate a test file its own namespace.
%  * Run the setup() function if it exists
%  * Test all static functions matching \var{Unittest_Function_Pattern}.
%  * Run the teardown() function if it exists
%  * Report exceptions in the "*test report*" buffer.
% setup(), teardown(), and test functions must be defined as \var{static}.
%\notes
%  If the last reported error is an exception, there might be
%  more hidden errors after it.
%\seealso{test_files, test_function, test_stack, AssertionError}
%!%-
public define test_file(file)
{
   variable err, leftovers, testfuns, testfun, skips=0,
     _setup, _teardown, _mode_setup, _mode_teardown, 
     namespace = "_" + path_sans_extname(path_basename(file));
   
   namespace = str_replace_all(namespace, "-", "_");
   % Ensure a clean start
   leftovers = pop2list();
   if (length(leftovers) > 0)
     testmessage("\n garbage on stack: %s", _sprint_list(leftovers));
   % reset the error count with every compilation unit
   Error_Count = 0; 

   % evaluate the file/buffer in its own namespace
   testmessage("\n %s: ", path_basename(file));
   try (err)
     () = evalfile(file, namespace);
   catch OpenError:
     {
        testmessage("\n  E: %s ", sprint_error(err));
        Error_Count++;
        return;
     }
   catch AnyError:
     {
        testmessage("\n  E: %s ", sprint_error(err));
        Error_Count++;
     }
   test_stack();

   _setup = __get_reference(namespace+"->setup");
   _teardown = __get_reference(namespace+"->teardown");
   _mode_setup = __get_reference(namespace+"->mode_setup");
   _mode_teardown = __get_reference(namespace+"->mode_teardown");

   % test functions matching the test pattern
   if (_mode_setup != NULL)
          @_mode_setup();
   testfuns = _apropos(namespace, Unittest_Function_Pattern, 2);
   % testmessage("\n\n " + sprint_variable(testfuns));
   testfuns = testfuns[array_sort(testfuns)];
   foreach testfun (testfuns)
     {
        if (wherefirst(array_map(Int_Type, 
                       &string_match, testfun, Unittest_Skip_Patterns, 1))
            != NULL)
          {
             testmessage("\n  %s: skipped", testfun);
             skips++;
             continue;
          }
        testfun = namespace+"->"+testfun;
        if (_setup != NULL)
          @_setup();
        test_function(testfun);
        test_stack();
        if (_teardown != NULL)
          @_teardown();
     }
   if (_mode_teardown != NULL)
          @_mode_teardown();
   if (Error_Count)
     testmessage("\n ");
   testmessage("\n %d error%s", Error_Count, plurals[Error_Count!=1] );
   if (skips)
     testmessage("\n %d test%s skipped (matching '%s')",
        skips, plurals[skips!=1], strjoin(Unittest_Skip_Patterns, "' or '"));
}

% test the current buffer
public define test_buffer()
{
   save_buffer();
   test_file(buffer_filename());
   popup_buffer(reportbuf);
   view_mode();
   % goto last error
   () = bsearch("E:");
}


% forward declaration
public define test_files();

%!%+
%\function{test_files}
%\synopsis{Evaluate test-scripts in \var{dir}}
%\usage{test_files(dir="")}
%\description
%  * Evaluate directory-wide fixture script setup.sl if it exists
%  * Run \slfun{test_file} on all files in \var{dir} that match the given
%    basename pattern (globbing) or the regexp \var{Unittest_File_Pattern} 
%  * Evaluate directory-wide fixture script teardown.sl if it exists
%\notes
% TODO: % gobbing of dirname part.
%\seealso{test_file, test_buffer, test_function, Unittest_File_Patterns}
%!%-
public define test_files() % (dir="")
{
   variable path = push_defaults("", _NARGS);
   
   variable dir = path_concat(buffer_dirname(), path_dirname(path));
   variable pattern = path_basename(path);
   variable files = listdir(dir);
   variable setup_file = path_concat(dir, "setup.sl");
   variable teardown_file = path_concat(dir, "teardown.sl");
   variable file, match, no_of_errors = 0, no_of_files;

   % separate and preprocess file list
   if (pattern == "")
     pattern = Unittest_File_Pattern;
   else
     pattern = glob_to_regexp(pattern);
   testmessage("\ntest_files in '%s' matching '%s': ", dir, pattern);

   if ((files == NULL) or (length(files) == 0))
     {
        if (file_status(dir) != 2)
          {
             testmessage("\n E: directory '%s' doesnot exist ", dir);
             return 1;
          }
        testmessage("\n no matching files found in '%s' ", dir);
        return 0;
     }

   match = array_map(Int_Type, &string_match, files, pattern, 1);

   files = files[where (match)];
   files = files[array_sort(files)];
   files = array_map(String_Type, &path_concat, dir, files);

   no_of_files = length(files);
   variable plural = plurals[no_of_files!=1];
   testmessage("testing %d file%s|dir%s ", no_of_files, plural, plural);
   update_sans_update_hook(1); % flush message
   
   if (1 == file_status(setup_file))
     evalfile(setup_file);
   foreach (files)
     {
        file = ();
        switch (file_status(file))
          { case 1: test_file(file); no_of_errors += Error_Count;}
          { case 2: no_of_errors += test_files(path_concat(file, ""));}
     }
   testmessage("\n%d file%s|dir%s, %d error%s ", no_of_files, plural, plural,
      no_of_errors, plurals[no_of_errors!=1]);
   if (1 == file_status(teardown_file))
     evalfile(teardown_file);

   popup_buffer(reportbuf);
   view_mode();
   return no_of_errors;
}

public define test_files_and_exit()
{
   variable args = pop2list(_NARGS), no_of_errors;
   
   no_of_errors = test_files(push_list(args));
   % append report buffer to report file
   sw2buf(reportbuf);
   mark_buffer();
   () = append_region_to_file(Unittest_Reportfile);

   exit(no_of_errors);
}

provide("unittest");


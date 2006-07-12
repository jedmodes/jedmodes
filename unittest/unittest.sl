% unittest.sl: Framework for testing jed extensions
%
% Copyright (c) 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% This script needs SLang 2
%
% Versions:
% 0.1 2006-07-12 first experimental release

require("sl_utils");  % push_defaults, ...
require("datutils");  % push_list, pop2list, ...

implements("unittest");

custom_variable("Unittest_Reportfile", "testreport.txt");
static variable reportbuf = "*test report*";
static variable Error_Count = 0;
private variable plural = ["", "s"]; % usage: sprintf("%d noun%s", num, plural(num!=1));

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
%  Make an assertion that \var{a} == \var{b}:
%#v+
%   if (a != b)
%     throw AssertionError, "$a != $b"$;
%#v-
%\notes
%  If I put the example code in an \sfun{assert} definition, the error message
%  would give the function definition code as place where the error occured.
%  Therefore it is better to throw the AssertionError directly in the test
%  script.
%\seealso{try, catch, new_exception, RunTimeError}
%!%-
!if (is_defined("AssertionError"))
  new_exception("AssertionError", RunTimeError, "False Assertion");

% Auxiliary functions
% -------------------

% Print a list to a string (simple version, see sprint_variable.sl for full)
% (Also, this version doesnot add the {} around the elements)
private define _sprint_list(lst)
{
   variable object, str = "";
   foreach (lst)
     {
        object = ();
        if (NULL != wherefirst(typeof(object) == [String_Type, BString_Type]))
           object = make_printable_string(object);
        str += ", "+ string(object);
     }
   return str[[2:]];
}

% _sprint_list({1,2,"3", NULL});
% _sprint_list({});

public define sprint_error(err)
{
   return sprintf("'%s' in %s:%dm %s ", err.descr, err.file, err.line, err.message);
}

static define _lists_equal(a, b)
{
   variable i;
   if (length(a) != length(b))
     return 0;
   for (i=0; i<length(a); i++)
     {
        try
          {
             if (a[i] != b[i])
               return 0;
          }
        catch TypeMismatchError:
          return 0;
     }
   return 1;
}

% _lists_equal({1}, {"foo"});                 % 0
% _lists_equal({1, 2}, {1,2});                % 1
% _lists_equal({1, 2}, {1,2,"foo"});          % 0
% _lists_equal({1, "foo", 2}, {1,2,"foo"});   % 0

% The test functions
% ------------------

%!%+
%\function{testmessage}
%\synopsis{Put a test message into the "*test report*" buffer}
%\usage{testmessage(fmt, ...)}
%\description
%  Insert a test message into a "*test report*" buffer using \sfun{vinsert}.
%  Return to the previous buffer.
%\example
%  Report if a function is defined:
%#v+
%    !if (is_defined(fun))
%       testmessage("%s E: not defined!\n", fun);
%#v-
%\notes
%  This test for existence is part of \sfun{test_function}.
%\seealso{vinsert, test_function}
%!%-
public  define testmessage() % (fmt, ...)
{
   variable buf = whatbuf(), args = __pop_args(_NARGS);
   sw2buf(reportbuf);
   set_readonly(0);
   eob;
   vinsert(__push_args(args));
   set_buffer_modified_flag(0);
   % view_mode();
   sw2buf(buf);
}

% Test if \var{a} is true
public define test_true() % (a, comment="")
{
   variable a, comment;
   (a, comment) = push_defaults( , "", _NARGS);

   if (a)
     return;
   testmessage("\n  E: Truth test failed. $comment"$);
   Error_Count++;
}

% Test if \var{a} equals \var{b}:
public define test_equal() % (a, b, comment="")
{
   variable a, b, comment;
   (a, b, comment) = push_defaults( , , "", _NARGS);

   variable err, result;
   try (err)
     {
        if (typeof(a) == Array_Type and typeof(b) == Array_Type)
          if (length(where(a==b)) == length(a))
            return;
        if (typeof(a) == List_Type and typeof(b) == List_Type)
          if (_lists_equal(a, b))
            return;
        if (a == b)
          return;
     }
   catch AnyError:
     {
        testmessage("\n  E: %s", sprint_error(err));
     }
   testmessage("\n  E: '$a'=='$b' failed. $comment"$);
   Error_Count++;
}

% test the stack for relics
public define test_stack()
{
   variable relics;
   if (_stkdepth)
     {
        relics = pop2list();
        testmessage("\n  E: garbage on stack: %s", _sprint_list(relics));
        Error_Count++;
     }
}

%!%+
%\function{test_function}
%\synopsis{Test a SLang function}
%\usage{ListType test_function(fun, [args])}
%\description
%  Test a function in a try-catch environment and report success.
%
%  The return value(s) of the function will be returned as a list (so that
%  there is always one return value for test_function) and reported in the
%  report buffer.
%\example
%#v+
%    results = test_function("eval", "3+4");
%#v-
%  reports
%#v+
%    eval(3+4): OK (7)
%#v-
%  and returns {7}, while
%#v+
%    test_function("message", NULL);
%#v+
%  reports
%#v+
%     message(NULL): 'Type Mismatch' in /home/milde/.jed/lib/unittest.sl:-1, Unable to typecast Null_Type to String_Type
%#v-
%\notes
%  If execution of the function throws an exeption, the static variable Error_Count
%  is increased by 1.
%\seealso{run_function, test_eval, testmessage, test_file, test_files}
%!%-
public define test_function() % (fun, [args])
{
   variable args = pop2list(_NARGS-1);
   variable fun = ();
   variable err, results = {}, stack_before = _stkdepth();

   testmessage("\n  $fun(%s): "$, _sprint_list(args));
   % convert string to function reference
   if (typeof(fun) == String_Type)
     fun = __get_reference(fun);
   if (fun == NULL)
     {
        testmessage("E: function not defined");
        Error_Count++;
        return results;
     }
   % test-run the function
   try (err)
     {
        @fun(push_list(args));
        testmessage("OK ");
     }
   catch AnyError:
     {
        testmessage("E: %s", sprint_error(err));
        Error_Count++;
     }
   % handle return value(s)
   results = pop2list(_stkdepth()-stack_before);
   testmessage("(%s)", str_replace_all(_sprint_list(results), "\n", "\\n"));
   return results;
}

% Test if the return value of a tested function equals the expected result
% (This is basically a list comparision with special report settings)
public  define test_return_value(results, expected_results)
{
   if (_lists_equal(results, expected_results))
     return;
   testmessage("\n  E: return value is not (%s) ",
      _sprint_list(expected_results));
   Error_Count++;
}

%!%+
%\function{test_eval}
%\synopsis{Evaluate expression, report success, return results as list}
%\usage{test_eval(expression)}
%\description
%  Test an expression in a try-catch environment and report success.
%  The return value will be popped appended to the report line and returned
%  as list.
%\example
%  While \sfun{test_equal} reports only a failure of the assertion and
%  increases the error count,
%#v+
%    result = test_eval("3 == NULL");
%#v-
%  will set result to {0}, report the result of the comparision and not
%  increase the error count if the return value is FALSE.
%\notes
%  \sfun{test_eval} calls \sfun{test_function} with \sfun{eval} and
%  \var{expression} as arguments. To eval \var{expression} in a given
%  namespace, call test_function directly as e.g.
%#v+
%    test_function(&eval, "3 == NULL", "dict");
%#v-
%\seealso{test_true, test_equal, test_file, eval, test_function, testmessage}
%!%-
public  define test_eval(expression)
{
   test_function("eval", expression);
}

%!%+
%\function{test_file}
%\synopsis{Evaluate \var{file}, report exceptions, return their number}
%\usage{test_file(file)}
%\description
%  Evaluate a file, report exceptions in the "*test report*" buffer and
%  return no of catched errors.
%\notes
%  If the last reported error is an exception in the file, there might be
%  more hidden errors after the point of
%\seealso{test_files}
%!%-
public define test_file(file)
{
   Error_Count = 0; % reset the error count with every file
   testmessage("\n %s: ", path_basename(file));
   variable err;
   try (err)
        () = evalfile(file);
   catch AnyError:
     {
        testmessage("  E: %s ", sprint_error(err));
        Error_Count++;
     }
   test_stack();
   % testmessage("\n $Error_Count error%s"$, plural[Error_Count!=1] );
   return Error_Count;
}

% evaluate files matching \var{pattern}
%
% \var{pattern} uses globbing syntax, it may include a directory
% part, which will be preceded by \sfun{getcwd} if it is a relative path.
public define test_files() % (path="*.sl"))
{
   variable path = push_defaults("*.sl", _NARGS);
   % separate and preprocess
   variable dir = expand_filename(path_dirname(path));
   variable pattern = glob_to_regexp(path_basename(path));
   variable files = listdir(dir);
   variable match, result, no_of_files;

   testmessage("\ntest_files(\"$path\"): "$);

   if ((files == NULL) or (length(files) == 0))
     {
        if (file_status(dir) != 2)
          testmessage("directory '$dir' doesnot exist ");
        else
          testmessage("no matching files found in '$dir' "$);
        return 1;
     }

   match = array_map (Int_Type, &string_match, files, pattern, 1);

   files = files[where (match)];
   files = files[array_sort(files)];
   files = array_map(String_Type, &path_concat, dir, files);

   no_of_files = length(files);
   testmessage("testing $no_of_files file%s "$, plural[no_of_files!=1]);
   flush("testing $no_of_files files in $dir"$);
   result = array_map(Int_Type, &test_file, files);

   result = array_sum(result);

   testmessage("\n$no_of_files file%s, $result error%s "$,
      plural[no_of_files!=1], plural[Error_Count!=1]);

   message("tested $no_of_files files, found $result error(s)"$);
   return array_sum(result);
}

public define test_files_and_exit()
{
   variable args = pop2list(_NARGS);
   test_files(push_list(args));
   % append report buffer to report file
   sw2buf(reportbuf);
   mark_buffer();
   () = append_region_to_file(Unittest_Reportfile);

   exit_jed();
}

provide("unittest");


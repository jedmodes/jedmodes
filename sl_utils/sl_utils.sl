% Various programming utils that are used by most of my other modes.
%
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Version    1.0   first public release
%            1.1   new: max(), contract_filename()
%            1.2   new: normalize_modename(), what_line_if_wide()
%            1.3   backwards compatibility: emulate run_program() if not
%                  existent (works only in xjed)
% 2004-03-22 1.3.1 bugfix in contract_filename() error if  HOME
%                  environment variable is missing (report Thomas Koeckritz)
%            1.3.2 removed max(), as it contradicts the intrinsic max()
%                  definition (which resembles array_max() from datutils.sl)
% 2005-04-11 1.4   new function prompt_for_argument()
%                  added provide("sl_utils")
%            1.5   new function _implements(): implement a "named" namespace
%                  but allow re-evaluation if `_debug_info` is TRUE
% 2005-05-23 1.5.1 bugfix in _implements(): separate _implement and provide,
%                  do not rely on _featurep()
% 2005-06-07 1.5.2 moved run_program emulation to compat16-15.sl

% _debug_info = 1;

provide("sl_utils");

%!%+
%\function{push_defaults}
%\synopsis{Push n args to the stack}
%\usage{(a_(n+1), ..., a_m) = push_defaults(a_1, ..., a_m, n)}
%\description
% Push n args to the stack. Helps to define a slang function with
% optional arguments.
%\example
% A function with one compulsory and two optional arguments
%#v+
% define fun() % (a1, a2="d2", a3=whatbuf())
% {
%    variable a1, a2, a3;
%    (a1, a2, a3) = push_defaults( , "d2", whatbuf(), _NARGS);
%    vmessage("(%S, %S, %S, %S)", a1, a2, a3, a4);
% }
%#v-
% results in:
%   fun(1)       %  --> (1, d2, *scratch*)
%   fun(1, 2)    %  --> (1, 2, *scratch*)
%   fun(1, 2, 3) %  --> (1, 2, 3, 4)
% but
%   fun()        %  --> (NULL, d2, *scratch*)  !!compulsory arg missing!!
%   fun(1, , )   %  --> (1, NULL, NULL)  !!empty args replaced with NULL!!
%\notes
% Do not forget the _NARGS argument!
% The arguments to push_default will always be evaluated. If time is an issue,
% rather use a construct like
%#v+
% define fun() % (a=time_consuming_fun())
% {
%    !if (_NARGS)
%      time_consuming_fun();
%    variable a = ();
%    ...
% }
%#v-
%
%\seealso{__push_args, __pop_args, _NARGS }
%!%-
define push_defaults() % args, n
{
   variable n = ();
   variable args = __pop_args(_NARGS-1);
   __push_args(args[[n:]]);
}

%!%+
%\function{prompt_for_argument}
%\synopsis{Prompt for an optional argument if it is not given.}
%\usage{Str prompt_for_argument(Ref prompt_function, [args], Int use_stack)}
%\description
%  This function facilitates the definition of function with optional
%  arguments.
%
%  The first argument is a prompt function (e.g. \var{read_mini} or
%  \var{read_with_completion}, followed by its arguments and the
%  \var{use_stack} argument.
%
%  If \var{use_stack} is non-zero, this function simply returns and
%  the calling code picks up the top element from stack.
%  Otherwise, \var{prompt_function} is called with the given arguments
%  (except when the minibuffer is already active, in which case an error
%  is risen).
%\example
%#v+
%  define prompt_for_message() % ([str])
%  {
%     variable str = prompt_for_argument(&read_mini,
%                                        "Message:", "", "", _NARGS);
%     message(str);
%  }
%#v-
%\seealso{push_defaults, _NARGS, read_mini, read_with_completion}
%!%-
define prompt_for_argument() % (fun, [args], use_stack)
{
   variable use_stack = ();
   variable args = __pop_args(_NARGS-2);
   variable fun = ();
   if (use_stack)
     return;  % argument is already on stack
   else
     {
        if (MINIBUFFER_ACTIVE) % cannot use minibuffer for prompting
          error("missing argument");
        return @fun(__push_args(args));
     }
}

%!%+
%\function{push_array}
%\synopsis{Push an ordinary array on stack}
%\usage{(a[0], ..., a[-1])  push_array(Array a)}
%\description
% Push the elements of an array to the stack. This works like
% __push_args(args) but with an ordinary array (all types)
%\example
%#v+
%   variable a = ["message", "hello world"];
%   runhooks(push_array(a));
%#v-
%\notes
%   Elements of an Any_Type-array are references. They are dereferenced
%   in order to get type-independend behaviour.
%\seealso{array, pop2array, __push_args, __pop_args}
%!%-
define push_array(a)
{
   if (_typeof(a) == Any_Type)
        foreach (a)
             if (dup == NULL)
               ();
             else
              @();
   else
     foreach (a)
       ();
}

%!%+
%\function{get_blocal}
%\synopsis{return value of blocal variable or default value}
%\usage{Any get_blocal (String name, [Any default=NULL])}
%\description
% This function is similar to get_blocal_var, but if the local variable
% "name" doesnot exist, it returns the default value instead of an error.
% Default defaults to NULL.
%\example
%#v+
%    if (get_blocal(foo), 0)
%      message("this buffer is fooish");
%#v-
% will print the message if foo is a blocal variable with nonzero value.
%\seealso{get_blocal_var, blocal_var_exists}
%!%-
define get_blocal() % (name, default=NULL)
{
   variable name, default;
   (name, default) = push_defaults( , NULL, _NARGS);

   if (blocal_var_exists(name))
     return get_blocal_var(name);
   return default;
}

%!%+
%\function{run_function}
%\synopsis{Run a function if it exists.}
%\usage{Int_Type run_function(fun, [args])}
%\description
% Run a function if it exists. Return whether it exists or not
% The function can be given by name or by reference (this allows both:
% yet undefined function (as string) as well as static functions
% (as reference)
% Any arguments following the function argument will be passed to the
% function.
%\example
%#v+
%
%    !if (run_function("foo"))
%       message("\"foo\" is not defined");
%
%    !if (run_function(&foo))
%       message("\"foo\" is not defined");
%#v-
%\notes
% If fun is (solely) an internal function, the optional arguments will
% be popped.
%\seealso{runhooks, run_blocal_hook}
%!%-
define run_function()  % (fun, [args])
{
   variable args = __pop_args(_NARGS-1);
   variable fun = ();
   if (typeof(fun) == String_Type)
     {
        if (is_defined(fun) > 0)
          fun = __get_reference(fun);
        else if (is_internal(fun))
          {
             call(fun);
             return 1;
          }
     }
   if (typeof(fun) == Ref_Type)
     {
        @fun(__push_args(args));
        return 1;
     }
   return 0;
}

%!%+
%\function{contract_filename}
%\synopsis{Make a filename as short as possible without ambiguity}
%\usage{ contract_filename(file, cwd=getcwd())}
%\description
%  The opposite of expand_filename (in some case of view)
%  Make a filename as short as possible while
%  expand_filname will restore it to the previous value.
%\notes
%  * If the path starts with the working dir, strip it.
%  (This maight fail on case insensitive filesystems).
%  * If the path starts with the home-dir, replace it with "~".
%\seealso{expand_filename}
%!%-
define contract_filename() % (file, cwd=getcwd())
{
   variable file, cwd;
   (file, cwd) = push_defaults( , getcwd(), _NARGS);
   variable home = getenv("HOME");
   % strip leading cwd
   cwd = path_concat(cwd, ""); % ensure that cwd has a trailing dirsep
   if (is_substr(file, cwd) == 1)
     file = file[[strlen(cwd):]];
   % or replace HOME with ~
   else if (andelse{home != NULL}{strlen(home)})
     {
        home = path_concat(home, ""); % ensure home has a trailing dirsep
        if (is_substr(file, home) == 1)
          file = path_concat("~", file[[strlen(home):]]);
     }
   return file;
}

% when a buffer is folded what_line may give the false number
define what_line_if_wide ()
{
  if (count_narrows ())
    {
      push_narrow ();
      widen_buffer ();
      what_line ();
      pop_narrow ();
    }
  else
    what_line ();
}

define _implements(name)
{
#ifexists _slang_utf8_ok
  implements(name);        % SLang 2 has a re-evaluation save implements()
#else
  if (length(where(name == _get_namespaces())) and _debug_info)
    use_namespace(name);
  else
    implements(name);
#endif
}

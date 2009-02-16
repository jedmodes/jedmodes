% Diagnostic functions for SLang programmers
% show the value of variables (nice for debugging)
% 
% Copyright © 2006 Günter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
% 
% Version 1.0 2003-07-09  * first public version
% Version 1.1 2005-03-21  * added tm documentation to public functions


autoload("popup_buffer", "bufutils");
autoload("fit_window", "bufutils");
autoload("view_mode", "view");
require("sprint_var");

%!%+
%\variable{Diagnose_Buffer}
%\synopsis{Name of the buffer used by show() and related diagnostic functions}
%\description
%   The show* diagnostic functions show their output in a special popup 
%   buffer. Diagnose_Buffer sets the name of this buffer (defaulting to
%   "*debug*").
%\seealso{show_string, show, vshow, show_object, show_stack, show_eval}
%!%-
custom_variable("Diagnose_Buffer", "*debug*");

% popup the diagnose buffer with n lines / using n+100 percent of space
% (set to 0 for don't fit)
custom_variable("Diagnose_Popup", 0.3);

%!%+
%\function{show_string}
%\synopsis{Insert the argument at the end of the Diagnose_Buffer}
%\usage{show_string(Str str)}
%\description
%   Open a popup buffer and insert \var{str}.
%\seealso{pop2buf, show, Diagnose_Buffer}
%!%-
public define show_string(str)
{
   variable calling_buf = whatbuf();
   popup_buffer(Diagnose_Buffer, Diagnose_Popup);
   set_readonly(0);
   eob;
   insert(strcat("\n", str, "\n"));
   set_buffer_modified_flag (0);
   view_mode();
   fit_window(get_blocal_var("is_popup"));
   pop2buf(calling_buf);
}


%!%+
%\function{sprint_args}
%\synopsis{Return a formatted string of the argument list}
%\usage{Str sprint_args(args)}
%\description
%   Take a variable number of arguments, convert to a strings with
%   \sfun{sprint_variable()} and return the concatenated strings.
%\seealso{show, mshow}
%!%-
public define sprint_args() % args
{
   variable arg, n=_NARGS, sep=" ", strarray = String_Type[n];
   loop(n)
     {
	n--;
	arg = sprint_variable(());  % convert to a string
	if(is_substr(arg, "\n"))
	   sep = "\n";
	strarray[n] = arg;
     }
   return strjoin(strarray, sep) + sep;
}


%!%+
%\function{show}
%\synopsis{Show the content of the argument list in the \var{Diagnose_Buffer}.}
%\usage{show(args)}
%\description
%   Take a variable number of arguments, convert to strings with
%   sprint_variable() and show in the \var{Diagnose_Buffer}.
%\example
%#v+
%   show(TAB, [1, 2, 3, 4])
%#v-
%\notes
%   This is my basic debugging tool. show_object() shows even more info, 
%   but in most cases show() will suffice.
%   
%   Using sprint_variable() instead of string for the "anything -> string"
%   conversion results in the verbose representation of composite variables
%   (arrays, associative-arrays, etc).
%   
%\seealso{show_string, vshow, mshow, show_object, show_stack, show_eval}
%!%-
public define show() % args
{
   variable args = __pop_args(_NARGS);
   show_string(sprint_args(__push_args(args)));
}

%!%+
%\function{vshow}
%\synopsis{Show a sprintf style argument list in the diagnose buffer}
%\usage{vshow(args)}
%\description
%   Convert the argument list to a string using sprintf() and show it
%   in the \var{Diagnose_Buffer} using show_string().
%\seealso{sprintf, vmessage, verror, show_string}
%!%-
public define vshow() % args
{
   variable args = __pop_args(_NARGS);
   show_string(sprintf(__push_args(args)));
}


%!%+
%\function{mshow}
%\synopsis{Show the content of the argument list in the minibuffer}
%\usage{mshow(args)}
%\description
%   Convert the arguments to a string with sprint_args() and 
%   show as message in the minibuffer.
%\notes
%   For output that spans several lines and for a more permanent record use
%   show() instead of mshow()
%\seealso{show, sprint_args, message}
%!%-
public define mshow() % args
{
   variable args = __pop_args(_NARGS);
   message(sprint_args(__push_args(args)));
}

public define show_in_scratch() % args
{
   variable args = __pop_args(_NARGS);
   variable buf = whatbuf();
   sw2buf("*scratch*");
   insert(sprint_args(__push_args(args)));
   sw2buf(buf);
}

%!%+
%\function{show_object}
%\synopsis{put debug information in a debug buffer }
%\usage{Void show_object (String item [, String hint]);}
%\usage{Void show_object (Ref_Type item [, String hint]);}
%\description
% Inserts the actual value of item (or "not defined") into a diagnose buffer.
% An optional argument hint is appended to the output.
% The hint string may contain valid sprint format specifiers 
% (like %s) with the appropriate variables as additional arguments. 
% If the first argument is "", only the hint is written.
%\example
% For example
%       variable CA;
%       variable CU = "kuckuck";
%       show_object ("CA");
%       show_object ("cu");
%       show_object ("CU", "a hint");
%       show_object ("", "I'm here at %s", time ());
%       show_object ("foo");
%       show_object ("bol");
%       show_object ("center_line");
% result in the following diagnose buffer
%       CA:   not initialized
%       cu:   not defined
%       CU == kuckuck	% a hint
%       % I'm here at 07:21
%       foo:	 user defined function
%       bol:	 intrinsic function
%       center_line:	 internal function
% TODO: Currently only globally defined variables and functions are detected 
%       if given as strings. Use the second format with reference (pointer) 
%       for static variables or functions and function-local variables.
%       blocal variables need to be given as strings.
%        
%\seealso{show, vshow}
%!%-
public define show_object() % (object, [hint= ""])
{
   % get arguments
   variable hint = "";         % optional second argument
   variable object;              % name of object to output info about
   if (_NARGS > 1)
     {
	variable args = __pop_args(_NARGS-1);
	hint = sprintf (__push_args(args));
     }
   object = ();  % take 1st arg from stack (might be String or Reference)  
   
   variable ref = NULL;                  % reference to object
   variable str = "";	                 % output string
   variable value = " <Uninitialized>";	 % variable value
   
   EXIT_BLOCK 
     {
	if (hint != "")
	  str += "\t% " + hint;
	show_string(str);
     }

   % Get String_Type object and Ref_Type ref
   if (typeof(object) == Ref_Type) % Reference given, convert to a string
     {
	ref = object;
	object = string(object)[[1:]];  % without leading '&'
	if (object == "ocal Variable Reference") % for local Variables 
	  object = "Local variable ";
     }
   else % object is already a string
     {
	object = string(object);
	ref = __get_reference(object);
     }
   
   % determine type of object
   switch (is_defined(object))
     { case +1 :  str = object + ": intrinsic function"; return;}
     { case +2 :  str = object + ": library function"; return;}
     { case  0 :  % not globally defined
	if (is_internal(object))
	  {
	     str = object + ":\t internal function"; 
	     return;
	  }
	else if (blocal_var_exists(object))
	  {
	     str = "Blocal variable " + object
	       + " == " + sprint_variable(get_blocal_var(object));
	     return;
	  }
	else if (ref == NULL)
	  {
	     str = object + " <Undefined> (or local/static given as string)"; 
	     return;
	  }
	else
	  str = object;
     }
     { case -1 :  str = "Intrinsic variable " + object;}
     { case -2 :  str = "Library variable " + object;}
   
   % add variable value
   if (__is_initialized(ref))
     value = " == " + sprint_variable(@ref);
   str += value;
}


%!%+
%\function{show_stack}
%\synopsis{Show a listing of the stack, emptying the stack }
%\usage{show_stack()}
%\description
%   Pop all items from the stack and show them in the Diagnose_Buffer.
%\notes
%   This is a nice tool to find out about functions leaving rubbish on 
%   the stack.
%\seealso{show, _pop_n, _stkdepth, pop, stack_check}
%!%-
public define show_stack()
{
   variable element;
   if (_stkdepth)
     {
	show_string("Stack listing: ");
	loop(_stkdepth)
	  {
	     element = ();
	     show(element);
	  }
     }
   else
     show_string("Stack empty");
}


%!%+
%\function{show_eval}
%\synopsis{Show the (String_Type) argument(s) and the result of their evaluation.}
%\usage{show_eval(String args)}
%\description
%   Take a variable number of strings and show the string and the result of
%   its evaluation in the Diagnose_Buffer
%\example
%#v+
%   show_eval("TAB", "WRAP")
%#v-
%\notes
%   The string will be evaluated in the global namespace, so static
%   variables and functions are only accessible in a "named namespace"
%   via the usual "namespace_name->variable_name" notation.
%\seealso{show, vshow, mshow}
%!%-
public define show_eval() % args
{
   variable arg;
   _stk_reverse(_NARGS);
   loop(_NARGS)
     {
	arg = ();
	show(arg, eval(arg));
     }
}


private variable last_stkdepth = 0;

% modus: 0 set, 1 warn, 2 error
define stack_check(modus)
{
   variable str, change = _stkdepth - last_stkdepth;
   if (modus == 0)
     { 
	last_stkdepth = _stkdepth(); 
	return; 
     }
   
   str = sprintf("stackcheck: Stack changed by %d", change);
   
   if (modus == 1)
     message(str);
   else if (modus == 2 and (_stkdepth() != last_stkdepth))
     error(str);
}
   

provide("diagnose");

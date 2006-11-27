% datutils.sl: convenience functions for several Data_Types
% 
% Copyright (c) 2006 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% VERSIONS 
% 1.0   first public release
% 1.1   new functions pop2array, array, null_fun, array_repeat,
%       array_fill_missing
% 1.2   removed array_concat, array_append, array_insert
%       after learning about [[1,2],3] == [1,2,3]
%       removed array_fill_missing (buggy)
% 1.2.1 reincluded array_append
%       (as [[1,2],[3,4]] -> 2d Array in SLang < 1.16)
%       moved string_repeat and string_reverse to strutils.sl
% 1.2.2 bugfix in array_max(), the definition in sl_utils contrdicted
%       the intrinsic one which resembles array_max() (report PB)
% 1.2.3 removed "public" keyword from all functions
% 1.2.3 added provide("datutils");
% 2.0   2006-06-22 added list functions, full tm documentation
% 2.1   2006-10-04 added list_concat()
% 2.2   2006-11-27 removed array_reverse(): it is not used anywhere and 
% 		   conflicts with the internal SLang function of the same 
% 		   name (not activated by default in Jed)

_autoload(
   "push_defaults", "sl_utils",
   "push_array", "sl_utils",
   2);


% --- Array functions ------------------------------------------

% helper functions
define null_fun() {}

static define dereference(arg)
{
   return @arg;
}
static define typeof_ref(ref)
{
   return typeof(@ref);
}

%!%+
%\function{pop2array}
%\synopsis{Return N stack-items as an array of type \var{type}}
%\usage{Array_Type pop2array(N=_stkdepth, [type])}
%\description
% Return an array that consists of the N topmost stack elements.
% The top element becomes element arr[N-1].
% If \var{type} is not given, autodetermine it (fall back to \var{Any_Type}
% if the element types differ).
%\notes
% Attention: dont use \sfun{pop2array} in a function call with optional
% arguments , i.e. not
%#v+
%  show(pop2array())
%#v-
% but
%#v+
%  $1 = pop2array(); 
%  show($1);
%#v-
%\seealso{array, pop2list, push_array}
%!%-
define pop2array() % (N=_stkdepth, [type])
{
   variable n=_stkdepth(), type;
   (n, type) = push_defaults(n, Any_Type, _NARGS);
   variable i, a = type[n];
   for (i=n-1; i>=0; i--)
	a[i] = ();
   if (_NARGS >= 2 or n == 0) % type argument given or no elements
     return a;
   % autodetermine type
   variable types = array_map(DataType_Type, &typeof_ref, a);
   if(length(where(types == types[0])) == n) % all args of same type
     return array_map(types[0], &dereference, a);
   return a; % i.e. _typeof(a) == Any_Type
}

%!%+
%\function{array}
%\synopsis{Return an array containing the arguments}
%\usage{Array_Type array([args])}
%\description
%  Pack the arguments into an array and return it.
%  The type is autodetermined (defaulting to \var{Any_Type}
%  if the element types differ).
%\notes
% If you know the datatype of the arguments, you can save resources pushing
% the arguments first and using \sfun{pop2array} with the datatype argument.
%#v+
%    (arg1, ...., argN);
%    a = pop2array(N, datatype)
%#v-
% instead of (the simpler)
%#v+
%    a = array(arg1, ...., argN);
%#v-
%\seealso{pop2array, push_array, list2array}
%!%-
define array() %([args])
{
   return pop2array(_NARGS);
}

%!%+
%\function{array_append}
%\synopsis{Append a value to an array or concatenate \var{a} and \var{b}}
%\usage{Array = array_append(a, b)}
%\description
% \sfun{array_append} provides a means to use 1d-arrays like lists. It
% concatenates \var{a} and \var{b}. 
%  
% The arguments may be of any type and will be converted to Array_Type (if
% the not already are) before the concatenation.
%\example
% The following statemants are all TRUE:
%#v+
%  array_append(1,2)          == [1,2]
%  array_append(1, [2,3,4])   == [1,2,3,4]
%  array_append([1,2], [3,4]) == [1,2,3,4]
%  array_append([1,2,3], 4)   == [1,2,3,4]
%#v-
%\notes
% For arrays with 1000 values, it becomes time-consuming (0.13 s),
% for 2000 values annoying (0.5 s) and for 5000 values prohibitive (3 s)
% (CPU-time on a AMD-Duron 700MHz under Linux)
%\seealso{list_append}
%!%-
define array_append(a, b)
{
   if (typeof(a) != Array_Type)
     a = [a];
   if (typeof(b) != Array_Type)
     b = [b];
   !if (length(a)) % empty array
     return b;
   variable c = _typeof(a)[length(a)+length(b)];
   c[[:length(a)-1]] = a;
   c[[length(a):]] = b;
   return c;
}

%!%+
%\function{array_delete}
%\synopsis{Delete the element(s) at position(s) \var{N}}
%\usage{Array_Type array_delete(Array_Type a, Integer_Type N)}
%\usage{Array_Type array_delete(Array_Type a, Array_Type N)}
%\description
% Return a slice of all positions not in \var{N}.
% This provides a means to use 1d-arrays like lists.
%\example
%#v+
%  array_delete([1,2,3,4], 0)      == [2,3,4]
%  array_delete([1,2,3,4], [0,1])  == [3,4]
%  array_delete([1,2,3,4], [0,-1]) == [2,3]
%  array_delete([1,2,3,4], -1)     == [1,2,3]
%#v-
%\notes
% For arrays with 1000 values, it becomes time-consuming (0.09 s),
% for 2000 values annoying (0.32 s) and for 5000 values prohibitive (1.83 s).
% With SLang 2, consider using the new List_Type instead.
%\seealso{array_append, where, list_delete}
%!%-
define array_delete(a, n)
{
   variable i = Int_Type[length(a)];
   i[n] = 1;
   i = where(not(i));
   return a[i];
}


%!%+
%\function{array_max}
%\synopsis{Return the maximal value of an array}
%\usage{result = array_max(Array_Type a)}
%\description
%  The \sfun{array_max} function examines the elements of a numeric array and
%  returns the value of the largest element.
%\example
%#v+
%  array_max([1,2,30,4] == 30
%#v-
%\notes
% \sfun{max} is a slang intrinsic since 1.4.6. (but must be activated manually)
%\seealso{array_sum, array_product, max, min}
%!%-
define array_max(a)
{
#ifnexists max
   variable maximum = a[0], element;
   foreach(a)
     {
	element = ();
	if (element > maximum)
	  maximum = element;
     }
   return maximum;
#else
   return max(a);
#endif
}

%!%+
%\function{array_sum}
%\synopsis{Return the sum of the array elements}
%\usage{result = array_sum(a)}
%\description
%  Sum up the values of a numeric array and return the result.
%\notes
% \sfun{sum} is a slang intrinsic since 1.4.6. (but must be activated manually)
%\seealso{array_max, array_product, sum}
%!%-
define array_sum(a)
{
   variable sum = 0;
   foreach (a)
     sum += ();
   return sum;
}


%!%+
%\function{array_product}
%\synopsis{Return the product of the array elements}
%\usage{result = array_product(a)}
%\description
%  Multiply the values of a numeric array and return the result.
%\seealso{array_sum, array_max}
%!%-
define array_product(a)
{
   variable product = 1;
   foreach (a)
     product *= ();
   return product;
}


%!%+
%\function{array_value_exists}
%\synopsis{Return the number of occurences of \var{value} in array \var{a}}
%\usage{Integer_Type array_value_exists(a, value)}
%\description
%  Count, how many times \var{value} is present in array \var{a}. 
%  For normal arrays, this is equal to
%#v+
%    length(where(a == value))
%#v-
%  while special care is taken to get meaningfull results with arrays of
%  \var{Any_Type}.
%\seealso{where, wherefirst, wherelast, assoc_value_exists}
%!%-
define array_value_exists(a, value)
{
   if (_typeof(a) != Any_Type)
     return length(where(a == value));

   variable element, i=0;
   foreach (a)
     {
	element = ();
	if (andelse {element != NULL}
	      	    {typeof(@element) == typeof(value)}
	       	    {@element == value}
	    )
	  i++;
     }
   return (i);
}

%!%+
%\function{array_repeat}
%\synopsis{Repeat an array \var{N} times}
%\usage{Array_Type array_repeat(a, N)}
%\description
% Concatenate an array N-1 times to itself and return the result.
%\seealso{string_repeat, array_append}
%!%-
define array_repeat(a, n)
{
   variable i, len_a = length(a);
   variable aa = _typeof(a)[n*len_a];
   for (i=0; i <= length(aa)-1; i +=len_a)
     aa[[i:i+len_a-1]] = a;
   return aa;
}


%!%+
%\function{array_transpose}
%\synopsis{Swap the axes of a 2d array}
%\usage{Array_Type array_transpose(a)}
%\description
%  Swap rows and columns of a 2dimensional array.
%\seealso{array_info, reshape}
%!%-
define array_transpose(a)
{
   variable i, dim, dimensionality, type;
   (dim, dimensionality, type) = array_info(a);
   !if (dimensionality == 2)
     error("array_transpose expects a 2d-array");
   variable b = @Array_Type(type, [dim[1], dim[0]]);
   for (i=0; i<dim[0]; i++)
     b[*,i] = a[i,*];
   return b;
}

% --- Associative Array functions -----------------------------------

% find out if the associative array contains value
%!%+
%\function{assoc_value_exists}
%\synopsis{Return the number of occurences of \var{value} in \var{ass}}
%\usage{Integer_Type assoc_value_exists(Assoc_Type ass, value)}
%\description
%  Count, how many times \var{value} is present in the associative 
%  array \var{ass}. 
%\seealso{array_value_exists, assoc_key_exists, assoc_get_key, assoc_get_values}
%!%-
define assoc_value_exists(ass, value)
{
   array_value_exists(assoc_get_values(ass), value);
}


%!%+
%\function{assoc_get_key}
%\synopsis{Return the key of a value of an Associative Array}
%\usage{String_Type key = assoc_get_key(ass, value)}
%\description
%  Reverse the usual lookup of an hash table (associative array). Return the
%  first key whose value is equal to \var{value}.
%\notes
%  Of course, this function is far slower than the corresponding ass[key].
%\seealso{assoc_value_exists}
%!%-
define assoc_get_key(ass, value)
{
   variable key;
   foreach (ass) using ("keys")
     {
	key = ();
	if (ass[key] == value)
	  return key;
     }
}

% --- List functions -------------------------------------------

% The list type is new in SLang2
#ifexists _slang_utf8_ok

%!%+
%\function{push_list}
%\synopsis{Push the list elements on the stack}
%\usage{push_list(List_Type lst)}
%\description
%  Push all elements of a list to the stack. 
%  Very convenient for converting a list to an argument list.
%\example
%#v+
%  variable args = {"foo ", "bar ", "uffe "};
%  variable str = strjoin(push_list(args));
%#v-
%\seealso{pop2list, push_array}
%!%-
define push_list(lst)
{
   foreach (lst)
     ();
}

%!%+
%\function{pop2list}
%\synopsis{Return list with N topmost stack-items}
%\usage{List_Type lst = pop2list(N=_stkdepth)}
%\description
% Return a list that consists of the N topmost stack elements. The default
% is to return all elements currently on the stack.
% The top element becomes lst[N-1].
%\example
% Together with \sfun{push_list}, this is a convenient way to manipulate or
% pass on an argument list. Compared to \sfun{__pop_args}/\sfun{__push_args}, 
% it has the advantage that the args are easily accessible via the normal
% index syntax and list functions:
%#v+
%  define silly() % ([args])
%  {
%     variable args = pop2list(_NARGS);
%     list_append(args, "42", -1);
%     args[1] = 3;
%     show(push_list(args));
%  }      
%#v-
%\notes
% Attention: dont use \sfun{pop2list} in a function call with optional
% arguments.
%\seealso{push_list, pop2array, _stkdepth}
%!%-
define pop2list() % (N=_stkdepth)
{
   variable N = push_defaults(_stkdepth, _NARGS);
   
   variable object, list = {};
   loop (N)
     {
        object = ();
        list_insert(list, object, 0);
     }
   return list;
}

%!%+
%\function{list2array}
%\synopsis{Convert a list to an array}
%\usage{Array_Type list2array(list, [DataType_Type type])}
%\description
%  Return an array containing the list elements.
%  
%  The type of the array elements is either given by the optional \var{type}
%  argument (speeds up the conversion) or auto-determined. If the list
%  contains elements of different type, Any_Type is used as container.
%\example
%  \sfun{list2array} enables the use of lists in places that require an
%  array, e.g.:
%#v+
%  message(strjoin(list2array({"hello", "world"}, String_Type), " "));
%  23 + list2array({1, 2, 3}) == [24, 25, 26]
%#v-
%\seealso{array, array2list, push_list, pop2list, pop2array}
%!%-
define list2array(list) % (list, [type])
{
   if (_NARGS < 2)
     return array(push_list(list));
   
   variable type = list;
   list = ();
   push_list(list);
   return pop2array(length(list), type);
}


%!%+
%\function{array2list}
%\synopsis{Convert an array to a list}
%\usage{List_Type array2list(a)}
%\description
%  Return a list of the  elements of \var{a}.
%\example
%#v+
%  array2list([1, 2, 3]) == {1, 2, 3}
%#v-
%\seealso{list2array, push_array, pop2list}
%!%-
define array2list(a)
{
   push_array(a);
   return pop2list();
}

%!%+
%\function{list_concat}
%\synopsis{Concatenate 2 lists}
%\usage{list_concat(l1, l2)}
%\description
%  Concatenate 2 lists by appending the elements of \var{l2} to \var{l1}.
%\notes
%  As this function uses a foreach loop over \var{l2}, it can also be an 
%  Array_Type object.
%\seealso{list_append, list_insert, push_list}
%!%-
define list_concat(l1, l2)
{
   variable element;
   foreach(l2)
     {
	element = ();
	list_append(l1, element, -1);
     }
}

#endif


provide("datutils");

% datutils.sl
% 
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Data manipulations, convenience functions for several Data_Types
%
% Version 1.0  Günter Milde  <g.milde web.de>
%         1.1  new functions pop2array, array, null_fun, array_repeat,
%              array_fill_missing
%         1.2  removed array_concat, array_append, array_insert
%              after learning about [[1,2],3] == [1,2,3]
%              removed array_fill_missing (buggy)
%         1.2.1 reincluded array_append
%               (as [[1,2],[3,4]] -> 2d Array in SLang < 1.16)
%               moved string_repeat and string_reverse to strutils.sl
%         1.2.2 bugfix in array_max(), the definition in sl_utils contrdicted
%               the intrinsic one which resembles array_max() (report PB)
%         1.2.3 removed "public" keyword from all functions

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

% Return n stack-items as an array of type Type (n defaults to _stkdepth).
% If \var{type} is not given, autodetermine it (use Any_Type if
% the element types differ)
% Attention: dont use it in a function call with optional arguments
% , i.e. not show(pop2array()) but
%  $1 = pop2array(), show($1);
define pop2array() % (n=_stkdepth, [type])
{
   variable n, type;
   (n, type) = push_defaults(_stkdepth(), Any_Type, _NARGS);

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

% Return an array containing the arguments
% If you know the datatype of the arguments, you can save resources
% pushing the arguments first and using pop2array().
%    (arg1, ...., argN);
%    pop2array(N, datatype)
% instead of (the simpler)
%    array(arg1, ...., argN);
define array() %([args])
{
   return pop2array(_NARGS);
}

%!%+
%\function{array_reverse}
%\synopsis{Swap the element order of an ordinary array}
%\usage{Array array_reverse(a)}
%\description
%   Return an Array whose elements are the reverse of the Array in the
%   argument.
%\seealso{Array_Type}
%!%-
define array_reverse(a)
{
   variable i = length(a) - 1;
   __tmp(a)[[i:0:-1]];
}



% Append a value to an array or concatenate a and b
% This provides a means to use 1d-arrays like lists.
% For arrays with 1000 values, it becomes time-consuming (0.13 s),
% for 2000 values annoying (0.5 s) and for 5000 values prohibitive (3 s)
% (CPU-time on a AMD-Duron 700MHz under Linux)
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

% Delete the element(s) at position(s) n
% (Return a slice of all positions not in n)
% This provides a means to use 1d-arrays like lists.
% For arrays with 1000 values, it becomes time-consuming (0.09 s),
% for 2000 values annoying (0.32 s) and for 5000 values prohibitive (1.83 s)
define array_delete(a, n)
{
   variable i = Int_Type[length(a)];
   i[n] = 1;
   i = where(not(i));
   return a[i];
}

% Return the maximal value of the array elements
define array_max(a)
{
   % max is a slang intrinsic since 1.4.6. together with min and sum
   % (but must be activated manually)
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

% Return the sum of the array elements
define array_sum(a)
{
   variable sum = 0;
   foreach (a)
     sum += ();
   return sum;
}

% Return the product of the array elements
define array_product(a)
{
   variable product = 1;
   foreach (a)
     product *= ();
   return product;
}

% Return the number of occurences of value in array a
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

% Concatenate an array n-1 times to itself (seealso string_repeat)
define array_repeat(a, n)
{
   variable i, len_a = length(a);
   variable aa = _typeof(a)[n*len_a];
   for (i=0; i <= length(aa)-1; i +=len_a)
     aa[[i:i+len_a-1]] = a;
   return aa;
}

% Swap the axes of a 2d array
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
define assoc_value_exists (ass, value)
{
   array_value_exists(assoc_get_values(ass), value);
}

% Return the key of a value of an Associative Array
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

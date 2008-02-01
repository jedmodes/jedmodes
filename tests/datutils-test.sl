% Test the functions in datutils.sl  Test datutils.sl
% 
% Copyright (c) 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1 2006-03-03 

_debug_info = 1;

require("unittest");


% Fixture
% -------

require("datutils");

private variable testbuf = "*bar*";
private variable teststring = "a test line";
private variable intlist = {1,2,3,4}, intarray = [1,2,3,4];
private variable strlist = {"hello", "world"}, strarray = ["hello", "world"];

static define setup()
{
   sw2buf(testbuf);
   insert(teststring);
}

static define teardown()
{
   sw2buf(testbuf);
   set_buffer_modified_flag(0);
   close_buffer(testbuf);
}

% Test functions
% --------------

% define null_fun() {}
static define test_null_fun()
{
   null_fun();
   test_equal(23, null_fun(23));
}


% array_max: library function
% 
%  SYNOPSIS
%   Return the maximal value of an array
% 
%  USAGE
%   result = array_max(Array_Type a)
% 
%  DESCRIPTION
%   The `array_max' function examines the elements of a numeric array and
%   returns the value of the largest element.
% 
%  EXAMPLE
% 
%    array_max([1,2,30,4] == 30
% 
% 
%  NOTES
%  `max' is a slang intrinsic since 1.4.6. (but must be activated manually)
% 
%  SEE ALSO
%   array_sum, array_product, max, min
static define test_array_max()
{
   test_equal(6, array_max([1,2,6,3]));
   test_equal(12, array_max([1.4, 12, 3, 5.7]));
   test_equal(-1, array_max([-12, -3,-1]));
   test_equal(-1, array_max([-1]));
}

% array_sum: library function
% 
%  SYNOPSIS
%   Return the sum of the array elements
% 
%  USAGE
%   result = array_sum(a)
% 
%  DESCRIPTION
%   Sum up the values of a numeric array and return the result.
% 
%  NOTES
%  `sum' is a slang intrinsic since 1.4.6. (but must be activated manually)
% 
%  SEE ALSO
%   array_max, array_product, sum
static define test_array_sum()
{
   test_equal(1+2+3+4+5, array_sum([1:5]));
}

% array_product: library function
% 
%  SYNOPSIS
%   Return the product of the array elements
% 
%  USAGE
%   result = array_product(a)
% 
%  DESCRIPTION
%   Multiply the values of a numeric array and return the result.
% 
%  SEE ALSO
%   array_sum, array_max
static define test_array_product()
{
   test_equal(2*3*4*5, array_product([2:5]));
   test_equal(2, array_product([2]));
}


% list2array: library function
%   Convert a list to an array
%
%  EXAMPLE
%   `list2array' enables the use of lists in places that require an
%   array, e.g.:
% 
%    message(strjoin(list2array({"hello", "world"}, String_Type), " "));
%    23 + list2array({1, 2, 3}) == [24, 25, 26]
static define test_list2array()
{
   % list2array with optional arg
   test_equal(intarray, list2array(intlist, Integer_Type));
   test_equal(strarray, list2array(strlist, String_Type));
   % list2array without otional arg
   test_equal(intarray, list2array(intlist));
   test_equal(strarray, list2array(strlist));
   % examples
   test_equal("hello world", strjoin(list2array({"hello", "world"}), " "));
   test_equal(23 + list2array({1, 2, 3}), [24, 25, 26]);
   
}


% array_append: library function
% 
%  SYNOPSIS
%   Append a value to an array or concatenate `a' and `b'
% 
%  USAGE
%   Array = array_append(a, b)
% 
%  DESCRIPTION
%  `array_append' provides a means to use 1d-arrays like lists. It
%  concatenates `a' and `b'. 
%   
%  The arguments may be of any type and will be converted to Array_Type (if
%  the not already are) before the concatenation.
% 
%  EXAMPLE
%  The following statemants are all TRUE:
% 
%    array_append(1,2)          == [1,2]
%    array_append(1, [2,3,4])   == [1,2,3,4]
%    array_append([1,2], [3,4]) == [1,2,3,4]
%    array_append([1,2,3], 4)   == [1,2,3,4]
% 
% 
%  NOTES
%  For arrays with 1000 values, it becomes time-consuming (0.13 s),
%  for 2000 values annoying (0.5 s) and for 5000 values prohibitive (3 s)
%  (CPU-time on a AMD-Duron 700MHz under Linux)
% 
%  SEE ALSO
%   list_append
static define test_array_append()
{
   test_equal(array_append(1,2)          , [1,2]);
   test_equal(array_append(1, [2,3,4])   , [1,2,3,4]);
   test_equal(array_append([1,2], [3,4]) , [1,2,3,4]);
   test_equal(array_append([1,2,3], 4)   , [1,2,3,4]);
}

% array_value_exists: library function
%   Return the number of occurences of `value' in array `a'
static define test_array_value_exists()
{
   % trivial ones (translate to length(where(a == value)) )
   test_equal(0, array_value_exists([1,2,3], 4));
   test_equal(1, array_value_exists([1,2,3], 2));
   test_equal(3, array_value_exists(["1", "1", "1", "W"], "1"));
   
   % Any_Type arrays:
   variable a = Any_Type[4];
   test_equal(0, array_value_exists(a, 3));
   test_equal(4, array_value_exists(a, NULL));
   a[1] = 3;
   a[2] = "3";
   a[3] = 3;
   test_equal(1, array_value_exists(a, NULL));
   test_equal(2, array_value_exists(a, 3));
   test_equal(1, array_value_exists(a, "3"));
}

% assoc_get_key: library function
%   Return the key of a value of an Associative Array
static define test_assoc_get_key()
{
   variable ass = Assoc_Type[Integer_Type];
   ass["5"] = 5;
   ass["3"] = 3;
   % testmessage("ass %s\n", sprint_variable(ass));
   % testmessage("values %s\n", sprint_variable(assoc_get_values(ass)));
   % testmessage("keys %s\n", sprint_variable(assoc_get_keys(ass)));
   test_equal(NULL, assoc_get_key(ass, 1));
   test_equal("5", assoc_get_key(ass, 5));
}

% Array_Type array([args])
% Return an array containing the arguments

static define test_array__integer()
{
   test_equal(array(0, 1, 2, 3), [0, 1, 2, 3]);
}

static define test_array__string()
{
   test_equal(array("0", "1"), ["0","1"]);
}

static define test_array__empty()
{
   test_equal(array(), Any_Type[0]);
}

static define test_array__mixed()
{
   variable a = Any_Type[3], a1 = array(0, "1", '2');
   a[0] = 0; a[1] = "1"; a[2] = '2';
   test_equal(length(a1), 3);
   test_equal(_typeof(a1), Any_Type);
}


#stop
   
% pop2array: library function
% 
%  SYNOPSIS
%   Return N stack-items as an array of type `type'
% 
%  USAGE
%   Array_Type pop2array(N=_stkdepth, [type])
% 
%  DESCRIPTION
%  Return an array that consists of the N topmost stack elements.
%  The top element becomes element arr[N-1].
%  If `type' is not given, autodetermine it (fall back to `Any_Type'
%  if the element types differ).
% 
%  NOTES
%  Attention: dont use `pop2array' in a function call with optional
%  arguments , i.e. not
% 
%    show(pop2array())
% 
%  but
% 
%    $1 = pop2array(); 
%    show($1);
% 
% 
%  SEE ALSO
%   array, pop2list, push_array
static define test_pop2array()
{
   Arr  pop2array(N=_stkdepth, [type]);
}


% array_delete: library function
% 
%  SYNOPSIS
%   Delete the element(s) at position(s) `N'
% 
%  USAGE
%   Array_Type array_delete(Array_Type a, Integer_Type N)
% 
%  USAGE
%   Array_Type array_delete(Array_Type a, Array_Type N)
% 
%  DESCRIPTION
%  Return a slice of all positions not in `N'.
%  This provides a means to use 1d-arrays like lists.
% 
%  EXAMPLE
% 
%    array_delete([1,2,3,4], 0)      == [2,3,4]
%    array_delete([1,2,3,4], [0,1])  == [3,4]
%    array_delete([1,2,3,4], [0,-1]) == [2,3]
%    array_delete([1,2,3,4], -1)     == [1,2,3]
% 
% 
%  NOTES
%  For arrays with 1000 values, it becomes time-consuming (0.09 s),
%  for 2000 values annoying (0.32 s) and for 5000 values prohibitive (1.83 s).
%  With SLang 2, consider using the new List_Type instead.
% 
%  SEE ALSO
%   array_append, where, list_delete
static define test_array_delete()
{
   Arr  = array_delete(Arr  a, i N);
}

% array_repeat: library function
% 
%  SYNOPSIS
%   Repeat an array `N' times
% 
%  USAGE
%   Array_Type array_repeat(a, N)
% 
%  DESCRIPTION
%  Concatenate an array N-1 times to itself and return the result.
% 
%  SEE ALSO
%   string_repeat, array_append
static define test_array_repeat()
{
   Arr  = array_repeat(a, N);
}

% array_transpose: library function
% 
%  SYNOPSIS
%   Swap the axes of a 2d array
% 
%  USAGE
%   Array_Type array_transpose(a)
% 
%  DESCRIPTION
%   Swap rows and columns of a 2dimensional array.
% 
%  SEE ALSO
%   array_info, reshape
static define test_array_transpose()
{
   Arr  = array_transpose(a);
}

% assoc_value_exists: library function
% 
%  SYNOPSIS
%   Return the number of occurences of `value' in `ass'
% 
%  USAGE
%   Integer_Type assoc_value_exists(Assoc_Type ass, value)
% 
%  DESCRIPTION
%   Count, how many times `value' is present in the associative 
%   array `ass'. 
% 
%  SEE ALSO
%   array_value_exists, assoc_key_exists, assoc_get_key, assoc_get_values
static define test_assoc_value_exists()
{
   i = assoc_value_exists(Ass ass, value);
}

% push_list: library function
% 
%  SYNOPSIS
%   Push the list elements on the stack
% 
%  USAGE
%   push_list(List_Type lst)
% 
%  DESCRIPTION
%   Push all elements of a list to the stack. 
%   Very convenient for converting a list to an argument list.
% 
%  EXAMPLE
% 
%    variable args = {"foo ", "bar ", "uffe "};
%    variable str = strjoin(push_list(args));
% 
% 
%  SEE ALSO
%   pop2list, push_array
static define test_push_list()
{
   push_list(List_Type = lst);
}

% pop2list: library function
% 
%  SYNOPSIS
%   Return list with N topmost stack-items
% 
%  USAGE
%   List_Type lst = pop2list(N=_stkdepth)
% 
%  DESCRIPTION
%  Return a list that consists of the N topmost stack elements. The default
%  is to return all elements currently on the stack.
%  The top element becomes lst[N-1].
% 
%  EXAMPLE
%  Together with `push_list', this is a convenient way to manipulate or
%  pass on an argument list. Compared to `__pop_args'/`__push_args', 
%  it has the advantage that the args are easily accessible via the normal
%  index syntax and list functions:
% 
%    define silly() % ([args])
%    {
%       variable args = pop2list(_NARGS);
%       list_append(args, "42", -1);
%       args[1] = 3;
%       show(push_list(args));
%    }      
% 
% 
%  NOTES
%  Attention: dont use `pop2list' in a function call with optional
%  arguments.
% 
%  SEE ALSO
%   push_list, pop2array, _stkdepth
static define test_pop2list()
{
   List_Type lst = pop2list(N=_stkdepth);
}

% array2list: library function
% 
%  SYNOPSIS
%   Convert an array to a list
% 
%  USAGE
%   List_Type array2list(a)
% 
%  DESCRIPTION
%   Return a list of the  elements of `a'.
% 
%  EXAMPLE
% 
%    array2list([1, 2, 3]) == {1, 2, 3}
% 
% 
%  SEE ALSO
%   list2array, push_array, pop2list
static define test_array2list()
{
   List_Type = array2list(a);
}

% list_concat: library function
% 
%  SYNOPSIS
%   Concatenate 2 lists
% 
%  USAGE
%   list_concat(l1, l2)
% 
%  DESCRIPTION
%   Concatenate 2 lists by appending the elements of `l2' to `l1'.
% 
%  NOTES
%   As this function uses a foreach loop over `l2', it can also be an 
%   Array_Type object.
% 
%  SEE ALSO
%   list_append, list_insert, push_list
static define test_list_concat()
{
   list_concat(l1, = l2);
}

% define list_inject(l1, l2, i)
static define test_list_inject()
{
   list_inject();
}

sw2buf("*test report*");
view_mode();

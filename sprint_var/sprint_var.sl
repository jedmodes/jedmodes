% --- Formatted info about variable values ---
% 
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
% 
% Provides the function sprint_variable() that can handle complex variables 
% such as arrays, associative arrays, and structures.
%
% USAGE
% 
% Place in your jed library path and do things like
% message(sprint_variable([1, 2, 3, 5]));
% 
% NOTES
%
% The latest snapshot of slang 2 has a print.sl library file that does many
% of the things sprint_var.sl does:
% 
% print.sl		sprint_var.sl
% ========		=============
% struct_to_string	sprint_struct
% print_array		sprint_array
% print			sprint_variable
%
%
% VERSIONS
% 1.0             first public version
% 1.1 2005-04-20  print user defined data types as struct 
%     		  (test with is_struct_type that also works for structures of
%     		   types other than Struct_Type)
%     		  added tm documentation


autoload("array_product", "datutils");
autoload("array_repeat", "datutils");

%!%+
%\variable{Sprint_Indent}
%\synopsis{Indendation string used by sprint_variable() for complex variables}
%\usage{String_Type Sprint_Indent = "   "}
%\description
% How much shall a sub-list be indented in a variable listing with
% \var{sprint_variable}?
% 
% Set as literal string of spaces.
%\seealso{sprint_variable}
%!%-
custom_variable("Sprint_Indent", "   ");

% newline + absolute indendation (used/set by sprint_...)
static variable Sprint_NL = "\n";

% dummy definition
define sprint_struct() {}

%!%+
%\function{sprint_variable}
%\synopsis{Print a variable to a string (verbosely)}
%\usage{String_Type sprint_variable(var)}
%\description
% A more verbose variant of \var{string} that recurses into elements
% of compound data types.
%\notes
% The latest snapshot of slang 2 has a print.sl library file that does many
% of the things sprint_var.sl does:
% 
% print.sl		sprint_var.sl
% ========		=============
% struct_to_string	sprint_struct
% print_array		sprint_array
% print			sprint_variable
%\seealso{show, shoe_message, Sprint_Indent, print}
%!%-
public define sprint_variable(var)
{
   variable type, sprint_hook;
   type = extract_element(string(typeof(var)), 0, '_');
   sprint_hook = __get_reference("sprint_"+strlow(type));
   if (sprint_hook != NULL)
     {
        % show_string("printing using sprint_"+strlow(type));
	return @sprint_hook(var);
     }
   
   % Test for user defined types (struct-like)
   if (is_struct_type(var))
     return sprint_struct(var);

   return string(var);
}

% Return a 1d array of indices for multidim-array with dimensions dims
define multidimensional_indices(dims)
{
   variable i, j, N = length(dims);          % dimensionality
   variable L = array_product(dims);
   variable index = Array_Type[L], a = Integer_Type[N,L];
   for (i=0; i<N; i++)
     {
	a[i,*] = array_repeat([0:array_product(dims[[i:]])-1]
				  /array_product(dims[[i+1:]]),
				  L/array_product(dims[[i:]])
				  );
     }
   for (j=0; j<L; j++)
     index[j] = a[*,j];
   return index;
}
  
% print to a string all elements of an array:
% for simple (atomic) values: "[1,2,3]",
% for compound values: "[0] 1,\n[1]2,\n,[2] 3"
define sprint_array(a)
{
   variable strarray, str, sep = ",";

   if (typeof(a) != Array_Type)
     return("sprint_array: " + string(a) + "is no array!");
   if (length(a) == 0)
     return("[]");

   variable dims, dimensionality, indices;
   (dims, dimensionality, ) = array_info(a);
   strarray = array_map(String_Type, &sprint_variable, a);
   % try simple oneliner
   str = "[" + strjoin(strarray, sep) + "]";
   % show(str);   
   % multidimensional, compound elements or too long
   if (orelse {dimensionality > 1} {strlen(str) > WRAP} {is_substr(str, "\n")})
     {
	indices = multidimensional_indices(dims);
	indices = array_map(String_Type, &sprint_variable, indices);
	reshape(strarray, length(strarray));
	strarray =  indices + " " + strarray;
	str = string(a) + Sprint_NL + strjoin(strarray, Sprint_NL);
	(str, ) = strreplace(str, "\n", "\n"+Sprint_Indent, strlen(str));
     }
   return (str);
}

% print to a string all keys and elements of an associative array:
define sprint_assoc(ass)
{
   if (typeof(ass) != Assoc_Type) 
     return(string(ass)+ "is no associative array");
   variable str = string(ass);
   % get and sort keys
   variable keys = assoc_get_keys(ass);
   variable I = array_sort(keys);   % returns the indices in sort order
   keys = keys[I];              % array as index returns array of values
   % get values and append key-value-pairs to str
   Sprint_NL += Sprint_Indent;
   variable key;
   foreach (keys)
     {
	key = ();
	str += sprintf("%s[%s]\t%s",
		       Sprint_NL, string(key), sprint_variable(ass[key]));
     }
   % the default value:
   ERROR_BLOCK {_clear_error; "not defined";} % in case no default is defined
   variable default = sprint_variable(ass["?_*_!"]); % (hopefully) never used key
   str += Sprint_NL + "DEFAULT\t " + default;
   Sprint_NL = Sprint_NL[[:-1-strlen(Sprint_Indent)]];
   return(str);
}

% print to a string all fields of a structure
define sprint_struct(s)
{
   variable field, value;
   variable str = string(s);
   Sprint_NL += Sprint_Indent;
   foreach (get_struct_field_names(s))
     {
	field = ();
	value = get_struct_field(s, field);
	str += Sprint_NL + "." + field + "\t" + sprint_variable(value);
     }
   Sprint_NL = Sprint_NL[[:-1-strlen(Sprint_Indent)]];
   return(str);
}

% Why is there no easy way to  access .line and .column of a Mark?
define mark_info(mark)
{
   variable b, l, c;
   variable currbuf = whatbuf();

   ERROR_BLOCK
     {
	_clear_error;
	pop;
	return("deleted buffer", 0, 0);
     }
   b = user_mark_buffer(mark);
   sw2buf(b);
   push_spot();
   goto_user_mark(mark);
   l = what_line();
   c = what_column();
   pop_spot();
   sw2buf(currbuf);
   return (b, l, c);
}

% print to a string nicely formatted info about a user_mark:
define sprint_mark(m)
{
   if (typeof(m) != Mark_Type) return(string(m) + "is no user mark");
   variable buf, line, column;
   return sprintf("User_Mark: %s(%d,%d)", mark_info(m));
}

% surround with "" to make clear it is a string
define sprint_string(str)
{
   (str, ) = strreplace(str, "\n", "\\n", strlen(str));
   (str, ) = strreplace(str, "\t", "\\t", strlen(str));
   (str, ) = strreplace(str, "\e", "\\e", strlen(str));
   return ("\"" + str + "\"");
}

define sprint_char(ch)
{
   return ("'" + char(ch) + "'");
}

define sprint_any(any)
{
   return("Any_Type: " + sprint_variable(@any));
}
  

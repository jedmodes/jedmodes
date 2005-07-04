% csvutils.sl
% 
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Utilities to work with comma (or tabulator) separated values (csv files)
% We will call such a 2d-array of values a table
%
% Version    1.0 First public version
% 2005-03-31 1.1 made slang-2 proof: A[[0:-2]] --> A[[:-2]]   

% requirements
autoload("push_defaults", "sl_utils");
autoload("array_max", "datutils");
autoload("array_product", "datutils");
autoload("array_transpose", "datutils");
autoload("string_repeat", "strutils");
autoload("get_buffer", "txtutils");

% --- static functions -----------------------------------------------------------

% replace x with value, if x == NULL
static define fill_missing(x, value)
{
   if (x == NULL)
     return value;
   else
     return x;
}

static define align_fields(a, align)
{
   % expand the align argument to the number of columns
   variable dims;
   (dims, , ) = array_info(a);
   if (strlen(align) < dims[1])
     align = string_repeat(align, dims[1])[[:dims[1]-1]];

   % TODO: wrap fields for columns in uppercase ("LMCR")
   % wrap_cols = where (bstring_to_array(str) == bstring_to_array(strlow(str)));

   % trim fields
   variable b = array_map(String_Type, &strtrim, a);
   % Pad the fields to get aligned columns
   variable i, j, pad;  % indizes, required padding
   variable field_width = array_map(Int_Type, &strlen, b);
   variable col_width;  % the width of the table columns

   for (j=0; j < dims[1]; j++)
     {
	col_width = array_max(field_width[*,j]);
	for (i=0; i < dims[0]; i++)
	  {
	     pad = col_width - field_width[i,j];
	     switch (align[j])
	       {case 'l': b[i,j] += string_repeat(" ", pad);}
	       {case 'r': b[i,j] = string_repeat(" ", pad) + b[i,j];}
	       {case 'c': b[i,j] = string_repeat(" ", pad/2) + b[i,j]
		     	  	   + string_repeat(" ", (pad+1)/2);}
	       {case 'm': b[i,j] = string_repeat(" ", (pad+1)/2) + b[i,j]
		     	  	   + string_repeat(" ", pad/2);}
	  }
     }
   return b;
}

% --- public functions ------------------------------------------------

% Return the buffer/region as an string-array of lines
public define get_lines() % (kill=0)
{
   variable kill;
   (kill) = push_defaults(0, _NARGS);

   variable str = get_buffer(kill);
   % remove last "\n" if present
   if (str[-1] == '\n')
     str = str[[:-2]];
   return strchop(str, '\n', 0);
}

% --- convert spaces to single tab
%     (as some programs expect just one tab between values)

%!%+
%\function{buffer_compress}
%\synopsis{Remove excess whitespace characters from the buffer}
%\usage{Void buffer_compress(white)}
%\description
%  Calls strcompress on the buffer (or region, if defined)
%\seealso{strcompress, get_lines, trim_buffer}
%!%-
define buffer_compress(white)
{
   push_spot();
   variable lines = get_lines(1);
   % (strcompress also trimms, therefore do it on lines!)
   lines = array_map(String_Type, &strcompress, lines, white);
   insert(strjoin(lines, "\n"));
   pop_spot();
}

% "normalize" csv-date: change all whitespace (" " and "\t") to single tabs
% (also trims lines)
public define spaces2tab()
{
   buffer_compress("\t ");
}

%!%+
%\function{strchop2d}
%\synopsis{Chop a string into a 2d-array (lines and columns)}
%\usage{Array strchop2d(str, col_sep='\t', line_sep='\n', quote=0)
%       Array strchop2d(String str, String col_sep, line_sep='\n')}
%\description
%  The 2d equivalent to strchop and strtok. Split the string first into
%  lines (or equivalent with line_sep != '\n') and then into fields.
%  Return the result as a 2d-array with missing values set to NULL
%
%  The datatype of col_sep determines which function is used to split
%  the lines:
%    if typeof(col_sep) == String_Type, use strtok, else use strchop
%\example
%#v+
%  strchop2d(bufsubstr, " \t")
%#v-
%  will return the data in the region interpreted as a white-space
%  delimited table.
%\seealso{strchop, strtok, read_table}
%!%-
define strchop2d() % (str, col_sep='\t', line_sep='\n', quote=0)
{
   variable str, col_sep, line_sep, quote;
   (str, col_sep, line_sep, quote) = push_defaults( , '\t', '\n', 0, _NARGS);
   variable i, no_cols, table;
   % -> array of lines
   str = strchop(str, line_sep, quote);
   % show("Lines", str);
   % split lines: -> array of arrays of fields
   if (typeof(col_sep) == String_Type)
     str = array_map(Array_Type, &strtok, str, col_sep);
   else
     str = array_map(Array_Type, &strchop, str, col_sep, quote);
   % show("Table", str);
   no_cols = array_max(array_map(Int_Type, &length, str));
   % show("Number of columns", no_cols);
   % insert into a 2d array
   table = String_Type[length(str), no_cols];
   for (i = 0; i < length(str); i++)
     table[i,[0:length(str[i])-1]] = str[i];
   return(table);
}

%!%+
%\function{get_table}
%\synopsis{Return a 2d-string-array with csv data in the region/buffer}
%\usage{String get_table(col_sep=NULL, kill=0)}
%\description
% Return a 2d-string-array with the data in the region/buffer
% The default col_sep==NULL means whitespace (any number of spaces or tabs).
% The optional argument \var{kill} tells, whether the table should be
% deleted after reading.
%
%\example
%#v+
%   get_table(" ")     columns are separated by single spaces
%   get_table(" | ")   columns are separated by space-sourounded bars
%   get_table(NULL)    columns are separated by whitespace (default)
%#v-
%\seealso{strchop2d, format_table, insert_table}
%!%-
define get_table() % (col_sep=NULL, kill=0)
{
   variable col_sep, kill;
   (col_sep, kill) = push_defaults(NULL, 0, _NARGS);

   variable cs, str;

   str = get_buffer(kill);
   % remove last newline, if present
   if (str[-1] == '\n')
     str = str[[:-2]];

   if (typeof(col_sep) == String_Type)
     {
	if (strlen(col_sep) > 1)
	  {
	     % find a unused character -> use it as delimiter
	     cs = '~';
	     while (is_substr(str, char(cs)))
	       {
		  cs++;
		  if (cs > 255)
		    error ("get_table: did not find unique replacement for multichar col_sep");
	       }
	     str = str_replace_all(str, col_sep, char(cs));
	     col_sep = cs;
	  }
	else
	  col_sep = col_sep[0];  % convert to Char_Type
     }
   if (col_sep == NULL) % white-space delimited columns
     col_sep = "\t ";

   return strchop2d(str, col_sep, '\n', 0);
 }

%!%+
%\function{strjoin2d}
%\synopsis{Print 2d-array as a nicely formatted table to a string}
%\usage{Str strjoin2d(Array a, col_sep="\t", line_sep="\n", align=NULL)}
%\description
%   The function takes an 2d-array and returns a string that represents
%   the data as an csv-table. It can be seen as a 2d-variant of
%   strjoin(Array_Type a, String_Type delim).
%\seealso{strjoin, strchop2d, insert_table, get_table}
%!%-
define strjoin2d() %(a, col_sep="\t", line_sep="\n", align=NULL)
{
   % get arguments
   variable a, col_sep, line_sep, align;
   (a, col_sep, line_sep, align) = push_defaults( , "\t", "\n", , _NARGS);

   variable b; % copy of array a
   % get the array metadata
   variable dims, nr_dims, type;
   (dims, nr_dims, type) = array_info(a);
   % show("dims", dims, "nr_dims", nr_dims, "type", type);

   !if (nr_dims == 2)
     error("first argument to strjoin2d must be a 2d-array");
   !if (length(a)) % empty array
	return "";

   % Convert array elements to strings
   if (type != String_Type)
     b = array_map(String_Type, &string, a);
   else
     % fill missing values (NULL) with ""
     b = array_map(String_Type, &fill_missing, a, "");
   % align columns
   if (align != NULL)
     b = align_fields(b, align);
   % build the lines by joining the fields
   variable i, lines = String_Type[dims[0]];
   for (i=0; i < dims[0]; i++)
     lines[i] = strtrim_end(strjoin(b[i,*], col_sep));
   % join the lines
   return strjoin(lines, line_sep);
}

%!%+
%\function{insert_table}
%\synopsis{Print 2d-array as a nicely formatted table}
%\usage{Void insert_table(Array a, col_sep=" ", align="l")}
%\description
%   The function takes an 2d-array and writes it as an aligned table.
%   The \var{col_sep} argument is a string to separate the items on a line,
%   it defaults to " \t" (whitespace).
%   The \var{align} argument is a string formed of the charaters:
%     "l": left align,
%     "r": right align,
%     "c": center align, or
%     " ": no align (actually every character other than "lrc"),
%   one for each column. If the string is shorter than the number of columns,
%   it will be repeated, i.e. if it contains only one character, the
%   align is the same for all columns)
%\example
%   The call
%#v+
%       insert_table(a, "|", "llr ");
%#v-
%   inserts \var{a} as a table with elements separated by "|" and
%   first and second columns left aligned, third column right aligned
%   and last column not aligned.
%\seealso{get_table, strjoin2d, strjoin}
%!%-
define insert_table() %(a, align="l", col_sep=" ")
{
   variable a, align, col_sep;
   (a, align, col_sep) = push_defaults( , "l", " ", _NARGS);
   insert(strjoin2d(a, col_sep, "\n", align));
   newline();
}


%!%+
%\function{format_table}
%\synopsis{Adjust a table to evenly spaced columns}
%\usage{ format_table(col_sep=NULL, align="l", new_sep=col_sep)}
%\description
%  Read a table into a 2d array, reformat and insert again.
%  \var{col_sep} the string separating columns (defaults to all whitespace)
%  \var{align} a string formed of the charaters:
%     "l": left align,
%     "r": right align,
%     "c": center align, or
%     " ": no align (actually every character other than "lrc"),
%   one for each column. If the string is shorter than the number of columns,
%   it will be repeated, i.e. if it contains only one character, the
%   align is the same for all columns
%  \var{new_col_sep} a string to separate the items on a line,
%\seealso{get_table, insert_table}
%!%-
public define format_table() % (col_sep=" \t", align="l", new_sep=col_sep)
{
   % optional arguments
   variable col_sep, align, new_sep;
   (col_sep, align, new_sep) = push_defaults(NULL, "l", NULL, _NARGS);
   if (new_sep == NULL)
     new_sep = col_sep;
   if (new_sep == NULL)
     new_sep = " ";

   variable a = get_table(col_sep, 1); % delete after reading
   insert_table(a, align, new_sep);
}

% Compute number of columns that fit into \var{width}
% when a list \var{a} is rearranged as aligned 2d array
define compute_columns() % (a, width=SCREEN_WIDTH, col_sep_length=1)
{
   variable a, width, col_sep_length;
   (a, width, col_sep_length) = push_defaults( ,SCREEN_WIDTH, 1, _NARGS);

   variable i, lines, cols = 0;      % index, number of lines/columns
   variable table_width, field_width = array_map(Int_Type, &strlen, a);
   variable pad; % number of elements missing to make the reshape possible
   variable fw;  % reshaped field width
   do
     {
	cols++;
	pad = cols-1 - (length(a)+cols-1) mod cols;
	lines = (length(a)+pad)/cols;
	% show("fields", length(a), "pad", pad, "lines", lines, "cols", cols);
	fw = [field_width, Int_Type[pad]];
	reshape(fw, [cols, lines]);
	% show_string(strjoin2d(fw, " ", "\n", "r"));
	table_width=cols * col_sep_length;
	for (i=0; i < cols; i++)
	  table_width += array_max(fw[i,*]);
	% show("width", width, "table_width", table_width);
     }
   while (table_width < width);
   return cols-1; % as we stopped when it did no longer fit
}

% arrange a 1d-array as a table (2d-array) with cols columns
define list2table() % (a, cols=compute_columns(a))
{
   variable a, cols;
   (a, cols) = push_defaults(, 0, _NARGS);
   !if (cols)
     cols = compute_columns(a);
   variable pad=0, lines=0, pad_strings, table;
   if (length(a))
     {
	pad = cols-1 - (length(a)+cols-1) mod cols;
	lines = (length(a)+pad)/cols;
     }
   % Transform the list to a 2d array with n columns
   pad_strings = String_Type[pad];
   pad_strings[*] = "";
   table = [a, pad_strings];  % pad to make reshapable
   reshape(table, [cols, lines]);
   table = array_transpose(table);
   return table;
}

provide("csvutils");

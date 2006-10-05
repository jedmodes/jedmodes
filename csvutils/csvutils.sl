% csvutils.sl: work with comma (or tabulator) separated values (csv files)
% 
% Copyright (c) 2003 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Utilities to work with comma (or tabulator) separated values (csv files)
% We will call such a 2d-array of values a table
%
% Version    1.0 First public version
% 2005-03-31 1.1 made slang-2 proof: A[[0:-2]] --> A[[:-2]]
% 2005-11-24 1.2 new default "" for col_sep in get_table(), format_table()
% 	         indent to beg-of-region and "wizard" for format_table()
% 	         new function format_table_rect(): format the rectangular
% 	         region as table.
% 2005-11-25 1.2.1 new functions max_column() and goto_max_column()
% 2005-11-28 1.2.2 bugfix in goto_max_column() (report P. Boekholt)
%            1.2.3 code cleanup in get_lines()
% 2006-07-10 1.2.4 doc update, bugfix in format_table_rect(),
%                  do not remove trailing whitespace in strjoin2d if
%                  align==NULL
%                  disabled format_table_rect(), it doesnot work
%            1.2.5 docu update
% 2006-10-05 1.3   replaced spaces2tab with an optional arg to buffer_compress
% 	     	   documentation fixes

% requirements
autoload("push_defaults", "sl_utils");
autoload("array_max", "datutils");
autoload("array_product", "datutils");
autoload("array_transpose", "datutils");
autoload("string_repeat", "strutils");
autoload("get_buffer", "txtutils");

% --- static functions -------------------------------------------------------

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
define get_lines() % (kill=0)
{
   variable kill = push_defaults(0, _NARGS);
   variable str = get_buffer(kill);
   % trim trailing newline(s)
   str = strtrim_end(str, "\n");
   return strchop(str, '\n', 0);
}

% --- convert spaces to single tab

%!%+
%\function{buffer_compress}
%\synopsis{"Normalize" whitespace delimited data}
%\usage{Void buffer_compress(white="\t ")}
%\description
%  Change all in-line whitespace (" " and "\t") to single tabs
%  (also trims lines). This is configurable with the \var{white}
%  argument.
%  
%  Calls \sfun{strcompress} on the buffer lines or (if visible) region.
%\notes
%  As buffer_compress acts on the lines, newline chars are not compressed,
%  even if included in the argument string.
%\seealso{strcompress, trim_buffer, untab_buffer}
%!%-
public define buffer_compress() % (white="\t ")
{
   variable white = push_defaults("\t ", _NARGS);
   % (strcompress also trimms, therefore do it on lines!)
   variable lines = get_lines(1);
   lines = array_map(String_Type, &strcompress, lines, white);
   insert(strjoin(lines, "\n"));
}


% Tables
% ------


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
%\usage{String get_table(col_sep="", kill=0)}
%\description
% Return a 2d-string-array with the data in the region/buffer
% The default col_sep=="" means whitespace (any number of spaces or tabs).
% The optional argument \var{kill} tells, whether the table should be
% deleted after reading.
%
%\example
%#v+
%   get_table(" ");   % columns are separated by single spaces
%   get_table(" | "); % columns are separated by space-sourounded bars
%   get_table("");    % columns are separated by any whitespace (default)
%#v-
%\seealso{strchop2d, format_table, insert_table}
%!%-
define get_table() % (col_sep="", kill=0)
{
   variable col_sep, kill;
   (col_sep, kill) = push_defaults("", 0, _NARGS);

   variable cs, str;

   % get visible region (expanded to full lines) or buffer
   str = get_buffer(kill, 1);  
   % trim trailing newline(s)
   str = strtrim_end(str, "\n");

   if (col_sep == "") 
     col_sep = "\t ";       % white-space delimited columns
   else if (strlen(col_sep) == 1)
     col_sep = col_sep[0];  % convert to Char_Type
   else
     {  % find an unused character -> use it as delimiter
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
     % lines[i] = strtrim_end(strjoin(b[i,*], col_sep));
     lines[i] = strjoin(b[i,*], col_sep);
   % join the lines
   return strjoin(lines, line_sep);
}

%!%+
%\function{insert_table}
%\synopsis{Print 2d-array as a nicely formatted table}
%\usage{Void insert_table(Array a, align="l", col_sep=" ")}
%\description
%   The function takes an 2d-array and writes it as an aligned table.
%   \var{col_sep} is the string separating the items on a line. It defaults 
%   to " " (space).
%   \var{align} is a format string formed of the key charaters:
%     "l": left align,
%     "r": right align,
%     "c": center align, or
%     "n": no align (actually every character other than "lrc"),
%   one for each column. If the string is shorter than the number of columns,
%   it will be repeated, i.e. if it contains only one character, the
%   align is the same for all columns)
%\example
%   The call
%#v+
%       insert_table(a, " | ", "llrn");
%#v-
%   inserts \var{a} as a table with elements separated by " | " and
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
%\usage{format_table((col_sep=NULL, align=NULL, new_sep=NULL)}
%\description
%  Read visible region or buffer as grid data into a 2d array, reformat and
%  insert again.  The indention of the whole table is determined by the point
%  or mark (whichever is more left) if a visible region is defined.

%  If the arguments are not given, they will be asked for in the minibuffer:
%    \var{col_sep}:     the string separating columns (default "" means whitespace)
%    \var{align}:       string of "l", "r", "c", or "n" (see \sfun{insert_table})
%    \var{new_col_sep}: string to separate the columns in the output.
%\seealso{get_table, insert_table}
%!%-
public define format_table() % (col_sep=NULL, align=NULL, new_sep=NULL)
{
   % optional arguments
   variable col_sep, align, new_sep;
   (col_sep, align, new_sep) = push_defaults( ,  , , _NARGS);
   if (col_sep == NULL)
     col_sep = read_mini("Column separator (leave empty for 'whitespace'):", "", "");
   if (align == NULL)
     align = strlow(read_mini("Column alignment (Left Right Center None):", "", "l"));
   if (new_sep == NULL)
     {  % set default
        if (col_sep != "")
          new_sep = col_sep;
        else
          new_sep = " ";
        new_sep = read_mini("Output column separator:", "", new_sep);
     }
   
   % get indention (least indention of region)
   variable indent = 1;
   if (is_visible_mark){
      indent = what_column();
      exchange_point_and_mark();
      if (what_column() < indent)
	indent = what_column();
   }

   variable a = get_table(col_sep, 1); % delete after reading
   
   push_mark();
   insert_table(a, align, new_sep);

   goto_column(indent);
   open_rect();
}

%!%+
%\function{max_column() }
%\synopsis{Return maximal column number of the buffer (or region)}
%\usage{Integer max_column(trim=0)}
%\description
% Returns 1+length of the longest line of the buffer (or, if visible,
% region). If the optional parameter \var{trim} is nonzero, trailing
% whitespace will be removed during the scan.
%\seealso{goto_max_column, what_column}
%!%-
define max_column()
{
   variable trim = push_defaults(0, _NARGS);
   variable max_col = 0, mark_visible = is_visible_mark();
   
   if (mark_visible)
     narrow();
   push_spot_bob();
   do
     {
	eol();
	if (trim)
	  trim();
	if (what_column() > max_col)
	  max_col = what_column();
     }
   while (down_1);
   pop_spot;
   if (mark_visible)
     widen();
   return (max_col);
}


%!%+
%\function{goto_max_column}
%\synopsis{Goto the maximal column of the buffer (or region)}
%\usage{goto_max_column()}
%\description
% Goto the column of the longest line of the buffer (or, if visible, region).
% Insert whitespace if needed. The region stays marked.
% 
% If the optional parameter \var{trim} is nonzero, trailing
% whitespace will be removed during the scan.
%\notes
% This function comes handy, if you want to mark a rectagle but
% the last line is shorter than preceding lines.
%\seealso{max_column, goto_column, copy_rect}
%!%-
public define goto_max_column()
{
   variable trim = push_defaults(0, _NARGS);
   if (is_visible_mark)
     { % duplicate visible mark
	push_spot();
        pop_mark_1();
        loop (2)
          push_visible_mark();
        pop_spot();
     }                        
   goto_column(max_column(trim));
}


% Buggy, not needed anywhere, so commented out
% %!%+
% %\function{format_table_rect}
% %\synopsis{Format the contents of the rectangle as table}
% %\usage{ format_table_rect([[[col_sep], align], new_sep])}
% %\description
% % This functions calls \sfun{format_table} on a rectangle. A rectangle is
% % defined by the diagonal formed by the mark and the current point.
% %\seealso{format_table, kill_rect, insert_rect}
% %!%-
% public define format_table_rect() % ([[[col_sep], align], new_sep])
% {
%    variable args = __pop_args(_NARGS), buf = whatbuf(), 
%    tmpbuf = make_tmp_buffer_name("*format_table_rect*");
%    check_region(0);
%    exchange_point_and_mark();
%    kill_rect();
%    sw2buf(tmpbuf);
%    erase_buffer();  % paranoia
%    insert_rect();
%    
%    format_table(__push_args(args));
%    
%    % bob();
%    % push_visible_mark();
%    % eob();
%    % goto_max_column();
%    mark_buffer();
%    copy_recyt();
%    set_buffer_modified_flag(0);
%    % delbuf(tmpbuf);
% 
%    sw2buf(buf);
%    insert_rect();
% }


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

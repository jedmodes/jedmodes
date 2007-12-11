% csvutils-test.sl:  Test csvutils.sl Test csvutils.sl
% 
% Copyright (c) 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% Versions:
% 0.1 2006-03-03   basic test, check public functions
% 0.2 2006-10-05   use test function discovery

require("unittest");
require("txtutils");
require("datutils");

% uncomment if you do not want to test default activation
test_true(is_defined("buffer_compress"), "public function buffer_compress undefined");
test_true(is_defined("format_table"), "public function format_table undefined");
test_true(is_defined("goto_max_column"), "public function goto_max_column undefined");

testmessage(" only basic test, arguments not tested completely");


% Fixture
% -------

require("csvutils");

private variable testbuf = "*bar*";
private variable teststring = "first line \n  second   line" ;
private variable testtable = strtok(teststring);
reshape(testtable, [2,2]);
private variable linelength = array_map(Int_Type, &strlen, 
                                        strtok(teststring,"\n"));
private variable max_linelength = array_max(linelength);   

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

% define get_lines() % (kill=0)
static define test_get_lines()
{
   variable lines = get_lines();
   test_equal(lines, strtok(teststring, "\n"));
}

% buffer_compress: library function
% 
%  SYNOPSIS
%   Remove excess whitespace characters from the buffer
% 
%  USAGE
%   Void buffer_compress(white="\t ")
% 
%  DESCRIPTION
%   Calls `strcompress' on the buffer or (if visible) region.
% 
%  SEE ALSO
%   trim_buffer, strcompress, get_lines, get_buffer
static define test_buffer_compress()
{
   buffer_compress();
   test_equal(get_buffer(), strjoin2d(testtable),
      "buffer_compress() should replace in-line whithespace with tabs");
   buffer_compress(" \t");
   test_equal(get_buffer(), strjoin2d(testtable, " "),
      "buffer_compress should call strcompress() on the buffer");
}


% strchop2d: undefined
% 
%  SYNOPSIS
%   Chop a string into a 2d-array (lines and columns)
% \usage{Array strchop2d(str, col_sep='\t', line_sep='\n', quote=0)
%        Array strchop2d(String str, String col_sep, line_sep='\n')}
% 
%  DESCRIPTION
%   The 2d equivalent to strchop and strtok. Split the string first into
%   lines (or equivalent with line_sep != '\n') and then into fields.
%   Return the result as a 2d-array with missing values set to NULL
% 
%   The datatype of col_sep determines which function is used to split
%   the lines:
%     if typeof(col_sep) == String_Type, use strtok, else use strchop
% 
%  EXAMPLE
% 
%    strchop2d(bufsubstr, " \t")
% 
%   will return the data in the region interpreted as a white-space
%   delimited table.
% 
%  SEE ALSO
%   strchop, strtok, read_table
static define test_strchop2d()
{
   variable table = strchop2d(teststring, " ");
   test_equal(table, testtable, "strchop2d should return a 2d array");
}

% get_table: undefined
% 
%  SYNOPSIS
%   Return a 2d-string-array with csv data in the region/buffer
% 
%  USAGE
%   String get_table(col_sep="", kill=0)
% 
%  DESCRIPTION
%  Return a 2d-string-array with the data in the region/buffer
%  The default col_sep=="" means whitespace (any number of spaces or tabs).
%  The optional argument `kill' tells, whether the table should be
%  deleted after reading.
% 
% 
%  EXAMPLE
% 
%     get_table(" ");   % columns are separated by single spaces
%     get_table(" | "); % columns are separated by space-sourounded bars
%     get_table("");    % columns are separated by any whitespace (default)
% 
% 
%  SEE ALSO
%   strchop2d, format_table, insert_table
static define test_get_table()
{
   variable table = get_table();
   test_equal(table, testtable, "get_table should return a 2d array");
}

% strjoin2d: library function
% 
%  SYNOPSIS
%   Print 2d-array as a nicely formatted table to a string
% 
%  USAGE
%   Str strjoin2d(Array a, col_sep="\t", line_sep="\n", align=NULL)
% 
%  DESCRIPTION
%    The function takes an 2d-array and returns a string that represents
%    the data as an csv-table. It can be seen as a 2d-variant of
%    strjoin(Array_Type a, String_Type delim).
% 
%  SEE ALSO
%   strjoin, strchop2d, insert_table, get_table
static define test_strjoin2d()
{
   variable str = strjoin2d(testtable);
   test_equal(str, "first\tline\nsecond\tline");
}

% insert_table: undefined
% 
%  SYNOPSIS
%   Print 2d-array as a nicely formatted table
% 
%  USAGE
%   Void insert_table(Array a, align="l", col_sep=" ")
% 
%  DESCRIPTION
%    The function takes an 2d-array and writes it as an aligned table.
%    `col_sep' is the string separating the items on a line. It defaults 
%    to " " (space).
%    `align' is a format string formed of the key charaters:
%      "l": left align,
%      "r": right align,
%      "c": center align, or
%      "n": no align (actually every character other than "lrc"),
%    one for each column. If the string is shorter than the number of columns,
%    it will be repeated, i.e. if it contains only one character, the
%    align is the same for all columns)
% 
%  EXAMPLE
%    The call
% 
%         insert_table(a, " | ", "llrn");
% 
%    inserts `a' as a table with elements separated by " | " and
%    first and second columns left aligned, third column right aligned
%    and last column not aligned.
% 
%  SEE ALSO
%   get_table, strjoin2d, strjoin
static define test_insert_table()
{
   erase_buffer();
   insert_table(testtable);
   test_equal(get_buffer(), "first  line\n"
                           +"second line\n");
}

% format_table: library function
% 
%  SYNOPSIS
%   Adjust a table to evenly spaced columns
% 
%  USAGE
%   format_table(col_sep=NULL, align=NULL, new_sep=NULL)
% 
%  DESCRIPTION
%   Read visible region or buffer as grid data into a 2d array, reformat and
%   insert again.  The indention of the whole table is determined by the point
%   or mark (whichever is more left) if a visible region is defined.
% 
%   If the arguments are not given, they will be asked for in the minibuffer:
%     `col_sep':     the string separating columns (default "" means whitespace)
%     `align':       string of "l", "r", "c", or "n" (see `insert_table')
%     `new_sep':     string to separate the columns in the output.
% 
%  SEE ALSO
%   get_table, insert_table
static define test_format_table()
{
   format_table("", "n", "|");
   test_equal(get_buffer(), "first|line\nsecond|line\n");
}

% define max_column()
static define test_max_column()
{
   test_equal(max_column(), max_linelength+1);
}

% goto_max_column: library function
% 
%  SYNOPSIS
%   Goto the maximal column of the buffer (or region)
% 
%  USAGE
%   goto_max_column()
% 
%  DESCRIPTION
%  Goto the column of the longest line of the buffer (or, if visible, region).
%  Insert whitespace if needed. The region stays marked.
%  
%  If the optional parameter `trim' is nonzero, trailing
%  whitespace will be removed during the scan.
% 
%  NOTES
%  This function comes handy, if you want to mark a rectagle but
%  the last line is shorter than preceding lines.
% 
%  SEE ALSO
%   max_column, goto_column, copy_rect
static define test_goto_max_column()
{
   goto_max_column();
   test_equal(what_column(), max_linelength+1,
      "point should be at the column of the longest line in the buffer");
}

% define compute_columns() % (a, width=SCREEN_WIDTH, col_sep_length=1)
static define test_compute_columns()
{
   test_equal(compute_columns(strtok(teststring), 14, 1), 2,
      "2 columns should fit");
}

% define list2table() % (a, cols=compute_columns(a))
static define test_list2table()
{
   variable table = list2table(strtok(teststring), 2);
   test_equal(table[0,*], testtable[*,0]);
   test_equal(table[1,*], testtable[*,1]);
}

sw2buf("*test report*");
view_mode();

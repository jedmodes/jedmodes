% test-csvutils.sl:  Test csvutils.sl
% 
% Copyright (c) 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1 2006-03-03   basic test, check public functions

require("unittest");

% fixture
sw2buf("*scratch*");
private variable teststring = "first line \n  second   line";
private variable teststring_compressed = strcompress(teststring, " \n");
erase_buffer();
insert(teststring);


% define get_lines() % (kill=0)
% get_lines: library function  Undocumented
test_function("get_lines");
test_equal(typeof(unittest->Last_Result[0]), Array_Type);
test_equal(_typeof(unittest->Last_Result[0]), String_Type);
test_equal(length(unittest->Last_Result[0]), 2);
test_equal(strjoin(unittest->Last_Result[0], "\n"), teststring);

% public define buffer_compress(white)
% buffer_compress(white); Remove excess whitespace characters from the buffer
test_function("buffer_compress", " \n\t");
test_last_result();
test_equal(strjoin(get_lines(), " "), teststring_compressed);

% public define buffer_compress() % with optional arg white="\t ";
% spaces2tab(); "Normalize" whitespace delimited data
test_function("buffer_compress");
test_last_result();
test_equal(strjoin(get_lines(), "\t"), str_replace_all(teststring_compressed, " ", "\t"));

% define strchop2d() % (str, col_sep='\t', line_sep='\n', quote=0)
% ; Chop a string into a 2d-array (lines and columns)
test_function("strchop2d", get_buffer());
test_equal(string(unittest->Last_Result[0]), "String_Type[2,2]");
test_equal(strjoin(unittest->Last_Result[0], " "), teststring_compressed);

% define get_table() % (col_sep="", kill=0)
% Str get_table(col_sep="", kill=0); Return a 2d-string-array with csv data in the region/buffer
erase_buffer();
insert(teststring);
test_function("get_table");
test_equal(strjoin(unittest->Last_Result[0], " "), teststring_compressed);
test_function("get_table", "l");
private variable testtable = unittest->Last_Result[0];

% define strjoin2d() %(a, col_sep="\t", line_sep="\n", align=NULL)
% Str strjoin2d(Arr a, col_sep="\t", line_sep="\n", align=NULL); Print 2d-array as a nicely formatted table to a string
test_function("strjoin2d", testtable, "l");
test_last_result(teststring);

% define insert_table() %(a, align="l", col_sep=" ")
% insert_table(Arr a, col_sep=" ", align="l"); Print 2d-array as a nicely formatted table
erase_buffer();
test_function("insert_table", testtable, "n", " l");
test_last_result();
test_equal(str_replace_all(get_buffer(), "\n", " "), teststring_compressed + " ");


% public define format_table() % (col_sep=" \t", align="l", new_sep=" ")
% format_table(col_sep="", align="l", new_sep=col_sep); Adjust a table to evenly spaced columns
test_function("format_table", "", "l", " | ");
test_last_result();
% test alignment
bob();
test_true(fsearch("|"), "new col_sep not found (format_table)");
$1 = what_column();
test_true(fsearch("|"));
test_equal($1, what_column());  

% define max_column()
% max_column: library function  Undocumented
erase_buffer();
insert(teststring);
test_function("max_column");
test_last_result(16);

% public define goto_max_column()
% goto_max_column(); Goto the maximal column of the buffer (or region)
bob();
test_function("goto_max_column");
test_last_result();
test_equal(what_column(), 16);

% Buggy, not needed anywhere, so commented out
% % public define format_table_rect()
% % format_table_rect([[[col_sep], align], new_sep]); Format the contents of the rectangle as table
% bob();
% skip_word();
% push_visible_mark();
% eob();
% insert(" folly ");
% test_function("format_table_rect", " \t", "r", " | ");
% test_last_result();

% define compute_columns() % (a, width=SCREEN_WIDTH, col_sep_length=1)
% compute_columns: library function  Undocumented
private variable funlist = _apropos("Global", "str", 1);
test_function("compute_columns", funlist, 80, 1);
test_last_result(3);

% define list2table() % (a, cols=compute_columns(a))
% list2table: library function  Undocumented
test_function("list2table", funlist, 3);
test_equal(typeof(unittest->Last_Result[0]), Array_Type);
test_equal(_typeof(unittest->Last_Result[0]), String_Type);
% erase_buffer();
% insert(strjoin2d(unittest->Last_Result[0], " ", "\n", "l"));

erase_buffer();

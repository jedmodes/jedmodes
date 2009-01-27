%  utf8helper-test.sl:  Test utf8helper.sl
% 
% Copyright © 2006 Guenter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 1.1 2007-06-02 

require("unittest");

% test availability of public functions (comment to skip)
test_true(is_defined("latin1_to_utf8"), "public fun latin1_to_utf8 undefined");
test_true(is_defined("utf8_to_latin1"), "public fun utf8_to_latin1 undefined");
test_true(is_defined("strtrans_latin1_to_utf8"), "public fun strtrans_latin1_to_utf8 undefined");
test_true(is_defined("strtrans_utf8_to_latin1"), "public fun strtrans_utf8_to_latin1 undefined");

% Fixture
% -------

require("utf8helper");

% testbufs[_slang_utf8_ok] is in native encoding
private variable teststrings = {},
    base_dir = path_dirname(__FILE__), 
    testbufs = ["ch_table-lat1-decimal.txt", 
		"ch_table-utf8-decimal.txt"];

static define setup()
{
   % do not autoconvert the test buffers:
   UTF8Helper_Read_Autoconvert = 0;
   variable buf;
   foreach buf (testbufs) {
      % load file
      () = find_file(path_concat(base_dir, buf));
      % unset readonly flag (and unset file binding), 
      % so that we can edit without further questions.
      variable file, dir, name, flags;
      (file, dir, name, flags) = getbuf_info();
      setbuf_info("", dir, name, flags & ~0x8);
      
      % extract teststring
      mark_buffer();
      list_append(teststrings, bufsubstr());
   }
}

static define teardown()
{
   variable buf;
   foreach buf (testbufs)
     {
        sw2buf(buf);
        set_buffer_modified_flag(0);
        close_buffer();
     }
}

% Test functions
% --------------

% public define latin1_to_utf8()
static define test_latin1_to_utf8()
{
   % transform buffer;
   sw2buf(testbufs[0]);
   latin1_to_utf8();
   test_equal(get_blocal_var("encoding"), "utf8", 
      "should set blocal var 'encoding'");
   mark_buffer();
   variable str = bufsubstr();
   test_equal(str, teststrings[1]);
   test_unequal(str, teststrings[0]);
}

% public define utf8_to_latin1 ()
static define test_utf8_to_latin1()
{
   sw2buf(testbufs[1]);
   utf8_to_latin1();
   test_equal(get_blocal_var("encoding"), "latin1",
      "should set blocal var 'encoding'");
   mark_buffer();
   variable str = bufsubstr();
   test_unequal(str, teststrings[1]);
   test_equal(str, teststrings[0]);
}

static define test_utf8_to_latin1_reset_CASE_SEARCH()
{
   variable old_case_search = CASE_SEARCH;
   CASE_SEARCH = 0;

   sw2buf(testbufs[1]);
   set_readonly(1);
   try {
      utf8_to_latin1();
   }
   catch RunTimeError:
     { }
   test_equal(CASE_SEARCH, 0, "should reset CASE_SEARCH");
   CASE_SEARCH = old_case_search;
}

% public define strtrans_latin1_to_utf8(str)
static define test_strtrans_latin1_to_utf8()
{
   test_unequal(strtrans_latin1_to_utf8(teststrings[0]), teststrings[0]);
   test_equal(strtrans_latin1_to_utf8(teststrings[0]), teststrings[1]);
}

static define test_strtrans_latin1_to_utf8_empty()
{
   test_equal(strtrans_latin1_to_utf8(""), "");
}

% public define strtrans_utf8_to_latin1(str)
static define test_strtrans_utf8_to_latin1()
{
   test_unequal(strtrans_latin1_to_utf8(teststrings[1]), teststrings[1]);
   test_equal(strtrans_utf8_to_latin1(teststrings[1]), teststrings[0]);
}

static define test_strtrans_utf8_to_latin1_empty()
{
   test_equal(strtrans_utf8_to_latin1(""), "");
}

% scan for non-printable characters in current buffer
% static define has_invalid_chars()
static define test_find_invalid_char()
{
   sw2buf(testbufs[not(_slang_utf8_ok)]); % testbuffer in other encoding
   bob();
   test_true(utf8helper_find_invalid_char());
}

static define test_has_invalid_char_false()
{
   sw2buf(testbufs[_slang_utf8_ok]); % testbuffer in native encoding
   bob();
   test_equal(0, utf8helper_find_invalid_char());
}

#stop 

#if (_slang_utf8_ok)

% define insert_after_char(char)
static define test_insert_after_char()
{
   insert_after_char();
}

% define stroke() { insert_after_char(0x336); }
static define test_stroke()
{
   stroke();
}

% define underline() { insert_after_char(0x332); }
static define test_underline()
{
   underline();
}

% define double_underline() { insert_after_char(0x333); }
static define test_double_underline()
{
   double_underline();
}

% define overline() { insert_after_char(0x305); }
static define test_overline()
{
   overline();
}

% define double_overline() { insert_after_char(0x33f); }
static define test_double_overline()
{
   double_overline();
}
#endif

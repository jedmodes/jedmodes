% utf8helper-test.sl:  Test utf8helper.sl
% 
% Copyright (c) 2006 Guenter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 1.1 2007-06-02 
% 1.2 2008-01-20

require("unittest");

% Fixture
% -------

require("utf8helper");

% Save default values
private variable read_autoconvert = UTF8Helper_Read_Autoconvert;
private variable write_autoconvert = UTF8Helper_Write_Autoconvert;
% now set to YES
% UTF8Helper_Read_Autoconvert = 1;
% UTF8Helper_Write_Autoconvert = 1;

% Set the _jed_*_hooks
% """"""""""""""""""""
% make sure the hooks are appended but do not re-append if 
% already done in utf8helper.sl

!if (read_autoconvert)
   append_to_hook("_jed_find_file_after_hooks", 
		  "utf8helper->utf8helper_read_hook");

!if (write_autoconvert) {
   append_to_hook("_jed_save_buffer_before_hooks", 
		  "utf8helper->utf8helper_write_hook");
   append_to_hook("_jed_save_buffer_after_hooks", 
		  "utf8helper->utf8helper_restore_hook");
}


% Test buffers and strings
% """"""""""""""""""""""""

% encoding[_slang_utf8_ok] is in native encoding
private variable encoding = ["latin1", "utf8"];

% testbufs[_slang_utf8_ok] is in native encoding
private variable base_dir = path_dirname(__FILE__);
private variable teststrings,
   testbufs = array_map(String_Type, &path_concat,
			base_dir, ["ch_table-lat1-decimal.txt", 
				   "ch_table-utf8-decimal.txt"]);

% set up test-strings and Autoconvert custom-vars
static define setup()
{
   teststrings = array_map(String_Type, &strread_file, testbufs);
}

% close test buffers and re-set Autoconvert variables
static define teardown()
{
   variable buf;
   foreach buf (testbufs) {
      () = find_file(buf);
      set_buffer_modified_flag(0);
      close_buffer();
   }
   UTF8Helper_Read_Autoconvert = read_autoconvert;
   UTF8Helper_Write_Autoconvert = write_autoconvert;
}

% Test functions
% --------------

static define test_read_autoconvert_0()
{
   % do not autoconvert the test buffer:
   UTF8Helper_Read_Autoconvert = 0;

   % testbufs[_slang_utf8_ok] is in native encoding
   % load file in "wrong" encoding
   () = find_file(testbufs[not(_slang_utf8_ok)]);
   % look for encoding:
   test_equal(get_blocal("encoding"), NULL, "do not autoconvert file");
   
   % manually call autoconvert to native encoding
   utf8helper->autoconvert(1); % (to_native == 1)
   % test registered encoding:
   test_equal(get_blocal("encoding"), encoding[_slang_utf8_ok],
	      "should convert to native encoding");
   % and content
   mark_buffer();
   test_equal(bufsubstr(), teststrings[_slang_utf8_ok],
      "content should be in native encoding" + encoding[_slang_utf8_ok]);
   % re-convert to original encoding
   utf8helper->autoconvert(0); 
   % look for encoding:
   test_equal(get_blocal("encoding"), encoding[not(_slang_utf8_ok)],
	      "should re-convert to original encoding");
   % look for content:
   mark_buffer();
   test_equal(bufsubstr(), teststrings[not(_slang_utf8_ok)],
      "should re-convert to " + encoding[not(_slang_utf8_ok)]);
}


static define test_read_autoconvert_1()
{
   % do autoconvert the test buffers:
   UTF8Helper_Read_Autoconvert = 1;
   % load file in "wrong" encoding (should autoconvert)
   () = find_file(testbufs[not(_slang_utf8_ok)]);
   % test registered encoding:
   test_equal(get_blocal("encoding"), encoding[_slang_utf8_ok],
	      "should convert to native " + encoding[_slang_utf8_ok]);
   mark_buffer();
   test_equal(bufsubstr(), teststrings[_slang_utf8_ok],
	      "should convert content to native encoding");
}

static define test_read_autoconvert_nothing_to_do()
{
   % do autoconvert the test buffers:
   UTF8Helper_Read_Autoconvert = 1;
   % load file in "native" encoding (no autoconvert)
   () = find_file(testbufs[_slang_utf8_ok]);
   % test registered encoding:
   test_equal(get_blocal("encoding"), NULL,
	      "should already be in native " + encoding[_slang_utf8_ok]);
   mark_buffer();
   test_equal(bufsubstr(), teststrings[_slang_utf8_ok],
	      "should convert content to native encoding");
}

static define test_read_autoconvert_interactive()
{
   % do not autoconvert the test buffers:
   UTF8Helper_Read_Autoconvert = -1;

   % testbufs[_slang_utf8_ok] is in native encoding
   % load file in "wrong" encoding
   () = find_file(testbufs[not(_slang_utf8_ok)]);
   update_sans_update_hook(1);
   flush("Press any key to continue");
   () = getkey();
   testmessage("\n    buffer encoding is '%S'", get_blocal("encoding"));
}

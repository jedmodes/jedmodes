%  utf8helper-test.sl:  Test utf8helper.sl
% 
% Copyright (c) 2006 Guenter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 1.1 2007-06-02 

require("unittest");

% Fixture
% -------

% Do not load here, as the hooks are only added !if (_featurep("utf8helper"))
% require("utf8helper");
custom_variable("UTF8Helper_Read_Autoconvert", 0);
custom_variable("UTF8Helper_Write_Autoconvert", 0);

% testbufs[_slang_utf8_ok] is in active encoding
private variable   teststrings,
  testbufs = ["ch_table-lat1-decimal.txt", 
              "ch_table-utf8-decimal.txt"],
  base_dir = path_dirname(__FILE__),
  read_autoconvert = UTF8Helper_Read_Autoconvert,
  write_autoconvert = UTF8Helper_Write_Autoconvert;

% set the _jed_*_hooks
UTF8Helper_Read_Autoconvert = 1;
UTF8Helper_Write_Autoconvert = 1;

% now evaluate:
() = evalfile("utf8helper");

static define setup()
{
   teststrings = array_map(String_Type, 
      &strread_file, base_dir + "/" + testbufs);
}

static define teardown()
{
   variable buf;
   foreach buf (testbufs)
     {
        !if (bufferp(buf))
          continue;
        sw2buf(buf);
        set_buffer_modified_flag(0);
        close_buffer();
     }
   UTF8Helper_Read_Autoconvert = read_autoconvert;
   UTF8Helper_Write_Autoconvert = write_autoconvert;
}

% Test functions
% --------------


static define test_read_autoconvert()
{
   % do autoconvert the test buffers:
   UTF8Helper_Read_Autoconvert = 1;

   % load file in "wrong" encoding
   () = find_file(base_dir + "/" + testbufs[not(_slang_utf8_ok)]);
   % should autoconvert:
   if (_slang_utf8_ok)
     test_equal(get_blocal("encoding"), "utf8");
   else
     test_equal(get_blocal("encoding"), "latin1");
   mark_buffer();
   % testbufs[_slang_utf8_ok] is in active encoding
   test_equal(bufsubstr(), teststrings[_slang_utf8_ok],
      "should autoconvert to native encoding");
}

static define test_read_autoconvert_false()
{
   % do not autoconvert the test buffers:
   UTF8Helper_Read_Autoconvert = 0;

   % testbufs[_slang_utf8_ok] is in active encoding
   % load file in "wrong" encoding
   () = find_file(base_dir + "/" + testbufs[not(_slang_utf8_ok)]);
   mark_buffer();
   test_equal(bufsubstr(), teststrings[not(_slang_utf8_ok)],
      "should not autoconvert to native encoding");
}

static define test_read_autoconvert_interactive()
{
   % do not autoconvert the test buffers:
   UTF8Helper_Read_Autoconvert = -1;

   % testbufs[_slang_utf8_ok] is in active encoding
   % load file in "wrong" encoding
   () = find_file(base_dir + "/" + testbufs[not(_slang_utf8_ok)]);
   update_sans_update_hook(1);
   flush("Press any key to continue");
   () = getkey();
   testmessage("\n    buffer encoding is '%S'", get_blocal("encoding"));
   
   
}

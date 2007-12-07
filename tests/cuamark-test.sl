% test-cuamark.sl:  Test cuamark.sl
% 
% Copyright (c) 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1 2006-03-03 
% 0.2 2007-12-07  transformed from procedural script to test-functions

require("unittest");


% Fixture
% -------

require("cuamark");

private variable testbuf = "*bar*";
private variable teststring = "a test line";

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

% cua_mark: library function
% 
%  SYNOPSIS
%   Mark a cua-region (usually, with Shift-Arrow keys)
% 
%  USAGE
%   cua_mark()
% 
%  DESCRIPTION
%    if no visible region is defined, set visible mark and key-hooks
%    so that Cua_Unmarking_Functions unmark the region and
%    Cua_Deleting_Functions delete it.
% 
%  SEE ALSO
%   cua_kill_region, cua_copy_region, Cua_Unmarking_Functions, Cua_Deleting_Functions
static define test_cua_mark()
{
   bob();
   cua_mark();
   eol();  % this should not cancel the mark (see Cua_Unmarking_Functions)
   test_true(is_visible_mark(), "there should be a visible mark");
   test_equal(bufsubstr(), teststring);
}

% TODO: This test doesnot work, as the unmarking is done in a keypress hook
%       (we would need to simulate a keypress, how?)
% bob();
% test_function("cua_mark");
% test_last_result();
% call("eol_cmd");  % this should cancel the mark (see Cua_Unmarking_Functions)
% test_true(not is_visible_mark(), "cua_mark(): there should be no visible mark "+
%                                  "after (no-shifted) movement");


% cua_insert_clipboard: library function
% 
%  SYNOPSIS
%   Insert X selection at point
% 
%  USAGE
%   Void cua_insert_clipboard()
% 
%  DESCRIPTION
%  Insert the content of the X selection at point.
%  Use, if you want to have a keybinding for the "middle click" action.
% 
%  NOTES
%  This function doesnot return the number of characters inserted so it can
%  be bound to a key easily.
% 
%  SEE ALSO
%   x_insert_selection, x_insert_cutbuffer
static define test_cua_insert_clipboard()
{
   % TODO: how to trigger an X event?
   testmessage("currently, the insertion happens at 'random' times. \n"
	       +"Sometimes only after the test-buf is closed again \n"
	       +"triggering errors for this test as well as the next!");
   return;
   % kill the buffer content and place in the selection
   mark_buffer();
   cua_kill_region();
   % Test that this is true
   test_true(bobp() and eobp(), 
	     "cua_kill_region error prevents test of cua_insert_clipboard");
   
   % Re-insert selection
   cua_insert_clipboard();
   
   % the buffer content should be restored
   if (is_defined("x_insert_selection") or is_defined("x_insert_cutbuffer"))
     {
	mark_buffer();
	test_equal(bufsubstr(), teststring,
		   "inserting the selection should restore content");
     }
}


% cua_kill_region: library function
% 
%  SYNOPSIS
%   Kill region (and copy to yp-yankbuffer [and X selection])
% 
%  USAGE
%   Void cua_kill_region()
% 
%  DESCRIPTION
%    Kill region. A copy is placed in the yp-yankbuffer.
% 
%    If `x_copy_region_to_selection' or `x_copy_region_to_cutbuffer'
%    exist, a copy is pushed to the X selection as well.
% 
%  SEE ALSO
%   yp_kill_region, cua_copy_region, yp_yank
static define test_cua_kill_region()
{
   mark_buffer();
   cua_kill_region();
   % the buffer should now be empty
   test_true(bobp() and eobp(), "After killing the buffer, it should be empty");
   % inserting the yp-yankbuffer should restore the content
   yp_yank();
   mark_buffer();
   test_equal(bufsubstr(), teststring, 
	      "yp_yank() shoule re-insert the killed region");
}


% cua_copy_region: library function
% 
%  SYNOPSIS
%   Copy region to yp-yankbuffer [and X selection])
% 
%  USAGE
%   Void cua_copy_region()
% 
%  DESCRIPTION
%    Copy the region to the yp-yankbuffer.
% 
%    If `x_copy_region_to_selection' or `x_copy_region_to_cutbuffer'
%    exist, a copy is pushed to the X selection as well.
% 
%  SEE ALSO
%   yp_copy_region_as_kill, cua_kill_region, yp_yank
static define test_cua_copy_region()
{
   mark_buffer();
   cua_copy_region();
   % the buffer content should be untouched
   mark_buffer();
   test_equal(bufsubstr(), teststring);
   % the yp_yankbuffer should have a copy
   erase_buffer();
   yp_yank();
   mark_buffer();
   test_equal(bufsubstr(), teststring);
}
   
sw2buf("*test report*");
view_mode();

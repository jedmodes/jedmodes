% cuamouse-test.sl:  Test cuamouse.sl
%
% Copyright (c) 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1 2006-03-03
% 02  2007-12-11 Define test-functions instead of procedural script

require("unittest");

#ifndef XWINDOWS
testmessage("\n  I: cuamouse only works with xjed, skipping");
#stop
#endif

% test availability of public functions (comment to skip)
test_true(is_defined("copy_region_to_clipboard"), "public fun copy_region_to_clipboard undefined");

% Fixture
% -------

require("cuamouse");

private variable testbuf = "*bar*";
private variable teststring = "a test line\n";

static define setup()
{
   sw2buf(testbuf);
   % create a region from (2,2) to (4,6)
   loop(3) {
      insert("\n");
      insert(teststring);
   }
   goto_line(2);
   goto_column(2);
   push_visible_mark();
   goto_line(4);
   goto_column(7);
}

static define teardown()
{
   sw2buf(testbuf);
   set_buffer_modified_flag(0);
   close_buffer(testbuf);
}

% Test functions
% --------------

% click_in_region: library function
%
%  SYNOPSIS
%   determine whether the mouse_click is in a region
%
%  USAGE
%   Int click_in_region(line, col)
%
%  DESCRIPTION
%    Given the mouse click coordinates (line, col), the function
%    returns an Integer denoting:
%           -1 - click "before" region
%           -2 - click "after" region
%            0 - no region defined
%            1 - click in region
%            2 - click in region but "void space" (i.e. past eol)
%
%  SEE ALSO
%   cuamouse_left_down_hook, cuamouse_right_down_hook
static define test_click_in_region()
{
   test_equal(click_in_region(2, 2), 1, "click in the region should return 1");
   test_equal(click_in_region(2, 9), 1, "click in the region should return 1");
   test_equal(click_in_region(3, 1), 1, "click in the region should return 1");
   test_equal(click_in_region(4, 6), 1, "click in the region should return 1");
}

% "before" region
static define test_click_in_region_before()
{
   test_equal(click_in_region(1, 3), -1, "click before region should return -1");
   test_equal(click_in_region(2, 1), -1, "click before region should return -1");
}

% "after" region
static define test_click_in_region_after()
{
   test_equal(click_in_region(4, 7), -2, "click after region should return -2");
   test_equal(click_in_region(4, 12), -2, "click after region should return -2");
   test_equal(click_in_region(5, 1), -2, "click after region should return -2");
}
% in region but after eol
static define test_click_in_region_after_eol()
{
   test_equal(click_in_region(2, 13), 2, "click after eol should return 2");
   test_equal(click_in_region(3, 2), 2, "click after eol should return 2");
}

% no region
static define test_click_in_region_no_region()
{
   pop_mark(0);
   test_equal(click_in_region(1, 1), 0, "no region should return 0");
   test_equal(click_in_region(2, 5), 0, "no region should return 0");
}

% copy_region_to_clipboard: library function
%
%  SYNOPSIS
%   Copy region to x-selection/cutbuffer and internal mouse clipboard
%
%  USAGE
%    copy_region_to_clipboard()
%
%  DESCRIPTION
%    Copy region to selection/cutbuffer and internal mouse clipboard.
%
%    The region stays marked.
%
%  NOTES
%    Tries x_copy_region_to_selection() and x_copy_region_to_cutbuffer()
%    (in this order).
%
%    With CuaMouse_Use_Xclip = 1, the region is piped to the `xclip` command
%    line tool instead. This is a workaround for interaction with applications
%    using the QT toolkit that refuse to paste the selected text otherwise.
%
%  SEE ALSO
%   CuaMouse_Use_Xclip, copy_region, yp_copy_region_as_kill
static define test_copy_region_to_clipboard()
{
   copy_region_to_clipboard();
}

% define cuamouse_insert(from_jed)
static define test_cuamouse_insert()
{
   dupmark();
   variable str = bufsubstr();
   copy_region_to_clipboard();
   push_mark();
   cuamouse_insert(1);
   test_equal(bufsubstr(), str, "should insert the copied text");
}

% define cuamouse_2click_hook(line, col, but, shift) %mark word
static define test_cuamouse_2click_hook()
{
   pop_mark(0);
   cuamouse_2click_hook(1,1,1,0);
   test_true(is_visible_mark(), "double click should mark the word");
}

% internal use, test later
#stop

% define cuamouse_drag(line, col)
static define test_cuamouse_drag()
{
   cuamouse_drag();
}

% define cuamouse_left_down_hook(line, col, shift)
static define test_cuamouse_left_down_hook()
{
   cuamouse_left_down_hook();
}

% define cuamouse_middle_down_hook(line, col, shift)
static define test_cuamouse_middle_down_hook()
{
   cuamouse_middle_down_hook();
}

% define cuamouse_right_down_hook(line, col, shift)
static define test_cuamouse_right_down_hook()
{
   cuamouse_right_down_hook();
}

% define cuamouse_down_hook(line, col, but, shift)
static define test_cuamouse_down_hook()
{
   cuamouse_down_hook();
}

% define cuamouse_drag_hook(line, col, but, shift)
static define test_cuamouse_drag_hook()
{
   cuamouse_drag_hook();
}

% define cuamouse_up_hook(line, col, but, shift)
static define test_cuamouse_up_hook()
{
   cuamouse_up_hook();
}

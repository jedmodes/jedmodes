% ncal.sl
% 
% This provides an ncal layout for the JED calendar, similar to the
% layout of ncal and gcal -i. It should look like this:
% 
% Apr 2004              May 2004              Jun 2004          
%    5 12 19 26            3 10 17 24 31         7 14 21 28      Monday
%    6 13 20 27            4 11 18 25         1  8 15 22 29      Tuesday
%    7 14 21 28            5 12 19 26         2  9 16 23 30      Wednesday
% 1  8 15 22 29            6 13 20 27         3 10 17 24         Thursday
% 2  9 16 23 30            7 14 21 28         4 11 18 25         Friday
% 3 10 17 24            1  8 15 22 29         5 12 19 26         Saturday
% 4 11 18 25            2  9 16 23 30         6 13 20 27         Sunday
% 
% 14 15 16 17 18        18 19 20 21 22 23     23 24 25 26 27     week
% 
% Weeks start on Monday, it's an ISO thing.  To use this
% instead of the standard calendar, add
% 
% autoload("calendar", "ncal");
% 
% to .jedrc
require("cal");
require("calmisc");
use_namespace("calendar");
% ISO calendar always starts on Monday
CalStartWeek = 1;
CalWeekdays = weekdaynames[ (CalStartWeek + [0:6]) mod 7 ];
cal_nlines = 10;

define generate_calendar (month, year)
{
   today_visible = 0;
   set_readonly(0); erase_buffer();
   (displayed_month, displayed_year) = (month, year);

   % output a month to the stack
   variable first, max,
     white = "                                         ";
   variable day_array = strchop("   ,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,   ",
	     ',', 0),
   white_array = strchop("   ,   ,   ,   ,   ,   ,   ,   ,   ,   ,   ,   ,   ,   ,   ",
			 ',', 0);
   variable month_name, month_len, month_line;
   
   USER_BLOCK0
     {   
	if (month == this_month and year == this_year)
	  today_visible = 1;

	month_name = extract_element(CalMonths, month - 1, ',');
	month_len = strlen(month_name) + 5;
	first = (18 - month_len) / 2; 
	month_line = sprintf("%s%s%5d%s",white[[1:first]],  month_name, year, white[[1:18 - first - month_len]]);
	
	% get days in month
	first = cal_day_of_week(month, 1, year);
	max = last_day_of_month(month, year);
	
	% now make the line of ISO week numbers
	variable i, number, weekline;
	"";
	_for (0, 5, 1)
	  {
	     i = ();
	     if (1 + i * 7 <= max + first)
	       {
		  (,number,) = cal_iso_date(month, 1+i*7, year);
		  sprintf("%3d", number);
	       }
	     else
	       "   ";
	  }
	weekline = create_delimited_string(6);
	
	variable c = [white_array[[1:first]], day_array[[1:max]], white_array[[1:42 - max - first]]];
	[month_line,
	 c[[0:6]] + c[[7:13]] + c[[14:20]] + c[[21:27]] + c[[28:34]] + c[[35:41]],
	 "                  ", weekline];
     }
   
   
   % output three months
   
   % each month is an array of 10 lines of 18 characters.

   --month; if (month == 0) { month = 12; --year; }
   X_USER_BLOCK0;
   "    ";
   ++month; if (month == 13) { month = 1; ++year; }
   X_USER_BLOCK0;
   "    ";
   ++month;  if (month == 13) { month = 1; ++year; }
   X_USER_BLOCK0;

   insert(strjoin("   " + ["  ", CalWeekdays, "  ", "week"] + () + () + () + () + (), "\n"));

   bob;
   recenter(1);
   if (today_visible)
     {
	cal_cursor_to_visible_date (this_month, this_day, this_year);
	if(this_day < 10)
	  {
	     del();
	     insert ("*");
	  }
	else
	  {
	     go_left_1;
	     deln(2);
	     insert("**");
	  }
	runhooks ("calendar_today_visible_hook");
     }
   else
     runhooks ("calendar_today_invisible_hook");
   set_readonly(1); set_buffer_modified_flag(0);

}

define cal_cursor_to_visible_date (month, day, year)
{
   goto_line (2 + cal_day_of_week (month, day, year));
   goto_column (3 * (1 + (day + cal_day_of_week (month, 1, year) - 1) / 7)
		+ 22 * (1 + 12 * (year - displayed_year) + month - displayed_month));
}

definekey( "calendar->forward_day( -7)", Key_Left , "Calendar_Map");
definekey( "calendar->forward_day(  7)", Key_Right, "Calendar_Map");
definekey( "calendar->forward_day( -1)", Key_Up   , "Calendar_Map");
definekey( "calendar->forward_day(  1)", Key_Down , "Calendar_Map");

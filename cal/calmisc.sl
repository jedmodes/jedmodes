% calmisc.sl
% 
% $Id: calmisc.sl,v 1.1.1.1 2004/10/28 08:16:18 milde Exp $
% 
% Copyright (c) 2003 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This file provides some autoloaded functions for the calendar
% that are not always needed.

require("cal");
use_namespace("calendar");
% Compute the `ISO commercial date' for point. The ISO year corresponds
% approximately to the Gregorian year, but weeks start on Monday and end
% on Sunday.  The first week of the ISO year is the first such week in
% which at least 4 days are in a year. The idea is to compute the number
% of days before this week began, the number of complete weeks elapsed
% this year before this week, add 1 to that, and if there were more than 3
% days before that, add one more. If the day in the year is smaller than 7
% and the week has less than 4 days in this year, this day in the year,
% plus 3, will be smaller than the day of the week, etc.
static define cal_iso_date(month, day, year)
{
   variable iso_wday, days_before_this_week, weeks;
   % subtract 1 because iso weeks start on day 1;
   % -1 mod 7 = -1 so add 7 to stay positive;
   % add 1 to start counting from 1
   iso_wday = 1 + (cal_day_of_week(month, day, year) + CalStartWeek + 6) mod 7;
   days_before_this_week = cal_day_number(month, day, year) - iso_wday;

   % maybe this week goes with last year
   if (cal_day_number(month, day, year) - iso_wday < -3)
     {
	year--;
	days_before_this_week += 365 + cal_leap_year_p(year);
     }
   
   weeks = 1			       %  add one for the first week of the year
     + days_before_this_week / 7       %  add completed week
     + ((days_before_this_week mod 7) > 3);   %  add one for first 
   					      %  week if more than 3 days
   
   % maybe this should go with the next year
   if (cal_day_number(month, day, year) 
       > iso_wday + 361 + cal_leap_year_p(year))
     {
	year++;
	weeks = 1;
     }
   return iso_wday, weeks, year;
}

public define cal_print_iso_date ()
{
   vmessage("ISO date: day %d of week %d of %d",
	    cal_iso_date(cursor_day));
}


% go to an iso date. The idea is to go to year + weeks + 7 * days,
% and go to the nearest matching weekday from there.
public define cal_goto_iso_date()
{
   variable iweek, iday, iyear,
     absdate, daydiff;
   iyear = integer(read_mini("year", "", string(this_year)));
   iweek = integer(read_mini("week", "1", ""));
   iday = integer(read_mini("day", "1", ""));
   iday--; iweek--; % I count from 0
   absdate = absolute_from_gregorian(1,1,iyear) + 7 * (iweek) + iday;
   daydiff = (cal_day_of_week(gregorian_from_absolute(absdate))
	      + CalStartWeek - 1) mod 7 - iday;
   % this maps [1,2,3,4,5 6] and [-6,-5,-4,-3,-2,-1] to [-1,-2,-3,3,2,1]
   absdate += 7 * (daydiff / 4)  - daydiff;
   goto_absolute_date(absdate);
   % testing ...
   cal_print_iso_date;
}

public define cal_print_day_of_year()
{
   variable day = cal_day_number(cursor_date());
   vmessage ("day %d of %d; %d days remaining in the year",
	     day, cursor_year, 365 - day + cal_leap_year_p(cursor_year));
}

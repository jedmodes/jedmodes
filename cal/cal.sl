% cal.sl    -*- mode: Slang; mode: fold -*-
%
% authors: JED, Eero Tamminen, Paul Boekholt <p.boekholt@hetnet.nl>
% 
% $Id: cal.sl,v 1.1.1.1 2004/10/28 08:16:18 milde Exp $
%
% This is a clone of the Emacs calendar package.  You can move around,
% insert diary entries and view diary entries for the day at point if
% you have the BSD calendar program or something like it.
% You can bind your own keys with the calendar_mode_hook.
%
% The calendar is not correct for dates before November 1582, or before
% October 1752, depending on where you live.  This is because Pope Gregory
% XIII let October 15 1582 follow October 4 1582.  England and the American
% colonies followed in 1752, so the unix "cal" program has 10 days missing
% in September 1752.
% 
% BSD calendar has a bug with weekly reminders and looking ahead.  It just 
% keeps counting days and may give a date like Jan 36.  Maybe I should use
% gcal, ical or remind, or write the diary stuff in S-Lang, let me know what 
% you think.

require("keydefs");

% customization

% each month name may be at max. 15 characters
custom_variable ("CalMonths", ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]);
% each day is two characters, separated with space
custom_variable ("CalDays", " S  M Tu  W Th  F  S");
% sunday=0, monday=1... if you set this, you must also rotate CalDays
custom_variable ("CalStartWeek", 0);
% prompt
custom_variable ("CalPrompt", "Month Year:");
% weekday names for inserting weekly reminders
custom_variable ("weekdays", ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]);

% the file where you keep all your appointments.
% According to Emacs it should be ~/diary, but in my version of calendar
% it's ~/calendar.
custom_variable ("diary_file", dircat(Jed_Home_Directory, "calendar"));
% the number of days to look ahead when viewing appointments.
% By default, if you press "d" on Sunday + CalStartWeek, you should see the 
% appointments for the following week.
custom_variable ("cal_diary_lookahead", [6,0,0,0,0,0,0]);

variable displayed_month, displayed_year; % the displayed month / yr
variable this_month, this_day, this_year; % today's date
variable cursor_month, cursor_day, cursor_year, cursor_absolute_date; % cursor date

%{{{ calendar functions

% nonnegative remainder of M/N with N instead of 0.
% Apparently there are two modulo operators in lisp, -1 % 12 gives -1
% and -1 mod 12 gives 11.  In S-Lang we just have mod.
define cal_mod (m, n)
{
   variable x = m mod n;
   if (x < 1) x += n;
   return x;
}

% interval in months between two months
define cal_interval (mon1, yr1, mon2, yr2)
{
   return 12 * (yr2 - yr1) + mon2 - mon1;
}

% is yearnum a leap year
static define cal_leap_year_p (year)
{
   return ((not(year mod 4) and (year mod 100))
	   or (not (year mod 400)));
}

% The last day in MONTH during YEAR
static define last_day_of_month(month, year)
{
   variable days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
   if (month == 2 and cal_leap_year_p(year)) return 29;
   else return days[month - 1];
}

% calculate day of year for given date
static define cal_day_number(month, day, year)
{
   day += 31 * ( month - 1 );
   if (month > 2)
     {
	day -= (month * 4 + 23) / 10;
	if (cal_leap_year_p (year)) day++;
     }
   return day;
}

% calculate day of week for given date, from Sunday + CalStartWeek
static define cal_day_of_week(month, day, year)
{
   variable c;

   cal_day_number(month, day, year);
   --year;

   c = year/100 * 3;

   return (() + year + year/4 - c/4 - (c mod 4) - CalStartWeek) mod 7;
}

% return current (month, year, day) as integers (from date string)
static define cal_get_date()
{
   variable t, months, month, day, year;

   t = strtok( time ());

   % have to be same as time() returns
   months = "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec";
   month = is_substr(months, t[1]) / 4 + 1; % 5/4 = 1

   day = t[2];

   year = t[4];
   % Some systems display the time as: Tue Jul 06 16:31:18 1993
   % while others use:                 Tue Jul  6 16:31:18 1993

   return month, integer(strtrim_beg(day, "0")), integer(year);
}

% convert month number or localized name string into integer
static define cal_convert_month (month_name)
{
   variable m;
   month_name = strlow(month_name);
   % compare to country specific month names
   for (m = 0; m < 12; ++m)
     {
	!if (strcmp(month_name, strlow(CalMonths[m])))
	  return m + 1;
     }
   % presume it's an integer
   return integer(month_name);
}

% The number of days elapsed between the Gregorian date 12/31/1 BC and DATE.
% The Gregorian date Sunday, December 31, 1 BC is imaginary.
% This won't work with 16 bit integers.
static define absolute_from_gregorian (month, day, year)
{
   cal_day_number(month, day, year);
   --year;
   return ()
     + 365 * year
     + year / 4
     - year / 100
     + year / 400;
}

static define gregorian_from_absolute (day)
{
   variable n400, n100, n4, n1, month, year, mdays;
   day--;
   n400 = day / 146097;
   day  = day mod 146097;
   n100 = day / 36524;
   day  = day mod 36524;
   n4   = day / 1461;
   day  = day mod 1461;
   n1   = day / 365;
   day  = day mod 365 + 1;
   year = 400 * n400 + 100 * n100 + 4 * n4 + n1;
   if (n100 == 4 or n1 == 4) return (12, 31, year);
   year++;
   for (month = 1; mdays = last_day_of_month(month,year), mdays < day; month++)
     day -= mdays;
   return month, day, year;
}

%}}}

%{{{ calendar drawing functions

% output given month to buffer
static define cal_make_month (indent, month, year, day, highlight)
{
   variable month_name, first, max, i, istr;

   % get days in month
   first = cal_day_of_week(month, 1, year);
   max = last_day_of_month(month, year);
   ++indent;
   bob();

   % output month/year line
   month_name = CalMonths[month - 1];
   goto_column(indent + (strlen(CalDays) - strlen(month_name) - 5) / 2);
   insert(month_name); insert_single_space(); insert(string(year));
   !if (down_1 ()) newline();

   % output days line
   goto_column(indent);
   insert(CalDays);
   !if (down_1()) newline ();

   % output day numbers in 7 columns
   goto_column(first * 3 + indent);
   for (i = 1; i <= max; ++i)
     {
	if (first == 7)
	  {
	     !if (down_1())
	       {
		  eol(); newline ();
	       }
	     goto_column(indent);
	     first = 0;
	  }

	% highlight current day
	if ((day == i) and highlight)
	  {
	     if (day < 10)
	       insert (" * ");
	     else
	       insert ("** ");
	  }
	else vinsert ("%2d ", i);
	++first;
     }
}

static define generate_calendar (month, year)
{
   set_readonly(0); erase_buffer();
   (displayed_month, displayed_year) = (month, year);
   % output three months

   --month; if (month == 0) { month = 12; --year; }
   cal_make_month (0, month, year, this_day,
		   ((month == this_month) and (year == this_year)));

   ++month; if (month == 13) { month = 1; ++year; }
   cal_make_month (25, month, year, this_day,
		   ((month == this_month) and (year == this_year)));

   ++month;  if (month == 13) { month = 1; ++year; }
   cal_make_month (50, month, year, this_day,
		   ((month == this_month) and (year == this_year)));
   set_readonly(1); set_buffer_modified_flag(0);

   bob();
   recenter(1);
}

%}}}

%{{{ calendar movement functions

static define cursor_gregorian_from_absolute ()
{
   (cursor_month, cursor_day, cursor_year) = gregorian_from_absolute (cursor_absolute_date);
}

static define cursor_absolute_from_gregorian ()
{
   cursor_absolute_date = absolute_from_gregorian(cursor_month, cursor_day, cursor_year);
}

static define cal_cursor_to_visible_date (month, day, year)
{
   (cursor_month, cursor_day, cursor_year) = (month, day, year);
   goto_line ((day + 20 + cal_day_of_week (month, 1, year)) / 7);
   goto_column (2
		+ 25 *  (1 + cal_interval (displayed_month, displayed_year, month, year))
		+ 3 * (cal_day_of_week(month, day, year)));
}

static define cal_goto_date (month, day, year)
{
   !if (month == displayed_month and year == displayed_year)
     generate_calendar (month, year);
   cal_cursor_to_visible_date (month, day, year);
}

% Move the cursor forward ARG days.
% Moves backward if ARG is negative.
public define cal_forward_day (arg)
{
   variable prefix = prefix_argument(-1);
   if (prefix == -1) prefix = 1;
   cursor_absolute_date += arg * prefix;
   cursor_gregorian_from_absolute;
   cal_goto_date (cursor_month, cursor_day, cursor_year);
}

%}}}

%{{{ diary functions

% view the appointments for the date at point
public define view_diary_entries()
{
   variable lookahead = prefix_argument(-1);
   if (lookahead == -1)
     lookahead = cal_diary_lookahead[cal_day_of_week(cursor_month,cursor_day,cursor_year)];
   setbuf("*Diary*");
   set_readonly(0);
   variable cmd = sprintf("calendar -l%d -t %d.%d.%d", lookahead,cursor_day,cursor_month,cursor_year);
   erase_buffer;
   () = run_shell_cmd(cmd);
   set_buffer_modified_flag(0);
   set_readonly(1);
   if (bobp() and eobp())
     {
	message ("no appointments");
     }
   else
     {
	pop2buf("*Diary*");
	otherwindow();
     }
}

% calendar requires continuation lines to begin with a tab.
public define diary_wrap_hook()
{
   bol();
   !if (looking_at_char('\t')) insert_char ('\t');
   eol();
}

% insert a string in the diary file
static define make_diary_entry (string)
{
   otherwindow();
   () = find_file(diary_file);
   widen_buffer();
   eob();
   !if(bolp()) insert ("\n");
   push_mark();
   narrow();
   insert(string + "	");
   set_buffer_hook("wrap_hook", "diary_wrap_hook");
}

% insert a diary entry for date at point
% It seems my version of calendar does not understand the europen date format
% of day/month/year so there is no option for it.
public define insert_diary_entry ()
{
   make_diary_entry(sprintf("%d/%d/%d", cursor_month, cursor_day, cursor_year));
}

% and for this day of the week
public define insert_weekly_diary_entry ()
{
   make_diary_entry(weekdays
		    [cal_day_of_week(cursor_month, cursor_day, cursor_year)]);
}

% and for this day of every month
public define insert_monthly_diary_entry ()
{
   make_diary_entry("*/" + string(cursor_day));
}

% and for this day of every year
public define insert_yearly_diary_entry ()
{
   make_diary_entry(string(cursor_month) + "/" +  string(cursor_day));
}

%}}}

static define calendar_mode()
{
   run_mode_hooks("calendar_mode_hook");
   set_mode("calendar", 0);
   use_keymap ("Calendar_Map");
}

% read a month and year
static define read_date ()
{
   variable t, default, month, year;
   default = sprintf ("%s %d", CalMonths[this_month-1], this_year);

   t = strtrim (read_mini (CalPrompt, default, Null_String));

   month = cal_convert_month(extract_element(t, 0, ' '));
   year = integer(extract_element(t, 1, ' '));
   if (month < 1 or month > 12 or year < 1)
     error ("not a valid date");
   return month, year;
}

public define cal_other_month ()
{
   variable month, day, year;
   (month, year) = read_date();
   if (month == displayed_month)
     day = cursor_day;
   else if (month == this_month and year == this_year)
     day = this_day;
   else day = 1;
   cal_goto_date (month, day, year);
   cursor_absolute_from_gregorian();
}

% output three month calendar into separate buffer
public define calendar ()
{
   variable month, day, year;

   % ask user for month / year

   (this_month, this_day, this_year) = cal_get_date();
   (month, year) = read_date();
   pop2buf("*calendar*");
   generate_calendar(month, year);

   if (month == this_month and year == this_year)
     day = this_day;
   else
     day = 1;
   cal_cursor_to_visible_date (month, day, year);
   cursor_absolute_from_gregorian();
   % I need 8 lines
   variable nlines = window_info('r');
   if (nlines > 8)
     {
	otherwindow();
	loop (nlines - 8) enlargewin();
	otherwindow();
     }
   else
     {
	loop (8 - nlines) enlargewin();
     }
   %  what the heck, give current time
   message(time);
   calendar_mode ();
}

public define cal_quit()
{
   otherwindow();
   if (bufferp("*Diary*")) delbuf ("*Diary*");
   if (bufferp("*calendar*")) delbuf ("*calendar*");
   onewindow();
}

$2 = "Calendar_Map";
!if (keymap_p($2))
  make_keymap($2);
definekey( "cal_forward_day( -1)", Key_Left , $2);
definekey( "cal_forward_day(  1)", Key_Right, $2);
definekey( "cal_forward_day( -7)", Key_Up   , $2);
definekey( "cal_forward_day(  7)", Key_Down , $2);
definekey( "cal_forward_day(-91)", Key_PgUp , $2);
definekey( "cal_forward_day( 91)", Key_PgDn , $2);
definekey( "cal_quit"       , "q", $2);
definekey( "view_diary_entries()", "d", $2);
definekey( "insert_diary_entry()", "id", $2);
definekey( "insert_weekly_diary_entry()", "iw", $2);
definekey( "insert_monthly_diary_entry()","im", $2);
definekey( "insert_yearly_diary_entry()", "iy", $2);
definekey( "cal_other_month()", "o", $2);

provide("cal");

% cal.sl    -*- mode: Slang; mode: fold -*-
%
% $Id: cal.sl,v 1.15 2007/12/08 07:14:21 paul Exp paul $
% Keywords: calendar, Emacs
%
% Copyright (c) 2000-2006 JED, Eero Tamminen, Paul Boekholt
% Released under the terms of the GNU GPL (version 2 or later).
%
% This is a clone of the Emacs calendar package.  You can move around,
% insert diary entries and view diary entries for the day at point. You
% can bind your own keys with the calendar_mode_hook.

provide("cal");
_autoload("cal_print_iso_date", "calmisc.sl",
"cal_goto_iso_date", "calmisc.sl",
"cal_print_day_of_year", "calmisc.sl", 3);

require("diary");
require("keydefs");
use_namespace("calendar");
variable mode = "calendar";

%{{{ customization
% each month name may be at max. 15 characters
custom_variable ("CalMonths", "Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec");
% each day is two characters, separated with space
$1 = " S  M Tu  W Th  F  S ";
% CalDays gets rotated for CalStartWeek
custom_variable ("CalDays", $1 [ (CalStartWeek * 3 + [0:20]) mod 21]);
% prompt
custom_variable ("CalPrompt", "Month Year:");
% the number of days to look ahead when viewing appointments.
% By default, if you press "d" on Sunday + CalStartWeek, you should see
% the appointments for the following week.  The arithmetic is such that
% the customvar looks ahead n days, like the calendar program, but the
% numeric prefix looks at n days including the current day, like Emacs.
% The diary() function does not look ahead.
custom_variable ("DiaryLookahead", [6,0,0,0,0,0,0]);


% This is a list of arrays of strings that assigns different colors to
% different appointments.  It should look like 
% {["meeting", "String"], ["breakfast", "lunch", "Comment"], ...}

custom_variable ("diary_colors", {});

% more custom_variables in diary.sl
%}}}
variable displayed_month, displayed_year; % the displayed month / yr
% same as cursor_month and cursor_year, but maybe someone likes Emacs'
% motion better.
variable this_month, this_day, this_year; % today's date
variable cursor_month, cursor_day, cursor_year, cursor_absolute_date; % cursor date
variable cal_nlines = 8;
%{{{ calendar functions

% is yearnum a leap year
% if it's not divisible by 4, it won't be divisible by 100 or 400
define cal_leap_year_p (year)
{
   andelse
     {not(year & 3)}
     {orelse 
	  {0 != year mod 100}
	  {not (year mod 400)}};
}

variable days_in_month = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
variable days_to_month =[0, 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];

% The last day in MONTH during YEAR
define last_day_of_month(month, year)
{
   if (andelse
     {month == 2}
     {cal_leap_year_p(year)})
     return 29;
   else return days_in_month[month];
}

% calculate day of year for given date
define cal_day_number(month, day, year)
{
   day + days_to_month[month] +
     (andelse
      {month > 2}
	{cal_leap_year_p(year)});
}

% calculate day of week for given date, from Sunday + CalStartWeek
define cal_day_of_week(month, day, year)
{
   variable c, a;
   cal_day_number(month, day, year);
   --year;
   
   a = () + year + year/4;
   c = year/100 * 3;
   if (c & 3) a--;

   return (a - c/4 - CalStartWeek) mod 7;
}

% return current (month, day, year) as integers
define cal_get_date()
{
   variable now = localtime(_time());
   return 1 + now.tm_mon, now.tm_mday, 1900 + now.tm_year;
}

% convert month number or localized name string into integer
define cal_convert_month (month_name)
{
   variable m;
   m = is_list_element(strlow(CalMonths), strlow(month_name), ',');
   if (m) return m;
   % presume it's an integer
   return atoi(month_name);
}

% The number of days elapsed between the Gregorian date 12/31/1 BC and DATE.
% The Gregorian date Sunday, December 31, 1 BC is imaginary.
% This won't work with 16 bit integers.
define absolute_from_gregorian (month, day, year)
{
   cal_day_number(month, day, year);
   --year;
   return ()
     + 365 * year
     + year / 4
     - year / 100
     + year / 400;
}

define gregorian_from_absolute (day)
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
   day  = day mod 365;
   day++;
   year = 400 * n400 + 100 * n100 + 4 * n4 + n1;
   if (n100 == 4 or n1 == 4) return (12, 31, year);
   year++;
   for (month = 1; mdays = last_day_of_month(month,year), mdays < day; month++)
     day -= mdays;
   return month, day, year;
}

%}}}

%{{{ calendar drawing functions
variable today_visible;

define cal_cursor_to_visible_date (month, day, year);

define generate_calendar (month, year)
{
   today_visible = 0;
   set_readonly(0); erase_buffer();
   (displayed_month, displayed_year) = (month, year);

   % output a month to the stack
   
   variable first, max,
        daystring = "  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31                     ",
     white = "                                                  ";
   variable month_name, month_len, month_line;
   USER_BLOCK0
     {
	if (month == this_month and year == this_year)
	  today_visible = 1;

	month_name = extract_element(CalMonths, month - 1, ',');
	month_len = strlen(month_name) + 5;
	first = (21 - month_len) / 2; 
	month_line = sprintf("%s%s%5d%s",white[[1:first]],  month_name, year, white[[1: 21 - first - month_len]]);
	
	% get days in month
	first = 3 * cal_day_of_week(month, 1, year);
	max = 3 * last_day_of_month(month, year);
	
	variable c = white[[1:first]] + daystring[[1:max]] + white[[1:126 - max - first]];
	[month_line,CalDays,c[[0:20]],c[[21:41]],c[[42:62]],c[[63:83]],c[[84:104]],c[[105:125]]];
     }


   % output three months

   % each month is an array of 8 lines of 21 characters, the '+' operator
   % works transparently on arrays.

   --month; if (month == 0) { month = 12; --year; }
   X_USER_BLOCK0;
   "    ";
   ++month; if (month == 13) { month = 1; ++year; }
   X_USER_BLOCK0;
   "    ";
   ++month;  if (month == 13) { month = 1; ++year; }
   X_USER_BLOCK0;

   insert(strjoin(() + () + () + () + (), "\n"));
   
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


%}}}

%{{{ calendar movement functions

% save a few tokens
define cursor_date()
{
   return cursor_month, cursor_day, cursor_year;
}

% This function will actually move to any of the 3 visible months, like in
% Emacs, but I find Emacs' calendar motion confusing. I can still use this
% for marking diary entries.
define cal_cursor_to_visible_date (month, day, year)
{
   goto_line ((day + 20 + cal_day_of_week (month, 1, year)) / 7);
   goto_column (2
		+ 25 *  (1 + 12 * (year - displayed_year) + month - displayed_month)
		+ 3 * (cal_day_of_week(month, day, year)));
}


define cal_goto_date (month, day, year)
{
   !if (month == displayed_month and year == displayed_year)
     generate_calendar (month, year);
   cal_cursor_to_visible_date (month, day, year);
   runhooks("calendar_move_hook");
}

define goto_absolute_date(date)
{
   cursor_absolute_date=date;
   (cursor_month, cursor_day, cursor_year) = gregorian_from_absolute (date);
   cal_goto_date (cursor_date());
}

define goto_gregorian_date() % (month, day, year)
{
   (cursor_month, cursor_day, cursor_year) = ();
   cursor_absolute_date = absolute_from_gregorian(cursor_date());
   cal_goto_date (cursor_date());
}

% Move the cursor forward ARG days.
% Moves backward if ARG is negative.
define forward_day (arg)
{
   variable prefix = prefix_argument(-1);
   if (prefix == -1) prefix = 1;
   goto_absolute_date(cursor_absolute_date + arg * prefix);
}
   

%}}}

%{{{ calendar mark functions

variable marked_date;

define cal_set_mark()
{
   marked_date = cursor_absolute_date;
}

define cal_exchange_point_and_mark()
{
   if (marked_date == NULL) throw RunTimeError, "calendar mark is not set";
   variable this_date = cursor_absolute_date;
   goto_absolute_date(marked_date);
   marked_date = this_date();
}

define cal_count_days_region()
{
   if (marked_date == NULL) throw RunTimeError, "calendar mark is not set";
   vmessage("region has %d days (inclusive)", 1 + abs(cursor_absolute_date - marked_date));
}
  

%}}}

%{{{ diary functions

% show diary entries for this date
%!%+
%\function{show_diary_entries}
%\synopsis{view appointments for day in calendar}
%\usage{show_diary_entries()}
%\description
%   Open the \var{DiaryFile} and show appointments for the day selected
%   in the \var{calendar} buffer and \var{DiaryLookAhead}[day of week]
%   days after, or for the number of days of the prefix argument
%\seealso{calendar, diary}
%!%-
public define show_diary_entries()
{
   variable lookahead = prefix_argument(-1), date = cursor_absolute_date,
     month, day, year,
     wday = cal_day_of_week(cursor_date());
   if (_NARGS) lookahead = ();
   else if (lookahead == -1)
     lookahead = 1 + DiaryLookahead[wday];
   open_diary();
   pop2buf(dbuf);
   mark_buffer();
   set_region_hidden(1);
   loop (lookahead)
     {
	(month, day, year) = gregorian_from_absolute(date);
	show_entries_for_day(month, day, year);
	show_matching_entries (CalWeekdays[wday]);
	show_matching_entries(sprintf("%s+%d", CalWeekdays[wday], 1 + (day - 1) / 7));
	% uncomment this to show floating diary entries in Emacs format
	% if you want backward floating entries, ask
	% show_matching_entries(sprintf("&%%%%(diary-float t %d +%d)", (day + CalStartWeek) mod 7, 1 + (day - 1) / 7));
	wday = (wday + 1) mod 7;
	date++;
     }
   % show_matching_entries left point at bob.  It makes sense to list 
   % recurring appointments first and then non-recurring ones, so go to
   % the last visible line.
   eob;
   skip_hidden_lines_backward(1);
   pop2buf("*calendar*");
}

define show_all_diary_entries()
{
   open_diary;
   push_spot;
   mark_buffer;
   set_region_hidden(0);
   pop_spot;
   pop2buf(dbuf);
   pop2buf("*calendar*");
}

% calendar requires continuation lines to begin with a tab.
define diary_indent_hook()
{
   !if (looking_at_char('\t')) insert_char ('\t');
}

define diary_wrap_hook()
{
   push_spot_bol();
   diary_indent_hook();
   pop_spot();
}

public define mark_diary_entries();

% insert a string in the diary file
define make_diary_entry (s)
{
   open_diary();
   pop2buf(dbuf);
   eob();
   !if(bolp()) newline();
   set_line_hidden(0);
   insert(s + "\t");
   set_buffer_hook("wrap_hook", &diary_wrap_hook);
   set_buffer_hook("indent_hook", &diary_indent_hook);
   setbuf("*calendar*");
   mark_diary_entries;
   pop2buf(dbuf);
}

% insert a diary entry for date at point
define insert_diary_entry ()
{
   if (DiaryEuropeanFormat)
     make_diary_entry(sprintf("%d/%d/%d", cursor_day, cursor_month, cursor_year));
   else
     make_diary_entry(sprintf("%d/%d/%d", cursor_date()));
}

% and for this day of the week
define insert_weekly_diary_entry ()
{
   make_diary_entry
     (CalWeekdays[cal_day_of_week(cursor_date())]);
}

% and for this day of every month
define insert_monthly_diary_entry ()
{
   if (DiaryEuropeanFormat)
     make_diary_entry(string(cursor_day) + "/*");
   else
     make_diary_entry("*/" + string(cursor_day));
}

% and for this day of every year
define insert_yearly_diary_entry ()
{
   if (DiaryEuropeanFormat)
     make_diary_entry(string(cursor_day) + "/" +  string(cursor_month));
   else
     make_diary_entry(string(cursor_month) + "/" +  string(cursor_day));
}

variable default_color = length(diary_colors) + 1;
define extract_color_number(color_entry)
{
   return color_number(diary_colors[color_entry][-1]);
}

% This doesn't work on lists.
% variable diary_color_numbers = array_map(Integer_Type, &extract_color_number, diary_colors);

define assign_colors(month_colors, mark_pattern, month, year)
{
   month_colors[*]=0;
   variable mark_re = sprintf(mark_pattern, month, year);
   variable appt, i, day, appt_pattern;
   bob();
   while (re_fsearch(mark_re))
     {
	day = atoi(regexp_nth_match(1));
	!if (month_colors[day])
	  month_colors[day] = default_color;
	()=ffind_char('\t');
	while (looking_at_char('\t'))
	  {
	     appt=line_as_string();
	     for (i = 1; i < month_colors[day]; i++)
	       {
		  foreach appt_pattern (diary_colors[i-1][[:-2]])
		    {
		       if (is_substr(appt, appt_pattern))
			 {
			    month_colors[day] = i;
			    break;
			 }
		    }
	       }
	     !if(down_1()) return;
	  }
     }

}

define insert_colors(month_colors, month, year)
{
   variable color, day;
   foreach day (where(month_colors))
     {
	cal_cursor_to_visible_date(month, day, year);
	if (month_colors[day] == default_color)
	  color = color_number("keyword");
	else
	  color = extract_color_number(month_colors[day]-1);
	bskip_chars("0-9*");
	insert(sprintf("\e[%d]", color));
	skip_chars("0-9*");
	insert("\e[0]");
     }
}

% mark days for which there are appointments.
public define mark_diary_entries()
{
   set_readonly(0);
   bob;
   replace("\t", " ");
   variable mark_pattern, mark_re,
     month, day, year;
   variable month_colors = Integer_Type[32];
   if (DiaryEuropeanFormat)
     mark_pattern = "^\\([0-9][0-9]?\\)/0?%d/%d\t";
   else
     mark_pattern = "^0?%d/\\([0-9][0-9]\\)?/%d\t";
   (month, year) = (cursor_month, cursor_year);
   open_diary();
   USER_BLOCK0
     {
	setbuf(dbuf);
	push_spot();
	assign_colors(month_colors, mark_pattern, month, year);
	pop_spot();
	setbuf("*calendar*");
	insert_colors(month_colors, month, year);
     }

   --month; if (month == 0) { month = 12; --year; }
   X_USER_BLOCK0;
   ++month; if (month == 13) { month = 1; ++year; }
   X_USER_BLOCK0;
   ++month;  if (month == 13) { month = 1; ++year; }
   X_USER_BLOCK0;

   pop_spot();
   set_readonly(1);
   set_buffer_modified_flag(0);
   cal_cursor_to_visible_date(cursor_date);
}


%}}}

%{{{ other functions

% read a month and year
define read_date ()
{
   variable t, default, month, year;
   default = sprintf ("%s %d", extract_element(CalMonths, this_month-1, ','), this_year);

   t = strtrim (read_mini (CalPrompt, default, Null_String));

   month = cal_convert_month(extract_element(t, 0, ' '));
   year = integer(extract_element(t, 1, ' '));
   if (month < 1 or month > 12 or year < 1)
     throw RunTimeError, "not a valid date";
   return month, year;
}

define other_month ()
{
   variable month, day, year;
   (month, year) = read_date();
   if (month == displayed_month)
     day = cursor_day;
   else if (month == this_month and year == this_year)
     day = this_day;
   else day = 1;
   goto_gregorian_date (month, day, year);
}


define quit()
{
   otherwindow();
   if (whatbuf() == dbuf)
     {
	bury_buffer(dbuf);
	otherwindow;
     }
   onewindow();
   delbuf ("*calendar*");
}

%}}}

%{{{ calendar mode

define cal_menu(menu)
{
   menu_append_item (menu, "view appointments", "show_diary_entries");
   menu_append_item (menu, "mark diary entries", "mark_diary_entries");
   menu_append_item (menu, "&show all entries", "calendar->show_all_diary_entries");
   menu_append_separator(menu);
   menu_append_item (menu, "insert &diary entry", "calendar->insert_diary_entry");
   menu_append_item (menu, "insert &weekly entry", "calendar->insert_weekly_diary_entry");
   menu_append_item (menu, "insert &monthly entry", "calendar->insert_monthly_diary_entry");
   menu_append_item (menu, "insert &yearly entry", "calendar->insert_yearly_diary_entry");
   menu_append_separator(menu);
   menu_append_item (menu, "&other month", "calendar->other_month");
   menu_append_item (menu, "day of year", "cal_print_day_of_year");
   menu_append_item (menu, "iso date", "cal_print_iso_date");
   menu_append_item (menu, "go to iso date", "cal_goto_iso_date");
   menu_append_item (menu, "&quit", "calendar->quit");
}


define calendar_mode()
{
   set_mode("calendar", 0);
   use_keymap ("Calendar_Map");
   _set_buffer_flag(0x1000);
   mode_set_mode_info(mode, "init_mode_menu", &cal_menu);
   run_mode_hooks("calendar_mode_hook");
}


% output three month calendar into separate buffer

%!%+
%\function{calendar}
%\synopsis{calendar and diary}
%\usage{public define calendar ()}
%\description
%  \var{calendar} opens a three month calendar window.
%  The asterisk denotes the current day.  
%  The arrow keys move by day and week, PgUp and PgDn move by 91 days
%  (close enough to 3 months).
%  These commands accept a numeric argument as a repeat count.  For
%  convenience, the digit keys specify numeric arguments in Calendar
%  mode even without the Meta modifier.
%  \var{o}   move to an other month
%  \var{p d} show the daynumber in the minibuffer
%  \var{p c} show the ISO commercial date
%  \var{g c} go to an ISO commercial date
%  
%  Diary functions:
%  
%  \var{i d} insert diary entry
%  \var{i w} insert weekly diary entry
%  \var{i m} insert monthly diary entry
%  \var{i y} insert yearly diary entry
%  \var{d}   view diary entries for day at point
%  \var{s}   show the entire diary file
%  \var{m}   mark dates this month for which there are appointments
%  	     (only non-recurring appointments)
%   
%\notes
%  slsh also has a calendar function, which is similar to JED's
%  \var{diary} function and can be used as a replacement for the BSD
%  calendar program.
%   
%\seealso{diary, show_diary_entries}
%!%-
public define calendar ()
{
   variable month, day, year;
   variable obuf = whatbuf();
   % ask user for month / year

   (this_month, this_day, this_year) = cal_get_date();
   (cursor_month, cursor_day, cursor_year) =
     (this_month, this_day, this_year);
   (month, year) =  this_month, this_year; % read_date();

   % I want the calendar in the bottom window
   onewindow();
   sw2buf("*calendar*");
   _set_buffer_flag(0x1000);
   bob();
   splitwindow();	% when I do this manually I end up in top 
   			% window, but when done from slang in the bottom?
   % I need 8 lines
   variable nlines = window_info('r');
   if (nlines > cal_nlines)
     {
	otherwindow();
	loop (nlines - cal_nlines) enlargewin();
     }
   else
     {
	loop (cal_nlines - nlines) enlargewin();
	otherwindow();
     }
   sw2buf(obuf);
   otherwindow();
   generate_calendar(month, year);
   if (month == this_month and year == this_year)
     day = this_day;
   else
     day = 1;
   goto_gregorian_date(month, day, year);
   %  what the heck, give current time
   message(time);
   calendar_mode ();
}


$2 = "Calendar_Map";
!if (keymap_p($2))
  make_keymap($2);
definekey( "calendar->forward_day( -1)", Key_Left , $2);
definekey( "calendar->forward_day(  1)", Key_Right, $2);
definekey( "calendar->forward_day( -7)", Key_Up   , $2);
definekey( "calendar->forward_day(  7)", Key_Down , $2);
definekey( "calendar->forward_day(-91)", Key_PgUp , $2);
definekey( "calendar->forward_day( 91)", Key_PgDn , $2);
#ifdef IBMPC_SYSTEM
definekey( "calendar->cal_set_mark",		"^@^C", $2);
#else
definekey( "calendar->cal_set_mark", "^@", $2);
#endif
definekey( "calendar->cal_exchange_point_and_mark", "^x^x", $2);
definekey( "calendar->cal_count_days_region", "\e=", $2);
definekey( "calendar->quit"       , "q", $2);
definekey( "show_diary_entries", "d", $2);
definekey( "calendar->show_all_diary_entries", "s", $2);
definekey( "calendar->insert_diary_entry", "id", $2);
definekey( "calendar->insert_weekly_diary_entry", "iw", $2);
definekey( "calendar->insert_monthly_diary_entry","im", $2);
definekey( "calendar->insert_yearly_diary_entry", "iy", $2);
definekey( "calendar->other_month", "o", $2);
definekey( "mark_diary_entries", "m", $2);
definekey( "cal_print_iso_date", "pc", $2);
definekey( "cal_goto_iso_date", "gc", $2);
definekey( "cal_print_day_of_year", "pd", $2);

% treat number keys as numeric prefix
. 1 9 1 {string "digit_arg" exch $2 definekey} _for


%}}}

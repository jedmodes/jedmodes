% diary.sl
% 
% $Id: diary.sl,v 1.4 2005/11/26 16:58:06 paul Exp paul $
% Keywords: calendar, Emacs
% 
% Copyright (c) 2003 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This file provides the diary function that can be used to view your
% appointments on starting JED. To keep this file small, diary() has no
% facilities for viewing appointments for another date than today (or
% tomorrow after 9 pm) or for looking ahead. If you want to do that, start
% calendar and run show_diary_entries (bound to d) or use the BSD calendar
% program - or Emacs.

provide("diary");

implements("calendar");

variable dbuf = " *diary*";
% sunday=0, monday=1...
custom_variable ("CalStartWeek", 0);

% weekday names for inserting weekly reminders
variable weekdaynames =
  ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
custom_variable ("CalWeekdays", weekdaynames[ (CalStartWeek + [0:6]) mod 7 ]);
% the file where you keep all your appointments.
% According to Emacs it should be ~/diary, but in my version of calendar
% it's ~/calendar.
custom_variable ("DiaryFile", dircat(getenv("HOME"), "calendar"));

% Should the diary be in the European format dd/mm/yyyy? This only works
% with show_diary_entries(), unless you have a calendar program that 
% understands it. To convert your calendar file between European and 
% American style, try regexp-replacing \([^\/]+\)/\([0-9\*]+\) by \2\/\1
custom_variable ("DiaryEuropeanFormat", 0);


#ifdef HAS_DFA_SYNTAX
create_syntax_table ("diary");
%%% DFA_CACHE_BEGIN %%%
define setup_dfa_callback_diary (mode)
{
   dfa_enable_highlight_cache("diary.dfa", mode);
   dfa_define_highlight_rule ("^[0-9\\*][0-9\\*]?/[0-9\\*][0-9\\*]?\t", "comment", mode);
   dfa_define_highlight_rule ("^[0-9][0-9]?/[0-9][0-9]?/20[0-9][0-9]\t", "comment", mode);
   foreach (weekdaynames)
     dfa_define_highlight_rule (Sprintf("^%s\\+?[1-5]?\t", exch, 1), "string", mode);
   
   dfa_build_highlight_table(mode);
}
dfa_set_init_callback (&setup_dfa_callback_diary, "diary");
%%% DFA_CACHE_END %%%
#endif

public define diary_mode()
{
#ifdef HAS_DFA_SYNTAX
   use_syntax_table("diary");
   use_dfa_syntax(1);
#endif
}

% open the diary
define open_diary()
{
   () = read_file(DiaryFile);
   diary_mode;
   rename_buffer(dbuf);
   set_buffer_no_autosave(); % Don't want an "autosaved is newer" message on startup
}

define show_matching_entries(string)
{
   bob();
   while (bol_fsearch(string + "\t"))
     {
	do
	  {
	     set_line_hidden(0);
	     !if (down_1) return;
	  }
	while (looking_at_char(' ') or looking_at_char('\t') or eolp);
     }
}

% show diary entries for this date
define show_entries_for_day (month, day, year)
{
   if (DiaryEuropeanFormat)
     {
	show_matching_entries(sprintf("%d/%d/%d", day, month, year));
	show_matching_entries(sprintf("%d/%d", day, month));
	show_matching_entries(sprintf("%d/*", day));
     }
   else
     {
	show_matching_entries(sprintf("%d/%d/%d", month, day, year));
	show_matching_entries(sprintf("%d/%d", month, day));
	show_matching_entries(sprintf("*/%d", day));
     }
   bob();
}

% Show the diary for today, or for tomorrow if it's
% after 9.00 pm. You may put this in your .jedrc.
%!%+
%\function{diary}
%\synopsis{view appointments for today}
%\usage{diary()}
%\description
%   Open the \var{DiaryFile} and show appointments for today, or,
%   after 9.00 pm, for tomorrow.
%   If \var{DiaryEuropeanFormat} == 1, the diary file looks like
%#v+
%   19/3/2003	appointment with Fate
%   07/04	happy birthday!
%   25/*	Payday
%   Friday	Thank God!
%   	Continued line, starts with whitespace
%   Friday+1	the first Friday of the month
%#v-
%   and should be mostly compatible with Emacs' diary and the BSD calendar
%   program except Emacs does not recognize Friday+1, BSD calendar does
%   not recognize European dates, and this function doesn't recognize lots
%   of things (it is however lightning fast compared to Emacs' diary).
%   There \em{must} be a tab after the date pattern. If you make appointments
%   from within \var{calendar}, that should be all right.
%   
%\notes
%   This function only shows appointments for today, use
%   \var{show_diary_entries} from within the \var{calendar} to view
%   appointments for other days and for more than one day
%\seealso{calendar, show_diary_entries}
%!%-
public define diary()
{

   variable now = localtime(10800 + _time()),
   month, day, year, wday;
   (month, day, year, wday) = 1 + now.tm_mon, now.tm_mday, 1900 + now.tm_year,
     CalWeekdays[(now.tm_wday - CalStartWeek) mod 7];
   variable buf = whatbuf;
   open_diary();
   mark_buffer();
   set_region_hidden(1);
   show_entries_for_day(month, day, year);
   show_matching_entries(wday);
   show_matching_entries(sprintf("%s+%d", wday, 1 + (day - 1) / 7)); 
   % uncomment this to show floating diary entries in Emacs format
   % show_matching_entries(sprintf("&%%%%(diary-float t %d +%d)", now.tm_wday, 1 + (day - 1) / 7));
   bob;
   skip_hidden_lines_forward(1);
   if(is_line_hidden)
     {
	setbuf(buf);
   	bury_buffer(dbuf);
   	message("no diary entries");
     }
   else
     {
	pop2buf(dbuf);
	otherwindow;
     }
}

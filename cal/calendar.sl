#!/usr/bin/env slsh
% calendar.sl 	-*- mode: Slang; mode: Fold -*- 
% slsh replacement of the calendar program
% 
% $Id: calendar.sl,v 1.1.1.1 2004/10/28 08:16:18 milde Exp $
% Keywords: calendar
%
% Copyright (c) 2004 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This is a calendar script to show your appointments at login. Currently
% it works like the diary function in JED - it shows the appointments for
% today, or for tomorrow if it's after 9 pm.  The next version will
% probably have a 'look ahead' feature.
% 
% This script will also work in JED if you have hacked it to support
% module loading, but that's just for debugging purposes - the
% definitions in this file conflict with those in cal.sl.

#ifnexists _jed_version
require("custom");
#endif

import("pcre");

%{{{ custom variables

% weekday names for inserting weekly reminders
custom_variable ("CalWeekdays",
  ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]);

% the file where you keep all your appointments.
% According to Emacs it should be ~/diary, but in my version of calendar
% it's ~/calendar.
custom_variable ("DiaryFile", path_concat(getenv("HOME"), "calendar"));

% Should the diary be in the European format dd/mm/yyyy?
custom_variable ("DiaryEuropeanFormat", 0);

%}}}

%{{{ helper functions

% this seems to be faster than the strread_file in bufutils.sl
public define strread_file(file)
{
   variable str, fp = fopen (file, "r");
   if (fp == NULL)
     verror ("Unable to open %s: %s", file, errno_string (errno));

   () = fread (&str, Char_Type, 1000000, fp);
   str = typecast(str, String_Type);
   () = fclose(fp);
   return str;
}

%}}}

public define calendar()
{
   variable cal = strread_file(DiaryFile);
   variable now = localtime(10800 + _time()),
   month, day, year, wday;
   (month, day, year, wday) = 1 + now.tm_mon, now.tm_mday, 1900 + now.tm_year,
     CalWeekdays[now.tm_wday mod 7];
   
   variable pos = 0, pat;
   if (DiaryEuropeanFormat) pat= sprintf
     ("^(?:%s\\t|%s\\+%d\\t|%d(?:/\\*\\t|/%d(?:\\t|/%d\\t))).*(?:\\n[\\t ].*)*",
      wday, wday, 1 + (day - 1) / 7, day, month, year);

   % This will also match */5/2004 as the 5th of every month in 2004
   % JED's and BSD calendar don't support that, but Emacs' calendar does
   else pat = sprintf
          ("^(?:%s|%s\\+%d|(?:%d|\\*)/%d(?:/%d)?)\\t.*(?:\\n[\\t ].*)*",
	   wday, wday, 1 + (day - 1) / 7, month, day, year);
   variable cal_re = 
     pcre_compile(pat, PCRE_MULTILINE);

#ifexists _jed_version

   variable buf = whatbuf;
   pop2buf("*appointments*");
   erase_buffer;
   while(pcre_exec(cal_re, cal, pos))
     {
	insert (pcre_nth_substr(cal_re, cal, 0) + "\n");
	pos = pcre_nth_match(cal_re, 0)[1];
     }
   pop2buf(buf);

#else

   while(pcre_exec(cal_re, cal, pos))
     {
	message (pcre_nth_substr(cal_re, cal, 0));
	pos = pcre_nth_match(cal_re, 0)[1];
     }

#endif

}

public define slsh_main ()
{
   calendar();
   exit (0);   
}


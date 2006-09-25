% dict-cli.sl: dict backend using the command line interface `dict`
% 
% Copyright (c) 2005 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1   2006-03-13 first public version
% 0.1.1 2006-09-25 use do_shell_cmd() for error redirection  
%

provide("dict-backend");
provide("dict-cli");

% Requirements
% ------------

% * `dict` command line dict-client (see Dict_Cmd)


%!%+
%\variable{Dict_Cmd}
%\synopsis{Command line program for dict lookup}
%\usage{variable Dict_Cmd = "dict"}
%\description
% The command line program for dict lookup (on most systems this will be
% "dict"). An alternative is "dictl", a wrapper for conversion of|from UTF8
% into the users locale)
%\example
% To use the "dictl" wrapper if the current locale is not utf8 aware put in
% ~/.jed/jed.rc (or ~/.jedrc)
%#v+
%  if (_slang_utf8_ok)
%    variable Dict_Cmd = "dict";
%  else
%    variable Dict_Cmd = "dictl";
%#v-
%\seealso{dict, dict_mode, Dict_Server, Dict_DB}
%!%-
custom_variable("Dict_Cmd", "dict");


% cache for dict_show results
static variable show_cache = Assoc_Type[String_Type];
static variable last_host = "";


% transform host argument to command line option(s)
%   "host"       -->  "--host <host>"
%   "host:port"  -->  "--host <host> --port <port>"
private define parse_host(host)
{
   host = strtok(host, ":");
   return "--host " + strjoin(host, " --port ");
}


define dict_define(word, database, host)
{
   variable db, cmd;
   foreach (strtok(database, ","))
       {
	  db = ();
	  cmd = sprintf("%s --database '%s' %s '%s'", 
	     Dict_Cmd, db, parse_host(host), word);
	  set_prefix_argument(1);
	  do_shell_cmd(cmd);

       }
}

% insert the result of the MATCH command into the current buffer
define dict_match(word, strategy, database, host)
{
   variable db, cmd;
   foreach (strtok(database, ","))
       {
	  db = ();
	  cmd = sprintf("%s --database '%s' %s --match --strategy %s '%s'", 
	     Dict_Cmd, db, parse_host(host), strategy, word);
	  set_prefix_argument(1);
	  do_shell_cmd(cmd);
       }
}

% insert the result of the SHOW command into the current buffer
define dict_show(what, host)
{
   if (host != last_host)
     {
        show_cache = Assoc_Type[String_Type]; % reset cache
        last_host = host;
     }

   % if the result is cashed, insert and return
   if (assoc_key_exists(show_cache, what))
     return insert(show_cache[what]);
   
   % what --> option
   switch (what)
     { case "db":      what = "--dbs"; }
     { case "strat":   what = "--strats"; }
     { case "server":  what = "--serverinfo"; }
     { is_substr(what, "info"): % convert "info:<db>" to "-- info <db>"
	what = strtok(what, ":");
        what = "--info " + strjoin(what, " ");
     }
     { error("argument must be one of 'db', 'strat', 'server', info:<db>"); }
   
   set_prefix_argument(1);
   do_shell_cmd(sprintf("%s %s %s", Dict_Cmd, parse_host(host), what));
   
   % cache result
   mark_buffer();
   show_cache[what] = bufsubstr();
}



#iffalse
   %  Build a dict:// URL for the query defined by the arguments in the form
   %    dict://host:port/d:word:database
   %    dict://host:port/m:word:database:strategy
   %  (see `man dict` or section 5. "URL Specification" of RFC2229)
   variable db, urls, url;
   if (is_substr(word, "dict://") == 1)
     urls = [word];
   else if (strategy == NULL) % definition lookup
     urls = array_map(String_Type, &sprintf, "dict://%s/d:%s:%s", 
	Dict_Server, word, strtok(database, ","));
   else
     urls = array_map(String_Type, &sprintf, "dict://%s/m:%s:%s:%s",
	Dict_Server, word, strtok(database, ","), strategy);
#endif

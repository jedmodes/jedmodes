% dictmode.sl   dict dictionary lookup
%
% Copyright (c) 2006 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% This 'jed dict mode' provides an interface to the `dict` command line
% program. See dict.sl and dict-lookup.sl for alternatives
%
% Version
% 2006-01-11  0.1    first draft
% 2006-01-24  0.2    lots of tips from Paul Boekholt
%                    less dependencies
%                    added thesaurus function
% 	      	     dict calls "dict_client_hook" and "dict_show_databases_hook"
% 	      	     for alternative client
% 	      	     syntax highlighting (non DFA as DFA has problems with UTF8)
% 	      	     INITIALIZATION block with popup hook
% 2006-02-06  0.3    bugfixes [PB], 	      	     
% 2006-02-07  0.4    multiple databases
% 2006-02-20  0.5    "dict API" to use a dict-backend mode
% 2006-03-10  0.6    match (Paul Boekholt)
% 2006-03-13         first public version
% 2006-03-14  0.6.1  bugfix for zero-length keywords
% 2006-09-26  0.6.2  bugfix for {multi word keywords} (report Paul Boekholt)
% 2007-10-18  0.6.3  optional extensions with #if ( )
%
% Usage
% -----
%
% * Place "dictmode.sl" and required|recommended files in the
%   jed_library_path
% * Add the INITIALIZATION block to your .jedrc or use make_ini()
%   (http://jedmodes.sf.net/mode/make_ini/)
% * Optionally define custom variables and hooks

#<INITIALIZATION>
_autoload("dict", "dictmode",
   "thesaurus", "dictmode",
   "dict_lookup", "dictmode",
   "dict_menu_callback", "dictmode",
   4);
_add_completion("dict", "thesaurus", 2);

static define dict_load_popup_hook(menubar)
{
   variable menu = "Global.S&ystem";
   menu_insert_popup ("&Ispell", menu, "&Dict");
   menu_set_select_popup_callback(menu+".&Dict", &dict_menu_callback);
}
append_to_hook("load_popup_hooks", &dict_load_popup_hook);
#</INITIALIZATION>

% debug information, uncomment to locate errors
% _debug_info = 1;

% Requirements
% ============

% dict-backend
% ------------

%!%+
%\variable{Dict_Backends}
%\synopsis{List of SLang files providing a dict interface}
%\usage{variable Dict_Backends = "dict-cli.sl,dict-curl.sl,dict-socket.sl"}
%\description
%  When evaluated, dictmode.sl searches the files in this comma
%  delimited list in the jed library path and evaluates the first
%  found.
%\example
%  To choose the dict-curl.sl backend, set in jed.rc
%#v+
%   variable Dict_Backends = "dict-curl.sl";
%#v-
%\seealso{dict, dictmode, Dict_Server, Dict_DB, Dict_Cmd}
%!%-
custom_variable("Dict_Backends", "dict-cli.sl,dict-curl.sl,dict-socket.sl");

!if (_featurep("dict-backend"))
{
   foreach $1 (strchop(Dict_Backends, ',', 0))
     {
	if (expand_jedlib_file($1) != "")
	  if (evalfile($1))
	    break;
     }
   !if (_featurep("dict-backend"))
     verror("dictmode needs a backend, e.g. one of %s.", Dict_Backends);
}

require("keydefs");   % >= jed 99.17 or x-keydefs (symbolic names for keys)
% modes from jedmodes.sf.net/
require("view");      % readonly-keymap
require("sl_utils");  % push_defaults(), get_blocal(), run_function, ...
require("bufutils");  % >= 1.9 (as there was a bug in close_and_*_word())
                      % popup_buffer(), help_message(), ...
autoload("bget_word", "txtutils");

% Recommendations
% ---------------

% listing widget
#if (strlen(expand_jedlib_file("listing.sl")))
autoload("listing_mode", "listing");
autoload("listing_list_tags", "listing");
#endif 

% History: walk for and backwards in the history of lookups
#if (strlen(expand_jedlib_file("circle.sl")))
require("circle");
% dummy autoload for byte-compiling
#if (autoload("create_circ", "circle"), 1)
#endif
#endif

% Table formatting
#if (strlen(expand_jedlib_file("csvutils.sl")))
autoload("list2table", "csvutils");
autoload("get_lines", "csvutils");
autoload("strjoin2d", "csvutils");
% dummy autoload for byte-compiling
#if (autoload("list2table", "csvutils.sl"), 1)
#endif
#endif


% Custom variables
% ----------------

%!%+
%\variable{Dict_Server}
%\synopsis{Server for Dict lookups}
%\usage{variable Dict_Server = "localhost"}
%\description
%  The server that should be contacted by \sfun{dict}.
%
%  Most common values are "localhost" and "dict.org" but any server that
%  understands the DICT protocoll as specified in RFC2229 may be given.
%
%  If the port is different from the default (2628), it should be appended
%  as in e.g. "localhost:2777".
%\seealso{dict, dict->set_server, Dict_Cmd}
%!%-
custom_variable("Dict_Server", "localhost");
% custom_variable("Dict_Server", "dict.org");

%!%+
%\variable{Dict_DB}
%\synopsis{Default database(s) for dict lookup}
%\usage{variable Dict_DB = "*"}
%\description
%  A comma separated list of default dictionaries used with \sfun{dict}.
%
%  The Dict_DB can be changed with \sfun{dict->select_database} for a
%  running Jed session or customized in jed.rc.
%  dict->show("db") lists all available databases.
%\example
%  To get only the first matching entry, write in your jed.rc file
%#v+
%  variable Dict_DB = "!";
%#v-
%  To use "The Free On-line Dictionary of Computing" and the "Jargon File" write
%#v+
%  variable Dict_DB = "foldoc,jargon";
%#v-
%\seealso{dict, select_database, Dict_Thesaurus_DB, Dict_Translation_DB}
%!%-
custom_variable("Dict_DB", "*");  % "*" == default

%!%+
%\variable{Dict_Thesaurus_DB}
%\synopsis{Thesaurus database of the dict server}
%\usage{variable Dict_Thesaurus_DB = "moby-thes"}
%\description
%  The database(s) used for \sfun{thesaurus} lookups using the dict protocoll.
%  On dict.org, the only thesaurus database is "moby-thes".
%\notes
%  On Debian, this database is installed under the name "moby-thesaurus".
%\seealso{thesaurus, Dict_DB, Dict_Server}
%!%-
if (Dict_Server == "localhost")
  custom_variable("Dict_Thesaurus_DB", "moby-thesaurus");
else
  custom_variable("Dict_Thesaurus_DB", "moby-thes");

%!%+
%\variable{Dict_Translation_DB}
%\synopsis{Bilingual database for translations}
%\usage{variable Dict_Translation_DB = "trans"}
%\description
% An internal "virtual database" for translations.
% Comma separated list of bilingual databases.
%\example
% dict.org defines the (virtual) dictionary "trans" comprising of
% all bilingual dictionaries. 
% To choose a different set, write in your jed.rc something like
%#v+
%  Dict_Translation_DB = "fd-deu-eng,fd-deu-fra,fd-eng-deu,fd-fra-deu";
%#v-
% To set a key to look up a word in the bilinugal databases, add:
%#v+
%  setkey("dict(, Dict_Translation_DB)",   "^FT");
%#v-
%\notes
%  As there is a separate lookup for every database in the list, using
%  a server-side "virtual database" saves resources, especially if the
%  Dict_Server is not "localhost".
%\seealso{dict, dict_reverse_lookup, Dict_DB}
%!%-
custom_variable("Dict_Translation_DB", "trans");

%!%+
%\variable{Dict_Strat}
%\synopsis{Strategy for Dict match lookups}
%\usage{variable Dict_Strat = "."}
%\description
%  The strategy for listing matching words.
%
%  The default "." means use the server's default strategy.
%\seealso{dict, dict_DB, Dict_Server}
%!%-
custom_variable("Dict_Strat", ".");

% Namespace
% ---------

provide("dictmode");
provide("dict");
implements("dict");
private variable mode = "dict";

% static variables

static variable dictbuf = "*dict*";


% Functions
% =========

% compatibility for Jed < 0.99.17
#ifnexists strbytelen
define strbytelen() { strlen(); }
#endif

% Navigation
% ----------

#ifexists create_circ
variable Dict_History = create_circ(Array_Type, 30, "linear");

define previous_lookup()
{
   % runhooks fails with functions like "dict->match"
   () = run_function(push_array(circ_previous(Dict_History)));
}

define next_lookup()
{
   () = run_function(push_array(circ_next(Dict_History)));
}
#endif


define next_link()
{
   if (fsearch("{"))
     go_right_1();
   else
     {
	skip_word_chars();
	skip_non_word_chars();
     }
}

define previous_link()
{
   if(bsearch("}"))
     go_right(bsearch("{"));
   else
     bskip_word();
}

% get word or (if inside of {}) word group
static define dict_get_word()
{
   if (get_mode_name != mode) % not in a dict buffer, use default
     return bget_word();
   switch(parse_to_point())
     {
      case -2:
	() = bsearch("{");
	go_right_1();
	push_visible_mark();
	() = fsearch("}");
     }
     % Doesnot work with unbalanced string chars in [gcide]
     % {
     %  case -1:
     % 	() = bsearch("\"");
     % 	go_right_1();
     % 	push_visible_mark();
     % 	() = fsearch("\"");
     % }
   return strjoin(strtok(bget_word()), " "); % normalize whitespace
}

% parse an URL following the DICT protocoll and return
% (word, strategy, database, host)
static define parse_dict_url(url)
{
   %  Parse a dict:// URL for the query defined by the arguments in the form
   %    dict://host:port/d:word:database
   %    dict://host:port/m:word:database:strategy
   %  (see `man dict` or section 5. "URL Specification" of RFC2229)
   variable word, strategy, database, host;
   
   url = strtok(url, "/");
   host = url[1];
   url = strjoin(url[[2:]], "/");
   url = strtok(url, ":");
   word = url[1];
   database = url[2];
   if (url[0] == "m")
     strategy = url[3];
   else
     strategy = NULL;
   
   return word, strategy, database, host;
}

% Test
% show(parse_dict_url("dict://host:port/m:word:database:strategy"));
% show(parse_dict_url("dict://host:port/d:word:database:strategy"));

% Lookup
% ------

static define dict_mode(); % forward definition

%!%+
%\function{dict}
%\synopsis{Lookup a word using the Dict protocol (RFC2229)}
%\usage{dict(word=NULL, database=Dict_DB, strategy=NULL, host=Dict_Server)}
%\description
%  Interface for a RFC2229 dictionary lookup. The actual lookup is done
%  by a backend function (see \var{Dict_Backends}) and the result shown
%  in a \sfun{popup_buffer} in \sfun{dict_mode}. If \var{word} is a
%  "dict://" URL it will be parsed for database, strategy, and host.
%\example 
%  Interactive lookup (you will be asked for a word): M-x dict or
%#v+
%   dict(); 
%#v-
%  Find translations for the word at point by pressing "Ctrl-F T":
%#v+
%   setkey("dict(bget_word(), Dict_Translation_DB)", "^FT");
%#v-
%\seealso{dict_lookup, dict_reverse_lookup, dict_mode, thesaurus, dict->match}
%\seealso{Dict_Server, Dict_DB}
%!%-
public define dict() % (word=NULL, database=Dict_DB, strategy=NULL, host=Dict_Server)
{
   variable word, database, strategy, host;
   (word, database, strategy, host) = 
     push_defaults( , Dict_DB, , Dict_Server, _NARGS);
   if (word == NULL)
     word = read_mini("word to look up:", "", bget_word());

   % parse url
   if (is_substr(word, "dict://") == 1)
     (word, strategy, database, host) = parse_dict_url();

   % prepare buffer
   popup_buffer(dictbuf);
   set_readonly(0);
   erase_buffer();
   
   % insert result of dict lookup (using function provided by a "dict-backend")
   flush(sprintf("calling Dict %s [%s]", word, database));
   if (strategy == NULL)
     dict_define(word, database, host);
   else
     dict_match(word, strategy, database, host);
   
   % filter repeating header lines
   variable last_header = "Start";
   bob();
   while(bol_fsearch("From"))
     {
   	if(looking_at(last_header))
   	  {
	     % call("backward_delete_char");
   	     delete_line();
   	     while (bol_skip_white(), eolp() or looking_at(word))
   	       delete_line();
   	  }
   	else
   	  last_header = line_as_string();
     }
   bob();

   fit_window(get_blocal("is_popup", 0));
   
   % delete old keyword, define new
   variable old_keywordlen = 
     strbytelen(get_blocal("generating_function", ["", ""])[1]);
   if ((old_keywordlen > 0) and (old_keywordlen < 48))
     () = define_keywords_n(mode, "", old_keywordlen, 1);
   if ((strbytelen(word) > 0) and (strbytelen(word) < 48))
     () = define_keywords_n(mode, word, strbytelen(word), 1);
   
   % store the data for buffer (re)generation
   variable generator = [_function_name, word, database];
   if (strategy != NULL)
     generator = [_function_name, word, database, strategy];
   define_blocal_var("generating_function", generator);
#ifexists create_circ
   % Global->show(CURRENT_KBD_COMMAND);
   if (CURRENT_KBD_COMMAND != "dict->previous_lookup" and
      CURRENT_KBD_COMMAND != "dict->next_lookup")
     circ_append(Dict_History, get_blocal("generating_function"));
#endif
   
   dict_mode();
   () = fsearch(word);
}


% If you want to specify strategy, database and/or host, 
% use dict(pattern, db, strat, host)

%!%+
%\function{dict->match}
%\synopsis{Look up matches with dict}
%\usage{dict->match()}
%\description
%  Wrapper around \sfun{dict} to look up matches using \var{Dict_Strat}
%  as strategy.
%\seealso{dict, dict_lookup, dict->show, thesaurus, Dict_DB, Dict_Server}
%!%-
define match()
{
   variable pattern = read_mini("Search pattern:", dict_get_word(), ""),
   fun = mode+"->"+_function_name;
   
   dict(pattern, Dict_DB, Dict_Strat);
}

%!%+
%\function{dict_lookup}
%\synopsis{Non-interactive dictionary lookup}
%\usage{dict_lookup()}
%\description
%  Look up word at point (non-interactive) using the current database.
%\notes
%  Exception: The \var{Dict_DB} default database is used, if the current
%  lookup function is "thesaurus". This way it is easy to get detailled
%  definitions for word from the thesaurus results (simply pressing enter or
%  double clicking on the word).
%\seealso{dict, dict_reverse_lookup}
%!%-
public define dict_lookup()
{
   variable database, generator = get_blocal("generating_function", ["dict"]);
   if (generator[0] == "thesaurus" or length(generator) < 3)
     database = Dict_DB;
   else
     database = generator[2];
   dict(dict_get_word(), database);
}

static define double_click_hook(line, col, but, shift)
{
   dict_lookup();
   return(0);
}

%!%+
%\function{dict->reverse_lookup}
%\synopsis{Reverse dictionary lookup}
%\usage{dict->reverse_lookup()}
%\description
%  Look up the word at point in the reverse database, if the current
%  definition comes from a bilingual database (denoted by a hyphen in the
%  database key  e.g. deu-eng -> eng-deu. 
%    
%  If the current database is monolingual (doesnot contain a hyphen), the
%  default bilingual database (\var{Dict_Translation_DB}) is used.
%\notes
% dict->reverse_lookup uses the banner line, e.g.
%   From English - German Dictionary 1.4 [english-german]:
% to find out the current database
% 
% The reversal lookup works fine for most bilingual
%  databases but is not fail proof (e.g. 'moby-thes' becomes 'thes-moby'!)
%\seealso{dict, dict_lookup, Dict_Translation_DB}
%!%-
define reverse_lookup()
{
   variable database, word = dict_get_word(),
   generator = get_blocal("generating_function", ["dict", "", ""]);

   bol_bsearch("From");
   if (re_fsearch("\\[\\(.*\\)\\]"))
     database = regexp_nth_match(1);
   else
     database = generator[2];
   % show("reverse lookup", database);

   database = strtok(database, "-");
   if (length(database) > 1)
     % also consider cases like "fd-deu-eng"
     database = strjoin([database[[:-3]], database[-1], database[-2]], "-");
   else
     database = Dict_Translation_DB;

   runhooks(generator[0], word, database);
}

% Thesaurus
% ---------

%!%+
%\function{thesaurus}
%\synopsis{Thesaurus lookup using the Dict protocoll}
%\usage{thesaurus(word=bget_word())}
%\description
%  Do a lookup using \sfun{dict} and the \var{Dict_Thesaurus_DB}.
%  Format the output in columns. 
%\notes
%  If you prefer the more dense standard output of the moby-thesaurus,
%  bind dict(, Dict_Thesaurus_DB) to a key.
%\seealso{dict, dict_lookup, dict_mode, Dict_Thesaurus_DB}
%!%-
public define thesaurus() % (word=bget_word())
{
   variable word, database;
   (word, database) = push_defaults( , Dict_Thesaurus_DB, _NARGS);
   if (word == NULL)
     word = read_mini("Thesaurus lookup for:", dict_get_word(), "");

   dict(word, database);

   % overwrite some settings from dict-mode
   % define_blocal_var("word_chars", get_word_chars() + " ");
   define_blocal_var("generating_function", [_function_name, word, database]);
#ifexists create_circ
   if (CURRENT_KBD_COMMAND != "dict->previous_lookup" and
      CURRENT_KBD_COMMAND != "dict->next_lookup")
     circ_set(Dict_History, [_function_name, word, database]);
#endif

   % Format the output
   set_readonly(0);
   bob();
   % delete the headers
   if (fsearch(word))
     {
	go_down_1(); bol(); push_mark(); bob();
	del_region();
     }
   do
     trim();
   while (down_1);
   bob();
   replace(", ", "\n");
   replace(",\n", "\n");

% format thesaurus output in collumns
#ifexists list2table
   variable words = get_lines(1);
   words = list2table(words);
   insert(strjoin2d(words, " ", "\n", "l"));
#else
   buffer_format_in_columns();
#endif
   bob;
   set_readonly(1);
   set_buffer_modified_flag(0);
}


% what is one of ["db", "strat", "info", "server", info:<db>]
%!%+
%\function{dict->show}
%\synopsis{Interface to the SHOW command in RFC2229}
%\usage{dict->show(what=NULL)}
%\description
%  Show info about the current \var{Dict_Server}.
%  What is one of
%   "db"        -- available databases
%   "strat"     -- available strategies
%   "server"    -- info|help for the server
%   "info:<db>" -- info about the database <db>
%\seealso{dict, dict->match, dict->select_database, dict->select_strategy}
%!%-
static define show() % (what=NULL)
{
   !if (_NARGS)
     read_with_completion("db,strat,server,info:", "Show what:", 
	"db", "", 's');
   variable what = ();

   popup_buffer("*dict show*");
   set_readonly(0);
   erase_buffer();

   dict_show(what, Dict_Server);
   
   view_mode();
   bob();
}


% Set custom variables
% --------------------

%!%+
%\function{dict->set_server}
%\synopsis{set the Dict Server}
%\usage{dict->set_server()}
%\description
%  Set the server that should be contacted by \sfun{dict}.
%
%  The most common values "localhost" and "dict.org" are available with
%  TAB or SPACE completion, but any server that
%  understands the DICT protocoll as specified in RFC2229 may be given.
%
%  If the port is different from the default (2628), it should be appended
%  as in e.g. "localhost:2777".
%\seealso{Dict_Server, dict, dict_mode}
%!%-
define set_server()
{
   Dict_Server = read_with_completion("dict.org,localhost",
      "Set Dict server:", Dict_Server, "", 's');
}

% Database selection
% ------------------

% set a new value for Dict_DB
define set_database() % (database=NULL)
{
   variable database = push_defaults(, _NARGS);
   if (database == NULL)
     database = read_mini("New Dict database:", Dict_DB, "");
   Dict_DB = extract_element(strtrim(database), 0, ' ');
   vmessage("Dict_DB set to '%s'", Dict_DB);
}

% this function is called by pressing "Return" in the buffer opened by select_database()
private define select_database_return_hook()
{
#ifexists listing_mode
   variable db = listing_list_tags(1);
#else
   variable db = [line_as_string()];
#endif
   close_buffer();
   db = array_map(String_Type, &strtrim, db);
   db = array_map(String_Type, &extract_element, db, 0, ' ');
   set_database(strjoin(db, ","));
}

% Show a list of databases and let the user select one (or several)
define select_database()
{
   show("db");
   
   % Formatting 
   %   Databases available:
   %    foldoc         The Free On-line Dictionary of Computing (19 Sep 2003)
   %    ...
   set_readonly(0);
   bob(); 
   if (ffind("available"))
      delete_line();  % chop first line
   % add symbolic databases
   insert(" *         Default search\n");
   insert(" !         First matching dictionary\n");
   
   bob();
   () = fsearch(strtok("Dict_DB", ",")[0]);
#ifexists listing_mode
   listing_mode();
#else
   view_mode();
#endif
   set_buffer_hook("newline_indent_hook", &select_database_return_hook);
   message("Select database(s), press [Return] to apply");
}

% set a new value for Dict_Strat
define set_strategy() % (strategy=NULL)
{
   variable strategy = push_defaults(, _NARGS);
   if (strategy == NULL)
     strategy = read_mini("New Dict strategy:", Dict_Strat, "");
   Dict_Strat = extract_element(strtrim(strategy), 0, ' ');
   vmessage("Dict_Strat set to '%s'", Dict_Strat);
}

% this function is called by pressing "Return" in the buffer opened by
% select_strategy()
private define select_strategy_return_hook()
{
   variable strat = line_as_string();
   close_buffer();
   set_strategy(strat);
}

% Show a list of strategies and let the user select one (or several)
define select_strategy()
{
   show("strat");
   
   % Formatting 
   set_readonly(0);
   bob(); 
   if (ffind("available"))
     delete_line();  % chop first line
   insert(".  Server default\n");
   ()=bol_fsearch(Dict_Strat);
#ifexists listing_mode
   listing_mode();
#else
   view_mode();
#endif
   set_buffer_hook("newline_indent_hook", &select_strategy_return_hook);
   message("Select strategy, press [Return] to apply");
}

  
% Dict mode
% =========

static define dict_status_line()
{
   variable generator = get_blocal("generating_function");
   variable str = sprintf(" %s  %s [%s]", whatbuf(), generator[1], generator[2]);
   set_status_line(str + " (%p)", 0);
}

% Keybindings
% -----------

!if (keymap_p(mode))
  copy_keymap(mode, "view");

definekey(mode+"->next_link",              "\t", mode);
definekey(mode+"->previous_link", Key_Shift_Tab,  mode);
definekey("dict",                          "d",  mode); % definition lookup
definekey(mode+"->select_database",        "D",  mode);
definekey("close_and_insert_word",         "i",  mode);
definekey(mode+"->match",		   "m",  mode);
definekey(mode+"->select_strategy",        "M",  mode);
definekey("close_and_replace_word",        "r",  mode);
definekey(mode+"->set_server",	   "S",  mode);
definekey("thesaurus",             	   "t",  mode);
definekey("dict(, Dict_Translation_DB)",   "u",  mode); % uebersetzen
definekey(mode+"->reverse_lookup",         "v",  mode);
#ifexists create_circ
definekey(mode+"->next_lookup",            ".",  mode); % "non-shift >" (dillo-like)
definekey(mode+"->previous_lookup",        ",",  mode); % "non-shift <" (dillo-like)
#endif
definekey("dict_lookup",   		   "\r", mode); % Return

set_help_message(
"D)efinition lookup  I)nsert  R)eplace  T)hesaurus [RET]:follow up  Alt-O: menu"
   , mode);

% Menu
% ----

public define dict_menu_callback(menu)
{
   % Lookups
   menu_append_item(menu, "&definition lookup", "dict");
   menu_append_item(menu, "&Match", mode+"->match");
   menu_append_item(menu, "&Thesaurus", "thesaurus");
   menu_append_item(menu, "Translate (&Uebersetzen)", "dict(, Dict_Translation_DB)");
   % Settings
   menu_append_separator(menu);
   menu_append_item(menu, "Set &Database", mode+"->select_database");
   menu_append_item(menu, "Strateg&y", mode+"->select_strategy");
   menu_append_item(menu, "Set &Server", mode+"->set_server");
}

static define mode_menu(menu)
{
   dict_menu_callback(menu);
   % Navigation
   menu_append_separator(menu);
#ifexists create_circ
   menu_append_item(menu, "Lookup Current Word", "dict_lookup");
   menu_append_item(menu, "Re&verse Lookup", mode+"->reverse_lookup");
   menu_append_item(menu, "&> Next Lookup", mode+"->next_lookup");
   menu_append_item(menu, "&< Previous Lookup", mode+"->previous_lookup");
#endif
   menu_append_item(menu, "&Insert", "close_and_insert_word");
   menu_append_item(menu, "&Replace", "close_and_replace_word");
   menu_append_item(menu, "&Quit", "close_buffer");
}

% Syntax tables
% -------------

% definitions
create_syntax_table(mode);
define_syntax(get_word_chars, 'w', mode); % Words
define_syntax("[]<>", ',', mode);	  % Delimiter
define_syntax('F', '#', mode);      	  % Headers (preprocess)
define_syntax("{", "}", '%', mode); 	  % Links (comments, enables parse_to_point())
% Strings (enables parse_to_point()), doesnot work with [gcide]
% define_syntax('"', '"', mode);	  
set_syntax_flags(mode, 0x20);

%!%+
%\function{dict_mode}
%\synopsis{Mode for Dict lookup results}
%\usage{dict_mode()}
%\description
%  A mode for results of a dictionary lookup according to RFC2229 as e.g. done
%  by \sfun{dict} and \sfun{thesaurus}.
%  
%  Provides a Mode menu, syntax highlight, navigation and command history.
%  
%  For keybindings, have a look at the Mode menu (Alt-O) or use
%  Help>Describe_Keybindings (or M-x describe_bindings).
%  
%  Customization can be done defining a \sfun{dict_mode_hook}.
%\seealso{dict, thesaurus, dict_lookup}
%!%-
define dict_mode()
{
   set_mode(mode, 0);
   set_readonly(1);
   set_buffer_modified_flag(0);
   use_keymap (mode);
   use_syntax_table(mode);
   mode_set_mode_info (mode, "init_mode_menu", &mode_menu);
   set_buffer_hook ("mouse_2click", &double_click_hook);
   dict_status_line();
   run_mode_hooks(mode + "_mode_hook");
   help_message();
}

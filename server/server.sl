% server.sl
% Run JED as editing server
% 
% $Id: server.sl,v 1.1.1.1 2004/10/28 08:16:25 milde Exp $
% Keywords: processes, mail, Emacs
% 
% Copyright (c) 2003, 2004 Paul Boekholt
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This mode should work with the Emacs tools emacsclient and emacsserver.
% Emacsserver is a subprocess listening to a socket. Emacsclient sends a
% request to the socket and then waits for the server to say "done".
% See § 2.1 of the Mail-User-HOWTO.
% 
% Add the following lines to .jedrc:
% require ("server");
% server_start();
% setkey("server_done", "#");
% If you just want to edit emails add
% define server_visit_hook()
% {
%    mail_mode();
%    local_setkey("server_done", "^C^C");
% }
% or, if you're in the console,
%    local_setkey(". server_done suspend", "^C^C");
% then edit .muttrc
% set editor="emacsclient %s || jed %s"
% Start JED in another console/window or in the background, start
% Mutt, press m, and bring JED back to the foreground. 
% When you're done editing, press C-x # and switch back to Mutt.
% 
% To use this with cbrowser, choose Options>Editor>Other and add an
% emacsclient entry: emacsclient +%d %s
% 
% To use with ddd: Edit>preferences>helpers>Edit Sources:
% emacsclient +@LINE@ @FILE@ || xjed +@LINE@ @FILE@ 
% 
% caveats:
% -Never kill a server buffer, or you will have to kill the server and
%  restart manually (just kill the " *server*" buffer and type M-x
%  server_start). JED seems to lack a kill_buffer_hook to deal with this.
% -Never open the same file from two emacsclients, or JED will forget to
%  notify the first client when finished.
% -Don't try to open two files from one emacsclient.
% -Beware...
% 
% You can do something like this with the rjed patch to JED, but that's
% still at 0.99-15, and this mode lets you use Emacs or JED, whichever 
% happens to be running.

require("keydefs");
autoload("string_nth_match", "strutils");
custom_variable ("Server_Pgm", "/usr/share/emacs/lib/emacsserver");

static variable server_process = -1, server_input,
  sbuf = " *server*";


% Execute an emacsclient request. Emacsserver output looks like
% Client: number [-nowait] {[+line[:column]] file} ...
% I can deal with lines and columns, but not with multiple files.
static define server_parse_output (pid, output)
{
   variable pattern = "^Client: \\([0-9]+\\) \\([ +:0-9]*\\)\\([^ ]+\\) *$",
   substring, subpattern = "+\\([0-9]+\\):?\\([0-9]*\\)";
   if (orelse {string_match(output, pattern, 1)}
	 {pattern = "^Client: \\([0-9]+\\) -nowait \\([ +:0-9]*\\)\\([^ ]+\\) *$",
	      string_match(output, pattern, 1)})
     {
	substring = string_nth_match(output, 2);
	% A find_file_hook may call string_match(), so after find_file()
	% we can't use string_nth_match()
	variable client = string_nth_match(output, 1);
	() = find_file(string_nth_match (output, 3));
	define_blocal_var("client", client);
	if (string_match(substring, subpattern, 1))
	  {
	     goto_line(integer(string_nth_match (substring, 1)));
	     () = goto_column_best_try(integer(string_nth_match (substring, 2)));
	  }
	runhooks("server_visit_hook");
     }
   else message(output);
   update(0);
   if (_Jed_Emulation == "emacs") "";
   else Key_Home;
   buffer_keystring();
   % The first keyboard command will go into the buffer this replaced. 
   % Maybe a bug in JED? So I give it a ^L in emacs emulation or a Home
   % in another emulation.
 }

% Tell the emacsclient I'm finished
%!%+
%\function{server_done}
%\synopsis{Tell the emacsclient to return}
%\usage{ server_done()}
%\description
%   This saves a server buffer, and tells the emacslient to return.
%\seealso{server_start}
%!%-
public define server_done()
{
   if (blocal_var_exists("client"))
     {
	save_buffer;
	send_process(server_process, sprintf("Close: %s Done\n", get_blocal_var("client")));
	delbuf(whatbuf);
	runhooks("server_done_hook");
     }
   else
     message ("not a server buffer!");
}

% Start the server. Why restarting doesn't work?
%!%+
%!%f
%\function{server_start}
%\synopsis{start an emacsserver subprocess}
%\usage{ server_start()}
%\description
%  Allow this JED process to be a server for client processes. This
%  starts a server communications subprocess through which client
%  "editors" can send your editing commands to this JED. To use the
%  server, set up the program \var{emacsclient} in the \var{Emacs} distribution as
%  your standard "editor".
%\example
%  In .muttrc:
%#v+
% set editor="emacsclient %s || jed %s"  
%#v-
%  when you edit a message, Mutt will give control to emacsclient, you'll
%  see
%#v+
%  "waiting for Emacs..."
%#v-
%  now suspend Mutt/emacsclient, and bring JED to the foregeround. Edit
%  your message and call \var{server_done} when finished. Bring Mutt back to
%  the foreground, emacsclient will return and you should be back in Mutt.
%\notes
%   Don't kill a server buffer, use \var{server_done}. If you do kill the
%   server buffer, you must interrupt the emacsclient process or it will wait
%   forever.
%\seealso{server_done}
%!%-
public define server_start()
{
   variable buf = whatbuf;
   setbuf(sbuf);
   server_process = open_process (Server_Pgm, 0);
   set_process (server_process, "output", &server_parse_output);
   process_query_at_exit(server_process, 0);
   setbuf(buf);
}

provide ("server");


% server.sl
% Run JED as editing server
% 
% $Id: server.sl,v 1.5 2006/09/30 07:48:48 paul Exp paul $
% Keywords: processes, mail, Emacs
% 
% Copyright (c) 2003-2006 Paul Boekholt
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This mode should work with the Emacs tools emacsclient and emacsserver.
% Emacsserver is a subprocess listening to a socket. Emacsclient sends a
% request to the socket and then waits for the server to say "done".
% See § 2.1 of the Mail-User-HOWTO.
% 
% To install add the following lines to .jedrc:  
% variable Server_Pgm="/path/to/emacsserver";
% require ("server");
% server_start();
% setkey("server_done", "^X#");
% 
% caveats:
% -Never open the same file from two emacsclients, or JED will forget to
%  notify the first client when finished.
% -Don't try to open two files from one emacsclient.


provide("server");
require("pcre");
implements("server");
custom_variable ("Server_Pgm", "/usr/share/emacs/lib/emacsserver");
static variable server_process = -1, server_input;

variable pattern = "^Client: ([0-9]+) (?:-nowait )?(?:\\+([0-9]+)(?::([0-9]+))?)? *([^ ]+) *$";
variable cpattern = pcre_compile(pattern);

% This emulates a kill_buffer_after_hook
try
{
   typedef struct { client } Client_Type;
}
catch DuplicateDefinitionError;

define destroy_client(Client)
{
   send_process(server_process, sprintf("Close: %s Done\n", Client.client));
}

__add_destroy(Client_Type, &destroy_client);

% This is needed because it's not possible to switch buffers in a subprocess
% output handler.
variable client_buf;
define before_key_hook();
define before_key_hook(fun)
{
   remove_from_hook ("_jed_before_key_hooks", &before_key_hook);
   sw2buf(client_buf);
}

% Execute an emacsclient request. Emacsserver output looks like
% Client: number [-nowait] {[+line[:column]] file} ...
% I can deal with lines and columns, but not with multiple files.
define server_parse_output (pid, output)
{
   !if(pcre_exec(cpattern, output))
     throw RunTimeError, "I don't understand that";
   variable buf = whatbuf();
   () = find_file(pcre_nth_substr(cpattern, output, 4));
   variable Client = @Client_Type;
   Client.client = pcre_nth_substr(cpattern, output, 1);
   define_blocal_var("client", Client);
   if (pcre_nth_match(cpattern, 2) != NULL)
     goto_line(atoi(pcre_nth_substr(cpattern, output, 2)));
   if (pcre_nth_match(cpattern, 3) != NULL)
     ()=goto_column_best_try(atoi(pcre_nth_substr(cpattern, output, 3)));
   runhooks("server_visit_hook");
   client_buf=whatbuf();
   variable client_keymap=what_keymap();
   update(1);
   setbuf(buf);
   % Set the client buffer's keymap in the " *server*" buffer.
   % The first keyboard command will be interpreted there.
   use_keymap(client_keymap);
   add_to_hook ("_jed_before_key_hooks", &before_key_hook);
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
	delbuf(whatbuf);
     }
   else
     message ("not a server buffer!");
}

%!%+
%\function{server_start}
%\synopsis{start an emacsserver subprocess}
%\usage{ server_start()}
%\description
%  Allow this JED process to be a server for client processes.  This starts
%  a server communications subprocess through which client "editors" can
%  send your editing commands to this JED. To use the server, set up the
%  program \var{emacsclient} in the \var{Emacs} distribution as your standard
%  "editor".
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
%  now suspend Mutt/emacsclient, and bring JED to the foregeround.  Edit your
%  message and call \var{server_done} when finished.  Bring Mutt back to the
%  foreground, emacsclient will return and you should be back in Mutt.
%\seealso{server_done}
%!%-
public define server_start()
{
   variable buf = whatbuf;
   setbuf(" *server*");
   server_process = open_process (Server_Pgm, 0);
   set_process (server_process, "output", &server_parse_output);
   process_query_at_exit(server_process, 0);
   setbuf(buf);
   flush("done");
}

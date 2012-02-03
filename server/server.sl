% server.sl
% Run JED as editing server
% 
% $Id: server.sl,v 1.6 2012/02/03 17:06:03 paul Exp $
% 
% Copyright (c) 2003-2012 Paul Boekholt
% Released under the terms of the GNU GPL (version 2 or later).
% 
% Use JED as an editing server.  This should be used with Emacs'
% emacsclient program.
% 
% To install add the following lines to .jedrc:  
% require ("server");
% server_start();
% setkey("server_done", "^X#");
% 
% caveats:
% -Never open the same file from two emacsclients, or JED will forget to
%  notify the first client when finished.
% -Don't try to open two files from one emacsclient.

#ifnexists _jed_version
% slsh replacement for the emacsserver program, which is no longer
% in Emacs. This is based on Emacs' emacsserver.c and server.el.

require("select");
require("socket");
require("custom");

custom_variable("server_name", "server");
custom_variable("server_socket_dir", sprintf("/tmp/emacs%d", geteuid()));

variable socket_filename=path_concat(server_socket_dir, server_name);
if (-1 == remove(socket_filename) && errno != ENOENT) 
{
   throw RunTimeError, errno_string(errno);
}

private define ensure_safe_dir(dir)
{
   % Try to make the server_socket_dir and ensure it's safe
   % This will not make parent dirs
   variable st;
   if (-1 == mkdir(dir, 0700) && errno != EEXIST)
     {
	throw RunTimeError, errno_string(errno);
     }
   st = stat_file(dir);
   if (st == NULL) throw IOError, "unable to stat socket dir";
   ifnot (stat_is("dir", st.st_mode)) throw RunTimeError, "socket dir is not a directory";
   if (st.st_uid != geteuid() || st.st_mode & (S_IRWXG | S_IRWXO))
     {
	throw RunTimeError, "socket dir is not safe";
     }
}

ensure_safe_dir(server_socket_dir);

variable s = socket(PF_UNIX, SOCK_STREAM, 0);
bind(s, socket_filename);
listen(s, 5);

variable openfiles = {};
define handle_input(iread)
{
   variable fd, line, code, infd, command, of, i, infile, fno;
   foreach fd (iread)
     {
	if (fd == 0)
	  {
	     ()=fgets(&line, stdin);
	     if (3 != sscanf(line, "%s %d %[^\n]", &code, &infd, &command)) throw RunTimeError, "could not parse server output";
	     i = 0;
	     foreach of (openfiles)
	       {
		  if (of.fno == infd)
		    {
		       ()=fputs(command + "\n", of.file);
		       ifnot (strncmp (code, "Close:", 6)) 
			 {
			    list_delete(openfiles, i);
			 }
		       break;
		    }
		  i++;
	       }
	  }
	else
	  {
	     % client sends list of filenames
	     infd = accept(s);
	     fno = _fileno(infd);
	     infile = fdopen(infd, "r+");
	     list_append(openfiles, struct { fno = fno, file = infile, fd = infd } );
	     ()=fgets(&line, infile);
	     ()=printf("Client: %d %s\n", _fileno(infd), line);
	  }
     }
}

variable ss;
variable in_fd=fileno(stdin);
if (in_fd == NULL) throw IOError, "could not find descriptor for stdin";

forever
{
   ss=select([in_fd, s], NULL, NULL, -1);
   switch(ss.nready)
     {
      case 0 or case -1: throw IOError;
     }
     {
	handle_input(ss.iread);
     }
}
#else
provide("server");
require("datutils", "utils");
private variable server_process = -1;

private define destroy_client(Client)
{
   send_process(server_process, sprintf("Close: %s Done\n", Client.client));
}

% Execute an emacsclient request. Emacsserver output looks like
% Client: number -dir dir {[-position +line[:column]] -file file} ...
% I can deal with lines and columns, but not with multiple files.
private define server_parse_output (pid, output)
{
   variable arg, l = utils->array2list(strchop(output, ' ', 0));
   variable dir=NULL, file=NULL, client=NULL, line=NULL, column=NULL;
   while(length(l))
     {
	arg = list_pop(l);
	switch(arg)
	  {
	   case "-dir": dir = list_pop(l);
	  }
	  {
	   case "-file": file = list_pop(l);
	  }
	  {
	   case "Client:": client = list_pop(l);
	  }
	  {
	   case "-position":
	     arg = list_pop(l);
	     ()=sscanf(arg, "+%d:%d", &line, &column);
	  }
     }
   if (dir == NULL or file == NULL or client == NULL) return;
   ()=find_file(path_concat(dir, file));
   variable Client = struct { client = client };
   __add_destroy(Client, &destroy_client);
   define_blocal_var("client", Client);
   if (line != NULL) goto_line(line);
   if (column != NULL) ()=goto_column_best_try(column);
   runhooks("server_visit_hook");
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
	save_buffer();
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
%\seealso{server_done}
%!%-
public define server_start()
{
   setbuf(" *server*");
   server_process = open_process ("slsh", __FILE__, 1);
   set_process (server_process, "output", &server_parse_output);
   set_process_flags(server_process, 0x01);
   process_query_at_exit(server_process, 0);
   flush("done");
}
#endif

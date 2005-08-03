% --------------------------------------------------------------- -*- SLang -*-
%
% SCRNHELP
%
%  Copyright (c) 2001 Francesc Rocher
%  Released under the terms of the GNU General Public License (ver. 2 or later)
%
% $Id: scrnhelp.sl,v 1.4 2001/01/14 08:15:43 rocher Exp $
%
% -----------------------------------------------------------------------------
%
% DESCRIPTION
%	This file contains a couple of functions to show/hide a help buffer
%	associated to a JED mode.
%
% USAGE
%	From some JED mode, autoload these functions and call them from some
%	particular functions. 'scrnhelp' function will show the help file
%	associated to that mode. It must be invoked as follows:
%
%		scrnhelp ("*myMode*", "*myMode help*", "mymode.hlp", 10);
%
%	where "*myMode*" is the name of the JED mode, "*myMode help*" is the
%	name of the help buffer, "mymode.hlp" is the filename containing some
%	help and '10' is the number of lines of such file. To hide the help
%	buffer, simply call
%
%		scrnhelp_quit ("*myMode help*");
%
%	NOTE: The last line of the help file should not end with '\n'.
%
% AUTHOR
%	Francesc Rocher <f.rocher@computer.org>
%	Feel free to send comments, suggestions or improvements.
%
% -----------------------------------------------------------------------------

define scrnhelp_quit (hbuf)
{
   pop2buf (hbuf);
   delbuf (hbuf);
   otherwindow ();
   onewindow ();
}

define scrnhelp (cbuf, hbuf, file, lines)
{
   % Shows a help screen.
   %
   % Parameters:
   %       cbuf: name of the 'calling' buffer
   %       hbuf: name of the 'help' buffer
   %       file: filename to insert into the help buffer
   %      lines: number of lines of the help file
   
   variable rows;

   !if (bufferp (hbuf))
     {
        setbuf (hbuf);
        set_readonly (0);
        () = insert_file (expand_jedlib_file (file));
        set_readonly (1);
        set_buffer_modified_flag (0);
     }
   else
     {
        scrnhelp_quit (hbuf);
        return;
     }

   !if (buffer_visible (hbuf))
     {
        onewindow ();
        pop2buf (hbuf);
        bob ();
        rows = window_info ('r') - lines;
        pop2buf (cbuf);
        loop (rows) enlargewin ();
     }
}

% vispell.sl
% 
% Author:        Paul Boekholt
%
% $Id: vispell.sl,v 1.8 2006/01/15 17:43:11 paul Exp paul $
% 
% Copyright (c) 2003-2006 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This file provides a full-screen interface to ispell, like in joe or vi.
% Thanks to Romano Giannetti and John Davis.
autoload ("vrun_program_fg", "runpgm");
provide ("vispell");
require("ispell_common");
use_namespace("ispell");

public define vispell()
{

   variable cmd, tmp = "/tmp/jedispell", mode, mask;
   cmd = ispell_command;
   (mode,) = what_mode();

   % set the format depending on the mode (troff/TeX/html)
   switch (mode)
     { case "TeX" or case "LaTeX" : cmd += " -t";}
     { case  "nroff": cmd += " -n";}
     { case "html" or case "sgml" : cmd += " -h";}
   if(Ispell_Program_Name == "aspell") cmd += " check";
   tmp = make_tmp_file(tmp);
   !if (is_visible_mark)
     mark_buffer();
   () = dupmark;
   mask = umask(0x600);
   ERROR_BLOCK 
     {
	() = umask(mask);
     }
   () = write_region_to_file(tmp);
   EXECUTE_ERROR_BLOCK;
   sleep(2);
   cmd = strcat (cmd, " ", tmp);
   if (is_defined("x_server_vendor"))
     {
	system (strcat ("rxvt -e ", cmd));
	0; % how do I get the return status of a program running in an xterm?
     }
   else
     run_program (cmd);
   !if ()
     {
	del_region();
	() = insert_file(tmp);
     }
   else 
     {
	message("ispell failed to run");
	pop_mark_0;
     }
    () = delete_file(tmp);
   call("redraw");
}


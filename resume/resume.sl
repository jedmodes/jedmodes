% resume.sl
% 
% Author:        Paul Boekholt <p.boekholt@hetnet.nl>
% 
% $Id: resume.sl,v 1.1.1.1 2004/10/28 08:16:25 milde Exp $
% 
% Helper for opening files in JED from the shell prompt.  Add this to 
% your .bashrc
% function edit()
% {
%   if jobs %jed 2> /dev/null ; then
%      echo "$(pwd)/$@" >| ${JED_HOME}/.jed_args && fg %jed
%   else
%      jed "$@"
%   fi
% }
% and require("resume") to .jedrc.
% Log out and in again.  Start a JED, suspend it and say "edit resume.sl" 
% at the shell.  If you did this right, JED should now be fg'ed with 
% resume.sl opened.

autoload("strread_file", "bufutils");
custom_variable("resume_jed_file", dircat (Jed_Home_Directory, ".jed_args"));

static define resume_process_args()
{
   variable args = strread_file(resume_jed_file);
   foreach (strtok (args))
     () = find_file();
}

static define resume_suspend_hook ()
{
   ()=find_file(resume_jed_file);
   erase_buffer;
   save_buffer;
   delbuf(whatbuf);
   flush("");
   1;
}

add_to_hook("_jed_resume_hooks", &resume_process_args);
add_to_hook("_jed_suspend_hooks", &resume_suspend_hook);
provide ("resume");

% 1.6   20004-11-30
%     * added new optional argument "postfile_args" to shell_cmd_on_region
% 1.6   20004-11-30
%     * added new optional argument "postfile_args" to shell_cmd_on_region
% jedmodes.sl
% Utilities for the publication of modes at Jedmodes
% 
% Keywords: tools
% Authors: Günter Milde, Paul Boekholt
% 
% Contains a script for generating a JMR dcdata file from a template, with
% some information extracted from your S-Lang source, a function to upload
% files with scp and  new-mode and new-version wizards.
% 
% Copy the dcdata.txt template to Jed_Home.
% You should make a directory structure in your Jed_Home_Directory
% that shadows your JMR directories.
% 
% Example illustrating the use with cal.sl: (This is how I, Paul Boekholt
% do it)
% 
% Jed-Home
%   |--mode-index.php
%   |
%   `--jedmodes
%      |
%      |--cal/
%      |   |--dcdata.txt
%      |   |--index.php -> ../../mode-index.php
%      |--bufed/
%      |
%      ...
%      
% The script creates the cal directory, the dcdata.txt, and the index.php
% symlink.  Simply open cal.sl in JED and type M-x make_dcdata_file.  The
% dcdata.txt file will pop up, edit it as necessary and save.
% 
% As an example, here is what the generated dcdata file for this script
% looks like for me:
% 
% # See also http://jedmodes.sf.net/doc/DC-Metadata/dcmi-terms-for-jedmodes.txt
% # Compulsory Terms
% title:            jedmodes
% abstract:         Script for creating dcdata
% creator: 	    Boekholt, Paul
% description:
% subject:          tools.slang
% requires: 	    templates
% rights: Copyright (c) 2003 Paul Boekholt
%  Released under the terms of the GNU General Public License (v. 2 or later)
% # Terms with auto-guesses at Jedmodes
% .....
% 
% Notes: 
% 
% - though this mode has two authors, only Paul Boekholt is in the
%   'creator' field.  This is because this field is not guessed from the
%   slang source - it comes from the get_username() function.
% 
% - neither is the description or the version - in fact there's no need for
%   specifying the version, it's implicit in the cal/1.12 directory name
% 
% You can use the jedmodes_upload() and jedmodes_new_version()
% functions to upload the mode from within JED.
%  
% Or you create the 1.12/ subdirectory and copy cal.sl (or
% cal.tgz) there.  Repeat the process for any other modes you
% wish to create or update.  Then leave JED, chdir to Jed_Home and do
% 
% $> tar -czvf modes.tgz `find . -cnewer modes.tgz`
% $> scp modes.tgz boekholt@ssh.sf.net://home/groups/j/je/jedmodes/htdocs/mode
% $> ssh ssh.sf.net
% 
% sf> cd /home/groups/j/je/jedmodes/htdocs/mode
% sf> tar -xzvf modes.tgz.
% 
% sf> exit 

% This script requires the JMR templates mode.
require("templates");

% _debug_info = 1;

% --- Variables ---

% the directory where you shadow your JMR directories. Has to be
% called "jedmodes" - leave as is.
custom_variable("Jedmodes_Dir", dircat(Jed_Home_Directory, "jedmodes"));

custom_variable("Jedmodes_CVS_Root", 
   dircat(Jed_Home_Directory, "jedmodes/src/mode/"));

% the line no where you usually write a summary of what the mode does.
% In this script, it's on line two.
custom_variable("Jedmodes_Abstract_Line_No", 2);

% if you use the dabbrev from jedmodes, you may want to set
public variable Dabbrev_Default_Buflist=1; 
% to have dabbrev() expand from all visible buffers

% --- Functions ---

% Fill in requirements. This is not smart enough to skip requirements
% that may be in the standard library.
define get_requires()
{
   variable pattern, requirement, requirements = Assoc_Type[Int_Type];
   push_spot_bob();
   foreach (["^require ?(\"\\([^)]+\\)\");", 
	     "^autoload ?(\"[^\"]+\" ?, ?\"\\([^)]+\\)\");"])
     {
	pattern = ();
	while (re_fsearch(pattern))
	  {
	     requirement = path_basename(regexp_nth_match(1));
	     !if (file_status(path_concat(
		path_concat(JED_ROOT, "lib"), requirement + ".sl")))
	       % use assoc to throw out doublettes
	       requirements[requirement] = 1;
	     go_right_1();
	  }
	bob;
     }
   pop_spot();
   return strjoin(assoc_get_keys(requirements), "; ");
}

static define dc_parsep()
{
   bol;
   ffind_char(':');
}

% insert the dcdata template and do additional replacements
autoload("insert_template", "templates");
public define insert_dcdata()
{
   variable dc_replacements = Assoc_Type[String_Type];
   dc_replacements["<TITLE>"] = path_sans_extname(whatbuf());
   dc_replacements["<REQUIRES>"] = get_requires();
   bob();
   push_visible_mark();
   insert_template("mode.dcdata");
   narrow_to_region();
   bob;
   foreach(dc_replacements) using ("keys", "values")
     replace();
   widen();
}

public define make_dcdata_file()
{ 
   variable dcdata_template = dircat(Templates_Dir, "dcdata.txt");
   if (file_status(dcdata_template) != 1)
     dcdata_template = dircat(Jedmodes_Dir, "../doc/mode-template/dcdata.txt");
   variable dc_replacements = Assoc_Type[String_Type];
   dc_replacements["<TITLE>"] = path_sans_extname(whatbuf());
   dc_replacements["<REQUIRES>"] = get_requires();
   dc_replacements["<SUBJECT>"]="";
   bob;
   if (bol_fsearch("% Keywords:"))
     {
	()=ffind(":");
	go_right_1;
	skip_white;
	push_mark_eol;
	bufsubstr;
	()=strreplace(",",";",100);
	dc_replacements["<SUBJECT>"]=();
     }
   
   bob;
   go_down(Jedmodes_Abstract_Line_No-1);
   dc_replacements["<ABSTRACT>"] = strtrim(get_line(), "% \t");
   variable this_dc_dir = dircat(Jedmodes_Dir, dc_replacements["<TITLE>"]);
   mkdir (this_dc_dir, 0755);   % make it world searchable
   chdir (this_dc_dir);
   write_string_to_file("<?php\n" +
      "// Index file for mode directories, reads mode-index.php with mode argument\n" +
      "$jedmodes_root = dirname(dirname(dirname(__FILE__)));\n" +
      "$title = basename(dirname(__FILE__));\n"+
      "include(\"$jedmodes_root/mode-index.php\");\n?>\n", "index.php");
   % system("ln -s ../../mode-index.php index.php");
   % make the file world readable
   chmod("index.php", 0644);

   read_file(dircat (this_dc_dir, "dcdata.txt"));
   pop2buf("dcdata.txt");
   insert_template_file(dcdata_template);
   bob;
   foreach(dc_replacements) using ("keys", "values")
     replace();
   set_buffer_hook("par_sep", &dc_parsep);
 }

% upload a file from the private jedmodes mirror to sourceforge
public define jedmodes_upload()
{
   variable from = buffer_filename(), 
   to = "jedmodes.sf.net:/home/groups/j/je/jedmodes/"
     + path_dirname(from[[is_substr(from, "jedmodes")+8:]]);
   save_buffer();
   ishell();
   eob;
   vinsert("\n\n#upload to jedmodes\nscp -p %s %s", from, to);
}

% upload a new mode version from the personal library
public define jedmodes_new_version()
{
   variable buf = whatbuf(),
   mode_dir = dircat(Jedmodes_CVS_Root,
      read_mini("Mode Sources Directory", path_sans_extname(buf), "")),
   to = "jedmodes.sf.net:/home/groups/j/je/jedmodes/"
     + (mode_dir[[is_substr(mode_dir, "jedmodes")+8:]]);

   % copy to the jedmodes mirror first
   % set the umask to 0, so we can have searchable dirs
   variable old_umask = umask(0);
   !if(file_status(mode_dir))
     () = mkdir(mode_dir, 0755);  % world searchable
   () = umask(old_umask);
   % save to version directory (ask for overwrite)
   buffer_keystring(mode_dir + " ");
   save_buffer_as();
   % unfortunately, here save_buffer_as leaves the file only user-readable
   chmod(buffer_filename(), 0644);
   % chdir(mode_dir);
   
   % prepare the upload via ishell
   ishell();
   eob;
   % insert("\n\n#upload the mode sources\ncd " + mode_dir);
   % % upload with scp
   % vinsert("\nscp -pr %s %s", buf, to);
   % cvs update
   insert("\n\n#commit to cvs");
   vinsert("\n\ncd %s", path_dirname(mode_dir));
   variable comment = read_mini("CVS Comment:", "", "");
   vinsert("\ncvs commit -m '%s' %s", comment, path_basename(mode_dir));
   go_up_1();
}

% Add a new mode from the personal library
% Best called from the open buffer of the new mode
public define jedmodes_new_mode()
{
   % Description file dcdata.txt
   variable buf = whatbuf();
   variable mode_dir = dircat(Jedmodes_Dir,
      read_mini("Mode Home Directory", path_sans_extname(whatbuf()), "")),
   to = "jedmodes.sf.net:/home/groups/j/je/jedmodes/"
     + (mode_dir[[is_substr(mode_dir, "jedmodes")+8:]]);

   % create dcdata.txt file in the jedmodes mirror
   % set the umask to 0, so we can have searchable dirs
   variable old_umask = umask(0);
   !if(file_status(mode_dir))
     () = mkdir(mode_dir, 0755);  % world searchable
   () = umask(old_umask);
   make_dcdata_file();
   save_buffer_as();
   % unfortunately, here save_buffer_as leaves the file only user-readable
   chmod(dircat(mode_dir, "dcdata.txt"), 0644);

   % prepare the upload via ishell
   ishell();
   eob;
   insert("\n\n#upload the mode description\ncd " + mode_dir);
   vinsert("\nscp -pr %s %s", ".", to);
   sw2buf(buf);
   jedmodes_new_version();
   vinsert("\n\n#commit to cvs \n\ncd %s", path_dirname(mode_dir));
   vinsert("\ncvs add %s %s", path_basename(mode_dir), path_concat(path_basename(mode_dir), buf));
   variable comment = read_mini("CVS Comment:", "", "");
   vinsert("\ncvs commit -m '%s' %s", comment, path_basename(mode_dir));
   sw2buf("dcdata.txt");
}

_add_completion("make_dcdata_file", "jedmodes_upload", 
   "jedmodes_new_version", "jedmodes_new_mode", 4);

provide("jedmodes");

% tracker.sl -*- mode: slang; mode: fold; eval: tracker_start("tracker") -*-
%
% Author:        Paul Boekholt <p.boekholt@hetnet.nl>
% 
% $Id: tracker.sl,v 1.1.1.1 2004/10/28 08:16:26 milde Exp $
% 
% A time tracker.  Install:
% autoload("tracker_start", "tracker");
% autoload("tracker_view", "tracker");
% 
% static define tracker_load_popup_hook (menubar)
% {
%    variable menu = "Global.S&ystem";
%    menu_append_popup(menu, "&Tracker");
%    menu = "Global.S&ystem.&Tracker";
%    menu_append_item(menu, "&Start", "tracker_start");
%    menu_append_item(menu, "s&Top", "tracker_stop");
%    menu_append_item(menu, "&View", "tracker_view");
% }
% 
% append_to_hook ("load_popup_hooks", &tracker_load_popup_hook);
% 
% To remove a project you have to edit the trackerfile before evaluating
% this file.
% To track automatically when editing a file, add something like 
% eval: tracker_start("tracker")
% to the modeline.

variable projects = Assoc_Type[Integer_Type, 0];

variable tracker_on = 0, project, trackerbuf="*tracker*",
  trackerfile=dircat(Jed_Home_Directory, "tracker");

static variable old_status_line = Status_Line_String;

%{{{ static functions

static define tracker_load()
{
   variable p, th, tm, line;
   setbuf (trackerbuf);
   erase_buffer;
   () = insert_file (trackerfile);
   bob;
   while (not eolp)
     {
	line = strchop(line_as_string, '\t', 0);
	() = sscanf(line[-1], "%d:%d", &th, &tm);
	p = strjoin(line[[:-2]], "\t");
	message(p);
	go_down_1;
	bol;
	projects[p] = 60 * th + tm;
     }
   set_buffer_modified_flag(0);
   delbuf(trackerbuf);
}

static define tracker_update()
{
   if (tracker_on)
     {
	projects[project] += (_time() - tracker_on) / 60;
     }
}

static define tracker_update_buffer()
{
   variable key, value;
   setbuf (trackerbuf);
   erase_buffer;
   tracker_update;
   foreach (projects) using ("keys", "values")
    {
       (key, value) = ();
       vinsert ("%s\t%d:%02d\n", key, value / 60, value mod 60);
    }
}

static define tracker_save()
{
   tracker_update_buffer();
   () = write_buffer(trackerfile);
   1;
}

%}}}

%{{{ public functions

public define tracker_stop()
{
   tracker_update();
   tracker_on = 0;
   set_status_line(old_status_line, 1);
}

public define tracker_start() % (project)
{
   tracker_update;
   if (_NARGS) project = ();
   else
     project = read_with_completion
     (strjoin(assoc_get_keys(projects), ","), "project", "", "", 's');
   tracker_on = _time();
   set_status_line(strcat (old_status_line, " ", project), 1); 
}

public define tracker_view()
{
   tracker_update_buffer();
   TAB=20;
   pop2buf (trackerbuf);
}


%}}}

add_to_hook("_jed_exit_hooks", &tracker_save);
tracker_load();

provide ("tracker");

% zip.sl
% 
% $Id: zip.sl,v 1.2 2008/10/25 11:23:58 paul Exp paul $
% 
% Copyright (c) 2008 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This is a mode for browsing zip archives similar to dired or filelist.
% Requirements:
% the Ruby module (http://www.cheesit.com/downloads/slang/slruby.html)
% the RubyZip library (http://rubyzip.sourceforge.net)

#<INITIALIZATION>
autoload("zip", "zip");
define zip_find_file_hook(filename)
{
   if (path_extname(filename) == ".zip")
     {
	zip(filename);
	return 1;
     }
   return 0;
}
append_to_hook("_jed_find_file_before_hooks", &zip_find_file_hook);
#</INITIALIZATION>
require("slruby");
require("listing");
private variable mode="zip";
rb_load_file(dircat(path_dirname(__FILE__), "jedzip.rb"));
private variable Zip = rb_eval("Zip::Jed");

custom_variable("FileList_KeyBindings", "mc");

%{{{ set the member's mode
private define set_mode_from_extension (ext)
{
   variable n, mode;
   if (@Mode_Hook_Pointer(ext)) return;
   
   n = is_list_element (Mode_List_Exts, ext, ',');

   if (n)
     {
	n--;
	mode = extract_element (Mode_List_Modes, n, ',') + "_mode";
	if (is_defined(mode) > 0)
	  {
	     eval (mode);
	     return;
	  }
     }

   mode = strcat (strlow (ext), "_mode");
   if (is_defined (mode) > 0)
     {
	eval (mode);
	return;
     }
}

%}}}
%{{{ working with the zip

private define zip_open()
{
   variable zip = get_blocal_var("Zip");
   variable member = line_as_string();
   if (member[[-1:]] == "/")
     {
	throw RunTimeError, "this is a directory";
     }
   () = zip.view_member(member);
   set_mode_from_extension (file_type (member));
   view_mode();
}

private define zip_open_otherwindow()
{
   variable buf = whatbuf();
   zip_open();
   pop2buf(buf);
}

public define zip_extract_member(line, dest, zip)
{
   if (line[[-1:]] == "/")
     {
	throw RunTimeError, "this is a directory";
     }
   () = zip.extract_member(line, dest);
   return 1;
}

private define zip_extract_tagged()
{
   variable zip = get_blocal_var("Zip");
   variable dest = read_with_completion("Extract file(s) to:", "", "", 'f');
   listing_map(1, &zip_extract_member, dest, zip);
}

%}}}
%{{{ keybindings, menu

ifnot (keymap_p(mode))
{
   copy_keymap(mode, "listing");
   definekey(&zip_open, "^M", mode);
   if (FileList_KeyBindings == "mc")
     {
	% MC bindings
	definekey(&zip_open, Key_F3, mode);
	definekey(&zip_open, Key_F4, mode);
	definekey(&zip_extract_tagged, Key_F5, mode);
	definekey(&zip_open_otherwindow, "o", mode);
     }
   else
     {
	% dired bindings
	definekey(&zip_extract_tagged, "C", mode);
	definekey(&zip_open_otherwindow, "^o", mode);
	definekey("listing->tag_matching(1)",	"%d", mode); % tag regexp
	definekey("listing->tag(0); go_up_1",	_Backspace_Key,  mode);
     }
}

private define zip_mode()
{
   listing_mode();
   set_mode(mode, 0);
   use_keymap(mode);
   mode_set_mode_info(mode, "init_mode_menu", &listing->listing_menu);
}

%}}}

public define zip () % [ filename ]
{
   variable zipfile;
   if (_NARGS == 1) zipfile = ();
   else zipfile = read_with_completion("file to read", "", "", 'f');
   if (1 != file_status(zipfile)) 
     throw RunTimeError, "file zipfile$ doesn't exist"$;
   variable buffer = "*zip: $zipfile*"$;
   if (bufferp(buffer))
     return pop2buf(buffer);
   variable zip = Zip.new(zipfile);
   pop2buf(buffer);
   erase_buffer();
   define_blocal_var("Zip", zip);
   setbuf_info(path_basename(zipfile), path_dirname(zipfile),buffer,8);
   () = zip.list();
   zip_mode();
}
provide("zip");

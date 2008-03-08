% File:		tar.sl  -*- mode: SLang -*-
%
% $Id: tar.sl,v 1.11 2006/01/19 21:02:09 paul Exp paul $
%
% Copyright (c) 2003-2008 Paul Boekholt
% Released under the terms of the GNU GPL (version 2 or later).
% 
% this is a jed interface to GNU tar
% It works like emacs' tar-mode or dired.
% Except that in emacs' tar-mode, changes do not become permanent until you 
% save them.
% You can view the contents of a tar file, view and extract 
% members and delete them if the tar is not compressed.
% If you want want tar archives to be opened automatically in tar-mode, add
% add_to_hook("_jed_find_file_before_hooks", &check_for_tar_hook);
% to .jedrc
% Thanks to Günter Milde for his ideas, comments, patches and bug reports.

require("view");
require("syncproc");

% binding scheme may be dired or mc.  We use a variable from filelist.sl
% for consistency.
custom_variable("FileList_KeyBindings", "mc");

% A structure for setting some bufferlocal variables.
ifnot (is_defined("Tarvars"))
typedef struct
{
     file,			       %  tar filename (w/ path)
     base_file, 		       %  base of filename
     root,			       %  where to extract to
     options,			       %  z for tgz, &c
     readonly
} Tarvars;

public variable help_string = Assoc_Type[String_Type];
help_string["mc"] = 
  "1Help 2Menu 3View 4Edit 5Copy 6__ 7__ 8Delete 9PullDn 10Quit";
help_string["dired"] = 
  "e:edit C:copy v:view d:tag u:untag x:delete tagged r:rescan h:help q:quit";

%{{{ set the member's mode
% This is from site.sl - I don't want the modeline from tar members processed
% because script kiddies can use it for evil.
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

%{{{ reading a tar
private define tar_init_menu ();

private define tar_mode ()
{
   set_mode( "tar", 0);
   use_keymap("Tar");
#ifdef HAS_DFA_SYNTAX
   use_syntax_table("tar");
#endif
   run_mode_hooks("tar_mode_hook");
   mode_set_mode_info( "tar", "init_mode_menu", &tar_init_menu);
   message(help_string[FileList_KeyBindings]);
   bob;   
}

private define tar_options (file)
{
   variable exts = strchopr(file, '.', 0);
   if (1 == length(exts))
     throw RunTimeError, "file doesn't have a tar extension";
   switch (exts[0])
     { case "tar" : return String_Type[0];}
     { case "tgz" : return "-z";}
     { case "tZ" or case "tz" : return "-Z";}
     { case "tbz" : return  "--bzip2";}      %  they changed the short form
   if (2 == length(exts) || exts[1] != "tar") 
     throw RunTimeError, "file doesn't have a tar extension";
   switch (exts[0])
     { case "gz" : return "-z";}
     { case "Z" or case "compress" : return "-Z";}
     { case "bz2" or case "bz" : return "--bzip2";}
     { throw RunTimeError, "file doesn't have a tar extension";}
}

private define tar_get_vars ()
{
   ifnot (blocal_var_exists("tar")) throw RunTimeError, "not a tar buffer?";
   return get_blocal_var("tar");
}

private define tar_get_member ()
{
   return line_as_string[[2:]];
}

public define tar_list ()
{
   variable tar = tar_get_vars;
   set_readonly(0);
   erase_buffer;
   variable pid = open_filter_process(["tar", "-t", tar.options, "-f", tar.file], "@");
   variable status = close_filter_process(pid);
   if (status)
     {
	throw RunTimeError, "tar exited with $status"$;
     }
   do
     {
	insert("  ");
     }
   while (down(1));
   trim_buffer;
   set_buffer_modified_flag(0);
   set_readonly(1);
   message(help_string[FileList_KeyBindings]);
}

%!%+
%\function{tar}
%\synopsis{tar [ filename [readonly]] }
%\usage{public define tar ()}
%\description
%   A mode for viewing the contents of tar archives.  It resembles
%   Emacs' tar-mode, but works by calling the GNU tar program.  You
%   can mark archive members with the 'd' key, like in dired.  Set
%   \var{FileList_KeyBindings} to "mc" if you want keybindings like
%   in Midnight Commander.  When you mark a directory member, its
%   submembers are also marked.  Delete tagged members with 'x'.
%\notes
%   Unlike in Emacs' tar-mode, when you delete members they are gone - no
%   need to save the file.  To protect unwary users, there is the
%   readonly argument.
%\seealso{tar_copy, check_for_tar_hook}
%!%-
public define tar () % [ filename [ RO ] ]
{
   variable tar = @Tarvars;
   if (_NARGS == 2) (tar.file, tar.readonly) = ( , );
   else if (_NARGS == 1) (tar.file, tar.readonly) = ( , 0);
   else tar.file = read_with_completion("file to read", "", "", 'f');
   ifnot (1 == file_status(tar.file)) 
     return message("file \" "+tar.file+" \"doesn't exist");
   tar.base_file = path_basename(tar.file);
   tar.options = tar_options(tar.base_file);
   tar.root = "";
   variable bufname ="*tar: " + tar.base_file + "*";
   sw2buf(bufname);
   setbuf_info("",path_dirname(tar.file),bufname,8);
   define_blocal_var("tar", tar);
   tar_list;
   tar_mode;
}

%}}}

%{{{ working with the tar

public define tar_set_root (tar)
{
   do
     {
	tar.root = read_file_from_mini("what directory to extract to?");
     }
   while (2 != file_status(tar.root));
   set_blocal_var(tar, "tar");
   return tar.root;
}

private define extract_to_buf (buf)
{
   variable tar, member, buffer;
   tar = tar_get_vars;
   member = tar_get_member;
   if (member[-1] == '/') throw RunTimeError, "this is a directory";
   setbuf(buf);
   erase_buffer;
   variable pid = open_filter_process(["tar", "-xO", tar.options, "-f", tar.file, member], "@");
   variable status = close_filter_process(pid);
   if (status)
     {
	throw RunTimeError, "tar exited with $status"$;
     }
   set_buffer_modified_flag(0);
}

public define tar_view_member ()
{
   variable tar, member, buffer;
   tar = tar_get_vars;
   member = tar_get_member;
   buffer = sprintf("%s (%s)", path_basename(member), path_basename(tar.file));
   if(bufferp(buffer)) sw2buf(buffer);
   else 
     {
	extract_to_buf(buffer);
	sw2buf(buffer);
	set_mode_from_extension (file_type (member));
	view_mode();
     }
}

private define tar_copy_member ()
{
   variable tar = tar_get_vars(),
   member = tar_get_member();
   if (member[-1] == '/') throw RunTimeError, "this is a directory";
   variable name = read_file_from_mini("where to copy this file to");
   if (2 == file_status(name))
     name = dircat(name, path_basename(member));
   variable state;
   auto_compression_mode(0, &state);
   try
     {
	extract_to_buf(" *tar_copy_buffer*");
	write_buffer(name);
	delbuf(whatbuf());
     }
   finally
     {
	auto_compression_mode(state);
     }
} 

%{{{ tagging members

private define set_tag (tag)
{
   bol;
   go_right_1;
   insert_char(tag);
   del;   
}

private define tag_submembers (path, tag)
{
   for (bob; re_fsearch("^ [ xD]" + path + ".+"); go_down_1)
     set_tag(tag);
}

private define tag_member (on)
{
   push_spot;
   variable member = tar_get_member();
   variable tag, subtag;
   if (on) (tag,subtag) = 'D','x';
   else (tag,subtag) = ' ',' ';

   bol;
   go_right_1;
   if (looking_at_char('x')) return;
   set_readonly(0);
   set_tag(tag);
   % tag any other members with this name
   for (bob; re_fsearch("^ [x ]" + member + "$"); go_down_1)
     set_tag(subtag);

   if (member[-1] == '/')
     tag_submembers(member, subtag);
   pop_spot;
   set_readonly(1);
   set_buffer_modified_flag(0);
}

public define tar_tag_member(dir) % (on/off)
{
   if (_NARGS != 2)   %  toggle on/off 
     (line_as_string[1] == ' ');
   tag_member();
   if (dir) go_down_1;
   else go_up_1;
}

public define tar_untag_all ()
{
   push_spot_bob;
   set_readonly(0);
   do
     {
	bol;
	go_right_1;
	if (looking_at_char('D') || looking_at_char('x'))
	  {
	     insert_char(' ');
	     del;
	  }
     }
   while (down_1);
   pop_spot;
   set_readonly(1);
   set_buffer_modified_flag (0);
}

public define tar_tag_all()
{
   push_spot_bob;
   set_readonly(0);
   while (bol_fsearch ("  "))
     tar_tag_member(1);
   pop_spot;
   set_readonly(1);
   set_buffer_modified_flag (0);
}


private define get_tagged_members ()
{
   variable members = "", allmembers="";
   push_spot_bob;
   do
     {
	if (looking_at(" D"))
	  members += tar_get_member() + "\n";
	else if (looking_at(" x"))
	  allmembers += tar_get_member() + "\n";
     }
   while (down_1);
   pop_spot;
   return members, allmembers;
}

%}}}

%{{{ working with tagged members

public define tar_delete ()
{
   variable tar, member;
   tar = tar_get_vars;
   if (tar.readonly) throw RunTimeError, "archive is opened read-only";
   if (tar.options != "") throw RunTimeError, "I can't delete from a compressed archive";
   variable members, allmembers;
   (members, allmembers) = get_tagged_members;
   if (members == "") return;
   variable buf=whatbuf;
   sw2buf(" *Deletions*");
   erase_buffer();
   insert(members + allmembers);
   buffer_format_in_columns();
   ifnot (1 == get_yes_no("Do you wish to PERMANENTLY delete these members"))
     return sw2buf(buf);
   setbuf("*tar output*");
   erase_buffer();
   variable pid = open_filter_process(["tar", "--delete", "-f", tar.file, "-T",  "-"], ".");
   send_process(pid, members);
   send_process_eof(pid);
   variable status = close_filter_process(pid);
   if (status)
     {
	pop2buf(whatbuf());
	throw RunTimeError, "tar exited with $status"$;
     }
   sw2buf(buf);
   variable line=what_line;
   tar_list;
   goto_line(line);
}

private define tar_extract (all)
{
   variable tar, members ="";
   tar = tar_get_vars;
   if (tar.root == "") tar.root = tar_set_root(tar);
   ifnot (all)
     (members, ) = get_tagged_members;
   setbuf("*tar output*");
   variable pid = open_filter_process(["tar", "-x", tar.options, "-C", tar.root,
				       "-f", tar.file, "-T", "-"], ".");
   send_process(pid, members);
   send_process_eof(pid);
   variable status = close_filter_process(pid);
   if (status)
     {
	pop2buf(whatbuf());
	throw RunTimeError, "tar exited with $status"$;
     }
}

% are there tagged members?
private define are_there_tagged()
{
   push_spot_bob;
   bol_fsearch (" D");
   pop_spot;
}

%!%+
%\function{tar_copy}
%\description
%   If there are tagged tar members, copy them.  Otherwise copy the
%   member at point.
%\seealso{tar}
%!%-
public define tar_copy()
{
   if (are_there_tagged) tar_extract(0);
   else tar_copy_member;
}

%}}}

%}}}

%{{{ DFA highlighting, keybindings, menu

#ifdef HAS_DFA_SYNTAX
create_syntax_table ("tar");

%%% DFA_CACHE_BEGIN %%%
private define setup_dfa_callback(mode)
{
   dfa_enable_highlight_cache(mode + ".dfa", mode);
   dfa_define_highlight_rule("^  .*/$", "keyword", mode);
   dfa_define_highlight_rule("^ D.*$", "string", mode);
   dfa_define_highlight_rule("^ x.*$", "comment", mode);
   dfa_build_highlight_table(mode);
}
dfa_set_init_callback(&setup_dfa_callback, "tar");
%%% DFA_CACHE_END %%%
enable_dfa_syntax_for_mode("tar");
#endif

% Keybindings:
ifnot (keymap_p ("Tar"))
  copy_keymap("Tar", "view");
% dired bindings do not do any harm (as we are in readonly) so they
% should be available also to mc-Freaks (so the menu gives keybindings)
definekey("tar_tag_all", "a", "Tar");
definekey("tar_untag_all", "z", "Tar");
definekey("tar_list", "g", "Tar");
definekey("tar_view_member", "v", "Tar");
definekey("tar_copy", "C", "Tar");
definekey("tar_copy", "c", "Tar");
definekey("tar_tag_member(1,1)", "d", "Tar");
definekey("tar_tag_member(0,1)", "u", "Tar");
definekey("tar_tag_member(0,0)", _Backspace_Key, "Tar");
definekey("tar_delete", "x", "Tar");
definekey("message(help_string[FileList_KeyBindings])", "h", "Tar");
definekey("message(help_string[FileList_KeyBindings])", "?", "Tar");
definekey("delbuf(whatbuf())", "q", "Tar");
definekey("tar_view_member", "^M", "Tar");
if (FileList_KeyBindings == "mc")
{
   require("keydefs");
   undefinekey("^R", "Tar"); % I had an error, as ^R was a keymap (^RA...^RZ)
   definekey("tar_list", "^R", "Tar");
   % keep Key_F1 for the general help, or (with hyperhelp) let it do
   % help_mode (tries to open tar.hlp in the help buffer)
   definekey("menu_select_menu(\"Global.M&ode\")", Key_F2, "Tar");
   definekey("tar_view_member", Key_F3, "Tar");
   definekey("tar_copy", Key_F5, "Tar");
   definekey("tar_delete", Key_F8, "Tar");
   definekey("delbuf(whatbuf())", Key_F10, "Tar");
   definekey("tar_tag_member(1)", Key_Ins, "Tar");
}


private define tar_init_menu (menu) 
{
   menu_append_item(menu, "&view", "tar_view_member");
   menu_append_item(menu, "&tag", "tar_tag_member(1,1)");
   menu_append_item(menu, "&untag", "tar_tag_member(0,1)");
   menu_append_item(menu, "tag &all", "tar_tag_all");
   menu_append_item(menu, "untag all", "tar_untag_all");
   menu_append_item(menu, "&copy", "tar_copy");
   menu_append_item(menu, "copy all", &tar_extract, 1);
   menu_append_item(menu, "e&xpunge (delete) tagged", "tar_delete");
   menu_append_item(menu, "&set extract dir", "tar_set_root");
   menu_append_item(menu, "&rescan", "tar_list");
   menu_append_item(menu, "&quit tar", "delbuf(whatbuf())");
}

%}}}
 
provide("tar");

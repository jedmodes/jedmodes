
% File:          tar.sl      -*- mode: SLang; mode: fold -*-
%
% Author:        Paul Boekholt <p.boekholt@hetnet.nl>
% 
% $Id: tar.sl,v 1.1.1.1 2004/10/28 08:16:26 milde Exp $
% 
% this is a jed interface to GNU tar
% It works like emacs' tar-mode or dired.
% You can view the contents of a tar file, view and extract 
% members and delete them if the tar is not compressed.
% 
% what doesn't work yet? (I haven't tried myself)
%   -multi volume archives
%   -tagging lots of members (member names are sent to tar on the command line)
%   
% if tar's error messages mess up your screen, run emacs_recenter (bound to
% ^L in emacs mode)
% This is alpha software, beware!


% A structure for setting some bufferlocal variables.
!if (is_defined("Tarvars"))
typedef struct
{
     file,			       %  tar filename
     base_file, 		       %  base of filename
     root,			       %  where to extract to
     options			       %  z for tgz, &c  
} Tarvars;

%{{{ reading a tar
static define tar_init_menu ();

static define tar_mode ()
{
   set_mode( "tar", 0);
   use_keymap("Tar");
   runhooks("tar_mode_hook");
   mode_set_mode_info( "tar", "init_mode_menu", &tar_init_menu);
   bob;   
}

static define tar_options (file)
{
   variable exts = strchopr(file, '.', 0);
   switch (exts[0])
     { case "tar" : return "";}
     { case "tgz" : return "-z";}
     { case "tZ" or case "tz" : return "-Z";}
     { case "tbz" : return  "--bzip2";}      %  they changed the short form
   !if (orelse { 1 == length(exts) } { exts[1] == "tar" }) 
     error ("can't make out archive format");
   switch (exts[0])
     { case "gz" : return "-z";}
     { case "Z" or case "compress" : return "-Z";}
     { case "bz2" or case "bz" : return "--bzip2";}
     { error ("can't make out archive format");}
}

static define tar_get_vars ()
{
   !if (blocal_var_exists("tar")) error("not a tar buffer?");
   return get_blocal_var("tar");
}

static define tar_get_member ()
{
   return str_quote_string(line_as_string[[2:]], " ", '\\');
}

public define tar_list ()
{
   variable tar = @Tarvars;
   tar = tar_get_vars;
   set_readonly(0);
   variable cmd = strcat ("tar -t ", tar.options, " -f ", tar.file);
   erase_buffer;
   () = run_shell_cmd(cmd);
   bob;
   do
     {
	insert("  ");
     }
   while (down(1));
   set_buffer_modified_flag(0);
   set_readonly(1);
}

public define tar ()
{
   variable tar = @Tarvars;
   tar.file = read_with_completion("file to read", "", "", 'f');
   !if (strlen(tar.file)) return;
   !if (1 == file_status(tar.file)) error("file don't exist");
   tar.base_file = path_basename(tar.file);
   tar.options = tar_options(tar.base_file);
   tar.root = "";
   sw2buf("*tar: " + tar.base_file + "*");
   create_blocal_var("tar");
   set_blocal_var(tar, "tar");
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

static define extract_to_buf (buf)
{
   variable tar = @Tarvars, member, buffer;
   tar = tar_get_vars;
   member = tar_get_member;
   if (member[-1] == '/') error("this is a directory");
   variable cmd = strcat ("tar -xO ", tar.options, " -f ", tar.file, " ", member);
   sw2buf(buf);
   erase_buffer;
   () = run_shell_cmd(cmd);
   set_buffer_modified_flag(0);
   bob;
}

public define tar_edit_member ()
{
   variable tar = @Tarvars, member, buffer;
   tar = tar_get_vars;
   member = tar_get_member;
   buffer = strcat(path_basename(member), " (", tar.base_file, ")");
   if(bufferp(buffer)) sw2buf(buffer);
   else extract_to_buf(buffer);
}

public define tar_copy_member ()
{
   variable name =
     read_with_completion("where to copy this file to", "" , "", 'f');
   if (2 == file_status(name))
     name += path_basename(line_as_string()[[2:]]);
   extract_to_buf(" *tar_copy_buffer*");
   write_buffer(name);
   delbuf(whatbuf);
} 

%{{{ tagging members

static define set_tag (tag)
{
   bol;
   go_right_1;
   insert_char(tag);
   del;   
}

static define tag_submembers (path, tag)
{
   for (bob; re_fsearch("^ [ xD]" + path + ".+"); go_down_1)
     set_tag(tag);
}

static define tag_member (on)
{
   push_spot;
   variable member;
   member = tar_get_member;
   variable tag, subtag;
   if (on) (tag,subtag) = 'D','x';
   else (tag,subtag) = ' ',' ';

   set_readonly(0);
   bol;
   go_right_1;
   if (looking_at_char('x')) return;
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

public define tar_tag_member (on, dir)
{
   tag_member(on);
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
	if (looking_at_char('D') or looking_at_char('x'))
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

static define get_tagged_members ()
{
   variable members = "", allmembers="";
   push_spot_bob;
   do
     {
	if (looking_at(" D"))
	  members += tar_get_member() + " ";
	else if (looking_at(" x"))
	  allmembers += tar_get_member() + " ";
     }
   while (down_1);
   pop_spot;
   return members, allmembers;
}

%}}}

%{{{ working with tagged members

public define tar_delete ()
{
   variable tar = @Tarvars, member;
   tar = tar_get_vars;
   !if (tar.options == "") error("I can't delete from a compressed archive");
   variable members, allmembers;
   (members, allmembers) = get_tagged_members;
   if (members == "") return;
   whatbuf;
   sw2buf(" *Deletions*");
   erase_buffer();
   insert(strjoin(strchop(members + allmembers, ' ', '\\'),"\n"));
   buffer_format_in_columns();
   !if (1 == get_y_or_n("delete these files"))
     {
	sw2buf;
	return;
     }
  sw2buf;
  variable cmd = "tar --delete -f " + tar.file + " " + members;
  () = run_shell_cmd(cmd);
  what_line;
  tar_list;
  goto_line;
}

public define tar_extract ()
{
   variable tar = @Tarvars, member;
   tar = tar_get_vars;
   if (tar.root == "") tar.root = tar_set_root(tar);
   variable members, allmembers;
   (members, allmembers) = get_tagged_members;
   if (members == "") return;
   variable cmd = strcat("tar -x ", tar.options, " -C ", tar.root,
			 " -f ", tar.file, " ", members);
   () = run_shell_cmd(cmd);
}

%}}}

%}}}


!if (keymap_p ("Tar"))
  make_keymap("Tar");
definekey("tar_list", "g", "Tar");
definekey("tar_edit_member", "e", "Tar");
definekey("tar_copy_member", "C", "Tar");
definekey("tar_edit_member; most_mode", "v", "Tar");
definekey("tar_tag_member(1,1)", "d", "Tar");
definekey("tar_tag_member(0,1)", "u", "Tar");
definekey("tar_tag_member(0,0)", _Backspace_Key, "Tar");
definekey("tar_delete", "x", "Tar");
definekey("delbuf(whatbuf())", "q", "Tar");
definekey("message(\"e:edit, C:copy, v:view, d:tag, u:untag, x:delete tagged files, r:rescan, q:quit\")", "?", "Tar");      


static define tar_init_menu (menu) 
{
   menu_append_item(menu, "&rescan", "tar_list");
   menu_append_item(menu, "&edit", "tar_edit_member");
   menu_append_item(menu, "&tag", "tar_tag_member(1,1)");
   menu_append_item(menu, "&untag", "tar_tag_member(0,1)");
   menu_append_item(menu, "untag &all", "tar_untag_all");
   menu_append_item(menu, "e&xpunge tagged files", "tar_delete");
   menu_append_item(menu, "extract tagged files", "tar_extract");
   menu_append_item(menu, "set extract dir", "tar_set_root");
   menu_append_item(menu, "&quit tar", "delbuf(whatbuf())");
}
 
provide("tar");

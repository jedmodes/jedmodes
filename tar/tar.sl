% File:		tar.sl  -*- mode: SLang; mode: fold -*-
%
% Author:	Paul Boekholt <p.boekholt@hetnet.nl>
% 
% $Id: tar.sl,v 1.10 2003/04/03 22:51:35 paul Exp paul $
%
% this is a jed interface to GNU tar
% It works like emacs' tar-mode or dired.
% Except that in emacs' tar-mode, changes do not become permanent until you 
% save them.
% You can view the contents of a tar file, view and extract 
% members and delete them if the tar is not compressed.
% See INSTALL for more information.
% Thanks to Günter Milde for his ideas, comments, patches and bug reports.
% 
% what doesn't work yet? (I haven't tried myself)
%   -multi volume archives
%   -tagging lots of members (member names are sent to tar on the command line)
%   
% if tar's error messages mess up your screen, run emacs_recenter (bound to
% ^L in emacs mode) or type M-x redraw.
% 
% This is alpha software, beware!
require("tarlib");

% binding scheme may be dired or mc.  We use a variable from filelist.sl
% for consistency.
custom_variable("FileList_KeyBindings", "mc");

% A structure for setting some bufferlocal variables.
!if (is_defined("Tarvars"))
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


%{{{ reading a tar
static define tar_init_menu ();

static define tar_mode ()
{
   set_mode( "tar", 0);
   use_keymap("Tar");
#ifdef HAS_DFA_SYNTAX
   use_syntax_table("tar");
#endif
   runhooks("tar_mode_hook");
   mode_set_mode_info( "tar", "init_mode_menu", &tar_init_menu);
   message(help_string[FileList_KeyBindings]);
   bob;   
}

static define tar_options (file)
{
   variable exts = strchopr(file, '.', 0);
   if (1 == length(exts))
     error ("file doesn't have a tar extension");
   switch (exts[0])
     { case "tar" : return "";}
     { case "tgz" : return "-z";}
     { case "tZ" or case "tz" : return "-Z";}
     { case "tbz" : return  "--bzip2";}      %  they changed the short form
   !if (orelse { 2 == length(exts) } { exts[1] == "tar" }) 
     error ("file doesn't have a tar extension");
   switch (exts[0])
     { case "gz" : return "-z";}
     { case "Z" or case "compress" : return "-Z";}
     { case "bz2" or case "bz" : return "--bzip2";}
     { error ("file doesn't have a tar extension");}
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
   variable tar = tar_get_vars;
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
   trim_buffer;
   set_buffer_modified_flag(0);
   set_readonly(1);
   message(help_string[FileList_KeyBindings]);
}

public define tar () % [ filename [ RO ] ]
{
   variable tar = @Tarvars;
   if (_NARGS == 2) (tar.file, tar.readonly) = ( , );
   else if (_NARGS == 1) (tar.file, tar.readonly) = ( , 0);
   else tar.file = read_with_completion("file to read", "", "", 'f');
   !if (1 == file_status(tar.file)) 
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

static define extract_to_buf (buf, uncompress)
{
   variable tar, member, buffer;
   tar = tar_get_vars;
   member = tar_get_member;
   if (member[-1] == '/') error("this is a directory");
   variable cmd = create_delimited_string 
     (" ", "tar -xO", tar.options, "-f", tar.file, member, 5);
   if (uncompress and member[[-3:]] == ".gz") cmd += "|gzip -d"; 
   % autocompression mode doesn't uncompress tar members
   sw2buf(buf);
   erase_buffer;
   () = run_shell_cmd(cmd);
   set_buffer_modified_flag(0);
   bob;
}


public define tar_view_member ()
{
   variable tar, member, buffer;
   tar = tar_get_vars;
   member = tar_get_member;
   buffer = path_basename(member);
   if(bufferp(buffer)) sw2buf(buffer);
   else
     {
	extract_to_buf(buffer, 1);
	if (member[[-3:]] == ".gz")
	  set_mode_from_extension (file_type(member[[:-4]]));
	else set_mode_from_extension (file_type (member));
     }
   less_mode;
}

static define tar_copy_member ()
{
   variable autocompress, name =
     read_with_completion("where to copy this file to", "" , "", 'f');
   if (2 == file_status(name))
     name = dircat(name, path_basename(line_as_string()[[2:]]));
   extract_to_buf(" *tar_copy_buffer*", 0);
   % compress.sl provides a function for turning autocompression_mode on, off
   % and for toggling, but not for checking whether it's on or off.  I want
   % it off.  Fortunately it does give a message.
   if (is_list_element(".gz,.Z,.bz2,.bz", path_extname(name), ','))
     {
	auto_compression_mode; % if it was on, it will now be off!
	autocompress = (MESSAGE_BUFFER[[:-1]] == 'F');
	ERROR_BLOCK { auto_compression_mode(autocompress); }
	auto_compression_mode(0);
	write_buffer(name);
	auto_compression_mode(autocompress);
     }
   else write_buffer(name);
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
   variable tar, member;
   tar = tar_get_vars;
   if (tar.readonly) error ("archive is opened read-only");
   if (tar.options != "") error("I can't delete from a compressed archive");
   variable members, allmembers;
   (members, allmembers) = get_tagged_members;
   if (members == "") return;
   whatbuf;
   sw2buf(" *Deletions*");
   erase_buffer();
   insert(strjoin(strchop(members + allmembers, ' ', '\\'),"\n"));
   buffer_format_in_columns();
   !if (1 == get_yes_no("Do you wish to PERMANENTLY delete these members"))
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

static define tar_extract (all)
{
   variable tar, members ="";
   tar = tar_get_vars;
   if (tar.root == "") tar.root = tar_set_root(tar);
   !if (all)
     (members, ) = get_tagged_members;
   variable cmd = strcat("tar -x ", tar.options, " -C ", tar.root,
			 " -f ", tar.file, " ", members);
   () = run_shell_cmd(cmd);
}

% are there tagged members?
static define are_there_tagged()
{
   push_spot_bob;
   bol_fsearch (" D");
   pop_spot;
}

% extract tagged members, if none are tagged extract member at point
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
static define setup_dfa_callback(mode)
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
!if (keymap_p ("Tar"))
  make_keymap("Tar");
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


static define tar_init_menu (menu) 
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

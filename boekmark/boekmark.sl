% boekmark.sl
% 
% Author:        Paul Boekholt <p.boekholt@hetnet.nl>
% 
% $Id: boekmark.sl,v 1.1.1.1 2004/10/28 08:16:17 milde Exp $
% 
% Easy-to-use bookmark function.

static variable Book_Marks =  Assoc_Type[Mark_Type];

define bkmrk_set_mark ()
{
   variable name = strtrim_end(substr(strtrim_beg(line_as_string()), 1,40));
   !if (strlen(name)) error("please select a line with something on it");
   Book_Marks[name] = create_user_mark;
   vmessage ("Bookmark %s set.", name);
}

define bkmrk_jump_mark(bkmrk)
{
   variable mrk = Book_Marks[bkmrk];
   
   Book_Marks["last"] = create_user_mark;
   
   sw2buf (mrk.buffer_name);
   !if (is_user_mark_in_narrow (mrk))
     {
#ifdef HAS_BLOCAL_VAR
	variable fun;
	ERROR_BLOCK
	  {
	     _clear_error ();
	     error ("Mark lies outside visible part of buffer.");
	  }
	fun = get_blocal_var ("bookmark_narrow_hook");
	mrk; eval (fun);
#else
	error ("Mark lies outside visible part of buffer.");
#endif
     }

   goto_user_mark (mrk);
}


static define bookmark_menu_callback(popup)
{
   variable key, cmd;
   menu_append_item(popup, "set bookmark", "bkmrk_set_mark");
   menu_append_separator(popup);
   foreach (Book_Marks) using ("keys")
    {
       key = ();
       cmd = sprintf(". \"%s\" bkmrk_jump_mark", str_quote_string(key, "\"\\", '\\'));
       menu_append_item(popup, "&" + key, cmd);
    }
}

static define bookmark_load_popup_hook(menubar)
{
   variable menu = "Global.&Search";
   menu_delete_item(strcat (menu, ".Se&t Bookmark"));
   menu_delete_item(strcat (menu, ".Got&o Bookmark"));
   menu_append_popup(menu, "&Bookmark");
    menu_set_select_popup_callback
      (menu+".&Bookmark",
       &bookmark_menu_callback);
}
append_to_hook ("load_popup_hooks", &bookmark_load_popup_hook);

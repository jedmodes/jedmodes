% functions from the tar-mode package that might be useful in other contexts.

require("most");
provide("most");

% This is from site.sl - I don't want the modeline from tar members processed
% because script kiddies can use it for evil.
public define set_mode_from_extension (ext)
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

% This is just most, except that pressing 'q' will not run the mode_hook
public define less_mode ()
{
   most_mode;
   set_mode("less", 0);
   use_keymap("Less");
}

!if (keymap_p("Less"))
{
   copy_keymap("Less", "Most");
   definekey("delbuf(whatbuf)", "q", "Less");
}

provide("tarlib");

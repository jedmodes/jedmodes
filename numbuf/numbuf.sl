% Number the buffers and bind Alt-1 .. Alt-9 to go to numbered_buffer
% 
% Copyright (c) 2006 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
% 
% Version 1.0  first public version
%         1.1  removed hidden dependency on datutils
%              cleaned up code
%         1.2  bugfix: buffer number did not show up when buffername was still
%                      present in Numbered_Buffer_List when (re)loading the
%                      buffer
%              Numbered_Buffer_List[0] now used as well (was kept empty)
%              (buffer-numbers and keybindings start at 1)
%         1.3  new custom variable Numbuf_number_all: number also buffers
%              not bound to a file
%         1.3.1  2005-11-02 Fix "public" statements
%         1.3.2  2007-03-07 numbuf_menu_callback() depended on Global.sw2buf()
%         	 	    from bufutils. Report Sangoi Dino Leonardo
%              
% USAGE
% 
% Put in jed_library_path and insert a line
%   require("numbuf")
% into your jed rc file. Optionally set (custom) variables.

% _debug_info=1;

% --- custom variables ----------------------------------------------------

% Keybindings: Default is to bind Alt-1 to Alt-9 to goto_numbered_buffer.
% (With ALT_CHAR = 27) By default these are bound to digit_arg, make sure you
% bind another keyset to digit_arg.
% Use the following to change this. (Set to NULL if you don't want keybindings)
custom_variable("Numbuf_key_prefix", "\e");  % Escape (Alt/Meta)

% Set this to 0 to have only Alt-0 bound to open_buffer_list()
custom_variable("Numbuf_show_list_when_failing", 1);

% Do you want to number all buffers? (using switch_active_buffer_hook)
custom_variable("Numbuf_number_all", 0);

% --- Internal variables ---------------------------------------------------

private variable chbuf_menu = "Global.&Buffers.&Change Buffer";

variable Numbered_Buffer_List = String_Type[10];
Numbered_Buffer_List[*] = ""; % initialize

% --- Functions ------------------------------------------------------------

% number the buffer if not done
define number_buffer()
{
   _pop_n(_NARGS);  % remove possible arguments from stack
   variable buf = whatbuf(), free_numbers;
   % don't number hidden buffers and the ".jedrecent" auxiliary buffer
   if (buf[0] == ' ' or buf == ".jedrecent")
     return;
   % Find reusable numbers
   free_numbers = where(Numbered_Buffer_List == buf); % buf is still in list
   !if (length(free_numbers))
     free_numbers = where(not(array_map(Int_Type, &bufferp, Numbered_Buffer_List)));
   if (length(free_numbers))
     {
	% add to list of numbered buffers and set status line
	Numbered_Buffer_List[free_numbers[0]] = buf;
	set_status_line("["+ string(free_numbers[0]+1)+ "]" 
	   + Status_Line_String, 0);
     }
}

% this is also defined in bufutils.sl but we don't want dependencies
private define go2buf(buf)
{
   if(buffer_visible(buf))
     pop2buf(buf);   % goto window where buf is visible
   else
     sw2buf(buf);    % open in current window
}

% Build the menu of numbered buffers
define numbuf_menu_callback (popup)
{
   variable menu, buf, entry, i = 1;

   foreach (Numbered_Buffer_List)
     {
        buf = ();
        if (bufferp(buf))
          menu_append_item (popup, "&"+string(i)+" "+buf, &go2buf, buf);
	i++;
     }
   % append the unnumbered buffers
   loop (buffer_list())
     {
        buf = ();
        if (orelse{buf[0] == ' '}{length(where(Numbered_Buffer_List == buf))})
          continue;
	(entry, ) = strreplace("&"+buf, "&*", "*&", 1);
	menu_append_item (popup, entry, &go2buf, buf);
     }

}

% Change the callback of the Change Buffer menu entry
private define numbuf_popup_hook(menubar)
{
   menu_set_select_popup_callback(chbuf_menu, &numbuf_menu_callback);
}
append_to_hook("load_popup_hooks", &numbuf_popup_hook);

define goto_numbered_buffer(n)
{
   variable buf = Numbered_Buffer_List[n-1]; % Arrays start with element 0

   if (andelse {buf != NULL} { bufferp(buf) })
     go2buf(buf);
   else if (Numbuf_show_list_when_failing)
     menu_select_menu(chbuf_menu);
   else
     message("Buffer "+string(n+1)+" doesn't exist.");
}

% Keybindings: Default is to bind Alt-1 to Alt-9 to goto_numbered_buffer
% See the custom variable Numbuf_key_prefix for changing this.
if (Numbuf_key_prefix != NULL)
{
   setkey(sprintf("menu_select_menu(\"%s\")", chbuf_menu),
	  Numbuf_key_prefix + "0");
   for($1=1; $1<10; $1++)
     setkey(sprintf("goto_numbered_buffer(%d)",$1),
	    Numbuf_key_prefix+string($1));
}

% Hooks:

if (Numbuf_number_all)
  append_to_hook("_jed_switch_active_buffer_hooks", &number_buffer);
else % number buffers associated to a file
{
   % either when opening a file (no arguments, no return value)
   add_to_hook("_jed_find_file_after_hooks", &number_buffer);
   % or when saving to a file (one argument, no return value)
   add_to_hook("_jed_save_buffer_after_hooks", &number_buffer);
}

provide("numbuf");


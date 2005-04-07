% A generic view mode for readonly buffers
% 
% Copyright (c) 2003 Günter Milde and Paul Boekholt
% Released under the terms of the GNU General Public License (ver. 2 or later)
% 
% Versions: 
%            1.0 first public release
% 2005-04-05 1.1 merge of GM and PB versions, bugfix in enable edit
% 2005-04-07 1.2 bugfix: added require("keydefs") (Rafael Laboissiere)
%
% CUSTOMIZATION
% 
% If you want to change the keybindings for all readonly buffers based
% on the "view" keymap you either just change this file, or insert in your 
% .jedrc
%   require("view");
%   definekey("close_and_insert_word", "i", "view");
% After that, in all modes that copy the view keymap, Key-i closes the buffer 
% and inserts the word into the calling buffer (if the binding 
% is not overwritten in the mode).
%   
% If you want all readonly buffers in view mode, insert
%   autoload("set_view_mode_if_readonly", "view");
%   append_to_hook("_jed_find_file_after_hooks", &set_view_mode_if_readonly);
% in your .jedrc

static variable mode = "view";

% requirements
autoload("close_buffer", "bufutils");
autoload("set_help_message", "bufutils");
autoload("help_message", "bufutils");
autoload("close_and_insert_word", "bufutils");
autoload("close_and_replace_word", "bufutils");

require("keydefs");  % in stadandard library but not loaded by all emulations

% customization
% Ask before going to edit mode?
custom_variable("View_Edit_Ask", 1);

% --- helper functions ---

% Make a readonly buffer editable (this is from most.sl)
define enable_edit()
{
   if(orelse
      {not View_Edit_Ask}
      {get_y_or_n("Edit this buffer") == 1}
     )
     {
	set_readonly(0);
	set_status_line("", 0);  % reset to global
	runhooks("mode_hook", file_type(buffer_filename));
     }
}

% this one is also in cuamisc.sl (and hopefully one day in site.sl)!
%!%+
%\function{repeat_search}
%\synopsis{continue searching with last searchstring}
%\usage{define repeat_search ()}
%\seealso{LAST_SEARCH, search_forward, search_backward}
%!%-
define repeat_search ()
{
   go_right (1);
   !if (fsearch(LAST_SEARCH)) error ("Not found.");
}

% --- the mode ---

% a generic keymap for readonly buffers (use for view-mode or
% as base for your specific map with copy_keymap(mode, "view"))
!if (keymap_p(mode))
{
   make_keymap(mode);
%    _for ('a', 'z', 1)
%      definekey(char, "error(help_message)", _stk_roll(2), mode);
   definekey("close_buffer",                     "\e\e\e", mode); % Escape
   definekey("page_up", 		         Key_BS,   mode);
   definekey("page_down",                        " ",      mode);
   % TODO: Key_Return/Key_BS  scroll one line down/up
   definekey("bob",                              "<",      mode);
   definekey("eob; recenter(window_info('r'));", ">",      mode);
   definekey("re_search_forward",                "/",      mode);
   definekey("repeat_search",                    "\\",     mode);
   definekey("help_message",                     "?",      mode);
   definekey("search_backward",                  "b",	   mode);
   definekey("enable_edit",                      "e",      mode);
   definekey("search_forward",                   "f",	   mode);
   definekey("goto_line",                        "g",      mode);
%    definekey("close_and_insert_word",            "i",      mode);
   definekey("describe_mode",                    "h",      mode);
%    definekey("page_down",                        "n",      mode);
%    definekey("page_up",                          "p",      mode);
   definekey("close_buffer",                     "q",      mode);
%   definekey("close_and_replace_word",           "r",      mode);
   definekey("isearch_forward",                  "s",      mode);
   _for (0, 9, 1)
     definekey("digit_arg", string(exch()), mode);
}

% view menu (appended to an possibly existing mode menu)
static define view_menu(){}
static define view_menu(menu)
{
   
   variable init_menu = get_blocal_var("init_mode_menu");
   if (andelse{init_menu != NULL}{init_menu != &view_menu})
     {
	@init_menu(menu);
	menu_append_separator(menu);
     }
   menu_append_item(menu, "&Edit",          "enable_edit");
   menu_append_item(menu, "&Close", "close_buffer");
}

public define view_mode()
{
   % If it's folded, this will add the folding keybindings to the view map
   if(blocal_var_exists("fold_start"))
     {
	use_keymap(mode);
	folding_mode;
     }
   set_readonly(1);
   set_buffer_modified_flag(0);
   define_blocal_var("init_mode_menu", mode_get_mode_info("init_mode_menu"));
   use_keymap(mode);
   set_mode(mode, 0);
   mode_set_mode_info(mode, "init_mode_menu", &view_menu);
   set_help_message(
     "SPC:pg_dn BS:pg_up f:search_fw b:search_bw q:quit e:edit ?:this_help");
   run_mode_hooks(mode);
}

public define set_view_mode_if_readonly()
{
   if (is_readonly)
     view_mode;
}

provide(mode);

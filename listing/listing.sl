% A mode for listings of e.g. files or findings
% to be used by more specific modes like dired, grep, locate, ...
%
% Copyright (c) 2003 Dino Sangoi, Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
% 
% Version    0.1   Dino Sangoi   first version
% 	     0.9   Günter Milde
%                  * "outsourcing" of the linklist datatype
%                  * Tags list is now buffer-local
%            0.9.1 * Tags list implemented as array
%            0.9.2 * Use array_map for most mappings
%                  * introduced the scope-argument
%            0.9.3 * Mode menu, more keybindings
%                	* new functions: edit, listing_list_tags
%            0.9.4 * replaced use of obsolete function array_concat
%            0.9.5 * optional argument "default" for get_confirmation()
% 2004-02-05 0.9.6 * bugfix: listing_mode no longer tries to delete
%                    empty lines (P. Boekholt)
% 2005-03-31 1.9.7 * made slang-2 proof: A[[0:-2]] --> A[[:-2]]   
%                    
% TODO:  * Shift-Click tags from point to Mousepoint
%          may be also: right-drag tags lines
        
% _debug_info = 1;

% --- requirements ---

% from jed's standard library
require("keydefs"); % symbolic names for keys
% non-standard extensions
require("view"); % readonly-keymap depends on bufutils.sl
autoload("array", "datutils");
autoload("array_delete", "datutils");
autoload("array_append", "datutils");
autoload("push_defaults", "sl_utils");
autoload("_implements", "sl_utils");

% --- name it
provide("listing");
_implements("listing");
private variable mode = "listing";

% --- Variables -------------------------------------------------------

custom_variable("ListingSelectColor", color_number("menu_selection"));
custom_variable("ListingMarkColor", color_number("region"));

% this one is for communication between different calls to 
% get_confirmation
static variable Dont_Ask = 0;

% --- Functions --------------------------------------------------

% --- Helper Functions (static)

% find out if the current line is tagged.
% If so, return the index of the mark + 1, else return 0
static define line_is_tagged()
{
   variable element, n = 1;
   variable line = what_line();

   !if (length(get_blocal_var("Tags"))) % tags list empty
     return 0;
   push_spot();   % remember position
   foreach(get_blocal_var("Tags"))
     {
	element = ();
	goto_user_mark(element); % only way to find out mark.line
	if (line == what_line())
	  {
	     pop_spot();
	     return(n);
	  }
	n++;
     }
   pop_spot();
   return(0);
}

% return the line belonging to the line-mark as string
static define get_tag(tag_mark)
{
   goto_user_mark(tag_mark);
   return line_as_string();
}

% helper function: just return the arguments
static define null_fun() { }

%!%+
%\function{tags_length}
%\synopsis{Return the number of tagged lines.}
%\usage{Int tags_length(scope=2)}
%\description
%  Return the number of tagged lines, considering scope.
%  For a discussion of the scope parameter see \var{listing_map}
%\seealso{listing_map, listing_mode, list_tags}
%!%-
static define tags_length() % (scope=2)
{
   variable scope=2;
   if (_NARGS)
     scope = ();
   scope -= not(length(get_blocal_var("Tags"))); 
   % -> if (scope <= 0) use current line
   if (scope <= 0) % use current line
     return 1; 
   else
     return length(get_blocal_var("Tags"));
}

% Delete the tagged lines.
% Helper function for listing_map
% Argument is an array of positions in the Tags blocal var.
%   E.g. delete_tag_lines(get_blocal_var("Tags") % delete all tagged lines
%        delete_tag_lines(get_blocal_var("Tags")[where(result==2)])
% The tag-marks will not be deleted!
static define delete_tag_lines(tags)
{
   push_spot();
   set_readonly(0);
   foreach (tags)
     {
	goto_user_mark(());
	delete_line();
     }
   set_readonly(1);
   set_buffer_modified_flag(0);
   pop_spot();
}


%!%+
%\function{get_confirmation}
%\synopsis{Ask whether a list of actions should go on}
%\usage{Int  listing->get_confirmation(Str prompt, Str default="")}
%\description
%   If an action (e.g. deleting) on tuple of instances (e.g. tagged files) 
%   needs a user confirmation, the function in question can use 
%   get_confirmation(prompt) instead of get_y_or_n(prompt) to offer more 
%   choices. The keybindings are a subset from jed's replace command: 
%   y: yes, n: no, !: all, q:quit
%   The optional argument default sets the action for pressing Enter 
%   (defaulting to no action).
%\notes
%   The static variable listing->Dont_Ask saves the "!: all" decision
%   (so the next invocation of get_confirmation doesnot ask but returns
%   always 1.) The function that starts the mapping on the action on 
%   the tuple of instaces must reset listing->Dont_Ask to 0. (listing_map
%   does this, so it is save to use get_confirmation in a function that gets
%   called from listing_map)
%   
%\seealso{listing_map, get_y_or_n}
%!%-
static define get_confirmation() % (prompt, [default])
{
   variable key, prompt, default;
   (prompt, default) = push_defaults( , "", _NARGS);

   if (Dont_Ask == 1)
     return 1;
   
   flush(prompt + " (y/n/!/q): " + default);
   loop(5)
     {
	key = getkey();
	if (key == '\r')
	  key = default[0];
	switch(key)
	  { case 'y' : return 1; }
	  { case 'n' : return 0; }
	  { case '!' : Dont_Ask = 1; return 1; }
	  { case 'q' or case '\e': Dont_Ask = -1; error("Quit!"); }
	  { case 'r' : recenter (window_info('r') / 2); }
	  { flush(prompt + " y:yes n:no !:all q:quit"); }
     }
   error("Quit!");
}
   
%!%+
%\function{tag}
%\synopsis{Mark the current line and append to the Tags list}
%\usage{Void tag(how = 1)}
%\description
%  Tag/untag the current line according to the (optional) argument how:
%     0 untag,
%     1 tag (default),
%     2 toggle
%\seealso{listing_mode, listing_map}
%!%-
static define tag() % (how = 1)
{
   variable how = push_defaults(1, _NARGS);

   variable tags = get_blocal_var("Tags");
   % see whether the line is already tagged
   variable is_tagged = line_is_tagged();
   % toggle: change the tag status
   if (how == 2)
     how = not(is_tagged);
   % already as we wish it
   if (how and is_tagged or not(how) and not(is_tagged))
     return;
   % tag
   if (how)
     set_blocal_var(
	array_append(tags, create_line_mark(ListingMarkColor)), "Tags");
   else % untag
     set_blocal_var(array_delete(tags, is_tagged-1), "Tags");
}


%!%+
%\function{tag_all}
%\synopsis{(Un)Tag all lines}
%\usage{Void tag_all(how = 1)}
%\description
%  Tag/untag all lines according to the (optional) argument how.
%  (Faster than iterating over tag(how))
%\seealso{tag, listing_mode, listing_map}
%!%-
static define tag_all() % (how = 1)
{
   variable how = push_defaults(1, _NARGS);

   if(is_visible_mark())
     narrow();
   push_spot();
   eob();
   variable i = 0, tags = Mark_Type[what_line()];
   bob();
   
   if (how)
     do
     {
	if(orelse {how==1} {not(line_is_tagged())})
	  {
	     tags[i] = create_line_mark(ListingMarkColor);
	     i++;
	  }
     }
   while (down_1());
   if (how) 
     set_blocal_var(tags[[:i-1]], "Tags");
   else
     set_blocal_var(Mark_Type[0], "Tags");
     
   pop_spot();
   widen();
}

% Tag all lines that match a regex pattern
static define tag_matching() %(how)
{
   variable how = push_defaults(1, _NARGS);
   
   variable prompt = ["Untag", "Tag"][how==1] + " all lines containing regexp:";
     
   variable pat = read_mini(prompt, "", ".*");
   push_spot_bob();
   while (re_fsearch(pat) and not(eobp))
     {
	tag(how);
	eol(); 
	go_right_1();
     }
   pop_spot();
}

% Switch to normal editing mode (text_mode)
static define edit()
{
   set_readonly(0);
   tag_all(0); % untag
   set_blocal_var(NULL, "Current_Line");
   text_mode();
   
%   set_status_line("", 0);
}

% --- Public Functions

%!%+
%\function{listing_map}
%\synopsis{Call a function for marked lines.}
%\usage{Void listing_map(Int scope, Ref fun, Any [args])}
%\description
%  Call fun (given as reference) for marked lines, i.e. tagged lines or
%  the current line depending on the value of the first argument scope
%     0 current line
%     1 tagged lines or current line, if no line is tagged.
%     2 tagged lines
%  The function will receive the tagged line(s) as first argument and
%  must return an integer, with the meaning:
%     0    leave tag
%     1    untag line
%     2	   delete line
%
%\seealso{listing_mode, tag, list_tags}
%!%-
 public define listing_map() % (scope, fun, [args])
{
   % get arguments
   variable scope, fun, args, buf = whatbuf();
   args = __pop_args (_NARGS - 2);
   (scope, fun) = ( , );

   variable tags = get_blocal_var("Tags");
   
   scope -= not(length(tags)); % -> if (scope <= 0) use current line
   % tag current line, if we are to use it
   if (scope <= 0)
	tags = [create_line_mark(ListingMarkColor)];
   
   !if (length(tags))
     error("No tags set");

   % We do not use array_map becouse in case of an error midways
   % we still want to clean up. By defining result in forehand and filling
   % as we go, we have the results also if a break occures after
   % some tags are processed.
   variable i, result = Int_Type[length(tags)];
   ERROR_BLOCK 	% clean up
     {
	setbuf(buf); % just in case we landed somewhere else
	delete_tag_lines(tags[where(result==2)]);
	if (scope > 0) % tagged lines used
	  set_blocal_var(tags[where(not(result))], "Tags");
	if (Dont_Ask == -1)
	  {
	     message("Quit");
	     _clear_error();
	  }
     }
   % Reset the static variable used by get_confirmation()
   Dont_Ask = 0;
   % now we are ready to do the actual mapping
   for(i=0; i<length(tags); i++)
     {
	% show("calling",fun, get_tag(tags[i]));
	!if (is_line_hidden)
	  result[i] = @fun(get_tag(tags[i]), __push_args(args));
     }
   % clean up
   EXECUTE_ERROR_BLOCK;
}

%!%+
%\function{listing_list_tags}
%\synopsis{Return an array of tagged lines.}
%\usage{Array[String] listing_list_tags([scope])}
%\description
%  Return an array of tagged lines. The lines will remain tagged.
%  For a discussion of the scope parameter see \var{listing_map}
%\seealso{listing_map, listing_mode, tag, tags_length}
%!%-
 public define listing_list_tags() % (scope=2, untag=0)
{
   variable scope, untag;
   (scope, untag) = push_defaults(2, 0, _NARGS);
   
   return array(listing_map(scope, &null_fun, untag));
}

% ---- The listing mode ----------------------------------------------------

% Update hook to highlight current line.
static define listing_update_hook()
{
   move_user_mark(get_blocal_var("Current_Line"));
}

% --- Keybindings

!if (keymap_p (mode))
  copy_keymap (mode, "view");

definekey (mode+"->edit",              "e", mode);
definekey (mode+"->tag(2)",            "t", mode); % toggle tag
definekey (mode+"->tag(1); go_down_1", "d", mode); % dired-like
definekey (mode+"->tag(0); go_down_1", "u", mode); % untag (dired-like)
definekey (mode+"->tag_matching(1)",   "+", mode);
definekey (mode+"->tag_matching(0)",   "-", mode);
definekey (mode+"->tag_all(2)",        "*", mode); % toggle all tags
definekey (mode+"->tag_all(1)",        "a", mode);
definekey (mode+"->tag_all(0)",        "z", mode);
definekey (mode+"->tag_all(0)",        "\e\e\e",        mode); % "meta-escape"
definekey (mode+"->tag(2); go_down_1", Key_Ins,        mode); % MC like
definekey ("go_up_1;"+mode+"->tag(2)",   Key_BS,   mode);     % Dired
definekey (mode+"->tag(2); go_down_1", Key_Shift_Down, mode); % CUA style
definekey (mode+"->tag(2); go_up_1",   Key_Shift_Up,   mode); % CUA style

% --- the mode dependend menu
static define listing_menu (menu)
{
   menu_append_item (menu, "&Tag/Untag",      mode+"->tag(2)");
   menu_append_item (menu, "Tag &All", 	      mode+"->tag_all(1)");
   menu_append_item (menu, "Untag A&ll",      mode+"->tag_all(0)");
   menu_append_item (menu, "Tag &Matching",   mode+"->tag_matching(1)");
   menu_append_item (menu, "&Untag Matching", mode+"->tag_matching(0)");
   menu_append_item (menu, "&Invert Tags",    mode+"->tag_all(2)");
   menu_append_item (menu, "&Edit Listing",   mode+"->edit");
}

public define listing_mode ()
{
   % % delete last empty line
   % push_spot();
   % eob();
   % if (bolp and  eolp)
   %   call("backward_delete_char");
   % pop_spot();
   
   set_buffer_modified_flag (0); % so delbuf doesnot ask whether to save first
   set_readonly(1);
   set_mode(mode, 0);
   use_keymap(mode);
   mode_set_mode_info(mode, "init_mode_menu", &listing_menu);
   % TODO set_buffer_hook("mouse_2click", &listing_mouse_2click_hook);
   define_blocal_var("Current_Line", create_line_mark(ListingSelectColor));
   define_blocal_var("Tags", Mark_Type[0]); % array of tagged lines
   set_buffer_hook("update_hook", &listing_update_hook); % mark current line
   run_mode_hooks(mode+"_mode_hook");
}


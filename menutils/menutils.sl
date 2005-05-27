% menutils.sl	-*- mode: Slang; mode: Fold -*-
% popup menu extensions
% 
% $Id: menutils.sl,v 1.1 2005/05/27 18:24:00 paul Exp paul $
% Keywords: slang, ui
%
% Copyright (c) 2004, 2005 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).

provide("menutils");

static define menu_do_toggle(var)
{
   @var = not @var;
}


%!%+
%\function{menu_checkbox}
%\synopsis{make a 'checkbox' menu item}
%\usage{menu_checkbox(String menu, String name, Ref or Integer var, [String or Ref fun1, [String or Ref fun2]])}
%
%\description
%   define a menu item that works as a checkbox.  When \var{var} != 0,
%   the menu will have an '[X]', else a '[ ]' in front.  When called
%   with 3 arguments, \var{var} should be a reference to the variable.
%   The menu item will toggle \var{var} (if it's 0 it will become 1,
%   else 0).  With 4 arguments, \var{fun1} is a name or reference to a
%   'toggle' function.  \var{Var} is an integer indicating the state
%   that is toggled by \var{fun1}. With 5 arguments, \var{fun1} should
%   toggle \var{var} on and \var{fun2} should toggle it off.
%\notes
%   
%\seealso{menu_radio}
%!%-
public define menu_checkbox() % menu, name, var, fun1, [fun2]
{
   variable menu, name, var, fun1, fun2;
   (menu, name, var, fun1, fun2) = push_defaults(,,,,, _NARGS);
   variable menu_item;
   if (fun1 == NULL)
     {
	if (@var) menu_item = "[X] " + name;
	else menu_item = "[ ] " + name;
	menu_append_item (menu, menu_item, &menu_do_toggle, var);
     }
   else
     {
	if (var) menu_item = "[X] " + name;
	else menu_item = "[ ] " + name;
	if (fun2 == NULL or not var)
	  menu_append_item (menu, menu_item, fun1);
	else
	  menu_append_item (menu, menu_item, fun2);
     }
}

static define menu_do_radio();

static define menu_make_radio(menu, var, names, values, fun)
{
   variable i = 0;
   loop (length(names))
     {
	variable a = __pop_args(menu, var, names[i], values[i], names, values, fun, 7);
	if (@var == values[i])
	  menu_append_item(menu, "(*) " + names[i], &menu_do_radio, a);
	else
	  menu_append_item(menu, "( ) " + names[i], &menu_do_radio, a);
	i++;
     }
}

static define menu_do_radio(a)
{
   variable menu, var, name, value, names, values, fun;
   (menu, var, name, value, names, values, fun) = __push_args(a);
   @var = value;
   if (fun != NULL) @fun(value);
   menu_delete_items(menu);
   menu_make_radio(menu, var, names, values, fun);
}


%!%+
%\function{menu_radio}
%\synopsis{make a 'radio buttons' popup menu}
%\usage{public define menu_radio(String menu, String popup, Ref var, String names, [String values], [Ref fun])}
%\description
%   With 3 arguments:
%   
%   Make a popup menu \var{popup} under menu \var{menu}, with items in
%   the comma-separated list \var{names}, like:
%   
%#v+
%   ( ) apples
%   ( ) pears
%   (*) beer
%#v-
%   
%   The item that is equal to the value of \var{var} is checked. Select an
%   item to assign another value to \var{var}.
%   
%   If there is a 4th parameter and it's not NULL, it is a
%   comma-separated list of values that correspond 1:1 to the
%   \var{names}. To assign a value to \var{var}, check the
%   corresponding item in \var{names} in the popup.
%   
%   The 5th parameter is a function that is called when an item is
%   selected.
%   
%\notes
%   
%\seealso{menu_checkbox}
%!%-
public define menu_radio()  % menu, popup, var, names, [values], [fun]
{
   variable menu, popup, var, names, values, fun;
   (menu, popup, var, names, values, fun) = push_defaults(,,,,,, _NARGS);
   if (typeof(names) == String_Type) names = strchop(names, ',', '\\');
   if (values == NULL) values = names;
   menu_append_popup (menu, popup);
   menu_make_radio (menu + "." + popup, var, names, values, fun);
}


% A color scheme for the terminal/console with white background
% 
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
% 
% This scheme uses only the basic color set, so it should work with all 
% flavours of jed (tested with jed in rxvt and Linux console).
% 
static variable bg = "white";

set_color("normal", "black", bg);
set_color("status", "yellow", "blue");
set_color("region", "yellow", "blue");
set_color("operator", "blue", bg);      % +, -, etc..
set_color("number", "blue", bg);    % 10, 2.71, etc.. 
set_color("comment", "magenta", bg);% /* comment */
set_color("string", "blue", bg);    % "string" or 'char'
set_color("keyword", "blue", bg);    % if, while, unsigned, ...                                                 
set_color("keyword1", "red", bg);    % malloc, exit, etc...
set_color("delimiter", "blue", bg);     % {}[](),.;...
set_color("preprocess", "green", bg);   
set_color("message", "blue", bg);
set_color("error", "red", bg);
set_color("dollar", "red", bg);
set_color("...", "red", bg);			  % folding indicator

set_color ("menu_char", "yellow", "blue");
set_color ("menu", "white", "blue");
set_color ("menu_popup", "white", "blue");
set_color ("menu_shadow", "blue", "black");
set_color ("menu_selection", "white", "cyan");


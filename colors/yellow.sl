% Light yellow color scheme for xjed
% 
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% This scheme uses colors only available in xjed, will not work with jed in 
% a console or X terminal.

static variable bg = "LightYellow";

set_color("normal",     "black",     bg);
set_color("status", 	"yellow",    "blue");
set_color("operator", 	"black",     bg);  % +, -, etc..
set_color("number",  	"darkblue",  bg);  % 10, 2.71, etc.. 
set_color("comment", 	"magenta",   bg);  % /* comment */
set_color("region", 	"yellow",    "blue");
set_color("string", 	"darkblue",  bg);  % "string" or 'char'
set_color("keyword", 	"blue",      bg);  % if, while, unsigned, ...
set_color("keyword1", 	"brightblue",bg);  % malloc, exit, etc...
set_color("keyword2",	"darkblue",  bg);	   
set_color("keyword3",	"red",       bg);	   
set_color("delimiter",  "blue",      bg);  % {}[](),.;...
set_color("preprocess", "darkgreen", bg);   
set_color("message",   	"blue",      bg);
set_color("error",  	"brightred", bg);
set_color("dollar", 	"brightred", bg);
set_color("...",   	"red", 	     bg);  % folding indicator

set_color ("menu_char",          "yellow", "blue");
set_color ("menu", 		 "white",  "blue");
set_color ("menu_popup",	 "white",  "blue");
set_color ("menu_shadow", 	 "blue",   "black");
set_color ("menu_selection", 	 "white",  "darkblue");
set_color ("menu_selection_char","yellow", "darkblue");
%set_color ("mouse", "black", bg);


% Associate keystrings via x_set_keysym (works for xjed only)
%
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% 1.1 2004-12-01 first public version
% 
% USAGE / CUSTOMISATION
% 
% x-keysyms.sl requires x-keydefs.sl. If you want to use alternative key
% strings, do e.g.
% 
% if (is_defined("x_set_keysym"))  % xjed running
% {
%    require("x-keydefs");   % symbolic keynames
%    % change string values for Keys here, e.g.
%    % Key_Return = "\e[8~";
%    % Key_BS    = "\e[16~";
%    % Key_Tab   = "\e[z";
%    require("x-keysyms");   % set key strings for special keys
% }
% else
% {
%    require("keydefs");
% }
%
% EXTENSION
% 
% Get the keysyms from the file keysymdef.h or the Jed variable X_LAST_KEYSYM 
% e.g. with
% 
% public define showkey_literal()
% {
%    flush ("Press key:");
%    variable key = get_keystring();
%    if (prefix_argument(0))
%      insert (key);
%    else
%      {
% #ifdef XWINDOWS
% 	key += sprintf(" X-Keysym: %X", X_LAST_KEYSYM);
% #endif
% 	message ("Key sends " + key);
%      }
% }
%
% Attention: x_set_keysym() currently works only for keysyms in the range
% `0xFF00' to `0xFFFF'
%
% On 28 May 2003 John wrote to jed-users:
% I will fix it in the next release.  When I wrote the code, there were
% no such keysyms below 0xFF00.

require("x-keydefs"); % symbolic names for keystrings (xjed version)

% ESC (make it destinguishable from keys that start with \e
x_set_keysym(0xFF1B, 0,    Key_Esc);  

% DEL (see also .jedrc for this topic)
% (on my system it did not distinguish modifiers)
x_set_keysym(0xFFFF,  0,   Key_Del); 
x_set_keysym(0xFFFF , '$', Key_Shift_Del); 
x_set_keysym(0xFFFF , '^', Key_Ctrl_Del);  

% Backspace:
x_set_keysym(0xFF08 , 0,   Key_BS);    
x_set_keysym(0xFF08 , '$', Key_Shift_BS);    
x_set_keysym(0xFF08 , '^', Key_Ctrl_BS);  

% Enter: (make it distinguishable from ^M)
x_set_keysym(0xFF0D , 0,   Key_Return);
x_set_keysym(0xFF0D , '^', Key_Ctrl_Return);
x_set_keysym(0xFF0D , '$', Key_Shift_Return);

% TAB: 
x_set_keysym(0xFF09 , 0,   Key_Tab);
x_set_keysym(0xFF09 , '^', Key_Ctrl_Tab);
x_set_keysym(0xFF09 , '$', Key_Shift_Tab); % (reverse tab)
% unfortunately, Shift-Tab doesnot send any keystring in most X-Window setups.
% as it is bound to "ISO_Left_Tab", Keysym 0xFE20
%
% A line 
%      keycode 23 = Tab  
% in ~/.Xmodmap cured this problem before the advent of xkb in X11-4 
%
% For jed >= 99.16 one of the following should work:
% x_set_keysym(0xFE20, '$', Key_Shift_Tab);
% x_set_keysym(0xFE20, 0, Key_Shift_Tab);

% numeric keypad (without Num Lock)
x_set_keysym(0xFFAF , 0,   Key_KP_Divide);
x_set_keysym(0xFFAA , 0,   Key_KP_Multiply);
x_set_keysym(0xFFAB , 0,   Key_KP_Add);



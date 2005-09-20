% extended set of key variables for xjed
%
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% based on keydefs.sl (which itself goes back to Guido Gonzatos code in ide.sl)
% 
% special edition for xjed:
%   * skip code for wjed and konsole for faster loadup
%   * add some key definitions 
%     (Key_Escape, Key_Alt, Key_*_Return, Key_*_Tab, Key_KP_*)
%   
%   * calls x_set_keysym for "special_keys"
%   
% 1.1   2004-12-01  first public version
% 1.2   2004-12-03  merged files x-keydefs.sl and x-keysyms.sl
%                   with call to x_keydefs_hook for customization
% 1.3   2005-09-20  set Key_Alt_* in a loop
%                   
% USAGE / CUSTOMISATION
% 
% Place in the jed library path and do e.g.
% 
% if (is_defined("x_set_keysym"))  % xjed running
%    require("x-keydefs");   % symbolic keynames
% else
%    require("keydefs");
% 
% 
% If you want to use alternative key strings, define x_keydefs_hook(). e.g.
% 
% x_keydefs_hook()
% {
%    % change string values for Keys here, e.g.
%    Key_Return = "\e[8~";
%    Key_BS    = "\e[16~";
%    Key_Tab   = "\e[z";
%    % new definitions, e.g
%    global variable Key_Shift_Ctrl_Right = "\e[^c"
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
%
% unfortunately, Shift-Tab doesnot send any keystring in most X-Window setups.
% as it is bound to "ISO_Left_Tab", Keysym 0xFE20
%
% A line 
%      keycode 23 = Tab  
% in ~/.Xmodmap cured this problem before the advent of xkb in X11-4
%
% After the expansion of the keysym range, the following should work:
% x_set_keysym(0xFE20, '$', Key_Shift_Tab);


% no modifier
% -----------

variable Key_Up         = "\e[A";
variable Key_Down       = "\e[B";
variable Key_Right      = "\e[C";
variable Key_Left       = "\e[D";

variable Key_Tab        = "^I";    % alternative "\e[z"

variable Key_Home       = "\e[1~";
variable Key_Ins        = "\e[2~";
variable Key_Del        = "\e[3~";
variable Key_End        = "\e[4~";
variable Key_PgUp       = "\e[5~";
variable Key_PgDn       = "\e[6~";

variable Key_Return     = "^M";           % alternative "\e[8~"
variable Key_BS         = _Backspace_Key; % alternative "\e[16~"
variable Key_F1         = "\e[11~";
variable Key_F2         = "\e[12~";
variable Key_F3         = "\e[13~";
variable Key_F4         = "\e[14~";
variable Key_F5         = "\e[15~";
%                          \e[16~   % alternative to ^H or ^? for Key_BS
variable Key_F6         = "\e[17~";
variable Key_F7         = "\e[18~";
variable Key_F8         = "\e[19~";
variable Key_F9         = "\e[20~";
variable Key_F10        = "\e[21~";
%                          \e[22~
variable Key_F11        = "\e[23~";
variable Key_F12        = "\e[24~";

% Numeric Keypad  (without Num Lock, strings as in rxvt)
variable Key_KP_Return    = "\eOM";
variable Key_KP_Divide    = "\eOo"; % key sends  "/" by default
variable Key_KP_Multiply  = "\eOj"; % key sends "*"  by default
variable Key_KP_Subtract  = "\eOm"; 
variable Key_KP_Add       = "\eOk"; % key sends "+"  by default
variable Key_KP_Separator = "\eOn"; % key sends "\eOl" with Num Lock

variable Key_KP_0         = "\eOp";
variable Key_KP_1         = "\eOq";
variable Key_KP_2         = "\eOr";
variable Key_KP_3         = "\eOs";
variable Key_KP_4         = "\eOt";
variable Key_KP_5         = "\eOu";
variable Key_KP_6         = "\eOv";
variable Key_KP_7         = "\eOw";
variable Key_KP_8         = "\eOx";
variable Key_KP_9         = "\eOy";

% ALT keys
% --------

% (Some jed-versions (console) don' set ALT_CHAR)
custom_variable("ALT_CHAR", 27); % '\e'
variable Key_Alt          = char(ALT_CHAR);

% (loop is < 0.01 s slower than explicit coding but saves ~30 lines of code)
foreach(_apropos("Global", "^Key_[^A]", 8))
{
   $1 = ();
   custom_variable(strreplace($1, "_", "_Alt_", 1), pop(),
                   Key_Alt + @__get_reference($1));
}

% ESCAPE key
% ----------

variable Key_Esc       = "\e\e\e"; % triple Escape

% SHIFT keys
% ---------- 
 
variable Key_Shift_Up    = "\e[a";
variable Key_Shift_Down  = "\e[b";
variable Key_Shift_Right = "\e[c";
variable Key_Shift_Left  = "\e[d";
                         
variable Key_Shift_Tab   = "\e[Z";  % reverse_tab

variable Key_Shift_Home  = "\e[1$";
variable Key_Shift_Ins   = "\e[2$";
variable Key_Shift_Del   = "\e[3$";
variable Key_Shift_End   = "\e[4$";
variable Key_Shift_PgUp  = "\e[5$";
variable Key_Shift_PgDn  = "\e[6$";
                        
variable Key_Shift_Return = "\e[8$";
variable Key_Shift_BS    = "\e[16$";

variable Key_Shift_F1    = "\e[11$";
variable Key_Shift_F2    = "\e[12$";
variable Key_Shift_F3    = "\e[13$";
variable Key_Shift_F4    = "\e[14$";
variable Key_Shift_F5    = "\e[15$";
%        Key_Shift_BS    =  \e[16$
variable Key_Shift_F6    = "\e[17$";
variable Key_Shift_F7    = "\e[18$";
variable Key_Shift_F8    = "\e[19$";
variable Key_Shift_F9    = "\e[20$";
variable Key_Shift_F10   = "\e[21$";
variable Key_Shift_F11   = "\e[23$";
variable Key_Shift_F12   = "\e[24$";

% Ctrl keys
% ---------

variable Key_Ctrl_Up    = "\e[^A";
variable Key_Ctrl_Down  = "\e[^B";
variable Key_Ctrl_Right = "\e[^C";
variable Key_Ctrl_Left  = "\e[^D";

variable Key_Ctrl_Tab   = "\e[^Z";

variable Key_Ctrl_Home  = "\e[1^";
variable Key_Ctrl_Ins   = "\e[2^";
variable Key_Ctrl_Del   = "\e[3^";
variable Key_Ctrl_End   = "\e[4^";
variable Key_Ctrl_PgUp  = "\e[5^";
variable Key_Ctrl_PgDn  = "\e[6^";

variable Key_Ctrl_Return = "\e[8^";
variable Key_Ctrl_BS    = "\e[16^";

variable Key_Ctrl_F1    = "\e[11^";
variable Key_Ctrl_F2    = "\e[12^";
variable Key_Ctrl_F3    = "\e[13^";
variable Key_Ctrl_F4    = "\e[14^";
variable Key_Ctrl_F5    = "\e[15^";
%        Key_Ctrl_BS      "\e[16^"
variable Key_Ctrl_F6    = "\e[17^";
variable Key_Ctrl_F7    = "\e[18^";
variable Key_Ctrl_F8    = "\e[19^";
variable Key_Ctrl_F9    = "\e[20^";
variable Key_Ctrl_F10   = "\e[21^";
variable Key_Ctrl_F11   = "\e[23^";
variable Key_Ctrl_F12   = "\e[24^";

% ------------------ End of variable definitions ------------------------ 

runhooks("x_keydefs_hook");

% ------------------ Bind some more keys to keystrings ------------------


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

% numeric keypad (without Num Lock)
x_set_keysym(0xFFAF , 0,   Key_KP_Divide);
x_set_keysym(0xFFAA , 0,   Key_KP_Multiply);
x_set_keysym(0xFFAB , 0,   Key_KP_Add);


provide("keydefs");
provide("x-keydefs");  % enhanced set of key definitions

% extended set of key variables
%
%   * add key definitions 
%     (Key_Escape, Key_Alt, Key_*_Return, Key_*_Tab, Key_KP_*)
%     
%   * On xjed, call x_set_keysym for "special_keys"
%   
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
% 
% VERSIONS
%   
% 1.1   2004-12-01  first public version
% 1.2   2004-12-03  merged files x-keydefs.sl and x-keysyms.sl
%                   with call to x_keydefs_hook for customization
% 1.3   2005-09-20  set Key_Alt_* in a loop
% 1.4   2005-10-12  (re) use the definitions in standard keydefs.sl,
%                   let it work on "non-X" jed versions
%                   
% USAGE
% 
% Place in the jed library path.
% 
% To use it independend of a mode requiring it, do 
% (e.g. in your jed.rc or .jedrc file)
%
%    require("x-keydefs");
% 
% CUSTOMISATION | EXTENSION
% 
% If you want to use alternative key strings, define x_keydefs_hook(). e.g.
% 
%    x_keydefs_hook()
%    {
%       % Use the ESC key to compose Alt-something:
%       Key_Escape = "\e";
%       % Altenative keystring values:
%       Key_Return = "\e[8~";
%       Key_BS    = "\e[16~";
%       Key_Tab   = "\e[z";
%       % new definitions:
%       global variable Key_Shift_Ctrl_Right = "\e[^c"
%    }
%    
% In xjed, additional bindings can be enabled with x_set_keysym():   
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
% 
% Shift-Tab on X-Windows
% ----------------------
%
% Unfortunately, Shift-Tab doesnot send any keystring in most X-Window setups.
% as it is bound to "ISO_Left_Tab", Keysym 0xFE20
%
% A line 
%      keycode 23 = Tab  
% in ~/.Xmodmap cured this problem before the advent of xkb in X11-4
%
% After the expansion of the keysym range, the following should work:
% x_set_keysym(0xFE20, '$', Key_Shift_Tab);

% make sure we have tha basic definitions loaded:
% require("keydefs");
() = evalfile("keydefs");

provide("x-keydefs");  % eXtended set of key definitions

#ifdef IBMPC_SYSTEM

% TODO: add the IBMPC definitions here
#stop

#endif

% Alt and Escape
% --------------

% (Some jed versions (console) don' set ALT_CHAR)
custom_variable("ALT_CHAR", 27); % '\e'

variable Key_Alt          = char(ALT_CHAR);
variable Key_Esc          = "\e\e\e";       % triple Escape

% Tab
% ---

variable Key_Tab          = "^I";     % alternative "\e[z"
variable Key_Shift_Tab    = "\e[Z";   % reverse_tab
variable Key_Ctrl_Tab     = "\e[^Z";
variable Key_Alt_Tab      = strcat(Key_Alt, Key_Tab);


% Return
% ------ 

variable Key_Return       = "^M";     % alternative "\e[8~"
variable Key_Shift_Return = "\e[8$";
variable Key_Ctrl_Return  = "\e[8^";
variable Key_Alt_Return   = strcat(Key_Alt, Key_Return);


% Numeric Keypad
% --------------

% (without Num Lock, strings as in rxvt)
variable Key_KP_Return    = "\eOM";
variable Key_KP_Divide    = "\eOo";   % key sends  "/" by default
variable Key_KP_Multiply  = "\eOj";   % key sends "*"  by default
variable Key_KP_Subtract  = "\eOm"; 
variable Key_KP_Add       = "\eOk";   % key sends "+"  by default
variable Key_KP_Separator = "\eOn";   % key sends "\eOl" with Num Lock

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


% Customziation by hook
% ---------------------

runhooks("x_keydefs_hook");


% Additional keystrings with Xjed
% -------------------------------

% We need to trick the function check for non-X jed (we cannot use #ifdef XJED,
% as the byte-compiled file should be usable with jed on a console as well.)
private variable set_keysym_p = __get_reference("x_set_keysym");

if (is_defined("x_server_vendor"))
{
   % ESC (make it distinguishable from keys that start with \e
   @set_keysym_p(0xFF1B, 0,    Key_Esc);  
   
   % DEL (see also .jedrc for this topic)
   % (on my system it did not distinguish modifiers)
   @set_keysym_p(0xFFFF,  0,   Key_Del); 
   @set_keysym_p(0xFFFF , '$', Key_Shift_Del); 
   @set_keysym_p(0xFFFF , '^', Key_Ctrl_Del);  
   
   % Backspace:
   @set_keysym_p(0xFF08 , 0,   Key_BS);    
   @set_keysym_p(0xFF08 , '$', Key_Shift_BS);    
   @set_keysym_p(0xFF08 , '^', Key_Ctrl_BS);  
   
   % Return: (make it distinguishable from ^M)
   @set_keysym_p(0xFF0D , 0,   Key_Return);
   @set_keysym_p(0xFF0D , '^', Key_Ctrl_Return);
   @set_keysym_p(0xFF0D , '$', Key_Shift_Return);
   
   % TAB: 
   @set_keysym_p(0xFF09 , 0,   Key_Tab);
   @set_keysym_p(0xFF09 , '^', Key_Ctrl_Tab);
   % @set_keysym_p(0xFE20, '$', Key_Shift_Tab);
   
   % numeric keypad (without Num Lock)
   @set_keysym_p(0xFFAF , 0,   Key_KP_Divide);
   @set_keysym_p(0xFFAA , 0,   Key_KP_Multiply);
   @set_keysym_p(0xFFAB , 0,   Key_KP_Add);
}

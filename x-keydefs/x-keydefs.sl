% x-keydefs.sl: Extended set of key variables
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
% 1.5               prepare IBMPC support (incomplete, untested)
%                   set Key_Shift_Tab for xjed
% 1.5.1 2005-11-21  documentation fix (autoload get_keystring from strutils)
% 1.5.2 2006-01-17  documentation fix (warn about ESC redefinition, workaround)
% 1.5.3 2006-01-17  jed compatible default for Key_Esc ("\e" not "\e\e\e")
% 1.5.4 2006-01-18  added termcap entries for keypad keys (where possible)
% 1.5.5 2006-01-19  updated the IBMPC definitions (not fully tested yet)
%       
% USAGE
%
% Place in the jed library path.
%
% Do not byte-compile, if you plan to use this file for both, Unix and
% DOS/Windows from one libdir!
%
% To make the Key_Vars available, write (e.g. in your jed.rc or .jedrc file)
%
%    require("x-keydefs");
%
% !! Attention !!
% 
%   On xjed, `x_set_keysym' is used to make sure the keys send the
%   strings as defined here (or in the x_keydefs_hook() described below).
%   
%   While generally this leads to the expected behaviour with a
%   simple  require("x-keydefs"), some modes that define keybindings
%   without use of Key_* variales may break.
% 
% CUSTOMISATION | EXTENSION
%
% If you want to use alternative key strings, define x_keydefs_hook(). e.g.
%
%    define x_keydefs_hook()
%    {
%       % Let the ESC key send a triple "\e" (e.g. for "cua" emulation):
%       Key_Escape = "\e\e\e";
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
% autoload("get_keystring", "strutils");  % from jedmodes.sf.net
% public define showkey_literal()
% {
%    flush ("Press key:");
%    variable key = get_keystring();
%    if (prefix_argument(0))
%      insert (key);
%    else
%      {
% #ifdef XWINDOWS
%        key += sprintf(" X-Keysym: %X", X_LAST_KEYSYM);
% #endif
%        message ("Key sends " + key);
%      }
% }
%
% Attention: In JED <= 99.16, x_set_keysym() works only for keysyms in the
%            range `0xFF00' to `0xFFFF'.
%            Since JED 99.17 this restriction is gone.
%
% Shift-Tab on X-Windows
% ----------------------
%
% Unfortunately, Shift-Tab doesnot send any keystring in most X-Window setups.
% as it is bound to "ISO_Left_Tab", Keysym 0xFE20
%
% This is no longer an issue with jed >= 99.17. For jed < 99.17, a line
%      keycode 23 = Tab
% in ~/.Xmodmap can cure this problem. However, this doesnot work
% with xkb keyboard handling in X11-4
%
%
% TODO: test IBMPC keystrings, 
%       find keystrings for Ctrl-Shift Movement keys

% ----------------------------------------------------------------------------

% make sure we have the basic definitions loaded:
require("keydefs");

provide("x-keydefs");  % eXtended set of key definitions

% Auxiliary function to define symbolic keynames to count for different
% operating systems. (Extended version of the auxiliary fun in keydefs.sl
% including the ibmpc string.)
private variable Is_Xjed = is_defined("x_server_vendor");
static define set_keyvar(ibmpc, termcap, default)
{
#ifdef IBMPC_SYSTEM
   return ibmpc;
#endif
   if (Is_Xjed)
     return default;
#ifexists get_termcap_string
   variable s = get_termcap_string(termcap);
   if (s == "")
     return default;
   return s;
#else
   return default;
#endif
}

% Numeric Keypad
% --------------

% * variable names are chosen to match X-Window's keysymdef.h
% 
% * default strings as in rxvt without active Num Lock
%   and in X-Windows (where Num Lock only affects the string sent by [,|Del])
%   
% * By default, KP_Divide, KP_Multiply, and KP_Add send "/", "*", and "+" in 
%   xjed (their keysym does not change with Num Lock). 
%   x-keydefs.sl uses x_set_keysym to change this to the variables values
%   (therefore you should use the x_keydefs_hook() to change the value so xjed 
%   will see the changes)
% 
% * ibmpc strings correspond to VT220 codes
% 
% TODO: check IBMPC keystrings, if different use set_keyvar()

variable Key_KP_Return    = "\eOM";
variable Key_KP_Divide    = set_keyvar("\eOQ", "", "\eOo"); 
variable Key_KP_Multiply  = set_keyvar("\eOR", "", "\eOj"); 
variable Key_KP_Add       = set_keyvar("\eOm", "", "\eOk"); 
variable Key_KP_Subtract  = set_keyvar("\eOS", "", "\eOm"); 
variable Key_KP_Separator = "\eOl";   % numeric_comma: [,|Del] with Num Lock in X
variable Key_KP_Delete    = "\eOn";   % numeric_period: [,|Del] without Num Lock in X

variable Key_KP_0         = "\eOp";
variable Key_KP_1         = set_keyvar("\eOq", "K4", "\eOq");
variable Key_KP_2         = "\eOr";
variable Key_KP_3         = set_keyvar("\eOs", "K5", "\eOs");
variable Key_KP_4         = "\eOt";
variable Key_KP_5         = set_keyvar("\eOu", "K2", "\eOu");
variable Key_KP_6         = "\eOv";
variable Key_KP_7         = set_keyvar("\eOw", "K1", "\eOw");
variable Key_KP_8         = "\eOx";
variable Key_KP_9         = set_keyvar("\eOy", "K3", "\eOy");

% Alt and Escape
% --------------

% (Some jed versions (console) don' set ALT_CHAR)
custom_variable("ALT_CHAR", 27); % '\e'

variable Key_Alt          = set_keyvar("", "", char(ALT_CHAR));
% cua emulation uses triple escape ("\e\e\e") as Esc key string.
custom_variable("Key_Esc", set_keyvar("", "", "\e"));

% Tab
% ---

variable Key_Tab          = set_keyvar("^I", "", "^I");    % alternative "\e[z"
variable Key_Shift_Tab    = set_keyvar("^@^O", "", "\e[Z");  % reverse_tab
variable Key_Ctrl_Tab     = set_keyvar("", "", "\e[^Z");
variable Key_Alt_Tab      = set_keyvar("", "", strcat(Key_Alt, Key_Tab));

% Return
% ------

variable Key_Return       = set_keyvar("^M", "", "^M");    % alternative "\e[8~"
variable Key_Shift_Return = set_keyvar("", "", "\e[8$");
variable Key_Ctrl_Return  = set_keyvar("^J", "", "\e[8^");
variable Key_Alt_Return   = set_keyvar("", "", strcat(Key_Alt, Key_Return));


% Shift-Control Movement Keys
% ---------------------------

% TODO: find keystrings
% variable Key_Ctrl_Shift_Up      = set_keyvar("", "", "\e[%A");
% variable Key_Ctrl_Shift_Down    = set_keyvar("", "", "\e[%B");
% variable Key_Ctrl_Shift_Right   = set_keyvar("", "", "\e[%C");
% variable Key_Ctrl_Shift_Left    = set_keyvar("", "", "\e[%D");
variable Key_Ctrl_Shift_Home    = set_keyvar("", "", "\e[1%");
variable Key_Ctrl_Shift_End     = set_keyvar("", "", "\e[4%");
variable Key_Ctrl_Shift_PgUp    = set_keyvar("", "", "\e[5%");
variable Key_Ctrl_Shift_PgDn    = set_keyvar("", "", "\e[6%");


% Customziation by hook
% ---------------------

runhooks("x_keydefs_hook");

% abort here, if we are on DOS or Windows
#ifdef IBMPC_SYSTEM
#stop
#endif

% Additional keystrings with Xjed
% -------------------------------

% We need to trick the function check for non-X jed (we cannot use #ifdef XJED,
% as the byte-compiled file should be usable with jed on a console as well.)
private variable x_set_keysym_p = __get_reference("x_set_keysym");

if (is_defined("x_server_vendor"))
{
   % ESC (make it distinguishable from keys that start with \e
   @x_set_keysym_p(0xFF1B, 0,    Key_Esc);

   % DEL (see also .jedrc for this topic)
   % (on my system it did not distinguish modifiers)
   @x_set_keysym_p(0xFFFF,  0,   Key_Del);
   @x_set_keysym_p(0xFFFF , '$', Key_Shift_Del);
   @x_set_keysym_p(0xFFFF , '^', Key_Ctrl_Del);

   % Backspace:
   @x_set_keysym_p(0xFF08 , 0,   Key_BS);
   @x_set_keysym_p(0xFF08 , '$', Key_Shift_BS);
   @x_set_keysym_p(0xFF08 , '^', Key_Ctrl_BS);

   % Return: (make it distinguishable from ^M)
   @x_set_keysym_p(0xFF0D , 0,   Key_Return);
   @x_set_keysym_p(0xFF0D , '^', Key_Ctrl_Return);
   @x_set_keysym_p(0xFF0D , '$', Key_Shift_Return);

   % TAB:
   @x_set_keysym_p(0xFF09 , 0,   Key_Tab);
   @x_set_keysym_p(0xFF09 , '^', Key_Ctrl_Tab);
#ifeval (_jed_version >= 9917)
   @x_set_keysym_p(0xFE20, '$',  Key_Shift_Tab);
#endif

   % numeric keypad (keys whose keysym does not change with Num Lock)
   @x_set_keysym_p(0xFFAA , 0,   Key_KP_Multiply);
   @x_set_keysym_p(0xFFAB , 0,   Key_KP_Add);
   @x_set_keysym_p(0xFFAF , 0,   Key_KP_Divide);
   
   % Shift-Control Movement Keys
   @x_set_keysym_p(0xFF50 , '%', Key_Ctrl_Shift_Home);
   % @x_set_keysym_p(0xFF51 , '%', Key_Ctrl_Shift_Left);
   % @x_set_keysym_p(0xFF52 , '%', Key_Ctrl_Shift_Up);
   % @x_set_keysym_p(0xFF53 , '%', Key_Ctrl_Shift_Right);
   % @x_set_keysym_p(0xFF54 , '%', Key_Ctrl_Shift_Down);
   @x_set_keysym_p(0xFF55 , '%', Key_Ctrl_Shift_PgUp);   
   @x_set_keysym_p(0xFF56 , '%', Key_Ctrl_Shift_PgDn);           
   @x_set_keysym_p(0xFF57 , '%', Key_Ctrl_Shift_End);  
   
}

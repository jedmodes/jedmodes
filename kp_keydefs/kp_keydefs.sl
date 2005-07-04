% kp_keydefs.sl
% 
% Extends keydefs.sl with symbolic keynames for the numeric keypad
% Only tested under Linux with PC Keyboard and X-Windows.
% 
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 1.1 2005-07-04 


% Define symbolic keynames 
static define set_keyvar (ibmpc, termcap, default)
{
#ifdef IBMPC_SYSTEM
     return ibmpc;
#endif
#ifdef XWINDOWS
     return default;
#endif
#ifexists get_termcap_string
   variable s = get_termcap_string (termcap);
   if (s == "")
     return default;
   return s;
#else
   return default;
#endif
}

% Numeric Keypad  (without Num Lock)
variable Key_KP_0         = set_keyvar ("\eOp", "",   "\eOp");
variable Key_KP_1         = set_keyvar ("\eOq", "K4", "\eOq");
variable Key_KP_2         = set_keyvar ("\eOr", "",   "\eOr");
variable Key_KP_3         = set_keyvar ("\eOs", "K5", "\eOs");
variable Key_KP_4         = set_keyvar ("\eOt", "",   "\eOt");
variable Key_KP_5         = set_keyvar ("\eOu", "K2", "\eOu");
variable Key_KP_6         = set_keyvar ("\eOv", "",   "\eOv");
variable Key_KP_7         = set_keyvar ("\eOw", "K1", "\eOw");
variable Key_KP_8         = set_keyvar ("\eOx", "K3", "\eOx");
variable Key_KP_9         = set_keyvar ("\eOy", "",   "\eOy");
variable Key_KP_Enter     = set_keyvar ("\eOM", "",   "\eOM");
variable Key_KP_Separator = set_keyvar ("\eOn", "",   "\eOn");
variable Key_KP_Add       = set_keyvar ("\eOm", "",   "\eOm");
variable Key_KP_Subtract  = set_keyvar ("\eOS", "",   "\eOS");
variable Key_KP_Multiply  = set_keyvar ("\eOR", "",   "\eOR");
variable Key_KP_Divide    = set_keyvar ("/",    "",   "\eOT");
                                                 
% TODO: find sensible XWin default values for these
variable Key_Shift_Tab  = set_keyvar ("^@^O",    "bt", "\e[Z");  % reverse_tab
variable Key_Shift_BS   = set_keyvar ("\x08",    "",  "\e[16$");
                                                   
variable Key_Ctrl_Tab   = set_keyvar ("^@\d148",    "", "\e[009^");
variable Key_Ctrl_BS    = set_keyvar ("\e@",        "", "\e[16^" );

% We no longer need this
static define set_keyvar ();

#ifdef XWINDOWS
% On X-Windows, for otherwise unindentified keys we can set the keysyms
% via x_set_keysysm.
% DEL (see also the original .jedrc for this topic)
x_set_keysym (0xFFFF,   0, Key_Del);
x_set_keysym (0xFFFF, '$', Key_Shift_Del);
x_set_keysym (0xFFFF, '^', Key_Ctrl_Del);    
% Backspace: I just used a "spare" string. is there a sensible default string?
x_set_keysym (0xFF08, '$', Key_Shift_BS);
x_set_keysym (0xFF08, '^', Key_Ctrl_BS);    
% TAB: unfortunately, Shift-Tab doesnot send any keystring in my
% X-Windows as it is set to ISO_Left_Tab. A line
%      keycode 23 = Tab
% in ~/.Xmodmap cures this problem. Now the following works
% x_set_keysym (0xFF09, '$', Key_Shift_Tab);  %  (reverse tab)
x_set_keysym (0xFF09, '^', Key_Ctrl_Tab);   % (is there a default?)

% Keypad: On Unix, KP +, * , / come through as-is
x_set_keysym(0xFFAB, 0, Key_KP_Add); 
x_set_keysym(0xFFAA, 0, Key_KP_Multiply);
x_set_keysym(0xFFAF, 0, Key_KP_Divide);



#endif


provide ("kp_keydefs");

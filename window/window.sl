% Window management routines.
%
% Copyright (c) 2004 Marko Mahnic
% Released under the terms of the GNU General Public License (ver. 2 or later)
% 


%!%+
%\variable{WindowInfo_Type}
%\synopsis{struct WindowInfo_Type}
%\usage{list = @WindowInfo_Type}
%\description
% A linked list that describes each window.
% 
% The head element describes the screen (the biggest window). 
% Each 'line' of the screen represents a window.
% 
% The following elements describe the windows in top-down order.
% The minibuffer is not included in the list.
%!%-
!if (is_defined ("WindowInfo_Type"))
{
   typedef struct
   {
      height,
      buffer,
      line,
      offs,
      next
   } WindowInfo_Type;
}

static variable Windows = NULL;


%!%+
%\function{select_top_window}
%\synopsis{Select the window at the top of the screen}
%\usage{Void select_next_window()}
%\description
% Select the window at the top of the screen.
% 
%\seealso{select_prev_window, select_next_window, select_bottom_window}
%!%-
define select_top_window()
{
   variable i;
   for (i = nwindows(); i > 0; i--)
   {
      if (TOP_WINDOW_ROW == window_info('t')) break;
      otherwindow();
   }
}


%!%+
%\function{select_bottom_window}
%\synopsis{Select the window at the bottom of the screen}
%\usage{Void select_next_window()}
%\description
% Select the window at the bottom of the screen. 
% The minibuffer is never selected even if it is active.
% 
%\seealso{select_prev_window, select_next_window, select_top_window}
%!%-
define select_bottom_window()
{
   variable togo = nwindows() - 1;
   if (MINIBUFFER_ACTIVE) togo--;
   
   select_top_window();
   if (togo > 0)
   {
      while (togo > 0)
      {
         otherwindow();
         togo--;
      }
   }
}

%!%+
%\function{select_next_window}
%\synopsis{Select the next window}
%\usage{Void select_next_window()}
%\description
% Select the next window. Same as otherwindow().
% 
%\seealso{select_prev_window, select_top_window, select_bottom_window}
%!%-
define select_next_window()
{
   otherwindow();
}


%!%+
%\function{select_prev_window}
%\synopsis{Select the previous window}
%\usage{Void select_prev_window()}
%\description
% Select the previous window.
% 
%\seealso{select_next_window, select_top_window, select_bottom_window}
%!%-
define select_prev_window()
{
   variable i;
   for (i = nwindows() - 1; i > 0; i--) otherwindow();
}

%!%+
%\function{select_window}
%\synopsis{Select the nth. window from top}
%\usage{}
%\description
% Select the nth. window from top. 
% The top window is #1.
% 
% \seealso{what_window, nwindows}
%!%-
define select_window(n)
{
   if (n < 1) n = 1;
   n = (n - 1) mod nwindows();
   select_top_window();
   loop(n) otherwindow();
}

%!%+
%\function{what_window}
%\synopsis{Return the number of the current window}
%\usage{Integer_Type what_window()}
%\description
% Return the number of the current window. Windows are numbered
% from 1 to nwindows(). The top window is #1.
% 
% \seealso{select_window, nwindows}
%!%-
define what_window()
{
   variable curwin = window_info('t');
   variable n = 1;
   select_top_window();
   while (window_info('t') != curwin)
   {
      otherwindow();
      n++;
   }
   
   return n;
}

%!%+
%\function{save_windows}
%\synopsis{Save window configuration with buffer positions}
%\usage{WindowInfo_Type save_windows ()}
%\description
% Save window configuration with buffer positions.
% 
%\returns
% Linked list of window information (WindowInfo_Type).
%\seealso{restore_windows}
%!%-
define save_windows ()
{
   variable curwin = window_info('t');
   variable list, pwin;

   % Save screen
   list = @WindowInfo_Type;
   list.height = SCREEN_HEIGHT;
   list.line = what_window();
   list.next = @WindowInfo_Type;
   
   select_top_window();
   
   % Save first window
   pwin = list.next;
   pwin.next = NULL;
   pwin.height = window_info('r');
   pwin.buffer = whatbuf();
   pwin.line = what_line();
   pwin.offs = window_line();
   
   
   % Save other windows
   otherwindow();
   while (window_info('t') != TOP_WINDOW_ROW)
   {
      if (window_info('t') >= SCREEN_HEIGHT - 1) % minibuffer
      {
         otherwindow();
         continue;
      }
      
      pwin.next = @WindowInfo_Type;
      pwin = pwin.next;
      pwin.next = NULL;
      pwin.height = window_info('r');
      pwin.buffer = whatbuf();
      pwin.line = what_line();
      pwin.offs = window_line();
    
      otherwindow();
   }
   
   % Activate current window
   if (curwin != TOP_WINDOW_ROW)
   {
      otherwindow();
      while ((window_info('t') != curwin) and (window_info('t') != TOP_WINDOW_ROW))
         otherwindow();
   }
   
   return list;
}


%!%+
%\function{restore_windows}
%\synopsis{Restore a previously saved configuration of windows}
%\usage{Void restore_windows(WindowInfo_Type list)}
%\description
% Restore a configuration of windows that was previously stored
% with save_windows().
% 
%\seealso{save_windows} 
%!%-
define restore_windows(list)
{
   if (list == NULL) return;
   if (list.next == NULL)
   {
      onewindow();
      return;
   }
   
   variable pwin;
   variable i, diff;
   
   pwin = list.next;

   % create all windows
   onewindow();
   while (pwin.next != NULL)
   {
      splitwindow();
      pwin = pwin.next;
   }
   
   select_bottom_window();
   diff = (SCREEN_HEIGHT - nwindows()) - window_info('r');
   for (i = 0; i < diff; i++) enlargewin();

   % restore window state
   select_top_window();
   pwin = list.next;
   
   while (pwin != NULL)
   {
      diff = pwin.height - window_info('r');
      
      if (diff > 0) for (i = 0; i < diff; i++) enlargewin();
      
      if (bufferp(pwin.buffer))
      {
         sw2buf(pwin.buffer);
         goto_line(pwin.line);
         recenter(pwin.offs);
      }
      
      otherwindow();
      pwin = pwin.next;
   }
   
   % Restore active window
   select_window(list.line);
}

%!%+
%\function{save_windows_cmd}
%\synopsis{Save window configuration with buffer positions into a local variable}
%\usage{Void save_windows_cmd()}
%\description
% Save window configuration with buffer positions into a local variable.
% 
% Suitable for a menu entry.
% 
% \seealso{restore_windows_cmd, save_windows}
%!%-
define save_windows_cmd()
{
   Windows = save_windows();
}


%!%+
%\function{restore_windows_cmd}
%\synopsis{Restore a previously saved configuration of windows}
%\usage{Void restore_windows_cmd()}
%\description
% Restore a previously saved configuration of windows. The configuration
% must have been stored with save_windows_cmd().
% 
% Suitable for a menu entry.
% 
% \seealso{save_windows_cmd, restore_windows}
%!%-
define restore_windows_cmd()
{
   restore_windows(Windows);
}


static define do_create_windows(nwin)
{
   variable i, s, diff, ifill;
   variable wins;
   
   if (nwin == 0) onewindow();
   if (nwin == 1)
   {
      pop();
      onewindow();
   }
   if (nwin < 2) return;
   
   wins = Integer_Type[nwin];

   % Create windows
   onewindow();
   for (i = 0; i < nwin - 1; i++) splitwindow();
   
   % Read window info and find the 'elastic' window
   ifill = -1;
   for (i = 0; i < nwin; i++)
   {
      s = ();
      wins[nwin - 1 - i] = s;
      if (ifill < 0 and s == 0) ifill = i;
   }
   
   if (ifill < 0) ifill = nwin - 1;
   
   % Enlarge the elastic window to max size
   select_top_window();
   for (i = 0; i < ifill; i++) otherwindow();
   for (i = 0; i < SCREEN_HEIGHT - nwindows(); i++) enlargewin();
   
   % Enlarge other windows
   otherwindow();
   if (window_info('t') >= SCREEN_HEIGHT - 1)
      otherwindow();
   ifill = (ifill + 1) mod nwin;
   
   for (i = 0; i < nwin; i++) 
   {
      if (wins[ifill] > 1)
      {
         diff = wins[ifill] - window_info('r');
         while (diff > 0) 
         {
            enlargewin();
            diff--;
         }
      }

      otherwindow();
      if (window_info('t') >= SCREEN_HEIGHT - 1)  % minibuffer
         otherwindow();
      ifill = (ifill + 1) mod nwin;
   }
}


% Create windows with sizes passed in parameters.
% 0 means: whatever is left
%!%+
%\function{create_windows}
%\synopsis{Create a configuration of windows with the desired sizes}
%\usage{Void create_windows(Integer_Type s0, Integer_Type s1 [, ...]) }
%\description
% Create a configuration of windows with the desired sizes. 
% Window sizes are defined top to bottom (s0 for topmost window).
% 
% The first window with a desired size of 0 will be 'elastic' - 
% it's size will shrink or grow so that other windows.
% 
% If none of the parameters sX is 0, the bottom window will be 
% elastic.
% 
%\example
%#v+
%   create_windows(7, 0, 3) 
%#v-
%  will create 3 windows: 
%    * the topmost will have 7 lines
%    * the bottom one will have 3 lines
%    * the middle window will take whatever is left
% 
%\notes
% If the screen is too small, the function may fail.
% 
%\seealso{create_windows_rel, save_windows, restore_windows}
%!%-
define create_windows()
{
   do_create_windows(_NARGS);
}


%!%+
%\function{create_windows_rel}
%\synopsis{Create a configuration of windows with the desired relative sizes }
%\usage{Void create_windows_rel(Integer_Type s0, Integer_Type s1 [, ...]) }
%\description
% Create a configuration of windows with the desired relative sizes. All sizes
% must be equal or greater than 1.
% 
%\example
%#v+
%   create_windows(30, 60, 10) 
%#v-
%  will create 3 windows: 
%    * the topmost one will be 20% of total height
%    * the middle one will be 60% of total height
%    * the bottom one will be 10% of total height
%    
%\seealso{create_windows, save_windows, restore_windows}
%!%-
define create_windows_rel()
{
   variable wins, sum, i, vislines, nwin;
   
   if (_NARGS == 0) onewindow();
   if (_NARGS == 1)
   {
      pop();
      onewindow();
   }
   if (_NARGS < 2) return;
   
   
   % Read parameters from stack - only values >= 1
   wins = Integer_Type[_NARGS];
   _stk_reverse(_NARGS);

   nwin = 0;
   for (i = 0; i < _NARGS; i++)
   {
      wins[nwin] = ();
      if (wins[nwin] >= 1) nwin++;
   }
   
   if (nwin < 2)
   {
      onewindow();
      return;
   }

   % Calculate window sizes
   vislines = SCREEN_HEIGHT - 1 - (TOP_WINDOW_ROW - 1) - nwin;
   sum = 0;
   for (i = 0; i < nwin; i++) sum += wins[i];
   for (i = 0; i < nwin; i++)
   {
      wins[i] = int(1.0 * vislines * wins[i] / sum + 0.5);
      if (wins[i] < 2) wins[i] = 2;
   }

   % Fixup
   sum = 0;
   for (i = 0; i < nwin; i++) sum += wins[i];
   while (sum > vislines)
   {
      variable max = 2, imax;
      for (i = 0; i < nwin; i++)
      {
         if (wins[i] > max)
         {
            imax = i;
            max = wins[i];
         }
      }
      if (max <= 2) break;
      else
      {
         wins[imax]--;
         sum--;
      }
   }

   % Create windows
   for (i = 0; i < nwin; i++) wins[i];
   do_create_windows(nwin);
}



% ----------------------------------------------------------
% Demo/Testing code
% ----------------------------------------------------------
#iffalse
define pause(m)
{
   vmessage("Pause: %s", m);
   update(1);
   () = getkey();
}

define dump_windows(list)
{
   variable pwin = list;
   variable buf = whatbuf();
   
   setbuf("*scratch*");
   eob();
   
   insert ("\n");
   while (pwin != NULL)
   {
      vinsert("%d (L:%d C:%d B:%s) ", pwin.height, pwin.line, pwin.offs, pwin.buffer);
      pwin = pwin.next;
   }
   
   setbuf(buf);
}

define Test()
{
   variable Current;
   variable TestWin1;
   variable TestWin2;

   Current = save_windows();
   dump_windows(Current);
   
   create_windows_rel (30, 30, 30);
   select_top_window();
   bob();
   select_next_window();
   eob();
   TestWin1 = save_windows();
   create_windows_rel (20, 20, 60);
   TestWin2 = save_windows();
   create_windows_rel (10, 20, 30, 40);
   save_windows_cmd();

   % dump_windows(TestWin1);
   % dump_windows(TestWin2);
   % dump_windows(Windows);

   onewindow();
   pause("onewindow");
   restore_windows(TestWin1);
   pause("TestWin1: 30, 30, 30");
   restore_windows(TestWin2);
   pause("TestWin1: 20, 20, 60");
   restore_windows_cmd();
   pause("Internal: 10, 20, 30, 40");
   
   restore_windows(Current);
}

Test();

#endif

provide("window");

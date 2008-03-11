% folding-keypad-bindings.sl: Numpad Keybindings for Folding Mode
% ===============================================================
% 
% Copyright (c) 2007 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
% 
% Versions
% ========
% 0.1 2008-03-10  First evaluation version. Keybindings and behaviour are
%                 subject to change after "road testing".
% 
% Usage
% =====
% Place in the jed library path.
% 
% Set the keybindings in a hook, e.g. in jed.rc:
% 
% |   autoload("folding_keypad_bindings", "folding-keypad-bindings");
% |   define fold_mode_hook(mode)
% |   {
% |      folding_keypad_bindings();
% |   }
% 
% Bindings 
% ========
% 
% All key-bindings are on the numeric keypad (Key_KP_*).
%  
% Motion Commands
% ---------------
% :2/Down:  Move down to the next visible fold heading.
% :8/Up:    moves similarly backward.
% :4/Left:  Move up to the fold heading of the containing fold.
%           (not implemented yet).
% :6/Right: Move down to the next (maybe ivisible) fold heading and unhide it.
%    
% Outline Visibility Commands
% ---------------------------
% Global commands
% """""""""""""""
% folding the whole buffer.
% With a numeric argument n, they hide everything except the
% top n levels of heading lines.
% 
% local_setkey("fold_whole_buffer",        Key_KP_Delete); % hide-body
% local_setkey("fold_open_buffer",         Key_KP_0);      % show-all
% 
% 
% :,/Del: Fold whole buffer. 
% :0/Ins: Unfold buffer (make all lines visible).
% 
% Subtree commands
% """"""""""""""""
% Not implemented yet.
% 
% :+:  increase, and
% :-:  decrease the "verbosity" (level of headings shown).
% 
% Local commands
% """"""""""""""
% 
% Apply only to the body lines of that heading. 
% Sub-folds are not affected.
% 
% :5:     Hide or show body under this heading (fold_toggle_fold).
% :Enter: Open fold and narrow the buffer to it. (fold_enter_fold).
% 
% 
% Requirements
% ------------
% ::

_autoload("fold_whole_buffer", "folding",
          "fold_open_buffer", "folding",
          "fold_close_fold", "folding",
          "fold_open_fold", "folding",
          "fold_search_backward", "folding",
          "fold_search_forward", "folding",
          "fold_get_marks", "folding",
          7);

% Auxiliary functions
% -------------------
% ::
  
# ifexists Test
% get (or guess) the current fold-level
private define get_fold_level()
{
   variable fold_start, fold_end;
   (fold_start, fold_end, , ) = fold_get_marks();
   variable max_level=1, level=1;

   push_spot_bob();
   while (pcre_fsearch(sprintf("(%s|%s)", 
                               fold_start_pattern, fold_end_pattern))) {
      if (is_line_hidden()) 
         continue;
      go_down_1();
      if (is_line_hidden()) {
         skip_hidden_lines_forward(1);
         continue;
      } 
      if ffind(fold_start)
         level++;
      else
         max_level = nint(_max(max_level, level));
      level--;
   }
   pop_spot();
   % show(nint(_max(max_level, level)));
   return nint(_max(max_level, level));
}

% Change the fold-leve of the current buffer by `incr'
define fold_increment_level(incr)
{
   variable level = get_fold_level() + incr;
   set_prefix_argument(level);
   fold_whole_buffer();
   vmessage("fold-level %d", level);
}
#endif

% close fold if open, open fold if closed
define fold_toggle_fold()
{
   !if (down_1())
      return;
   variable is_hidden = is_line_hidden();
   go_up_1();
   
   if (is_hidden)
      fold_open_fold();
   else
      fold_close_fold();
}

% find next fold marker, return success
private define fold_fsearch_start()
{   
   % TODO: regexp search for "fold_start ... end_of_start"
   variable fold_start, end_of_start;
   (fold_start, , end_of_start, ) = fold_get_marks();
   eol();
   return fsearch(fold_start);
}

% find previous fold marker, return success
private define fold_bsearch_start()
{   
   % TODO: regexp search for "fold_start ... end_of_start"
   variable fold_start, end_of_start;
   (fold_start, , end_of_start, ) = fold_get_marks();
   return bsearch(fold_start);
}

% goto next fold-mark starte and make it visible
define fold_next_fold()
{
   !if (fold_fsearch_start())
      eob();
   set_line_hidden(0);
}

% goto next visible fold-start marker
define fold_next_visible_fold()
{
   while (fold_fsearch_start()) {
      !if (is_line_hidden()) 
         return;
   }
   % message("Last fold");
   eob();
}

% goto previous visible fold marker
define fold_previous_visible_fold()
{
   while (fold_bsearch_start) 
      !if (is_line_hidden())
         return;
   % message("First fold");
   bob();
}

% Bind Keypad Keys
% ----------------
% ::

define folding_keypad_bindings()
{
   % Motion Commands
   local_setkey("fold_next_visible_fold",     Key_KP_2); % Down
   local_setkey("fold_previous_visible_fold", Key_KP_8); % Up
   % local_setkey("fold_up_fold",             Key_KP_4); % Left
   local_setkey("fold_next_fold",             Key_KP_6); %
 
   % Outline Visibility Commands
   
   % global
   local_setkey("fold_whole_buffer",        Key_KP_Delete); % hide-body
   local_setkey("fold_open_buffer",         Key_KP_0);      % show-all
   
   % subtree
   % local_setkey("fold_increment_level(-1)", Key_KP_Subtract); % decrease level
   % local_setkey("fold_increment_level(1)",  Key_KP_Add);      % increase level
   
   % local
   local_setkey("fold_toggle_fold",         Key_KP_5); % hide-entry|show-entry
   local_setkey("fold_enter_fold",          Key_KP_Enter);
   % local_setkey("",                       Key_KP_6);  % > 
}

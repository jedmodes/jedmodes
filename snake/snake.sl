% snake.sl
% Eat the apples and stay away from the walls
% 
% $Id: snake.sl,v 1.1 2004/03/11 10:09:51 paul Exp paul $
% Keywords: games
%
% Copyright (c) 2004 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).

if (_featurep("snake"))
  use_namespace("snake");
else
  implements("snake");
provide("snake");

autoload("get_keystring", "strutils");

custom_variable("Snake_Use_DFA", 1);
custom_variable("Snake_Initial_Number_Apples", 50);

%{{{ Syntax Highlighting

#ifdef HAS_DFA_SYNTAX
create_syntax_table ("snake");
custom_color("snake", "green", "green");
custom_color("snake_border", "blue", "blue");
%%% DFA_CACHE_BEGIN %%%
static define setup_dfa_callback (mode)
{
   dfa_define_highlight_rule("O", "snake", mode);
   dfa_define_highlight_rule("[\\-\\|\\+\\`\\'\\,]", "snake_border", mode);
   dfa_build_highlight_table(mode);
}
dfa_set_init_callback (&setup_dfa_callback, "snake");
%%% DFA_CACHE_END %%%

#endif
%}}}

%{{{ snake variables

% It is a little known fact of herpetology that snakes are made of
% segments.
!if (is_defined("Segment_Type"))
{
   typedef struct
     {
	next,
	  prev,
	  x, y
     } Segment_Type;
}

variable snake = @Segment_Type,
  tail,
  score=0,
  grow=0,
  number_apples = 0;

%}}}

%{{{ drawing

% Create a segment.
define draw_segment(segment)
{
   variable update_score = 0;
   goto_line(segment.y);
   goto_column(segment.x);
   !if (looking_at_char(' '))
     {
	if (looking_at_char('*'))
	  {
	     score++;
	     update_score = 1;
	     grow += 3;
	  }
	else
	  return 0;
     }
   
   del;
   insert_char('O');

   if (update_score)
     {
	number_apples--;
	eob; bol; del_eol; vinsert("Score: %04d\t apples: %d", score, number_apples);
	!if (number_apples) return -1;
     }
   
   bob;
   return 1;
}

define place_apple()
{
   do
     {
	goto_line(2 + random(0, 19));
	goto_column(11 + random(0, 59));
     } while (not(looking_at_char(' ')));
   del();
   insert_char('*');
   number_apples++;
}

%}}}

%{{{ moving

% Move the snake.  This is achieved by moving the snake's tail segment to
% its head.  This was inspired by a National Geographic Channel special
% on the hidden life of snakes.
define snake_move(x,y)
{
   variable segment;
   if (grow)
     {
	segment = @Segment_Type;
	grow--;
     }
   else
     {
	goto_line(tail.y);
	goto_column(tail.x);
	del;
	insert_char(' ');
	segment = tail;
	tail = segment.prev;
	segment.prev = NULL;
     }
   segment.next = snake;
   snake.prev = segment;
   snake = segment;
   segment.x=x;
   segment.y=y;
   return draw_segment(segment);
}



%}}}

%{{{ initialisation

% Place some apples.
define draw_apples()
{
   () = random(-1, 10);
   loop(Snake_Initial_Number_Apples)
     place_apple;
}

define init_snake(x,y)
{
   snake.x = x;
   snake.y = y;
   tail = snake;
   ()=draw_segment(snake);
}

%}}}

%{{{ snake

%!%+
%\function{snake}
%\synopsis{race against time eating apples}
%\usage{snake()}
%\description
%   A snake game with a twist: every 5 seconds, an apple is placed on the
%   field.  To win, you have to eat all the apples and avoid banging into
%   the wall.  You can run by keeping the arrow keys pressed.
%   Custom Variables:
%   \var{Snake_Initial_Number_Apples} = 50; The number of apples the game starts with.
%   \var{Snake_Use_Dfa} = 1: determines if the snake should be drawn
%     using DFA syntax highlighting
%   You can set the color of the snake and the wall with
%#v+
%  custom_color("snake", "red", "red");
%  custom_color("snake_border", "black", "black");
%#v-
%\seealso{custom_color}
%!%-
public define snake()
{
   score = 0;
   grow = 5;
   number_apples = 0;
   sw2buf("*snake*");
   onewindow;
   erase_buffer;
   if (Snake_Use_DFA)
     {
	use_syntax_table("snake");
	use_dfa_syntax(1);
     }
   % grid is 20 * 60
   insert
     ("         ,------------------------------------------------------------+\n");
   loop(20)insert
     ("         |                                                            |\n");
   insert
     ("         `------------------------------------------------------------'\n");
   
   % draw some apples. The playing field runs from column 10 to 69
   % and line 4 to 24
   draw_apples();
   
   eob; vinsert("Score: %04d", score);

   bob;
   recenter(1);
   variable x = 20, y = 15, ch, dir = 1, delay, 
   timer = _time;
   init_snake(x,y);
   EXIT_BLOCK
     {
	set_buffer_modified_flag(0);
     }
   
   forever
     {
	switch(dir)
	  {case 1: x++;}
	  {case -1: x--;}
	  {case 2: y++;}
	  {case -2: y--;}
	if ((_time > timer + 5))
	     {
		place_apple;
		timer = _time;
	     }
	     
	switch (snake_move(x,y))
	  { case -1:  eob; insert ("\t\tyou win!");return;}
	  { case 0: eob; insert ("\t\tyou lose!"); return;}
	update_sans_update_hook(1);
	if (dir == 2 or dir == -2) delay = 2;
	else delay = 1;
	!if (input_pending(delay)) continue;
	ch = get_keystring;
	% debug
	% message(ch);
	% ch;
	% switch (ch)
	%   {case Key_Left: dir = -1;}
	%   {case Key_Right: dir = 1;}
	%   {case Key_Up: dir = -2;}
	%   {case Key_Down: dir = 2;}
	%   {case "q": return;}
	if (ch == "q") return;
	(,ch) = get_key_binding (ch); 
	switch (ch)
	  {case "previous_char_cmd": dir = -1;}
	  {case "next_char_cmd": dir = 1;}
	  {case "previous_line_cmd": dir = -2;}
	  {case "next_line_cmd": dir = 2;}
     }
}

%}}}


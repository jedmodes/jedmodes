% -------------------------------------------- -*- mode:Slang; mode:folding -*-
%
% CONWAY'S GAME OF LIFE
%
% $Id: life.sl,v 1.13 2000/04/07 12:36:30 rocher Exp $
%
% --------------------------------------------------------------------- %{{{
%
% DESCRIPTION
%	An implementation of the Game of Life for jed.
%
% USAGE
%	() = evalfile ("life"); life ();
%
% AUTHORS
%	John E. Davis <davis@space.mit.edu>
%	Francesc Rocher <f.rocher@computer.org>
%	Feel free to send comments, suggestions or improvements.
%
% ------------------------------------------------------------------------ %}}}

implements ("life");

% PRIVATE VARIABLES           %{{{

private variable
   height      = SCREEN_HEIGHT-4,
   width       = SCREEN_WIDTH-2,
   cell        = Char_Type[width, height],
   top_line    = "",
   bottom_line = "",
   msg         = "space:start/stop   n:next   c:clear   o:draw   r:random   -,0,+:delay   q:quit",
   dollar      = 0,
   delay       = 150,
   left, right, up, down;

%}}}


% PRIVATE FUNCTIONS

private define life_dump  ()  %{{{
{
   variable y, s = Char_Type [width, height];

   s [*,*] = ' ';
   s [where (cell)] = 'o';

   set_readonly (0);
   erase_buffer ();
   insert (top_line);

   for (y = 0; y < height; y++)
     {
        insert_char ('|');
        foreach (s [*,y])
           insert_char ();
        insert ("|\n");
     }
   insert (sprintf ("`-:%04d:-", delay));
   insert (bottom_line);
   bob ();
   set_readonly (1);
   update (1);
   message (msg);
}

%}}}
private define make_left  (n) %{{{
{
   variable a = Int_Type [n];
   a [0] = n-1;
   a [[1:]] = [0:n-2];

   return a;
}

%}}}
private define make_right (n) %{{{
{
   variable a = Int_Type [n];
   a [[0:n-2]] = [1:n-1];
   a [-1] = 0;

   return a;
}

%}}}


% PUBLIC FUNCTIONS

public define life_quit   ()  %{{{
{
   set_buffer_modified_flag (0);
   delbuf ("*LIFE*");
   DOLLAR_CHARACTER = dollar;

   local_unsetkey ("0");
   local_unsetkey ("-");
   local_unsetkey ("+");
   local_unsetkey ("c");
   local_unsetkey (".");
   local_unsetkey ("o");
   local_unsetkey (" ");
   local_unsetkey ("n");
   local_unsetkey ("r");
   local_unsetkey ("q");
}

%}}}
public define life_clear  ()  %{{{
{
   cell [*,*] = 0;
   life_dump ();
}

%}}}
public define life_state  ()  %{{{
{
   variable x = what_column () - 2;
   variable y = what_line () - 2;

   if ((0 <= x) and (x < width) and
       (0 <= y) and (y < height))
     {
        variable c = what_char ();

        if (c == 'o')
          {
             c = ' ';
             cell [x,y] = 0;
          }
      else
          {
             c = 'o';
             cell [x,y] = 1;
          }
        set_readonly (0);
        del ();
        insert (sprintf ("%c",c));
        set_readonly (1);
     }
}

%}}}
public define life_next   ()  %{{{
{
   variable b, i;
   variable middle = [:];

   b = (cell [left,up]     + cell [middle,up]    + cell [right,up] +
        cell [left,middle] +                       cell [right,middle] +
        cell [left,down]   + cell [middle,down]  + cell [right,down]);
   b = typecast (b, Char_Type);

   i = where ((b < 2) or (b > 3) or ((b == 2) and (cell == 0)));
   b [i] = 0;
   b [where (b)] = 1;
   cell = b;
   life_dump ();
}

%}}}
public define life_delay  (d) %{{{
{
   if (d)
     {
        delay += d * 25;
        if (delay < 0)
           delay = 0;
     }
   else
      delay = 0;
}

%}}}
public define life_random ()  %{{{
{
   variable x, y;

   () = random (-1,100);
   for (x = 0; x < width; x++)
      for (y = 0; y < height; y++)
         cell [x,y] = typecast ((random (0,99) < 15), Char_Type);

   life_dump ();
}

%}}}
public define life_start  ()  %{{{
{
   variable stop = 0, k, q = 0;

   while (stop == 0)
     {
        life_next ();
        if (input_pending (0))
          {
             k = getkey ();
             switch (k)
               { case 'q': stop = 1; q = 1; }
               { case 'r': life_random (); }
               { case ' ': stop = 1; }
               { case '0': life_delay (0); }
               { case '-': life_delay (-1); }
               { case '+': life_delay (1); }
          }
        usleep (delay);
     }
   if (q)
      life_quit ();
}

%}}}

%!%+
%\function{life}
%\synopsis{Conway's Game of Life}
%\usage{Void_Type life ();}
%\description
% This is an implementation of the Conway's Game of Life for jed.
%!%-
public define life        ()  %{{{
{
   dollar = DOLLAR_CHARACTER;
   DOLLAR_CHARACTER = 0;

   left = make_left (width);
   right = make_right (width);
   up = make_left (height);
   down = make_right (height);

   pop2buf ("*LIFE*");
   onewindow ();
   !if (strlen (top_line))
     {
        life_random ();

        top_line = ".--- Conway's Game of Life ";
        loop (width-26)
           top_line += "-";
        top_line += ".\n";

        bottom_line = "";
        loop (width-8)
           bottom_line += "-";
        bottom_line += "'";

        local_setkey ("life_delay(0)",  "0");
        local_setkey ("life_delay(-1)", "-");
        local_setkey ("life_delay(1)",  "+");
        local_setkey ("life_clear",     "c");
        local_setkey ("life_state",     ".");
        local_setkey ("life_state",     "o");
        local_setkey ("life_start",     " ");
        local_setkey ("life_next",      "n");
        local_setkey ("life_random",    "r");
        local_setkey ("life_quit",      "q");
     }

   life_start ();
}

%}}}

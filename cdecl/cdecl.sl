% File:          cdecl.sl      -*- mode: SLang -*-
%
% $Id: cdecl.sl,v 1.3 2003/09/16 16:51:57 paul Exp paul $
% Keywords: c, tools
% 
% Copyright (c) 2002, 2003 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This is a SLang translation of the `dcl' program from
% the book `The C programming language'

static variable name, out, datatype, word_chars = "0-9A-Za-z_";
static define dcl();
static define dirdcl();

static define dirdcl()
{
  if (looking_at_char( '('))	       %  dcl
    {
      go_right_1;	  
      dcl;
      !if (looking_at_char( ')'))
	error("missing \)");
      go_right_1;
    }
  else				       %  name
    {
      push_mark;
      skip_chars(word_chars);
      name = bufsubstr;
      !if (strlen(name)) error ("expected name or dcl");
    }
    forever
    {
      skip_white;
      if (looking_at_char( '('))       %  function
	{
	  !if (ffind_char( ')'))       %  skip the arguments
	    error("missing \)");
	  out += " function returning";
	}
      else if (looking_at_char('['))   %  array
	{
	  out += " array";
	  push_mark;
	  !if (ffind_char( ']'))
	    error("missing \]");
	  out += bufsubstr + "] of";
	}
      else
	break;
      go_right_1;	  
    }
}

static define dcl()
{
  variable ns = 0;
  skip_white;
  while (looking_at_char( '*'))	       %  pointer
    {
      ns++;
      go_right_1;
      skip_white;
    }
  dirdcl;
  loop (ns)
    out += " pointer to";
}

public define cdecl()
{
  out = "";
  push_spot_bol;
  skip_white;
  push_mark;
  skip_chars(word_chars);	       %  datatype. I don't know 'const' etc
  datatype = " " + bufsubstr;
  dcl;
  pop_spot;
  message (name + ":" + out + datatype);
}

provide("cdecl");

% File:          autotext.sl      -*- mode: SLang; mode: fold -*-
%
% $Id: autotext.sl,v 1.20 2003/09/16 12:46:22 paul Exp paul $
% 
% Copyright (c) 2002, 2003 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% This file provides autotext a la MS Word

#iffalse
%add this to .jedrc
require("autotext");
setkey("complete_autotext", "[[C"); % f3
#endif

public variable autotext = Assoc_Type[String_Type];
custom_variable("Autotext_File", dircat(Jed_Home_Directory, 
#ifdef UNIX
                        ".autotext"));
#else
                        "autotext"));
#endif

static variable autotext_has_changed = 0;

%{{{ inserting autotext

% Insert() does not wrap, so here is a hack to insert some text and wrap it
% by formatting the first paragraph (up to the first empty line).
% If you don't want wrapping, define your autotext to begin with an empty line
% or switch to no_mode
public define insert_wrap(string)
{
  variable flags;
  ( , flags) = what_mode();
  !if (flags & 1) % wrap-flag
    {
      insert(string);
      return;
    }
  %{{{ see if we are in an indented paragraph
  push_spot();
  bol();
  skip_white();
  what_column();
  pop_spot();
  %}}}
  what_column();
  push_mark();
  insert("\n\n\n\n");
  push_spot();
  %{{{ create the wrapped text
  ()=up(2);
  goto_column();
  insert("X");           % the first line of a paragraph may be indented
  push_spot();
  insert("\n");
  push_spot();
  goto_column();          % indentation for the rest of the paragraph
  insert(string);
  push_mark();
  pop_spot();
  call("format_paragraph");
  pop_spot();
  if (looking_at_char(' ')) call("next_char_cmd");  % extra space
  bufsubstr();            % got it!
  %}}}
  pop_spot();
  del_region();
  insert();
}
%}}}
  
%{{{ Adding autotext items

% This is to define a new autotext item. 
public define new_autotext_item()
{
  variable key, text;
  !if(markp())
    {
      flush("no region is defined");
      return;
    } 
  text = bufsubstr();
  !if(strlen(text)) return;
  key = strtrim_end(substr(extract_element(strtrim_beg(text), 0,'\n'), 1,40));
  forever
    {
      key = read_mini("Keyword? ", "", key);
      !if(assoc_key_exists(autotext, key)) break;
      if(1 == get_y_or_n("Keyword exists. Overwrite")) break;
    }
  !if(strlen(key)) return;
  autotext[key]=text;
  autotext_has_changed = 1;
}
%}}}

%{{{ Building the menus

%menu for removing autotext items
static define autotext_remove_callback(popup)
{
  variable k;
  foreach (autotext) using ("keys")
    {
      k = ();
      menu_append_item(popup, k, sprintf
		       ("assoc_delete_key(autotext, %s)",make_printable_string(k)));
    }
  autotext_has_changed = 1;
}

%menu for inserting autotext
static define autotext_menu_callback(popup)
{
  variable key, cmd;
  menu_append_item(popup, "new", "new_autotext_item");
  menu_append_popup(popup, "&Remove");
  menu_set_select_popup_callback(popup+".&Remove", &autotext_remove_callback);
  menu_append_separator(popup);
  foreach (autotext) using ("keys")
    {
      key = ();
       cmd = sprintf("insert_wrap(autotext[%s])", make_printable_string(key));
      menu_append_item(popup, "&" + key, cmd);
    }
}

%create the menu
static define add_autotext_popup_hook(menubar)
{
  variable menu = "Global.&Edit";
  menu_append_separator(menu);
  menu_append_popup(menu, "&Autotext");
  menu_set_select_popup_callback(menu+".&Autotext", &autotext_menu_callback);
}

%}}}

%{{{ completion on autotext

define complete_autotext()
{
  bskip_word_chars();
  push_mark();
  push_mark();
  skip_word_chars();
  variable word = bufsubstr();
  !if(strlen(word)) 
    {
      pop_mark_0();
      return;
    }
  variable vals = assoc_get_values(autotext) 
    [where(array_map(Integer_Type, &is_substr, 
		     assoc_get_keys(autotext), word))];

  variable valslen = length(vals);
  !if(valslen)
    {
      message("no autotext found");
      pop_mark_0();
      return;
    }
  del_region();
  push_mark();
  %{{{ cyclic inserting, stolen from dabbrev.sl
  variable fun_type, fun, i = 0;
  forever
    {
      if(i == valslen)
	{
	  insert(word);
	  i=0;
	}
      else
	{
	  insert_wrap(vals[i]);
	  i++;
	}
      update_sans_update_hook(1);
      (fun_type, fun) = get_key_binding();
      !if(fun == "complete_autotext") break;
      del_region();
      push_mark();
    }
  pop_mark_0();
  if(fun_type) call(fun); else eval(fun);
  %}}}
}
%}}}

%{{{ file stuff.

% the autotext file is evaluated as slang code, and since a slang literal 
% string is limited to 256 char, we need to split it up
define slang_string(string)
{
  variable outstring = make_printable_string(substr(string, 1, 100));
  variable i = 101;
  loop(strlen(string) / 100)
    {
      outstring += "\n+ " + make_printable_string(substr(string, i, 100));
      i+=100;
    }
  return outstring;
}


public define save_autotext_file()
{
  variable key, value, fp;
  if(0 == autotext_has_changed) return 1;
  fp = fopen(Autotext_File, "w");
  if(fp == NULL)
    {
      flush("could not save autotext");
      return 1;
    }
  ERROR_BLOCK
    {
      flush("I failed to save your autotext");
      () = getkey();
      _clear_error();
    }
  foreach (autotext) using ("keys", "values")
    {
      (key, value) = ();
      () = fputs("autotext[" + make_printable_string(key) + "] = \n" + 
		 slang_string(value) + ";\n", fp);
    }
  return 1;
}

public define read_autotext_file()
{
  !if(1 == file_status(Autotext_File)) return;
  ERROR_BLOCK
    { 
      flush("error reading the autotext in " + Autotext_File);
      _clear_error(); 
    }
  () = evalfile(Autotext_File);
}
%}}}

append_to_hook("load_popup_hooks", &add_autotext_popup_hook);
add_to_hook("_jed_exit_hooks", &save_autotext_file);
read_autotext_file();

provide("autotext");

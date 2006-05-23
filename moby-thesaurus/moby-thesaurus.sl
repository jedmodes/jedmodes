%% moby-thesaurus.sl
%%
%% This script provides an interface for listing and selecting synonyms
%% for a word by querying the moby-thesaurus dictionary, residing on
%% either a local or a remote DICT server.
%%
%% Authors: Morten Bo johansen, Paul Boekholt
%% Released under the terms of the GNU General Public License (ver. 2 or later)
%%
%% Required software: 
%% 
%% - datutils.sl (http://jedmodes.sourceforge.net/mode/datutils/)
%% - sl_utils.sl (http://jedmodes.sourceforge.net/mode/sl_utils/)
%% - txtutils.sl (http://jedmodes.sourceforge.net/mode/txtutils/)
%% - the dict client program.
%% 
%% Optional software:
%% 
%% - the dict server program for local queries
%% - the dict moby-thesaurus dictionary for local queries.
%% 
%% Quick Installation:
%%
%% - Copy this file and the required *.sl files to your Jed Library Path,
%%   usually ~/.jed/lib/ or /usr/share/jed/lib
%% 
%% - Activate the mode in your jed.rc file (~/.jedrc):
%%   
%%   * Copy/paste the lines between #<INITIALIZATION> and #</INITIALIZATION> 
%%     
%%   * add a keybinding, e.g.
%%   
%%         unsetkey ("\e1");  
%%         setkey ("thesaurus_popup_completions ()", "\e1"); % Alt-1
%%   
%%     (replace "\e1" with your favourite key binding and remember to remove
%%     the "%%" characters)
%%   
%%   * Optionally modify the custom variables
%%   
%%         Thesaurus_Charset = "iso-8859-1"
%%         Dict_Server = "localhost"
%%         Dict_DB = "moby-thesaurus"
%%           
%%     e.g. to:
%%      
%%         variable
%%           Dict_Server = "dict.org",
%%           Dict_DB = "moby-thes";
%%           
%%       if you have a broadband connection and you do not want to have
%%       a DICT server running locally. Note that the names of the Dict_DB
%%       might differ for local and remote servers.
%%
%% Alternative (automatic) way of installing:
%%
%% - Install the files
%%     libdir.sl (http://jedmodes.sourceforge.net/mode/libdir/)
%%     make_ini.sl (http://jedmodes.sourceforge.net/mode/make_ini/)
%%   and follow the instructions there
%%
%%
%% Use: There are two interfaces for selecting a synonym:
%%      
%%   1) In the menubar accessible with F10 -> System -> Thesaurus
%%      Invoking this menu item will pop up a list of synonyms for the
%%      word at point. Hitting <enter> on one of them will replace the
%%      original word with the selected one.
%%
%%   2) A completions popup buffer, that can be invoked on a keypress.
%%      If you inserted the setkey line above it will be available with
%%      ALT-1. From the list of completions you can choose a synonym by
%%      typing in as many characters of that word as neccessary to make
%%      it the unambiguous choice and then hit <tab> to complete it.
%%      Hitting <enter> will replace the original word.
%%
%%   In both cases the word at the editing point or immediately preceding
%%   it will be looked up.

#<INITIALIZATION>
autoload("thesaurus_popup_menu", "thesaurus.sl");
autoload("thesaurus_popup_completions", "thesaurus.sl");
private define thesaurus_load_popup_hook(menubar)
{
   variable menu = "Global.S&ystem";
   menu_append_popup(menu, "&Thesaurus");
   menu="Global.S&ystem.&Thesaurus";
   menu_set_select_popup_callback(menu, &thesaurus_popup_menu ());
}
append_to_hook("load_popup_hooks", &thesaurus_load_popup_hook);
#</INITIALIZATION>

custom_variable ("Thesaurus_Charset", "iso-8859-1");
custom_variable ("Dict_Server", "localhost");
custom_variable("Dict_Thesaurus_DB", "moby-thesaurus");

autoload ("array_max", "datutils");
autoload ("mark_word", "txtutils");
autoload ("get_word", "txtutils");
implements ("thesaurus");

% string_match isn't utf-8 aware, but this only tries to get some ascii
% characters from the beginning of the string, so it should work
private define get_indent(str)
{
   variable len;
   if (string_match(str, "^[ \t]+", 1))
     {
        (,len)=string_match_nth(0);
        return len;
     }
   else return 0;
}

private define insert_syn (syn)
{
   mark_word ();
   del_region ();
   insert (syn);
}

%% Unfortunately there is no standard for formatting the dict output
%% and a variety of formats exists which may differ with various
%% distributions, depending on how the dictionary was converted into
%% dict format, and since there is no option to the dict command that
%% will spit out just the translations, something must be done to
%% isolate them in the output. The following assumes that the lines with
%% the translations always have some indentation, and preferably more
%% indentation than the headword. If the lines with the translations
%% have no indentation, this lookup function will fail.
private define thesaurus_list_synonyms (word)
{
   variable indent, syns = "", syn, cmd;
   variable len, fp, max_indent = 0;
   variable dict_cmd = sprintf ("dict -h %s -P - -C -d", Dict_Server);
   
   cmd = sprintf ("%s \"%s\" '%s' | iconv -f utf-8 -t %s", 
                  dict_cmd, Dict_Thesaurus_DB, word, Thesaurus_Charset);
   
   fp = popen (cmd, "r");
   
   if (fp == NULL) verror("popen failed");
   
#ifexists _slang_utf8_ok
   () = fread (&syns, String_Type, 50000, fp);
#else
   () = fread (&syns, Char_Type, 50000, fp);
#endif
   
   () = pclose (fp);
   syns = strchop (syns, '\n', 0);
   indent=array_map(Integer_Type, &get_indent, syns);
   max_indent=array_max(indent);
   syns=syns[where(indent == max_indent)];
   
   !if (length(syns) and max_indent)
     { 
        % this is to close the menu in case there is no match,
        % but surely there must be a less crude solution?
        call ("kbd_quit");
     }
   
   % in case there is information about word class, domain or
   % pronunciation in square or angle brackets like eg. <adj.> [bot.],
   % then filter them out from the output.
   syns=array_map(String_Type, &str_uncomment_string, syns, "[<", ">]");
   
   syns = strjoin (syns, "\n");
   syns = strcompress (syns, ",,\n");
   syns = strcompress (syns, "  ");
   syns = str_replace_all (syns, ", ", ",");
   return word, syns;
}

public define thesaurus_popup_menu (popup)
{
   variable syn, syns, word;
   word = get_word ();
   (word, syns) = thesaurus_list_synonyms (word);
   syns = strchop (syns, ',', 0);
   word = strup (word) + ":";
   foreach (syns)
     {
        syn = ();
        menu_append_item(popup, syn, &insert_syn, syn);
     }
   menu_insert_item (0, popup, word, "");
   menu_set_object_available (popup + "." + word, 0);
   menu_insert_separator (1, popup);
}

public define thesaurus_popup_completions ()
{
   variable syn, syns, word, prompt;
   word = get_word ();
   (word, syns) = thesaurus_list_synonyms (word);
   prompt = sprintf ("Synonym for \"%s\":", word);
   recenter (1);
   ungetkey ('\t');
   syn = read_with_completion (syns, prompt, "", "", 's');
   !if (strlen (syn)) return;
   insert_syn (syn);
}

private define thesaurus_mouse_2click_hook (line, col, but, shift)
{
   thesaurus_popup_completions ();
   return (0);
}

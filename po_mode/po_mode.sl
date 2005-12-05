%% po_mode.sl -*- mode: slang; mode: fold -*-
%%
%% po_mode.sl -- an Emacs-like Jed editing mode for 
%% portable object files (*.po)
%% 
%% Copyright: http://www.fsf.org/copyleft/gpl.html
%% Author   : Morten Bo Johansen <mojo@mbjnet dk>
%%
%% Thanks to Paul Boekholt for some general hints relating to S-Lang
%% scripting.
%%
%% Tested with Jed 0.99.16/17 on Linux, compiled against both slang1
%% and slang2. Tested with emulations, cua, edt, emacs, ide, jed and 
%% wordstar. You must edit several functions to make it usable on
%% non-Unix systems.
%%
%% Installation
%% ------------
%% 
%% Copy this file and po_mode.hlp to a directory in your jed library path,
%% e.g. /usr/share/jed/lib. For initialization, either use make_ini()
%% (from jedmodes.sf.net/mode/make_ini/) or copy the content of the
%% INITIALIZATION block to your .jedrc.
%%
%% For the rest, please refer to the po_mode.hlp file for the ins and outs
%% of this mode. There is some rather important information therein, so you
%% should read it ;-). If you copied it to the same place as this file, it
%% should be available in po_mode by typing '?'.
%%
%% $Log: po_mode.sl,v $
%% Revision 1.8  2005/11/10 09:15:25  mojo
%% - A substantial (4x!) speedup in wordlist_lookup_all (), 
%%   courtesy of Paul Boekholt.
%% - Redefined some keys to avoid more of the reserved_key bindings.
%% - Added function to toggle wrapping.
%%
%% Revision 1.7  2005/10/26 14:20:33  mojo
%% - New user function: jump to any next fuzzy or untranslated entry,
%%   bound to space like in Emacs.
%% - Much improved wordlist functions: It is now possible to look up words
%%   in both the custom wordlist as well as in the Freedict Translation
%%   Dictionaries and to combine lookups in the two. Also added function to
%%   prefill all msgstrs with translations from above wordlists.
%% - added choice to mail file to Debian BTS.
%% - Improved documentation.
%% - Various bug fixes.
%%
%% Revision 1.6  2005/01/10 19:37:50  mojo
%% - New user function: Limit display to entries matching an expression.
%% - Improved validation command: The output window now contains a warning
%%   if there is a mismatch between charset encoding in header and the actual
%%   encoding of the document. Requires the file(1) utility.
%%
%% Revision 1.5  2005/01/02 19:06:18  mojo
%% - New user function: Grep for a word/string in source directory,
%%   using grep.sl from Jedmodes.
%% - When updating the gettext compendium, user can choose to overwrite
%%   translations for matching msgids.
%% - Added function to add a directory of po-files to native compendium.
%% - Many minor improvements and fixes.
%%
%% Revision 1.4  2004/11/23 21:31:37  mojo
%% - Modification of plural form strings should work correctly now.
%% - Simplified get_msgid_line_format ().
%% - New user functions: mark_fuzzy_all and replace_in_msgstrs.
%% - Redefined key for rejecting changes in po_edit buffer to avoid conflicts.
%%
%% Revision 1.3  2004/11/12 16:53:27  mojo
%% - A fix in format_msgstr_before () wrt. to the removal of 
%%   surrounding double quotes.
%%
%% Revision 1.2  2004/11/11 16:35:55  mojo
%% - Time zone in revision date was wrong in many instances. 
%%   Now use the date cmd to get it.
%%
%% Revision 1.1  2004/11/07 22:35:42  mojo
%% - strreplace -> str_replace_all 
%% - small changes in mail and comependium functions 
%% - other minor cosmetic changes 
%% Thanks to Paul Boekholt for most of these.
%%
%% Revision 1.0  2004/11/06 16:37:30  mojo
%% First public release

#<INITIALIZATION>
autoload ("po_mode", "po_mode");
add_mode_for_extension ("po", "po");
add_mode_for_extension ("po", "pot");
#</INITIALIZATION>

%{{{ static variables

static variable 
  mode = "PO",
  View_Limit = 0,
  Wrap_Status = 1,
  translator_cmt_re = "^#[^.:,~]*[\n ]+",
  str_any_re = "^#?~? ?msg",
  msgid_re = "^#?~? ?msgid ",
  msgstr_re = "^#?~? ?msgstr ",
  msgid_any_re = "^#?~? ?msgid",
  msgstr_any_re = "^#?~? ?msgstr\\[?",
  msgid_plural_re = "^#?~? ?msgid_",
  po_edit_buf = "*Translate*",
  Edit_Mode = "po_edit",
  Translation_Status = 0,
  Multi_Line = 0,
  po_cmt_buf = "",
  dict_checks = 0,
  dict_error_msg = "",
  Overwrite_Compendium = 0,
  entry_number;

%}}}

%{{{ autoloads

autoload ("grep", "grep");

%}}}

%{{{ requirements

require ("keydefs");

%}}}

%{{{ customization

%% Name and email address of you, the translator
custom_variable ("Translator", "Full Name <email@address>");
%% Your language - use adjective in English, e.g. "German", "Danish" etc.
custom_variable ("Language", "My Language");
%% Email address of your language team
custom_variable ("Team_Email", "<LL@Li.org>");
% Default character encoding of po-file. Note that Jed 0.99.16/17 does not yet
% handle utf-8 encoded files.
custom_variable ("Charset", "iso-8859-1");
%% If po-file has plural forms: how many plural forms does your language
%% have? See /usr/share/doc/gettext-doc/gettext_10.html#SEC1.
custom_variable ("Nplurals", "2");
%% See /usr/share/doc/gettext-doc/gettext_10.html#SEC1
custom_variable ("Plural", "(n != 1)");
%% Program to use for spell checking; use ispell or aspell
custom_variable ("Spell_Prg", "ispell");
%% Language dictionary for ispell/aspell, e.g. "deutsch" for German
custom_variable ("Spell_Dict", "dansk");
%% What compendiums to use: 
%% 1 = native po_mode compendium
%% 2 = gettext compendium
%% 3 = both 
custom_variable ("Use_Compendium", 3);
%% Path to native compendium file:
custom_variable ("Compendium", dircat (getenv ("HOME"), ".compendium_pomode"));
%% Path to compendium file, created with msgcat:
custom_variable ("Compendium_Gettext", dircat (getenv ("HOME"), ".compendium_gettext"));
%% If fuzzy matching is used with gettext compendiums 0 = no, 1 = yes:
custom_variable ("Gettext_Use_Fuzzy", 0);
%% Path to wordlist
custom_variable ("Custom_Wordlist", dircat (getenv ("HOME"), ".wordlist_pomode"));
%% What wordlist(s) to use for word translation lookups?:
%% 1 = custom
%% 2 = dict freedict translation dictionary
%% 3 = both
custom_variable ("Use_Wordlist", 3);
%% If you use dict, you must set the dict dictionary to use,
%% this one is English -> German
custom_variable ("Dict_Dictionary", "fd-eng-deu");
%% Do not look up translations for words less than n chars
custom_variable ("Dict_Minimum_Wordsize", 4);

private variable Language_Team = sprintf ("%s %s", Language, Team_Email);

%}}}

%{{{ prototypes

public define po_mode();

%}}}

%{{{ auxiliary functions

%% Search for a file in $PATH
static define prg_found_in_path (file)
{
   variable path = getenv ("PATH");
   path = str_replace_all (path, ":", ",");
   return search_path_for_file (path, file);
}

static define write_tmp_buffer (file)
{
   push_spot ();
   mark_buffer ();
   () = write_region_to_file (file);
   pop_spot ();
}

%% The example function from the S-Lang documentation
static define file_size (file)
{
   variable st;
   st = stat_file(file);
   if (st == NULL) verror ("unable to stat %s", file);
   return st.st_size;
}

%% Mark a word and return it (and with argument return and delete it).
static define po_mark_word (delete)
{
   variable word = "";
   
   push_spot ();
   bskip_word_chars ();
   push_mark ();
   skip_word_chars ();
   if (delete)
     word = bufsubstr_delete ();
   else
     word = bufsubstr ();
   pop_spot ();
   return word;
}

%% Strip word of n chars and return it. Also return nth char.
static define strip_chars (word, n)
{
   variable char = "";
   variable len = strlen (word)-1;
   if (n <= len)
     {
        word = word [[:len-n]];
        char = word [[len-n:len-n]];
     }
   return word, char;
}

%% Sort a string array removing duplicate members and return result
static define sort_uniq (str)
{
   variable i, a = "", b = "";

   str = str [array_sort (str)];
   
   _for (0, length (str)-1, 1)
     {                                                                        
        i = ();                                                               
        a = str [i];                                                     
        !if (0 == strcmp (a, b))
          str [i] = a;
        else
          str [i] = Null_String;
        b = a;
     }
   
   return str;
}

%% Remove some characters from a string.
static define format_string (str)
{
   str = strcompress (str, " ");
   str = str_replace_all (str, "\\n", "");
   str = str_delete_chars (str, "\n\(\)\"\^`´',\.\?\!;<>[]\*/{}\+#:&\\");
   str = strtrim_beg (str);
   return str;
}

%}}}

%{{{ delimitation

% All sorts of quaint syntactical variations -- all legal to gettext have been
% taken into account, which is why this section looks somewhat patchy. E.g.:
% Entries seperated by blank line or no blank line in between, various types
% of comments in between entries or not, blank lines in between comments and
% message strings or not, trailing quotes in comment lines, handling of obsolete
% entries, plural entries wrapped on several lines,  etc. -- it should all work.
% If only a well formed standard gettext format was assumed, it could of course
% have been written in just a few lines.


%% Determine if an entry is untranslated. Could have been simplified
%% with the pcre-module which can search across lines, but this is faster
%% Thanks to Günter Milde for suggesting this.
static define is_untranslated ()
{
   EXIT_BLOCK { pop_spot (); }
        
   () = ffind ("\"");
   push_spot ();
   !if (looking_at ("\"\"")) return 0;
   if (down (1))
     not looking_at ("\"");
   else
     return 1;
}

static define is_translated ()
{
   not is_untranslated ();
}

static define is_comment ()
{
   bol ();
   orelse
     {looking_at ("#\n") }
     {looking_at ("##") }
     {looking_at ("#,") }
     {looking_at ("#.") }
     {looking_at ("#:") }
     {looking_at ("# ") }
     {looking_at ("#~ #")};
}

static define search_any_msgid ()
{
   while (re_fsearch ("msgid_?"))
     {
        if (bolp ()) return 1;
        else if (bfind ("#~")) return 1;
        else
          {
             eol ();
             continue;
          }
     }

   return 0;
}

define position_on (pos); % for recursion

define position_on (pos)
{
   bol ();
   switch (pos)
     { case "msgid":
        if (is_comment () or eolp () or re_looking_at (msgid_any_re))
          {
             if (search_any_msgid ());
             else
               {
                  () = re_bsearch (msgid_any_re);
               }
             return;
          }
        if (re_looking_at ("#?~? ?\""))
          {
             () = re_bsearch (str_any_re);
          }
        if (re_looking_at (msgstr_any_re + "1"))
          {
             () = re_bsearch (msgid_plural_re);
             return;
          }
        if (re_looking_at (msgstr_any_re + "0") or re_looking_at (msgstr_re))
          {
             () = re_bsearch (msgid_re);
             return;
          }
     }
     { case "msgstr":
        if (re_looking_at (msgstr_any_re)) return;
        position_on ("msgid");
        if (re_looking_at (msgid_re))
          {
             () = re_fsearch (msgstr_any_re + "0?");
          }
        else
          {
             () = re_fsearch (msgstr_any_re + "1");
          }
     }
     { case "entry_start":
        position_on ("msgstr");
        () = re_bsearch (msgid_re);
        while (up (1))
          {
             if (blooking_at ("\""))
               { 
                  bol ();
                  if (is_comment ()) continue;
                  else break;
               }
          }
        bol ();
        if (bobp ()) return;
        while (down (1))
          {
             if (is_comment () or re_looking_at (msgid_re)) return;
          }
     }
     { case "entry_end":
        position_on ("msgstr");
        if (re_fsearch (msgid_re));
        else
          { 
             eob ();
             bskip_chars ("\n\t ");
             return;
          }
        position_on ("entry_start");
        bskip_chars ("\n\t ");
     }
}

static define mark (str)
{
   switch (str)
     { case "entry":
        position_on ("entry_start");
        push_mark ();
        position_on ("entry_end");
     }
     { case "strings":
        position_on ("msgid");
        push_mark ();
        position_on ("entry_end");
     }
     { case "msgid":
        position_on ("msgid");
        () = ffind ("\"");
        if (looking_at ("\"\""))
          {
             () = down (1);
          }
        push_mark ();
        () = re_fsearch (str_any_re);
        () = up (1);
     }
     { case "msgstr":
        position_on ("msgstr");
        if (is_untranslated ()) return push_mark_eol ();
        else
          {
             push_mark ();
             while (down (1))
               {
                  if (re_looking_at (str_any_re) or is_comment () or eolp ()) break;
                  if (re_looking_at ("#?~? ?\"")) continue;
               }
             eol ();
             if (eobp ()) return;
             else
               {
                  () = up (1);
               }
          }
     }
}

static define is_header ()
{
   push_spot ();
   position_on ("msgid");
   !if (bol_bsearch ("msgid")) 1;
   else 0;
   pop_spot ();
}

%% Narrow to msgstr and msgid, excluding comments.
static define narrow_to_strings ()
{
   mark ("strings");
   narrow_to_region ();
   bob ();
}

static define narrow_to_entry ()
{
   mark ("entry");
   narrow_to_region ();
   bob ();
}

%% Return either the msgid or the msgstr as a string.
static define msg_as_string (str)
{
   variable msg = "";
   push_spot ();
   if (str)
     mark ("msgstr");
   else
     mark ("msgid");
   msg = bufsubstr ();
   pop_spot ();
   return msg;
}

static define is_fuzzy ()                                                     
{                                                                             
   EXIT_BLOCK { position_on ("entry_end"); }
   
   position_on ("entry_start");
   do
     {
        if (looking_at ("msgid")) return 0;
        if (looking_at ("#, fuzzy")) return 1;
     }
   while (down (1));
}       

%}}}

%{{{ statistics

%% Make all count variables local to the buffer
static define count (i)
{
   switch (i)
     { case "t": get_blocal_var ("translated"); }
     { case "u": get_blocal_var ("untranslated"); }
     { case "f": get_blocal_var ("fuzzy"); }
     { case "o": get_blocal_var ("obsolete"); }
     { case "t+": set_blocal_var (get_blocal_var ("translated") + 1, "translated"); }
     { case "t-": set_blocal_var (get_blocal_var ("translated") - 1, "translated"); }
     { case "u+": set_blocal_var (get_blocal_var ("untranslated") + 1, "untranslated"); }
     { case "u-": set_blocal_var (get_blocal_var ("untranslated") - 1, "untranslated"); }
     { case "f+": set_blocal_var (get_blocal_var ("fuzzy") + 1, "fuzzy"); }
     { case "f-": set_blocal_var (get_blocal_var ("fuzzy") - 1, "fuzzy"); }
     { case "o+": set_blocal_var (get_blocal_var ("obsolete") + 1, "obsolete"); }
     { case "o-": set_blocal_var (get_blocal_var ("obsolete") - 1, "obsolete"); }
}

%% The status line that shows the counts for translated, untranslated, fuzzy
%% and obsolete entries
static define set_po_status_line ()
{
   if (View_Limit == 1)
     {
        set_status_line (" (PO) <limit>", 0);
        return;
     }
   
   variable t, u, f, o, s, n, p;
   t = count ("t"); u = count ("u"); f = count ("f"); o = count ("o");
   n = t + f + u;
   if (n == 0) n = 1;
   p = Sprintf ("(%S%s) ", (t*100)/n, "%%",  2);
   s = Sprintf ("%dt/%du/%df/%do", t, u, f, o, 4);
   set_status_line (" %b " + p + s + "  (%m%a%n%o)  %p   %t", 0);
}

%% The actual counting of the various entries. Could be done in
%% one pass, but this is faster.
static define po_statistics ()
{
   variable t, u, f, o;
   
   create_blocal_var ("translated"); 
   set_blocal_var (0, "translated");
   create_blocal_var ("untranslated"); 
   set_blocal_var (0, "untranslated");
   create_blocal_var ("fuzzy"); 
   set_blocal_var (0, "fuzzy");
   create_blocal_var ("obsolete"); 
   set_blocal_var (0, "obsolete");
   create_blocal_var ("total_entries"); 
   set_blocal_var (0, "total_entries");
    
   t = count ("t"); u = count ("u"); f = count ("f"); o = count ("o");
   
   ERROR_BLOCK
     {
        pop_spot ();
        _clear_error ();
        error ("Maybe po-file has syntax errors? Try to validate ..");
     }

   flush ("counting entries ...");
   push_spot_bob ();
   () = bol_fsearch ("\"");
   loop (2) push_mark ();
   while (re_fsearch ("^msgstr.[^1]"))
     {
        if (is_untranslated ())
          u++;
        else
          t++;
     }
   pop_mark (1);
   while (bol_fsearch ("#~ msgid"))
     {
        eol ();
        o++;
     }
   pop_mark (1);
   while (bol_fsearch ("#, fuzzy"))
     {
        () = down (1);
        !if (looking_at ("#~")) f++;
     }
   
   t = t - f; % translated count doesn't exlude fuzzies so deduct them here
   
   set_blocal_var (t, "translated");
   set_blocal_var (u, "untranslated");
   set_blocal_var (f, "fuzzy");
   set_blocal_var (o, "obsolete");
   set_blocal_var (t + u + f + o, "total_entries");
   
   pop_spot (); 
   set_po_status_line ();
   update (1);
}

define get_current_entry_number ()
{
   push_spot ();
   position_on ("msgid");
   variable n = 0;
   while (re_bsearch (msgid_re)) n++;
   pop_spot ();
   return n;
}

%% Shows the counts in the message area, including total counts and current
%% position
define show_po_statistics ()
{
   variable t, u, f, o;
   variable n = get_blocal_var ("total_entries");
   variable cn = get_current_entry_number ();
   t = count ("t"); u = count ("u"); f = count ("f"); o = count ("o");
   po_statistics ();
   vmessage ("%s %d/%d; %d translated, %d untranslated, %d fuzzy, %d obsolete", "Position:", cn, n, t, u, f, o);
}

%}}}

%{{{ navigation

static define restore_entry_position (n)
{
   bob ();
   loop (n+1)
     {
        () = re_fsearch (msgstr_re);
        eol ();
     }
   position_on ("msgid");
}

define show_current_entry_number ()
{
   push_spot ();
   variable n = get_current_entry_number ();
   vmessage ("# %d", n);
   pop_spot ();
}

%% Go to next entry which is either untranslated or fuzzy
define any_next_unfinished ()
{
   if (count ("u") == 0 and count ("f") == 0)
     return flush ("no unfinished entries");

   forever
     {
        position_on ("entry_end");
        while (down (1))
          {
             if (looking_at ("msgstr "))
               {
                  if (is_untranslated ())
                    { 
                       () = bol_bsearch ("msgstr ");
                       return;
                    }
               }
             if (looking_at ("#, fuzzy"))
               { 
                  () = down (1);
                  if (looking_at ("#~")) continue;
                  else return;
               }
          }
        bob ();
        flush ("wrapping search around buffer");
        continue;
     }
}

define po_next_entry ()
{
   position_on ("msgid");
   eol ();
   if (re_fsearch (msgid_any_re));
   else
     return bol ();
   if (is_line_hidden ())
     {
        skip_hidden_lines_forward (1);
        () = re_fsearch (msgid_re);
     }
}

define po_previous_entry ()
{
   position_on ("entry_start");
   () = re_bsearch (msgid_re);
   if (is_line_hidden ())
     {
        skip_hidden_lines_backward (1);
        () = re_bsearch (msgid_re);
     }
}

define top_justify_entry ()
{
   position_on ("entry_start");
   recenter (1);
}

%% Go to the next untranslated entry and wrap search around buffer
define find_untranslated ()
{
   if (count ("u") == 0)
     return flush ("no untranslated entries");
   
   EXIT_BLOCK { () = bol_bsearch ("msgid"); }
   
   () = bol_fsearch ("msgstr"); eol ();
   while (bol_fsearch ("msgstr"))
     if (is_untranslated) return;
   flush ("wrapping search around buffer");
   bob ();
   while (bol_fsearch ("msgstr"))
     if (is_untranslated) return;
}

%% Go to the next translated entry and wrap search around buffer
define find_translated ()
{
   if (count ("t") == 0)
     return flush ("no translated entries");

   EXIT_BLOCK { () = bol_bsearch ("msgid"); }

   forever
     {
        position_on ("entry_end");
        while (bol_fsearch ("msgstr"))
          {
             if (is_untranslated () or is_fuzzy ()) continue;
             else return;
          }
        bob ();
        flush ("wrapping search around buffer");
        continue;
     }
}

define find_fuzzy ()
{
   if (count ("f") == 0)
     return flush ("no fuzzy entries");

   forever
     {
        while (bol_fsearch ("#, fuzzy"))
          {
             () = down (1);
             !if (looking_at ("#~"))
               { 
                  () = bol_fsearch ("msgid");
                  return;
               }
             else continue;
          }
        bob ();
        flush ("wrapping search around buffer");
        continue;
     }
}

%% Find the next obsolete entry and wrap search around buffer
define find_obsolete ()
{
   if (count ("o") == 0)
     return flush ("no obsolete entries");
   
   forever
     {
        position_on ("entry_end");
        while (bol_fsearch ("#~ msgid")) return;
        flush ("wrapping search around buffer");
        bob ();
        continue;
     }
}

%% Find the previous untranslated msgstr.
define bfind_untranslated ()
{
   if (count ("u") == 0)
     return message ("no untranslated entries");

   push_mark ();
   while (bol_bsearch ("msgstr"))
     {
        if (is_untranslated ())
          {
             () = bol_bsearch ("msgid");
             return pop_mark (0);
          }
        () = bol_bsearch ("msgid");
     }
   flush ("no untranslated strings above this point");
   pop_mark (1);
}

%% Find the previous translated entry
define bfind_translated ()
{
   if (count ("t") == 0)
     return flush ("no translated entries");

   while (bol_bsearch ("msgstr"))
     {
        if (is_untranslated ())
          { 
             () = bol_bsearch ("msgid ");
             continue;
          }
        else if (is_fuzzy ())
          { 
             () = bol_bsearch ("msgid ");
             continue;
          }
        else 
          {
             () = bol_bsearch ("msgid ");
             return;
          }
     }
}

%% Find the previous entry with fuzzy flag.
define bfind_fuzzy ()
{
   push_mark ();
   position_on ("entry_start");
   !if (bol_bsearch ("#, fuzzy"))
     {
        flush ("no fuzzy entries above this point");
        pop_mark (1);
     }
   pop_mark (0);
}

%% Find the previous obsolete entry.
define bfind_obsolete ()
{
   push_mark ();
   position_on ("entry_start");
   !if (bol_bsearch ("#~ msgid"))
     {
        flush ("no obsolete entries above this point");
        pop_mark (1);
     }
   pop_mark (0);
}

%% Find the next entry with a translator comment and wrap search around buffer
define find_translator_comment ()
{
   push_mark ();
   while (re_fsearch (translator_cmt_re))
     {
        () = re_fsearch (msgid_re);
        return pop_mark (0);
     }
   flush ("wrapping search around buffer");
   bob ();
   while (re_fsearch (translator_cmt_re))
     {
        () = re_fsearch (msgid_re);
        return pop_mark (0);
     }
   pop_mark (1);
   flush ("no more translator comments");
}

define goto_entry ()
{
   variable entry_number = read_mini ("Go to entry number:", "", "");
   if (integer (entry_number) > get_blocal_var ("total_entries") or
       integer (entry_number) < 1)
     return flush ("no such entry");
   bob ();
   loop (integer (entry_number) + 1)
     {
        eol ();
        () = re_fsearch (msgid_re);
     }
} 

%}}}

%{{{ flagging

%% Flag translation as "fuzzy", or obsolete entry if already fuzzy
define fuzzy_or_obsolete_entry ()
{
   EXIT_BLOCK
     {     
        set_readonly (1);
        set_po_status_line ();
        pop_spot ();
     }
   position_on ("msgstr");
   push_spot ();
   if (looking_at ("#~") or is_untranslated ()) return;
   () = bol_bsearch ("msgid ");
   if (up (1)) bol ();
   set_readonly (0);
   if (looking_at ("#, fuzzy"))
     {
        !if (get_y_or_n ("Make entry obsolete")) return;
        narrow_to_entry ();
        do
          {
             insert ("#~ ");
          }
        while (down (1));
        widen_region ();
        count ("f-"); count ("o+");
        return;
     }
   if (looking_at ("#,"))
     {
        skip_chars ("#, ");
        insert ("fuzzy, ");
     }
   else
     {
        () = down (1);
        insert ("#, fuzzy\n");
     }
   
   !if (bol_bsearch ("msgid")) return;
   count ("f+"); count ("t-");
}

define remove_fuzzy_flag ()
{
   EXIT_BLOCK { pop_spot (); }
   push_spot ();
   position_on ("entry_start");
   () = bol_fsearch ("msgid ");
   if (up (1)) bol ();
   !if (looking_at ("#, fuzzy")) return;
   else
     {
        set_readonly (0);
        push_mark ();
        skip_chars ("#, fuzy");
        del_region ();
        if (eolp ()) del ();
        else insert ("#, ");
     }
   set_readonly (1);
   if (is_header ()) return;
   if (count ("f") > 0) count ("f-");;
   count ("t+");
   set_po_status_line ();
}

define flag_fuzzy_all ()
{
   !if (get_y_or_n ("Flag all entries fuzzy")) return;
   push_spot_bob ();
   po_next_entry ();
   while (bol_fsearch ("msgstr"))
     {
        if (is_fuzzy ()) continue;
        else fuzzy_or_obsolete_entry ();
     }
   pop_spot ();
}

%}}}

%{{{ po-header

%% Insert a default header
static define insert_po_header ()
{
   set_readonly (0);
   bob ();
   insert
     ("# SOME DESCRIPTIVE TITLE.\n" +
      "# Copyright (C) YEAR Free Software Foundation, Inc.\n" +
      "# FIRST AUTHOR <EMAIL@ADDRESS>, YEAR.\n" +
      "#\n" +
      "#, fuzzy\n" +
      "msgid \"\"\n" +
      "msgstr \"\"\n" +
      "\"Project-Id-Version: PACKAGE VERSION\\n\"\n" +
      "\"PO-Revision-Date: YEAR-MO-DA HO:MI +ZONE\\n\"\n" +
      "\"Last-Translator: FULL NAME <EMAIL@ADDRESS>\\n\"\n" +
      "\"Language-Team: LANGUAGE <LL@li.org>\\n\"\n" +
      "\"MIME-Version: 1.0\\n\"\n" +
      "\"Content-Type: text/plain; charset=CHARSET\\n\"\n" +
      "\"Content-Transfer-Encoding: 8bit\\n\"\n" +
      "\"Plural-Forms: nplurals=2; plural=\(n != 1\)\\n\"\n\n");
   
   set_readonly (1);
}

% Set the revision date. It should insert time strings in the format of
% e.g. "2004-06-28 20:11-0400" where the last part is the users time zone. 
% The use of the date command to get the time zone is perhaps a little
% ugly, but I cannot figure out how to get the right time zone at all times
% across all time zones with S-Lang's built-in time functions. Maybe you can
% help?
static define set_po_revision_date ()
{
   !if (mode == get_mode_name) return;
 
   variable tm = localtime (_time ());
   variable day, month, year;
   variable rev_str;
   
   variable t = sprintf ("%d-%02d-%02d %02d:%02d",
                         1900 + tm.tm_year, 1+tm.tm_mon,
                         tm.tm_mday, tm.tm_hour, tm.tm_min);
   
   rev_str = sprintf ("%s%s", "\"PO-Revision-Date: ", t);

   push_spot_bob ();
   narrow_to_strings ();
   if (re_fsearch ("^\"PO-Revision-Date.*$"))
     {
        set_readonly (0);
        () = replace_match (rev_str, 1);
        () = run_shell_cmd (sprintf ("%s%s", "date +%z", "'\\n\"'")); del ();
     }
   widen_region ();
   pop_spot ();
   set_readonly (1);
}

append_to_hook ("_jed_save_buffer_before_hooks", &set_po_revision_date);

%% Adjust the po-header to user's settings.
define replace_headers ()
{
   !if (get_y_or_n ("Replace headers")) return;
   
   variable team, name, charset, plural_str, project;

   name = sprintf ("\"Last-Translator: %s\\n\"", Translator);
   team = sprintf ("\"Language-Team: %s\\n\"", Language_Team);
   project = sprintf ("\"Project-Id-Version: %s\\n\"", whatbuf ());
   charset = sprintf ("\"Content-Type: text/plain; charset=%s\\n\"", Charset);
   plural_str = 
     sprintf ("\"Plural-Forms: nplurals=%s; plural=%s\\n\"", Nplurals, Plural);
   
   push_spot_bob ();
   set_readonly (0);
   narrow_to_strings ();
   if (re_fsearch ("^\"Project-Id-Version.*"))
     { 
        () = replace_match (project, 1);
     }
   if (re_fsearch ("^\"Last-Translator.*"))
     { 
        () = replace_match (name, 1);
     }
   if (re_fsearch ("^\"Language-Team.*"))
     { 
        () = replace_match (team, 1);
     }
   if (re_fsearch ("^\"Content-Type.*"))
     { 
        () = replace_match (charset, 1);
     }
   if (re_fsearch ("^\"Plural-Forms.*"))
     {
        () = replace_match (plural_str, 1);
     }
   else
     {
        eob ();
        insert ("\n" + plural_str);
     }
   
   widen_region ();
   remove_fuzzy_flag ();
   pop_spot ();
   set_readonly (1);
}

%}}}

%{{{ po_edit buffer

% Here is an outline of the rationale behind the way editing of gettext
% message strings is handled in this mode.
% 
% - Upon loading a po-file, the buffer where the editing of the message
%   string (msgstr) is to be done is created and the po_edit_mode is set 
%   for it. This buffer is kept open all of the time.
%   
%   The function pre_format_msgstr () is then called which converts the
%   C-like printable string format of the message string into a user-friendly
%   editing format, surrounding double quotes and newline literals are
%   expanded.
%   
%   The message-id (msgid), which is the text to be translated, is narrowed in 
%   a fold in the top of a split window and the po_edit buffer is popped up 
%   as the bottom window where the formatted message string is inserted for 
%   editing. The number of lines in the top window is approx. fit to the 
%   number of lines in the message id to get the editing point closer to the 
%   text to be translated.
%   
%   Finally the function setup_edit_buf () is called to set up the editing
%   environment for the po_edit buffer: if the string is multi-line an eob
%   (end-of-buffer) marker is inserted. For single-line strings wrapping is
%   set at 78 characters, a wrap_hook is set which ensures that
%   word-delimiting white space is inserted at the end of each line at wrap
%   point. The enter-key is disabled.
%   
% - When the user presses key to finish editing, the function
%   post_format_msgstr () is called which converts the message string
%   back into the C-like printable format: all lines are surrounded in 
%   double quotes, embedded double quotes are escaped, for multi-line
%   strings embedded newline literals are inserted at every actual
%   newline character.
%   
%   The contents of the po_edit buffer are erased and its window is put
%   in the background and the old message string is replaced by the new
%   one. Statistics are updated.
%   
%   All of this should hopefully make editing completely transparent, with
%   the user not having to worry about anything relating to the formatting
%   of the message string.

static define po_edit_menu (menu)
{
   menu_append_item (menu, "Finish Editing",         "po_end_edit");
   menu_append_item (menu, "Enlarge Msgstr Window",  "enlargewin");
   menu_append_item (menu, "Decrease Msgstr Window", "decreasewin");
   menu_append_item (menu, "Discard Changes",        "del_editbuf");
}

%% Mode for the editing buffer.
static define po_edit_mode ()
{
   use_keymap (Edit_Mode);
   set_abbrev_mode (1);
   if (abbrev_table_p (Edit_Mode)) use_abbrev_table (Edit_Mode);
   run_mode_hooks ("po_edit_mode_hook");
   mode_set_mode_info (Edit_Mode, "init_mode_menu", &po_edit_menu);
   set_buffer_modified_flag (0);
   set_buffer_undo (1);
}

static define create_po_edit_buf ()
{
   variable po_buf = whatbuf ();                          
   setbuf (po_edit_buf);
   po_edit_mode ();
   setbuf (po_buf);
}

static define restore_po_buffer_window ()
{
   otherwindow ();
   onewindow();
   widen_region ();
   bury_buffer (po_edit_buf);
}

static define po_edit_parsep ()
{
   bol_skip_white ();                                                         
   if (eolp ()) return 1;                                                                
   else if (re_looking_at ("^-$")) return 1;                                                                
   else return 0;   
}

%% Thanks to John E. Davis for this solution.
static define po_edit_wrap_hook ()
{
   push_spot ();
   bol ();
   go_left (1);
   insert (" ");
   pop_spot ();
}

static define single_line_newline_hook ()
{
   flush ("single-line format");
}

% Setup of the edit buffer
static define setup_edit_buf ()
{
   if (Multi_Line == 1)
     {
        eob ();
        insert ("\n-");
        set_line_readonly (1);
        set_buffer_hook ("par_sep", &po_edit_parsep);
        unset_buffer_hook ("newline_indent_hook");
        set_mode (Edit_Mode, 0);
     }
   else
     {
        set_buffer_hook ("newline_indent_hook", &single_line_newline_hook);
        WRAP = 78;
        set_buffer_hook ("wrap_hook", &po_edit_wrap_hook);
        set_mode (Edit_Mode, 1); % wrap_mode
     }
   
   bob ();
}

% Simulate a gettext unwrapping of a multi-line msgid in order to get
% the right pattern for newline literals in get_msgid_line_format ().
static define po_unwrap (str)
{
   variable len, pos = 1;
   
   while (string_match (str, "[^\\\\].\n", pos))
     {
        (pos, len) = string_match_nth (0);
        str = strsub (str, pos + len, ' ');
     }
   
   return str;
}

% The formatting done to the msgstr before it is read into the po_edit
% buffer
static define pre_format_msg (str)
{
   variable s, i, alen;
   
   % detect if msgid has embedded newline literals
   if (is_substr (msg_as_string (0), "\\n") or is_header ())
     Multi_Line = 1;
   else
     Multi_Line = 0;
   
   str = str_replace_all (str, "\"\"\n", Null_String);
   str = str_replace_all (str, "\\\"", "\"");
   str = strchop (str, '\n', 0);
   alen = length (str)-1;

   % remove enclosing double quotes
   _for (0, alen, 1)                                                 
    {                                                                        
       i = ();                                                               
       s = str [i];                                                     
       s = s [[1:strlen (s)-2]]; 
       if (Multi_Line == 1)
         {
            s = strtrim_end (s, " ");
            % expand newline literal of the last line
            if (i == alen)
              {
                 if (string_match (s, "\\\\n$", 1))
                   {
                      s = str_replace_all (s, "\\n", "\\n\n");
                   }
              }
         }
       str [i] = s;
    }
   
   str = strjoin (str, "\n");
   
   % make sure that possibly wrapped multi-line strings are unwrapped
   if (Multi_Line == 1)
     {
        str = po_unwrap (str);
     }
   
   str = str_replace_all (str, "\\n", Null_String);
   
   !if (strlen (str))
     Translation_Status = 0;
   else
     Translation_Status = 1;
   
   return str;
}

% The formatting done to the msgstr before it is read back into the po buffer
static define post_format_msgstr ()
{
   variable str, len, alen;

   % remove the eob marker
   if (Multi_Line == 1)
     {
        eob ();
        set_line_readonly (0);
        () = up (1);
        push_mark ();
        eob ();
        del_region ();
     }
   
   mark_buffer ();
   str = bufsubstr ();

   % escape embedded double quotes
   str = str_replace_all (str, "\"", "\\\"");
   
   % insert newline literals
   if (Multi_Line == 1)
     {
        str = str_replace_all (str, "\n", "\\n\n");
     }
   
   str = strchop (str, '\n', 0);

   % remove empty lines
   str = str [where (array_map (Integer_Type, &strlen, str))];
   
   alen = length (str)-1;

   % surround lines in double quotes
   str [[:alen]] = "\"" + str + "\"";
   if (length (str) == 0) str = "\"\"";
   
   str = strjoin (str, "\n");
   len = strlen (str);
   if (len > 72 or alen > 0) str = "\"\"\n" + str;

   return str, len;
}

define decreasewin ()
{
   otherwindow ();
   enlargewin ();
   otherwindow ();
}

define cancel_editbuf ()
{
   erase_buffer ();
   restore_po_buffer_window ();
   set_po_status_line ();
}

% A split window is shown with the msgid to be translated in the top window
% and the translation to be filled in is in the bottom window.
define po_edit ()
{
   if (is_line_hidden ()) return;
   
   variable n, wn, nlines, msgstr, po_buf;
   
   !if (bufferp (po_edit_buf)) create_po_edit_buf ();
   
   if (nwindows == 2 and mode == get_mode_name)
     {
        otherwindow ();
        return;
     }
   
   set_status_line (" ", 0);
   msgstr = pre_format_msg (msg_as_string (1));
   mark ("msgid");
   recenter (1);
   pop2buf (po_edit_buf);
   insert (msgstr);
   otherwindow ();
   narrow_to_region (); % msgid fold
   n = what_line ();
   bob ();
   wn = window_info ('r');
   nlines = wn - n;
   % alert user to msgid not being fully shown
   if (n > wn) set_status_line ("                          -- more --                                             ", 0);
   otherwindow ();
   loop (nlines-2) enlargewin ();
   
   setup_edit_buf ();

   set_buffer_modified_flag (0);
}

%% The finished translation is read back into the po-file
define po_end_edit ()
{
   !if (buffer_modified)
     { 
        cancel_editbuf ();
        position_on ("msgid");
        return;
     }
   
   variable msgstr, len;
   
   (msgstr, len) = post_format_msgstr ();
   erase_buffer ();
   restore_po_buffer_window ();
   set_readonly (0);
   mark ("msgstr");
   del_region ();
   insert (msgstr);
   position_on ("msgstr");
   if (re_looking_at ("^msgstr.[^1]"))
     {
        % msgstr was untranslated but is now translated so increment 
        % translated count by one.
        if (Translation_Status == 0 and len > 2)
          {
             count ("t+");
             if (count ("u") > 0) count ("u-");
          }
        % msgstr was translated but is now untranslated so decrement 
        % translated count by one.
        if (Translation_Status == 1 and len == 2)
          {
             remove_fuzzy_flag ();
             if (count ("t") > 0) count ("t-");
             count ("u+");
          }
     }
   set_po_status_line ();
   set_readonly (1);
   recenter (0);
}

%}}}

%{{{ translator comments

static define po_comment_mode ()
{
   set_mode ("po_comment", 0);
   use_keymap ("po_comment");
   set_buffer_undo (1);
}

static define mark_translator_comment ()
{
   narrow_to_entry ();
   if (orelse
        { re_fsearch (translator_cmt_re) }
        { bol_fsearch ("#,") }
        { re_fsearch (msgid_re)});

   push_mark ();
   while (re_looking_at (translator_cmt_re))
     {
        () = down (1);
     }
   widen_region ();
}

static define strip_comments ()
{
   bob ();
   while (re_looking_at (translator_cmt_re))
     {
        do
          {
             bol (); push_mark ();
             skip_chars ("# \t");
             del_region ();
          }
        while (down (1));
     }
}

static define add_comments ()
{
   if (eobp () and bobp ()) return;
   bob ();
   do
     {
        bol (); insert ("# ");
     }
   while (down (1));
   eob ();
   newline ();
}

define del_translator_comment ()
{
   set_readonly (0);
   mark_translator_comment ();
   del_region ();
   set_readonly (1);
}

%% Insert a translator comment or edit an existing one
define po_edit_comment ()
{
   variable po_buf;
   po_cmt_buf = "*" + whatbuf () + "*";
   mark_translator_comment ();
   exchange_point_and_mark ();
   recenter (1);
   po_buf = pop2buf_whatbuf (po_cmt_buf);
   setbuf (po_buf);
   copy_region (po_cmt_buf);
   setbuf (po_cmt_buf);
   strip_comments ();
   po_comment_mode ();
   set_buffer_modified_flag (0);
   bob ();
}

define po_end_edit_comment ()
{
   !if (buffer_modified)
     {
        delbuf (po_cmt_buf);
        restore_po_buffer_window ();
        return;
     }
   
   eob ();
   bskip_chars (" \t\n");
   while (not eobp ()) del ();
   add_comments ();
   mark_buffer ();
   set_buffer_modified_flag (0);
   restore_po_buffer_window ();
   del_translator_comment ();
   set_readonly (0);
   insbuf (po_cmt_buf);
   delbuf (po_cmt_buf);
   position_on ("msgid");
   set_readonly (1);
}

%}}}

%{{{ modification of entries outside of po_edit buffer

static define trim_buf ()
{
   do
     {
        trim (); eol (); trim ();
     }
   while (down (1));
   
   bob ();
}

static define delete_entry ()
{
   narrow_to_entry ();
   mark_buffer ();
   del_region ();
   widen_region ();
}
 
static define del_msgstr ()
{
   mark ("msgstr");
   del_region ();
}

%% Delete an obsolete entry
define del_obsolete ()
{
   position_on ("msgid");
   !if (looking_at ("#~"))
     error ("not an obsolete entry");
   else
     {
        set_readonly (0);
        delete_entry ();
        if (eolp () and bolp ()) del ();
        set_readonly (1);
        if (count ("o") > 0) count ("o-");
        set_po_status_line ();
     }
}

%% Remove contents of msgstr (leaving it unstranslated)
define cut_msgstr ()
{
   push_spot ();
   position_on ("msgstr");
   if (looking_at ("#~") or is_untranslated ()) return pop_spot ();
   remove_fuzzy_flag ();
   set_readonly (0);
   del_msgstr ();
   insert ("\"\"");
   bol ();
   if (re_looking_at ("^msgstr.[^1]"))
     {
        count ("t-");
        count ("u+");
     }
   set_po_status_line ();
   set_readonly (1);
   pop_spot ();
}

%% Copy contents of msgid to msgstr
define copy_msgid_to_msgstr ()
{
   if (is_header ()) return;
   
   variable msgid, msgstr;
   
   msgid = msg_as_string (0);
   msgstr = msg_as_string (1);
   
   position_on ("msgstr");
   if (re_looking_at ("^msgstr.[^1]"))
     {
        if (strlen (msgstr) == 2) % untranslated
          {
             count ("u-"); count ("t+");
             set_po_status_line ();
          }
        else
          {
             !if (get_y_or_n ("Overwrite previous translation")) return;
          }
     }
   set_readonly (0);
   push_spot ();
   del_msgstr ();
   if (strlen (msgid) > 72 or is_substr (msgid, "\n"))
     insert ("\"\"\n" + msgid);
   else
     insert (msgid);
   
   pop_spot ();
   set_readonly (1);
}

define copy_msgstr ()
{
   create_blocal_var ("msgstr_dup");
   push_spot ();
   mark ("msgstr");
   set_blocal_var (bufsubstr (), "msgstr_dup");
   pop_spot ();
   flush ("msgstr copied");
}

define insert_msgstr ()
{
   !if (blocal_var_exists ("msgstr_dup"))
     error ("nothing to insert");

   variable str = get_blocal_var ("msgstr_dup");
   position_on ("msgstr");
   if (is_untranslated ())
     {
        if (count ("u") > 0) count ("u-");
        count ("t+");
        set_po_status_line ();
     }
   else
     {
        !if (get_y_or_n ("Overwrite previous translation")) return;
     }
   set_readonly (0);
   del_msgstr ();
   insert (str);
   set_readonly (1);
}

%% Search and replace strings within msgstrs
define replace_in_msgstrs ()
{
   variable pat, rep, prompt, word;
   
   pat = read_mini ("Replace in msgstrs:", Null_String, Null_String);                     
   !if (strlen (pat)) return;                                                 
   prompt = strcat (strcat ("Replace '", pat), "' with:");                    
   rep = read_mini (prompt, "", "");                
   
   push_spot_bob ();

   while (fsearch (pat))
     {
        po_edit ();
        while (fsearch (pat))
          {
             word = po_mark_word (1);
             if (string_match (word, sprintf ("^%s$", pat), 1))
               insert (rep);
             else
               insert (word);
          }
        po_end_edit ();
        position_on ("entry_end");
     }
   pop_spot ();
   flush ("done");
}

define po_undo ()
{
   variable n = get_current_entry_number ();
   set_readonly (0);
   call ("undo");
   restore_entry_position (n);
   po_statistics ();
   set_readonly (1);
}

%}}}

%{{{ various gettext functions

static define check_enc ()
{
   if (NULL == prg_found_in_path ("file")) return -1;

   variable header_enc, cmd;
   push_spot_bob ();
   () = fsearch ("charset=");
   skip_chars ("charset=");
   push_mark ();
   () = ffind ("\\");
   header_enc = bufsubstr ();
   cmd = sprintf ("file -i - | grep -i %s", header_enc);
   mark_buffer ();
   !if (0 == pipe_region (cmd))
     {
        pop_spot ();
        return 0;
     }
   else
     {
        pop_spot ();
        return 1;
     }
}

static define check_integrity (file)
{
   variable msg = sprintf ("checking integrity of %s ...", file);
   variable buf = whatbuf ();
   
   flush (msg);
   
   !if (1 == file_status (file))
     {
        flush (sprintf ("file not found", file));
        return 0;
     }
   
   if (0 == system (sprintf ("%s %s 2>/dev/null", 
                             "msgfmt -c -o /dev/null", file)) and
       0 == system (sprintf ("%s%s %s 2>/dev/null", 
                             "msgcat -o /dev/null --to-code=", Charset, file)))
     {
        flush (sprintf ("%s %s", msg, "(ok)"));
        sleep (0.2);
        return 1;
     }
   else
     {
        flush (sprintf ("%s %s", msg, "(failed)"));
        sleep (0.2);
        return 0;
     }
}

%% Check po-file for syntax errors and character set conversion errors
define po_validate_command ()
{
   if (NULL == prg_found_in_path ("msgfmt"))
     error ("gettext utilities not installed");
   
   variable tmpfile = make_tmp_file ("/tmp/po_validate");
   variable cmd_v, cmd_c;
   cmd_v = sprintf ("%s >> %s %s", 
                    "msgfmt - --statistics -c -v -o /dev/null", tmpfile, "2>&1");
   cmd_c = sprintf ("%s%s >>%s %s",
                    "msgcat - -o /dev/null --to-code=", Charset, tmpfile, "2>&1");

   flush ("validating file ...");
   push_spot ();
   mark_buffer ();
   () = dupmark ();
   () = append_string_to_file 
     ("*** Output from validation with msgfmt ***:\n\n", tmpfile);
   () = pipe_region (cmd_v);
   () = append_string_to_file ("\n-----\n", tmpfile);
   () = append_string_to_file 
     ("\n*** Output from encoding conversion test ***:\n", tmpfile);
   () = pipe_region (cmd_c);
   () = append_string_to_file ("\n-----\n", tmpfile);
   
   if (0 == check_enc ())
     () = append_string_to_file 
     ("\nNB: Charset encoding in header does not match that of the document.", tmpfile);
   pop_spot ();
   recenter (1);
   pop2buf ("*Validation Output*");
   () = insert_file (tmpfile);
   set_buffer_modified_flag (0);
   most_mode ();
   bob ();
   () = delete_file (tmpfile);
   % update (1);
   call ("redraw");
}

%% Compile the po-file *.po -> *.mo
define po_compile ()
{
   if (NULL == prg_found_in_path ("msgfmt"))
     error ("msgfmt program not found in $PATH");
   
   variable dir = dircat (getenv ("HOME"), Null_String);
   variable cmd = read_mini ("Compile command: ", "", "msgfmt" +
                             " -o " + dir + path_sans_extname (whatbuf()) +
                             ".mo " + whatbuf());
   if (strlen (cmd)) compile (cmd);
}

%% Use the gettext program 'msgunfmt' to decompile a *.mo file and read it
%% into the editor
define po_decompile ()
{
   if (NULL == prg_found_in_path ("msgunfmt"))
     error ("msgunfmt program not found in $PATH");
   
   variable mo_file = read_with_completion ("*.mo-file:", "", "", 'f');
   variable po_file = dircat (getenv ("HOME"),
                              strcat (path_sans_extname
                                      (path_basename (mo_file)) + ".po"));
   
   if (1 == file_status (po_file))
     {
        vmessage ("File %s exists, overwrite? (y/n)", po_file); update (1);
        if ('y' == getkey ());
        else return;
     }
   () = system (strcat ("msgunfmt ", mo_file, " > ", po_file));
   () = find_file (po_file);
}

%% Use msgcat to wrap/unwrap entries
static define wrap_entries (wrap)
{
   if (NULL == prg_found_in_path ("msgcat"))
     error ("msgcat program not found in $PATH");

   variable n = get_current_entry_number ();
   variable status;
   
   variable tmpfile = make_tmp_file ("/tmp/po_tmpfile");
   variable newfile = make_tmp_file ("/tmp/po_newfile");
   
   write_tmp_buffer (tmpfile);
   
   if (wrap)
     {
        flush ("wrapping entries ...");
        status = system (sprintf ("%s %s > %s 2>/dev/null",
                                  "msgcat", tmpfile, newfile));
     }
   else
     {
        flush ("unwrapping entries ...");
        status = system (sprintf ("%s %s > %s 2>/dev/null", 
                                  "msgcat --no-wrap", tmpfile, newfile));
     }
   
   !if (status == 0)
     {
        () = delete_file (tmpfile);
        () = delete_file (newfile);
        return flush ("error in file");
     }
   
   set_readonly (0);
   erase_buffer ();
   () = insert_file (newfile);
   () = delete_file (tmpfile);
   () = delete_file (newfile);
   set_readonly (1);
   restore_entry_position (n);
   flush ("done");
}

define toggle_wrap ()
{
   if (Wrap_Status)
     {
        wrap_entries (0);
        Wrap_Status = 0;
     }
   else
     {
        wrap_entries (1);
        Wrap_Status = 1;
     }
}

%% Update current po-file to newer version with gettext msgmerge
define po_file_update ()
{
   if (NULL == prg_found_in_path ("msgmerge"))
     error ("msgmerge program not found in $PATH");
   
   variable oldfile = make_tmp_file ("/tmp/oldfile");
   variable merged_file = make_tmp_file ("/tmp/newfile");
   variable pot_file = read_with_completion ("Path to newer file:", "", "", 'f');
   
   write_tmp_buffer (oldfile);
   
   if (buffer_modified ()) save_buffer ();
   
   flush ("updating po-file ...");
   !if (0 == system (sprintf ("%s %s %s -o %s >/dev/null 2>&1",
                              "msgmerge" , oldfile, pot_file, merged_file)))
     {
        delete_file (oldfile);
        delete_file (merged_file);
        error ("could not merge files, syntax errors probably");
     }
   set_readonly (0);
   erase_buffer ();
   () = insert_file (merged_file);
   delete_file (oldfile);
   delete_file (merged_file);
   bob ();
   po_statistics ();
   flush ("save under a new name if you want to keep the old version");
   set_readonly (1);
}

%% Use gettext msgconv to apply a different character set encoding
define conv_charset ()
{
   if (NULL == prg_found_in_path ("msgconv"))
     error ("msgconv program not found in $PATH");
   
   variable oldfile = make_tmp_file ("/tmp/conv_charset_old");
   variable newfile = make_tmp_file ("/tmp/conv_charset_new");
   variable charset;
   variable n = get_current_entry_number ();
   variable encodings = 
     "ascii,iso-8859-1,iso-8859-2,iso-8859-3,iso-8859-4,iso-8859-5,"+
     "iso-8859-6,iso-8859-7,iso-8859-8,iso-8859-9,iso-8859-13,iso-8859-14,"+
     "iso-8859-15,koi8-r,koi8-u,koi8-t,cp850,cp866,cp874,cp932,cp949,"+
     "cp950,cp1250,cp1251,cp1252,cp1253,cp1254,cp1255,cp1256,cp1257,gb2312,"+
     "euc-jp,euc-kr,euc-tw,big5,big5-hkscs,gbk,gb18030,shift_jis,johab,tis-620,"+
     "viscii,georgian-ps,utf-8";
   
   charset = read_with_completion (encodings, "Convert to? <tab>:", 
                                   Charset, "", 's');
   write_tmp_buffer (oldfile);
   
   vmessage ("converting to %s ...", charset); update (1);
   !if (0 == system (sprintf ("%s%s %s > %s",
                              "msgconv --to-code=", charset, oldfile, newfile)))
     {
        () = delete_file (oldfile);
        () = delete_file (newfile);
        error ("syntax errors or locale not installed, could not convert");
     }
   
   set_readonly (0);
   erase_buffer ();
   () = insert_file (newfile);
   () = delete_file (oldfile);
   () = delete_file (newfile);
   set_readonly (1);
   restore_entry_position (n);
}

define mark_fuzzy_all ()
{
   !if (get_y_or_n ("Flag all entries fuzzy")) return;
   
   if (NULL == prg_found_in_path ("msgattrib"))
     error ("msgattrib program not found in $PATH");
   
   variable n = get_current_entry_number ();
   variable tmpfile = make_tmp_file ("/tmp/po_fuzzy_all");
   variable cmd = 
     sprintf ("%s > %s 2>/dev/null","msgattrib --set-fuzzy", tmpfile);
   
   flush ("flagging all translations fuzzy ...");                                   
   mark_buffer ();                                                            
   !if (0 == pipe_region (cmd))
     {
        flush ("errors in current file");  
        restore_entry_position (n);
        () = delete_file (tmpfile);
        return;
     }
   set_readonly (0);
   erase_buffer ();
   () = insert_file (tmpfile);
   () = delete_file (tmpfile);
   set_readonly (1);
   restore_entry_position (n);
   po_statistics ();
   flush ("done");
}

%}}}

%{{{ source view, grep source, mail, spell check, help window, limit

%% Get source references and return them as a formatted string
static define po_mark_src_str ()
{
   push_spot ();
   narrow_to_entry ();
   !if (bol_fsearch ("#:"))
     {
        widen_region ();
        pop_spot ();
        error ("no source reference");
     }
   push_mark ();
   while (looking_at ("#:"))
     {
        () = down (1);
     }
   bufsubstr ();
   str_replace_all("\n", " ");
   str_replace_all ("#: ", Null_String);
   strtrim (); % leave on stack
   widen_region ();
   pop_spot ();
}

%% Exit po_mode
define edit_whole_buffer ()
{
   no_mode ();
   use_keymap ("global");
   set_readonly (0);
   call ("redraw");
   set_status_line ("", 0);
   flush ("use \"M-x po_mode\" to return");
}

%% Set the path to source files
define set_source_path ()
{
   variable s = read_with_completion ("Source dir:", "", "", 'f');
   if (strlen (s))
     {
        create_blocal_var ("Source_Dir");
        set_blocal_var (s, "Source_Dir");
     }
}

%% Pop up windows containing files from source references for viewing
define view_source ()
{
   variable str, buf, ln, line, srcfile;
   variable cnt = 1;

   str = po_mark_src_str ();
   ln = length (strchop (str, ' ', 0));

   foreach (strchop (str, ' ', 0))
     {
        $0 = ();
        $1 = strchop ($0, ':', 0);
        buf = $1[0];
        line = $1[1];
        !if (blocal_var_exists ("Source_Dir"))
          {
             set_source_path ();
          }
        srcfile = path_concat (get_blocal_var ("Source_Dir"), buf);
        !if (1 == file_status (srcfile))
          {
             vmessage ("Source file %s not found (use 'S' to set the path)", srcfile);
             return;
          }
        variable oldbuf = pop2buf_whatbuf (buf);
        () = insert_file (srcfile);
        set_buffer_modified_flag (0);
        set_readonly (1);
        goto_line (integer (line));
        local_setkey ("close_file", "q");
        c_mode ();
        onewindow ();

        if (ln > 1)
          {
             vmessage ("%s %d %s %d %s", "Source reference", cnt, "of", ln,
                       "(space cycles, 'q' closes window, other key to scroll)");
             while (cnt == ln)
               {
                  vmessage ("%s %d %s %d %s", "Source reference", cnt, "of",
                            ln, "(space or 'q' closes window, other key to scroll)");
                  break;
               }
          }
        else vmessage ("%s %d %s %d %s", "Source reference", cnt, "of", ln,
                       "(space or 'q' closes window, other key to scroll)");

        update (1);
        variable ch = getkey ();
        switch (ch)
          { ch == ' ': delbuf (buf); sw2buf (oldbuf); cnt++; }
          { ch == 'q': delbuf (buf); return; }
          { ch != ' ' or 'q': flush ("'q' closes window"); return; }
     }
}

%% Grep for a string in the source directory. Requires grep.sl
define grep_src ()
{
   !if (blocal_var_exists ("Source_Dir"))
     {
        set_source_path ();
     }
   
   variable str, srcdir;
   
   if (markp ())
     str = bufsubstr ();
   else
     str = po_mark_word (0);
     
   str = read_mini ("Search for:", str, "");
   str = str_quote_string (str, "\\^$[]*.+\"", '\\');
   str = "'" + str + "'";
   srcdir = get_blocal_var ("Source_Dir");
   grep (str, srcdir);
   call ("redraw");
}

%% Toggle limitation of display to entries containing word or a string of words.
define limit_view ()
{
   variable expr, matches = 0;
   
   if (View_Limit == 0)
     {
        entry_number = get_current_entry_number ();
        if (markp ()) expr = bufsubstr ();
        else expr = po_mark_word (0);
        expr = read_mini ("Limit to:", expr, "");
        !if (strlen (expr)) return;
        push_spot_bob ();
        push_mark ();
        while (fsearch (expr))
          {
             if (bfind ("#: "))
               {
                  eol ();
                  continue;
               }
             position_on ("entry_start");
             () = up (1);
             set_region_hidden (1);
             position_on ("entry_end");
             () = down (1);
             push_mark ();
             matches++;
          }
        eob ();
        set_region_hidden (1);
        set_status_line (sprintf (" (PO) Limit: %d entries matching \"%s\"",
                                  matches, expr), 0);
        
        pop_spot ();
        flush ("'l' unlimits");
        View_Limit = 1;
        
     }
   else
     {
        mark_buffer ();
        set_region_hidden (0);
        View_Limit = 0;
        set_po_status_line ();
        restore_entry_position (entry_number);
        recenter (0);
     }
}

%% Send po-file to the translation robot, language team or Debian BTS.
define mail_po_file ()
{
   if (orelse { count ("u") != 0 } { count ("f") != 0 } { count ("o") != 0 })
     !if (get_y_or_n ("Unprocessed entries remain, continue")) return;

   variable buf = whatbuf ();
   variable cmd = "gzip -9 | uuencode -m";
   variable po_robot, debian_bts, recipient;
   variable file = strcat (buf + ".gz");
   variable tmpfile = make_tmp_file ("/tmp/pomail");
   variable package_file, package, version;
   
   po_robot = "The Free Translation Project <translation@iro.umontreal.ca>";
   debian_bts = "Debian Bug Tracking System <submit@bugs.debian.org>";
   
   % a canonical Debian file name is e.g. geneweb_4.10-4_da.po, where the first
   % part corresponds to the package name in the package database and the 
   % second part to its version number.
   package_file = strchop (buf, '_', 0);
   if (length (package_file) == 3)
     {
        if (string_match (package_file[1], "[0-9]+", 1))
          {
             package = package_file[0];
             version = package_file[1];
          }
     }
   else
     {
        package = "";
        version = "";
     }
   
   switch (get_mini_response 
           ("Mail your team[t], translation robot[r] or Debian BTS[d] ?"))
     { case 't': recipient = 1; }
     { case 'r': recipient = 2; }
     { case 'd': recipient = 3; }
     { case not 't' or 'r' or 'd': flush ("no recipient!"); return; }
   
   !if (1 == recipient)
     { 
        wrap_entries (0); % unwrap entries for robot
        write_tmp_buffer (tmpfile);
        
        !if (check_integrity (tmpfile))
          {
             () = delete_file (tmpfile);
             error ("errors in file, use (V)alidate to find and then correct");
          }
        !if (NULL == prg_found_in_path ("uuencode"))
          {
             push_spot ();
             mark_buffer ();
             () = pipe_region (sprintf ("%s > %s %s",
                                        cmd, tmpfile, file));
             pop_spot ();
          }
        else
          {
             () = delete_file (tmpfile);
             error ("uuencode program not found");
          }
     }
   else 
     {
        wrap_entries (1);
        write_tmp_buffer (tmpfile);
     }

   recenter (1);
   mail ();
   
   switch (recipient)
     { case 1:
        insert (Language_Team);
        () = bol_fsearch ("Subject:"); eol ();
        insert (read_mini ("Subject:", buf, "")); }
   
     { case 2:
        insert (po_robot);
        () = bol_fsearch ("Subject:");  eol ();
        % mandatory subject when submitting files to robot
        vinsert ("%s %s", "TP-Robot", buf); }
   
     { case 3:
        insert (debian_bts);
        () = bol_fsearch ("Subject:"); eol ();
        insert (read_mini ("Subject:", "", ""));
        eob (); newline ();
        package = read_mini ("Package name:", package, "");
        
        !if (strlen (package))
          {
             () = delete_file (tmpfile);
             error ("you must specify the name of the package");
          }
        
        flush (sprintf ("looking up \"%s\" in package database ...", package));
        
        !if (0 == system (sprintf ("dpkg -l %s >/dev/null 2>&1", package)))
          {
             () = delete_file (tmpfile);
             verror ("package \"%s\" does not exist in package database", package);
          }
        vinsert ("Package: %s\n", package);
        version = read_mini ("Version number? (ok to leave blank):", version, "");
        if (strlen (version)) vinsert ("Version: %s\n", version);
        insert ("Severity: wishlist\nTags: patch l10n");
     }
   
   eob (); newline (); push_spot ();
   
   if (3 == recipient)
     {
        insert ("\nUuencoded file follows. Please pipe mail to\n" +
                "uudeview or uudecode program to extract file.\n\n");
     }
   () = insert_file (tmpfile);
   () = delete_file (tmpfile);
   flush ("type \"M-x mail_send\" to send");
   pop_spot ();
}

%% Display help window
define show_help ()
{
   variable file = expand_jedlib_file ("po_mode.hlp");
   
   !if (1 == file_status (file))
     {
        vmessage ("The file %s was not found in Jed's library path", file);
        return;
     }
   
   () = find_file (file);
   most_mode ();
   flush ("scroll down for more. 'q' closes help window");
}

%% Send a bug report
define reportbug ()
{
   mail ();
   insert ("Morten Bo Johansen <mojo@mbjnet.dk>");
   () = bol_fsearch ("Subject:"); 
   eol ();
   insert ("[po_mode] ");
}

%% Interactively spell check msgstrs with ispell or aspell. If xjed is used,
%% the interactive spelling process will be opened in a separate terminal 
%% window
define po_spellcheck ()
{
   if (count ("t") == 0)
     return flush ("nothing to spell check");

   if (NULL == prg_found_in_path ("pospell"))
     return flush ("spellutils not installed or $PATH is incomplete");

   if (NULL == prg_found_in_path (Spell_Prg))
     return vmessage ("%s %s", Spell_Prg, "not found in $PATH");
   
   variable TermPrg;
   
   !if (NULL == prg_found_in_path ("rxvt"))
     TermPrg = "rxvt -e ";
   else
     TermPrg = "xterm -e ";

   variable tmpfile, aspell_cmd, ispell_cmd, line, status;
   variable n = get_current_entry_number ();
   
   tmpfile = make_tmp_file ("/tmp/spellfile");
   
   aspell_cmd = strcat ("pospell -n ", tmpfile, " -p ",
                        Spell_Prg, " -- -c -d ", Spell_Dict, " %f");
   ispell_cmd = strcat ("pospell -n ", tmpfile, " -p ",
                        Spell_Prg, " -- -x -C -d ", Spell_Dict, " %f");

   write_tmp_buffer (tmpfile);
   
   if (Spell_Prg == "ispell")
     {
        if (is_defined ("x_server_vendor"))
          status = system (strcat (TermPrg, ispell_cmd));
        else 
          status = run_program (ispell_cmd);
     }
   if (Spell_Prg == "aspell")
     {
        if (is_defined ("x_server_vendor"))
          status = system (strcat (TermPrg, aspell_cmd));
        else 
          status = run_program (aspell_cmd);
     }
   set_readonly (0);
   erase_buffer ();
   () = insert_file (tmpfile);
   set_readonly (1);
   restore_entry_position (n);
   () = delete_file (tmpfile);
   () = system (sprintf ("%s %s", "rm >/dev/null 2>&1", "/tmp/newsbody*"));
   if (status > 11)
     flush ("spell checking failed");
}
   
%}}}

%{{{ wordlists

%% Strip regular verbs of conjugations so they appear in the infinitive form,
%% nouns of plural endings so they appear in singular and adjectives of
%% their adverbial endings. The rules have been checked against about 10 MB of
%% po-files and litterature text from the Gutenberg project and they get it
%% right about 99.5% of the time. Nontheless a few of the rules are somewhat
%% crude, so in the actual lookup in the wordlist, lookup is performed for
%% word in both verbatim and stripped forms.
static define strip_word (word)
{
   word = strlow (word);

   variable  word_1, word_2, word_3, word_4, char_1, char_2, char_3, char_4;
   
   (word_1, char_1) = strip_chars (word, 1);
   (word_2, char_2) = strip_chars (word, 2);
   (word_3, char_3) = strip_chars (word, 3);
   (word_4, char_4) = strip_chars (word, 4);

   forever
     {
        % e.g. ponies -> pony, tried -> try
        if (string_match (word, "ie[ds]$", 1)) 
          {
             if (is_list_element ("series", word, ',')) break;
             if (strlen (word) < 5)
               {
                  word = word_1;
                  break;
               }
             
             word = word_3 + "y";
             break;
          }
   
        % ****** PLURAL NOUNS AND THIRD PERSON SINGULAR VERBS ******
        if (string_match (word, "[^aious]s$", 1))
          {
             word = word_1;
             break;
          }

        % ****** ING FORM ******
        if (string_match (word, "ing$", 1))
          {
             if (0 == strcmp (char_3, char_4))
               { 
                  word = word_4;
                  break;
               }
             
             word = word_3 + "e";
             break;
          }
        
        % ****** ADVERBS ******
        if (string_match (word, "ly$", 1))
          {
             word = word_2;
             break;
          }

        % ****** (mostly) REGULAR PAST TENSE VERBS *******
        
        if (string_match (word, "[^e]ed$", 1))
          {
             if (string_match (word, "^un", 1)) break;
             
             if (is_list_element ("bled,fed,bred,sped", word, ','))
               {
                  word = word_2 + "eed";;
                  break;
               }

             % double consonant words like "begged", "hopped" etc.
             if (0 == strcmp (char_2, char_3) and char_2 != "l")
               {
                  if (orelse {char_3 == "f"}{char_3 == "o"}{char_3 == "s"})
                    { 
                       word = word_2;
                       break;
                    }
                  word = word_3;
                  break;
               }

             if (is_list_element ("y,w,x", char_2,  ','))
               { 
                  word = word_2;
                  break;
               }
             if (is_list_element ("c,u,v,z", char_2,  ','))
               { 
                  word = word_1;
                  break;
               }

             switch (char_2)
               { case "b": 
                  if (is_list_element ("bed,deathbed,embed", word, ',')) break;
                  if (string_match (word, "[aeiou]bed$", 1))
                    word = word_1;
                  else 
                    word = word_2;
                  break;
               }
               { case "d":
                  if (string_match (word, "[^aeo][aeiou]ded$", 1)) 
                    word = word_1;
                  else
                    word = word_2;
                  break;
               }
               { case "f": 
                  if (string_match (word, "[^a]fed$", 1))
                    word = word_2;
                  else
                    word = word_1;
                  break;
               }
               { case "g": 
                  if (orelse
                      { is_list_element ("clanged,fanged,hanged,ringed", word, ',') }
                      { string_match (word, "onged$", 1) } )
                        { 
                           word = word_2;
                           break;
                        }
                  word = word_1;
                  break;
               }
               { case "h":
                  if (is_list_element ("shed,bloodshed,openmouthed", word, ',')) break;
                  if (string_match (word, "[aei]thed$", 1))
                    {
                       word = word_1;
                       break;
                    }
                  if (string_match (word, "[^eot][ae]ched$", 1))
                    {
                       word = word_1;
                       break;
                    }
                  word = word_2;
                  break;
               }
               
               { case "k": 
                  if (is_list_element ("crooked,naked", word,  ',')) break;
                  if (string_match (word, "[^eo][aio]ked$", 1)) word = word_1;
                  else word = word_2;
                  break;
               }
               { case "l":
                  if (is_list_element ("led,fled,sled", word, ',')) break;
                  if (0 == strcmp (char_2, char_3))
                    { 
                       if (strlen (word) <= 8 )
                         {
                            word = word_2;
                            break;
                         }
                       if (string_match (word, "[^ctw][aeiou]lled$", 1))
                         word = word_3;
                       else
                         word = word_2;
                       break;
                    }
                  if (string_match (word, "[bcdfgkpstz]led$", 1))
                    {
                       word = word_1;
                       break;
                    }
                  if (string_match (word, "[^aeno][aciouy]led$", 1))
                    word = word_1;
                  else
                    word = word_2;
                  break;
               }
               { case "m": 
                  if (string_match (word, "[^aeot][aeiou]med$", 1))
                    word = word_1;
                  else
                    word = word_2;
                  break;
               }
               { case "n": 
                  if (string_match (word, "[^adeikost][aiou]ned$", 1))
                    word = word_1;
                  else
                    word = word_2;
                  break;
               }
               { case "o":
                  if (string_match (word, "[^t]oed$", 1))
                    word = word_2;
                  else
                    word = word_1;
                    break;
               }
               { case "p":
                  if (string_match (word, "[^e][aiy]ped$", 1))
                    word = word_1;
                  else
                    word = word_2;
                  break;
               }
               { case "r": 
                  if (is_list_element ("goodnatured,red,hatred,hundred,kindred,sacred,shred", word, ',')) break;
                  if (string_match (word, "[acinou][bhlnpst]ored$", 1))
                    { 
                       word = word_2;
                       break;
                    }
                  if (string_match (word, "[^ameov][aiovu]red$", 1))
                    word = word_1;
                  else
                    word = word_2; 
                  break;
               }
               { case "s": 
                  if (is_list_element ("aliased,biased,antialiased", word,  ','))
                    { 
                       word = word_2;
                       break;
                    }
                  if (string_match (word, "sed$", 1)) word = word_1; break;
               }
               { case "t": if (string_match (word, "[^aeko][aeou]ted$", 1))
                    word = word_1;
                  else
                    word = word_2;
                  break;
               }
          }
        
        break;
     }
   
   return word;
}

static define run_dict_checks (word)
{
   if (NULL == prg_found_in_path ("iconv"))
     dict_error_msg = "iconv program not present";
   else if (NULL == prg_found_in_path ("dict"))
     dict_error_msg = "dict client program not installed";
   
   else !if (string_match (Dict_Dictionary, "^fd-.*", 1))
     dict_error_msg = "you must use one of the Freedict translation" +
                      "dictionaries, e.g \"fd-eng-deu\"";
   
   variable dict_cmd = "dict -P - -C -d";
   variable status;
   
   status = run_shell_cmd (sprintf ("%s %s %s >/dev/null 2>&1",
                                    dict_cmd, Dict_Dictionary, word));
   
   switch (status)
     { case 22: dict_error_msg = "No databases available"; }
     { case 30: dict_error_msg = "Unexpected response code from server"; }
     { case 31: dict_error_msg = "Server is temporarily unavailable"; }
     { case 37: dict_error_msg = "Access denied"; }
     { case 39: dict_error_msg = "Invalid database"; }
     { case 41: dict_error_msg = "Connection to server failed"; }
   
   dict_checks = 1;
}

%% Look up a word translation in a freedict dictionary and return the result.
static define dict_lookup_word (word)
{
   variable trans = "", def = "", cmd = "";
   variable grep_cmd = "egrep \"       [a-zA-Z\\(]\"";
   variable dict_cmd = "dict -P - -C -d";
   variable fp, status;
   variable word_stripped = strip_word (word);
   
   % At least in the English/German dict wordlist, sometimes the 
   % verbs are listed as "to <verb>" and searches will fail if you
   % omit the "to" prefix, so search for word both with and
   % without the "to" prefix, as well as word in stripped form.
   % This will create some duplicates in the output , but they are 
   % removed again in lookup_word ()
   !if (is_substr (word, " "))
     word = sprintf ("%s %s \"to %s\"", word, word_stripped, word_stripped);
   
   if (dict_checks == 0)
     {
        run_dict_checks (word);
        if (strlen (dict_error_msg))
          {
             return Null_String;
          }
     }

   cmd = sprintf ("%s %s %s | %s | iconv -f utf8 -t %s",
                  dict_cmd, Dict_Dictionary, word, grep_cmd, Charset);

   fp = popen (cmd, "r");
   
   if (fp != NULL)
     {
        () = fread (&trans, String_Type, 1000, fp);
     }
   
   () = pclose (fp);
   
   trans = str_replace_all (trans, "\n", ",");
   return trans;
}

%% Look up word in a custom wordlist. Look up word both verbatim and stripped
static define custom_lookup_word (word)
{

   variable buf = whatbuf ();
   variable wordlist_buf = path_basename (Custom_Wordlist);
   variable trans = "", word_stripped = "";
   
   !if (1 == file_status (Custom_Wordlist))
     { 
        vmessage ("wordlist %s not found", Custom_Wordlist);
        return trans;
     }

   word = strtrim (word, "\"");
   word_stripped = strip_word (word);
   
   if (bufferp (wordlist_buf))       
     {
        setbuf (wordlist_buf);
        bob ();
     }
   else
     {
        () = read_file (Custom_Wordlist);
     }

   bury_buffer (wordlist_buf);
   
   while (bol_fsearch (word + ":"))
     {
        () = ffind (":");
        skip_chars (": \t");
        push_mark_eol ();
        trans += bufsubstr () + ",";
     }
   
   bob ();
   
   while (bol_fsearch (word_stripped + ":"))
     {
        () = ffind (":");
        skip_chars (": \t");
        push_mark_eol ();
        trans += bufsubstr () + ",";
     }

   setbuf (buf);
   return trans;
}

%% Look up translation for a word in a custom wordlist. If word is not
%% found there, then look it up in a dict dictionary of choice. It is bound
%% to a double click with the mouse or 'd'. See po_mode.hlp on format of
%% custom wordlist.
define lookup_word (word, auto)
{
   variable def = "", tran = "", trans = "", ctrans = "", dtrans = "";
   variable word_stripped = strip_word (word);
   variable prompt;
     
   !if (strlen (word))
     {
        if (markp ())
          word = sprintf ("\"%s\"", bufsubstr ());
        else
          word = po_mark_word (0);
      }
   
   word = strlow (word);
   
   prompt = sprintf ("%s ->:", word);
   
   switch (Use_Wordlist)
     { case 1: ctrans = custom_lookup_word (word); }
     { case 2:
        if (strlen (word) >= Dict_Minimum_Wordsize)
          {
             dtrans = dict_lookup_word (word);
             if (strlen (dict_error_msg)) error (dict_error_msg);
          }
     }
     { case 3: 
        !if (strlen (dict_error_msg))
          {
             if (strlen (word) >= Dict_Minimum_Wordsize)
               {
                  dtrans = dict_lookup_word (word);
               }
          }
        ctrans = custom_lookup_word (word);
     }

   ERROR_BLOCK 
     { 
        if (nwindows == 2 and "PO" == get_mode_name) otherwindow ();
        error ("quit");
     }

   trans = strcat (ctrans, ",", dtrans);
   trans = strcompress (trans, " ");
   trans = str_replace_all (trans, ", ", ",");
   trans = strtrim (trans, ",");
   trans = strchop (trans, ',', 0);
   def = trans [0];
   trans = sort_uniq (trans); % sort and remove duplicates
   trans = strjoin (trans, ",");
   
   if (auto) return def;
   
   !if (strlen (def)) verror ("no translation for \"%s\"", word);
   tran = read_with_completion (trans, prompt, def, "", 's');
   
   if (nwindows == 2 and "PO" == get_mode_name)
     { 
        otherwindow ();
        insert (tran + " ");
     }
   else
     {
        po_edit ();
        insert (tran + " ");
        po_end_edit ();
        !if (is_fuzzy ()) fuzzy_or_obsolete_entry ();
        recenter (0);
     }
   
   if (strlen (dict_error_msg))
     {
        flush (sprintf ("dict: %s", dict_error_msg));
     }
}

static define po_mouse_2click_hook (line, col, but, shift)
{
   lookup_word (Null_String, 0);
   return (0);
}

%% Look up translation for every word in every msgid
define wordlist_lookup_all ()
{
   flush ("Use Wordlist(s)?: 1 = custom, 2 = dict, 3 = both, q = abort" );
   
   switch (getkey ())
     { case '1': Use_Wordlist = 1; }
     { case '2': Use_Wordlist = 2; }
     { case '3': Use_Wordlist = 3; }
     { case 'q': return flush ("quit"); }

   variable all_translations = Assoc_Type[String_Type];
   variable idword = "", idwords = "", tran = "";
   variable u = get_blocal_var ("untranslated");
   variable n = 0;
   
   push_spot_bob ();
   po_next_entry ();
   set_readonly (0);
   while (bol_fsearch ("msgstr "))
     {
        !if (is_untranslated ()) continue;
        n++;
        flush (sprintf ("getting translations for words in msgid %d of %d ...", n, u));
        
        variable translations = "";
        idwords = strlow (format_string (msg_as_string (0)));
        
        foreach (strchop (idwords, ' ', 0))
          {
             idword = ();
             % if word has a "-" prepended it will act as an "argument" to dict
             idword = strtrim (idword, "-");
             if (assoc_key_exists(all_translations, idword))
               tran=all_translations[idword];
             else
               {
                  tran = lookup_word (idword, 1);
                  all_translations[idword]=tran;
               }
             if (strlen (tran)) translations += tran + " ";
          }
        position_on ("msgstr");
        () = ffind ("\"");
        () = right (1);
        insert (translations);
        fuzzy_or_obsolete_entry (); eol ();
        set_readonly (0);
     }
   pop_spot ();
   po_statistics ();
   set_po_status_line ();
   set_readonly (1);
   if (strlen (dict_error_msg))
     {
        flush (sprintf ("dict: %s", dict_error_msg));
     }
}

%% Pop up a buffer with all available dict definitions on word at point
define dict_lookup_all_def ()
{
   variable word = po_mark_word (0);
   !if (strlen (word)) return;
   pop2buf ("*DICT DEFINITIONS*");
   onewindow;
   if (20 == run_shell_cmd (sprintf ("dict %s", word)))
     {
        set_buffer_modified_flag (0);
        delbuf (whatbuf ());
        error ("No matches found");
     }
   set_buffer_modified_flag (0);
   most_mode ();
   bob ();
   create_syntax_table ("dict");
   dfa_define_highlight_rule ("^From.*:$", "keyword", "dict");
   dfa_build_highlight_table ("dict");
   use_syntax_table ("dict");
   use_dfa_syntax (1);
}

%}}}

%{{{ compendiums

variable good_files, bad_files;
  
static define del_msgid_ext_ascii ()
{
   set_readonly (0);
   variable msgid = "";
   
   while (bol_fsearch ("msgid"))
     {
        msgid = msg_as_string (0);
        if (string_match (msgid, "[^A-Za-z0-9!\\[\\]\^\|\?\.\\-\"\*\+\(\)#\$%&',/:;<=>@`{}~_ \t\n\r\\\\]", 1))
          {
             mark ("entry");
             del_region ();
             loop (2) del ();
          }
        else
          {
             eol ();
             continue;
          }
     }
}

%% Create string arrays of po-files in a directory and check their integrity
%% with the gettext tools, possibly resulting in one array containing good 
%% files and another containing bad/corrupt files.
static define po_listdir ()
{
   variable dir, file, filelist, nfiles, po_files;
   variable exts, po_matches, ok;
   variable i;

   dir = read_with_completion ("directory with po-files:", "", "", 'f');
   filelist = listdir (dir);                                            
   exts = array_map (String_Type, &path_extname, filelist);                              
   po_matches = where (0 == array_map (Int_Type, &strcmp, exts, ".po"));
   nfiles = length (po_matches);
   if (nfiles == 0)
     { 
        flush (sprintf ("no po-files in %s", dir));
        return 0;
     }
   switch (Use_Compendium)
     { case 1: flush (sprintf ("Add %d files to %s? [y/n]",
                               nfiles, Compendium)); }
     { case 2: flush (sprintf ("Add %d files to %s? [y/n]",
                               nfiles, Compendium_Gettext)); }
     { case 3: flush (sprintf ("Add %d files to %s and %s? [y/n]",
                               nfiles, Compendium, Compendium_Gettext)); }
   
   if ('y' == getkey ()); else { update (1); return 0; }

   po_files = filelist [po_matches];
   po_files = po_files [array_sort (po_files)];
   
   _for (0, nfiles-1, 1)                                                 
     {                                                                        
        i = ();                                                               
        file = po_files [i];                                                     
        po_files [i] = dircat (dir, file);
     }

   
   ok = array_map (Int_Type, &check_integrity (), po_files);
   good_files = po_files [where (ok)]; 
   bad_files = po_files [where (not ok)];
   nfiles = length (good_files);
   if (nfiles == 0)
     {
        flush ("found no good files to add to compendium");
        return 0;
     }
   return 1;
}

%% Creates a native compendium file from current buffer with comments, fuzzy 
%% and untranslated entries removed, formatted and sorted.
define update_native_compendium (sort)
{
   if (count ("t") == 0)
     return flush ("no translated entries");

   if (search_file (Compendium, "msgid \"\"", 1)) 
     return flush ("looks like a gettext compendium, not used");
   
   variable file, str;
   variable i = 0, n = 0;
   
   (file,,,) = getbuf_info (whatbuf);                                   

   flush (sprintf ("adding %s to %s ...", file, Compendium));
   
   push_spot_bob (); po_next_entry ();
   
   while (bol_fsearch ("msgstr "))
     {
        if (is_untranslated () or is_fuzzy ()) continue;
        else n++;
     }

   str = String_Type[n];

   bob (); po_next_entry ();
   
   while (bol_fsearch ("msgstr "))
     {
        if (is_untranslated () or is_fuzzy ()) continue;
        else
          {
             mark ("strings");
             str[i] = bufsubstr ();
             i++;
          }
     }
   str = array_map (String_Type, &str_replace_all, str, "msgid ", Null_String);
   str = array_map (String_Type, &str_replace_all, str, "msgstr ", "¤");
   str = array_map (String_Type, &format_string, str);
   str = strjoin (str, "\n");
   () = append_string_to_file (str + "\n", Compendium);
   if (sort)
     {
        flush ("sorting native compendium ...");
        variable tmpfile = make_tmp_file ("/tmp/update_native_compendium");
        () = system (sprintf ("%s %s > %s", "sort -uf", Compendium, tmpfile));
        () = copy_file (tmpfile, Compendium);
        () = delete_file (tmpfile);
     }
   update (1);
   pop_spot ();
}
             
static define prep_gettext_compendium ()
{
   if (NULL == prg_found_in_path ("msgcat"))
     {
        flush ("gettext utilities not installed");
        return 0;
      }
   
   variable flags, name, buf;
   
   buf = whatbuf ();
   
   !if (1 == file_status (Compendium_Gettext))
     {
        () = read_file (Compendium_Gettext);
        (,, name, flags) = getbuf_info ();
        if (flags & 8)
          {
             delbuf (name);
             flush (sprintf ("writing to %s not allowed", Compendium_Gettext));
             return 0;
          }
        else
          {
             insert_po_header ();
             replace_headers ();
             save_buffer ();
             delbuf (name);
             sw2buf (buf);
          }
     }
   else
     {
        !if (search_file (Compendium_Gettext, "msgid \"\"", 1))
          {
             flush ("does not look like a gettext compendium, not used");
             return 0;
          }

        flush (sprintf ("Overwrite matching entries in %s [y/n]",
                        Compendium_Gettext));
        
        if ('y' == getkey ())
          {
             Overwrite_Compendium = 1;
          }
        else
          {
             Overwrite_Compendium = 0;
          }
     }
   
   update (1);
   return 1;
}

%% Add a directory of po-files to native compendium.
static define add_dir_to_native_compendium ()
{
   variable file;
   variable tmpfile = make_tmp_file ("/tmp/update_native_compendium");
   variable nfiles = length (good_files);
   foreach (good_files)
     {
        file = ();
        () = read_file (file);
        update_native_compendium (0);
        nfiles--;
        flush (sprintf ("%d file(s) remaining ..", nfiles)); sleep (0.2);
        delbuf (whatbuf ());
     }
   flush ("sorting compendium ...");
   () = system (sprintf ("%s %s > %s", "sort -uf", Compendium, tmpfile));
   () = copy_file (tmpfile, Compendium);
   () = delete_file (tmpfile);
   flush (sprintf ("%d files added to %s", length (good_files), Compendium));
}


%% Fill in translations from native compendium file
static define init_with_native_compendium ()
{
   !if (1 == file_status (Compendium))
     verror ("compendium file \"%s\" not found.", Compendium);
   
   variable msgid, msgstr_cmpd;
   variable buf = whatbuf ();
   variable cbuf = path_basename (Compendium);
   () = read_file (Compendium);
   setbuf (buf);
   vmessage ("getting translations from %s ...", Compendium); update (1);
   push_spot_bob ();
   po_next_entry ();
   forever
     {
        msgid = msg_as_string (0);
        msgid = format_string (msgid);
        setbuf (cbuf);
        bob ();
        if (bol_fsearch (msgid+"¤"))
          {
             () = ffind ("¤");
             () = right (1);
             push_mark_eol ();
             msgstr_cmpd = bufsubstr ();
             setbuf (buf);
             () = bol_fsearch ("msgstr ");
             if (is_translated ())
               { 
                  if (bol_fsearch ("msgid ")) continue;
                  else break;
               }
             else
               {
                  () = right (1);
                  if (strlen (msgstr_cmpd))
                    {
                       insert (msgstr_cmpd);
                       fuzzy_or_obsolete_entry ();
                       set_readonly (0);
                    }
                  if (bol_fsearch ("msgid ")) continue;
                  else break;
               }
          }
         else
          { 
             setbuf (buf);
             eol ();
             if (bol_fsearch ("msgid ")) continue;
             else break;
          }
     }
   pop_spot ();
   delbuf (cbuf);
}

%% Update the compendium with contents of the current buffer
static define update_gettext_compendium ()
{
   if (count ("t") == 0)
     return flush ("no translated entries");
   
   !if (prep_gettext_compendium) return;

   variable oldfile, newfile;
   variable msgcat_cmd, msgattrib_cmd, cmd;

   newfile = make_tmp_file ("/tmp/po_newfile");
   oldfile = make_tmp_file ("/tmp/po_oldfile");
   
   msgcat_cmd = 
     "msgcat  2>/dev/null --sort-output --use-first --no-location --to-code=";
   msgattrib_cmd = 
     "msgattrib --no-location --translated --no-fuzzy --clear-obsolete  2>/dev/null";
   
   if (Overwrite_Compendium == 1)
     { 
        cmd = sprintf ("%s%s %s %s | %s >%s", msgcat_cmd, Charset,
                       oldfile, Compendium_Gettext, msgattrib_cmd, newfile);
     }
   else
     {
        cmd = sprintf ("%s%s %s %s | %s >%s", msgcat_cmd, Charset,
                       Compendium_Gettext, oldfile, msgattrib_cmd, newfile);
     }
   
   write_tmp_buffer (oldfile);
   
   !if (check_integrity (oldfile))
     { 
        () = delete_file (oldfile);
        error ("errors in this file, compendium not updated");
     }
   
   vmessage ("updating %s ...", Compendium_Gettext); update (1);
   
   !if (0 == system (cmd))
     error ("some error occured, perhaps syntax errors?");
   
   if (file_size (newfile) == 0)
     { 
        flush ("some error occurred, gettext compendium not updated ...");
        return;
     }
   else
     {
        () = copy_file (newfile, Compendium_Gettext);
        () = read_file (Compendium_Gettext);
        replace_headers ();
        save_buffer ();
        delbuf (whatbuf ());
        flush ("gettext compendium succesfully updated");
     }
   
   () = delete_file (oldfile);
   () = delete_file (newfile);
}

%% Add a directory of po-files to the gettext compendium.
static define add_dir_to_gettext_compendium ()
{
   !if (prep_gettext_compendium) return;
   
   variable msgattrib_file, ctemp_file, str_good_files;
   variable msgcat_cmd, msgattrib_cmd;
   variable nfiles = length (good_files);
   variable status;
   
   msgattrib_file = make_tmp_file ("/tmp/po_msgattrib");
   ctemp_file = make_tmp_file ("/tmp/po_ctempfile");
   
   msgcat_cmd = 
     "msgcat  2>/dev/null --sort-output --use-first --no-location --to-code=";
   msgattrib_cmd = 
     "msgattrib  2>/dev/null --no-location --translated --no-fuzzy --clear-obsolete";

   str_good_files = strjoin (good_files, " ");
   
   flush (sprintf( "adding %d files to %s ...", nfiles, Compendium_Gettext));
   
   if (Overwrite_Compendium == 1)
     { 
        status = 
          system (sprintf ("%s%s %s %s > %s", msgcat_cmd, Charset, 
                           str_good_files, Compendium_Gettext, ctemp_file));
     }
   else
     {
        status = 
          system (sprintf ("%s%s %s %s > %s", msgcat_cmd, Charset,
                           Compendium_Gettext, str_good_files, ctemp_file));
     }
   
   !if (status == 0)
     error ("could not concatenate files");
   
   flush ("cleaning up gettext compendium ...");
   status = system (sprintf ("%s %s > %s",
                             msgattrib_cmd, ctemp_file, msgattrib_file));

   if (status == 0)
     {
        () = copy_file (msgattrib_file, Compendium_Gettext);
        () = read_file (Compendium_Gettext);
        replace_headers ();
        save_buffer ();
        delbuf (whatbuf ());
        flush ("gettext compendium succesfully updated");
     }
   else
     flush ("error, gettext compendium not updated");
  
   
   () = delete_file (msgattrib_file);
   () = delete_file (ctemp_file);
}

%% Merge translations from a compendium file into po-file, using the gettext
%% msgmerge program.
static define init_with_gettext_compendium ()
{   
   !if (1 == file_status (Compendium_Gettext))
     verror ("\"%s\" not found.", Compendium_Gettext);
   
   variable status, oldfile, newfile;
   variable n = get_current_entry_number ();
   oldfile = make_tmp_file ("/tmp/po_oldfile");
   newfile = make_tmp_file ("/tmp/po_newfile");
   
   if (count ("o") > 0)
     {
        flush ("removing obsolete entries ...");                                   
        push_spot ();                                                              
        mark_buffer ();                                                            
        !if (0 == pipe_region (sprintf ("%s > %s",
                                        "msgattrib --no-obsolete", oldfile)))
          {
             flush ("errors in current file");  
             pop_spot ();
             return;
          }
        pop_spot ();
     }
   else
     {
        write_tmp_buffer (oldfile);
     }
   
   vmessage ("getting translations from %s ...", Compendium_Gettext); update (1);
   
   if (Gettext_Use_Fuzzy == 0)
     status = system (sprintf ("%s%s -o %s /dev/null %s >/dev/null 2>&1", 
                               "msgmerge -q --no-fuzzy-matching --compendium=",
                               Compendium_Gettext, newfile, oldfile));
   else
     status = system (sprintf ("%s%s -o %s /dev/null %s >/dev/null 2>&1", 
                               "msgmerge -q --compendium=", Compendium_Gettext,
                               newfile, oldfile));
   
   if (status != 0)
     error ("some error occured, perhaps syntax errors in compendium?");
   
   erase_buffer ();
   () = insert_file (newfile); 
   () = delete_file (oldfile);
   () = delete_file (newfile);
   
   restore_entry_position (n);
}

%% Overwrite a translation in the gettext compendium with translation for 
%% current msgid if it exists, else add entry to compendium
define make_preferred_gettext ()
{
   if (Use_Compendium == 1)
     {
        flush ("not implemented");
        return;
     }
   
   variable po_buf = whatbuf ();
   variable compendium_buf = path_basename (Compendium_Gettext); 
   variable msgstr, msgid, msgid_compendium, entry, str;
   
   msgstr = msg_as_string (1);
   if (strlen (msgstr) == 2)
     { 
        flush ("untranslated entry");
        return;
     }
   
   !if (bufferp (compendium_buf))
     {
        () = read_file (Compendium_Gettext);
     }
   
   setbuf (po_buf);
   msgid = msg_as_string (0);
   str = substr (msgid, 1, 20);
   pop_spot ();
   setbuf (compendium_buf);
   bob ();
   forever 
     {
        if (fsearch (str))
          {
             msgid_compendium = msg_as_string (0);
             if (0 == strcmp (msgid, msgid_compendium))
               {
                  del_msgstr ();
                  insert (msgstr);
                  () = save_buffer ();
                  vmessage ("msgstr in %s overwritten", Compendium_Gettext);
                  return;
               }
             else
               { 
                  eol ();
                  continue;
               }
          }
        else break;
     }
   setbuf (po_buf);
   narrow_to_strings ();
   mark_buffer ();
   widen_region ();
   entry = "\n" + bufsubstr ();
   setbuf (compendium_buf);
   eob ();
   insert (entry);
   () = save_buffer ();
   vmessage ("entry added to %s", Compendium_Gettext);
}

define gettext_fuzzy_match ()
{
   if (Use_Compendium == 1)
     {
        flush ("not implemented");
        return;
     }
   
   variable po_buf = whatbuf ();
   variable compendium_buf = path_basename (Compendium_Gettext); 
   variable msgid, msgstr, str;
   !if (bufferp (compendium_buf))
     {
        !if (read_file (Compendium_Gettext))
          verror ("could not read %s", Compendium_Gettext);
     }
   setbuf (po_buf);
   push_spot ();
   msgid = msg_as_string (0);
   str = format_string (msgid);
   str = substr (str, 1, 20);
   setbuf (compendium_buf);
   bob ();
   if (fsearch (str))
     {
        mark ("msgstr");
        msgstr = bufsubstr ();
        setbuf (po_buf);
        set_readonly (0);
        del_msgstr ();
        insert (msgstr);
        fuzzy_or_obsolete_entry ();
        set_readonly (1);
     }
   else 
     flush ("not found");
   
   setbuf (po_buf);
   pop_spot ();
   set_po_status_line ();
}

define edit_compendium ()
{
   switch (Use_Compendium)
     { case 1: () = find_file (Compendium); }
     { case 2: () = find_file (Compendium_Gettext); }
     { case 3: () = find_file (Compendium); () = find_file (Compendium_Gettext); }
}   

define init_with_compendiums ()
{
   flush ("Initialize with translations from compendium(s)? [y/n]");
   !if ('y' == getkey ()) return update (1);

   set_readonly (0);
   
   switch (Use_Compendium)
     { case 1: init_with_native_compendium (); }
     { case 2: init_with_gettext_compendium (); }
     { case 3: init_with_gettext_compendium (); sleep (1); init_with_native_compendium (); }

   set_readonly (1);
   po_statistics ();
   flush ("done");
}

define update_compendiums ()
{
   switch (Use_Compendium)
     { case 1: 
        vmessage ("Update %s? [y/n]", Compendium); update (1);
        !if ('y' == getkey ()) return;
        update_native_compendium (1); }
   
     { case 2: 
        vmessage ("Update %s? [y/n]", Compendium_Gettext); update (1);
        !if ('y' == getkey ()) return;
        update_gettext_compendium (); }
     
     { case 3: 
        vmessage ("Update %s and %s? [y/n]", Compendium, Compendium_Gettext); update (1);
        !if ('y' == getkey ()) return;
        update_native_compendium (1);
        update_gettext_compendium (); }
}

define add_dir_to_compendium ()
{
   !if (po_listdir ()) return;
   
   variable str_bad_files = strjoin (bad_files, "\n");
   
   switch (Use_Compendium)
     { case 1: add_dir_to_native_compendium (); }
     { case 2: add_dir_to_gettext_compendium (); }
     { case 3: 
        add_dir_to_gettext_compendium ();
        add_dir_to_native_compendium (); }
   
   if (strlen (str_bad_files))
     {
        pop2buf ("*corrupt files*");
        insert ("The following file(s) either had syntax errors or " +
                "errors in\ncharacter set conversion and were not " +
                "added to the compendium(s):\n\n" + str_bad_files);
        
        bob ();
        most_mode ();
        
        !if (get_y_or_n ("Load file(s) to check for errors with the (V)alidate command")) return;
        
        variable file;
        
        foreach (bad_files)
          {
             file = ();
             () = find_file (file);
             onewindow ();
          }
     }
}

%}}}

%{{{ dfa syntax and colors

static variable bg = "";

#ifdef HAS_DFA_SYNTAX
%%% DFA_CACHE_BEGIN %%%
create_syntax_table (mode);
static define setup_dfa_callback (mode)
{
   (, bg) = get_color ("normal"); % that dfa backgr. fits with user's color

   add_color_object ("strings");
   add_color_object ("srccomment");
   add_color_object ("flagcomment");
   add_color_object ("autocomment");
   add_color_object ("usercomment");
   add_color_object ("lbreak");
   add_color_object ("begblank");
   add_color_object ("endblank");

   % For Xjed. You could use RGB color codes here if you wanted.
   if (is_defined ("x_server_vendor"))
     {
        set_color ("strings", "magenta", bg);
        set_color ("srccomment", "gray", bg);
        set_color ("flagcomment", "red", bg);
        set_color ("autocomment", "gray", bg);
        set_color ("usercomment", "black", "green");
        set_color ("lbreak","magenta", bg);
        set_color ("begblank","black", "cyan");
        set_color ("endblank","black", "cyan");
     }
   else
     {
        set_color ("strings", "magenta", bg);
        set_color ("srccomment", "gray", bg);
        set_color ("flagcomment", "red", bg);
        set_color ("autocomment", "gray", bg);
        set_color ("usercomment", "black", "green");
        set_color ("lbreak","magenta", bg);
        set_color ("begblank","black", "cyan");
        set_color ("endblank","black", "cyan");
     }

   dfa_enable_highlight_cache ("po.dfa", mode);
   dfa_define_highlight_rule ("^msg(id|str)", "strings", mode);
   dfa_define_highlight_rule ("^#[,]+.*", "flagcomment", mode);
   dfa_define_highlight_rule ("^#[:]+.*", "srccomment", mode);
   dfa_define_highlight_rule ("^#[\\.]+.*", "autocomment", mode);
   dfa_define_highlight_rule ("^#[ \t]+.*", "usercomment", mode);
   dfa_define_highlight_rule ("\"[ ]+", "begblank", mode);
   dfa_define_highlight_rule ("[ \t]+\\\\?n?\"$", "endblank", mode);
   dfa_define_highlight_rule ("\\\\n", "lbreak", mode);
   dfa_build_highlight_table (mode);
   enable_dfa_syntax_for_mode (mode);
}
dfa_set_init_callback (&setup_dfa_callback, mode);
%%% DFA_CACHE_END %%%
#endif

%}}}

%{{{ menu

static define po_menu (menu)
{
   menu_append_popup (menu, "&Navigate");
   $0 = menu + ".&Navigate";
     {
        menu_append_item ($0, "Top Justify Entry", "top_justify_entry");
        menu_append_item ($0, "Go to Entry Number", "goto_entry");
        menu_append_item ($0, "Show Current Entry Number", "show_current_entry_number");
        menu_append_item ($0, "Next Entry", "po_next_entry");
        menu_append_item ($0, "Previous Entry", "po_previous_entry");
        menu_append_item ($0, "Next Untranslated", "find_untranslated");
        menu_append_item ($0, "Previous Untranslated", "bfind_untranslated");
        menu_append_item ($0, "Next Translated", "find_translated");
        menu_append_item ($0, "Previous Translated", "bfind_translated");
        menu_append_item ($0, "Next Fuzzy", "find_fuzzy");
        menu_append_item ($0, "Previous Fuzzy", "bfind_fuzzy");
        menu_append_item ($0, "Next Obsolete", "find_obsolete");
        menu_append_item ($0, "Previous Obsolete", "bfind_obsolete");
        menu_append_item ($0, "Next Translator Comment", "find_translator_comment");
     }
   menu_append_popup (menu, "&Modify");
   $1 = menu + ".&Modify";
     {
        menu_append_item ($1, "Undo",  "po_undo");
        menu_append_item ($1, "Edit Msgstr", "po_edit");
        menu_append_item ($1, "Replace Headers", "replace_headers");
        menu_append_item ($1, "Copy Msgstr", "copy_msgstr");
        menu_append_item ($1, "Insert Msgstr", "insert_msgstr");
        menu_append_item ($1, "Copy Msgid To Msgstr", "copy_msgid_to_msgstr");
        menu_append_item ($1, "Cut Msgstr", "cut_msgstr");
        menu_append_item ($1, "Flag Entry As Fuzzy", "fuzzy_or_obsolete_entry");
        menu_append_item ($1, "Flag All Entries Fuzzy", "flag_fuzzy_all");
        menu_append_item ($1, "Remove Fuzzy Flag", "remove_fuzzy_flag");
        menu_append_item ($1, "Delete Obsolete Entry", "del_obsolete");
        menu_append_item ($1, "Remove Obsolete Flag", "unobsolete_entry");
        menu_append_item ($1, "Edit Comment", "edit_comment");
        menu_append_item ($1, "Delete Comment", "del_translator_comment");
        menu_append_item ($1, "Edit Entire File", "edit_whole_buffer");
        menu_append_item ($1, "Spell Check", "po_spellcheck");
        menu_append_item ($1, "Replace in Msgstrs", "replace_in_msgstrs");
     }
   menu_append_popup (menu, "&Gettext functions");
   $2 = menu + ".&Gettext functions";
     {
        menu_append_item ($2, "Compile *.po -> *.mo", "po_compile");
        menu_append_item ($2, "Decompile *.mo -> *.po", "po_decompile");
        menu_append_item ($2, "Validate", "po_validate_command");
        menu_append_item ($2, "Update", "po_file_update");
        menu_append_item ($2, "Unwrap Entries", "wrap_entries (0)");
        menu_append_item ($2, "Wrap Entries", "wrap_entries (1)");
        menu_append_item ($2, "Change Encoding", "conv_charset");
     }
   menu_append_popup (menu, "&Compendiums and Wordlists");
   $3 = menu + ".&Compendiums and Wordlists";
     {
        menu_append_item ($3, "Add Buffer To Compendium(s)", "update_compendiums");
        menu_append_item ($3, "Add Dir to Compendium(s)", "add_dir_to_compendium");
        menu_append_item ($3, "Initialize w/Compendium(s)", "init_with_compendiums");
        menu_append_item ($3, "Make Translation Preferred", "make_preferred_gettext");
        menu_append_item ($3, "Fetch Fuzzy Translation", "gettext_fuzzy_match");
        menu_append_item ($3, "Edit Compendium(s)", "edit_compendium");
        menu_append_item ($3, "Look up word in wordlist", "lookup_word (Null_String, 0)");
        menu_append_item ($3, "Look up all words in wordlist", "wordlist_lookup_all");
     }
   menu_append_item (menu, "Show Help",  "show_help");
   menu_append_item (menu, "Statistics", "show_po_statistics");
   menu_append_item (menu, "Mail Robot or Team", "mail_po_file");
   menu_append_item (menu, "Set Source Path", "set_source_path");
   menu_append_item (menu, "View Source Reference", "view_source");
   menu_append_item (menu, "Grep in Source Directory", "grep_src");
   menu_append_item (menu, "Toggle Limited View", "limit_view");
   menu_append_item (menu, "Send Bug Report", "reportbug");
}

%}}}

%{{{ keymaps

% Emulations "edt" and "wordstar" have no _Reserved_Key_Prefix,
% set it to Ctrl-C
if (_Jed_Emulation == "edt" or _Jed_Emulation == "wordstar")
{
   _Reserved_Key_Prefix = "\003";
}

!if (keymap_p ("po_comment"))
{
   make_keymap ("po_comment");
   definekey ("enlargewin", "^[-", "po_comment");      %  esc +
   definekey ("decreasewin", "^[/", "po_comment");     %  esc -
   if (NULL != getenv ("DISPLAY"))
     {
        definekey ("enlargewin", "^[+", "po_comment");
        definekey ("decreasewin", "^[-", "po_comment");
     }
   definekey ("po_end_edit_comment", "\t", "po_comment");
   definekey_reserved ("po_end_edit_comment", "^C", "po_comment");
   definekey_reserved ("cancel_editbuf", "^K", "po_comment");
}

!if (keymap_p ("po_edit"))
{
   make_keymap ("po_edit");
   definekey_reserved ("cancel_editbuf", "^K", Edit_Mode); % emacs-like
   definekey_reserved ("po_end_edit", "^C", Edit_Mode); % emacs-like
   definekey ("po_end_edit", "\t", Edit_Mode);
   definekey ("enlargewin", "\e-", Edit_Mode);
   definekey ("decreasewin", "\e/", Edit_Mode);
   if (NULL != getenv ("DISPLAY"))
     {
        definekey ("enlargewin", "\e+", Edit_Mode);
        definekey ("decreasewin", "\e-", Edit_Mode);
     }
}

!if (keymap_p (mode))
{
   make_keymap (mode);
   definekey ("show_current_entry_number", "@", mode);
   definekey ("make_preferred_gettext", "+", mode);
   definekey ("gettext_fuzzy_match", "*", mode);
   definekey ("top_justify_entry", ".", mode);
   definekey ("page_up", "b", mode);
   definekey ("update_compendiums", "B", mode);
   definekey ("po_undo", "_", mode);
   definekey ("po_edit_comment", "#", mode);
   definekey ("show_po_statistics", "=", mode);
   definekey ("show_help", "?", mode);
   definekey ("find_fuzzy", "f", mode);
   definekey ("bfind_fuzzy", "F", mode);
   definekey ("goto_entry", "g", mode);
   definekey ("grep_src", "G", mode);
   definekey ("limit_view", "l", mode);
   definekey ("po_next_entry", "n", mode);
   definekey ("any_next_unfinished", " ", mode);
   definekey ("po_previous_entry", "p", mode);
   definekey ("po_compile", "c", mode);
   definekey ("lookup_word (Null_String, 0)", "d", mode);
   definekey ("wordlist_lookup_all", "D", mode);
   definekey ("po_decompile", "C", mode);
   definekey ("copy_msgstr", "w", mode);
   definekey ("insert_msgstr", "y", mode);
   definekey ("edit_whole_buffer", "E", mode);
   definekey ("replace_headers", "H", mode);
   definekey ("init_with_compendiums", "I", mode);
   definekey ("cut_msgstr", "K", mode);
   definekey ("mail_po_file", "M", mode);
   definekey ("find_obsolete", "o", mode);
   definekey ("bfind_obsolete", "O", mode);
   definekey ("view_source", "s", mode);
   definekey ("replace_in_msgstrs", "R", mode);
   definekey ("set_source_path", "S", mode);
   definekey ("find_translated", "t", mode);
   definekey ("bfind_translated", "T", mode);
   definekey ("find_untranslated", "u", mode);
   definekey ("bfind_untranslated", "U", mode);
   definekey ("po_validate_command", "V", mode);
   definekey ("po_edit", "\t", mode);                           % tab
   definekey ("dict_lookup_all_def", "^D", mode); 
   definekey ("po_edit", "^M", mode);                           % enter
   definekey ("del_obsolete", Key_Del, mode);                   % del
   definekey ("fuzzy_or_obsolete_entry", Key_BS, mode);         % backspace
   definekey ("remove_fuzzy_flag", Key_Alt_BS, mode);
   definekey ("find_translator_comment", "\e#", mode);
   definekey ("copy_msgid_to_msgstr", "\e^m", mode);
   definekey ("toggle_wrap", "\\", mode);
   definekey_reserved ("del_translator_comment", "#", mode);
   definekey_reserved ("edit_compendium", "ce", mode);
   definekey_reserved ("cut_msgstr", "k", mode);
   definekey_reserved ("add_dir_to_compendium", "d", mode);
   definekey_reserved ("po_spellcheck", "s", mode);
   definekey_reserved ("conv_charset", "E", mode);
   definekey_reserved ("flag_fuzzy_all", "F", mode);
   definekey_reserved ("po_file_update", "U", mode);
}

%}}}

%{{{ mode definition

define po_mode ()
{
   set_mode (mode, 0);
   use_keymap (mode);
   use_syntax_table (mode);
   mode_set_mode_info (mode, "init_mode_menu", &po_menu);
   set_buffer_hook ("mouse_2click", &po_mouse_2click_hook ());
   use_dfa_syntax (1);
   run_mode_hooks ("po_mode_hook");
   trim_buf ();
   create_po_edit_buf ();
   po_statistics ();
   if (eobp () and bobp ()) insert_po_header ();
   set_buffer_modified_flag (0);
   set_readonly (1);
   message ("F10 -> Mode, gives you access to menu functions. Type '?' for help");
}

provide (mode);

%}}}

% Mode for editing Mupad files. 
% (MuPad is a computer algebra system, see http://www.mupad.de)
% 
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Based on Guido Gonzatos matlab.sl  <guido@ibogeo.df.unibo.it>
% Enables interactive work using ishell.sl
%  
% 0.9 19 May 1999 first public version
% 0.9.1  2005-04-25 bugfix to work with SLang2  (report Jörg Sommer)
% 0.9.2  2005-11-02 fix public definiton of mupad_mode() 

% requirements
require("comments");
autoload ("ishell_send_input", "ishell.sl");
autoload ("ishell_mode", "ishell.sl");

  
private variable modename = "Mupad";

custom_variable ("Mupad_Command", "mupad");

% do commenting with comments.sl
set_comment_info (modename, "# ", " #", 7);

% Now create and initialize a simple syntax table.
create_syntax_table (modename);
% (only two comment definitions work at the same time, MuPad has three)
define_syntax ("#", "#", '%', modename);		% comments 
%define_syntax ("/*", "*/", '%', modename);		% comments 
define_syntax ("//", "", '%', modename);		% comments 
define_syntax ("([{", ")]}", '(', modename);		% parentheses
define_syntax ('"', '"', modename);			% strings
define_syntax ('\\', '\\', modename);			% escape character
define_syntax ("0-9a-zA-Z_", 'w', modename);		% identifiers
define_syntax ("0-9a-fA-F.xXL", '0', modename);	% numbers
define_syntax (",;", ',', modename);			% delimiters
define_syntax ("!&+-.*^;<>\|~='/:", '+', modename);	% operators
define_syntax ('>', '#', modename);                 % preprocess (used for output)
set_syntax_flags (modename, 4);

% Mupad reserved words. Are there more?
() = define_keywords_n (modename, "doifinofto", 2, 0);
() = define_keywords_n (modename, "for", 3, 0);
() = define_keywords_n (modename, "caseelifelsefromholdnextprocthen", 4, 0);
() = define_keywords_n (modename, "beginbreaklocaluntilwhile", 5, 0);
() = define_keywords_n (modename, "end_ifrepeatreturn", 6, 0);
() = define_keywords_n (modename, "end_for", 7, 0);
() = define_keywords_n (modename, "end_procend_case", 8, 0);
() = define_keywords_n (modename, "end_whileotherwise", 9, 0);
() = define_keywords_n (modename, "end_repeat", 10, 0);
%() = define_keywords_n (modename, "edit_history", 12, 0);
%() = define_keywords_n (modename, "end_try_catch", 13, 0);

variable Mupad_Indent = 2;

% Mupad indent routine.
define mupad_indent ()
{
  variable goal = 1;
  variable cs = CASE_SEARCH;
  variable ch;

  % goto beginning of line and skip past continuation char
  USER_BLOCK0
    {
      bol ();
      skip_white ();
    }

  push_spot ();
  push_spot ();
  CASE_SEARCH = 1;	% Mupad is case sensitive
  while (up_1 ())
    {
      bol_skip_white();
      if ( eolp() ) continue;
      X_USER_BLOCK0 ();
      goal = what_column ();
      
%      if (looking_at("switch"))
%	goal += 2 * Mupad_Indent; % to account for 'case'
      
      if (looking_at ("if") or 
	  looking_at ("else") or 
	  looking_at ("elif") or
	  looking_at ("case") or
	  looking_at ("for") or
	  looking_at ("while") or
	  looking_at ("repeat") or
	  looking_at ("proc") or
	  looking_at ("begin") )
	 goal += Mupad_Indent;
      
      break;
    }

  % now check the current line
  pop_spot ();
  push_spot ();
  X_USER_BLOCK0 ();

%  if (looking_at ("end_procswitch"))
%    goal -= 2 * Mupad_Indent;
  
  if (looking_at ("end_if") or 
      looking_at ("else") or
      looking_at ("elif") or
      looking_at ("end_case") or 
      looking_at ("end_for") or
      looking_at ("end_while") or 
      looking_at ("end_repeat") or
      looking_at ("end_proc") ) 
    goal -= Mupad_Indent;
  
  CASE_SEARCH = cs;		% done getting indent
  if (goal < 1) goal = 1;
  pop_spot ();

  bol_skip_white ();
  ch = char(what_char());
  bol_trim ();
  goal--;
  insert_spaces (goal);
  pop_spot ();
  skip_white ();

} % mupad_indent

define mupad_newline ()
{

   if (bolp ())
     {
	newline ();
	return;
    }

  mupad_indent ();
  newline ();
  mupad_indent ();
}

% interactive MuPad session with the actual document as template
define mupad_shell ()
{
   ishell_mode(Mupad_Command);
}

define mupad_help()
{
   !if(is_substr(get_mode_name(), "ishell"))
     error("Currently help only works in mupad-shell mode");

   variable topic = "";
   if (_NARGS)
     topic = ();
   
   if (topic == "")
     topic = read_mini("Gnuplot Help for: ", "", "");
   
   set_blocal_var("o", "IShell_output_placement");
   % closing NL needed by send_process
   send_process(get_blocal_var("IShell_Id"), "?" + topic + "\n");
}

% --- the mode dependend menu

static define init_menu (menu)
{
%   menu_append_item (menu, "&Evaluate Region/Buffer", "mupad_run");
   menu_append_item (menu, "Mupad &Shell", "mupad_shell");
   menu_append_item (menu, "Mupad &Help", "mupad_help");

}

% --- keybindings
%!if (keymap_p (modename)) make_keymap (modename);
% TODO

%!%+
%\function{mupad_mode}
%\synopsis{a mode for edition of mupad skripts}
%\description
% Protoytype: Void mupad_mode ();
% This is a mode that is dedicated to facilitate the editing of 
% Mupad language files.  
% Hooks: \var{mupad_mode_hook}
%!%-
public define mupad_mode ()
{
   set_mode(modename, 2);
%   use_keymap(modename);
   use_syntax_table (modename);
   set_buffer_hook ("indent_hook", "mupad_indent");
   set_buffer_hook ("newline_indent_hook", "mupad_newline");
   mode_set_mode_info (modename, "init_mode_menu", &init_menu);
   define_blocal_var("help_for_word_hook", "mupad_help");
   run_mode_hooks("mupad_mode_hook");
}

provide("mupad");



% --- End of file mupad.sl ---

%% -*- mode:slang; mode:fold; -*-
%% JED ASP
%% Author: Marko Mahnic <marko.mahnic@...si>
%% Version 1.1
%% 
%% AUTOLOAD:
%%    asp_run_scripts
%% 
%% This code tries to simulate MS IIS Active Server Pages with JED.
%% 
%% The script is defined with arbitrary BEGIN and END tag, they are both
%% passed to the asp_run_scripts function.
%% 
%% The scripts are executed while there are any in the file.
%% 
%% If you need to insert raw text into the buffer within the script,
%% use the %T comment. You can use SLang escape sequences in raw text.
%% If tou need to insert the value of some SLang variable into raw text,
%% you can do it using the (%F, X%) format, where F is the format, X is an
%% arbitrary expression whose result has a valid type for F. The expression
%% may not contain string constants.
%%

static variable asp_buf = "*ASP_CODE_BUF*";
static variable asp_begin_tag = "";
static variable asp_end_tag = asp_begin_tag;

static define asp_error (text)
{
   error (text);
}

% \usage{Void asp_transform_raw_text()}
static define asp_transform_raw_text()
{
   bob ();
   variable str;
   while (re_fsearch ("^[ \t]*%T[ \t]")) {
      push_mark();
      narrow();
      bol();

      () = ffind_char ('%');
      skip_chars("^ \t");
      skip_chars(" \t");
      push_mark();
      eol();
      str = bufsubstr_delete();
      push_mark(); bol(); del_region();

      str = str_quote_string (str, "\"", '\\');
      insert ("insert (\"" + str + "\");");
      
      % replace all the substrings Y\\X, where Y is not '\' and X is not '"' nor '\',  with Y\X
      % with this we allow the use of all SLang escape sequences in raw text
      % PROBLEM: when I want to get '\n' I actually get '\\n' in output.
      bol();
      while (re_fsearch ("[^\\\\]\\\\\\\\[^\"\\\\]")) { 
	 go_right(1);
	 del();
      }
      
      bol();
      if (re_fsearch("(%.+,.+%)")) {
	 bol();
	 insert ("v");
	 while (re_fsearch("(%[^,]+,.+%)")) {
	    del();
	    () = ffind_char(',');
	    push_mark();
	    ffind ("%)");
	    deln(2);
	    str = bufsubstr_delete();
	    push_spot();
	    eol();
	    go_left(2);
	    insert (str);
	    pop_spot();
	 }
      }
      
      widen();
   }
}

% \usage{Int asp_exec_marked_script (String ScriptBeginTag)}
static define asp_exec_marked_script (ScriptBeginTag)
{
   variable script;
   !if (markp()) {
      asp_error ("Script not marked.");
      return (-1);
   }
   
   () = dupmark();
   script = bufsubstr();
   
   %  Detect script within script
   if (is_substr (script, ScriptBeginTag)) {
      pop_mark(0);
      asp_error ("Script within script.");
      return (-2);
   }
   del_region();
   
   variable buf = whatbuf(); 
   setbuf (asp_buf);
   erase_buffer();
   insert (script);
   asp_transform_raw_text();
   mark_buffer();
   script = bufsubstr();
   set_buffer_modified_flag(0);
   
   setbuf (buf);
   eval (script);
   
   return (0);
}

% \usage{Void asp_run_scripts (String ScriptBeginTag, String ScriptEndTag)}
define asp_run_scripts (ScriptBeginTag, ScriptEndTag)
{
   variable buf = whatbuf();
   asp_begin_tag = ScriptBeginTag;
   asp_end_tag = ScriptEndTag;
   
   % setbuf (DocBuffer);
   
   bob ();
   while (fsearch (ScriptBeginTag)) {
      deln(strlen(ScriptBeginTag));   %% Do not try to run the script twice
      push_mark();
      !if (fsearch (ScriptEndTag)) {
	 pop_mark(1);
	 eol();
	 asp_error ("End of script not found.");
	 break;
      }

      go_right (strlen (ScriptEndTag));
      if (not 0 == asp_exec_marked_script (ScriptBeginTag)) {
	 break;
      }
      bob ();
   }

   setbuf (buf);
   
   if (bufferp (asp_buf)) delbuf (asp_buf);
}

provide("jedasp");

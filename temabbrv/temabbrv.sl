%%----temabbrv.sl--------------------------------------------------------
%%  Author: Marko Mahnic <marko.mahnic@....si>
%%  Version: 0.99
%%     
%%-----------------------------------------------------------------------     
%% History:
%%   0.99 December 2004
%%     * $(variable) inserts the value of a variable 
%%       or "?" if not is_defined(variable)
%%   0.98 Jul 2004
%%     * Custom variable TEMABBRV_EOL_ONLY
%%   0.97 Nov 2003
%%     * A list of possible template tags is displayed when the
%%       word on the left of the cursor is too short.
%%     * Improved the search for template files (suggested by PB)
%%   0.96 Nov 2003
%%     * A cleaner implemntation of tem_default_search_path() 
%%       (Paul Boekholt)
%%   0.95 Nov 2003
%%     * Search path for template files fixed
%%   0.92 Apr 2003
%%     * Cycle thru multiple expansions
%%     * Template file format changed
%%   0.90 Dec 2002
%%     * First version
%%-----------------------------------------------------------------------     
%% 
%% Takes the current word (only at eol) and expands it if the word 
%% expansion is defined for current mode. If the same word is defined
%% many times, cycles thru all definitions.
%% 
%% If a template contains parameters, the user is prompted for 5 seconds
%% to press '!' and start expanding parameters. If any other key is pressed
%% parameter expansion is skipped.
%%
%% Some simple postprocessing of expanded text is supported:
%%    - indentation
%%    - parameter replacement ($1, $2, ...)
%%    - cursor positioning with $_
%%    - variable insetion with $(varanme)
%%    
%% You can define arbitrary templates in template files (.tem).
%% For example, templates for SLang mode are in slang.tem.
%%
%% Template files can include other template files.
%% 
%% --------------------------------------------------------------------
%% 1. Installation:
%% 
%%   Put temabbrv.sl in any directory that is in get_jed_library_path(),
%%   for example ~/jed/.
%% 
%%   In your jed.rc add:
%%      require ("temabbrv");
%% 
%% 2. Template files:
%% 
%%   Create a directory named 'template' in any directory that is
%%   in get_jed_library_path(), for example ~/jed/template
%%   and put your template files in it.
%% 
%%   Create the .tem files in /template directory for the modes you desire
%%   (for SLang you create slang.tem). All filenames are lowercase.
%%   
%%   You could also put your template files in an arbitrary directroy
%%   and call:
%%       tem_add_template_dir ("~/mytemplates/jed");
%%     
%% 3. Keybindings:
%%     
%%   To define the keybinding:
%%     local_setkey ("temabbrev", "\t");         % in mode startup hook (preferred)
%%     or
%%     setkey   ("temabbrev", "\t");             % golobal keymap, jed.rc
%%     or
%%     definekey ("temabbrev", "\t", keymap);    % mode keymap, XXmode.sl
%%   TAB key might be a good idea, but you can use your own keybinding.
%% 
%%   eg. 
%%      slang_mode_hook ()
%%      {
%%         local_setkey ("temabbrev", "\t");
%%      }
%% ----------------------------------------------------------------------------
%% Template example (comments are not part of template):
%% 
%% @@#INCLUDE Something.inc  % this will include Something.inc
%% 
%% @@[if]                % Beginning of definition (@@[),  template name (if)
%% if ($_)               % $_ after processing, place the cursor here ($_ is deleted)
%% {
%%    sth = $1;
%% }
%% @@: I+, $1 sth value  % end of definition (@@:), options (comma delimited): 
%%                       %   I+              indent after insertion
%%                       %   $1 sth value    Prompt for value of $1 during expansion
%% ----------------------------------------------------------------------------
%% In jed.rc you can use
%%    variable TEMABBRV_DEFAULT_ACTION = "indent_line";
%% if you wish to indent the line when temabbev fails to expand the word.
%% This way you can have indentation and expansion on the same key (TAB).
custom_variable ("TEMABBRV_DEFAULT_ACTION", "");

%% A comma separated list of directories to search for templates
custom_variable ("TEMABBRV_TEMPLATE_DIRS", NULL);

%% temabbrv active on EOL only
custom_variable ("TEMABBRV_EOL_ONLY", 1);


static variable temLastToken = "";
static variable temExpBegin_point = NULL;
static variable temExpEnd_point = NULL;
static variable temLoadedModes = "";
static variable loadedfiles_this_mode = "";

static define get_template_buffer(mode)
{
   return sprintf (" *%s*templates*", strlow(mode));
}

static define get_token_header_prefix(token)
{
   return "@@["+ token;
}

static define get_token_header(token)
{
   return "@@["+ token + "]";
}

static define extract_token(tokheader)
{
   return strtrim(tokheader, "[]@ \t");
}

%% Defalut template search path: JED_HOME and Jed library path
static define tem_default_search_path()
{
   variable libpaths = 
     sprintf("%s,%s", Jed_Home_Directory, get_jed_library_path);
   
   variable dir, tempaths = "";
   foreach(strtok(libpaths, ","))
     {
	dir = dircat("template");
	if (2 == file_status(dir))
	  tempaths = sprintf ("%s,%s", tempaths, dir);
     }

   return strtrim_beg(tempaths, ",");
}

define tem_add_template_dir(dir)
{
   if (TEMABBRV_TEMPLATE_DIRS == NULL) 
      TEMABBRV_TEMPLATE_DIRS = tem_default_search_path();
   
   if (2 == file_status(dir))
      TEMABBRV_TEMPLATE_DIRS = sprintf ("%s,%s", dir, TEMABBRV_TEMPLATE_DIRS);
}

%!%+
%\description
% Tries to determine if the file incfile exists.
%!%-
static define expand_include_file(incfile, fromfile)
{
   variable root, path;
   incfile = strtrans (incfile, "\\", "/");
   root = extract_element(incfile, 0, '/');
   
   if (strncmp (root, "$", 1) == 0)          % environment variable; JED_ROOT, JED_HOME, ...
   {
      path = getenv(substr(root, 2, -1));
      if (path == NULL and root == "$JED_HOME")
         path = Jed_Home_Directory;
      
      (incfile, ) = strreplace(incfile, root, path, 1);
   }
   else if (strncmp (root, ".", 1) == 0)     % relative to base file
   {
      incfile = path_concat(path_dirname(fromfile), incfile);
   }
   else if (not is_substr(incfile, "/"))
   {
      incfile = search_path_for_file(TEMABBRV_TEMPLATE_DIRS, incfile, ',');
   }
   
   if (incfile == NULL) return NULL;
   if (1 != file_status (incfile)) return NULL;
   
   return (incfile);
}

static define insert_template_file ();

static define insert_template_file (file)
{
   variable incfile;

   if (is_list_element (loadedfiles_this_mode, file, ',')) return;

   loadedfiles_this_mode = sprintf("%s,%s", loadedfiles_this_mode, file);

   if (1 == file_status (file))
   {
      push_mark();
      narrow();
      %% vinsert("-------- file '%s'\n", file);
      () = insert_file (file);
      bob();

      %% Include other files
      while (bol_fsearch ("@@#INCLUDE"))
      {
         go_right (10);
         push_mark();
         eol();
         incfile = str_delete_chars(bufsubstr(), " \t\n");
         incfile = expand_include_file(incfile, file);

         delete_line();
         bol();
         
         if (incfile != NULL)
            insert_template_file(incfile);
         
         bob();
      }
      widen();
   }
   
   set_buffer_modified_flag (0);
   eob();
}

static define tem_load_mode_template (mode)
{
   variable file;
   
   if (is_list_element (temLoadedModes, mode, ',')) return;
   temLoadedModes = sprintf("%s,%s", temLoadedModes, mode);

   if (TEMABBRV_TEMPLATE_DIRS == NULL) 
      TEMABBRV_TEMPLATE_DIRS = tem_default_search_path();

   file = search_path_for_file(TEMABBRV_TEMPLATE_DIRS, 
			       strlow(mode) + ".tem", ',');
   if (file == NULL) return;
   
   loadedfiles_this_mode = "";
   setbuf (get_template_buffer(mode));
   insert_template_file(file);
   loadedfiles_this_mode = "";
}

#iffalse
% Replaced
static define tem_load_mode_template (mode)
{
   variable aPaths, file, i, inc;
   variable temBuf, tmpbuf = "*tmp*";
   variable loadedFiles = "";
   
   if (is_list_element (temLoadedModes, mode, ',')) return;

   temLoadedModes = sprintf ("%s,%s", temLoadedModes, mode);
   
   if (TEMABBRV_TEMPLATE_DIRS == NULL) 
      TEMABBRV_TEMPLATE_DIRS = tem_default_search_path();

   % ! This includes only the first file found
   % file = search_path_for_file(TEMABBRV_TEMPLATE_DIRS, 
   % 	    			 strlow(mode) + ".tem", ',');
   % if (file == NULL) return;
      
   % ! This way I can include all files
   aPaths = strtok (TEMABBRV_TEMPLATE_DIRS, ",");
   for (i = 0; i < length(aPaths); i++)
   {
      file = dircat(aPaths[i], strlow(mode) + ".tem");
      % if (is_list_element(loadedFiles, file, ',')) continue;
      
      if (1 == file_status (file))
      {
         % loadedFiles = sprintf("%s,%s", loadedFiles, file);
         
	 setbuf (tmpbuf);
	 erase_buffer();
	 () = insert_file (file);
	 bob();
         
         %% Include other files
         while (bol_fsearch ("@@#INCLUDE"))
         {
            go_right (10);
            push_mark();
            eol();
            inc = bufsubstr();
            delete_line();
            bol();
            inc = str_delete_chars(inc, " \t\n");
            inc = dircat (path_dirname(file), inc);
            push_spot();
            % !if (is_list_element(loadedFiles, inc, ','))
            {
               () = insert_file (inc);
               % loadedFiles = sprintf("%s,%s", loadedFiles, file);
            }
            pop_spot();
         }
         
	 set_buffer_modified_flag (0);
	 setbuf (get_template_buffer(mode));
	 eob();
	 insert ("\n");
	 insbuf (tmpbuf);
      }
   }
   
   if (bufferp (tmpbuf)) delbuf(tmpbuf);
}
#endif

static define tem_find_expansion (token, findfirst)
{
   variable mode, buf, temBuf;
   (mode,) = what_mode();
   mode = strlow (mode);
   buf = whatbuf ();
   
   tem_load_mode_template(mode);
   temBuf = get_template_buffer(mode);
   
   !if (bufferp (temBuf))
   {
      setbuf (buf);
      return 0;
   }
   else setbuf (temBuf);

   if (findfirst) bob();
   
   token = get_token_header(token);
   
   eol();
   if (bol_fsearch (token)) 
   {
      setbuf (buf);
      return 1;
   }
   
   bob ();
   setbuf (buf);
   
   return 0;
}

define tem_find_possible_tokens(prefix)
{
   variable mode, buf, temBuf;
   variable toklist = "";
   
   (mode,) = what_mode();
   mode = strlow (mode);
   buf = whatbuf ();

   tem_load_mode_template(mode);
   temBuf = get_template_buffer(mode);
   
   !if (bufferp (temBuf))
   {
      setbuf (buf);
      return "";
   }
   else setbuf (temBuf);
   
   prefix = get_token_header_prefix(prefix);
   
   bob();
   
   while (bol_fsearch(prefix))
   {
      if (toklist == "") toklist = extract_token(line_as_string());
      else 
      {
         variable token = extract_token(line_as_string());
         variable pos = is_list_element(toklist, token, '|');
         
         !if (pos) toklist = toklist + "|" + token;
         else
         {
            % TODO: count instances of token
         }
      }
      eol();
   }
   
   bob ();
   setbuf (buf);
   
   return toklist;
}

static define tem_eval_variables()
{
   bob();
   while (fsearch ("$("))
   {
      push_mark();
      go_right(2);
      push_mark();
      if ( not ffind(")"))
      {
         pop_mark(1);
         pop_mark(0);
      }
      else
      {
         variable var = bufsubstr();
         variable res;
         go_right(1);
         del_region();
         
         ERROR_BLOCK
         {
            _clear_error();
         }
         
         if (not is_defined(var))
            insert ("?");
         else
         {
            res = eval(var);
            insert(string(res));
         }
      }
   }
}

static define tem_expand_parameters(OptArray)
{
   bob();
   while (re_fsearch ("\\$[1-9]"))
   {
      push_mark ();
      go_right (2);
      variable param = bufsubstr();
      variable prompt = param, repl = "";
      variable i;

      for (i = 0; i < length (OptArray); i++)
      {
         if (1 == is_substr (OptArray[i], param))
         {
            prompt = OptArray[i];
            break;
         }
      }

      repl = read_mini (prompt + ":", "", "");
      bob ();
      replace (param, repl);
   }
}

%!%+
%\function{tem_expand_template}
%\synopsis{Integer_Type tem_expand_template (token)}
%\description
%   Expands the last found template
%\returns
%   0 error
%   1 template expanded
%   2 template expanded, parameters inserted
%!%-
static define tem_expand_template (token)
{
   variable mode, buf, i, temBuf;
   variable options = "", expand = "", indent = 0;
   variable OptArray;
   variable bExpandArgs;
   
   (mode,) = what_mode();
   mode = strlow (mode);
   buf = whatbuf ();
   
   temBuf = get_template_buffer(mode);
   !if (bufferp(temBuf)) return 0;
   
   setbuf (temBuf);
   !if (looking_at (get_token_header(token)))
   {
      setbuf (buf);
      return 0;
   }

   %% Find expansion
   go_down (1);
   bol();
   push_mark();
   i = 0;
   while (not looking_at("@@:") and not eobp())
   {
      go_down (1);
      i++;
   }
   
   if (i > 0)
   {
      go_up(1);
      eol();
      expand = bufsubstr();
      go_down(1);
      bol();
   }
   else
   {
      expand = "";
      pop_mark(0);
   }
   
   %% Process options
   if (looking_at("@@:"))
   {
      go_right (3);
      push_mark ();
      eol ();
      options = bufsubstr();
      OptArray = strtok(options, ",");
      for (i = 0; i < length (OptArray); i++)
      {
	 OptArray[i] = strtrim (OptArray[i]);
	 if (OptArray[i] == "I+") indent = 1;
	 else if (OptArray[i] == "I-") indent = 0;
      }
   }
   
   setbuf (buf);
   push_mark();
   temExpBegin_point = create_user_mark();
   insert (expand);
   temExpEnd_point = create_user_mark();
   narrow_to_region ();
   tem_eval_variables();
   bob ();

   bExpandArgs = 0;
   if (re_fsearch ("\\$[1-9]"))
   {
      bob(); push_mark(); eob(); widen_region();
      update_sans_update_hook(1);
      narrow_to_region ();
      flush("Press '!' to expand parameters");
      if (input_pending (50))
      {
         variable ch = getkey();
         if (ch == '!') bExpandArgs = 1;
         else ungetkey(ch);
      }
      message("");
   }
   
   %% Expand parameters
   if (bExpandArgs)
   {
      tem_expand_parameters(OptArray);
   }
   
   %% Place the cursor to the marked position or eob
   bob();
   if (fsearch ("$_")) deln(2);
   else eob();
   push_spot ();

   if (indent)
   {
      bob();
      push_mark ();
      eob();
   }
   
   widen_region();
   
   if (indent and markp()) % indent inserted region
   {
      check_region (0);
      variable endl = what_line();
      exchange_point_and_mark();
      variable line = what_line();
      pop_mark(0);
      
      do {
         indent_line ();
         eol(); trim();
         line++;
      }
      while (down(1) and line <= endl);
   }

   pop_spot();

   if (bExpandArgs) return 2;
   
   return 1;
}

static define remove_last_expansion ()
{
   if (temExpBegin_point != NULL and temExpEnd_point != NULL)
   {
      goto_user_mark(temExpBegin_point);
      push_mark();
      goto_user_mark(temExpEnd_point);
      del_region();
   }
   temExpBegin_point = NULL;
   temExpEnd_point = NULL;
}

public define temabbrev()
{
   variable fun_type, fun, rvExpand;
   variable first_time = 1;
   variable tokenChars = "a-z0-9_";

   temLastToken = "";
   temExpBegin_point = NULL;
   temExpEnd_point = NULL;
   
   if (eolp () or (not eolp() and not TEMABBRV_EOL_ONLY)) 
   {
      push_spot();
      push_mark();
      bskip_chars(tokenChars);
      temLastToken = bufsubstr();
      pop_spot();
   }

   if (temLastToken == "")
   {
      if (TEMABBRV_DEFAULT_ACTION != "") 
         call (TEMABBRV_DEFAULT_ACTION);
      return;
   }
      
   forever
   {
      fun_type = -1;
      
      !if (tem_find_expansion (temLastToken, first_time))
      {
         !if (first_time) 
         {
            remove_last_expansion();
            insert (temLastToken);
            update_sans_update_hook (1);   %  force update
            
            vmessage ("No more completions for '%s'", temLastToken);
         }
         else
         {
            variable toklist = tem_find_possible_tokens(temLastToken);
            if (toklist == "")
               vmessage ("No completions for '%s'", temLastToken);
            else
               vmessage (toklist);
         }
         
         break; % forever
      }
      else
      {
         if (first_time)
         {
            push_mark();
            bskip_chars(tokenChars);
            del_region();
         }
         else remove_last_expansion();
         
         rvExpand = tem_expand_template (temLastToken);
         update_sans_update_hook (1);      %  force update
         
         if (rvExpand == 2) break;
      }

      (fun_type, fun) = get_key_binding ();
	
      if (fun != "temabbrev")
         break; % forever
      
      first_time = 0;
   }
   

   if (fun_type > 0) call (fun);
   else if (fun_type == 0) eval (fun);
}

provide ("temabbrv");


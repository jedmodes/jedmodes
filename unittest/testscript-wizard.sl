% testscript-wizard.sl: Generate a test script template for a sl mode
% 
% Copyright (c) 2006 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1   2006-03-03
% 0.3   2006-10-04 * adapted to unittest 0.3 (test function detection, fixtures)
% 0.3.1 2006-10-05 * bugfixes, requirements

require("strutils");
require("hyperhelp", "help.sl");
autoload("insert_template", "templates");

custom_variable("Unittest_Test_Directory", "~/.jed/lib/unit-tests");

% valid chars in function and variable definitions
static variable Slang_word_chars = "A-Za-z0-9_";

private variable tmpbuf = make_tmp_buffer_name("*testscript-parse*");

% generate a testscript template for \var{file}
public define testscript_wizard()  % (file=buffer_filename())
{
   variable file = push_defaults(buffer_filename(), _NARGS);
   % try on jed-library path, if not found directly
   if (file_status(file) != 1)
     file = expand_jedlib_file(file);

   variable public_functions = {}, definitions = {}, definition, 
     definition_line, tokens, fun, help_str, usage_str, namespace_name = "";
   
   % Parse the file
   % --------------
   
   sw2buf(tmpbuf);
   erase_buffer();
   () = insert_file(file);
   set_buffer_modified_flag(0);
   define_blocal_var("Word_Chars", Slang_word_chars);
   
   % named namespace?
   bob();
   if (orelse{bol_fsearch("implements")}  
        {bol_fsearch("_implements")} 
        {bol_fsearch("use_namespace")})
     namespace_name = strtrim(strtok(line_as_string(), "( ")[1], "\");");
   % does the mode contain explicitely public functions?
   bob();
   while (bol_fsearch("public define "), right())
     {
        list_append(public_functions, get_word());
        % get_y_or_n("funs " + sprint_list(public_functions) + " continue?");
     }
   
   % collect definitions of public accessible functions
   bob();
   while (fsearch("define "))
      {
         push_spot_bol();
         if (looking_at("public") 
            or looking_at("define")
            or (looking_at("static") and namespace_name != "")
            )
           {
              eol();
              push_mark();
              while (up_1() and looking_at("% "))
                ;
              list_append(definitions, bufsubstr(), -1);
           }
         pop_spot();
         eol();
      }
   delbuf(tmpbuf);
   
   % Set up the test script buffer
   % -----------------------------
   
   () = find_file(expand_filename(path_concat(Unittest_Test_Directory,
      path_sans_extname(path_basename(file))+ "-test.sl")));
   % if this is an empty file and templates are set up correctly, the standard
   % template for slang files will be used.
   
   % adapt the slang code template for test scripts
   bob();
   eol();
   insert(" Test " + path_basename(file));
   eob();
   insert("require(\"unittest\");\n\n");

   
   if (length(public_functions))
     insert("% test availability of public functions (comment to skip)\n");
   foreach (public_functions)
     {
        fun = ();
        vinsert("test_true(is_defined(\"%s\"), \"public fun %s undefined\");\n",
           fun, fun);
     }
   
   % preface
   insert("\n% Fixture\n");
   insert("% -------\n\n");
   vinsert("require(\"%s\");\n\n", path_sans_extname(path_basename(file)));
   insert("private variable testbuf = \"*bar*\";\n");
   insert("private variable teststring = \"a test line\";\n\n");
   
   insert("static define setup()\n");
   insert("{\n");
   insert("   sw2buf(testbuf);\n");
   insert("   insert(teststring);\n");
   insert("}\n\n");

   insert("static define teardown()\n");
   insert("{\n");
   insert("   sw2buf(testbuf);\n");
   insert("   set_buffer_modified_flag(0);\n");
   insert("   close_buffer(testbuf);\n");
   insert("}\n\n");

   
   if (namespace_name != "")
       insert("% private namespace: `" + namespace_name + "'\n\n");

   % function test templates
   
   insert("% Test functions\n");
   insert("% --------------\n\n");
   
   foreach (definitions)
     {
        definition = ();
        % extract definition line
        definition = strtok(definition, "\n")[-1];
        % extract function name
        tokens = strtok(definition, " \t(");
        try
          fun = tokens[wherefirst(tokens == "define")+1];
        catch AnyError:
          continue;
        % documentation (online help or comments)
        if (tokens[0] == "static")
          fun = namespace_name + "->" + fun;
        help_str = help->help_for_object(fun);
        if (is_substr(help_str, "Undocumented"))
          help_str = definition + "\n";
        usage_str = help->extract_usage(help_str);
        if (usage_str == "")
          usage_str = "$fun()"$;
        else
          usage_str = strtrim_end(usage_str, ";");
        push_mark();
        insert(help_str);
        comment_region();
        % test function
        vinsert("static define test_%s()\n", strtok(fun, ">")[-1]);
        insert("{\n");
        insert("   $usage_str;\n"$);
        insert("}\n\n");
     }
   % trailer
   insert("sw2buf(\"*test report*\");\n");
   insert("view_mode();\n");

   bob();
   fsearch("sw2buf");
}


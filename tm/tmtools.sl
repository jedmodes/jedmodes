% tmtools.sl: Some semi-automatic tm style documentation generation.
%
% Copyright (c) 2005 Dino Leonardo Sangoi, Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
% 
% _debug_info=1;

% Requirements
% ------------

% If you have Dinos cext.sl, uncomment the next line and
% exchange c_top_of_function with new_top_of_function.
%require("cext");
require("comments");
autoload("get_word", "txtutils");
autoload("insert_markup", "txtutils");
autoload("string_nth_match", "stringutils");

% Uhm, the word should be defined by mode, I guess (but currently is not)
% More accurate: it should be mode specific: when I edit a latin1 encoded
% text after calling tm_make_doc, I get trouble with Umlauts. Therefore:
private variable word_chars = "A-Za-z0-9_";

% valid tm attributes (subset understood by tm2ascii() in tm.sl)
static variable tm_attributes = "var, em";

static define tm_make_var_doc()
{
   variable line = line_as_string, name, value, tm;
   !if (string_match(line, "custom_variable ?(\"\\(.*\\)\", ?\\(.*\\));", 1))
     return;
   (name, value) = (string_nth_match(line,1), string_nth_match(line, 2));
   if (is_substr(value, "\""))
     tm = "%%!%%+\n%%\\variable{%s}\n%%\\synopsis{}\n%%\\usage{String_Type %s = \"%s\"}\n%%\\description\n%%  \n%%\\seealso{}\n%%!%%-\n";
   else % assume it's an integer TODO: check value, auto-guess type
     tm = "%%!%%+\n%%\\variable{%s}\n%%\\synopsis{}\n%%\\usage{Int_Type %s = %s}\n%%\\description\n%%  \n%%\\seealso{}\n%%!%%-\n";
   tm = sprintf(tm, name, name, value);
   bol;
   insert(tm);
}

%!%+
%\function{tm_make_doc}
%\synopsis{Create documentation comments for a function}
%\usage{tm_make_doc()}
%\description
%   When this function is called from inside a C or SLang function, it
%   creates right above the function itself a set of commented lines
%   formatted as expected by tm2txt. Some data will be generated
%   automagically from the function definition and comments.
%\notes
%   Bind to a key.
%\seealso{tm_set_attr}
%!%-
public define tm_make_doc()
{
   variable name, name_with_args;
   variable c = get_comment_info();
   variable cb, cm, ce;
   
   if (c == NULL)
     verror("No comment strings defined for %s mode", get_mode_name());
   
   cb = strtrim(c.cbeg);
   ce = strtrim(c.cend);
   cm = strtrim(c.cbeg);
   if (c.cend != "") {
      if (strlen(cm) > 1)
	cm = " " + cm[[1:]];
   }
   
   % if we're looking at a custom_variable, document it
   bol;
   if (looking_at("custom_variable")) return tm_make_var_doc;
   % new_top_of_function();
   % find the top of function
   down_1(); % dont't jump to last fun, if in first line of function
   c_top_of_function(); % goes to first opening {
   !if (re_bsearch("[]\\)\\}\\;\\>\\\"]"))
     break;
   if (what_char != ')')
     return;
   right(1); % leave on Stack
   push_mark();
   go_left(());  % get from stack
   call("goto_match");
   bskip_chars(" \t\n");
   name = bget_word(word_chars);
   bol();
   name_with_args = bufsubstr(); 
   % may contain static, local, global, and define keywords:
   if(get_mode_name() == "SLang")
     {
	(name_with_args, ) =  strreplace(name_with_args, "static ", "", 1);
	(name_with_args, ) =  strreplace(name_with_args, "local ", "", 1);
	(name_with_args, ) =  strreplace(name_with_args, "public ", "", 1);
	(name_with_args, ) =  strreplace(name_with_args, "define ", "", 1);
	% uncomment the next line, if you like to insert Void by default
	% (name_with_args, ) =  strreplace(name_with_args, "define ", "Void ", 1);
	% optional arguments
	(name_with_args, ) =  strreplace(name_with_args, "() % ", "", 1);
     }
	
%    TODO:
%    % Check existing comments
%    push_mark();
%    do
%      {go_up_1; bol;}
%    while(looking_at("%"));
% %   exchange_point_and_mark();
%    message(bufsubstr);
    
   % Grrr, Wy C uses " *%+" while slang uses "%!%+" ???
   if (cb == "%")
     insert ("%!%+\n");
   else
     insert (cb + "%+\n");
   vinsert("%s\\function{%s}\n", cm, name);
   insert (cm + "\\synopsis{}\n");
   % TODO: check for a return value
   vinsert("%s\\usage{ %s}\n", cm, name_with_args);
   insert (cm + "\\description\n");
   insert (cm + "  \n");
   insert (cm + "\\example\n");
   insert (cm + "#v+\n");
   insert (cm + "  \n");
   insert (cm + "#v-\n");
   insert (cm + "\\notes\n");
   insert (cm + "  \n");
   insert (cm + "\\seealso{}\n"); % comma separated list
   if (cm == "%")
     insert ("%!%-\n");
   else
     insert (cm + "%-\n");
   if (ce != "")
     insert(" "+ce+"\n");
}

%!%+
%\function{tm_set_attr}
%\synopsis{Add attribute around a word in tm format}
%\usage{tm_set_attr(String_Type attr)}
%\description
%   This function adds '\\attr{' and '}' around the word at the point.
%   (attr is replaced with the actual parameter).
%\notes
%   Bind this to a key. For example, I bind "tm_set_attr(\"var\")" to "^Wv".
%\seealso{tm_make_doc}
%!%-
public define tm_set_attr() % ([attr])
{
   variable attr;
   if (_NARGS)
     attr = ();
   else
     attr = read_string_with_completion ("Attribute", "var", tm_attributes);
   insert_markup(sprintf("\\%s{", attr), "}");
}

provide("tmtools");

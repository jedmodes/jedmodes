% structured_text Mode:

% FIXME show(re_fsearch("^[ |\t]*\\([0-9]+\. \\)"));  

% return length of list-mark or 0
% > 0 if line start with "[*|+|-] " or "[0-9]+\. "
define st_is_list()  
{
   variable rv = 0, col; % return value
   % show("line", what_line, "calling st_is_list");
   push_spot ();
   bol_skip_white ();
   % unordered list
   if ( orelse{looking_at ("- ")}{looking_at ("* ")}{looking_at("+ ")} )
     rv = 2;
   % ordered list
   else
     {
	col = what_column;
	skip_chars ("0-9#");
	if ( looking_at (". ") )			  
	  rv = (what_column - col + 2);
     }
   pop_spot();
   return rv;
}
  
  
% lines that start or end a paragraph:  empty line or list
define st_is_paragraph_separator()
{
   variable rv;
   % show("line", what_line, "calling st_is_paragraph_separator");
   push_spot ();
   EXIT_BLOCK {pop_spot ();}
   bol_skip_white ();
   
   if (eolp) % empty line
     rv = 1;
   else % check for list
     {
	go_down_1();
	rv = st_is_list(); 
     }
   pop_spot ();
   return rv;
}
% Todo: Lines that are marked as paragraph separator don't get
% formatted when calling format_paragraph :-(



% indent for structured text  (expanded from example in hooks.txt)
define st_indent ()
{
   variable indendation;
   % show("line", what_line, "calling st_indent");
   % get indendation of previous line
   push_spot();
   go_up_1;
   bol_skip_white();
   indendation = what_column - 1;        
   indendation += st_is_list();  % returns length of list indicator or 0
   go_down_1;
   indendation -= st_is_list();  % indent a list to the level of a preceding list
   bol_trim();
   whitespace(indendation);
   pop_spot();
   if (bolp)
     skip_white();
}

% indent to the level of the last non-empty line
define st_indent_relative ()
{
   variable indendation;
   push_spot();
   bol();
   push_spot(); % second_spot
   % search for preceding non-empty line
   bskip_chars ("\n\t ");         % bskip white + newlines
   % determine indendation level
   bol_skip_white ();
   indendation = what_column() - 1;
   % indent line and return to starting point
   pop_spot();        % second spot (beg of line)
   trim();
   whitespace (indendation);
   pop_spot();
   if (bolp)
     skip_white();
}

% newline_and_indent for structured text: indent to level of preceding line
% we have to redefine, as the default uses the indent_hook which does
% something different
define st_newline_and_indent ()
{
   % show("line", what_line, "calling st_newline_and_indent");
   variable indendation, col = what_column();
   % get number of leading spaces
   push_spot();
   bol_skip_white();
   indendation = what_column();
   pop_spot();
   newline();
   if (indendation > col)  % more whitespace than the calling points column
     indendation = col;
   whitespace(indendation-1);
}

% --- Create and initialize the syntax tables.
% $1 = "structured_text";
% create_syntax_table ($1);
% define_syntax ("#", "", '%', $1);    % Comments
% % define_syntax (">", "", '%', $1);    % Comments  Mail citations
% define_syntax ("-*+", '+', $1);      % Operators


public define text_mode_hook ()
{
   % set_comment_info ("Text"   , "% "   , ""    , 1|2|4);
   set_buffer_hook("wrap_hook", &st_indent);
   set_buffer_hook("indent_hook", &st_indent);
   set_buffer_hook("newline_indent_hook", &st_newline_and_indent);
   set_buffer_hook("par_sep", & st_is_paragraph_separator);
   % use_syntax_table ("structured_text");
}

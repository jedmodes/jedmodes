% a2ps.sl	-*- mode: Slang; mode: Fold -*-
% mode for editing a2ps stylesheets
% 
% $Id: a2ps.sl,v 1.1 2004/02/20 09:31:32 paul Exp paul $
% Keywords: languages
%
% Copyright (c) 2003 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).

% This mode should be useful for writing a2ps stylesheets, because if
% e.g. "case" happens to be a keyword in the language you want to
% pretty-print, you have to quote it.  Written for a2ps 4.13

$1 = "a2ps";
provide ($1);

%{{{ syntax table

% this is mostly out of sh_mode.sl
create_syntax_table ($1);
define_syntax ("#", "", '%', $1);
define_syntax ("([{", ")]}", '(', $1);

%define_syntax ('\'', '"', $1);
define_syntax ('"', '"', $1);
define_syntax ('/', '"', $1); % regexps

define_syntax ('\\', '\\', $1);
define_syntax ("-0-9a-zA-Z_", 'w', $1);        % words
define_syntax ("-+0-9", '0', $1);   % Numbers
define_syntax (",;:", ',', $1);
define_syntax ("%-+&*=<>|!~^", '+', $1);

set_syntax_flags($1, 0x80);

% The keywords are from ssh.ssh

define_keywords_n("a2ps", "byinis", 2, 0);
define_keywords_n("a2ps", "areend", 3, 0);
define_keywords_n("a2ps", "Tag1Tag2Tag3Tag4a2pscase", 4, 0);
define_keywords_n("a2ps", "ErrorLabelPlainfirststyle", 5, 0);
define_keywords_n("a2ps", "C-charIndex1Index2Index3Index4StringSymbolsecond", 6, 0);
define_keywords_n("a2ps", "CommentKeywordclosersversionwritten", 7, 0);
define_keywords_n("a2ps", "C-stringEncodingalphabetkeywordsoptionalrequires", 8, 0);
define_keywords_n("a2ps", "Invisiblealphabetsancestorsoperatorssensitivesequences", 9, 0);
define_keywords_n("a2ps", "exceptions", 10, 0);
define_keywords_n("a2ps", "insensitive", 11, 0);
define_keywords_n("a2ps", "Label_strong", 12, 0);
define_keywords_n("a2ps", "documentation", 13, 0);
define_keywords_n("a2ps", "Comment_strongKeyword_strong", 14, 0);

%}}}

%{{{ indentation mostly stolen from py_mode
private variable a2ps_indent = 0;

static define a2ps_line_starts_block()
{
   eol;
   blooking_at(" are");
}

static define a2ps_line_ends_block()
{
   bol_skip_white;
   looking_at("end ");
}

static define a2ps_indent_calculate()
{  % return the indentation of the previous a2ps line
   variable col = 0;
   variable subblock = 0;
   
   EXIT_BLOCK
     {
	pop_spot ();
	return col;
     }
   
   push_spot ();
   % check if current line ends a block
   subblock = a2ps_line_ends_block();
   
   % go to previous non blank line
   !if (re_bsearch ("[^ \t\n]"))
     return;
   bol_skip_white();
   
   col = what_column() - 1;
   
   if (a2ps_line_starts_block())
     col += 2;
   if (subblock)
     col -= 2;
}

define a2ps_indent_line()
{
   variable col;
%   push_spot;
   col = a2ps_indent_calculate();
   bol_trim ();
   whitespace( col );
 %  pop_spot;
}

define a2ps_newline_and_indent()
{
   push_spot;
   a2ps_indent_line();
   pop_spot;
   newline();
   a2ps_indent_line();
}

%}}}

%{{{ reformatting 
% a2ps documentation is one quoted line per source line.
% hmmm, email.sl won't let me redefine the quote chars.
define a2ps_reformat()
{
   variable quote;
   push_spot; 
     quote = string_get_match(line_as_string(), "^\\( *\"\\)[^\"]+\"$",1 ,1);
   !if (strlen(quote))
     return call("format_paragraph"), pop_spot;
   backward_paragraph;
   skip_chars("\n");
   push_mark;
   forward_paragraph;
   bskip_chars("\n");
   narrow;

   % remove end quotes
   bob;
   replace("\"\n", "\n");

   % remove begin quotes
   while (down_1) {trim; del;}

   % reformat
   WRAP -= strlen(quote);
   call("format_paragraph");
   WRAP += strlen(quote);
   
   % add begin quotes
   bob;
   while (down_1) {insert (quote);}
   
   % add end quotes
   bob;
   replace("\n", "\"\n");

   widen;
   pop_spot;
}

%}}}

!if (keymap_p ($1)) make_keymap ($1);

definekey ("indent_line", "\t", $1);
rebind("format_paragraph", "a2ps_reformat", $1);

define a2ps_mode ()
{
   set_mode("a2ps", 4);
   use_syntax_table ("a2ps");
   mode_set_mode_info ("a2ps", "fold_info", "#{{{\r#}}}\r\r");
   set_buffer_hook("indent_hook", &a2ps_indent_line);
   set_buffer_hook ("newline_indent_hook", &a2ps_newline_and_indent);
   use_keymap("a2ps");
   run_mode_hooks("a2ps_mode_hook");
}

add_mode_for_extension("a2ps", "ssh");

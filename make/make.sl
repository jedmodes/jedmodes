% -------------------------------------------- -*- mode:SLang; mode:folding -*-
%
% MAKE MODE FOR JED
%
% $Id: make.sl,v 1.1.1.1 2004/10/28 08:16:23 milde Exp $
%
% --------------------------------------------------------------------  %{{{
%
% DESCRIPTION
%	A very simple mode to write 'Makefile' files.
%
% USAGE
%	You can add the line
%
%		autoload ("make_mode", "make");
%
%	somewhere in your startup file. Actually it is not possible to
%	automatically start make_mode with the command line
%
%		$ jed Makefile
%
%	unless you put a line like
%
%		# -*- make -*-
%
%	near the beginning of your Makefile. Alternatively, you can read and
%	follow the instructions given in 'doc/txt/hooks.txt'.
%
% AUTHOR
%	Francesc Rocher (f.rocher@computer.org)
%       Feel free to send comments, suggestions or improvements.
%
% ------------------------------------------------------------------------ %}}}

implements("Make");

private define is_comment_line      ()  %{{{
{
   push_spot_bol ();
   skip_white ();
   $0 = 0;
   if (what_char () == '#')
      $0 = what_column ();
   pop_spot ();
   return $0;
}

%}}}
private define in_comment           ()  %{{{
{
   push_spot ();
   $0 = 0;
   if (bfind_char ('#'))
      $0 = what_column ();
   pop_spot ();
   return $0;
}

%}}}
private define is_continuation_line ()  %{{{
{
   push_spot ();
   $0 = 0;
   if (up (1))
     {
        eol ();
        bskip_white ();
        !if(bolp ())
          {
             () = left (1);
             if (what_char () == '\\')
               {
                  bol_skip_white ();
                  $0 = what_column ();
               }
          }
     }
   pop_spot ();
   return $0;
}

%}}}
private define is_rule_head         ()  %{{{
{
   push_spot_bol ();
   $0 = 0;
   while (ffind_char (':'))
     {
        $0 = 1;
        () = right (1);
     }
   () = left (1);
   if (andelse
         {$0}
         {in_comment () == 0}
         {looking_at (":=") == 0})
      $0 = 1;
   else
      $0 = 0;
   pop_spot ();
   return $0;
}

%}}}
private define is_rule_body         ();
private define is_rule_body         ()  %{{{
{
   if (is_comment_line ())
      return 0;
   $0 = is_rule_head ();
   !if ($0)
     {
        push_spot ();
        if (andelse
              {up (1)}
              {not bolp ()})
           $0 = is_rule_body ();
        else
           $0 = 0;
        pop_spot ();
     }
   return $0;
}

%}}}
public  define make_indent_line     ()  %{{{
{
   $0 = is_continuation_line ();
   if ($0)
     {
        push_spot ();
        bol_skip_white ();
        if (what_column () < $0)
          {
             bol_trim ();
             insert_char ('\t');
             while (what_column () < $0-TAB+1)
                insert_char ('\t');
             whitespace ($0 - what_column ());
          }
        else
          {
             while (what_column () > $0)
                call ("backward_delete_char_untabify");
          }
        pop_spot ();
        if (what_column () < $0)
           skip_white ();
        return;
     }
   if (in_comment ())
     {
        % insert_char ('\t');   % This is a possibility ...
        return;
     }
   if (is_rule_head ())
     {
        push_spot_bol ();
        trim ();
        pop_spot ();
        return;
     }
   if (is_rule_body ())
     {
        push_spot_bol ();
        !if (what_char () == '\t')
          {
             trim ();
             insert_char ('\t');
          }
        pop_spot ();
        if (bolp ())
           () = right (1);
        return;
     }
}

%}}}
public  define make_newline         ()  %{{{
{
   $1 = is_comment_line ();
   if ($1)
     {
        insert_char ('\n');
        whitespace ($1-1);
        insert ("# ");
        return;
     }
   else
     {
        insert_char ('\n');
        make_indent_line ();
     }
}

%}}}

% Syntax highlighting                   %{{{

$0 = "make";
create_syntax_table ($0);
define_syntax ("#", "", '%', $0);
define_syntax ('"', '"', $0);
define_syntax ('\'', '\'', $0);
define_syntax ("(", ")", '(', $0);
define_syntax ("0-9a-zA-Z_", 'w', $0);

#ifdef HAS_DFA_SYNTAX
%
% This does not works fine. It seems like the DFA mechanism
% in JED is seriously damaged. Or, alternatively (and probably),
% I don't know how to write good rules   :(
%
define_highlight_rule("\"[^\"]*\"", "string", $0);
define_highlight_rule("'[^']*'", "string", $0);
%define_highlight_rule("\"([^\"\\\\]|\\\\.)*\"", "string", $0);
%define_highlight_rule("\"([^\"\\\\]|\\\\.)*\\\\?$", "string", $0);
%define_highlight_rule("'([^'\\\\]|\\\\.)*'", "Qstring", $0);
%define_highlight_rule("'([^'\\\\]|\\\\.)*\\\\?$", "string", $0);
define_highlight_rule ("^[ \t]*@", "string", $0);
define_highlight_rule ("[ \t]*\\\\[ \t]*$", "string", $0);
define_highlight_rule ("[ \t]*#.*$", "comment", $0);
define_highlight_rule ("[A-Za-z_][A-Za-z_0-9]*", "Knormal", $0);
%define_highlight_rule ("[ \t]*[A-Za-z_][A-Za-z_0-9]*", "Knormal", $0);
%define_highlight_rule ("^[ \t]*[A-Za-z_][A-Za-z_0-9]*", "Knormal", $0);
define_highlight_rule ("^[^\"']*\\:$", "keyword1", $0);
define_highlight_rule ("^[^\"']*\\:[ \t]+", "keyword1", $0);
%define_highlight_rule ("[ \t]*\.PHONY.*", "keyword1", $0);
define_highlight_rule ("/include", "normal", $0);
build_highlight_table ($0);
#endif

() = define_keywords_n ($0, "ARASCCCOCPFCPCRMfiif", 2, 0);
() = define_keywords_n ($0, "CPPCXXGETLEXTEX", 3, 0);
() = define_keywords_n ($0, "YACCelseifeq", 4, 0);
() = define_keywords_n ($0, "PHONYWEAVEYACCRendefendififdefifneqvpath", 5, 0);
() = define_keywords_n ($0, "CFLAGSCWEAVEFFLAGSGFLAGSIGNORELFLAGSPFLAGSRFLAGSSILENTTANGLEYFLAGSdefineexportifndef", 6, 0);
() = define_keywords_n ($0, "ARFLAGSASFLAGSCOFLAGSCTANGLEDEFAULTLDFLAGSinclude", 7, 0);
() = define_keywords_n ($0, "CPPFLAGSCXXFLAGSMAKEINFOPRECIOUSSUFFIXESTEXI2DVIoverrideunexport", 8, 0);
() = define_keywords_n ($0, "SECONDARY", 9, 0);
() = define_keywords_n ($0, "INTERMEDIATE", 12, 0);
() = define_keywords_n ($0, "EXPORT_ALL_VARIABLES", 20, 0);

set_syntax_flags ($0, 0x10|0x80);

%}}}

public  define make_mode            ()  %{{{
{
   $0 = "make";
   !if (keymap_p ($0))
     {
        make_keymap ($0);
        definekey ("make_indent_line", "^I", $0);
        definekey ("make_newline",     "", $0);
     }
   set_mode ($0, 4);
   use_keymap ($0);
   use_syntax_table ($0);
   run_mode_hooks ("make_mode_hook");
}

%}}}

% yodl.sl	-*- mode: Slang; mode: Fold -*-
% mode for editing yodl documents
% 
% $Id: yodl.sl,v 1.1 2004/02/28 09:18:50 paul Exp paul $
% Keywords: wp
%
% Copyright (c) 2004 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).

if (_featurep("yodl"))
  use_namespace("yodl");
else
  implements("yodl");
provide("yodl");

static variable mode = "yodl";

%{{{ syntax table
create_syntax_table (mode);
define_syntax ("a-zA-Z", 'w', mode);        % words
define_syntax ("(", ")", '(', mode);

define_keywords_n(mode, "bfemitnlsctt", 2, 0);
define_keywords_n(mode, "TeXdefditeitfigmitnoprefrowurl", 3, 0);
define_keywords_n(mode, "bindbookcellcitecodefilelinklreflurlmboxmenunodepartsectsubssupsverb", 4, 0);
define_keywords_n(mode, "LaTeXcellsemailenditlabellsectnpartnsectquoteredeftabletcell", 5, 0);
define_keywords_n(mode, "centercindexendditendeitfigurefindexkindexlanglemailtometalCnemailpindexranglereporttindexvindexwhenms", 6, 0);
define_keywords_n(mode, "articlechapterendmenuhtmltagitemizemanpageroffcmdrowlinesgmltagstartitsubsectwhenmanwhentxt", 7, 0);
define_keywords_n(mode, "abstractappendixellipsisendtablefootnotelchapterlsubsectnchapternodenamenodetextnoxlatinnsubsectstartditstarteitverbpipewhenhtmlwhensgml", 8, 0);
define_keywords_n(mode, "clearpageendcenterenumeratemakeindexmscommandparagraphplainhtmlstartmenuwhenlatex", 9, 0);
define_keywords_n(mode, "columnlinemancommandnodeprefixnparagraphprintindexstarttablesubsubsecttxtcommand", 10, 0);
define_keywords_n(mode, "affiliationdescriptionhtmlbodyopthtmlcommandhtmlnewfileincludefilelsubsubsectmanpagebugsmanpagenamemetaCOMMENTnsubsubsectsetlanguagesgmlcommandstartcenterverbincludewhentexinfo", 11, 0);
define_keywords_n(mode, "gettocstringlatexcommandlatexoptionslatexpackagemanpagefilessettocstringtocclearpage", 12, 0);
define_keywords_n(mode, "getdatestringgetpartstringmanpageauthornosloppyhfuzzredefinemacrosetdatestringsetpartstringsubsubsubsect", 13, 0);
define_keywords_n(mode, "getaffilstringgettitlestringlsubsubsubsectmanpageoptionsmanpagesectionmanpageseealsonotocclearpagensubsubsubsectsetaffilstringsettitlestringstandardlayouttexinfocommandtitleclearpage", 14, 0);
define_keywords_n(mode, "gagmacrowarninggetauthorstringgetfigurestringincludeverbatimlatexlayoutcmdsmanpagesynopsissetauthorstringsetfigurestring", 15, 0);
define_keywords_n(mode, "getchapterstringnotitleclearpagesetchapterstringsethtmlfigureextsetlatexverbchar", 16, 0);
define_keywords_n(mode, "notableofcontentssetlatexfigureext", 17, 0);
define_keywords_n(mode, "latexdocumentclassmanpagedescriptionmanpagediagnosticssethtmlfigurealign", 18, 0);
define_keywords_n(mode, "setrofftableoptions", 19, 0);


%}}}
%{{{ keyword completion
variable yodl_words = ["abstract", "affiliation",
"appendix", "article", "center", "chapter", "cindex", "clearpage",
"columnline", "description", "ellipsis", "endcenter", "enddit", "endeit",
"endmenu", "endtable", "enumerate", "figure", "findex", "footnote",
"gagmacrowarning", "getaffilstring", "getauthorstring", "getchapterstring",
"getdatestring", "getfigurestring", "getpartstring", "gettitlestring",
"gettocstring", "htmlbodyopt", "htmlcommand", "htmlnewfile", "htmltag",
"includefile", "includeverbatim", "itemize", "kindex", "langle",
"latexcommand", "latexdocumentclass", "latexlayoutcmds", "latexoptions",
"latexpackage", "lchapter", "lsubsect", "lsubsubsect", "lsubsubsubsect",
"mailto", "makeindex", "mancommand", "manpage", "manpageauthor",
"manpagebugs", "manpagedescription", "manpagediagnostics", "manpagefiles",
"manpagename", "manpageoptions", "manpagesection", "manpageseealso",
"manpagesynopsis", "metaCOMMENT", "metalC", "mscommand", "nchapter",
"nemail", "nodename", "nodeprefix", "nodetext", "nosloppyhfuzz",
"notableofcontents", "notitleclearpage", "notocclearpage", "noxlatin",
"nparagraph", "nsubsect", "nsubsubsect", "nsubsubsubsect", "paragraph",
"pindex", "plainhtml", "printindex", "rangle", "redefinemacro", "report",
"roffcmd", "rowline", "setaffilstring", "setauthorstring",
"setchapterstring", "setdatestring", "setfigurestring",
"sethtmlfigurealign", "sethtmlfigureext", "setlanguage",
"setlatexfigureext", "setlatexverbchar", "setpartstring",
"setrofftableoptions", "settitlestring", "settocstring", "sgmlcommand",
"sgmltag", "standardlayout", "startcenter", "startdit", "starteit",
"startit", "startmenu", "starttable", "subsect", "subsubsect",
"subsubsubsect", "texinfocommand", "tindex", "titleclearpage",
"tocclearpage", "txtcommand", "verbinclude", "verbpipe", "vindex",
"whenhtml", "whenlatex", "whenman", "whenms", "whensgml", "whentexinfo",
"whentxt"];

define complete()
{
   variable beg = get_word(), i, len, completions, match;
   len = strlen(beg);
   completions = 
     yodl_words[where(not array_map(Integer_Type, &strncmp, yodl_words, beg, len))];

   % Complete as much as possible.  By construction, the first len characters
   % in the matches list are the same.  Start from there.
   
   !if(length(completions)) return message ("No completions");
   match = completions[0];
   if (length(completions) == 1) return insert (match[[len:]]);
   _for (len, strlen (match)-1, 1)
     {
	i=();
	if (match[i] != completions[-1][i])
	  break;
     }
   insert (match[[len:i-1]]);
   message (strjoin(completions, "  "));  

}

%}}}
%{{{ indentation

% this only indents inside paramater lists, it does not recogize
% startdit()-enddit() pairs etc. Also it can't distinguish braces that
% delimit parameter lists, and braces in ordinary text (but usually these
% are balanced)
define indent_line ()
{
   variable col = 1;
   push_spot ();
   bol ();
   while(find_matching_delimiter (')'))
     col++;
   goto_spot ();
   bol_skip_white ();
   if (col != what_column ())
     {
	bol_trim ();
	col--; whitespace (col);
     }
   pop_spot ();
   push_mark ();
   bskip_white ();
   if (bolp ()) 
     {
	skip_white ();
	pop_mark_0 ();
     }
   else pop_mark_1 ();
}

%}}}
%{{{ parsep
% this needs some more work
define yodl_paragraph_separator ()
{
   bol_skip_white ();

   if (eolp ()) 
     return 1;

   if (re_looking_at ("[a-zA-Z]+("))
     return 1;

   return 0;
} 

%}}}
%{{{ help
% this was influenced by hyperhelp.sl

variable yodl_help_file = expand_jedlib_file("yodlfun.txt");
variable yodl_current_topic ="";

define help_for_yodl();

% most yodl keywords in the help file are enclosed in ` '
define yodlhelp_next_word()
{
   while(re_fsearch("\\`[a-zA-Z]+.*\\'"))
     {
	go_right_1();
	% Skip the current topic.
	!if (andelse
	     {strlen(yodl_current_topic)}
	       {re_looking_at(sprintf("\\<%s\\>", yodl_current_topic))})
	  break;
     }
}

define yodl_help_popup()
{
   popup_buffer("*yodl help*");
   use_syntax_table(mode);
   view_mode;
   local_setkey("indent_line", "\t");
   define_blocal_var("help_for_word_hook", &help_for_yodl);
   set_buffer_hook("newline_indent_hook", &help_for_word_at_point);
   set_buffer_hook("indent_hook", &yodlhelp_next_word);
   bob;
}

define help_for_yodl(w)
{
   if (yodl_help_file == "") error ("no helpfile found");
   if (w == "") 
     error("don't know what to give help for");
   variable h = get_doc_string_from_file(yodl_help_file, w);
   if (h == NULL) return message ("Can't help you");
   setbuf("*yodl help*");
   set_readonly(0);
   erase_buffer;
   insert(h);
   yodl_help_popup();
   yodl_current_topic = w;
}

% unlike hyperhelp apropos, this does a full-text regexp search in the
% help file and displays all matching items.
public define yodl_apropos() 
{ 
   variable regexp = read_mini("apropos (regexp)", "", "");
   setbuf("*yodl help*");
   set_readonly(0);
   erase_buffer;
   () = run_shell_cmd 
     (sprintf
     ("sed -e '/^-----/!{H;$!d;}' -e 'x;/%s/!d' %s",
      regexp, yodl_help_file));
   yodl_current_topic="";
   if (bobp and eobp) return message("no matches");
   yodl_help_popup();
}

%}}}
%{{{ keymap
!if (keymap_p (mode)) make_keymap (mode);

definekey ("yodl->complete", "\e\t", mode);
definekey ("indent_line", "\t", mode);
definekey_reserved ("yodl_apropos", "ha", mode);
%}}}

public define yodl_mode ()
{
   set_mode(mode, 1);
   use_syntax_table (mode);
   set_buffer_hook ("indent_hook", &indent_line);
   set_buffer_hook ("par_sep", &yodl_paragraph_separator);
   define_blocal_var("help_for_word_hook", &help_for_yodl);
   use_keymap(mode);
   run_mode_hooks("yodl_mode_hook");
}

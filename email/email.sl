% email.sl -*- mode: SLang; mode: Fold -*-
% 
% $Id: email.sl,v 1.1.1.1 2004/10/28 08:16:20 milde Exp $
% Keywords: mail
% 
% This file was written by the following people:
%   Ulli "Framstag" Horlacher	-> mail_mode
%   Thomas Roessler 		-> mail_mode light
%   Abraham vd Merwe
%   Johann Botha		-> muttmail
%   Ulli Horlacher		-> mailmode (muttmail light)
%   Paul Boekholt
%   Morten Bo Johansen		-> email
%
% This mail mode should work with both sendmail.sl and Mutt.

implements ("email");

require("keydefs");
_autoload
  ("rebind", "bufutils",
   "string_nth_match", "strutils",
   "gpg_encrypt", "gpg",
   "gpg_sign", "gpg",
   "ispell_region", "ispell", 5);

% Set the threshold for the number of quote levels beyond which you
% consider it a waste of time to deal with them. E.g. setting the value
% to 2 would delete all quote levels beyond the second level. The number
% includes the level you create yourself when you reply. A value of 0
% disables deletion.
custom_variable ("Email_Quote_Level_Threshold", 0);
% Your quoting string
custom_variable ("Mail_Quote_String", "> ");
% Do we recognize mbox style "From " lines as headers?
% for backwards compatibility ...
custom_variable ("mail_mode_have_mbox", 1);
custom_variable ("Email_Have_Mbox", mail_mode_have_mbox);

%{{{ static variables

variable mode  = "email";

% List of things that look like non-nested quotes (as Emacs' supercite
% makes) in this buffer. We assume that you don't try to edit two emails
% at once.
variable sc_quotes = "";

%}}}

%{{{ keymap

!if (keymap_p (mode)) make_keymap (mode);
rebind("format_paragraph", "email_reformat", mode);
definekey_reserved ("kill_this_level_around_point", "", mode);
definekey_reserved ("email_delete_quoted_sigs", "", mode);
definekey_reserved ("remove_excess_quote_levels", "", mode);
definekey_reserved ("email_attach_file", "", mode);
definekey_reserved ("email_sign", "/s", mode);
definekey_reserved ("email_encrypt", "/e", mode);
definekey_reserved ("ispell_message", "i", mode);
%}}}

%{{{ syntax highlighting

create_syntax_table (mode);

define_syntax ("-a-zA-Z",'w',mode);	% words
define_syntax ("0-9",'0',mode);		% numbers
define_syntax (",;:",',',mode);		% delimiters
define_syntax ('*', '\'', mode);	% *bold*
define_syntax('>', '#', mode);		% quotes
set_syntax_flags(mode, 0x20 | 0x80);

static variable color_from = "comment";
static variable color_to = "keyword1";
static variable color_subject = "number";
static variable color_header = "...";
static variable color_url = "keyword";
static variable color_email = "keyword";
static variable color_signature = "comment";
static variable color_reply1 = "preprocess";
static variable color_reply2 = "string";
static variable color_smiley = "operator";
static variable color_bold = "string";
static variable color_underline = "delimiter";
static variable color_italic = "delimiter";

#ifdef HAS_DFA_SYNTAX
% The highlighting copes with email addresses and url's
dfa_enable_highlight_cache ("email.dfa",mode);

dfa_define_highlight_rule ("^(To:|Cc:) .*",color_to,mode);
dfa_define_highlight_rule ("^Date: .*",color_header,mode);
dfa_define_highlight_rule ("^From: .*",color_from,mode);
dfa_define_highlight_rule ("^Subject: .*",color_subject,mode);

dfa_define_highlight_rule ("(http|ftp|file|https)://[^ \t\n>]+",color_url,mode);
dfa_define_highlight_rule ("[^ \t\n<]*@[^ \t\n>]+",color_email,mode);

dfa_define_highlight_rule ("^-- $",color_signature,mode);
dfa_define_highlight_rule ("^> ?> ?> ?> ?> ?>.*",color_reply2,mode);
dfa_define_highlight_rule ("^> ?> ?> ?> ?>.*",   color_reply1,mode);
dfa_define_highlight_rule ("^> ?> ?> ?>.*",      color_reply2,mode);
dfa_define_highlight_rule ("^> ?> ?>.*",         color_reply1,mode);
dfa_define_highlight_rule ("^> ?>.*",            color_reply2,mode);
dfa_define_highlight_rule ("^>.*",               color_reply1,mode);

dfa_define_highlight_rule ("[\\(\\)]+-?[:;P\\^]|[:;P\\^]-?[\\(\\)]+","color_smiley",mode);
dfa_define_highlight_rule ("_[a-zA-Z]+_",color_underline,mode);
dfa_define_highlight_rule ("\\*[a-zA-Z]+\\*",color_bold,mode);
dfa_define_highlight_rule ("/[a-zA-Z]+/",color_italic,mode);

dfa_build_highlight_table (mode);
enable_dfa_syntax_for_mode(mode);
#endif

%}}}

%{{{ static functions

%{{{ mostly header stuff

static define email_is_tag ()
{
   push_spot_bol ();
   orelse {andelse {Email_Have_Mbox} {bobp ()} {looking_at ("From ")}}
     {1 == re_looking_at ("^[A-Za-z][^: ]*:")};
   pop_spot ();
}

% I don't want to set a user mark in mail_mode(), because maybe headers etc.
% are added after mail_mode() is run
static define email_have_header ()
{
   push_spot_bob ();
   email_is_tag ();
   pop_spot ();
}

static define email_is_body ()
{
   !if (email_have_header ()) return 1;
   push_spot ();
   orelse
     {bol_bsearch ("\n")}
     {bol_bsearch ("--- Do not modify this line.  Enter your message below")};
   pop_spot ();
}


static define email_parsep ()
{
   push_spot_bol ();
   if (looking_at("--"))
     return pop_spot, 1;
   !if (email_is_body ())
     {
	(email_is_tag () or (skip_white (),eolp ()));
     }
   else
     {
	re_looking_at("[->|:} \t]*$");
     }
   pop_spot ();
}

static define reformat_header ()
{
   push_spot ();
   while (not (email_is_tag ()))
     {
	!if(up_1 ())
	  {
	     pop_spot ();
	     return;
	  }
     }

   bol ();
   ()=ffind_char(':');
   go_right_1 ();
   push_spot ();
   insert ("\n");
   bol_trim ();
   insert (" ");
   call ("format_paragraph");
   pop_spot ();
   del ();
   pop_spot ();
}

static define goto_end_of_headers()
{
   bob;
   () = orelse
     {bol_fsearch ("--- Do not modify this line.  Enter your message below")}
     {bol_fsearch ("\n")}
     {eob, newline, newline, 1};
   go_up_1;
}

static define narrow_to_body()
{
   push_spot;
   !if(email_have_header) mark_buffer;
   else
     {
	goto_end_of_headers;
	go_down(2);
	push_mark_eob;
     }
   narrow;
   pop_spot;
}

%}}}

%{{{ quote reformatting

% check if we're looking at a non-nested quote.
static define check_sc_quote()
{
   variable sc_quote;
   foreach (strchop(sc_quotes, ',', 0))
     {
	sc_quote = ();
	if (looking_at(sc_quote))
	  return sc_quote;
     }
   return "";
}

% efficient requoting function (no loop)
static define requote_buffer(quote)
{
   variable end_newline = 0;
   push_spot;
   % trim trailing newline
   eob;
   if (looking_at_char('\n'))
     {
	end_newline = 1;
	del;
     }
   bob;
   % first line does not have a newline before it
   insert(quote);
   replace("\n", "\n" + quote);
   % restore trailing newline
   if (end_newline)
     {
	eob;
	insert_char('\n');
     }
   pop_spot;
}

% reformat quoted text
static define reformat_quote()
{
   variable quotes, qlen;
   push_spot_bol;
   push_mark;
   skip_chars(">|: \t");
   quotes = bufsubstr;
   quotes += check_sc_quote;
   qlen = strlen(quotes);
   % narrow to comment
   while (up_1)
     {
	bol;
	if (orelse
	    { not looking_at(quotes)}
	    % If more quote-like stuff follows, it's a deeper quoting level
	    % Might as well test for -lists
	      { go_right(qlen), skip_white, eolp}
	      { check_sc_quote() != "" }
	      { push_mark, go_right_1, is_substr("->|:} \t", bufsubstr())})
	  {
	     go_down_1;
	     break;
	  }
     }
   push_mark;
   goto_spot;
   while (down_1)
     {
	if (orelse
	    { not looking_at(quotes)}
	      { go_right(qlen), skip_white, eolp}
	      { check_sc_quote() != "" }
	      { push_mark, go_right_1, is_substr("->|:} \t", bufsubstr())})
	  {
	     go_up_1;
	     break;
	  }
     }
   narrow;
   % unquote
   bob;
   deln(qlen);
   while (down(1))
     deln(qlen);
   goto_spot;
   % reformat
   WRAP=75 - strlen(strreplace(quotes, "\t", "        ", qlen), pop);
   call("format_paragraph");
   % requote
   requote_buffer(quotes);
   pop_spot;
   widen;
}

%}}}

%{{{ ispell quote hook

static define ispell_is_quote_hook()
{
   not looking_at(Mail_Quote_String);
}

%}}}

%}}}

%{{{ public functions

% Fix broken Outlook quoting.
% This is based on Tomasz 'tsca' Sienicki's oe_quot.sl for slrn.
public define un_oe_quote ()
{ variable rtk, hvr,len, cregexp =
     "\\(\n[|:> ]*\\)"  % line 1: quotes
     + "\\([|:>] ?\\)[^\n]\\{60,\\}" % extra quote, line of text
     + "\\1\\([^|:>]\\{1,15\\}\\)" % line 2: quotes, some text -> BROKEN!
     + "\\1\\2", % line 3: first and extra quote
     line = what_line;
   bob;
   if (email_have_header)
     {
	!if (bol_fsearch("--- Do not modify this line."))
	  ()= bol_fsearch("\n");
	go_down_1;
     }
   push_mark_eob;
   rtk = bufsubstr_delete;
   forever
     {
	if (string_match(rtk,cregexp,2))
	  {
	     (hvr,len) = string_match_nth(3);
	     rtk = (substr(rtk,1,hvr) + string_nth_match(rtk,2)
		    + substr(rtk,hvr+1,-1));
	  } else break;
     }
   insert(rtk);
   goto_line(line);
}

% check for non-nested quotes as Emacs' supercite makes. This only works
% after the quoted text is inserted into the buffer of course, so this is
% called from rmail_reply().
public define check_sc_quotes()
{
   variable sc_quote, pos = 1, len;
   sc_quotes = "";
   push_spot();
   mark_buffer;
   variable buffer = bufsubstr;
   pop_spot;
   while (string_match
	  (buffer,"\n\\([>|: \t]*\\)"	  % quotes
	   + "\\([a-zA-Z]\\{2,5\\}> ?\\)" % maybe sc quote
	   + "[^\n]*\n" % rest of line
	   + "\\1\\2"	% next line starts with quotes and sc quote
	   , pos))
	  {
	     sc_quote = string_nth_match(buffer, 2);
	     !if (is_list_element(sc_quotes, sc_quote, ','))
	       sc_quotes += sc_quote + ",";
	     (pos, len) = string_match_nth (0);
	     pos += len + 1;
	  }
}

public define email_reformat ()
{
   if (email_is_body ()) reformat_quote (); else reformat_header ();
}

% If standing in the middle of a quoted paragraph, split the line at
% point, insert three empty lines, prepend contextual number of quote
% characters to remainder of split line and move two lines up. Run
% email_reformat on the second paragraph.
public define email_split_quoted_paragraph ()
{
   if (bolp or eolp) return newline, indent_line;
   push_spot_bol;
   !if (re_looking_at ("^[>|:]+"))
     {
        pop_spot ();
        return newline, indent_line;
     }
   push_mark;
   skip_chars (">|:} ");
   "\n\n\n" + bufsubstr + check_sc_quote;
   pop_spot;
   trim;
   insert ();
   email_reformat ();
   go_up(2) ();
}

% Remove quote levels beyond a user defined number
public define remove_excess_quote_levels ()
{
   variable threshold = prefix_argument(-1);
   if (threshold == -1)
     threshold = Email_Quote_Level_Threshold;
   push_spot_bob ();
   while (re_fsearch (sprintf("^\\(%s[>|: ]+\\)", Mail_Quote_String)))
     {
        variable qlen = strlen (strtrans (regexp_nth_match(0)," ",""));
        if (qlen > threshold) delete_line ();
	else eol;
     }
   pop_spot ();
}

% Delete text this quoting level around point, possibly skipping quoted
% empty lines. This is not SC-aware yet.
public define kill_this_level_around_point ()
{
   push_spot_bol; push_mark; skip_chars(">|: \t");
   variable quotes = bufsubstr;
   variable qlen = strlen (quotes);
   !if (qlen) return pop_spot;
   while (up_1)
     {
	bol;
	if (orelse
	    { not looking_at(quotes)}
	      { go_right(qlen), andelse
		   { not eolp }
		   { push_mark, go_right_1, is_substr(">|:} \t", bufsubstr())}
	      })
	  {
	     go_down_1;
	     break;
	  }
     }
   push_mark;
   goto_spot;
   while (down_1)
     {
	if (orelse
	    { not looking_at(quotes)}
	      { go_right(qlen), andelse
		   { not eolp }
		   { push_mark, go_right_1, is_substr(">|:} \t", bufsubstr())}
	      })

	  {
	     go_up_1;
	     break;
	  }
     }
   del_region;
}

public define email_delete_quoted_sigs()
{
   variable quotes, qlen;
   bob;
   while (re_fsearch("^\\([>|: \t]+\\)-- ?[a-zA-Z]\\{0,7\\}$"))
     {
	quotes = regexp_nth_match(1);
	qlen = strlen(quotes);
	push_mark;
	while (down_1)
	  {
	     if (orelse
		 { not looking_at(quotes)}
		   { go_right(qlen), andelse
			{ not eolp }
			{ skip_white, push_mark, go_right_1, is_substr(">|:}", bufsubstr())}
		   })

	       {
		  go_up_1;
		  break;
	       }
	  }
	del_region;
     }
}

% clean up reply body:delete quoted signature, remove empty quoted lines
public define email_prepare_reply()
{
   push_spot; eob;
   % delete a quoted signature
   if (bol_bsearch(strcat(Mail_Quote_String, "-- ")))
     {
        push_mark;
	% Don't delete my own signature
	!if (bol_fsearch("-- "))
	  eob;
	del_region;
     }

   % remove empty quoted lines without removing the line itself
   bob;
   while (re_fsearch ("^[>|: \t]+$")) del_eol ();

   % trim trailing whitespace (if any)
   eob ();
   push_mark;
   bskip_chars (" \t\n");
   % leave a newline, avoid error with read-only line in mail()
   if (looking_at_char('\n')) go_right_1;
   % and another
   if (looking_at_char('\n')) go_right_1;
   del_region ();
   pop_spot;
}

% Clean up message before editing: position cursor, if quote_string is
% found call email_prepare_reply(). You may call this from
% email_mode_hook.
public define email_prepare_body ()
{
   if (bol_fsearch(Mail_Quote_String))
     email_prepare_reply;
   else
     !if (bol_fsearch("\n")) eob;
}

% This only works with sendmime.sl, and with Mutt.
public define email_attach_file()
{
   !if (email_have_header) error ("no headers!");
   variable attachment = read_with_completion("Attach", "", "", 'f');
   push_spot;
   goto_end_of_headers;
   vinsert("\nAttach: %s", attachment);
   pop_spot;
}

static define fun_on_body(fun)
{
   variable line = what_line, wline = window_line;
   narrow_to_body;
   @fun;
   widen;
   goto_line(line);
   recenter(wline);
}

% encrypt a message
public define email_encrypt()
{
   fun_on_body(&gpg_encrypt);
}

% sign a message
public define email_sign()
{
   fun_on_body(&gpg_sign);
}

% spell check a message
% To do: check the subject line too.
public define ispell_message()
{
   fun_on_body(&ispell_region);
}
  
public define mail_mode ()
{
   no_mode ();
   set_mode (mode,1);
   use_keymap (mode);
   use_syntax_table (mode);
   set_buffer_hook ("par_sep", &email_parsep);
   set_buffer_hook ("newline_indent_hook", "email_split_quoted_paragraph");
   define_blocal_var("flyspell_syntax_table", mode);
   define_blocal_var("ispell_region_hook", &ispell_is_quote_hook);
   check_sc_quotes;
   runhooks ("text_mode_hook");
   runhooks ("email_mode_hook");
   if (Email_Quote_Level_Threshold > 0) remove_excess_quote_levels ();
}

%}}}

provide ("email");

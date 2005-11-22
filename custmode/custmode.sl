% Created : 08 Oct 2004
% Author  : Marko Mahnic
%
% Create a custom syntax table for the current buffer.
% The syntax is defined after the modeline.
% Each custom_mode buffer creates its own syntax table named custom_N.
% The name of the syntax table is stored in a buffer-local variable.
%
% 
% 
% 


require ("keywords");

static variable custom_syn="custom";
static variable blvar_modename="custom_mode";
static variable blvar_modeflgs="custom_flags";
static variable custom_count = 0;

static define extract_eol(eq_char)
{
   () = ffind_char(eq_char);
   go_right(1);
   push_mark();
   eol();
   return strtrim(bufsubstr());
}

static define extract_char(eq_char)
{
   () = ffind_char(eq_char);
   go_right(1);
   skip_white();
   return what_char();
}


static define prepare_syntax_table(modename)
{
   variable n = 0, kwds1 = NULL, kwds2 = NULL;
   variable modeflags = 2;
   variable kwdflags;
   create_syntax_table(modename);
   
   bob();
   n = re_fsearch ("-\\*- *mode: *custom");
   if (n < 1) return;
   if (what_line() > 4) return;

   go_down(1);
   bol();
   
   n = ffind ("###");
   while (n)
   {
      go_right(3);
      skip_white();
      if (looking_at("%"))
      {
         if (looking_at("%keywords1="))
         {
            if (kwds1 == NULL) kwds1 = keywords->new_keyword_list ();
            keywords->add_keywords (kwds1, extract_eol('='));
         }
         else if (looking_at("%keywords2="))
         {
            if (kwds2 == NULL) kwds2 = keywords->new_keyword_list ();
            keywords->add_keywords (kwds2, extract_eol('='));
         }
         else if (looking_at("%words="))         define_syntax (extract_eol('='), 'w', modename);
         else if (looking_at("%numbers="))       define_syntax (extract_eol('='), '0', modename);
         else if (looking_at("%commenteol="))    define_syntax (extract_eol('='), "", '%', modename);
         else if (looking_at("%string1="))       define_syntax (extract_char('='), '\'', modename);
         else if (looking_at("%string2="))       define_syntax (extract_char('='), '\"', modename);
         else if (looking_at("%preprocessor="))  define_syntax (extract_char('='), '#', modename);
         else if (looking_at("%quote="))         define_syntax (extract_char('='), '\\', modename);
         else if (looking_at("%parens="))
         {
            variable parens = extract_eol('=');
            variable len = strlen(parens);
            
            if ((len > 1) and ((len mod 2) == 0) )
               define_syntax (substr(parens, 1, len/2), substr(parens, len/2+1, len/2), '(', modename);
         }
         else if (looking_at("%modeflags="))
         {
            kwdflags = strlow(extract_eol('='));
            modeflags = 0;
            
            if (is_substr(kwdflags, "wrap")) modeflags |= 0x01;
            if (is_substr(kwdflags, "c")) modeflags |= 0x02;
            if (is_substr(kwdflags, "language")) modeflags |= 0x04;
            if (is_substr(kwdflags, "slang")) modeflags |= 0x08;
            if (is_substr(kwdflags, "fortran")) modeflags |= 0x10;
            if (is_substr(kwdflags, "tex")) modeflags |= 0x20;
         }
         else if (looking_at("%syntaxflags="))
         {
            kwdflags = strlow(extract_eol('='));
            variable syntax = 0;
            
            if (is_substr(kwdflags, "nocase")) syntax |= 0x01;
            if (is_substr(kwdflags, "comfortran")) syntax |= 0x02;
            if (is_substr(kwdflags, "nocmodeldspc")) syntax |= 0x04;
            if (is_substr(kwdflags, "tex")) syntax |= 0x08;
            if (is_substr(kwdflags, "comeolspc")) syntax |= 0x10;
            if (is_substr(kwdflags, "preprocline")) syntax |= 0x20;
            if (is_substr(kwdflags, "preprocldspc")) syntax |= 0x40;
            if (is_substr(kwdflags, "nostrspan")) syntax |= 0x80;
            
            set_syntax_flags(modename, syntax);
         }
      }
      
      go_down(1);
      if (eobp()) break;
      bol();
      n = ffind ("###");
   }
   
   if (kwds1 != NULL) 
   {
      keywords->sort_keywords(kwds1);
      if (syntax & 0x01) keywords->strlow_keywords(kwds1);
      keywords->define_keywords(kwds1, modename, 0);
   }

   if (kwds2 != NULL) 
   {
      keywords->sort_keywords(kwds2);
      if (syntax & 0x01) keywords->strlow_keywords(kwds1);
      keywords->define_keywords(kwds2, modename, 1);
   }

   return modeflags;
}

% --------------------------------------------------------------
% Main entry
%
public define custom_mode ()
{
   variable custom_id, modename, modeflags = 2;
   
   if (blocal_var_exists(blvar_modename))
   {
      modename = get_blocal_var(blvar_modename);
   }
   else 
   {
      create_blocal_var(blvar_modename);
      modename = sprintf("%s_%d", custom_syn, custom_count);
      set_blocal_var(modename, blvar_modename);
      custom_count++;
      
      modeflags = prepare_syntax_table(modename);
      create_blocal_var(blvar_modeflgs);
      set_blocal_var(modeflags, blvar_modeflgs);
   }
   
   if (blocal_var_exists(blvar_modeflgs))
      modeflags = get_blocal_var(blvar_modeflgs);
   
   set_mode(modename, modeflags);
   use_syntax_table(modename);
}



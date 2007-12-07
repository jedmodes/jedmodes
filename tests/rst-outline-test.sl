% rst-outline-test.sl:  Test rst-outline.sl
% 
% Copyright (c) 2007 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)

% Usage
% -----
% Place in the jed library path.
%
% Versions
% --------
% 0.1 2007-11-20

require("unittest");


% Fixture
% -------

require("rst-outline");

private variable testbuf = "*bar*";
private variable teststring = "a test line";


static define setup()
{
   sw2buf(testbuf);
   insert(teststring);
}

static define teardown()
{
   sw2buf(testbuf);
   set_buffer_modified_flag(0);
   close_buffer(testbuf);
}

% private namespace: `rst'

% Test functions
% --------------

% static define heading() % ([underline_character]) % as string
static define test_heading()
{
   variable ul_string = string_repeat("+", strlen(teststring));
   
   rst->heading(ul_string[[0]]);
   go_up_1();
   test_equal(ul_string, line_as_string(), 
      "should underline with given character");
   
   insert(ul_string + "\t");
   rst->heading(ul_string[[0]]);
   test_true(eobp(), "should replace existing section markup");
   go_up_1();
   test_equal(ul_string, line_as_string(), 
      "should adapt length of underline");
   
   ul_string = string_repeat("-", strlen(teststring));
   rst->heading(ul_string[[0]]);
   test_true(eobp(), "should replace existing section markup");
   go_up_1();
   test_equal(ul_string, line_as_string(), 
      "should change section markup");
}

   
static define test_heading_replace()
{
   variable ul_string = string_repeat("+", strlen(teststring));
   newline();
   insert(ul_string + " " + ul_string);
   bob();
   rst->heading(ul_string[[0]]);
   go_up_1();
   test_equal(ul_string, line_as_string(), 
      "should insert section markup");
   eob();
   test_equal(ul_string + " " + ul_string, line_as_string(),
      "should keep next line if it is not section markup");
}


static define test_heading_numeric()
{
   variable level, ul_string;
   
   for (level = 1; level < 2; level++)
     {
        ul_string = string_repeat(Rst_Underline_Chars[[level-1]], 
           strlen(teststring));
        rst->heading(level);
        go_up_1();
        test_equal(ul_string, line_as_string(), 
           "should underline with given level, replacing existing markup");
     }
}

  
  
#ifexists list_routines

% static  define extract_heading (nRegexp)
static define test_extract_heading()
{
   variable adornment = string_repeat("+", strlen(teststring));
   % testmessage("\n" + line_as_string);
   insert("\n" + adornment);
   % testmessage("\n" + line_as_string);
   bol();
   test_equal(" + a test line", rst->extract_heading(0),
      "should return section header preceded by adornment character");
}
static define test_extract_heading_subheading()
{
   variable adornment = string_repeat("+", strlen(teststring));
   insert("\n" + adornment);
   % extract first heading and update level-list
   () = rst->extract_heading(0);  
   insert("\n\n\nsubsection");
   insert(  "\n----------");
   bol();
   test_equal("  - subsection", rst->extract_heading(0),
      "should return sub section header");
}

#endif

% TODO: move this to the relevant places as
% check for well formatted heading is now in fsearch_heading()
#iffalse 
static define test_extract_heading_1()
{
   test_equal("", rst->extract_heading(0),
      "should return empty string if not on a section header");
}
static define test_extract_heading_3()
{
   insert("\n------");
   bol();
   test_equal("", rst->extract_heading(0),
      "should return empty string if underline too short");
}
static define test_extract_heading_4()
{
   insert("\n\n\n------");
   bol();
   test_equal("", rst->extract_heading(0),
      "should return empty string if on a transition");
}
static define test_extract_heading_5()
{
   insert("\n\n\n::");
   bol();
   test_equal("", rst->extract_heading(0),
      "should return empty string if on a literal block marker");
}
#endif

#stop
% define is_heading_underline()
static define test_is_heading_underline()
{
   is_heading_underline();
}

% static define has_overline()
static define test_has_overline()
{
   rst->has_overline();
}

% static define section_level(adornment)
static define test_section_level()
{
   rst->section_level();
}

% static define fsearch_heading() % (max_level=100, skip_hidden=0)
static define test_fsearch_heading()
{
   rst->fsearch_heading();
}

% static define bsearch_heading() % (max_level=100, skip_hidden=0)
static define test_bsearch_heading()
{
   rst->bsearch_heading();
}

% define update_adornments()
static define test_update_adornments()
{
   update_adornments();
}

% static define next_heading()  % (max_level=100)
static define test_next_heading()
{
   rst->next_heading();
}

% static define previous_heading() % (max_level=100)
static define test_previous_heading()
{
   rst->previous_heading();
}

% rst->skip_section: library function
% 
%  SYNOPSIS
%   Go to the next heading of same level or above
% 
%  USAGE
%   skip_section()
% 
%  DESCRIPTION
%  Skip content and sub-sections.
% 
%  NOTES
%  Point is placed at bol of next heading or eob
% 
%  SEE ALSO
%   rst_mode; rst->heading
static define test_skip_section()
{
   skip_section();
}

% static define bskip_section()
static define test_bskip_section()
{
   rst->bskip_section();
}

% static define up_section()
static define test_up_section()
{
   rst->up_section();
}

% rst->heading: library function
% 
%  SYNOPSIS
%   Mark up current line as section title
% 
%  USAGE
%   heading([adornment])
% 
%  DESCRIPTION
%  Mark up current line as section title by underlining it.
%  Replace eventually existing underline.
% 
%  If `adornment' is an integer (or a string convertible to an
%  integer),  use the adornment for this section level.
% 
%  Read argument if not given
%    * "canonical" adornments are listed starting with already used ones
%       sorted by level
%    * integer argument level can range from 1 to `no of already defined levels`
% 
%  NOTES
% 
%  SEE ALSO
%   rst_mode, Rst_Underline_Chars
static define test_heading()
{
   heading([adornment]);
}

% static define promote_heading(n)
static define test_promote_heading()
{
   rst->promote_heading();
}

% static define normalize_headings()
static define test_normalize_headings()
{
   rst->normalize_headings();
}

% static define extract_heading(regexp_index)
static define test_extract_heading()
{
   rst->extract_heading();
}

% public  define rst_list_routines_setup(opt)
static define test_rst_list_routines_setup()
{
   rst_list_routines_setup();
}

% static define fold_buffer(max_level)
static define test_fold_buffer()
{
   rst->fold_buffer();
}

% static define fold_section(max_level)
static define test_fold_section()
{
   rst->fold_section();
}

% static define emacs_outline_bindings() % (pre = _Reserved_Key_Prefix)
static define test_emacs_outline_bindings()
{
   rst->emacs_outline_bindings();
}

% static define rst_outline_bindings()
static define test_rst_outline_bindings()
{
   rst->rst_outline_bindings();
}

sw2buf("*test report*");
view_mode();

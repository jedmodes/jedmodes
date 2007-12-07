% test-listing-list.sl:  Test listing-list.sl Test listing.sl
%
% Copyright (c) 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1 2006-03-03

require("unittest");
autoload("get_buffer", "txtutils");

% test availability of public functions (comment to skip)
% test_true(is_defined("listing_mode"), "public fun listing_mode undefined");

require("listing");

% private namespace: `listing'

% fixture
static define setup()
{
   sw2buf("*bar*");
   insert("three\ntest\nlines");
}

static define teardown()
{
   sw2buf("*bar*");
   set_buffer_modified_flag(0);
   close_buffer("*bar*");
}

private define clear_input()
{
   while (input_pending(0))
     {
        () = getkey();
     }
}


% static define null_fun() { }
% null_fun: just return the arguments
static define test_null_fun()
{
   variable result, result2;
   listing->null_fun();
   test_stack();
   result = listing->null_fun(1);
   test_equal(result, 1);
   (result, result2) = listing->null_fun(1, "2");
   test_equal({result, result2}, {1, "2"});
   test_stack();
}

% static define get_confirmation() % (prompt, [default])
%       y: yes,
%       n: no,
%       !: all,
%       q:quit,
% Int  listing->get_confirmation(Str prompt, Str default=""); Ask whether a list of actions should go on
static define test_get_confirmation_yes()
{
   listing->Dont_Ask = 0;
   clear_input();
   ungetkey('y');
   test_equal(1, listing->get_confirmation("Prompt"),
      "key 'y' should result in 1");
   test_equal(listing->Dont_Ask, 0, "key 'y' should not change Dont_Ask");
   clear_input();
}

static define test_get_confirmation_no()
{
   listing->Dont_Ask = 0;
   clear_input();
   ungetkey('n');
   test_equal(0, listing->get_confirmation("Prompt"),
      "key 'n' should result in 0");
   test_equal(listing->Dont_Ask, 0, "key 'n' should not change Dont_Ask");
   clear_input();
}
   
static define test_get_confirmation_with_default()
{
   listing->Dont_Ask = 0;
   clear_input();
   ungetkey('\r');
   test_equal(1, listing->get_confirmation("Prompt", "y"),
      "key Return should use default ('y')");
   ungetkey('\r');
   test_equal(0, listing->get_confirmation("Prompt", "n"),
      "key Return should use default ('n')");
   test_equal(listing->Dont_Ask, 0, "key Return should not change Dont_Ask");
   
   ungetkey('n');
   test_equal(0, listing->get_confirmation("Prompt", "y"),
      "key 'n' should override default 'y'");
   ungetkey('y');
   test_equal(1, listing->get_confirmation("Prompt", "n"),
      "key 'y' should override default 'n'");
   clear_input();
}

static define test_get_confirmation_all()
{
   listing->Dont_Ask = 0;
   clear_input();
   ungetkey('!');
   test_equal(1, listing->get_confirmation("Prompt"),
      "key '!' should result in 1");
   ungetkey('n');
   test_equal(1, listing->get_confirmation("Prompt"),
      "Dont_Ask 1 should ignore key (not wait for it)");
   test_equal('n', getkey(), "Dont_Ask 1 should ignore key");
   clear_input();
}

static define test_get_confirmation_abort()
{
   variable err;
   listing->Dont_Ask = 0;
   clear_input();
   ungetkey('q');
   !if (input_pending(0))
     throw ApplicationError, "there should be a 'q' waiting at input";
   err = test_for_exception("listing->get_confirmation", "Prompt");
   if (err == NULL)
     throw AssertionError, "key 'q' should abort get_confirmation()";
   if (err.error != UserBreakError)
     throw AssertionError, 
     "key 'q' should throw UserBreakError not " + err.descr;
   clear_input();
}

static define test_get_confirmation_wrong_key()
{
   variable err;
   listing->Dont_Ask = 0;
   clear_input();
   buffer_keystring("eeeee"); % five nonaccepted keys
   !if (input_pending(0))
     throw ApplicationError, "there should be waiting input";
   err = test_for_exception("listing->get_confirmation", "Prompt");
   if (err == NULL)
     throw AssertionError, "three wrong keys should abort get_confirmation()";
   if (err.error != UserBreakError)
     throw AssertionError, 
     "three wrong keys should throw UserBreakError not " + err.descr;
   clear_input();
}

% public define listing_mode()
% listing_mode: library function  Undocumented
static define test_listing_mode()
{
   listing_mode();
   test_equal(pop2list(what_mode(),2 ), {"listing", 0});
   test_equal(what_keymap, "listing");
}

% static define tags_length() % (scope=2)
% Int tags_length(scope=2); Return the number of tagged lines.
static define test_tags_length()
{
   listing_mode();
   test_equal(0, listing->tags_length(), "no tagged line");
}

static define test_tags_length_0()
{
   listing_mode();
   test_equal(1, listing->tags_length(0), "one current line");
}
   
static define test_tags_length_1()
{
   listing_mode();
   test_equal(1, listing->tags_length(1), "one current line");
}

static define test_tags_length_2()
{   
   listing_mode();
   test_equal(0, listing->tags_length(2), "no tagged line");
}

% static define line_is_tagged()
% line_is_tagged: Return 0 or (index of tagged line +1)
static define test_line_is_tagged()
{
   listing_mode();
   test_equal(0, listing->line_is_tagged());
}

% static define tag() % (how = 1)
% tag(how = 1); Mark the current line and append to the Tags list
static define test_tag()
{
   listing_mode();
   listing->tag();
   test_stack();
   % now there should be 1 tagged line
   test_equal(1, listing->line_is_tagged(), "current line is tagged");
   test_equal(1, listing->tags_length, "one tagged line");
   % tag a second line
   bob();
   listing->tag();
   test_equal(2, listing->tags_length(), "2 tagged lines");
   test_equal(2, listing->line_is_tagged(), "current line should be second tag");
   % untag current line
   listing->tag(0);
   test_stack();
   test_equal(0, listing->line_is_tagged(), "current line not tagged");
   test_equal(1, listing->tags_length, "one tagged line");
   % toggle current line tag
   listing->tag(2);
   test_equal(2, listing->tags_length(), "2 tagged lines");
}


% static define tag_all() % (how = 1)
% tag_all(how = 1); (Un)Tag all lines
static define test_tag_all()
{
   listing_mode();
   bob();
   listing->tag_all();
   test_stack();
   test_equal(3, listing->tags_length(), "3 tagged lines");
   test_true(bobp(), "tag_all() should not move the point");
   % untag current line
   listing->tag(0);
   test_equal(0, listing->line_is_tagged(), "current line not tagged");
   test_equal(2, listing->tags_length, "should be 2 tagged lines");
   % toggle
   listing->tag_all(2);
   test_equal(1, listing->line_is_tagged(), "current line should be tagged");
   test_equal(1, listing->tags_length, "should be 1 tagged line");
   % untag
   listing->tag_all(0);
   test_equal(0, listing->tags_length(2), "no tagged line");
}


% static define tag_matching() %(how)
% tag_matching: undefined  Undocumented
static define test_tag_matching()
{
   clear_input();
   listing_mode();
   buffer_keystring("th\r"); % simulate keyboard input
   update_sans_update_hook(1);
   listing->tag_matching();
   test_equal(1, listing->tags_length, "should be 1 tagged line");
   
   clear_input();
   buffer_keystring("t\r");
   update_sans_update_hook(1);
   listing->tag_matching();
   test_equal(2, listing->tags_length, "should be 2 tagged lines");
   clear_input();
}


% public  define listing_list_tags() % (scope=2, untag=0)
% scope: 0 current line, 1 tagged or current line(s), 2 tagged lines

% Arr[Str] listing_list_tags(scope=2, untag=0); Return an array of tagged lines.
static define test_listing_list_tags()
{
   listing_mode();
   listing->tag_all();
   test_equal(3, listing->tags_length, "there should be 3 tagged lines");
   test_equal(["three", "test", "lines"], listing_list_tags(),
      "listing_list_tags() should return the tagged lines as String array");
}
static define test_listing_list_tags_0()
{
   listing_mode();
   listing->tag_all();
   !if (_eqs(["lines"], listing_list_tags(0)))
     throw AssertionError,
     "listing_list_tags(0) should return the current line as String array";
   !if (3 == listing->tags_length)
     throw AssertionError, "there should be 3 tagged lines";
}
static define test_listing_list_tags_1_non_tagged()
{
   listing_mode();
   !if (_eqs(["lines"], listing_list_tags(1)))
     throw AssertionError,
     "listing_list_tags(1) should return the tagged lines as String array";
   !if (0 == listing->tags_length)
     throw AssertionError, "there should be no tagged line";
}
static define test_listing_list_tags_1_tagged()
{
   listing_mode();
   listing->tag_all();
   !if (_eqs(["three", "test", "lines"], listing_list_tags(1)))
     throw AssertionError,
     "listing_list_tags(1) should return the tagged lines as String array";
   !if (3 == listing->tags_length)
     throw AssertionError, "there should be 3 tagged lines";
}
static define test_listing_list_tags_2_1()
{
   listing_mode();
   listing->tag_all();
   !if (_eqs(["three", "test", "lines"], listing_list_tags(2, 1)))
     throw AssertionError,
     "listing_list_tags should return the tagged lines as String array";
   !if (0 == listing->tags_length)
     throw AssertionError, "all lines should be untagged";
}
static define test_listing_list_tags_2_2()
{
   listing_mode();
   listing->tag_all();
   !if (_eqs(["three", "test", "lines"], listing_list_tags(2, 2)))
     throw AssertionError,
     "listing_list_tags should return the tagged lines as String array";
   !if (bobp and eobp)
     {
        testmessage("buffer content: '%s'", get_buffer());
        throw AssertionError, "all lines should be deleted";
     }
}


% public  define listing_map() % (scope, fun, [args])
% listing_map(Int scope, Ref fun, Any [args]); Call a function for marked lines.
%
% this is implicitely tested by listing_list_tags()

% static define listing_update_hook()
% listing_update_hook: undefined  Undocumented
%
% this is interactively tested


% static define listing_menu (menu)
% listing_menu: undefined  Undocumented
% static define test_listing_menu()
% {
%    listing_mode();
%    menu_select_menu("Global.M&ode.Tag &All");
%    !if (3 == listing->tags_length)
%      throw AssertionError, "there should be 3 tagged lines";
% }


% static define edit()
% edit: undefined  Undocumented
% test_function("listing->edit");
% test_last_result();

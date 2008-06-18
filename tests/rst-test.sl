% rst-test.sl:  Test rst.sl
%
% Copyright (c) 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1 2006-03-03

require("unittest");

% Customization
% -------------
%
% Set
%   Unittest_Skip_Patterns = [Unittest_Skip_Patterns, "long"];
% to skip long running tests.

% test availability of public functions (comment to skip)
test_true(is_defined("rst_mode"), "public fun rst_mode undefined");

% Fixture
% -------

require("rst");

private variable testfile = make_tmp_file("rst-testfile.txt");
private variable testbuf = path_basename(testfile);
private variable teststring = "a test line";

static define setup()
{
   () = find_file(testfile);
   insert(teststring);
   save_buffer();
}

static define teardown()
{
   sw2buf(testbuf);
   set_buffer_modified_flag(0);
   close_buffer(testbuf);
   test_true(delete_file(testfile), "cleanup failed");
}

% private namespace: `rst'

% Test functions
% --------------

% static define rst_export() % (to, outfile=path_sans_extname(whatbuf())+"."+to)
static define test_rst_export_long()
{
   variable to = "html";
   variable outfile = path_sans_extname(buffer_filename()) + "." + to;

   rst->rst_export(to);

   test_true(delete_file(outfile), "should create output file");
}

% public  define rst_to_html()
static define test_rst_to_html_long()
{
   variable outfile = path_sans_extname(buffer_filename()) + ".html";
   rst_to_html();

   test_true(delete_file(outfile), "should create html output");
}

% public  define rst_to_latex() % (outfile=path_sans_extname(whatbuf())+".tex")
static define test_rst_to_latex_long()
{
   variable outfile = path_sans_extname(buffer_filename()) + ".tex";

   rst_to_latex();

   test_true(delete_file(outfile), "should create latex output");
}

% public  define rst_to_pdf() % (outfile=path_sans_extname(whatbuf())+".pdf")
static define test_rst_to_pdf_long()
{
   variable outfile = path_sans_extname(buffer_filename()) + ".pdf";
   rst_to_pdf();
   test_true(delete_file(outfile), "should create pdf output");
}

% static define command_help(cmd)
static define test_command_help()
{
   rst->command_help("ls foo");
   test_equal(whatbuf(), "*rst export help*", "should open help buffer");
   close_buffer("*rst export help*");
}

% test the dictionary mapping filename extensions to export cmd pointers
static define test_export_cmds()
{
   test_equal(rst->export_cmds["html"] , &Rst2Html_Cmd);
   test_equal(rst->export_cmds["pdf"] , &Rst2Pdf_Cmd);
   test_equal(rst->export_cmds["tex"] , &Rst2Latex_Cmd);
}
% static define set_export_cmd(export_type)
static define test_set_export_cmd()
{
   variable export_type, cmd_p, cmd, addition = " --test";
   
   foreach export_type (["html", "pdf", "tex"]) {
      % get pointer to export cmd custom var
      cmd_p = rst->export_cmds[export_type];
      cmd = @cmd_p;
      % simulate keyboard input (adding `addition` to the default value)
      buffer_keystring(addition + "\r");
      rst->set_export_cmd(export_type);
      
      test_equal(@cmd_p, cmd + addition, 
		 "should be changed by set_export_cmd()");
      @cmd_p = cmd;
   }
}

% public  define rst_view_html() % (browser=Browse_Url_Browser))
% Needs interactive testing.
static define test_rst_view_html_interactive()
{
   rst_view_html();
}

% static define markup(type)
static define test_markup()
{
   rst->markup("strong");
   test_equal("a test **line**", line_as_string(), "should mark up last word");
}

% static define block_markup(type)
static define test_block_markup()
{
   insert("\n   strong");
   rst->block_markup("strong");
   test_equal("**strong**", line_as_string(),
      "should mark up last word and (re) indent");
}

% static define insert_directive(directive_type)
static define test_insert_directive()
{
   rst->insert_directive("test");
   test_equal(".. test:: ", line_as_string(),
      "should insert directive on a line on its own");
}

% static define new_popup(menu, popup)
static define test_new_popup()
{
   variable popup = rst->new_popup("Global", "test");
   test_equal("Global.test", popup, "should return identifier of popup");
   menu_delete_item(popup);
}

% static define rst_menu(menu)
static define test_rst_menu()
{
   % simple test for errors while executing,
   % TODO: test of functionality
   variable popup = "Global.test";
   menu_append_popup("Global", "test");
   rst->rst_menu(popup);
   menu_delete_item(popup);
}

% public define rst_mode()
static define test_rst_mode()
{
   % simple test for errors while executing,
   % TODO: test of functionality
   rst_mode();
}

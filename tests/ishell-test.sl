% Test ishell.sl
% ishell.sl: Interactive shell mode (based on ashell.sl by J. E. Davis)

% Copyright (c) 2007 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)

% Versions
% --------
% 0.2 2007-11-30  * merge with template from testscript wizard
%     		  * test log buffer

% currently, this tests function calls for errors but does only a partial
% test of advertised functionality

require("unittest");

% test availability of public functions (comment to skip)
test_true(is_defined("ishell_mode"), "public fun ishell_mode undefined");
test_true(is_defined("ishell"), "public fun ishell undefined");
test_true(is_defined("terminal"), "public fun terminal undefined");
test_true(is_defined("shell_command"), "public fun shell_command undefined");
test_true(is_defined("shell_cmd_on_region_or_buffer"), "public fun shell_cmd_on_region_or_buffer undefined");
test_true(is_defined("shell_cmd_on_region"), "public fun shell_cmd_on_region undefined");
test_true(is_defined("filter_region"), "public fun filter_region undefined");

% Fixture
% -------

require("ishell");

% custom_variable("Ishell_default_output_placement", ">");
% custom_variable("Ishell_logout_string", ""); % default is Ctrl-D
% custom_variable("Ishell_Max_Popup_Size", 10);
% custom_variable("Shell_Default_Shell", getenv ("COMSPEC"));
% custom_variable("Ishell_Default_Shell", Shell_Default_Shell);
% custom_variable("Shell_Default_Shell", getenv ("SHELL"));
% custom_variable("Ishell_Default_Shell", Shell_Default_Shell+" -i");

private variable cmd = "echo 'hello world'";
private variable testbuf = "*bar*";
private variable teststring = "a test line\n";

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

% Test functions
% --------------

% ishell_mode(cmd=Ishell_Default_Shell); Open a process and attach it to the current buffer.
% test_function("ishell_mode");
static define test_ishell_mode()
{
   ishell_mode(); % attach a shell to the buffer
   % test the attached shell
   % 
   % to test the proper working, we would need a way to synchronize the
   % assynchron working (i.e. wait for a response from the command.)
   % 
   % Maybe input_pending() can be (ab)used in conjunction with an output handler
   % pushing a string back on the input-stream (ungetkey()). (Maybe a special
   % blocal "Ishell_output_filter"?)
   
   usleep(2000);  % wait for the startup
   insert("pwd");
   ishell_send_input();
   usleep(1000);  % wait for the result
   % logout
   ishell_logout();
   usleep(1000);  % wait for the result
}


static define test_ishell()
{
   ishell(); % Interactive shell

   if (whatbuf() != "*ishell*")
     throw AssertionError, "  not in *ishell* buffer";

   % % logout
   % ishell_logout();
   % usleep(1000);  % wait for the result
   % close
   set_buffer_modified_flag(0);
   delbuf("*ishell*");
}

% terminal(cmd = Ishell_Default_Shell); Run a command in a terminal
static define test_terminal()
{
   % terminal();       % doesnot close!
   terminal("logout");
}


% shell_command(cmd="", output_handling=0); Run a shell command
static define test_shell_command_0()
{
   shell_command(cmd, 0); % output to "*shell-output*"
   test_equal(get_buffer(), "hello world\n");
   test_equal(whatbuf(), "*shell-output*");
   close_buffer("*shell-output*");
}

static define test_shell_command_named_buffer()
{
   shell_command(cmd, "*foo*"); % output to buffer "*foo*"
   test_equal(get_buffer(), "hello world\n");
   test_equal(whatbuf(), "*foo*");
   close_buffer("*foo*");
}

static define test_shell_command_1() % insert at point
{
   shell_command(cmd, 1); 
   test_equal(get_buffer(), teststring+"hello world\n");
}

static define test_shell_command_2() % replace region/buffer at point
{
   shell_command(cmd, 2); 
   test_equal(get_buffer(), "hello world\n");
}

static define test_shell_command_3() % return output
{
   test_equal("hello world\n", shell_command(cmd, 3));
}

static define test_shell_command_4() % message output
{
   shell_command(cmd, 4);
   test_equal("hello world\n", MESSAGE_BUFFER);
}

static define test_shell_command_ignore()
{
   shell_command(cmd, -1); % ignore output
}

static define test_shell_command_no_output()
{
   variable modename1, modename2;
   (modename1, ) = what_mode();
   if (bufferp("*shell-output*"))
     {
        sw2buf("*shell-output*");
        set_buffer_modified_flag(0);
        close_buffer();
     }
   shell_command(" "); % null-command -> no output
   test_equal(whatbuf(), testbuf, "output buffer should close if empty");
   (modename2, ) = what_mode();
   test_equal(modename1, modename2, "must not change modename");
}

% shell_cmd_on_region_or_buffer: library function  Undocumented
static define test_shell_cmd_on_region_or_buffer()
{
   push_visible_mark();
   bob();
   test_equal(shell_cmd_on_region_or_buffer("cat", 3), teststring);
}

  
% shell_cmd_on_region(cmd="", output_handling=0, postfile_args=""); Save region to a temp file and run a command on it
static define test_shell_cmd_on_region()
{
   test_equal(shell_cmd_on_region("cat", 3), teststring);
}


% filter_region(cmd=NULL); Filter the region through a shell command
static define test_filter_region()
{
   filter_region("wc");
   bob(); push_mark();
   fsearch("/tmp");
   test_equal(bufsubstr(), " 1  3 12 ",
	     "filter_region output differs from expected value");
}

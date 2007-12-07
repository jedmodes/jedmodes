% Test ishell.sl

% currently, this tests function calls for errors but does only a partial
% test of advertised functionality

% ishell.sl: Interactive shell mode (based on ashell.sl by J. E. Davis)

% custom_variable("Ishell_default_output_placement", ">");
% custom_variable("Ishell_logout_string", ""); % default is Ctrl-D
% custom_variable("Ishell_Max_Popup_Size", 10);
% custom_variable("Shell_Default_Shell", getenv ("COMSPEC"));
% custom_variable("Ishell_Default_Shell", Shell_Default_Shell);
% custom_variable("Shell_Default_Shell", getenv ("SHELL"));
% custom_variable("Ishell_Default_Shell", Shell_Default_Shell+" -i");

require("unittest");

% Fixture
% -------

autoload("Global->ishell_send_input", "ishell");
autoload("Global->ishell_logout", "ishell");
autoload("get_buffer", "txtutils");

private variable cmd = "echo 'hello world'";
private variable testbuf = "*bar*";
% the setting of ADD_NEWLINE has influence of the return value of
% functions saving the buffer (e.g. using bufsubstring()) and processing the
% resulting file
private variable add_newline_before = ADD_NEWLINE;

static define mode_setup()
{
   ADD_NEWLINE = 0;
}

static define mode_teardown()
{
   ADD_NEWLINE = add_newline_before;
}

static define setup()
{
   popup_buffer(testbuf);
   insert("bar bar");
}

static define teardown()
{
   sw2buf(testbuf);
   set_buffer_modified_flag(0);
   close_buffer(testbuf);
}

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
   terminal("exit");
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
   test_equal(get_buffer(), "bar barhello world\n");
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
   test_equal(shell_cmd_on_region_or_buffer("cat", 3), "bar bar");
}

% shell_cmd_on_region(cmd="", output_handling=0, postfile_args=""); Save region to a temp file and run a command on it
static define test_shell_cmd_on_region()
{
   test_equal(shell_cmd_on_region("cat", 3), "bar bar");
}

% filter_region(cmd=NULL); Filter the region through a shell command
static define test_filter_region()
{
   filter_region("wc");
   % the filename part of the output differs as we use a tmp file
   test_equal(get_buffer()[[0:4]], "0 2 7",
      "filter_region output differs from expected value");
}

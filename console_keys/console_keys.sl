% console_keys.sl: make shift-arrow etc. work under linux-console
%
% Copyright (c) 2005 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1 2006-02-02  proof of concept (works for me)
%
% USAGE
% -----
%
% put in your in jed.rc something like
%
%   #ifndef XWINDOWS IBMPC_SYSTEM
%   autoload("set_console_keys", "console_keys");
%   if (getenv("DISPLAY") == NULL and BATCH == 0)
%      set_console_keys();
%   #endif
%
% `loadkeys` permissions
% ----------------------
%
% On some systems (e.g. SuSE), loadkeys requires superuser privileges.
%
% In the current state, console_keys.sl doesnot provide a workaround. There is
% an earlier version that comes with a suid wrapper script `kjed` but the IMO
% cleaner approach would be to grant selected users the right to change the
% keymap.
%
% In any case, on such systems console_keys.sl will fail if you do not have
% access to  the "root" account.
%
% Drawbacks
% ---------
%
% console_keys.sl changes the keysyms for all virtual konsoles, which
% might break other programs
%
% Workaraound: console_keys saves you previous settings
%              (with dumpkeys) and loads them after finishing jed
%              However, while jed is running, shifted movement keys behave
%              differently from the standard.
% Idea:        Trap the konsole-switching keys as well and write a function
%              that resets the keys and switches the console (as well as
%              loads the console_keys after coming back with a _before_key_hook

% Directory for temporary files
custom_variable("Jed_Temp_Dir", getenv("TEMP"));
if (Jed_Temp_Dir == NULL)
  Jed_Temp_Dir = getenv("TMP");
if (Jed_Temp_Dir == NULL)
  Jed_Temp_Dir = "/tmp";

static variable keymap_cache =
  make_tmp_file(path_concat(Jed_Temp_Dir, "console_keys_"));

% restore the keymap to previous state
define restore_console_keys()
{
   variable cmd, status;

   % load the saved keymap
   cmd = "loadkeys " + keymap_cache;
   status = system(cmd);
   if (status)
     verror("%s returned %d, %s", cmd, status, errno_string(status));
   return 1;
}

% save the current keymap and set the special keymap
define set_console_keys()
{
   variable cmd, status,
     keymap = expand_jedlib_file("console_keys.map");

   if (keymap == NULL)
     verror("console_keys.map not found on '%s'", get_jed_library_path);

   % save the current keymap
   cmd = "dumpkeys > " + keymap_cache;
   status = system(cmd);
   if (status)
     verror("%s returned %d, %s", cmd, status, errno_string(status));

   % load the special keymap
   cmd = "loadkeys " + keymap;
   status = system(cmd);
   if (status)
     verror("%s returned %d, %s", cmd, status, errno_string(status));

   add_to_hook("_jed_exit_hooks", &restore_console_keys);
}


% -------------------------------------------- -*- mode:SLang; mode:folding -*-
%
% TREE-MODE FOR JED
%	$Id: tree.sl,v 1.1.1.1 2004/10/28 08:16:27 milde Exp $
%
% --------------------------------------------------------------------- %{{{
%
% DESCRIPTION
%	--- TODO ---
%	    See the documentation included for the function 'tree'.
%	--- TODO ---
%
% USAGE
%	Simply add this line somewhere in your startup file (.jedrc or jed.rc):
%
%		() = evalfile ("tree");
%
%	and press "M-X tree". Additionally, add the line
%
%		setkey ("tree", "^XT");
%
%	to bind 'tree' to "Ctrl-X T" (quite useful in emacs mode). Once the
%	'tree' file has been evaluated, you can customize some variables to
%	change its behavior.
%
% VARIABLES
%			Default
%	Name		 value 	Description
%	--------------- ------- ----------------------------------------------
%	ASK_USER	   0	If 1, ask the user where to begin.
%				Otherwise, use the current working directory.
%	AUTO_HIDE	   0	If 1, hide tree on node view, edit, etc ..
%				('dired' always hide tree).
%	CASE_SENSITIVE	   1	If 1, PATTERN_EXCLUDE and PATTERN_MATCH
%				wild-cards are case-sensitive.
%	DEPTH		   3	Max deep if DEPTH_LIMIT is 1.
%	DEPTH_LIMIT	   1	If 1, the depth of the tree will be limited.
%	DFA_SYNTAX	   0	If 1, a very simple syntax highlighting scheme
%				will be used if JED was compiled with DFA
%				syntax highlighting support.
%				WARNING: This is an experimental feature, use
%					 with caution.
%	INDENT		   3	Number of indentation spaces.
%	INSTALL_MENU	   1	If 1, a menu will be installed.
%	PADDING		   1	If 1, an extra line will be drawn between
%				certain nodes.
%	PATTERN_EXCLUDE	  ""	Exclude files that match this wild-card.
%       PATTERN_FOLD	  ""	Fold nodes matching this regular expression.
%	PATTERN_MATCH	  ""	List only files that match this wild-card.
%	SHOW_FILES	   1	If 0, show only directories.
%	SHOW_HIDDEN	   0	If 1, show also hidden files (.*).
%	GROUP_FILES 	   0	If -1, files will be shown firts,
%				if  0, files won't be shown grouped,
%				if  1, files will be shown last.
%				A value different than 0 affects directly on
%				performance. Use it with care.
%	USE_TREE	   0	If 1, use the external program 'tree' to
%				see the forest. Otherwise, use the slang
%				version (function 'tree_tree', see below).
%				WARNING: THIS OPTION IS CURRENTLY BROKEN,
%				SO DON'T CHANGE THIS VALUE.
%
%	The syntax
%
%		Tree->VARIABLE_NAME = <value>;
%
%	must be used to assign them a value.
%
% EXAMPLES
%	Here is an example:
%
%		() = evalfile ("tree");
%		Tree->AUTO_HIDE = 1;
%		Tree->PATTERN_EXCLUDE = "*~";
%		Tree->PATTERN_FOLD = "cvs";
%
% PLATFORM
%	Mainly tested under Linux 2.2.x, jed-B0.99.11 and slang-1.4.1.
%	It should work fine under any unix system.
%	The author will be very glad to see this program working
%	under VMS, DOS, Win*, OS/2, BeOS, ...
%
% TODO
%	- Make PATTERN_{EXCLUDE,FOLD,MATCH} a _list_ of wild-cards.
%
%	- Add 'dircolors' support (/etc/DIRCOLORS, ~/.dircolors).
%
%	- Tree and file operations: copy, move, rename, delete files,
%	  delete trees (recursively delete files and directories), etc.
%
%	- Use an external 'tree' program to generate trees.
%
%	- Improve documentation (volunteers?).
%
% BUGS
%	None known (yet). Needs to be tested under non unix systems.
%
% AUTHOR
%	Francesc Rocher (f.rocher@computer.org)
%	Feel free to send comments, suggestions or improvements
%
% --------------------------------------------------------------------- %}}}

% DEBUG ONLY
%_traceback = 1;
%_debug_info = 1;

implements ("Tree");

% VARIABLES                                                             %{{{

% Uppercase variables control tree-mode behavior.
% These are user-configurable (.jedrc: Tree->VARIABLE_NAME = <value>;)
static variable
   ASK_USER        = 0,
   AUTO_HIDE       = 0,
   CASE_SENSITIVE  = 1,
   DEPTH           = 3,
   DEPTH_LIMIT     = 1,
   DFA_SYNTAX      = 0,
   GROUP_FILES     = 0,
   INDENT          = 3,
   INSTALL_MENU    = 1,
   PADDING         = 1,
   PATTERN_EXCLUDE = "",  % exclude files matching this wild-card
   PATTERN_FOLD    = "",  % fold nodes matching this pattern
   PATTERN_MATCH   = "",  % show files matching this wild-card
   SHOW_FILES      = 1,
   SHOW_HIDDEN     = 0;

private variable
   USE_TREE          = 0,   % use external 'tree' (USELESS, DON'T CHANGE)
   tree_cwd          = "",  % current working directory (root)
   tree_indent       = "",  % indentation string
   tree_depth,              % depth of the current tree
   tree_depth_closed = 0,
   tree_exc_wc       = "",  % exclusion: wild-card
   tree_exc_re       = "",  % exclusion: regular expresion
   tree_fld_re       = "",  % folding: regular expression
   tree_mat_wc       = "",  % matching: wild-card
   tree_mat_re       = "",  % matching: regular expresion
   tree_msg          = "-,+,L:depth   ..:parent /:new root   toggle:[d]irs [h]idden [a]ll   H:more help",
   tree_st           = " TREE MODE | - -- ---- | press '?' for help | %p,%c  %t",
   tree_angle_char   = '`',
   tree_angle_str    = "`",
   tree_angle_       = tree_angle_str + "--",
   tree_regexp       = "[\\|" + tree_angle_str + "]\\-\\- .*/$",
   tree_root         = "";

%}}}

% FUNCTION PROTOTYPES                                                   %{{{

autoload ("dired_quick_help", "dired");
autoload ("dired_read_dir",   "dired");
autoload ("scrnhelp",         "scrnhelp");
autoload ("scrnhelp_quit",    "scrnhelp");
% (disabled) autoload ("mcrypt_insert_file", "mcrypt");

% Static functions -------------------
static  define tree_child          ();

% ALL these functions are assigned to a key on 'tree-mode'
% Public functions ------------------- DEFAULT BINDING
public  define tree                (); %  Ctrl-X t
public  define tree_child_first    (); %  f
public  define tree_child_last     (); %  l
public  define tree_child_next     (); %  c
public  define tree_child_prev     (); %  C
public  define tree_depth_close    (); %  Ctrl-C Ctrl-W
public  define tree_depth_decr     (); %  -
public  define tree_depth_incr     (); %  +
public  define tree_depth_limit    (); %  L
public  define tree_depth_open     (); %  Ctrl-C Ctrl-O
public  define tree_depth_set      (); %  1, 2, ..., 9
public  define tree_group_files    (); %  g, G, u
public  define tree_help           (); %  H
public  define tree_help_line      (); %  ?
public  define tree_move_down      (); %  DOWN
public  define tree_move_left      (); %  LEFT
public  define tree_move_right     (); %  RIGHT
public  define tree_move_up        (); %  UP
public  define tree_node_close     (); %  Ctrl-C Ctrl-X
public  define tree_node_dired     (); %  D
public  define tree_node_edit      (); %  e
public  define tree_node_eval      (); %  S
public  define tree_node_next      (); %  n
public  define tree_node_open      (); %  Ctrl-C Ctrl-S
public  define tree_node_open_with (); %  o
public  define tree_node_prev      (); %  N
public  define tree_node_show      (); %  Return
public  define tree_node_show_path (); %  =
public  define tree_node_view      (); %  v
public  define tree_node_view_pipe (); %  V
public  define tree_parent         (); %  p
public  define tree_parent_show    (); %  ..
public  define tree_point          (); %  Ctrl-I
public  define tree_quit           (); %  q
public  define tree_quit_help      (); %  H
public  define tree_read_exclude   (); %  x
public  define tree_read_folding   (); %  F
public  define tree_read_match     (); %  m
public  define tree_read_root      (); %  /
public  define tree_refresh        (); %  r
public  define tree_sort           ();
public  define tree_switch_dired   (); %  Ctrl-X d
public  define tree_toggle_all     (); %  a
public  define tree_toggle_case    (); %  s
public  define tree_toggle_dirs    (); %  d
public  define tree_toggle_hidden  (); %  h
public  define tree_toggle_padding (); %  P

% Private functions -------------------
private define tree_close_matching  ();
private define tree_cmd_subst       ();
private define tree_dir_next        ();
private define tree_dir_prev        ();
private define tree_menu            ();
private define tree_node_depth      ();
private define tree_node_name       ();
private define tree_node_path       ();
private define tree_padding_next    ();
private define tree_padding_prev    ();
private define tree_re_search       ();
private define tree_show            ();
private define tree_status          ();
private define tree_status_line     ();
private define tree_this_node_close ();
private define tree_tree            ();
private define tree_tree_cmd        ();
private define tree_wc2regexp       ();

%}}}

% STATIC FUNCTIONS ------------------------------------------------------------
static  define tree_child ()                                            %{{{
{
   % Returns 1 if the current line has a child (not a 'padding' line),
   % 0 otherwise.
   variable m = create_user_mark (), r = 1;

   eol ();
   () = left (4);
   if (looking_at ("   |"))
      r = 0;

   goto_user_mark (m);
   return r;
}

%}}}

% PUBLIC FUNCTIONS ------------------------------------------------------------
%
% INCOMPLETE DOCUMENTATION FOR TREE
%!%+
%\function{tree}
%\synopsis{tree}
%\description
% Tree is a directory listing utility with which you can browse your file
% system. It displays a tree view of the contents of the current working
% directory and, recursively, its subdirectories. Links are printed in the
% format "link -> real-path", and broken links in the format "link ~> path".
%
%                   (TO BE CONTINUED)
%
%!%-
public  define tree                ()                                   %{{{
{
   % Tree mode. Bind it to 'Ctrl-X t', for example, in the global keymap

   $0 = "tree_map";
   !if (keymap_p ($0))
     {
        make_keymap ($0);
        definekey ("() = tree_child_first", "f",    $0);
        definekey ("() = tree_child_last",  "l",    $0);
        definekey ("() = tree_child_next",  "c",    $0);
        definekey ("() = tree_child_prev",  "C",    $0);
        definekey ("tree_depth_close",      "", $0);
        definekey ("tree_depth_decr",       "-",    $0);
        definekey ("tree_depth_incr",       "+",    $0);
        definekey ("tree_depth_limit",      "L",    $0);
        definekey ("tree_depth_open",       "", $0);
        definekey ("tree_depth_set (1)",    "1",    $0);
        definekey ("tree_depth_set (2)",    "2",    $0);
        definekey ("tree_depth_set (3)",    "3",    $0);
        definekey ("tree_depth_set (4)",    "4",    $0);
        definekey ("tree_depth_set (5)",    "5",    $0);
        definekey ("tree_depth_set (6)",    "6",    $0);
        definekey ("tree_depth_set (7)",    "7",    $0);
        definekey ("tree_depth_set (8)",    "8",    $0);
        definekey ("tree_depth_set (9)",    "9",    $0);
        definekey ("describe_mode",         "M",    $0);
        definekey ("tree_group_files (-1)", "g",    $0);
        definekey ("tree_group_files (0)",  "u",    $0);
        definekey ("tree_group_files (1)",  "G",    $0);
        definekey ("tree_help",             "H",    $0);
        definekey ("tree_help_line",        "?",    $0);
        definekey ("tree_move_down",        "[B", $0);
        definekey ("tree_move_left",        "[D", $0);
        definekey ("tree_move_right",       "[C", $0);
        definekey ("tree_move_up",          "[A", $0);
        definekey ("tree_node_close",       "", $0);
        definekey ("tree_node_dired",       "D",    $0);
        definekey ("tree_node_edit",        "e",    $0);
        definekey ("tree_node_eval",        "S",    $0);
        definekey ("tree_node_next",        "n",    $0);
        definekey ("tree_node_open",        "", $0);
        definekey ("tree_node_open_with",   "o",    $0);
        definekey ("tree_node_prev",        "N",    $0);
        definekey ("tree_node_show",        "",   $0);
        definekey ("tree_node_show_path",   "=",    $0);
        definekey ("tree_node_view",        "v",    $0);
        definekey ("tree_node_view_pipe",   "V",    $0);
        definekey ("tree_parent",           "p",    $0);
        definekey ("tree_parent_show",      "..",   $0);
        definekey ("tree_point",            "^I",   $0);
        definekey ("tree_quit",             "q",    $0);
        definekey ("tree_read_exclude",     "x",    $0);
        definekey ("tree_read_folding",     "F",    $0);
        definekey ("tree_read_match",       "m",    $0);
        definekey ("tree_read_root",        "/",    $0);
        definekey ("tree_refresh",          "r",    $0);
        definekey ("tree_switch_dired",     "d",  $0);
        definekey ("tree_toggle_all",       "a",    $0);
        definekey ("tree_toggle_case",      "s",    $0);
        definekey ("tree_toggle_dirs",      "d",    $0);
        definekey ("tree_toggle_hidden",    "h",    $0);
        definekey ("tree_toggle_padding",   "P",    $0);
     }

   sw2buf ("*tree*");

   _for (0, 6, 1)
      tree_status ();
   tree_status_line (7);

   use_keymap ("tree_map");

   if (tree_indent == "" and INDENT)
      loop (INDENT)
         tree_indent += " ";

   set_mode ("tree", 0);

#ifdef HAS_DFA_SYNTAX
if (DFA_SYNTAX)
{
   $0 = "tree";
   create_syntax_table ($0);
   define_highlight_rule(" [^\\|`]* \\-\\> .*$", "Qcomment", $0);
   define_highlight_rule(" [^\\|`]* \\~\\> .*$", "Qerror", $0);
   define_highlight_rule(" [^\\|`]*/$", "Qkeyword", $0);
   define_highlight_rule(" [^\\|`]*\\*$", "Qkeyword1", $0);
   define_highlight_rule("^[^ ].*$", "Qstring", $0);
   build_highlight_table ($0);
   use_syntax_table ("tree");
}
#endif

   if (INSTALL_MENU)
      mode_set_mode_info ("tree", "init_mode_menu", &tree_menu);

   %set_buffer_hook ("update_hook", &tree_point);

   if (tree_cwd == "")
      tree_cwd = getcwd ();

   run_mode_hooks ("tree_hook");

   if (tree_exc_re != PATTERN_EXCLUDE)	% Has 'PATTERN_EXCLUDE' been set?
      tree_read_exclude (PATTERN_EXCLUDE);
   if (tree_mat_re != PATTERN_MATCH)	% Has 'PATTERN_MATCH' been set?
      tree_read_match (PATTERN_MATCH);
   if (tree_fld_re != PATTERN_FOLD)	% Has 'PATTERN_FOLD' been set?
      tree_read_folding (PATTERN_FOLD);

   if (ASK_USER)
      tree_read_root ();
   else
      tree_show (tree_cwd);
}

%}}}
public  define tree_child_first    ()                                   %{{{
{
   % Go to the first child of the current node.
   % Returns 1 if it exists, 0 otherwise.
   variable col;
   variable m = create_user_mark ();
   variable r = 0;

   if ((what_line () == 1))
     {
        r = down (1);
        tree_point ();
     }
   else
     {
        tree_point ();
        col = what_column ();
        () = down (PADDING + 1);
        if (andelse
           {col == goto_column_best_try (col)}
              {not is_line_hidden ()}
              {orelse
                   {looking_at ("|--")}
                   {looking_at (tree_angle_)} })
          {
             () = right (4);
             r = 1;
          }
     }

   !if (r)
      goto_user_mark (m);

   return r;
}

%}}}
public  define tree_child_last     ()                                   %{{{
{
   % Go to the last child of the current node, if it exists.
   % Returns 1 if it exists, 0 otherwise.
   variable col;
   variable m = create_user_mark ();
   variable r = 0;

   if (what_line () == 1)
      goto_column (INDENT+1);
   else
      tree_point ();

   col = what_column ();
   () = down (1);
   () = goto_column_best_try (col);
   %call ("next_line_cmd");

   !if (is_line_hidden ())
     {
        while (what_char () == '|')
          {
             %call ("next_line_cmd");
             () = down (1);
             goto_column (col);
          }
        if (looking_at (tree_angle_))
          {
             () = right (4);
             r = 1;
          }
     }

   !if (r)
      goto_user_mark (m);
   return r;
}

%}}}
public  define tree_child_next     ()                                   %{{{
{
   % Go to the next child of the parent of the current node
   % (i.e., go to the next brother).
   % Returns 1 if it exists, 0 otherwise.
   variable col;
   variable m = create_user_mark ();
   variable r = 0;

   if ((what_line () > 1) and (tree_child ()))
     {
        tree_point ();
        () = left (4);
        if (what_char () == tree_angle_char)
           goto_user_mark (m);
        else
          {
             r = 1;
             col = what_column () + 1;
             do
               {
                  () = down (1);
                  goto_column (col);
               }
             while (not (looking_at ("--")));
             () = right (3);
          }
     }

   return r;
}

%}}}
public  define tree_child_prev     ()                                   %{{{
{
   % Go to the previous child of the parent of the current node
   % (i.e., go to the previous brother).
   % Return 1 if it exists, 0 otherwise.
   variable m = create_user_mark ();
   variable col, n;

   if ((what_line () > 2) and (tree_child ()))
     {
        tree_point ();
        () = left (4);
        col = what_column ();
        () = up (1);
        goto_column (col);
        if (what_char () != '|')
           goto_user_mark (m);
        else
          {
             while (not (looking_at ("|--")))
               {
                  n = up (1);
                  if ((n == 0) or (goto_column_best_try (col) != col))
                    {
                       goto_user_mark (m);
                       return 0;
                    }
               }
             () = right (4);
          }
     }

   return 1;
}

%}}}
public  define tree_depth_close    ()                                   %{{{
{
   % Close (fold) all subtrees at the same depth that the current node.
   variable depth;
   variable m;

   if (_NARGS)
      depth = ();
   else
      depth = tree_node_depth ();
   tree_depth_closed = depth;
   tree_point ();
   m = create_user_mark ();
   bob ();
   while (tree_dir_next ())
      if (tree_node_depth () == depth)
         tree_node_close ();

   goto_user_mark (m);
}

%}}}
public  define tree_depth_decr     ()                                   %{{{
{
   % Decrements the current depth.
   if (andelse
      {DEPTH_LIMIT}
         {DEPTH > 1})
     {
        DEPTH--;
        tree_status_line (1);
        tree_show (tree_cwd);
     }
}

%}}}
public  define tree_depth_incr     ()                                   %{{{
{
   % Increments the current depth
   if (DEPTH_LIMIT)
     {
        DEPTH++;
        tree_status_line (1);
        tree_show (tree_cwd);
     }
}

%}}}
public  define tree_depth_limit    ()                                   %{{{
{
   % (un)toggle tree limited depth
   DEPTH_LIMIT = not (DEPTH_LIMIT);
   tree_status_line (1);
   tree_show (tree_cwd);
}

%}}}
public  define tree_depth_open     ()                                   %{{{
{
   % Open (unfold) all subtrees at the same depth that the current node.
   variable depth = tree_node_depth ();
   variable m;

   tree_depth_closed = 0;
   tree_point ();
   m = create_user_mark ();
   bob ();

   while (tree_dir_next ())
      if (tree_node_depth () == depth)
         tree_node_open ();

   goto_user_mark (m);
   tree_close_matching ();
}

%}}}
public  define tree_depth_set      ()                                   %{{{
{
   % Sets the current depth to '()' (the first value on the stack)
   if (DEPTH_LIMIT)
     {
        DEPTH = ();
        tree_status_line (1);
        tree_show (tree_cwd);
     }
}

%}}}
public  define tree_group_files    (where)                              %{{{
{
   GROUP_FILES = where;
   tree_refresh ();
   tree_status_line (0);
}

%}}}
public  define tree_help           ()                                   %{{{
{
   % Show a help screen.
   scrnhelp ("*tree*", "*tree help*", "tree.hlp", 12);
}

%}}}
public  define tree_help_line      ()                                   %{{{
{
   % Obviously ..
   flush (tree_msg);
}

%}}}
public  define tree_move_down      ()                                   %{{{
{
   call ("next_line_cmd");
   while (not (tree_child ()))
         call ("next_line_cmd");
   tree_point ();
}

%}}}
public  define tree_move_left      ()                                   %{{{
{
   call ("previous_char_cmd");
   if (looking_at_char (' '))
     {
        () = left (3);
        if (orelse
            {looking_at ("|--")}
              {looking_at (tree_angle_)})
          {
             tree_move_up ();
             eol ();
          }
        else
           () = right (3);

     }
}

%}}}
public  define tree_move_right     ()                                   %{{{
{
   call ("next_char_cmd");
   if (bolp ())
     {
        () = up (1);
        tree_move_down ();
     }
}

%}}}
public  define tree_move_up        ()                                   %{{{
{
   call ("previous_line_cmd");
   while (not (tree_child ()))
      call ("previous_line_cmd");
   tree_point ();
}

%}}}
public  define tree_node_close     ()                                   %{{{
{
   % Close (fold) a subtree.
   % The cursor can be at the node or at any of its sub-nodes.
   variable m = create_user_mark ();
   variable b = 0;

   !if (tree_this_node_close ())
     {
        tree_parent ();
        !if (tree_this_node_close ())
          {
             goto_user_mark (m);
             return;
          }
     }
}

%}}}
public  define tree_node_dired     ()                                   %{{{
{
   % Show current node in 'dired' mode.
   dired_read_dir (tree_node_path);
   dired_quick_help ();
   runhooks ("dired_hook");
}

%}}}
public  define tree_node_edit      ()                                   %{{{
{
   % Edit current node.
   variable file = tree_node_path ();
   variable st = stat_file (file);

   tree_quit_help ();

   if (andelse
      {st != NULL}
         {stat_is ("reg", st.st_mode)}
         {read_file (file)})
     {
        pop2buf (whatbuf ());
        if (AUTO_HIDE)
           onewindow ();
     }
   else
      error ("Unable to edit file '"+file+"'.");
}

%}}}
public  define tree_node_eval      ()                                   %{{{
{
   () = evalfile (tree_node_path ());
}

%}}}
public  define tree_node_next      ()                                   %{{{
{
   % Go to the next node.
   if (tree_re_search (tree_regexp, 'f'))
      () = right (4);
}

%}}}
public  define tree_node_open      ()                                   %{{{
{
   % Open (unfold) a subtree.
   variable m = create_user_mark (), n, b;

   tree_point ();
   push_mark ();
   skip_hidden_lines_forward (1);
   set_region_hidden (0);
   pop_mark (1);
   goto_user_mark (m);
   () = tree_child_last ();
   n = what_line ();
   tree_parent ();
   () = tree_child_first ();
   b = fsearch (PATTERN_FOLD);
   while ((what_line () < n) and (b))
     {
        if (b)
           () = tree_this_node_close ();
        () = down (1);
        b = fsearch (PATTERN_FOLD);
     }
   goto_user_mark (m);
   %tree_close_matching ();
}

%}}}
public  define tree_node_open_with ()                                   %{{{
{
   % Open the current node with an external program.
   %
   % Before issuing the command, few replacements are made on the
   % string entered by the user:
   %
   %    $f  Absolute path + filename
   %    $p  Absolute path of the current node, NOT ended with '/'
   %    $n  Filename (name + extension)
   %    $b  Basename of filename (without extension)
   %    $e  Extension (the last one found, without the dot)
   %
   % In order to avoid these substitutions to be made, use '$$' in place of '$'.
   % For instance, '$$f' would be read as '$f', while '$f' would be replaced by
   % the filename.
   %
   variable cmd;

   cmd = read_mini ("Command <fpnbe>:", "", "");
   if (string_match (cmd, "\\$", 1))
     {
        variable tnp = tree_node_path (), n, e;
        cmd = tree_cmd_subst (cmd, "$f", tnp);
        cmd = tree_cmd_subst (cmd, "$p", path_dirname (tnp));
        cmd = tree_cmd_subst (cmd, "$n", path_basename (tnp));
        (n, ) = strreplace (path_basename (tnp), path_extname (tnp), "", 1);
        cmd = tree_cmd_subst (cmd, "$b", n);
        (e, ) = strreplace (path_extname (tnp), ".", "", 1);
        cmd = tree_cmd_subst (cmd, "$e", e);
     }
   (cmd, ) = strreplace (cmd, "$$", "$", strlen (cmd));
   e = system (cmd + " >/dev/null 2>&1 &");
   if (orelse
         {e == 127}
         {e == -1})
      verror ("Error %d on command '%s'", e, cmd);
   else
      vmessage ("Command return %d.", e);
}

%}}}
public  define tree_node_prev      ()                                   %{{{
{
   % Go to the previous node.
   variable l = what_line ();

   if (l == 2)
     {
        () = up (1);
        bol ();
     }
   if (l > 2 and tree_re_search (tree_regexp, 'b'))
      %() = right (4);
      tree_point ();
}

%}}}
public  define tree_node_show      ()                                   %{{{
{
   % Show the tree with the current node as root.
   push_spot ();
   eol (); left (1);
   if (what_char () == '/')
     {
        pop ();
        tree_show (tree_node_path () + "/");
     }
   else
      pop_spot ();
}

%}}}
public  define tree_node_show_path ()                                   %{{{
{
   % Flush the absolute path name of the current node
   flush (tree_node_path ());
}

%}}}
public  define tree_node_view      ()                                   %{{{
{
   % Show the current node in 'most' mode.
   variable file, st;

   tree_quit_help ();
   file = tree_node_path ();
   st = stat_file (file);

   if (andelse
      {st != NULL}
         {stat_is ("reg", st.st_mode)}
         {read_file (file)})
     {
        pop2buf (whatbuf ());
        if (AUTO_HIDE)
           onewindow ();
        most_mode ();
     }
   else
      error ("Unable to view file '"+file+"'.");
}

%}}}
public  define tree_node_view_pipe ()                                   %{{{
{
   % Show the current node through a pipe.
   variable i, m;
   variable file = tree_node_path ();
   variable tree_pipe, tree_pipe_last;

   !if (__is_initialized (&tree_pipe_last))
     {
        tree_pipe_last = 54;
        tree_pipe = String_Type[tree_pipe_last + 1, 5];
        %
        % All this stuff could be added into JED in a much more
        % general manner. For example, it could be useful to
        % preview dvi files in LaTeX mode, ps, pdf files, etc.
        % This is a first approach.
        %
        % The order of the wild-cards in the next table is VERY important.
        % Generic wild-cards MUST appear later: for example "*.gz" must appear
        % after "*.tar.gz", "*.ps.gz", etc.
        % These wild-cards are NOT case sensitive.
        %  -----------------------------------------------------------
        %  'MOD' values: 'b' View results in a buffer
        %                'f' Use a function and view results in a buffer
        %                'X' Use an external program, usually under X
        %
        %                                             COMMANDS
        %                   MOD   WILD-CARDS   -----------------------
        %                   ---  ------------  pre  command       post
        tree_pipe[ 0,*] = [ "b", "*.tar",      "C", "tar tvvf",   ""  ];
        tree_pipe[ 1,*] = [ "b", "*.t[ag]z",   "C", "tar tzvvf",  ""  ];
        tree_pipe[ 2,*] = [ "b", "*.tar.gz",   "C", "tar tzvvf",  ""  ];
        tree_pipe[ 3,*] = [ "b", "*.tar.z",    "C", "tar tzvvf",  ""  ];
        tree_pipe[ 4,*] = [ "b", "*.tar.bz2",  "C", "tar tIvvf",  ""  ];
        tree_pipe[ 5,*] = [ "b", "*.bz2",      "",  "bzip2 -dc",  ""  ];
        tree_pipe[ 6,*] = [ "b", "*.zip",      "",  "unzip -l",   ""  ];
        tree_pipe[ 7,*] = [ "b", "*.rpm",      "r", "rpm -qRp",   "r" ];
        tree_pipe[ 8,*] = [ "b", "*.jar",      "C", "jar tvf",    ""  ];
        tree_pipe[ 9,*] = [ "f", "*.[1-9nlpo]","m",  "unix_man",  ""  ];
        tree_pipe[10,*] = [ "f", "*.[1-9][tTxX]","m", "unix_man", ""  ];
        tree_pipe[11,*] = [ "b", "*.man",      "m",  "unix_man",  ""  ];
        tree_pipe[12,*] = [ "b", "*.ms",       "",  "groff -Tascii -ms", "" ];
        % Image formats ...
        tree_pipe[13,*] = [ "X", "*.bmp",      "",  "xv",         ""  ];
        tree_pipe[14,*] = [ "X", "*.gif",      "",  "xv",         ""  ];
        tree_pipe[15,*] = [ "X", "*.jpg",      "",  "xv",         ""  ];
        tree_pipe[16,*] = [ "X", "*.jpeg",     "",  "xv",         ""  ];
        tree_pipe[17,*] = [ "X", "*.pbm",      "",  "xv",         ""  ];
        tree_pipe[18,*] = [ "X", "*.pcx",      "",  "xv",         ""  ];
        tree_pipe[19,*] = [ "X", "*.pgm",      "",  "xv",         ""  ];
        tree_pipe[20,*] = [ "X", "*.pm",       "",  "xv",         ""  ];
        tree_pipe[21,*] = [ "X", "*.pnm",      "",  "xv",         ""  ];
        tree_pipe[22,*] = [ "X", "*.png",      "",  "xv",         ""  ];
        tree_pipe[23,*] = [ "X", "*.ppm",      "",  "xv",         ""  ];
        tree_pipe[24,*] = [ "X", "*.tga",      "",  "xv",         ""  ];
        tree_pipe[25,*] = [ "X", "*.tif",      "",  "xv",         ""  ];
        tree_pipe[26,*] = [ "X", "*.tiff",     "",  "xv",         ""  ];
        tree_pipe[27,*] = [ "X", "*.xbm",      "",  "xv",         ""  ];
        tree_pipe[28,*] = [ "X", "*.xpm",      "",  "xv",         ""  ];
        tree_pipe[29,*] = [ "X", "*.xwd",      "",  "xwud -in ",  ""  ];
        tree_pipe[30,*] = [ "X", "*.xcf",      "",  "gimp --no-splash --no-splash-image --no-data > /dev/null 2>&1", "" ];
        % ... any more?
        % Movie formats ...
        tree_pipe[31,*] = [ "X", "*.avi",      "",  "xanim +q",   ""  ];
        tree_pipe[32,*] = [ "X", "*.mpg",      "",  "xanim +q",   ""  ];
        tree_pipe[33,*] = [ "X", "*.mpeg",     "",  "xanim +q",   ""  ];
        tree_pipe[34,*] = [ "X", "*.rp",       "",  "realplay",   ""  ];
        tree_pipe[35,*] = [ "X", "*.qt",       "",  "xanim +q",   ""  ];
        % ... any more?
        tree_pipe[36,*] = [ "X", "*.lyx",      "",  "klyx",       ""  ];
        tree_pipe[37,*] = [ "X", "*.fig",      "",  "xfig",       ""  ];
        tree_pipe[38,*] = [ "X", "*.dvi",      "",  "xdvi",       ""  ];
        tree_pipe[39,*] = [ "X", "*.ps",       "",  "gv",         ""  ];
        tree_pipe[40,*] = [ "X", "*.ps.gz",    "",  "gv",         ""  ];
        tree_pipe[41,*] = [ "X", "*.ps.z",     "",  "gv",         ""  ];
        tree_pipe[42,*] = [ "X", "*.eps",      "",  "gv",         ""  ];
        tree_pipe[43,*] = [ "X", "*.eps.gz",   "",  "gv",         ""  ];
        tree_pipe[44,*] = [ "X", "*.eps.z",    "",  "gv",         ""  ];
        tree_pipe[45,*] = [ "X", "*.pdf",      "",  "acroread",   ""  ];
        tree_pipe[46,*] = [ "X", "*.pdf.gz",   "",  "acroread",   ""  ];
        tree_pipe[47,*] = [ "X", "*.pdf.z",    "",  "acroread",   ""  ];
        tree_pipe[48,*] = [ "b", "*.htm",      "",  "lynx -dump", ""  ];
        tree_pipe[49,*] = [ "b", "*.html",     "",  "lynx -dump", ""  ];
        tree_pipe[50,*] = [ "b", "*.htm.gz",   "",  "lynx -dump", ""  ];
        tree_pipe[51,*] = [ "b", "*.html.gz",  "",  "lynx -dump", ""  ];
        tree_pipe[52,*] = [ "b", "*.gz",       "",  "gzip -dc",   ""  ];
        tree_pipe[53,*] = [ "b", "*.z",        "",  "gzip -dc",   ""  ];
        tree_pipe[54,*] = [ "b", "*.uue",      "",  "uudecode -o /dev/stdout", "" ];
        % (disabled) tree_pipe[??,*] = [ "f", "*.enc",      "",  "mcrypt_insert_file", "" ];

        _for (0, tree_pipe_last, 1)
          {
             i = ();
             tree_pipe[i,1] = tree_wc2regexp (tree_pipe[i,1], 0);
          }
     }

   _for (0, tree_pipe_last, 1)
     {
        i = ();
        m = string_match (file, tree_pipe[i,1], 1);
        if (m)
           break;
     }

   !if (m)
      return;

   if (orelse
      {tree_pipe[i,0] == "b"}
         {tree_pipe[i,0] == "f"})
     {
        tree_quit_help ();
        pop2buf ("*tree-pipe*");
        if (AUTO_HIDE)
           onewindow ();
     }

   flush ("Processing file "+file+" ...");

   % --- Pre-process --------------------------------------------
   switch (tree_pipe[i,2])
     {
       case "C": vinsert ("Contents of %s\n\n", file);
     }
     {
       case "r":
        insert ("===================\n");
        insert (" DESCRIPTION\n");
        insert ("===================\n");
        () = run_shell_cmd ("rpm -qip "+file+" 2>/dev/null");
        insert ("\n===================\n");
        insert (" REQUIRED PACKAGES\n");
        insert ("===================\n");
     }
     {
       case "m": delbuf ("*tree-pipe*");
     }

   % --- Command ------------------------------------------------
   switch (tree_pipe[i,0])
     {
       case "b": % Send output to buffer
        () = run_shell_cmd (tree_pipe[i,3]+" "+file+" 2> /dev/null");
     }
     {
       case "f": % Use a function
        eval (sprintf ("%s(\"%s\");",tree_pipe[i,3],file));
     }
     {
       case "X": % Use an external program
        () = system (tree_pipe[i,3]+" "+file+" 2> /dev/null &");
     }

   % --- Post-process -------------------------------------------
   switch (tree_pipe[i,4])
     {
       case "r":
        insert ("\n===================\n");
        insert (" CONTENTS\n");
        insert ("===================\n");
        () = run_shell_cmd ("rpm -qlp "+file+" 2>/dev/null");
     }

   % --- Finally ------------------------------------------------
   if (orelse
      {tree_pipe[i,0] == "b"}
         {tree_pipe[i,0] == "f"})
     {
        bob ();
        set_buffer_modified_flag (0);
        set_readonly (1);
        most_mode ();
     }
   flush ("Processing file "+file+" ... done");
}

%}}}
public  define tree_parent         ()                                   %{{{
{
   % Go to the parent of the current node.
   variable col;

   if (what_line () > 1)
     {
        tree_point ();
        () = left (4);
        col = what_column ();
        do
          {
             call ("previous_line_cmd");
             %() = up (1);
             %goto_column (col);
          }
        while (what_char () == '|');
        if (what_line () == 1)
           bol ();
     }
}

%}}}
public  define tree_parent_show    ()                                   %{{{
{
   % Show the tree with the parent of the current root as root.
   variable root;
   variable offset;

   !if (tree_cwd == "/")
     {
        offset = string_match (tree_cwd, "/[^/]*/$", 1);
        root = substr (tree_cwd, 1, offset);
        tree_show (root);
     }
}

%}}}
public  define tree_point          ()                                   %{{{
{
   % Moves the point to the first character of the node in the current line.
   bol ();
   skip_chars ("- |" + tree_angle_str);
}

%}}}
public  define tree_quit           ()                                   %{{{
{
   % Bye ..
   tree_quit_help ();
   delbuf ("*tree*");
}

%}}}
public  define tree_quit_help      ()                                   %{{{
{
   scrnhelp_quit ("*tree help*");
}

%}}}
public  define tree_read_exclude   ()                                   %{{{
{
   % Read a list of wild-cards. Matching filenames won't be shown.
   if (_NARGS)
      tree_exc_wc = ();
   else
     {
        % variable ok = 0;
        % while (not ok) {  %% Check valid wild-cards?
        tree_exc_wc = read_mini ("Exclude files:", "", tree_exc_wc);
        % ok = string_math (exclude, ".*(\[.*\])*.*", 0);
        %  }
     }

   !if (USE_TREE)
     {
        if (tree_exc_wc == "")
           tree_exc_re = "";
        else
           tree_exc_re = tree_wc2regexp (tree_exc_wc, 1);
     }

   if (tree_exc_re != PATTERN_EXCLUDE)
     {
        PATTERN_EXCLUDE = tree_exc_re;
        tree_status_line (5);
        !if (_NARGS)
           tree_show (tree_cwd);
     }
}

%}}}
public  define tree_read_folding   ()                                   %{{{
{
   % Reads a pattern. Matching nodes will be folded (closed).
   if (_NARGS)
      tree_fld_re = ();
   else
      tree_fld_re = read_mini ("Fold matching:", "", tree_fld_re);

   PATTERN_FOLD = tree_fld_re;
   tree_status_line (4);

   !if (_NARGS)
      tree_close_matching ();
}

%}}}
public  define tree_read_match     ()                                   %{{{
{
   % Read a wild-card. Only matching filenames will be shown.
   if (_NARGS)
      tree_mat_wc = ();
   else
     {
        % {
        % variable ok = 0;
        % while (not ok) {  %% Check valid wild-cards?
        tree_mat_wc = read_mini ("Pattern:", "", tree_mat_wc);
        % ok = string_match (match, ".*(\[.*\])*.*", 0);
        % }
     }

   !if (USE_TREE)
     {
        if (tree_mat_wc == "")
           tree_mat_re = "";
        else
           tree_mat_re = tree_wc2regexp (tree_mat_wc, 1);
     }

   if (tree_mat_re != PATTERN_MATCH)
     {
        PATTERN_MATCH = tree_mat_re;
        tree_status_line (6);
        !if (_NARGS)
           tree_show (tree_cwd);
     }
}

%}}}
public  define tree_read_root      ()                                   %{{{
{
   % Reads a new root and show the tree.
   variable n, st;
   variable root, tree_error = 1;

   root = read_with_completion ("Root directory:", "", "", 'f');

   if (strlen (root))
     {
        if (root[strlen (root)] != '/')
           root += "/";
        n = string_match (root, "//+$", 1);
        if (n)
           root = substr (root, 1, n);
     }

   st = stat_file (root);

   if (st != NULL)
     {
        if (stat_is ("dir", st.st_mode))
          {
             tree_error = 0;
             tree_show (root);
          }
        if (stat_is ("lnk", st.st_mode))
          {
             st = lstat_file (root);
             if (st != NULL)
                if (stat_is ("dir", st.st_mode))
                  {
                     tree_error = 0;
                     tree_show (root);
                  }
          }
     }

   if (tree_error)
      error ("Cannot open directory '"+root+"'");
}

%}}}
public  define tree_refresh        ()                                   %{{{
{
   tree_show (tree_cwd);
}

%}}}
public  define tree_sort           (a, b)                               %{{{
{
   $0 = lstat_file (tree_root + a);
   $1 = lstat_file (tree_root + b);

   if (andelse
         {stat_is ("dir", $0.st_mode)}
         {stat_is ("dir", $1.st_mode)})
      return (strcmp (a,b));
   if (stat_is ("dir", $0.st_mode))
      return -GROUP_FILES;
   if (stat_is ("dir", $1.st_mode))
      return GROUP_FILES;
   return (strcmp (a,b));
}

%}}}
public  define tree_switch_dired   ()                                   %{{{
{
   % Show current root in 'dired' mode.
   dired_read_dir (tree_cwd);
   dired_quick_help ();
   runhooks ("dired_hook");
}

%}}}
public  define tree_toggle_all     ()                                   %{{{
{
   % Show/Hide normal and hidden files.
   if (orelse
      {SHOW_FILES == 0}
         {SHOW_HIDDEN == 0})
     {
        SHOW_FILES = 1;
        SHOW_HIDDEN = 1;
        tree_status (2);
        tree_status_line (3);
        tree_show (tree_cwd);
     }
}

%}}}
public  define tree_toggle_case    ()                                   %{{{
{
   % Toggle wild-cards (exclude, match) case-sensitivity.
   CASE_SENSITIVE = not (CASE_SENSITIVE);

   if (PATTERN_EXCLUDE != "")
      tree_exc_re = tree_wc2regexp (tree_exc_wc, 1);

   if (PATTERN_MATCH != "")
      tree_mat_re = tree_wc2regexp (tree_mat_wc, 1);

   tree_status_line (7);

   if (orelse
      {PATTERN_EXCLUDE != ""}
         {PATTERN_MATCH != ""})
      tree_show (tree_cwd);
}

%}}}
public  define tree_toggle_dirs    ()                                   %{{{
{
   % Show/Hide normal files.
   SHOW_FILES = not (SHOW_FILES);
   tree_status_line (2);
   tree_show (tree_cwd);
}

%}}}
public  define tree_toggle_hidden  ()                                   %{{{
{
   % Show/Hide hidden files.
   SHOW_HIDDEN = not (SHOW_HIDDEN);
   tree_status_line (3);
   tree_show (tree_cwd);
}

%}}}
public  define tree_toggle_padding ()                                   %{{{
{
   % This function is only used as a key-binding
   PADDING = not (PADDING);
   tree_show (tree_cwd);
   if (tree_depth_closed)
      tree_depth_close (tree_depth_closed);
   tree_close_matching ();
}

%}}}

% PRIVATE FUNCTIONS -----------------------------------------------------------
private define tree_close_matching ()                                   %{{{
{
   % Fold nodes matching PATTERN_FOLD. Usually called after tree_show.
   variable m = create_user_mark (), d = 1;

   bob ();
   while (d and fsearch (PATTERN_FOLD))
     {
        () = tree_this_node_close ();
        d = down (1);
     }

   goto_user_mark (m);
}

%}}}
private define tree_cmd_subst      (cmd, pat, str)                      %{{{
{
   $0 = "^\\" + pat;
   if (string_match (cmd, $0, 1))
     {
        ($1, $2) = string_match_nth (0);
        cmd = substr (cmd, 1, $1) + str + substr (cmd, $1+$2+1, -1);
     }
   $0 = "[^\$]\\" + pat;
   while (string_match (cmd, $0, 1))
     {
        ($1, $2) = string_match_nth (0);
        cmd = substr (cmd, 1, $1+1) + str + substr (cmd, $1+$2+1, -1);
     }
   return cmd;
}

%}}}
private define tree_dir_next       ()                                   %{{{
{
   % Go to the next tree (i.e., the next directory).
   % Returns 1 if it exists, 0 otherwise.
   if (tree_re_search (tree_regexp, 'f'))
     {
        () = right (4);
        return 1;
     }
   else
      return 0;
}

%}}}
private define tree_dir_prev       ()                                   %{{{
{
   % Go to the previous tree (i.e., the previous directory).
   % Returns 1 if it exists, 0 otherwise.
   if (tree_re_search (tree_regexp, 'b'))
     {
        () = right (4);
        return 1;
     }
   else
      return 0;
}

%}}}
private define tree_menu           (menu)                               %{{{
{
   menu_append_item (menu, "P&arent", "tree_parent");
   menu_append_item (menu, "&First child", "() = tree_child_first");
   menu_append_item (menu, "&Prev child", "() = tree_child_prev");
   menu_append_item (menu, "&Next child", "() = tree_child_next");
   menu_append_item (menu, "&Last child", "() = tree_child_last");
   menu_append_separator (menu);
   menu_append_popup (menu, "N&ode");
   $0 = menu + ".N&ode";
     {
        menu_append_item ($0, "&Prev", "tree_node_prev");
        menu_append_item ($0, "&Next", "tree_node_next");
        menu_append_separator ($0);
        menu_append_item ($0, "&Enter", "tree_node_show");
        menu_append_item ($0, "&Up", "tree_parent_show");
        menu_append_item ($0, "&Go to", "tree_read_root");
        menu_append_separator ($0);
        menu_append_item ($0, "&Fold", "tree_node_open");
        menu_append_item ($0, "Unf&old", "tree_node_close");
        menu_append_item ($0, "E&dit", "tree_node_edit");
        menu_append_item ($0, "D&ired", "tree_node_dired");
        menu_append_item ($0, "Sho&w path", "tree_node_show_path");
        menu_append_separator ($0);
        menu_append_item ($0, "&View", "tree_node_view");
        menu_append_item ($0, "E&xtern view", "tree_node_view_pipe");
        menu_append_item ($0, "Open wi&th", "tree_node_open_with");
        menu_append_item ($0, "&SLang eval", "tree_node_eval");
     }
   menu_append_popup (menu, "&Match");
   $0 = menu + ".&Match";
     {
        menu_append_item ($0, "&List", "tree_read_match");
        menu_append_item ($0, "&Exclude", "tree_read_exclude");
        menu_append_item ($0, "&Fold", "tree_read_folding");
        menu_append_separator ($0);
        menu_append_item ($0, "&Case (in)sensitive", "tree_toggle_case");
     }
   menu_append_popup (menu, "&Depth");
   $0 = menu + ".&Depth";
     {
        menu_append_item ($0, "&Incr", "tree_depth_incr");
        menu_append_item ($0, "&Decr", "tree_depth_decr");
        menu_append_item ($0, "&Fold", "tree_depth_close");
        menu_append_item ($0, "Unf&old", "tree_depth_open");
        menu_append_item ($0, "(Un)&limited", "tree_depth_limit");
        menu_append_popup ($0, "&Set to");
        $0 += ".&Set to";
          {
             menu_append_item ($0, "&1", "tree_depth_set (1)");
             menu_append_item ($0, "&2", "tree_depth_set (2)");
             menu_append_item ($0, "&3", "tree_depth_set (3)");
             menu_append_item ($0, "&4", "tree_depth_set (4)");
             menu_append_item ($0, "&5", "tree_depth_set (5)");
             menu_append_item ($0, "&6", "tree_depth_set (6)");
             menu_append_item ($0, "&7", "tree_depth_set (7)");
             menu_append_item ($0, "&8", "tree_depth_set (8)");
             menu_append_item ($0, "&9", "tree_depth_set (9)");
          }
     }
%   menu_append_separator (menu);
   menu_append_popup (menu, "&Toggle");
   $0 = menu + ".&Toggle";
     {
        menu_append_item ($0, "&All", "tree_toggle_all");
        menu_append_item ($0, "&Directories", "tree_toggle_dirs");
        menu_append_item ($0, "&Hidden files", "tree_toggle_hidden");
        menu_append_separator ($0);
        menu_append_item ($0, "&Padding", "tree_toggle_padding");
     }
   menu_append_popup (menu, "&Group files");
   $0 = menu + ".&Group files";
     {
        menu_append_item ($0, "&Files firts", "tree_group_files (-1)");
        menu_append_item ($0, "Files &last", "tree_group_files (1)");
        menu_append_item ($0, "&UN-grouped", "tree_group_files (0)");
     }
   menu_append_separator (menu);
   menu_append_item (menu, "D&ired mode", "tree_switch_dired");
   menu_append_item (menu, "&Refresh", "tree_refresh");
   menu_append_separator (menu);
   menu_append_item (menu, "Quic&k help", "tree_help_line");
   menu_append_item (menu, "&Help", "tree_help");
   menu_append_separator (menu);
   menu_append_item (menu, "&Quit", "tree_quit");
}

%}}}
private define tree_node_depth     ()                                   %{{{
{
   % Computes the depth of the current node
   tree_point ();
   return (what_column () - INDENT) / 4;
}

%}}}
private define tree_node_name      ()                                   %{{{
{
   % Returns the name of the current node
   variable name;
   variable n;

   if (what_line () == 1)
      return substr (tree_cwd, 1, strlen (tree_cwd) - 1);

   tree_point ();
   push_mark ();
   eol ();
   name = str_delete_chars (bufsubstr (),"/\\*\\|=");
   pop_mark (1);
   %  tree_point ();
   n = string_match (name, " -> .*", 1);

   if (n)
      name = substr (name, 1, n-1);

   return name;
}

%}}}
private define tree_node_path      ()                                   %{{{
{
   % Returns the absolute pathname of the current node
   variable depth = tree_node_depth ();
   variable m = create_user_mark ();
   variable path = tree_node_name ();

   while (what_line () != 1)
     {
        tree_parent ();
        path = tree_node_name () + "/" + path;
     }

   goto_user_mark (m);
   return path;
}

%}}}
private define tree_padding_next   ()                                   %{{{
{
   % Returns 1 if the next line is a 'padding' one (ends with '|')
   variable r = 0;
   variable m = create_user_mark ();

   () = down (1);
   eol ();
   () = left (1);
   r = looking_at_char ('|');
   goto_user_mark (m);

   return (r);
}

%}}}
private define tree_padding_prev   ()                                   %{{{
{
   % Returns 1 if the previous line is a 'padding' one (ends with '|')
   variable r = 0;
   variable m = create_user_mark ();

   () = up (1);
   eol ();
   () = left (1);
   r = looking_at_char ('|');
   goto_user_mark (m);

   return r;
}

%}}}
private define tree_re_search      (re, fb)                             %{{{
{
   % Search a regexp in the current tree, where 're' is a regular expression
   % and 'fb' is a character that indicates the direction to search
   % ('f' forward, 'b' backward). If a matching string is found, then move
   % the point to that string and return 1. Return 0 otherwise.
   variable m = create_user_mark ();
   variable line = what_line ();
   variable r = 0;

   if (re != "")
     {
        if (fb == 'f')
          {
             r = re_fsearch (re);
             while (andelse
                    {is_line_hidden ()}
                    {line != what_line ()})
               {
                  skip_hidden_lines_forward (1);
                  r = re_fsearch (re);
                  line = what_line ();
               }
          }
      else
          {
             r = re_bsearch (re);
             while (andelse
                   {is_line_hidden ()}
                      {line != what_line ()})
               {
                  skip_hidden_lines_backward (1);
                  r = re_bsearch (re);
                  line = what_line ();
               }
          }
     }
   if (is_line_hidden ())
      r = 0;

   !if (r)
      goto_user_mark (m);
   else
      r = 1;

   return r;
}

%}}}
private define tree_show           (root)                               %{{{
{
   % Show the tree with 'root' as root.
   variable tree_node;

   flush ("Getting tree " + root + " ... ");

   % Save current node
   bol ();
   push_mark ();
   eol ();
   tree_node = bufsubstr ();
   pop_mark (0);

   % Buffer status
   set_readonly (0);
   erase_buffer ();

   % Which command?
   if (USE_TREE)       % external 'tree'
      tree_tree_cmd (root);
   else                % slang 'tree'
     {
        variable dir_num, file_num, total;
        tree_depth = 0;
        vinsert ("%s\n", root);
        if (PADDING)
           vinsert ("%s|\n", tree_indent);
        (dir_num, file_num) = tree_tree (root, 1, tree_indent);
        total = sprintf ("depth %d: %d director", tree_depth, dir_num);
        if (dir_num == 1)
           total += "y";
        else
           total += "ies";
        if (SHOW_FILES) {
           total += sprintf (", %d file", file_num);
           if (file_num > 1)
              total += "s";
        }
        eob ();
        () = up (1); eol (); del ();
        bob ();
        eol ();
        vinsert ("   [%s]", total);
     }

   % Buffer status
   set_buffer_modified_flag (0);
   set_readonly (1);

   % Fold nodes matching PATTERN_FOLD
   tree_close_matching ();

   % Search 'tree_node'
   bob ();
   if (bol_fsearch (tree_node))
      tree_point ();
   else
      tree_node_next ();
   tree_cwd = root;
   flush ("Getting tree "+root+" ... done");
}

%}}}
private define tree_status         (f)                                  %{{{
{
   % Makes the status line of tree mode.
   % It looks like:
   %
   %                   111111111122222222223
   %          123456789012345678901234567890
   %         :_________:X_X_XX_XXXX
   % -%%----- TREE MODE - - -- ---- | press '?' for help | %p,%c  %t
   %                    | | || ||||
   %                    0 1 23 4567 --> fileds, specific information
   %
   % Information shown:
   %
   %  f pos.  Description
   %  - ----  ----------------------------------------------------------------
   %  0 (11)  Group files (see GROUP_FILES): '<' for files first,
   %                                         '|' for UN-grouped,
   %                                         '>' for files last.
   %
   %  1 (13)  Depth: a digit, or 'U' if it is unlimited.
   %
   %  2 (15)  Dirs: 'D' if only directories are shown, '-' otherwise.
   %  3 (16)  Hidden: 'H' if hidden files are shown, '-' otherwise.
   %
   %  4 (18)  Folding: 'F' if a folding pattern has been set, '-' oterwhise.
   %  5 (19)  Exclude: 'X' if an 'exclusion' wild-card has been set,
   %          '-' otherwise.
   %  6 (20)  Match: 'M' if a 'match' wild-card has been set, '-' otherwise.
   %  7 (21)  Case-sensitivity: 'S' if 'match' or 'exclude' (or both) wild-card
   %          is set and it is/they are case-sensitive, '-' otherwise.
   %
   % -------------------------------------------------------------------------
   switch (f)
     {
       case 0: % (11) GROUP
        if (GROUP_FILES < 0)
           tree_st = tree_st[[:10]] + "<" + tree_st[[12:]];
        if (GROUP_FILES == 0)
           tree_st = tree_st[[:10]] + "|" + tree_st[[12:]];
        if (GROUP_FILES > 0)
           tree_st = tree_st[[:10]] + ">" + tree_st[[12:]];
     }
     {
       case 1: % (13) DEPHT
        if (DEPTH_LIMIT)
          {
             if (DEPTH < 10)
                tree_st = tree_st[[:11]] + " " + string (DEPTH) + tree_st[[14:]];
             else
                tree_st = tree_st[[:11]] + string (DEPTH) + tree_st[[14:]];
          }
        else
           tree_st = tree_st[[:11]] + " U" + tree_st[[14:]];
     }
     {
       case 2: % (15) DIRS
        !if (SHOW_FILES)
           tree_st = tree_st[[:14]] + "D" + tree_st[[16:]];
        else
           tree_st = tree_st[[:14]] + "-" + tree_st[[16:]];
     }
     {
       case 3: % (16) HIDDEN
        if (SHOW_HIDDEN)
           tree_st = tree_st[[:15]] + "H" + tree_st[[17:]];
        else
           tree_st = tree_st[[:15]] + "-" + tree_st[[17:]];
     }
     {
       case 4: % (18) FOLDING
        if (PATTERN_FOLD != "")
           tree_st = tree_st[[:17]] + "F" + tree_st[[19:]];
        else
           tree_st = tree_st[[:17]] + "-" + tree_st[[19:]];
     }
     {
       case 5: % (19) EXCLUDE
        if (PATTERN_EXCLUDE != "")
           tree_st = tree_st[[:18]] + "X" + tree_st[[20:]];
        else
           tree_st = tree_st[[:18]] + "-" + tree_st[[20:]];
     }
     {
       case 6: % (20) MATCH
        if (PATTERN_MATCH != "")
           tree_st = tree_st[[:19]] + "M" + tree_st[[21:]];
        else
           tree_st = tree_st[[:19]] + "-" + tree_st[[21:]];
     }
     {
       case 7: % (21) CASE-SENTITIVE
        if (CASE_SENSITIVE)
           tree_st = tree_st[[:20]] + "S" + tree_st[[22:]];
        else
           tree_st = tree_st[[:20]] + "-" + tree_st[[22:]];
     }
}

%}}}
private define tree_status_line    (f)                                  %{{{
{
   % Updates the status line of tree mode.
   tree_status (f);
   set_status_line (tree_st, 0);
}

%}}}
private define tree_this_node_close ()                                  %{{{
{
   variable m;

   if (andelse
      {what_line () > 1}
         {tree_child_first ()})
     {
        () = up (PADDING);
        bol ();
        push_mark ();
        () = up (1);
        tree_point ();
        m = create_user_mark ();
        if (tree_child_next ())
           () = up (1 + PADDING);
        else
           while (tree_child_last ());
        eol ();
        set_region_hidden (1);
        pop_mark (0);
        goto_user_mark (m);
        return 1;
     }
   else
      return 0;
}

%}}}
private define tree_tree           (root, depth, instr)                 %{{{
{
   %
   % SLang version of 'tree'. Slightly incomplete, less options than 'tree',
   % runs slower that 'tree' ... but works better than 'tree'   =8)
   % Needs some changes to work under non unix platforms (VMS, Win*, OS/2, ..).
   %
   % Parameters:
   %    'root'  root directory of the tree.
   %    'depth' maximum depth of the tree.
   %    'instr' indentation string to print before each node.
   %
   % Returns:
   %    the number of directories and files shown.
   %
   % TODO:
   %    code optimization.
   variable dir_num = 0, file_num = 0;
   variable node = String_Type[], Idx = Integer_Type[];
   variable total, last, i, idx, st;
   variable b, n;

   %
   % PRELIMINARIES .................................................... %{{{
   %
   node = listdir (root);

   if (node == NULL)
      return (0,0);

   total = length (node) - 1;
   if (GROUP_FILES)
     {
        tree_root = root;
        Idx = array_sort (node, "tree_sort");
     }
   else
      Idx = array_sort (node);

   if (tree_depth < depth)
      tree_depth = depth;

   %}}}
   %
   % PART I: DISCARDING NODES ......................................... %{{{
   %
   last = -1;

   _for (0, total, 1)
     {
        idx = ();
        i = Idx[idx];

        % 1. Discard hidden files and directories if not SHOW_HIDDEN
        if (andelse
           {node[i][0] == '.'}
              {not SHOW_HIDDEN})
          {
             Idx[idx] = -1; % This is the way in which nodes
             continue;      % are (drastically) discarded    =8)
          }
        st = lstat_file (root+node[i]);
        if (st == NULL)
          {
             % Some files cannot be read (uid, gid).
             Idx[idx] = -1;
             continue;
          }

        % 2. Discarding directories
        if (stat_is ("dir", st.st_mode))
          {
             % Non hidden directories are always shown.
             dir_num++;
             last = i;
             continue;
          }

        % 3. Discarding normal files
        % 3.1 Discard normal files if not SHOW_FILES,
        %     except links pointing to directories.
        if (stat_is ("lnk", st.st_mode))
          {
             st = stat_file (root+node[i]);
             if (andelse
                {st != NULL}
                   {stat_is ("dir", st.st_mode)})
               {
                  % Link to a directory
                  dir_num++;
                  last = i;
                  continue;
               }
          }
        !if (SHOW_FILES)
          {
             Idx[idx] = -1;
             continue;
          }

        % 3.2 Discard files that don't match PATTERN_MATCH
        if (andelse
           {tree_mat_re != ""}
              {not string_match (node[i], tree_mat_re, 1)})
          {
             Idx[idx] = -1;
             continue;
          }

        % 3.3 Discard files that match PATTERN_EXCLUDE
        if (andelse
           {tree_exc_re != ""}
              {string_match (node[i], tree_exc_re, 1)})
          {
             Idx[idx] = -1;
             continue;
          }
        file_num++; % Number of files shown
        last = i;   % At least the last node is 'i'
     }

   %}}}
   %
   % PART II: PROCESSING NODES......................................... %{{{
   %
   if (last == -1)
      return (0,0);

   _for (0, total, 1)
     {
        idx = ();
        i = Idx[idx];
        if (i == -1)
           continue;

        % 4. Print indentation
        insert (instr);
        if (i == last)
           vinsert ("%s ", tree_angle_);
        else
           insert ("|-- ");
        insert (node[i]);
        st = lstat_file (root + node[i]);

        if (st == NULL)
           continue;

        % 5. Processing directories
        if (stat_is ("dir", st.st_mode))
          {
             % Padding depends only on directories:
             %
             %   .
             %   .
             %   |-- a_file
             %   |                       <-- Padding before directory node
             %   |-- directory/
             %   |   |                   <-- Padding entries
             %   |   |-- another_file
             %   |   |-- another_one
             %   |   `-- last_file
             %   |                       <-- Padding after directory node
             %   |-- another_file
             %   .
             %   .

             % Padding before directory node
             if (PADDING)
               {
                  !if (tree_padding_prev ())
                    {
                       bol ();
                       vinsert ("%s|\n", instr);
                       eob ();
                    }
               }
             insert ("/\n");

             % 5.1 Enter this directory?
             if (orelse
                {not DEPTH_LIMIT}
                   {depth < DEPTH})
               {
                  variable ndirs = 0, nfiles = 0, sind = instr;
                  variable m = create_user_mark ();

                  if (i != last)
                     sind += "|   ";
                  else
                     sind += "    ";

                  (ndirs, nfiles) = tree_tree (root+node[i]+"/", depth+1, sind);
                  dir_num += ndirs;
                  file_num += nfiles;

                  % Padding ...
                  if (PADDING)
                    {
                       % ... entries
                       if (ndirs + nfiles)
                         {
                            goto_user_mark (m);
                            () = up (1);
                            !if (tree_padding_next ())
                              {
                                 () = down (1);
                                 bol ();
                                 vinsert ("%s|\n", sind);
                              }
                            eob ();
                         }
                       % ... after directory node
                       if (i != last)
                          vinsert ("%s|\n", instr);
                    }
               }
             else
                % Padding after directory node (non-visited directory)
                if (andelse
                   {PADDING}
                      {i != last})
                   vinsert ("%s|\n", instr);
             continue;
          }

        % 6. Processing files
        % 6.1 Links
        if (stat_is ("lnk", st.st_mode))
          {
             st = stat_file (root+node[i]);
             !if (st == NULL)
               {
                  insert (" -> ");
                  insert (readlink (root + node[i]));
                  if (stat_is ("dir", st.st_mode)) {
                     insert ("/\n");
                     continue;
                  }
               }
             else
               {
                  % broken link
                  insert (" ~> ");
                  insert (readlink (root + node[i]));
                  insert ("\n");
                  continue;
               }
          }

        % 6.2 Executables
        if (st.st_mode & 0111)
          {
             insert ("*\n");
             continue;
          }

        % 6.3 Fifos
        if (stat_is ("fifo", st.st_mode))
          {
             insert ("|\n");
             continue;
          }

        % 6.4 Sockets
        if (stat_is ("sock", st.st_mode))
           insert ("=");

        % 6.5 Regular files
        insert ("\n");
     }

   %}}}

   return (dir_num, file_num);
}

%}}}
private define tree_tree_cmd       (root)                               %{{{
{
   % Executes the external command 'tree'.
   %
   % WARNING: THIS IS VERY EXPERIMENTAL AND ONLY WORKS WITH AN UNRELEASED
   % VERSION OF TREE FOR LINUX.
   %
   variable cmd = "tree ";
   variable cmd_switches = "-jFn ";
   variable total = "";
   variable tree_depth_switch = "";

   % Some parameters for tree
   if (INDENT)
      cmd_switches += "-V \"" + tree_indent + "\" ";
   !if (SHOW_FILES)
      cmd_switches += "-d ";
   if (SHOW_HIDDEN)
      cmd_switches += "-a ";
   if (DEPTH_LIMIT)
      cmd_switches += sprintf ("-L %d ", DEPTH);
   if (PATTERN_MATCH != "")
      cmd_switches += "-P \"" + PATTERN_MATCH + "\" ";
   if (PATTERN_EXCLUDE != "")
      cmd_switches += "-I \"" + PATTERN_EXCLUDE + "\" ";

   % Command to execute
   vinsert ("%s\n", root);
   cmd += cmd_switches + "\"" + root + "\" 2> /dev/null | tail +2";
   () = run_shell_cmd (cmd);

   % Arrangements
   % 1. Get max depth reached
   eob ();
   () = up (1);
   bol ();
   skip_word ();
   () = right (1);
   push_mark ();
   fsearch (",");
   tree_depth = integer (bufsubstr ());
   pop_mark ();

   % 1. Remove totals from last line
   bol ();
   push_mark ();
   eol (); total = bufsubstr ();
   pop_mark (0);
   delete_line ();
   () = up (1);
   delete_line ();
   () = up (1);
   eol (); del ();

   % 3. Insert totals at the end of the first line
   bob ();
   eol ();
   vinsert ("   [%s]", total);
}

%}}}
private define tree_wc2regexp      (wc, cs)                             %{{{
{
   % Converts a wild-card to a regexp.
   variable re, i;

   re = "";

   !if (CASE_SENSITIVE and cs)
      re = "\\C";

   re += "^";

   _for (0, strlen (wc)-1, 1)
     {
        i = ();
        switch (wc[i])
          {case '.': re += "\\.";}
          {case '*': re += ".*";}
          {case '?': re += ".";}
          {re += sprintf ("%c", wc[i]);}
     }

   return re+"$";
}

%}}}

% infomisc.sl -*- mode: SLang; mode: fold -*-
% autoloaded functions for info

require("info");
use_namespace("info");
%{{{ full search

public define info_search ()
{
   variable this_line, this_file, str, err_str, file, wline, ifile, ext;
   err_str = "String not found.";
    
   str = read_mini("Re-Search:", LAST_SEARCH, Null_String);
   !if (strlen(str)) return;
   save_search_string(str);
   widen(); go_right_1 (); 
   if (re_fsearch(str)) 
     {
	info_narrow();
	return;
     }
   
   %
   %  Not found.  Look to see if this is split.
   %
   !if (strlen(Info_Split_File_Buffer))
     {
	info_narrow();
	error (err_str);
     }
   
   this_file = Info_This_Filename;
   this_line = what_line();
   wline = window_line(); %need this so state can be restored after a failure.
  
  
   setbuf(Info_Split_File_Buffer); widen(); bob();
   bol_fsearch("Indirect:"); pop();
   push_mark();
   if (info_search_marker(1)) go_up_1 (); else eob();
   narrow();
   bob();
   bol_fsearch(extract_filename(this_file)); pop();

   ERROR_BLOCK
     {
	widen();
	info_find_file (this_file);
	goto_line(this_line); eol();
	info_narrow();
	recenter(wline);
     }
   
   while (down_1 ())
     {
	% bol(); --- implicit
	push_mark();
	
	!if (ffind_char (':')) {pop_mark_0 ();  break; } 
	file = bufsubstr();
	flush("Searching " + file);
	(ifile, ext) = info_make_file_name(file);
#ifdef UNIX OS2
	if (strlen(ext))
	  {
	     variable re = str;

	     % Not all greps support -e option.  So, try this:
	     if (re[0] == '-') re = "\\" + re;

	     setbuf(" *Info*zcat*"); erase_buffer();

	     () = run_shell_cmd(sprintf("%s %s%s | grep -ci '%s'",
					make_unzip_cmd (ext),
					ifile, ext,
					re));
	     bob();
	     if (looking_at_char ('0'))
	       {
		  delbuf(whatbuf());
		  setbuf(Info_Split_File_Buffer);
		  continue;
	       }
	     setbuf(Info_Split_File_Buffer);
	  }
	else
#endif
	!if (search_file(ifile, str, 1))
	  {
	     setbuf(Info_Split_File_Buffer);
	     continue;
	  }
			 
	info_find_file(file);
	pop(fsearch(str));
	info_narrow();
	info_push_position(this_file, Info_Split_Filename, this_line);
	return;
     }
   error (err_str);
}


%}}}
%{{{ index search

static variable index_matches = NULL, index_index = 0;

public define info_index_next()
{
   !if (length(index_matches)) error ("no matches");
   info_find_node(index_matches[index_index]);
   vmessage("found %s (%d more)", index_matches[index_index],
	    length(index_matches) - index_index -1);
   index_index++;
   if (index_index == length(index_matches))
     index_index = 0;
}

% Do index search on an info file. The optional arg is
% used by info_lookup.
public define info_index()		       %  [topic]
{
   variable matches = "", this_match = "", next_node, have_index = 0, wline;
   if (bufferp("*Info*"))
     {
	sw2buf("*Info*");
     }
   !if (_NARGS)
     read_mini("index: ", "", "");
   variable string = ();
   wline = window_line();

   info_find_node("Top");
   index_index = 0;
   ERROR_BLOCK
     {
	info_keep_history = 1;
	pop_position;
	recenter(wline);
     }
   !if(re_fsearch("^* .*[Ii]ndex:"))
     error("no index");
   info_keep_history = 0;
   follow_menu;
   if (string == "") 
     {
	info_keep_history = 1;
	return;
     }
   forever
     {
	!if(fsearch(string))
	  {
	     !if(have_index) break;
	     next_node = info_extract_pointer("Next");
	     if (andelse { next_node != NULL } {is_substr(next_node, "Index")})
	       {
		  info_find_node(next_node);
		  continue;
	       }
	     else break;
	  }
	eol;
	push_mark;
	() = bfind_char(':');
	skip_chars(": \t");
	this_match = strtrim_end(bufsubstr, " \t.");
	eol;
	if (strlen(this_match) 
	    and not is_list_element(matches, this_match, '\n'))
	matches = strcat (matches, this_match, "\n");
     }
   index_matches = strtok(strtrim_end(matches, "\n"), "\n");
   index_index = 0;
   info_index_next;
   info_keep_history = 1;
}


%}}}
%{{{ info reader
%Type jed -info SUBJECT to start jed as an info reader.

public define info_reader (arg_num)
{
   variable file, node;
   
   info_mode ();
   variable f = "exit_jed";
   local_setkey (f,		"q");
   local_setkey (f,		"Q");
   
   if (arg_num != __argc)
     {
	node = "top";
	file = __argv[arg_num];
	arg_num++;
	ERROR_BLOCK
	  {
	     _clear_error;
	     % get hyperman.sl from http://jedmodes.sf.net
	     unix_man(file);
	     local_setkey (f,		"q");
	  }
#ifdef UNIX
	if (path_basename (file) != file)
	  {
	     variable dir = path_dirname (file);
	     file = path_basename (file);
	     Info_Directory = strcat (dir, "," + Info_Directory);
	  }
#endif
	% Goto top incase the requested node does not exist.
	info_find_node (sprintf ("(%s)top", file));

	if (arg_num != __argc)
	  {
	     node = __argv[arg_num];
	     arg_num++;
	  }
	
	info_find_node (sprintf ("(%s)%s", file, node));
     }
}

%}}}
%{{{ info tree
% This provides an expandable outline tree widget for info, a bit like
% Emacs' info-speedbar.  We have to grovel through the entire info file,
% so we cache the tree in Jed_Home/.info/infofilename.
% 
% The tree is made depth-first - we try to follow the menu, then we try
% to follow the 'next' pointer, then try to go up.  For some info files
% (JED) this doesn't work - the tree branches off into never never land.
% 
% You can scroll the info window up and down from the tree window with
% the Enter and Backspace keys.

_autoload ("tree_mode", "treemode",
	   "tree_user_func", "treemode", 2);

variable treebuf = "*info tree*";

define tree_scroll(cmd)
{
   variable buf = whatbuf;
   pop2buf("*Info*");
   call(cmd);
   pop2buf(buf);
}
   
define info_tree_fun()
{
   bol;
   skip_chars(" +.-");
   push_mark_eol;
   variable node = bufsubstr, buf = whatbuf;
   if (node == current_node)
     return tree_scroll("page_down");
   pop2buf("*Info*");
   info_find_node(node);
   pop2buf(buf);
}

   
define traverse()
{
   ERROR_BLOCK
     {
	_clear_error;
	indent--;
	next_up;
     }
   % indexes have a menu, we don't want to cycle forever
   if (string_match(info_extract_pointer("Node"), ".*Index$", 1))
     {
	error ("this is the end");
     }
   bob;
   () = bol_fsearch("* Menu");
   eol;
   () = bol_fsearch("* ");
   follow_menu;
}

static define make_tree()
{
   variable tree = "", spaces = "                     ",
     pointer;
   setbuf("*Info*");
   indent = 0;
   info_find_node("Top");
   info_keep_history=0;
   ERROR_BLOCK
     {
	_clear_error;
	pop_position;
	info_keep_history=1;
	setbuf(" *treetmp*");
	insert(tree);
	bob;
	trim;
	message("done");
	return;
     }

   setbuf("*Info*");
   
   flush("building the info tree");
   forever
     {
	% try to follow the menu
	tree =  strcat(tree, spaces[[:indent]],
		       info_extract_pointer("Node"), "\n");
	indent++;
	traverse;
     }
   EXECUTE_ERROR_BLOCK;
}

public define infotree()
{
   if (current_filename == "" or current_filename == "DIR")
     error ("open an info page first");
   setbuf(treebuf);
   erase_buffer;
   variable file = dircat 
     (dircat (Jed_Home_Directory, ".info"), current_filename);
   variable cached = insert_file(file);
   rename_buffer(sprintf("outline for %s", current_filename));
   treebuf = whatbuf;
   if (cached == -1)
     {
	make_tree;
	()=write_buffer(file);
	rename_buffer(" *treetmp*");
	setbuf(treebuf);
	insbuf(" *treetmp*");
	delbuf(" *treetmp*");
     }
   popup_buffer(treebuf);
   tree_mode;
   local_setkey("info->tree_scroll(\"page_up\")", Key_BS);
   rename_buffer(treebuf);
   tree_user_func(&info_tree_fun);
}


%}}}

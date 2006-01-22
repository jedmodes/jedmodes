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

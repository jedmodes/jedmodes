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
   ifnot (strlen(str)) return;
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
   if (indirect == NULL)
     {
	info_narrow();
	throw RunTimeError, err_str;
     }
   
   this_file = Info_This_Filename;
   this_line = what_line();
   wline = window_line(); %need this so state can be restored after a failure.
   
   variable is_later=0;
   foreach file (indirect.files)
     {
	ifnot (is_later)
	  {
	     if (file == extract_filename(this_file))
	       is_later = 1;
	     continue;
	  }
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
		  % what's this for?
		  continue;
	       }
	  }
	else
#endif
	  ifnot (search_file(ifile, str, 1))
	  {
	     continue;
	  }
	
	info_find_file(file);
	()=fsearch(str);
	info_narrow();
	info_push_position(this_file, indirect, this_line);
	return;
     }
   widen();
   info_find_file (this_file);
   goto_line(this_line); eol();
   info_narrow();
   recenter(wline);
   throw RunTimeError, err_str;
}

%}}}
%{{{ index search

private variable index = NULL;

public define info_index_next()
{
   if (index==NULL) throw RunTimeError, "do an index search first";
   ifnot (length(index.matches)) throw RunTimeError, "no matches";
   if (index.file != info_extract_pointer("File"))
     info_find_node(sprintf("(%s)Top",index.file));
   info_find_node(index.matches[index.index]);
   vmessage("found %s (%d more)", index.matches[index.index],
	    length(index.matches) - index.index -1);
   index.index++;
   if (index.index == length(index.matches))
     index.index = 0;
}

% Do index search on an info file. The optional arg is
% used by info_lookup.
public define info_index()		       %  [topic]
{
   variable matches = Assoc_Type[Integer_Type],
     this_match = "", next_node, have_index = 0, wline;
   index = struct
     {
	matches,
	index,
	file
     };
   index.file=info_extract_pointer("File");
   
   if (bufferp("*Info*"))
     {
	sw2buf("*Info*");
     }
   ifnot (_NARGS)
     read_mini("index: ", "", "");
   variable s = ();
   wline = window_line();

   info_find_node("Top");
   index.matches = {};
   index.index = 0;
   variable e;
   try (e)
     {     
	ifnot(re_fsearch("^* .*[Ii]ndex:"))
	  throw RunTimeError, "no index";
	info_keep_history = 0;
	follow_menu;
	if (s == "") 
	  {
	     info_keep_history = 1;
	     return;
	  }
	forever
	  {
	     ifnot(fsearch(s))
	       {
		  ifnot(have_index) break;
		  next_node = info_extract_pointer("Next");
		  if (next_node != NULL && is_substr(next_node, "Index"))
		    {
		       info_find_node(next_node);
		       continue;
		    }
		  break;
	       }
	     eol;
	     push_mark;
	     () = bfind_char(':');
	     skip_chars(": \t");
	     this_match = strtrim_end(bufsubstr, " \t.");
	     this_match = extract_element(this_match, 0, '.');
	     eol;
	     if (strlen(this_match) && not assoc_key_exists(matches, this_match))
	       {
		  matches[this_match]=1;
		  list_append(index.matches, this_match);
	       }
	  }
	index.index = 0;
	info_index_next();
	info_keep_history = 1;
     }
   catch RunTimeError:
     {
	info_keep_history = 1;
	pop_position;
	recenter(wline);
	throw RunTimeError, e.message;
     }
}


%}}}

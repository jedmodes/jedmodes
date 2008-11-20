% info.sl      -*- mode: SLang; mode: fold -*-
% Info reader for JED
%
% $Id: info.sl,v 1.15 2008/11/20 16:26:36 paul Exp paul $
% Keywords: help
% 
% Copyright (c) 2000-2008 JED, Paul Boekholt
% Released under the terms of the GNU GPL (version 2 or later).


_autoload("info_search", "infomisc",
	  "info_index", "infomisc",
	  "info_index_next", "infomisc",
	  "browse_url", "browse_url",
	  4);
require("pcre");
provide("info");

implements("info");
variable Info_This_Filename = Null_String;
variable Info_This_Filedir = Null_String;
variable indirect = NULL;


%{{{ info file

#ifndef VMS
% returns compression extension if file is compressed or "" if not 
define info_is_compressed (file)
{
   variable ext;
   foreach ext ([".Z", ".z", ".gz", ".bz2"])
     {
	if (1 == file_status(file + ext))
	  return ext;
     }
   return "";
}
#endif

define info_make_file_name (file)
{
   variable n=0, dir, dirfile, df, df_low;
   variable cext = "", path; % compressed extension
   if (strlen(Info_This_Filedir) and not is_list_element(Info_Directory, Info_This_Filedir, ','))
     path = sprintf("%s,%s", Info_This_Filedir, Info_Directory);
   else
     path = Info_Directory;
   
   EXIT_BLOCK
     {
	(Info_This_Filedir, ) = parse_filename(dirfile);
   	dirfile, cext;
     }
   
   USER_BLOCK0
     {
	if (1 == file_status(dirfile)) return;
#ifndef VMS
	cext = info_is_compressed(dirfile);
	if (strlen(cext)) return;
#endif
     }

   forever 
     {
	
	dir = extract_element(path, n, ',');
	if (dir == NULL) dir = "";
	df = expand_filename(dircat(dir,file));

	% try with first with info extension
#ifdef VMS
	dirfile = df + "info";  % VMS adds a '.' upon expansion
#else
	dirfile = df + ".info";
#endif

	X_USER_BLOCK0;

	df_low = expand_filename(dircat(dir,strlow(file)));
	
#ifdef VMS
	dirfile = df_low + "info";  % VMS adds a '.' upon expansion
#else
	dirfile = df_low + ".info";
#endif
	
	X_USER_BLOCK0;

 	% try next with inf extension, since .info causes problems on FAT
	% In addition, Unix and VMS distributions may have been derived from
	% PC 8+3 distributions.
	%
	% Also Windows 95 supports long filenames.  Since that OS is also 
	% considered to be MSDOS, we need to try this for MSDOS as well 
	% even though it has no effect under a true MSDOS system.
 	dirfile = df_low + ".inf";
	X_USER_BLOCK0;
	
% repeat without extension
	
	dirfile = df;
	X_USER_BLOCK0;

	dirfile = df_low;
	X_USER_BLOCK0;
	
	ifnot (strlen(dir))
	  {
	     throw RunTimeError, "Info file not found: " + file;
	  }
	
	++n;
     }
}

define make_unzip_cmd (ext)
{
   switch (ext)
     { case ".gz": "gzip -dc"; }
     { case ".bz2": "bzip2 -dc"; }
     { "uncompress -c"; }
}

define info_mode_menu();
define info_find_file (file)
{
   variable dirfile,  ext;
   (dirfile, ext) = info_make_file_name(file);
   setbuf("*Info*");
   set_readonly(0);
   widen(); erase_buffer();
#ifndef VMS
   if (strlen(ext))
     () = run_shell_cmd (sprintf("%s %s%s", make_unzip_cmd (ext), dirfile, ext));
   else
#endif
     () = insert_file(dirfile);
   bob();
   Info_This_Filename = dirfile;
   set_readonly(1);
   set_buffer_modified_flag(0);
   set_mode("info", 0);
   mode_set_mode_info("info", "init_mode_menu", &info_mode_menu);
   use_keymap("Infomap");
#ifdef HAS_DFA_SYNTAX
   use_syntax_table("info");
#endif
}


%}}}

%{{{ navigation

%{{{ finding the node

define info_find_node_split_file();  % extern

define info_search_marker(dir)
{
   if (dir > 0) return bol_fsearch_char(0x1F);
   else return bol_bsearch_char(0x1F);
}

define info_extract_pointer();
define narrow_to_node()
{
   push_mark();
   if (info_search_marker(1)) go_up_1(); else eob();
   narrow();
   bob();
   go_down_1();
   recenter(1);
   variable current_filename = path_sans_extname(info_extract_pointer("File"));
   set_status_line(sprintf("Jed Info:  (%%m)  (%s)%s  (%%p)  %%t",
   			   current_filename, info_extract_pointer("Node")), 0);

}

% find the node.
define info_find_node_this_file (the_node)
{
   widen(); bob();
   forever
     {
	ifnot (re_fsearch(sprintf("\\c^File:.*Node: ?%s[,\t]", str_quote_string 
				(the_node, "\\^$[]*.+?", '\\'))))
	  {
	     % dont give up, maybe this is a split file
 	     if (indirect == NULL)
	       throw RunTimeError, "Marker not found!. Node: " + the_node;
	     info_find_node_split_file(the_node);
	     return;
	  }
	go_up_1();
	bol();
	ifnot (looking_at_char(0x1F))
	  {
	     go_down_1 ();
	     eol();
	     continue;
	  }
	go_down_1();
	break;
     }
   narrow_to_node();
}

define make_indirect()
{
   variable mark = create_user_mark();
   bob ();
   ()=bol_fsearch("Indirect:");
   push_mark();
   ifnot (info_search_marker(1)) eob();
   narrow();
   variable re=pcre_compile("^(.*): ([\\d]+)");
   variable entry, i=0;
   indirect = struct{files, bytes, tag_table};
   indirect.files=String_Type[what_line()];
   indirect.bytes=Integer_Type[what_line()];
   bob();
   
   while (down_1())
     {
	entry=line_as_string();
	if (pcre_exec(re, entry))
	  {
	     indirect.files[i]=pcre_nth_substr(re, entry, 1);
	     indirect.bytes[i]=atoi(pcre_nth_substr(re, entry, 2));
	     i++;
	  }
     }
   indirect.files=indirect.files[[:i-1]];
   indirect.bytes=indirect.bytes[[:i-1]];
   eob();
   widen();
   push_mark();
   eob();
   indirect.tag_table=bufsubstr();
   goto_user_mark(mark);
}

define info_find_node_split_file (node)
{
   variable tag, tagpos, pos, pos_len, tag_len, file;
   variable re, offset = 0;
   if (indirect == NULL)
     make_indirect();

   re = pcre_compile(strcat("^Node: \\Q", node, "\\E[\t \x7F](\\d+)[ \t]*$"),
		     PCRE_MULTILINE);
   if (pcre_exec(re, indirect.tag_table))
     {
   	tagpos = pcre_nth_substr(re, indirect.tag_table, 1);
     }
   else
     {
	% This finds footnotes hidden in special footnote nodes such as in
	% the groff info page
	re = pcre_compile(strcat("^Node: *(.*)\x7F(\\d+)[ \t]*\n(?:^Ref:.*\n)*^Ref: \\Q",
				 node, "\\E[\t \x7F](\\d+)[ \t]*$"),
			  PCRE_MULTILINE | PCRE_UNGREEDY);
	if (pcre_exec(re, indirect.tag_table))
	  {
	     node = pcre_nth_substr(re, indirect.tag_table, 1);
	     tagpos = pcre_nth_substr(re, indirect.tag_table, 2);
	     offset = atoi(pcre_nth_substr(re, indirect.tag_table, 3)) - atoi(tagpos);
	  }
	else
	  throw RunTimeError, "could not find node in tag table";
     }

   file = wherelast (indirect.bytes <= atoi(tagpos));
   if (file == NULL)
     throw RunTimeError, "tag before any nodes?";
   
   file = dircat(Info_This_Filedir, indirect.files[file]);

   info_find_file(file);
   info_find_node_this_file(node);
   if (offset)
     {
	bob();
	go_right(offset);
     }
}


%}}}

%{{{ history

define info_narrow()
{
   push_spot();
   () = info_search_marker(-1);
   go_down_1 ();
   narrow_to_node();
   pop_spot();
}

% stack for last position 

ifnot (is_defined ("Info_Position_Type"))
{
   typedef struct
     {
	filename,
	indirect,
	line_number
     }
   Info_Position_Type;
}

variable Info_Position_Stack = Info_Position_Type [16],
  Info_Position_Rotator = [[1:15],0],
  Info_Stack_Depth = 0,
  Forward_Stack_Depth = 0;

define info_push_position(file, indirect, line)
{
   if (Info_Stack_Depth == 16)
     {
        --Info_Stack_Depth;
	  Info_Position_Stack  = Info_Position_Stack [Info_Position_Rotator];
     }
   
   variable pos = Info_Position_Stack [Info_Stack_Depth];

   pos.filename = file;
   pos.indirect = indirect;
   pos.line_number = line;

   ++Info_Stack_Depth;
   Forward_Stack_Depth = 0;
}

variable info_keep_history = 1;
define info_record_position ()
{
   if (whatbuf() != "*Info*") return;
   ifnot (info_keep_history) return;
   widen();
   
   info_push_position(Info_This_Filename, indirect, what_line());
   info_narrow();
}

define goto_stack_position()
{
   variable pos = Info_Position_Stack [Info_Stack_Depth];
   indirect = pos.indirect;
  
   if ((pos.filename == Info_This_Filename) && bufferp("*Info*"))
     {
        widen();
        goto_line(pos.line_number); bol();
        info_narrow();
        return;
     }
   ifnot (strlen(pos.filename)) return;
   info_find_file(pos.filename);
   goto_line(pos.line_number); bol();
   info_narrow();
}

define pop_position()
{
   --Info_Stack_Depth;
   goto_stack_position;
}

% increment forward depth and move back; if this is is our first step
% back, record the current position.
define goto_last_position ()
{
   if (Info_Stack_Depth <= 0) return;
   ifnot (Forward_Stack_Depth)
     {
   	info_record_position;
   	--Info_Stack_Depth;
     }
   ++Forward_Stack_Depth;
   pop_position;
}

% move forward again
define goto_next_position()
{
   ifnot (Forward_Stack_Depth) return;
   ++Info_Stack_Depth;
   --Forward_Stack_Depth;
   if (Info_Stack_Depth == 16) return;
   goto_stack_position;
}


%}}}

%{{{ moving around

define find_dir();
define follow_current_xref();
public define info_find_node(node)
{
   variable file, n = 0;
   variable current_filename = path_sans_extname(info_extract_pointer("File"));
   % Replace \n and \t characters in name by spaces
   node = strcompress (node, " \t\n");
   info_record_position();
   variable old_indirect = indirect;
   
   try
     {
	% if it looks like (file)node, extract file, node
	if (is_substr(node, "(") == 1
	    && (n = is_substr(node, ")"), n)
	    && (file = substr(node, 2, n - 2), 
		node = substr(node, n+1, strlen(node)),
		file != current_filename))
	  {
	     indirect = NULL;
	     info_find_file(file);
	  }
	node = strtrim (node);
	widen();
	variable mark = create_user_mark();
	bob ();
	ifnot (info_search_marker(1)) 
	  throw RunTimeError, "Marker not found.";
	go_down_1 ();
	USER_BLOCK0
	  {
	     if (looking_at("Indirect:"), goto_user_mark(mark))
	       info_find_node_split_file(node);
	     else
	       info_find_node_this_file(node);
	  }
	if (strlen(node))
	  {
	     X_USER_BLOCK0;
	  }
	else
	  {
	     node = "Top";
	     try
	       {
		  X_USER_BLOCK0;
	       }
	     catch RunTimeError:
	       {
		  node="top";
		  X_USER_BLOCK0;
	       }
	  }
	sw2buf("*Info*");
     }
   catch AnyError:
     {
	indirect = old_indirect;
   	sw2buf("*Info*");
   	info_reader ();
   	pop_position();
   	throw;
     }
}

% If buffer has a menu, point is put on line after menu marker if argument
% is non-zero, otherwise leave point as is.
% signals error if no menu.
define info_find_menu(save)
{
   push_spot_bob ();
   ifnot (re_fsearch("^\\c\\* Menu:"))
     {
	pop_spot();
	throw RunTimeError, "Node has no menu.";
     } 
   ifnot (save) 
     {
	pop_spot();
	return;
     }
   go_down_1 ();
   push_mark(); pop_spot(); pop_mark_1 ();
}


% Move the cursor to the start of the next nearest menu item or
% note reference in this node if possible.
define next_xref ()
{
   push_mark (); go_right_1 ();
   for (; fsearch_char('*'); skip_chars("*"))
     {
	if ((bolp() && looking_at ("* ")) || re_looking_at("\\C\\*note"))
	  {
	     if (re_looking_at("\\C^* menu")) continue;
	     exchange_point_and_mark();
	     break;
	  }
     }
   pop_mark_1();
}


% Move the cursor to the start of the previous nearest menu item or
% note reference in this node if possible.
define prev_xref ()
{
   push_mark (); go_left_1 ();
   for (; bsearch_char('*'); bskip_chars("*"))
     {
	if ((bolp() && looking_at ("* ")) || re_looking_at("\\C\\*note"))
	  {
	     if (re_looking_at("\\C^* menu")) continue;
	     exchange_point_and_mark();
	     break;
	  }
     }
   pop_mark_1();
}


% menu references

define follow_current_xref ()
{
   variable node;
   
   push_spot();
  
   ifnot (fsearch_char (':'))
     {
	pop_spot();
	throw RunTimeError, "Corrupt File?";
     }
   
   if (looking_at("::"))
     {
        push_mark();
        pop_spot();
        node = bufsubstr();
     }
   else
     {
        go_right_1 ();
        skip_white();
	if (eolp())
	  {
	     go_right_1 ();
	     skip_white();
	  }
        push_mark();
	if (looking_at_char('(')) () = ffind_char (')');
	% xrefs may be split across two lines, also I've seen xrefs terminated by '('
	skip_chars("^,\t.("); % does not skip newlines
	if (eolp) 
	  {
	     go_down_1();
	     skip_chars("^,\t.(");
	  }
	node = strcompress(bufsubstr(), " \n");
        pop_spot();
     }
   info_find_node(node);
}

% follow the menu item on this line. We are at bol.
define follow_menu()
{
   ifnot (ffind_char(':')) throw RunTimeError, "Corrupt File?";

   if (looking_at("::"))
     {
	push_mark();
	bol(); go_right(2);
     }
   else
     {
        go_right_1 ();
        skip_white();
        push_mark();
	if (looking_at_char('('))
	  {
	     () = ffind_char (')');
	  }
	% comma, tab, '.', or newline terminates
	skip_chars("^,.\t\n");
	 
        bskip_chars(" ");
     }
   info_find_node(bufsubstr());
}

% This reads the menu items into a comma-delimited string
define get_menu_items()
{
   push_spot_bob();
   ifnot (re_fsearch("^\\c\\* Menu:"))
     return pop_spot, NULL;
   eol();
   variable n = 0;
   ",";
   while (bol_fsearch("* "))
     {
	go_right(2);
	push_mark();
	()=ffind_char(':');
	bufsubstr();
	n++;
     }
   pop_spot();
   return create_delimited_string(n);
}

define menu ()
{
   variable node = Null_String;
   info_find_menu (0);
   variable items = get_menu_items();
   
   bol ();
   if (looking_at("* ") && ffind(":"))
     {
	push_mark();
	bol(); go_right(2);
	node = bufsubstr();
	bol();
     }

   node = read_string_with_completion("Menu item:", node, items);
   info_find_menu (1);
   ifnot (bol_fsearch(sprintf("* %s:", node))) throw RunTimeError, "Menu Item not found.";
   follow_menu();
}

define follow_nearest_node ()
{
   variable colon = ":", colons = "::";
  
   % This is the "enter" action, should be a separate function
   if (re_looking_at ("\\C*Note[ \t\n]"))
     {
	go_right (5); skip_chars (" \t\n");
	follow_current_xref ();
	return;
     }
   
   info_find_menu (0);
   bol();
   follow_menu();
}

define find_dir() 
{
   if ("*Info*" == whatbuf())
     {
	variable file = "* " + path_sans_extname(info_extract_pointer("File"));
	info_find_node ("(DIR)Top");
	() = bol_fsearch(file);
     }
   else
     info_find_node ("(DIR)Top");
}


define info_extract_pointer()
{
   variable name, errorname = NULL;
   if (_NARGS == 2) errorname = ();
   push_spot_bob();
   go_down_1();
   variable len = re_bsearch(() + ":");
   if (len)
     go_right(len - 1);
   else
     {
	pop_spot();
	if (errorname != NULL) throw RunTimeError, "node has no " + errorname;
	else return "";
     }
   skip_white();
   push_mark();
   skip_chars("^,\t\n");
   bskip_white();
   bufsubstr();
   pop_spot();
}

define info_up ()
{   
   variable upnode = info_extract_pointer("Up");
   if(upnode == NULL || upnode == "(dir)")
     find_dir ();
   else
     {
	"* " + info_extract_pointer("Node");
	info_find_node(upnode);
	() = bol_fsearch();
     }
}

define info_prev()
{
   info_find_node(info_extract_pointer("Prev[ious]*", "PREVIOUS"));
}

define info_next ()
{
   info_find_node(info_extract_pointer("Next", "NEXT"));
}

define info_top()
{
   info_find_node("Top");
}

%}}}

%}}}

%{{{ help for info

define quick_help()
{
   message("q:quit,  h:tutorial,  SPC:next screen,  DEL:prev screen,  m:menu,  s: search");
}

define tutorial()
{
   info_find_node("(info)help");
}

%}}}

%{{{ menu, keys, mouse, bookmarks

define info_mode_menu(menu)
{
   $1= _stkdepth;
   "&Add Bookmark", "info->add_bookmark";
   "&Help",	"info->tutorial";
   "&Search",	"info_search";
   "&Index",	"info_index";
   "&Top",	"info->top";
   "&Dir",	"info->find_dir";
   loop ((_stkdepth - $1)/2)
     menu_append_item(menu, _stk_roll(3));
}

define add_bookmark()
{
   menu_append_popup("Global.M&ode", "&Bookmark");

   variable bookmark = sprintf("(%s)%s",
			       path_sans_extname(info_extract_pointer("File")),
			       info_extract_pointer("Node"));
   menu_append_item("Global.M&ode.&Bookmark", bookmark, 
		    sprintf ("info_find_node(\"%s\")", bookmark));
   message ("bookmark added");
}
  
$2 = "Infomap";
ifnot (keymap_p($2))
{
   make_keymap($2);
   $1 = _stkdepth;
   "info->quick_help",		"?";
   "info->tutorial",		"h";
   "info->tutorial",		"H";
   "info->follow_nearest_node",		"^M";
   "info->menu",		"m";
   
   "info->next_xref",		"\t";
#ifdef MSDOS MSWINDOWS
   "info->prev_xref",		"^@^O";
#endif
   
   "info->info_next",		"N";
   "info->info_next",		"n";
   "info->info_prev",		"P";
   "info->info_prev",		"p";
   "info->info_up",		"U";
   "info->info_up",		"u";
   "info->info_top",		"t";
   "info->scroll",		" ";
   "page_up",			"^?";
   "bob",			"B";
   "bob",			"b";
   "info->goto_node",		"G";
   "info->goto_node",		"g";
   "info->quit",		"q";
   "info->quit",		"Q";
   "info->goto_last_position",	"l";
   "info->goto_last_position",	"L";
   "info->goto_next_position",	";";
   "info_search",		"S";
   "info_search",		"s";
   "info_search",		"/";
   "info->follow_reference",	"f";
   "info->follow_reference",	"F";
   "info->find_dir",		"D";
   "info->find_dir",		"d";
   "info_index",		"i";
   "info_index_next",		",";
   "info->add_bookmark",	"a";
   "info->forward_node",	"]";
   loop((_stkdepth() - $1) /2)
     definekey ($2);
   _for (1, 9, 1)
     {
	$1 = ();
	definekey("info->menu_number", string($1), $2);
     }
   runhooks ("info_binding_hook");
}

define mouse_hook(line, col, but, shift)
{
   if (bfind_char('*'))
     {
	follow_nearest_node();
     }
   else if (bfind("http://"))
     {
	push_mark();
	go_right(7);
	skip_chars("-a-zA-Z0-9~/.+&#=?");
	bskip_chars(".?");
	browse_url(bufsubstr);
     }
   1; 
}


%}}}

%{{{ DFA

#ifdef HAS_DFA_SYNTAX
create_syntax_table ("info");
%%% DFA_CACHE_BEGIN %%%
define setup_dfa_callback (mode)
{
 %  dfa_enable_highlight_cache(mode +".dfa", mode);
   % this should highlight both long and short menu items,
   % but not the *menu: line
   dfa_define_highlight_rule ("^\\*[^:]+:[: ]", "keyword0", mode);
   dfa_define_highlight_rule ("\\*[Nn]ote", "keyword0", mode);
   dfa_define_highlight_rule ("http://[\\-a-zA-Z0-9~/\\\.]+[a-zA-Z0-9/]", "string", mode);
   dfa_build_highlight_table(mode);
}
dfa_set_init_callback (&setup_dfa_callback, "info");
%%% DFA_CACHE_END %%%
enable_dfa_syntax_for_mode("info");
#endif

%}}}

%{{{ (mostly) interactive functions

%{{{ info mode

% The tm documentation has been adapted from Emacs' documentation. I hope
% all the info is correct.

%!%+
%\function{info_mode}
%
%\usage{define info_mode ()}
%\description
%
% Info mode provides commands for browsing through the Info documentation
% tree.  Documentation in Info is divided into "nodes", each of which
% discusses one topic and contains references to other nodes which discuss
% related topics.  Info has commands to follow the references and show you
% other nodes.
%
% \var{h}	Invoke the Info tutorial.
% \var{q}	Quit Info
% 
% Selecting other nodes:
% \var{mouse-1}
% 	Follow a node reference you click on.
% \var{RET}	Follow a node reference near point, like mouse-1.
% \var{n}	Move to the "next" node of this node.
% \var{p}	Move to the "previous" node of this node.
% \var{u}	Move "up" from this node.
% \var{m}	Pick menu item specified by name
% 	Picking a menu item causes another node to be selected.
% \var{d}	Go to the Info directory node.
% \var{f}	Follow a cross reference.  Reads name of reference.
% \var{l}	Move to the last node you were at.
% \var{;}	Move forward in the history stack
% \var{i}	Look up a topic in this file's Index and move to that node.
% \var{,}	Move to the next match from a previous `i' command.
% \var{t}	Go to the Top node of this file.
% 
% Moving within a node:
% \var{SPC}	Normally, scroll forward a full screen.
% 	When at the end of the node, the next scroll moves into its
% 	first subnode.  When after all menu items (or if there is no
% 	menu), move up to the parent node.
% \var{DEL}   Scroll backward.
% \var{b}	Go to beginning of node.
% 
% Advanced commands:
% \var{1}	Pick first item in node's menu.
% \var{2} ... \var{9} Pick second ... ninth item in node's menu.
% \var{g}	Move to node specified by name.
% 	You may include a filename as well, as (FILENAME)NODENAME.
% \var{s}	Search through this Info file for specified regexp,
% 	and select the node in which the next occurrence is found.
% \var{TAB}	Move cursor to next cross-reference or menu item.
% 
%\notes
% To start JED as an info reader, type "jed -info \var{TOPIC}.  JED will 
% look for info page \var{TOPIC}, if not found it will look for a man 
% page.  Pressing \var{q} quits JED.
%   
%\seealso{help_for_word_at_point, unix_man}
%!%-
private define start_info_reader ()
{
   variable ibuf = "*Info*";
   if (bufferp(ibuf)) return sw2buf(ibuf);
   if (Info_Stack_Depth) 
     pop_position ();
   ifnot (bufferp(ibuf)) find_dir();
   sw2buf(ibuf);
   onewindow();
   run_mode_hooks ("info_mode_hook");
   set_buffer_hook("mouse_up", &mouse_hook);
   define_blocal_var("generating_function", ["info_reader"]);
}

%}}}

define quit ()
{
   info_record_position();
   widen();
   delbuf("*Info*");
}

define goto_node()
{
   info_find_node (read_mini("Node:", Null_String, Null_String));
}


%{{{ follow reference

define info_looking_at (ref)
{
   push_mark ();
   ref = strcompress(strlow(ref), " ");
   
   go_down_1();
   eol();
   exchange_point_and_mark();
   not strncmp(strcompress(strlow(bufsubstr()), " \t\n"), ref, strlen(ref));
}

define follow_reference ()
{
   variable ref;
   
   push_spot_bob();
   ifnot (fsearch("*Note"), pop_spot())
     throw RunTimeError, "No cross references.";
  
   ref = read_mini("Follow *Note", Null_String, Null_String);
   push_spot_bob ();
   forever
     {
	ifnot (fsearch("*Note"))
	  {
	     pop_spot();
	     throw RunTimeError, "Bad reference.";
	  }
	go_right (5);  skip_chars (" \t\n");
	if (info_looking_at(ref)) break;
     }
   
   push_mark();
   pop_spot();
   %info_record_position
   pop_mark_1 ();
   
   follow_current_xref ();
}


%}}}

%{{{ menu number

define menu_number ()
{
   variable n = LAST_CHAR;
   if ((n < '1') || (n > '9')) return beep();
   n -= '0';
  
   info_find_menu(1);

   while (n)
     { 
	ifnot (bol_fsearch("* ")) return beep();
	if (ffind(":")) --n; else eol();
     }
   bol();
   follow_menu();

}

%}}}

%{{{ scrolling

define up()
{   
   variable upnode = info_extract_pointer("Up");
   if(upnode == NULL || upnode == "(dir)" || upnode == "Top")
     throw RunTimeError, "this is the end";
   else
     info_find_node(upnode);
}

define next_up();

define next_up()
{
   variable pointer;
   pointer = info_extract_pointer("Node");
   if (string_match(info_extract_pointer("Node"), ".*Index$", 1))
     {
	throw RunTimeError, "this is the end";
     }
   pointer = info_extract_pointer("Next");
   if (pointer == "Top") throw RunTimeError, "this is the end";
   if (pointer == "")
     {
	up();
	next_up();
     }
   else
     info_find_node(pointer);
}

define forward_node()
{
.  % indexes have a menu, we don't want to cycle forever
.  "Node" info_extract_pointer ".*Index$" 1 string_match
.    { "this is the end" message return } if
.  bob "^\\c\\* Menu:" re_fsearch 
.    { next_up return } ifnot
.  eol "* " bol_fsearch pop
.  follow_menu
}

define scroll()
{
.  what_line window_line -
.  push_spot eob
.  what_line 'r' window_info - < pop_spot
.    { "page_down" call return } if
.  forward_node
}

%}}}

%}}}

%{{{ info reader
%Type jed -info SUBJECT to start jed as an info reader.

public define info_reader ()
{
   variable file, node;
   
   start_info_reader ();

   if (_NARGS == 0)
     return;
   
   variable args = ();
   variable nargs = length (args);

   local_setkey ("exit_jed",		"q");
   local_setkey ("exit_jed",		"Q");

   if (nargs > 0)
     {
	file = args[0];

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
	if (nargs > 1)
	  info_find_node (sprintf ("(%s)%s", file, args[1]));
     }
}

public define info_mode()
{
   info_reader();
}

%}}}

% info.sl      -*- mode: SLang; mode: fold -*-
% Info reader for JED
%
% $Id: info.sl,v 1.1.1.1 2004/10/28 08:16:22 milde Exp $
% Keywords: help
% 
% Copyright (c) 2000-2003 JED, Paul Boekholt
% Released under the terms of the GNU GPL (version 2 or later).
if (_featurep("infospace")) use_namespace("info");
else implements ("info");
_autoload("info_search", "infomisc",
	  "info_index", "infomisc",
	  "info_index_next", "infomisc",
	  "infotree", "infomisc",
	  "browse_url", "browse_url", % in jedscape package
	  5);

variable Info_This_Filename = Null_String;
variable Info_This_Filedir = Null_String;

% Info file that Info is now looking at. This is the name that was
% specified in Info, not the actual file name.  This is used by infotree
% to cache the tree, if there are directory parts make the subdirectory
% in your Jed_Home/.info directory.
variable current_filename = Null_String;

% node info is currently looking at
variable current_node = Null_String;
%{{{ info file

#ifndef VMS
% returns compression extension if file is compressed or "" if not 
define info_is_compressed (file)
{
   variable exts, ext, n;
   exts = ".Z,.z,.gz,.bz2";
   n = 0;
   forever
     {
	ext = extract_element(exts, n, ',');
	if (ext == NULL) return "";

	if (1 == file_status(file + ext)) break;
	n++;
     }
   ext;
}
#endif

define info_make_file_name (file)
{
   variable n=0, dir, dirfile, df, df_low;
   variable cext = ""; % compressed extension
   
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
        %
        % Try to find requested file in remembered directory.
        %
	dirfile = expand_filename(dircat(Info_This_Filedir, file));
	if (1 == file_status(dirfile)) break;
	
	dir = extract_element(Info_Directory, n, ',');
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

	!if (strlen(dir)) error ("Info file not found: " + file);
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

% deleting the markers takes long, so make just 100
static variable headline_marks = Mark_Type[100],
  headline_color = [color_number("keyword"),
		    color_number("comment"),
		    color_number("string")];

define info_find_file (file)
{
   variable dirfile, flags, buf, dir;
   variable ext;
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
   variable i= 0, headnumber, underline;
   1;
   while (bol_fsearch("\x1F"))
     {
	()=down(4);
	push_mark; push_mark; eol; underline = bufsubstr;
	if (orelse
	    {headnumber = 0, string_match(underline, "^\\*+$", 1)}
	      {headnumber++, string_match(underline, "^\\=+$", 1)}
	      {headnumber++, string_match(underline, "^\\-+$", 1)}
	      {pop_mark_0, 0})
	  {
	     del_region;
	     % The tags table is not correct anymore,
	     % but we only use it to determine which
	     % file a node is in.
	     del;
	     up; % take a 1 from the stack and push one for next round
	     headline_marks[i] =create_line_mark(headline_color[headnumber]);
	     i++;
	     if (i == 100) break;
	  }
     }
   pop;
   bob;
   Info_This_Filename = dirfile;
   set_readonly(1);
   set_buffer_modified_flag(0);
   set_mode("info", 0);
   use_keymap("Infomap");
}


%}}}

%{{{ navigation

%{{{ finding the node

define info_find_node_split_file();  % extern

variable Info_Split_File_Buffer = Null_String;
variable Info_Split_Filename = Null_String;

define info_search_marker(dir)
{
   variable mark, pnt, search_fun;
   mark = "\x1F";
   if (dir > 0) search_fun = &fsearch; else search_fun = &bsearch;
   push_mark();
   forever 
     {
	if (not(@search_fun(mark)))
	  {
	     pop_mark_1 ();
	     return(0);
	  }
	if (bolp()) break;
	pnt = _get_point ();
	bol(); skip_chars("\x01-\x1E ");
	go_right_1 ();
	pnt = _get_point () - pnt;
	if ((pnt == 1) and (eolp() or looking_at_char('\xC'))) break;
	if (dir > 0) eol(); else bol();
     }
   pop_mark_0 ();
   return (1);
}

define info_extract_pointer();
define narrow_to_node()
{
   push_mark();
   if (info_search_marker(1)) go_up_1(); else eob();
   narrow();
   bob();
   go_down_1;
   recenter(1);
   current_filename = path_sans_extname(info_extract_pointer("File"));
   current_node = info_extract_pointer("Node");
   set_status_line(sprintf("Jed Info:  (%%m)  (%s)%s  (%%p)  %%t",
   			   current_filename, current_node), 0);

}

define info_find_node_this_file (the_node)
{
   variable node, len, fnd;
   CASE_SEARCH = 0;
   node = "Node: " + the_node;
   len = strlen(node);
   widen(); bob();
   forever
     {
	% some of this could/should be replaced by a regular expression:
	% !if (re_fsearch("^[\t ]*\x1F")) ....
	
	!if (info_search_marker(1))
	  {
	     % dont give up, maybe this is a split file
	     !if (strlen(Info_Split_File_Buffer)) 
	       error("Marker not found. " + node);
	     setbuf(Info_Split_File_Buffer);
	     info_find_node_split_file(the_node);
	     return;
	  }
	go_down_1 (); % bol();  --- already implicit
	if (ffind(node))
	  {
	     % is this really it?  ---
	     go_right(len);
	     if (eolp() or looking_at_char(',') or looking_at_char('\t')) break;
	  }
	
	eol ();
     }
   narrow_to_node;
}


define info_find_node_split_file (node)
{
   variable tag, tagpos, pos, pos_len, tag_len, buf, file;
   variable re, offset =0;
   buf = " *Info*";
  
   !if (bufferp(buf), setbuf(buf)) 
     {
	insbuf("*Info*");
     }
   
   widen();
      
   % make this re safe 
   tag = str_quote_string (node, "\\^$[]*.+?", '\\');
   
   eob();
  
   
   %!if (bol_bsearch(tag)) error("tag not found.");
   %go_right(strlen(tag));
   %skip_chars(" \t\x7F");
   
   re = strcat("Node: ", tag, "[\t \x7F]\\d+[ \t]*$");
   !if (re_bsearch(re)) 
     {
	% look for refs and footnotes in tag table
	re = strcat("Ref: ", tag, "[\t \x7F]\\d+[ \t]*$");
	!if (re_bsearch(re)) 
	  verror ("tag %s not found.", tag);
	()=ffind_char('');
	go_right_1; push_mark; eol;
	% the byte offset is not correct because we removed underlinings,
	% but we're still close (and footnotes don't have underlinings)
	% will probably not work on 16-bit systems
	offset = integer(bufsubstr);
	()=bol_bsearch("Node:");
	go_right(5); skip_white;
	push_mark; () =ffind_char('');
	node = bufsubstr;
	go_right_1; push_mark; eol;
	offset -= integer(bufsubstr);
     }
   eol ();
   bskip_chars(" \t");
   push_mark(); bskip_chars ("0-9");
   tagpos = bufsubstr();  % see comment about DOS below
   tag_len = strlen(tagpos);
  
   bob ();
   bol_fsearch("Indirect:"); pop();
   push_mark();
   !if (info_search_marker(1)) eob();
   narrow();
   bob();
   forever
     {
	!if (down_1 ()) break;
	% bol(); --- implicit in down
	!if (ffind(": ")) break;
	go_right(2);
	
	% This will not work on DOS with 16 bit ints.  Do strcmp instead.
	push_mark_eol(); pos = bufsubstr(); 
	pos_len = strlen(pos);
	if (tag_len > pos_len) continue;
	if (tag_len < pos_len) break;
	% now ==
	if (strcmp(tagpos, pos) < 0) break;
     }
   
   Info_Split_File_Buffer = Null_String;
   go_up_1 ();  bol();
   push_mark();
   () = ffind(": ");
   widen();
   file = dircat(Info_This_Filedir, bufsubstr());

   info_find_file(file);
   info_find_node_this_file(node);
   if (offset)
     {
	bob;
	go_right(offset);
     }
   Info_Split_File_Buffer = buf;
}


%}}}

%{{{ history

define info_narrow()
{
   if (whatbuf () != "*Info*") return;
   push_spot();
   () = info_search_marker(-1);
   go_down_1 (); push_mark();
   narrow_to_node;
   pop_spot();
}

% stack for last position 

!if (is_defined ("Info_Position_Type"))
{
   typedef struct
     {
	filename,
	split_filename,
	line_number
     }
   Info_Position_Type;
}

static variable Info_Position_Stack = Info_Position_Type [16],
  Info_Position_Rotator = [[1:15],0],
  Info_Stack_Depth = 0,
  Forward_Stack_Depth = 0;

define info_push_position(file, split, line)
{
   variable i;
   variable pos;

   if (Info_Stack_Depth == 16)
     {
        --Info_Stack_Depth;
	  Info_Position_Stack  = Info_Position_Stack [Info_Position_Rotator];
     }
   
   pos = Info_Position_Stack [Info_Stack_Depth];

   pos.filename = file;
   pos.split_filename = split;
   pos.line_number = line;

   ++Info_Stack_Depth;
   Forward_Stack_Depth = 0;
}

static variable info_keep_history = 1;
define info_record_position ()
{
   variable i, file;
  
   if (whatbuf() != "*Info*") return;
   !if (info_keep_history) return;
   widen();
   file = "";
   
   if (strlen (Info_Split_File_Buffer)) file = Info_Split_Filename;
   info_push_position(Info_This_Filename, file, what_line());
   info_narrow();
}

define goto_stack_position()
{
   variable split_file, file, n;
   variable pos;

   pos = Info_Position_Stack [Info_Stack_Depth];

   split_file = pos.split_filename;
   file = pos.filename;
   n = pos.line_number;
  
   if ((file == Info_This_Filename) and bufferp("*Info*"))
     {
        widen();
        goto_line(n); bol();
        info_narrow();
        return;
     }
   if (strlen(split_file))
     {
	setbuf(" *Info*");
	set_readonly(0);
	widen();
	erase_buffer();
#ifndef VMS
 	variable ext = info_is_compressed (split_file);
 	if (strlen(ext))
	  () = run_shell_cmd(sprintf("%s %s%s", make_unzip_cmd (ext), split_file, ext));
	else
#endif
	  () = insert_file (split_file);

	Info_Split_File_Buffer = whatbuf ();
	setbuf ("*Info*");
     } 
    
   !if (strlen(file)) return;
   info_find_file(file);
   goto_line(n); bol();
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
   !if (Forward_Stack_Depth)
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
   !if (Forward_Stack_Depth) return;
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
   variable the_node, file, n, len;
   n = 0;
  
   % Replace \n and \t characters in name by spaces
   node = strcompress (node, " \t\n");
   info_record_position();
   ERROR_BLOCK 
     {
%	if (bufferp(" *Info*")) delbuf(" *Info*");
	sw2buf("*Info*");
	info_mode ();
     }
   
   len = strlen(node);
  % if it looks like (file)node, extract file, node
  
   if (is_substr(node, "(") == 1) n = is_substr(node, ")");
  
   if (n)
     {
	the_node = node;
	node = substr(the_node, n + 1, strlen(node));
	the_node = strsub(the_node, n, 0);  % truncate string
	file = substr(the_node, 2, n);
	if (bufferp(Info_Split_File_Buffer)) delbuf(Info_Split_File_Buffer);
	Info_Split_File_Buffer = Null_String;
	ERROR_BLOCK
	  {
	     find_dir;
	     if (bol_fsearch(sprintf("* %s:",  file)))
	       {
		  follow_current_xref;
		  _clear_error;
	       }
	  }
	info_find_file(file);
     }
   
   node = strtrim (node);
   !if (strlen(node)) node = "Top";
   widen();
   push_spot_bob ();
   !if (info_search_marker(1)) error("Marker not found.");
   go_down_1 ();
   if (looking_at("Indirect:"), pop_spot())
     {
	Info_Split_Filename = Info_This_Filename;
	info_find_node_split_file(node);
     }
   else info_find_node_this_file(node);
   sw2buf("*Info*");
}

% If buffer has a menu, point is put on line after menu marker if argument
% is non-zero, otherwise leave point as is.
% signals error if no menu.
define info_find_menu(save)
{
   variable menu_re = "^\\c\\* Menu:";
   push_spot_bob ();

  
   !if (re_fsearch(menu_re))
     {
	pop_spot();
	error ("Node has no menu.");
     } 
	
   
   !if (save) 
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
	if ((bolp() and looking_at ("* ")) or re_looking_at("\\C\\*note"))
	  {
	     if (re_looking_at("\\C^* menu")) continue;
	     exchange_point_and_mark;
	     break;
	  }
     }
   pop_mark_1;
}


% Move the cursor to the start of the previous nearest menu item or
% note reference in this node if possible.
define prev_xref ()
{
   push_mark (); go_left_1 ();
   for (; bsearch_char('*'); bskip_chars("*"))
     {
	if ((bolp() and looking_at ("* ")) or re_looking_at("\\C\\*note"))
	  {
	     if (re_looking_at("\\C^* menu")) continue;
	     exchange_point_and_mark;
	     break;
	  }
     }
   pop_mark_1;
}


% menu references

define follow_current_xref ()
{
   variable node;
   
   push_spot();
  
   !if (fsearch_char (':'))
     {
	pop_spot(); error ("Corrupt File?");
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
	     go_down_1;
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
   !if (ffind_char(':')) error ("Corrupt File?");

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
	skip_chars("\d032-\d043\d045\d047-\d255");
	 
        bskip_chars(" ");
     }
   info_find_node(bufsubstr(()));
}

define menu ()
{
   variable node, colons, colon;
   node = Null_String;
   colon = ":"; colons = "::";
  
   if ((LAST_CHAR == '\r') and re_looking_at ("\\C*Note[ \t\n]"))
     {
	go_right (5); skip_chars (" \t\n");
	follow_current_xref ();
	return;
     }
   
   info_find_menu (0);
  
   bol ();

   if (looking_at("* ")
       and (ffind(colon)))
     {
	push_mark();
	bol(); go_right(2);
	node = bufsubstr() + colon;
	bol ();
     }

   !if (strlen (node) and (LAST_CHAR == '\r'))
     {
	node = read_mini("Menu item:", node, Null_String);
	info_find_menu (1);
     }

   !if (bol_fsearch("* " + node)) error ("Menu Item not found.");
   follow_menu;
}
   
define find_dir() 
{
   if ("*Info*" == whatbuf())
     {
	"* " + path_sans_extname(info_extract_pointer("File"));
	info_find_node ("(DIR)top");
	() = bol_fsearch();
     }
   else
     info_find_node ("(DIR)top");
}


define info_extract_pointer()
{
   variable name, errorname = NULL;
   if (_NARGS == 2) errorname = ();
   push_spot_bob;
   go_down_1;
   variable length =  re_bsearch(() + ":");
   if (length) go_right(length - 1);
   else
     {
	pop_spot;
	if (errorname != NULL) error ("node has no " + errorname);
	else return "";
     }
   skip_white();
   push_mark();
   skip_chars("\d032-\d043\d045-\d255");
   bskip_white();
   bufsubstr();
   pop_spot;
}

define info_up ()
{   
   variable upnode = info_extract_pointer("Up");
   if(upnode == NULL or upnode == "(dir)")
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
   "&Report Bug",   ". mail \"Paul <p.boekholt\" \"no\" \"spam\" pop pop \"@hetnet.nl>\" + insert";
   "&Add Bookmark", "info->add_bookmark";
   "&Help",	"info->tutorial";
   "&outline view", "infotree";
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
!if (keymap_p($2))
{
   make_keymap($2);
   $1 = _stkdepth;
   "info->quick_help",		"?";
   "info->tutorial",		"h";
   "info->tutorial",		"H";
   "info->menu",		"^M";
   "info->menu",		"M";
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
   "infotree",			"o";
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
	go_right_1;
	skip_white;
	follow_current_xref;
     }
   else if (bfind("http://"))
     {
	push_mark;
	go_right(7);
	skip_chars("-a-zA-Z0-9~/.+&#=\\?");
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
   dfa_enable_highlight_cache(mode +".dfa", mode);
   % this should highlight both long and short menu items,
   % but not the *menu: line
   dfa_define_highlight_rule ("^\\*[^:]+:[: ]", "keyword0", mode);
   dfa_define_highlight_rule ("\\*[Nn]ote", "Qkeyword0", mode);
   dfa_define_highlight_rule 
     ("http://[\\-a-zA-Z0-9~/\\\.\\+&#=\\?]+[a-zA-Z0-9/]",
      "keyword0", mode);
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
public define info_mode ()
{
   variable ibuf; ibuf = "*Info*";
   if (Info_Stack_Depth) 
     pop_position ();
   !if (bufferp(ibuf)) find_dir();
   sw2buf(ibuf);
   onewindow();
   mode_set_mode_info("info", "init_mode_menu", &info_mode_menu);
   set_mode("info", 0);
#ifdef HAS_DFA_SYNTAX
   use_syntax_table("info");
#endif
   run_mode_hooks ("info_mode_hook");
   set_buffer_hook("mouse_up", &mouse_hook);
   define_blocal_var("generating_function", ["info_mode"]);
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
   variable n;
   variable word;
   
   push_mark ();
   ref = strcompress(strlow(ref), " ");
   
   go_down_1;
   eol;
   exchange_point_and_mark;
   not strncmp(strcompress(strlow(bufsubstr()), " \t\n"), ref, strlen(ref));
}

define follow_reference ()
{
   variable colon, colons, note, err, item, node, ref;
   colon = ":"; colons = "::";
   note = "*Note";
   err = "No cross references.";
   
   push_spot_bob();
   fsearch(note);
   pop_spot;
   !if ()
     error(err);
  
   ref = read_mini("Follow *Note", Null_String, Null_String);
   push_spot_bob ();
   forever
     {
	!if (fsearch(note))
	  {
	     pop_spot();
	     error ("Bad reference.");
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
   variable node;  node = Null_String;
   variable n;
  
   n = LAST_CHAR;
   if ((n < '1') or (n > '9')) return (beep());
   n -= '0';
  
   info_find_menu(1);

   while (n)
     { 
	!if (bol_fsearch("* ")) return (beep());
	if (ffind(":")) --n; else eol();
     }
   bol;
   follow_menu;

}

%}}}

%{{{ scrolling

define next_up();
variable indent = 0; % used by infotree
define next_up()
{
   variable pointer;
   pointer = info_extract_pointer("Node");
   if (string_match(info_extract_pointer("Node"), ".*Index$", 1))
     {
	error ("this is the end");
     }
   ERROR_BLOCK
     {
	_clear_error;
	indent--;
	pointer = info_extract_pointer("Up");
	if (pointer == NULL)
	  error ("this is the end");
	else
	  {
	     if (pointer == "Top") error ("this is the end");
	     info_find_node(pointer);
	     next_up;
	  }
     }
   pointer = info_extract_pointer("Next");
   if (pointer == "Top") error ("this is the end");
   info_next;
}

define scroll()
{
   ERROR_BLOCK
     {
	_clear_error;
	next_up;
     }
   loop(1)
     {
	ERROR_BLOCK
	  {
	     _clear_error;
	     % indexes have a menu, we don't want to cycle forever
	     if (string_match(info_extract_pointer("Node"), ".*Index$", 1))
	       {
		  error ("this is the end");
	       }
	     info_find_menu(1);
	     () = bol_fsearch("* ");
	     follow_menu;
	  }
	call("page_down");
     }
}


%}}}

%}}}

provide("infospace");
provide("info");

% diff_mode.sl -*- mode: Slang; mode: fold -*-
%
%%exts:%% diff, patch

% Unified diff mode viewer and editor for Jed %{{{
%
% Written by Dino Leonardo Sangoi <dino@trieste.linux.it> on a shiny day.
%
% It does highlighting a bit like mcedit (the midnight commander editor) does.
% (It uses dfa syntax highlighting).
%
% It also helps editing diffs, usually an unsafe operation. Not that you
% can do it blindly now, but at least this script can rebuild diff markers
% after editing. You can also remove a whole block, adjusting the offsets
% accordingly. Since version 2.1 you can also apply just one block.
%
% Editing works only on unified diffs right now, and probably forever (mostly
% because I always use unified diffs).
%
% Versions
% --------
%
% 1.0.0pre2 2005-10-10 by sangoid
% 2.0       2007-04-27 "Jedmodes" branch by GM <milde users.sf.net>
%    * set default colors re-using existing color definitions
%      (better defaults for non-black color schemes but still customisable)
%    * removed pre Jed 0.99.16 compatibility hack
%    * diff_top_of_file(), diff_top_of_block(): try below if there is no top
%      above -> lets diff_jump_to() also work from the top of the diff buffer
%    * diff_jump_to(): ask for path if file not found
%    * new: diff_jump() (after a patch by Lechee Lai)
% 2.1   2007-07-21
%    * frontend commands: diff(), diff_buffer(), diff_dir_files()
%    * use of walk.sl now optional
% 2.1.1 2007-07-24 bugfix in diff_buffer, documentation fix
% 2.1.2 2007-07-27 bugfix: diff_jump_to(): pop_spot after computing destination
% 2.2   2007-09-03
%    * highlight trailing whitespace (too often this makes all of the difference)
%    * bugfixes after report by P. Boekholt:
%       - use of diff() before declaration
%       - hidden dependency on shell_command()
%       - spurious arg to pop2puf() in diff()
%       - test for files in both dirs in diff_dir_files()
% 2.2.1 2007-10-01 optional extensions with #if ( )
% 2.2.2 2007-10-04 no DFA highlight in UTF-8 mode (broken for multi-byte chars)
% 		   enable it with enable_dfa_syntax_for_mode("Diff");
% 2.2.3 2007-10-23 switch on highlight caching
% 2.3   2007-12-20 standard color-name "trailing_whitespace"
% 		   implement Jörg Sommer's fix for DFA highlight under UTF-8
% 2.3.1 2009-01-26 don't hightlight whitespace in first (diff's ±) column
%
% Usage
% -----
%
% Put diffmode.sl, treemode.sl, (and optionally walk.sl) in your
% Jed library path (cf. get_jed_library_path()).
%
% Add to your .jedrc or jed.rc file something like
%
%        autoload("diff_mode", "diffmode");
%        add_mode_for_extension("diff", "diff");
%        add_mode_for_extension("diff", "patch");
%
% and every file with extension '.diff' or '.patch' will automagically
% get the "diff" mode applied.
%
% Customization
% -------------
%
% Optionally you can set these variables:
%
% Diff_Use_Tree   -> whether to use the (experimental) tree mode viewer for
%                    patches containing more than one file. If zero, tree mode
%                    is not used, else the value is the minimum number of files
%                    needed inside a patch to trigger the tree mode viewer.
%                    (default = 4, just a randomly choosen number)
%
% DiffTree_Indent -> how much to indent lines in tree mode viewer. Default = 8
%
% You can customize the syntax highlight colors for "diff_block", "diff_junk",
% "diff_deleted", "diff_added", "diff_oldfile", "diff_newfile", "diff_cmd" in
% jed.rc, e.g.
%
%        set_color("diff_deleted", "blue", "red");
%
% Thanks to:
% - John Davis, for this great editor.
% - Abraham van der Merwe, I took some ideas (and maybe also some code...)
%                          from his diff.sl.
% - Guenter Milde, for the long emails we exchanged about jed modes (and for
%                 a lot of slang code I'm using)
%}}}

% Requirements
% ------------
%{{{

% Jed >= 0.99.16     % custom_color()
% S-Lang 2	     % "raw string literal"R
require("keydefs");  % standard mode, not loaded by default
require("treemode"); % bundled with diffmode

% Use walk.sl (for returning to buffers) if it is found in the library path
% Alternatively, http://jedmodes.sf.net/mode/navigate can be used for this.
#if (expand_jedlib_file("walk.sl") != "")
require("walk");
#endif

#if (expand_jedlib_file("bufutils.sl") != "")
autoload("bufsubfile", "bufutils.sl");
#endif

%}}}

% Customizable settings
% ---------------------
%{{{

% Set Diff_Use_Tree to 0 to avoid using a tree view for the diff.
% Otherwise, set it to the minimun number of files covered by the diff
% needed to use the tree view.
custom_variable("Diff_Use_Tree", 4);
custom_variable("DiffTree_Indent", 8);
% should tree pack single child nodes?
custom_variable("DiffTree_Pack", 1);

custom_variable("Diff_Cmd", "diff -u"); % command for diff-s

% Default color scheme

custom_color("diff_cmd",     get_color("operator"));    % diff
custom_color("diff_oldfile", get_color("bold"));        % ---
custom_color("diff_newfile", get_color("number"));      % +++
custom_color("diff_block",   get_color("preprocess"));  % @@
custom_color("diff_deleted", get_color("error"));       % -
custom_color("diff_added",   get_color("keyword"));     % +
custom_color("diff_junk",    get_color("comment"));     % Only / Binary
%}}}

%%%% Diff low level helpers %{{{

% return true if I'm looking_at() a header marker.
static define _diff_is_marker()
{
	orelse
	{ looking_at("+++ ") }
	{ looking_at("--- ") }
	{ looking_at("diff ") }
	{ looking_at("Only in ") }
	{ looking_at("Binary files ") };
}

% extract information from a block header line: returns:
% (position on old file, length on old file, position on new file, length on new file)
% [ this heavily uses the stack features of slang ].
static define _diff_parse_block_info(l)
{
	variable pos, len;

	% Uhmm, there's a better way to do this?
	if (string_match(l, "@@ \-\(\d+\),\(\d+\) \+\(\d+\),\(\d+\) @@"R, 1) == 0)
		error("malformed block header <"+l+">");

	(pos, len) = string_match_nth(1);
	integer(l[[pos:pos+len-1]]);
	(pos, len) = string_match_nth(2);
	integer(l[[pos:pos+len-1]]);
	(pos, len) = string_match_nth(3);
	integer(l[[pos:pos+len-1]]);
	(pos, len) = string_match_nth(4);
	integer(l[[pos:pos+len-1]]);
	%   return (oldpos,oldlen,newpos,newlen)
}

% count the added, deleted, and common lines in a block (is up to the caller
% to narrow a region to a block, and to put the point at the start).
% returns (added lines, deleted lines, common lines)
static define _diff_count_block()
{
	variable countplus = 0;
	variable countminus = 0;
	variable countspace = 0;

	while (down_1) {
		bol();
		if (eobp)
			break;
		switch(what_char())
		{ case '+' : countplus++; }
		{ case '-' : countminus++; }
		{ countspace++; }
	}
	return (countplus, countminus, countspace);
}

% skip a marker in the given direction (dir = 1 -=> down, dir = -1 -=> up)
static define _diff_skip_header(dir)
{
	variable f = &up_1;

	if (dir > 0)
		f = &down_1;

	while (bol(), _diff_is_marker())
		!if (@f())
			break;
}
%%%%}}}

%%%% Fast movement functions: these are a bit like c_{top,end}_of_function(). %{{{

% Go to the top of diffed file
define diff_top_of_file()
{
   % push mark instead of spot to be able to pop it without going there
	push_mark();
	% search the diff marker.
	if (andelse{bol_bsearch("--- ") == 0}{bol_fsearch("--- ") == 0}) {
		pop_mark(1);
		error("start of file not found.");
	}
	% found, see if there's a diff command line before.
	if (up_1()) {
		bol();
		if (looking_at("diff ") == 0)
			go_down_1();
	}
	pop_mark(0);
}

% Go to the end of diffed file
define diff_end_of_file()
{
	% Skip Junk AND first marker
	go_down_1();
	_diff_skip_header(1);

	if (bol_fsearch("--- ") == 0) {
		% I can only assume this is the last file-block.
		eob();
		% if point is on a void line, this is the last line in the file, so
		% skip it.
		if (bolp())
			go_up_1();
	}
	_diff_skip_header(-1);
	go_down_1();
}

% Go to the top of diffed block
define diff_top_of_block()
{
	push_mark();
	if (andelse{bol_bsearch("@@ ") == 0}{bol_fsearch("@@ ") == 0}) {
		pop_mark(1);
		error("start of block not found.");
	}
	pop_mark(0);
}

% Go to the end of diffed block
define diff_end_of_block()
{
	% Skip Junk
	_diff_skip_header(1);
	go_down_1();

	if (bol_fsearch("@@ ") != 0) {
		go_up_1;
		_diff_skip_header(-1);
		go_down_1;
	} else {
		% uhm, maybe this is the last block
		diff_end_of_file();
	}
}
%%%%}}}

%%%% Mark and narrow blocks %{{{
% mark the current file. if 'skipheader' is != 0, don't mark the header.
define diff_mark_file(skipheader)
{
	% if the point is in a header, mark the *next* file, not the previous.
	_diff_skip_header(1);

	diff_top_of_file();
	if (skipheader)
		_diff_skip_header(1);

	push_visible_mark();
	diff_end_of_file();
}

% mark the current block.
define diff_mark_block(skipheader)
{
	% if the point is in a header, mark the *next* block, not the previous.
	!if (looking_at("@@ "))
		diff_top_of_block();

	if (skipheader) {
		go_down_1();
		bol();
	}

	push_visible_mark();
	diff_end_of_block();
}

% mark the +++ --- header lines
static define mark_file_header()
{
   diff_top_of_file();
   push_visible_mark();
   _diff_skip_header(1);
}

% narrows the current file.
define diff_narrow_to_file(skipheader)
{
	diff_mark_file(skipheader);
	eol();
	!if (eobp())
		go_up_1(); % don't get the last line
	narrow();
}

% narrows the current block.
define diff_narrow_to_block(skipheader)
{
	diff_mark_block(skipheader);
	eol();
	!if (eobp())
		go_up_1(); % don't get the last line
	narrow();
}
%%%%}}}

%%%% Redo diff markers after editing %{{{

% Rewrite a block header after editing it. 'old_off' is the offset to apply
% to line numbers for 'old' side. 'new_off' is the offset to apply to line
% numbers on the 'new' side.
% returns two values: old_off and new_off modified accordinly to changes on
% this block (so returned values can be passed again to diff_redo_block for
% the next block in this file.
define diff_redo_block(old_off, new_off)
{
	variable countminus = 0;
	variable countplus = 0;
	variable countspace = 0;
	variable oldpos, oldsize, newpos, newsize;
	variable c;
	variable oldheader, newheader;

	push_spot();
	diff_narrow_to_block(0);
	bob();
	oldheader = line_as_string();
	(oldpos, oldsize, newpos, newsize) = _diff_parse_block_info(oldheader);

	(countplus, countminus, countspace) = _diff_count_block();
	countplus += countspace;
	countminus += countspace;
	newheader = sprintf("@@ -%d,%d +%d,%d @@", oldpos+old_off, countminus, newpos+new_off, countplus);
	flush(sprintf("@@ -%d,%d +%d,%d @@   -->   %s", oldpos, oldsize, newpos, newsize, newheader));

	if (strcmp(oldheader, newheader) != 0) {
		bob();
		delete_line();
		insert(newheader + "\n");
	}
	widen();
	pop_spot();
	return (old_off + countminus - oldsize, new_off + countplus - newsize);
}

% redo all blocks of this file, starting at block containing the cursor.
static define _diff_redo_from_here(oldoff, newoff)
{
	variable done;

	diff_end_of_block();
	diff_top_of_block();

	do {
		(oldoff, newoff) = diff_redo_block(oldoff, newoff);
		diff_end_of_block();
	} while (looking_at("@@ "));
}

% redo all blocks on this file.
define diff_redo_file()
{
	push_spot();
	diff_narrow_to_file(0);

	bob();
	_diff_redo_from_here(0, 0);
	widen();
	pop_spot();
}
%%%%}}}

%%%% Remove junk routines %{{{

% Remove "Only in..." lines (from diffs without -N)
define diff_remove_only_lines()
{
	push_spot();
	bob();
	while (bol_fsearch("Only in "))
		delete_line();
	pop_spot();
}

% Remove "Binary files..." lines
define diff_remove_binary_lines()
{
	push_spot();
	bob();
	while (bol_fsearch("Binary files "))
		delete_line();
	pop_spot();
}

define diff_remove_junk_lines()
{
	diff_remove_only_lines();
	diff_remove_binary_lines();
}
%%%%}}}

%%%% Remove block, optionally rebuilding markers %{{{

define diff_remove_block(redo)
{
	variable countplus, countminus;

	push_spot();
	% Ensure that we don't cross a file-block boundary
	diff_narrow_to_file(0);
	pop_spot();
	eol();
	diff_narrow_to_block(0);
	diff_top_of_block();
	% calculate deltas to apply to following blocks
	(countplus, countminus, ) = _diff_count_block();
	mark_buffer();
	del_region();
	widen(); % block

	if (eobp()) {
		if (what_line <= 4) {
			% This is the last block in this file, delete also the file header
			mark_buffer();
			del_region();
		}
	} else {
		if (redo) {
			push_spot();
			diff_end_of_block();
			_diff_redo_from_here(0, countminus-countplus);
			pop_spot();
		}
	}

	widen(); % file
	% All this leaves an extra void line, kill it
	!if (eobp())
		delete_line();
	% place the point at the beginning of the next block
	!if (looking_at("@@ ")) {
		diff_end_of_block();
		diff_top_of_block();
	}
}

% remove a whole file block (far easier than a single block)
define diff_remove_file()
{
	diff_mark_file(0);
	del_region();
}

% Get path of source file (If 'new' is true, new file, else old file.
define diff_get_source_file_name(new)
{
   variable marker, endcol, name;
   if (new)
     marker = "+++ ";
   else
     marker = "--- ";
   push_spot(); % save current position
   diff_top_of_file();
   () = bol_fsearch(marker);
   name = line_as_string();
   endcol = is_substr(name, "\t") - 2;
   name = name[[4:endcol]];
   pop_spot(); % restore point position
   !if (file_status(name) == 1)
     name = read_with_completion("Please adjust path:", "", name, 'f');
   return name;
}

% apply just one block
#ifexists bufsubfile
define diff_apply_block()
{
   variable patchfile, oldfile = diff_get_source_file_name(0);
   variable buf = whatbuf();
   push_spot();
   mark_file_header();
   patchfile = bufsubfile();
   pop_spot();
   push_spot();
   diff_mark_block(0);
   () = append_region_to_file(patchfile);
   do_shell_cmd(sprintf("patch %s %s", oldfile, patchfile));
   pop2buf(buf);
   pop_spot();
   diff_remove_block(1);
}
#endif

%%%%}}}

%%%% Standard mode things: keymap, syntax, highlighting %{{{
private variable mode = "Diff";

define diff_add_saurus_bindings()
{
	definekey("diff_top_of_file", Key_Shift_F11, mode);
	definekey("diff_end_of_file", Key_Shift_F12, mode);
	definekey("diff_top_of_block", Key_Ctrl_F11, mode);
	definekey("diff_end_of_block", Key_Ctrl_F12, mode);
	definekey("(,) = diff_redo_block(0,0)", Key_F12, mode);
	definekey("diff_redo_file()", Key_F11, mode);
	definekey("diff_remove_block(1)", Key_F8, mode);
	definekey("diff_remove_only_lines()", Key_F9, mode);
	definekey("diff_jump_to(1)", "^V", mode);
        definekey("diff_jump", "\r", mode);  % Return: "intelligent" jump
	%% Other Functions
	% diff_mark_file(skipheader);
	% diff_mark_block(skipheader);
	% diff_narrow_to_file(skipheader);
	% diff_narrow_to_block(skipheader);
}

!if (keymap_p(mode)) {
	make_keymap(mode);
	diff_add_saurus_bindings();
}

create_syntax_table(mode);


% Highlighting 
% ------------

% NEEDS dfa for this mode to work.

#ifdef HAS_DFA_SYNTAX

dfa_define_highlight_rule("^diff .*",      "diff_cmd",     mode);
dfa_define_highlight_rule("^\+\+\+ .*"R,   "diff_newfile", mode);
dfa_define_highlight_rule("^--- .*",       "diff_oldfile", mode);
% + or - eventually followed by something ending in non-whitespace:
dfa_define_highlight_rule("^\\+(.*[^ \t])?",  "diff_added",   mode);
dfa_define_highlight_rule("^-(.*[^ \t])?",    "diff_deleted", mode);
%
dfa_define_highlight_rule("^Only .*",      "diff_junk",    mode);
dfa_define_highlight_rule("^Binary .*",    "diff_junk",    mode);
dfa_define_highlight_rule("^@@ .*",        "diff_block",   mode);
% non-unified diffs:
dfa_define_highlight_rule("^> .*",         "diff_added",   mode);
dfa_define_highlight_rule("^< .*",         "diff_deleted", mode);
% trailing whitespace
dfa_define_highlight_rule("^ $",           "Qnormal",   mode); % not in the first column
dfa_define_highlight_rule("[ \t]+$",       "Qtrailing_whitespace",   mode);
% render non-ASCII chars as normal to fix a bug with high-bit chars in UTF-8
dfa_define_highlight_rule("[^ -~]+", "normal", mode);

dfa_build_highlight_table(mode);
enable_dfa_syntax_for_mode(mode);

#endif
%%%%}}}

%%%% Jump to functions %{{{

% Open diff source file. If 'new' is true, open the new version, else open the
% old version.
define diff_jump_to(new)
{
	variable name, pos, newpos;
	variable delta = what_line();
	% TODO: Improve computation of line to jump to.
        % Eventually consider manually added and removed lines while computing
        % delta (or manually call diff_redo_file() befor jumping).
#ifexists walk_forward
	walk_mark_current_position();
#endif
	push_spot(); % save current position
	diff_top_of_block();
	delta -= what_line();
	line_as_string(); % on stack
	(pos, , newpos, ) = _diff_parse_block_info();
	if (new)
     	   pos = newpos;
	pos += delta;
        name = diff_get_source_file_name(new);
	pop_spot();
	() = read_file(name);
	goto_line(pos);
	vmessage("%s:%d", name, pos);
#ifexists walk_forward
	walk_goto_current_position();
	walk_store_marked_position();
#else
     	sw2buf(whatbuf());
#endif
}

%%%%}}}

%%%% Jump to "right" source, ('+' to new, '-' to old) %{{{
define diff_jump()
{
   variable ch;
   push_spot();
   bol();
   ch = what_char();
   pop_spot();
   switch (ch)
     { case '-': diff_jump_to(0); }
     { case '+': diff_jump_to(1); }
   % { message ("not on a -/+ marked line"); }
     { diff_jump_to(0); } % there is a binding for jump_to(1)
   % TODO: ask in minibuffer for new/old?
}
%%%%}}}

%%%% Menu %{{{
%%%%

% Adds to the assoc array 'names' all the file names in this diff
% (taking the 'new' versions, i.e. those with '+++').
% key is the name, value is the line in diff where the file-block starts.
static define _get_files_names(names, func)
{
	variable s;

	bob;
	while (bol_fsearch("+++ ")) {
		% grab the name
		goto_column(5);
		push_mark();
		if (ffind("\t") == 0)
			eol();
%			error("invalid diff");
		s = bufsubstr();
		% find the top of this block, to get the correct line number.
		push_spot();
		_diff_skip_header(-1);
		go_down_1();
		names[s] = @func;
		pop_spot();
	}
}

static define get_files_names(names)
{
	_get_files_names(names, &what_line);
}

static define get_files_names_as_marks(names)
{
	_get_files_names(names, &create_user_mark);
}

% Adds to the assoc array 'names' all lines containing
% "Only in " and "Binary files " lines.
% (taking the 'new' versions, i.e. those with '+++').
% key is the name, value is -1 (we don't care where these are)
% TODO: Add those as 'real' files to tree, do some parsing to get the full
%       name from 'Only in', and pick  only the first (or last?) name in
%       'Binary files'.
static define get_files_markers(names)
{
	variable s;

	bob;
	while (re_fsearch("^[OB][ni][ln][ya][ r][iy][n ][ f]")) {
		if (looking_at("Only in ") or looking_at("Binary files ")) {
			push_mark();
			eol;
			s = bufsubstr();
			names[s] = -1;
		}
	}
}

static define files_popup_callback(popup)
{
	variable key, line, names = Assoc_Type[Int_Type];

	push_spot();
	get_files_names(names);
	pop_spot();

	variable keys = assoc_get_keys(names);
	keys = keys[array_sort(keys)];
	foreach key (keys)
	{
		line = names[key];
		menu_append_item(popup, key, &goto_line, line);
	}
}

public define diff_init_menu(menu)
{
	menu_append_popup(menu, "&File Blocks");
	menu_set_select_popup_callback(strcat(menu, ".&File Blocks"), &files_popup_callback);

	menu_append_separator(menu);
	menu_append_item(menu, "&top of block",      "diff_top_of_block");
	menu_append_item(menu, "&end of block",      "diff_end_of_block");
	menu_append_item(menu, "&Top of file block", "diff_top_of_file");
	menu_append_item(menu, "&End of file block", "diff_end_of_file");
	menu_append_separator(menu);
	menu_append_item(menu, "&mark block",      "diff_mark_block", 0);
	menu_append_item(menu, "&Mark file block", "diff_mark_file", 0);
#ifexists bufsubfile
	menu_append_item(menu, "&Apply block",     "diff_apply_block");
#endif   
	menu_append_item(menu, "&Delete Block",    "diff_remove_block", 1);
	menu_append_separator(menu);
	menu_append_item(menu, "Goto &old file", "diff_jump_to", 0);
	menu_append_item(menu, "Goto &new file", "diff_jump_to", 1);
	menu_append_separator(menu);
	menu_append_item(menu, "Re&write block &header",
	                       "(,) = diff_redo_block(0,0)");
	menu_append_item(menu, "Re&Write all headers",  "diff_redo_file");
	menu_append_item(menu, "Delete &junk lines",  "diff_remove_junk_lines");
	menu_append_item(menu, "&Rerun diff",  "diff_rerun");
	menu_append_item(menu, "Rerun re&versed",  "diff_rerun_reversed");
}

%%%%}}}

%%%% Tree View %{{{

% This variable contains a mark considered not valid
static variable InvMark;

define difftree_goto_pos()
{
	variable l = what_line, mode;
	variable li;

	li = tree_elem_get_data();

	if (li == NULL)
		error("diffmode: cannot show this item.");

	if (li == InvMark)
		error("diffmode: mark");

#ifexists walk_forward
	walk_mark_current_position();
#endif
	setbuf(user_mark_buffer(li));
	widen();  % just in case...
	goto_user_mark(li);
	diff_narrow_to_file(0);
	bob;

#ifexists walk_forward
   	walk_goto_current_position();
	walk_store_marked_position();
#endif
}

define difftree_goto_pos_event(event)
{
	difftree_goto_pos();
	return 1;
}

% Recursive function:
% for every row of 'aa' between 'start' and 'end', check the element
% at column 'depth', until finds a different element.
static define _build_section(base, aa, start, end, depth, km);
static define _build_section(base, aa, start, end, depth, km)
{
	variable child = "    ";
	variable i, firststart = start;

	flush("depth " +string(depth)+", range ["+string(start)+":"+string(end)+"]");
	for (i = start; i < end; i++) {
		if (aa[start][depth] != aa[i][depth]) {
			% this element is different
			% insert base
			if (base != "")
				tree_add_element(child, base, InvMark);
			base = aa[start][depth];
			if (depth == length(aa[start])-1)
				% this is the last element in this row, insert it.
				tree_add_element(child, base, km[start]);
			else
				% run on next depth
				_build_section(base, aa, start, i, depth+1, km);
			% turn back to parent, clear base, and set new start.
			() = tree_goto_parent();
			base = "";
			start = i;
		}
	}
	% here we are at the end of our run, handle the last element
	if ((firststart == start) and DiffTree_Pack) {
		% all the block has the same column, pack it with the next
		if (base != "")
			base += "/";
		base += aa[start][depth];
	} else {
		% put base on tree
		if (base != "")
			tree_add_element(child, base, InvMark);
		base = aa[start][depth];
	}
	if (depth == length(aa[start])-1)
		tree_add_element(child, base, km[start]);
	else
		_build_section(base, aa, start, end, depth+1, km);
	% goto parent, but not if I have packed the tree.
	!if ((firststart == start) and DiffTree_Pack)
		() = tree_goto_parent();
}

% fill the tree
static define insert_lines(names, marks)
{
	variable i = 0;
	variable count = 0;
	variable oldnode, node;
	variable aa;
	variable depth = 0;   % 'depth' is the element for every line that
	% _build_section() should handle.

	variable I;           % array sort index.
	variable ks = assoc_get_keys(names); % only the names.
	variable km = assoc_get_values(names);

	% sort the names,keeping ks and km in synch
	I = array_sort(ks);
	ks = ks[I];
	km = km[I];

	% SLang powerfulness: build an array of arrays containing each
	% a path element. e.g. if:
	% ks[0] == "/home/sauro/.jedrc"
	% ks[1] == "/home/sauro/.jed/home-lib.sl"
	% this builds:
	% aa[0] = [ "", "home", "sauro", ".jedrc" ]; (length = 4)
	% aa[1] = [ "", "home", "sauro", ".jed", "home-lib.sl" ]; (length = 5)
	% note the first void element, this is because of absolute paths
	% but usually patches use relative ones
	aa = array_map(Array_Type, &strchop, ks, '/', 0);
	% handle absolute paths, setting 'depth' to 1 to tell
	% _build_depth() to skip first column
	if (strcmp(aa[0][0], "") == 0)
		depth = 1;
	%%%   tree_set_user_datatype(Integer_Type);
	InvMark = create_user_mark();
	_build_section("", aa, 0, length(aa), depth, km);

	% that's all folks.
}

public define difftree()
{
	variable names = Assoc_Type[Mark_Type];
	variable marks = Assoc_Type[Int_Type];
	variable diffbuf, difftreebuf;

	get_files_names_as_marks(names);
	get_files_markers(marks);

	diffbuf = whatbuf();
	difftreebuf = "*tree of "+diffbuf+"*";
	if (bufferp(difftreebuf))
		delbuf(difftreebuf);
	setbuf(difftreebuf);
	tree_mode();
	tree_set_user_datatype(Mark_Type);
	if (tree_build_kmap("TreeDiff")) {
		definekey("tree_open(1)",  "[", "TreeDiff");
		definekey("tree_close(1)", "]", "TreeDiff");
		definekey("tree_toggle(0)", " ", "TreeDiff");
		definekey("difftree_goto_pos", "^M", "TreeDiff");
	}
	insert_lines(names, marks);

	sw2buf(difftreebuf);

	tree_set_user_func(&difftree_goto_pos_event, TREE_TOGGLE);
	use_keymap("TreeDiff");
	run_mode_hooks("difftree_mode_hook");
}
%%%%}}}

static define check_num_files(c)
{
	bob();
	while ((not eobp()) and (c > 0)) {
		diff_end_of_file();
		c--;
	}
	bob();
	return c;
}

public define diff_mode()
{
	set_mode(mode, 0);
	use_syntax_table(mode);
	use_keymap(mode);
	mode_set_mode_info(mode, "init_mode_menu", &diff_init_menu);
	set_buffer_undo(1);
	run_mode_hooks("diff_mode_hook");
	if ((Diff_Use_Tree > 0) and (check_num_files(Diff_Use_Tree) == 0)) {
		flush("Building diff tree...");
		difftree();
		flush("Building diff tree... Done.");
	}
}

% Frontend commands
% -----------------
%{{{
% diff 'wizard': call diff system command and display result in diff_mode
public define diff() % (old, new)
{
   variable old, new;
   (old, new) = push_defaults( , , _NARGS);
   variable prompt = sprintf("Compare (%s) ", Diff_Cmd);
   if (old == NULL)
     old = read_with_completion(prompt, "", "", 'f');
   if (new == NULL)
     new = read_with_completion(prompt + old + " to", "", "", 'f');

   % Prepare the output buffer
#ifexists popup_buffer
   popup_buffer("*diff*", 1.);  % use up to 100% of screen size
#else
   pop2buf("*diff*");
#endif
   set_readonly(0);
   erase_buffer();

   % call the diff command
   flush("calling " + Diff_Cmd);
   shell_perform_cmd(strjoin([Diff_Cmd, old, new], " "), 1);
   set_buffer_modified_flag(0);
   if (bobp() and eobp())
     {
	close_buffer();
	message("no differences found");
        return;
     }
   fit_window(get_blocal("is_popup", 0));
   diff_mode();
   define_blocal_var("generating_function", [_function_name, old, new]);
}

% save the buffer to a tmp file and get the diff to a second file
#ifexists bufsubfile
public define diff_buffer()
{
   variable prompt = sprintf("Compare (%s) buffer to ", Diff_Cmd);
   variable file1 = read_with_completion(prompt, "", "", 'f');
   variable file2 = bufsubfile();
   diff(file1, file2);
}
# endif

% list the differences between all equally named files in both dir1 and dir2
define diff_dir_files(dir1, dir2)
{
   variable file, cmd;
   dir1 = expand_filename(dir1);
   dir2 = expand_filename(dir2);
   sw2buf("*diff*");
   erase_buffer();
   vinsert("Comparing equally named files in '%s'\n", dir1);
   vinsert("and '%s'\n", dir2);
   foreach file (listdir(dir1))
     {
	if(file_status(path_concat(dir2, file)) != 1)
	  continue; % file does not exist in dir2
	cmd = sprintf("diff -u %s %s",
	   path_concat(dir1, file), path_concat(dir2, file));
	% Insert a separating header for every file pair
	% TODO: Add a syntax highlight rule???
	vinsert("*** diff '%s'\n", file);
	insert("===============================================================\n");
	set_prefix_argument(1);
	do_shell_cmd(cmd);
	eob();
	newline;
     }
   diff_mode;
}
%}}}

%%%% Re-run the diff command %{{{
define diff_rerun()
{
   variable line = what_line(),
   	    oldfile = diff_get_source_file_name(0),
   	    newfile = diff_get_source_file_name(1);
   diff(oldfile, newfile);
   goto_line(line);
}

% swap the order of the diffed files
define diff_rerun_reversed()
{
   variable line = what_line(),
   	    oldfile = diff_get_source_file_name(0),
   	    newfile = diff_get_source_file_name(1);
   diff(newfile, oldfile);
   goto_line(line);
}
%%%%}}}


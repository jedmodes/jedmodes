% Tree viewer for JED.
% -*- mode: SLang; mode: fold -*-
%
% Copyright (C) 2003-2004 by Dino Leonardo Sangoi <g1001863@univ.trieste.it>
% Released under the terms of the GNU GPL (version 2 or later).
%
% Version 1.99b
% $Revision: 26 $
% $Author: sauro $
% $Date: 2005-03-31 22:55:33 +0200 (Thu, 31 Mar 2005) $
% 
% This is not a standalone mode, but is used by other modes that need a 
% tree visualization.
%
%%%implements("Tree");
% _debug_info=1;
_traceback=1;
_boseos_info=3;
	
require("keydefs");

static variable TreeMode = "TreeMode";

% Events
public variable TREE_OPEN   = 1;
public variable TREE_CLOSE  = 2;
public variable TREE_TOGGLE = 4;
public variable TREE_MOVE   = 8;
public variable TREE_OPEN_PLACEHOLDER   = 16;

%{{{ Tree Helpers

% a simple function to set current buffer, and return old buffer
private define whatbuf_setbuf(buf)
{
	whatbuf(); %on stack
	setbuf(buf);
}

% convert all tabs to spaces.
private define _tree_untab_buffer()
{
	push_spot();
	bob();
	push_mark();
	eob();
	untab();
	pop_spot();
}

% run a user defined function on tree actions.
private define _tree_send_event(event)
{
	variable ret = 1;
	variable func = get_blocal_var("TreeEventFunc");
	variable mask;
	
	if (func != NULL) {
		mask = get_blocal_var("TreeEventMask");
		if ((event & mask) > 0) {
			variable umark = create_user_mark();
			ret = @func(event);
			% return to tree buffer, to allow func to move freely around
			setbuf(user_mark_buffer(umark));
			goto_user_mark(umark);
		}
	}
	return ret;
}

% put the point on the tree mark.
private define _tree_goto_line_start()
{
	bol_skip_white();
}
%}}}

%{{{ Private tree functions

% private, fast version of tee_elem_state() (assumes currently on a tree buffer)
private define _tree_elem_state()
{
	bol;skip_white;%_tree_goto_line_start();
	what_char(); 
}

% get start column for this element (i.e. tree depth)
private define _tree_elem_get_column()
{
	bol();
	skip_white();%_tree_goto_line_start();
	what_column();
	% Return value on stack
}

% get element name
private define _tree_elem_get_name()
{
	bol;skip_white;%_tree_goto_line_start();
	push_spot();
	go_right(2);
	push_mark_eol();
	bufsubstr(); % result on stack
	pop_spot();
	% return string on stack
}

% get data attached to this element.
private define _tree_elem_get_data()
{
	variable v = NULL;
	variable treedata = get_blocal_var("TreeUserData");
	
	if (treedata != NULL) {  
		variable pos = what_line() - 1;
		if (pos < treedata.pos)
			v = treedata.array[pos];
	}
	return v;
}
%}}}

%{{{ Private add/remove functions and helpers

% put an element, and the placeholder (if required)
private define __tree_insert_elem(name, col, indent, placeholder)
{
	goto_column(col);
	if (strlen(placeholder) > 0) {
		insert("+ " + name);
		newline();
		goto_column(col+indent);
		insert(". "+placeholder);
		set_line_hidden(1);
	} else 
		insert(". " + name);
}

% low level delete node.
private define _tree_delete_element()
{
	% very simple right now, but keep abstract
	% delete_line();
	% I can't use 'delete_line' as it does weird things with 'line hidden' flag.
	bol();
	del_eol();
	!if (bobp()) { 
		go_left_1(); del(); go_right_1(); 
	} else
		!if (eobp()) del();
}

%}}}

%{{{ Private movement functions
private define _tree_goto_child()
{
	variable col = _tree_elem_get_column();
	variable child = 0;
	
	push_mark();
	if (down(1)) 
		if (_tree_elem_get_column() > col)
			child = 1;
	pop_mark(1 - child);
	
	return child;        
}

% move to next or prev sibling ('move_func' can be &down_1 pr &up_1)
private define _tree_goto_sibling(move_func)
{
	variable col2, col = _tree_elem_get_column();
	variable sibling = 0;
	
	push_mark();
	while (@move_func()) {
		col2 = _tree_elem_get_column();
		if (col2 == col) sibling = 1;
		if (col2 <= col) break;
	}
	pop_mark(1 - sibling);
	
	return sibling;
}

private define _tree_goto_parent()
{
	variable col = _tree_elem_get_column();
	variable parent = 0;
	
	push_mark();
	while (up(1))
		if (_tree_elem_get_column() < col) {
			parent = 1;
			break;
		}
	pop_mark(1 - parent);
	
	return parent;
}

% this is a low level function that skips all the nodes below the current node.
private define __tree_skip_children()
{   
	variable col = _tree_elem_get_column();
	
	% skip children. need if I'm adding a sibling. If this is a child,
	% this will put it at the end.
	while (down(1))
		if (_tree_elem_get_column() <= col)
			break;
}
%}}}

%{{{ Tree node data manipulation

% Creates a treedata structure and set BLocal var.
private define _tree_data_create(type)
{
	variable treedata = get_blocal_var("TreeUserData");
	
	if (treedata != NULL)
		error("treemode: TreeData already present.");
	
	treedata = @struct { array, pos, type };
	treedata.pos = 0;    % first free pos
	treedata.type = type;
	treedata.array = treedata.type[100];
	set_blocal_var(treedata, "TreeUserData");
	return treedata;
}

% grows 'treedata', so that 'pos' fits in.
private define _tree_data_grow(treedata, pos)
{
	variable size = length(treedata.array);
	variable growsize = 100;
	
	if (pos >= size+growsize)
		growsize = pos + 1 - size;
	% this may fail using slang 1.4.5 or older.
	treedata.array = [ treedata.array, treedata.type[growsize] ];
}

% put 'data' in 'treedata', at 'pos'.
private define _tree_data_set(treedata, pos, data)  
{
	if (pos >= length(treedata.array))
		_tree_data_grow(treedata, pos);
	
	treedata.array[pos] = data;
	
	if (pos >= treedata.pos)
		treedata.pos = pos+1;
}

% put 'data' in 'treedata', at 'pos', opening place for the new element.
private define _tree_data_set_open(treedata, pos, data)
{
	if (pos >= treedata.pos) {
		% at the end, easy: simply set it
		_tree_data_set(treedata, pos, data);
	} else {
		% treedata.pos is always < length(treedata.array), so there's no need to
		% check for grow here.
		treedata.array = [ treedata.array[[:pos-1]], data, treedata.array[[pos:]] ];
		treedata.pos++;
	}
}

% add data to current node, opening space at 'pos'. 
private define _tree_elem_add_data(data)
{
	variable treedata = get_blocal_var("TreeUserData");
	
	if (treedata == NULL) {
		if (data == NULL)
			return;
		error("treemode: can't set data, tree_set_user_datatype() not called.");
	}
	
	_tree_data_set_open(treedata, what_line() - 1, data);
}

define printarr(name, arr)
{
	variable s, S = "["+string(length(arr))+"]";
	
	whatbuf(); setbuf("*array*");
	insert("- array: "+name+", type = "+string(arr)+"\n");
	foreach (arr) {
		s = string(());
		insert("  <"+s+">\n");
	}
	setbuf();
}

% add an array of data to the current position, and following elements.
% datas is an array filled with data to insert, and len should be equal
% to length(datas). But datas can be NULL, if so an array of length 'len'
% is generated. if 'placeholder' is an array of placeholder markers.
% 'datas' contains elements only for real elements, elements for placeholders
% is generated for every placeholder element not empty.
private define _tree_data_add_datas(datas, len, placeholder)
{
	variable treedata = get_blocal_var("TreeUserData");
	variable pos = what_line() - 1;
	
	if (treedata == NULL) {
		if (datas == NULL)
			return;
		error("treemode: can't set data, tree_set_user_datatype() not called.");
	}
	
	if (datas == NULL)
		datas = treedata.type[len];
	else if (len != length(datas))
		verror("treemode: data len (%d) != requested len (%d).", length(datas), len);
	
	if (placeholder != NULL) {
		variable ph = Integer_Type[2*len];
		variable d = treedata.type[2*len];
		% ph contains 1 for every element that is a placeholder
		ph[*] = 1;
		ph[2*where(placeholder == "")+1] = 0;
		d[ [0:2*len-1:2] ] = datas;
		datas = d[where(ph == 1)];
		len = length(datas);
	}
	
	if (pos >= treedata.pos) {
		treedata.array = [ treedata.array[[:pos-1]], datas ];	
		if (pos+len > treedata.pos)
			treedata.pos = pos+len;
	} else {
		treedata.array = [ treedata.array[[:pos-1]], datas, treedata.array[[pos:]] ];
		treedata.pos+=len;
	}
}

% remove data for element, shrinking the array.
private define _tree_elem_remove_data()
{
	variable treedata = get_blocal_var("TreeUserData");
	if (treedata == NULL) 
		return;
	
	variable pos = what_line() - 1;
	variable lastelem = length(treedata.array)-1;
	if (pos == 0)
		treedata.array = treedata.array[[1:]];
	else if (pos == lastelem)
		treedata.array = treedata.array[[:pos-1]];
	else if (pos < lastelem)
		treedata.array = [ treedata.array[[:pos-1]], treedata.array[[pos+1:]] ];
	else % ???
		verror("can't remove elem %d, max %d!", pos, lastelem);
	
	treedata.pos --;
}

%}}}

%{{{ Tree set mark

% if you really know the exact mark to place, use this fast function.
private define __tree_set_mark(mark)
{
	del();
	insert(mark);
}

% set the mark to 'mark' (should be "+" or "-") if this node has
% at least a child, elsewhere set mark to '.'.
% This is an internal function, so it expects to be already on the tree buffer.
static define tree_set_mark(mark)
{
	variable col1, col2 = 0;
	
	col1 = _tree_elem_get_column();
	push_spot();
	if (down(1))
		col2 = _tree_elem_get_column();
	pop_spot();
	if (col2 <= col1)
		mark = ".";
	
	del();
	insert(mark);
}
%}}}

%{{{ Private Open/Close subtree functions

% hides all children lines. if 'all' requested, set tree marks to 'close' state.
static define _tree_close(all)
{
	variable state = _tree_elem_state();
	
	% Allow 'close all' on a closed subtree.
	if ((state == '-') or ((state == '+') and (all != 0))) {
		if (_tree_send_event(TREE_CLOSE) == 0)
			return 0; % vetoed by user function
		
		push_spot();
		variable col = _tree_elem_get_column();
		while (down(1) and (_tree_elem_get_column() > col)) {
			if (andelse { all } { _tree_elem_state() != '.' }) {
				if (_tree_send_event(TREE_CLOSE) == 1)
					tree_set_mark("+");
			}
			set_line_hidden(1);
		}
		pop_spot();
		tree_set_mark("+");
	}
}

% tree open is a bit more complex: here are some helpers.
private define _tree_has_placeholder(ph)
{
	if (_tree_goto_child()) 
		if (_tree_elem_state() == '.') 
			if (strcmp(_tree_elem_get_name(), ph) == 0)
				return 1;
	return 0;
}

% send a TREE_OPEN or TREE_OPEN_PLACEHOLDER event.
private define __tree_send_open_event(ph)
{
	variable event = TREE_OPEN;
	
	if (ph != NULL) {
		push_spot();
		if (_tree_has_placeholder(ph)) {
			_tree_delete_element();
			_tree_elem_remove_data();
			event = TREE_OPEN_PLACEHOLDER;
		}
		pop_spot();
	}
	return _tree_send_event(event);
}

% open current node and all the children marked as opened (restore from a 'tree_close').
% if 'all' is set, open all the closed nodes.
private define _tree_open(all)
{
	variable state = _tree_elem_state();
	% Allow 'open all' on a opened subtree.
	if ((state == '+') or ((state == '-') and (all != 0))) {
		variable ph = get_blocal_var("TreePlaceholder");
		
		if (__tree_send_open_event(ph) == 0)
			return;
		
		push_spot();
		variable col = _tree_elem_get_column();
		while (down(1) and (_tree_elem_get_column() > col)) {
			set_line_hidden(0);
			if (_tree_elem_state() == '+') {
				if (andelse { all } {__tree_send_open_event(ph) == 1})
					tree_set_mark("-");
				else { % let it closed: skip to next sibling..
					__tree_skip_children();
					() = up(1);
				}
			}
		}
		pop_spot();
		tree_set_mark("-");
	}
}

%}}}

%{{{ Tree Creation helpers (all private)

% put the cursor on tree mark at every move, and send TREE_MOVE event if
% the line changed
%%%%private variable JGLine = NULL;
private define _tree_update_hook()
{
	variable oldline = get_blocal_var("TreeOldLine");
	variable line = what_line();
	
	%%%%   JGLine = create_line_mark(color_number("menu_selection"));
	bol;skip_white;%_tree_goto_line_start();
	if (line != oldline)
		() = _tree_send_event(TREE_MOVE);
	set_blocal_var(line, "TreeOldLine");
}

% this puts a new mark on *OLD* line.
private define _tree_create_mark(oldcol)
{
	variable mark = ". ";
	variable col;
	
	bol;skip_white;%_tree_goto_line_start();
	
	col = what_column;
	if (oldcol < col)
		mark = "- ";
	
	() = up(1);
	bol;skip_white;%_tree_goto_line_start();
	insert(mark);
	() = down(1);
	return col;
}

% put tree marks on all the lines in the buffer
private define _mark_all_buffer()
{
	variable col;
	bob();
	col = _tree_elem_get_column();
	while(down_1)
		col = _tree_create_mark(col);
}
%}}}

%%%% -------------- end of private functions ---------------------

%{{{ Public Movement functions

%!%+
%\function{tree_goto_child}
%
%\usage{Integer tree_goto_child([String buffer])}
%
%\description
%
% Try to go to the first child of current node.
% Returns 1 if successful, 0 if this node has no children (in this
% case, the cursor is not moved).
%
% Together with \var{tree_goto_next_sibling}, this can be used to
% iterate through all the children of a node. 
% 
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%\seealso{tree_goto_next_sibling, tree_goto_parent}
%!%-
public define tree_goto_child()
{
	variable c;
	if (_NARGS == 1) whatbuf_setbuf(()); % on stack
	c = _tree_goto_child();
	if (_NARGS == 1) setbuf(()); % from stack
	return c;
}

%!%+
%\function{tree_goto_next_sibling}
%
%\usage{Integer tree_goto_next_sibling([String buffer])}
%
%\description
%
% Try to go to the next sibling node.
% Returns 1 if successful, 0 if this node has no (more) siblings (in this
% case, the cursor is not moved).
%
% Together with \var{tree_goto_child}, this can be used to
% iterate through all the children of a node:
%
%%v+
%    % place on the parent node, then do
%    if (tree_goto_child())
%      do
%        {
%           % do whatever you want on current node
%        }
%      while (tree_goto_next_sibling());
%%v-      
%
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%\seealso{tree_goto_child, tree_goto_parent, tree_goto_prev_sibling}
%!%-
public define tree_goto_next_sibling()
{
	variable c;
	
	if (_NARGS == 1) whatbuf_setbuf(()); % on stack
	c = _tree_goto_sibling(&down_1);
	if (_NARGS == 1) setbuf(()); % from stack
	
	return c;
}

%!%+
%\function{tree_goto_prev_sibling}
%
%\usage{Integer tree_goto_prev_sibling([String buffer])}
%
%\description
%
% Try to go to the previous sibling node.
% Returns 1 if successful, 0 if this node has no (more) siblings (in this
% case, the cursor is not moved).
%
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%\seealso{tree_goto_child, tree_goto_parent, tree_goto_next_sibling}
%!%-
public define tree_goto_prev_sibling()
{
	variable c;
	
	if (_NARGS == 1) whatbuf_setbuf(()); % on stack
	c = _tree_goto_sibling(&up_1);
	if (_NARGS == 1) setbuf(()); % from stack
	
	return c;
}

%!%+
%\function{tree_goto_parent}
%
%\usage{Integer tree_goto_parent([String buffer])}
%
%\description
%
% Try to go to the parent of current node.
% Returns 1 if successful, 0 if this node has no parent (is the root node). 
% In this case, the cursor is not moved.
%
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%!%-
public define tree_goto_parent()
{
	variable c;
	
	if (_NARGS == 1) whatbuf_setbuf(()); % on stack
	c = _tree_goto_parent();
	if (_NARGS == 1) setbuf(()); % from stack
	
	return c;
}

%}}}

%{{{ Public Open/Close subtree functions

%!%+
%\function{tree_close}
%
%\usage{Void tree_close([String buffer], Integer all)}
%
%\description
%
% Close the current node. If \var{all} is zero, leave all children 
% in their current state, Otherwise close also all children.
% 
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%\seealso{tree_open, tree_close_inside, tree_toggle}
%!%-
public define tree_close(all)
{
	if (_NARGS == 2) whatbuf_setbuf(()); % on stack
	_tree_close(all);
	if (_NARGS == 2) setbuf(()); % from stack
}

%!%+
%\function{tree_open}
%
%\usage{Void tree_open([String buffer], Integer all)}
%
%\description
%
% Open the current node, if \var{all} is zero, preserves the state of
% all children, otherwise open all children recursively.
% 
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%\seealso{tree_close, tree_close_inside, tree_toggle}
%!%-
public define tree_open(all)
{
	if (_NARGS == 2) whatbuf_setbuf(()); % on stack
	_tree_open(all);
	if (_NARGS == 2) setbuf(()); % from stack
}

%!%+
%\function{tree_toggle}
%
%\usage{Void tree_toggle([String buffer], Integer all)}
%
%\description
%
% If the current node is open, closes it, else opens it.
% This calls \var{tree_open} or \var{tree_close}.
% 
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%\seealso{tree_open, tree_close, tree_close_inside}
%!%-
public define tree_toggle(all)
{
	if (_NARGS == 2) whatbuf_setbuf(()); % on stack
	
	switch (_tree_elem_state())
	{ case '+' : _tree_open(all); }
	{ case '-' : _tree_close(all); }
	{ () = _tree_send_event(TREE_TOGGLE); }
	
	if (_NARGS == 2) setbuf(()); % from stack
}

%!%+
%\function{tree_close_inside}
%
%\usage{Void tree_close_inside([String buffer], Integer all)}
%
%\description
%
% If the current node is an open node, simply closes that node,
% else closes the parent node of the current node.
% 
% This calls \var{tree_close} to do the work.
% 
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%\seealso{tree_open, tree_close, tree_toggle}
%!%-
public define tree_close_inside(all)
{
	if (_NARGS == 2) whatbuf_setbuf(()); % on stack
	
	if (_tree_elem_state() != '-')
		!if (_tree_goto_parent())
			return;
	_tree_close(all);
	
	if (_NARGS == 2) setbuf(()); % from stack
}
%}}}

%{{{ Tree management: add/remove nodes

%!%+
%\function{tree_add_element}
%
%\usage{Void tree_add_element([String buffer], String child, String name, data)}
%
%\description
%
% This functions adds a new node to a tree.
% \var{child} indicates if the new node will be a sibling of current node
% (in this case, it must by an empty string), or a child of current node,
% (in this case \var{child} is used to indent the new node).
% In both cases the new node will be put at the end of its level.
% \var{name} is the string that will be shown on tree.
% \var{data} is some user data associated to this tree node. You should call
% \var{tree_set_user_datatype()} before any call with \var{data} != NULL.
% 
% On exit the current node will be the newly inserted node.
% 
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%\seealso{tree_delete_element, tree_set_user_datatype}
%!%-
public define tree_add_element(child, name, data)
{
	if (_NARGS == 4) whatbuf_setbuf(()); % on stack
	
	variable col = _tree_elem_get_column();
	variable parentstate = ' ';
	
	% skip children. need if I'm adding a sibling. If this is a child,
	% this will put it at the end.
	__tree_skip_children();
	() = up(1); % this also puts the point at eol.
	
	newline();
	if (eobp()) {  
		() = up(1);  % allow insertion on an empty buffer
		child = ""; % and ignore child info!
	}
	
	goto_column(col);
	insert(child + ". " + name);
	
	bol;skip_white;%_tree_goto_line_start();
	% redo tree mark on parent
	push_spot();
	if (_tree_goto_parent()) {
		parentstate = _tree_elem_state();
		% this is the first child, set mark to close
		if (parentstate == '.') {          
			if (get_blocal_var("TreeInsertClose"))
				__tree_set_mark("+");
			else
				__tree_set_mark("-");
			parentstate = _tree_elem_state();
		}
	}   
	pop_spot();
	% if parent is closed, hide the new element
	if (parentstate == '+')
		set_line_hidden(1);
	_tree_elem_add_data(data);
	
	if (_NARGS == 4) setbuf(()); %from stack
}

private define __tree_get_ph(have_placeholder, names)
{
	variable ph  = get_blocal_var("TreePlaceholder");
	variable placeholder = String_Type[length(names)];
	
	if (ph != NULL) {
		if (typeof(have_placeholder) == Array_Type) {
			if (length(have_placeholder) != length(names))
				error("treemode: bad placeholder size");
			placeholder[where(have_placeholder != 0)] = ph;
			placeholder[where(have_placeholder == 0)] = "";
			return placeholder;
		}
		if (typeof(have_placeholder) == Integer_Type)
			if (have_placeholder != 0) {
				placeholder[*] = ph;
				return placeholder;
			}
	}
	
	placeholder[*] = "";   
	return placeholder;
}

%!%+
%\function{tree_add_children}
%
%\usage{Void tree_add_children([String buffer], Int indent, Int have_placeholder, String[] names, datas)}
%
%\description
%
% This functions adds some new nodes to an existing node on a tree.
% \var{indent} indicates the indentation to apply to these nodes.
% The new nodes will be put at the end of its level.
% \var{names} is an array of strings that will be shown on tree.
% \var{datas} is some user data associated to these tree nodes. You should call
% \var{tree_set_user_datatype()} before any call with \var{datas} != NULL.
% 
% On exit the current node will be the starting node.
% 
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%\seealso{tree_add_element, tree_delete_element, tree_set_user_datatype}
%!%-
public define tree_add_children(indent, have_placeholder, names, datas)
{
	if (_NARGS == 5) whatbuf_setbuf(()); % on stack
	
	if (length(names) > 0) {
		variable col = _tree_elem_get_column();
		variable parentstate = ' ';
		variable has_parent = 1;
		variable name;
		variable placeholder;
		variable i;
		
		placeholder = __tree_get_ph(have_placeholder, names);
		
		push_spot();  % on parent
		% skip children.
		__tree_skip_children();
		() = up(1); % this also puts the point at eol.
		
		newline();
		if (eobp()) {  
			has_parent = 0;
			() = up(1);  % allow insertion on an empty buffer
		} else 
			col += indent;
		
		push_spot(); % on first child added
		__tree_insert_elem(names[0], col, indent, placeholder[0]);
		
		for (i = 1; i < length(names) ; i++) {
			newline();
			__tree_insert_elem(names[i], col, indent, placeholder[i]);
		}   
		pop_spot(); % return to first child
		
		% add data.
		%%%%	if (__eqs(have_placeholder, 0))
		if (andelse { typeof(have_placeholder) == Integer_Type }
		    { have_placeholder == 0 })
			_tree_data_add_datas(datas, length(names), NULL); % speed up
		else
			_tree_data_add_datas(datas, length(names), placeholder);
		
		pop_spot(); % return to parent
		if (has_parent) {
			if (get_blocal_var("TreeInsertClose")) {
				__tree_set_mark("-");
				_tree_close(0);
			} else {
				__tree_set_mark("+");
				_tree_open(0);
			}
		}
	}
	
	if (_NARGS == 5) setbuf(()); %from stack
}

%!%+
%\function{tree_delete_element}
%
%\usage{Void tree_delete_element([String buffer])}
%
%\description
%
% This functions deletes the current node on buffer \var{handle}.
% If it has children, those are also deleted, recursively.
% 
% On exit the current node will be set to the parent node of the deleted node.
% 
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%\seealso{tree_add_element}
%!%-
public define tree_delete_element()
{
	if (_NARGS == 1) whatbuf_setbuf(()); % on stack
	
	variable state;
	variable col = _tree_elem_get_column();
	
	% find the parent
	push_mark();
	() = _tree_goto_parent();
	state = _tree_elem_state();   
	exchange_point_and_mark(); % mark on parent, point on starting element
	
	%%% FIXME: this works only when removing leaves !!!
	%%% TODO: speed up(?): push_mark; __tree_skip_children; del_region.
	_tree_elem_remove_data();
	% delete this node and all children
	do {
		_tree_delete_element();
	} while (_tree_elem_get_column() > col);
	
	% return to parent, and rebuild mark
	pop_mark_1();
	tree_set_mark(char(state));
	if (_NARGS == 1) setbuf(()); %from stack
}
%}}}

%{{{ Public element functions

%!%+
%\function{tree_elem_state}
%
%\usage{Char tree_elem_state([String buffer])}
%
%\description
%
% Return the state of current tree element. \var{buffer} parameter
% may be used if current buffer is not the wanted tree buffer.
% 
% state is one of:
%    '+': is a tree 'folder', currently closed.
%    '-': is a tree 'folder', currently opened.
%    '.': is a tree 'leaf'.
%
%!%-
public define tree_elem_state()
{
	variable c;
	if (_NARGS == 1) whatbuf_setbuf(()); % on stack
	c = _tree_elem_state();
	if (_NARGS == 1) setbuf(()); % from stack
	return c;
}

%!%+
%\function{tree_elem_get_column}
%
%\usage{Integer tree_elem_get_column([String buffer])}
%
%\description
%
% Return the indentation (in chars) of current tree element.
% TreeMode doesn't enforce a fixed indentation, it's up to the caller mode
% to interpret this value.
% TreeMode used this function internally to check if a node is a child
% of the previous node.
% 
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%!%-
public define tree_elem_get_column()
{
	variable c;
	if (_NARGS == 1) whatbuf_setbuf(()); % on stack
	c = _tree_elem_get_column();
	if (_NARGS == 1) setbuf(()); % from stack
	return c;
}

%!%+
%\function{tree_elem_get_name}
%
%\usage{String tree_elem_get_name([String buffer])}
%
%\description
%
% Return the name of current tree element.
%
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%!%-
public define tree_elem_get_name()
{
	variable c;
	if (_NARGS == 1) whatbuf_setbuf(()); % on stack
	c = _tree_elem_get_name();
	if (_NARGS == 1) setbuf(()); % from stack
	return c;
}

%!%+
%\function{tree_elem_get_data}
%
%\usage{(User type) tree_elem_get_data([String buffer])}
%
%\description
%
% Return the data associated with current tree element. The
% type of data returned is the type defined using \var{tree_set_user_datatype()}
%
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%\seealso{tree_set_user_datatype}
%   
%!%-
public define tree_elem_get_data()
{
	variable c;
	if (_NARGS == 1) whatbuf_setbuf(()); % on stack
	c = _tree_elem_get_data();
	if (_NARGS == 1) setbuf(()); % from stack
	return c;
}

%!%+
%\function{tree_elem_set_data}
%
%\usage{Void tree_elem_set_data([String buffer,] data)}
%
%\description
%
% Set data for current tree element.
%
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%!%-
public define tree_elem_set_data(data)
{
	if (_NARGS == 2) whatbuf_setbuf(()); % on stack
	
	variable treedata = get_blocal_var("TreeUserData");
	variable pos = what_line() - 1;
	
	if (treedata == NULL)
		error("treemode: can't set data, tree_set_user_datatype() not called.");   
	_tree_data_set(treedata, pos, data);
	
	if (_NARGS == 2) setbuf(()); % from stack
}

%}}}

%{{{ Tree interface

%!%+
%\function{tree_build}
%
%\usage{Void tree_build([String buffer])}
%
%\description
%
% Given a buffer layered out as a tree, this functions add 
% tree marks and set up everything to handle this buffer
% as a tree.
%
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%\seealso{tree_mode}
%!%-
public define tree_build()
{
	if (_NARGS == 1) whatbuf_setbuf(()); % on stack
	
	flush("treemode: preparing tree...");
	%%%%%%set_readonly(0);
	% rename current buffer, prepending "tree-"
	rename_buffer("tree-"+whatbuf());
	_tree_untab_buffer();
	_mark_all_buffer();
	%%%%%%set_readonly(1);
	message("treemode: preparing tree... Done.");
	
	if (_NARGS == 1) setbuf(()); % from stack
}

%!%+
%\function{tree_set_user_func}
%
%\usage{Void tree_set_user_func([String buffer,] Ref func, Integer mask)}
%
%\description
%
% This functions sets a slang function to be called on tree events.
% When an event occurs and it is present in \var{mask}, the \var{func} 
% function will be called with a parameter indicating
% the event. \var{func} must return an integer, with value '0' if not futher
% action should be taken, any other value if normal action should continue.
% 
% Valid Actions are:
%    TREE_OPEN          tree_open() called.
%    TREE_CLOSE         tree_close() called.
%    TREE_TOGGLE        tree_toggle() called on a leaf node.
%    TREE_MOVE          a tree movement().
%    
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%\notes
%    More event may be added, test for equality when checking for an event.
%
%!%-
public define tree_set_user_func(func, mask)
{
	if (_NARGS == 3) whatbuf_setbuf(()); % on stack
	set_blocal_var(func, "TreeEventFunc");
	set_blocal_var(mask, "TreeEventMask");
	if (_NARGS == 3) setbuf(()); % from stack
}

%!%+
%\function{tree_set_user_datatype}
%
%\usage{Void tree_set_user_datatype([String buffer,] DataType datatype)}
%
%\description
%
% This functions sets a the type for the internal data array. It fails if
% some data was already inserted in the tree (But elements without data are
% allowed).
%
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%!%-
public define tree_set_user_datatype(datatype)
{
	if (_NARGS == 2) whatbuf_setbuf(()); % on stack
	() = _tree_data_create(datatype);
	if (_NARGS == 2) setbuf(()); % from stack
}

%!%+
%\function{tree_set_close_on_insert}
%
%\usage{Void tree_set_close_on_insert([String buffer,] Integer close)}
%
%\description
%
% This functions sets a the flag for closing subtrees when inserting elements
% (via \var{tree_add_element}. If \var{close} is zero, the parent node of the 
% new node will be opened. If \var{close} is not zero, the parent node will
% be closed.
%
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%!%-
public define tree_set_close_on_insert(close)
{
	if (_NARGS == 2) whatbuf_setbuf(()); % on stack
	set_blocal_var(close, "TreeInsertClose");
	if (_NARGS == 2) setbuf(()); % from stack
}

%!%+
%\function{tree_set_placeholder}
%
%\usage{Void tree_set_placeholder([String buffer,] String placeholder)}
%
%\description
%
% Defines a placeholder to use when \var{tree_add_children()} is called with
% \var{have_placeholder} set to TRUE.
% If a placeholder is present when trying to open a node, the placeholder 
% will be removed, and the user function (defined using \var{tree_set_user_func()})
% will be called with TREE_OPEN_PLACEHOLDER instead of TREE_OPEN.
%
% \var{buffer} parameter may be used if current buffer is 
% not the wanted tree buffer.
% 
%!%-
public define tree_set_placeholder(placeholder)
{
	if (_NARGS == 2) whatbuf_setbuf(()); % on stack
	set_blocal_var(placeholder, "TreePlaceholder");
	if (_NARGS == 2) setbuf(()); % from stack
}

%}}}

%{{{ mode stuff

%!%+
%\function{tree_build_kmap}
%
%\usage{Int tree_build_kmap(String kmap)}
%
%\description
%
% This function builds a base keymap for a generic tree mode. This is 
% NOT called by tree_mode(), You are free to call this and add your 
% own keys, or build a keymap from scratch.
% Returns 1 if a new keymap was built, 0 otherwise.
% 
%!%-
public define tree_build_kmap(kmap)
{
	!if (keymap_p(kmap)) {
		make_keymap(kmap);
		
		_for (32, 127, 1) undefinekey(char(()), kmap);
		definekey("tree_open(0)", "", kmap);
		definekey("tree_toggle(0)", " ", kmap);
		definekey("tree_close(0)", Key_BS, kmap);
		definekey("tree_close_inside(0)", "/", kmap);
		definekey("tree_close_inside(0)", Key_Del, kmap);
		return 1;
	}
	return 0;
}

create_syntax_table(TreeMode);
#ifdef HAS_DFA_SYNTAX
static define setup_dfa_callback (name)
{
	dfa_enable_highlight_cache("treemode.dfa", name);
	dfa_define_highlight_rule("^[ \t]*\\+\\ ", "keyword", name);
	dfa_define_highlight_rule("^[ \t]*\\-\\ ", "number", name);
	dfa_define_highlight_rule("^[ \t]*\\.\\ ", "comment", name);
	dfa_build_highlight_table(name);
}
dfa_set_init_callback(&setup_dfa_callback, TreeMode);
%%% DFA_CACHE_END %%%
#endif

%!%+

%\function{tree_mode}
%
%\usage{Void tree_mode()}
%
%\description
%
% This functions enables tree mode on current buffer. It 
% expects an already marked tree (as built with \var{tree_build}),
% or an empty buffer.
% 
%\seealso{tree_build}
%!%-
public define tree_mode()
{
	set_overwrite(1);
	set_buffer_modified_flag(0);
	() = tree_build_kmap("Treemode");
	use_keymap("Treemode");
#ifdef HAS_DFA_SYNTAX
	enable_dfa_syntax_for_mode(TreeMode);
#endif
	set_mode(TreeMode, 0);
	use_syntax_table(TreeMode);
	set_buffer_hook("update_hook", &_tree_update_hook);
	define_blocal_var("TreeEventFunc", NULL);    % User Event Function
	define_blocal_var("TreeEventMask", NULL);    % User Event Mask
	define_blocal_var("TreeUserData", NULL);     % User Data Array
	define_blocal_var("TreeOldLine", -1);        % Old line (to avoid extra TREE_MOVE events)
	define_blocal_var("TreeInsertClose", 1);     % Insert will try to keep nodes closed
	define_blocal_var("TreePlaceholder", NULL);  % Placeholder
	bob();
}

public define tree_convert()
{
	tree_build();
	tree_mode();
        () = tree_build_kmap("TreeConverted");
}

%}}}

provide("treemode");

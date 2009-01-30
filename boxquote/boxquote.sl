% -*- SLang -*-
% $Id: boxquote.sl 198 2009-01-28 17:21:13Z phgrau $

% Copyright (c) Philipp Grau
% Released under the terms of the GNU GPL (version 2 or later).

% boxquote.sl
% 
% Inspired by boxquote.el for emacs
% Stolen code shamelessly from mail_mode.sl
% by Thomas Roessler <roessler@guug.de>
% 
% First version on 13.03.2002
% Philipp Grau <phgrau@zedat.fu-berlin.de>
% 
% Improvements by Paul Boekholt <paul@boekholt.com>

% Currently there are tree usefull functions:
% boxquote_insert_file: inserts a file in boxquotes
% boxquote_region: boxquotes a region
% boxquote_region_with_comment(); boxquotes a region with a comment
% 
% ToDo:
%       - make boxes cutomizable
%       - improve some things
%       - triming of the filename?
%         for cut&paste insertions?
%       - write a deboxquote
%       - fix bugs
%       - ...

% Usage: put something like the next line in your .jedrc
% () = evalfile("~/share/slang/boxquote.sl");
% 
% or use
% _autoload("boxquote_region", "boxquote"
% "boxquote_region_with_comment", "boxquote"
% "boxquote_insert_file", "boxquote",
% 3);
%
% 
% And the you can do something like M-x boxquote_insert_file <RET>
% An you will be asked for a file name.
% Or mark a region and call M-x boxquote_region <RET>

% _debug_info = 1;

%%%%% PROTOTYPES

define boxquote(name);
define boxquote_buffer(ntags);
public define boxquote_region();
public define boxquote_region_with_comment();
define boxquote_region_with_comment_jump();
public define boxquote_insert_file();

%%%%%% real stuff

define boxquote_region()
{
	boxquote("");
}

define boxquote_region_with_comment()
{
	variable comment = 
		read_mini ("Comment:", "","");
	boxquote(comment);
	
	
}

define boxquote_region_with_comment_jump()
{
	variable comment = 
		read_mini ("Comment:", "","");
	boxquote(" ");
	
	
}

define boxquote_insert_file()
{
	% insert_file();
	variable file = 
		read_with_completion ("File:", Null_String, Null_String, 'f');
	push_spot ();
	push_mark();
	() = insert_file (file);
	boxquote(file);
	pop_spot ();
}

define boxquote(name)
{
	% vmessage("Name=%s",name);
	
	!if (bolp) go_down_1;	
	push_spot();
	narrow();
	bob();
	insert(",----");
	if (name != "")
	{
		insert("[ ");
		insert(name);
		insert(" ]---");
	}
	insert("\n");
	boxquote_buffer(1);
	eob();
	bol();
	if (what_char () == '|')
	{
		del ();del();
		insert ("`----\n");
	}
	widen();
	pop_spot();
	down(1);
	% eol(); insert("\n");
}


define boxquote_buffer(ntags)
{
	variable tags;
	push_spot();
	% bob();
	tags = "";
	loop (ntags) tags = strcat (tags, "| ");
	do
	{
		insert (tags);
	}
	while (down_1 ());
	% up(1);
	pop_spot();
}

% So M-x finds the functions
$0 = _stkdepth; 
. "boxquote_insert_file" "boxquote_region" "boxquote_region_with_comment"
_add_completion(_stkdepth - $0);

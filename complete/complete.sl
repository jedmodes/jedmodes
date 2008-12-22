#<perl>
=pod
  ;
#</perl>
% complete.sl
% 
% $Id: complete.sl,v 1.2 2008/12/22 15:49:22 paul Exp paul $
%
% Copyright (c) 2004-2008 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This defines a function called "complete" that runs the blocal hook
% "complete_hook", and a function to find completions in a file.  The idea
% is to bind complete() to a key (M-tab say), make a keywords file, and
% set some blocal variables.  The keywords file is just a sorted file of
% keywords or function names, one per line. For example in php, write a
% php file like
% 
% <?php
% $funs = get_defined_functions();
% sort ($funs["internal"]);
% foreach($funs["internal"] as $word)
%   echo $word ."\n";
% ?>
% 
% save the output to the file php_words in your Jed_Home_Directory, and add
% this to .jedrc:
% 
% define php_mode_hook()
% {
%    define_blocal_var("Word_Chars", "a-zA-Z_0-9");
%    local_setkey("complete_word", "\e\t");
%    define_blocal_var("complete_hook", "complete_from_file");
% }
% 
% To do partial completion, press M-tab.  To cycle through completions,
% press M-tab again.
% 
% For S-Lang, run this script as
% jed-script complete.sl
% to make a completions file.
% 
% For Perl, run Perl on this file to get a completions file:
% perl complete.sl
% To add functions from additional modules, add them as extra parameters,
% appending the export tags like in perl's -M option (see perlrun):
% perl complete.sl 'CGI=:standard' 'Debian::DictionariesCommon=:all'

if (__argv[0] == path_basename(__FILE__))
{
   ()=find_file(dircat(Jed_Home_Directory, "slang_words"));
   erase_buffer();
   variable words = _apropos("Global", "...", 15);
   variable word;
   foreach word (words[array_sort(words)])
     {
	insert(word);
	newline();
     }
   save_buffer();
   exit(0);
}
require("txtutils");

private variable context = NULL;


% find the completions of WORD in FILE
% The file should be sorted!
private define before_key_hook();

private define before_key_hook (fun)
{
   if (typeof (fun) == Ref_Type) fun = "&";
   ifnot (is_substr (fun, "complete_word"))
     {
	if (context.n) pop_mark_0();
	remove_from_hook ("_jed_before_key_hooks", &before_key_hook);
	context = NULL;
     }
}

private define next_completion()
{
   if (context.n) del_region();
   if (context.n == context.n_completions) 
     {
	remove_from_hook ("_jed_before_key_hooks", &before_key_hook);
	context = NULL;
	flush("no more completions");
     }
   else
     {
	push_mark();
	insert(substr(context.completions[context.n], context.i, -1));
	flush (strjoin(context.completions[[context.n:]], "  "));
	context.n++;
     }
}

define complete_from_file() % (word [file])
{
   variable word, file;
   (word, file) = push_defaults(,, _NARGS);
   if (context != NULL) return next_completion();
   
   if (word == NULL || word == "") return message("no word"); % shouldn't happen
   if (file == NULL) file = dircat(Jed_Home_Directory, strlow
				   (sprintf("%s_words", what_mode(), pop)));
   if (1 != file_status(file)) return message ("no completions file");
   
   variable n_completions, len = strlen(word);
   word = str_quote_string (word, "\\^$[]*.+?", '\\');
   n_completions= search_file(file, sprintf("\\c^%s", word), 50);
   switch (n_completions)
     {case 0: return message ("no completions");}
     {case 50: return _pop_n(50);} % we can't do a partial completion
     {case 1: variable completion = strtrim();
	insert (substr(completion, len+1, -1));
	return;};

   variable completions = __pop_args(n_completions);
   completions = array_map(String_Type, &strtrim, [__push_args(completions)]);

   variable first_completion, last_completion, i, n = 0;
   first_completion = completions[0];
   last_completion = completions[-1];
   _for i (len, strlen(first_completion), 1)
     {
     	if (strncmp(first_completion, last_completion, i))
     	  break;
     }
   then
     {
     	i++;
     }
   insert (substr(first_completion, len+1, i - len - 1));
   message (strjoin(completions, "  "));
   
   context = struct { completions, n_completions, n, i };
   set_struct_fields(context, completions, n_completions, n, i);
   add_to_hook ("_jed_before_key_hooks", &before_key_hook);
}

define complete_word()
{
   variable word = get_word();
   ifnot (strlen(word)) return message("nothing to complete");
   run_blocal_hook("complete_hook", word);
}

provide("complete");

#<perl>
=cut
use strict;

# adapted from perl.sl
sub find_keywords {
	local @ARGV = "perldoc -u perlfunc|";
	while (<>) { last if /^=head2\s+Alphabetical/ }	# cue up
	
	my %kw = map { $_ => 1 }
	(
		# language elements + carp
		qw(
			else elsif foreach unless until while
			carp cluck croak confess
		),
		# keywords
		map { /^=item\s+([a-z\d]+)/ } <>,
	);
	return \%kw;
}

sub find_module_symbols {
	my ($kw, $module) = @_;
	my $fh;
	my ($module_sans_tags)=split(/[ =]/, $module);
	my @command = ( "perl",
		"-M" . $module,	
		"-e",
		'map {print "$_\n" if *$_{CODE} } keys %main::'. $module_sans_tags . '::'
	);
	
	my $fh;
	open($fh, "-|") or exec @command;
	while (<$fh>) {
		chomp;
		next if length($_) < 4;
		next if /^_/ or not /[a-z]/;
		$kw->{$_} = 1;
	}
}
my $kw = find_keywords;
while (my $module = shift @ARGV) {
	find_module_symbols($kw, $module);
}
map {print "$_\n" if length > 3 } sort keys %$kw;
#</perl>

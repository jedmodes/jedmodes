. "fileview_cmds" provide
. "fileview" use_namespace
. _stkdepth =$1

% This list reflects what I (Paul Boekholt) have on my disk and what
% Fransesc Rocher had back in '97.  Ideally there should be a cmds file
% for Gnome users, another one for KDE users, one for Windows users...
% (does this thing work in Windows?).
%
% The order of the wild-cards in the next table is VERY important.
% Generic wild-cards MUST appear later: for example "*.gz" must appear
% after "*.tar.gz", "*.ps.gz", etc.  If you want to use xv in X and zgv
% in the console, list xv first.
%
% Pushing everything on the stack and then popping it reverses the
% order, so generic wild-cards are listed first here.
%
% These wild-cards are NOT case sensitive.
%  -----------------------------------------------------------
%  'MOD' values: 'b' View results in a buffer
%                'f' Use a function and view results in a buffer
%                'X' Use an external program, requires X
%                'T' Requires a terminal - use run_program
%
%

  % MOD   WILD-CARDS      COMMANDS
% ---  ------------

% ...any more?
. "b"	"*.uue"		 "uudecode -o /dev/stdout"
. "b"	"*.html.gz"	 "lynx -dump"
. "b"	"*.htm.gz"	 "lynx -dump"
. "f"	"*.html"	 "jedscape_get_url(\"%s\")"
. "f"	"*.htm"		 "jedscape_get_url(\"%s\")"
% Image formats ...
% ...any more?
. "T"	"*.pcx"		 "zgv"
. "T"	"*.pbm"		 "zgv"
. "T"	"*.jpeg"	 "zgv"
. "T"	"*.jpg"		 "zgv"
. "T"	"*.gif"		 "zgv"
. "T"	"*.bmp"		 "zgv"

. "DISPLAY" getenv NULL != {
% pdf, postscript
. "X"	"*.pdf.z"	 "xpdf"
. "X"	"*.pdf.gz"	 "xpdf"
. "X"	"*.pdf"		 "xpdf"
. "X"	"*.eps.z"	 "gv"
. "X"	"*.eps.gz"	 "gv"
. "X"	"*.eps"		 "gv"
. "X"	"*.ps.z"	 "gv"
. "X"	"*.ps.gz"	 "gv"
. "X"	"*.ps"		 "gv"
. "X"	"*.dvi"		 "xdvi"
. "X"	"*.fig"		 "xfig"
. "X"	"*.lyx"		 "lyx"
% images
. "X"	"*.xcf"		 "gimp --no-splash --no-splash-image --no-data > /dev/null 2>&1"
. "X"	"*.xwd"		 "xwud -in "
. "X"	"*.xpm"		 "xli"
. "X"	"*.xbm"		 "xli"
. "X"	"*.tiff"	 "xli"
. "X"	"*.tif"		 "xli"
. "X"	"*.tga"		 "xli"
. "X"	"*.ppm"		 "xli"
. "X"	"*.png"		 "xli"
. "X"	"*.pnm"		 "xli"
. "X"	"*.pm"		 "xli"
. "X"	"*.pgm"		 "xli"
. "X"	"*.pcx"		 "xli"
. "X"	"*.pbm"		 "xli"
. "X"	"*.jpeg"	 "xli"
. "X"	"*.jpg"		 "xli"
. "X"	"*.gif"		 "xli"
. "X"	"*.bmp"		 "xli"
% Movie formats
. "X"	"*.qt"		 "xanim +q"
. "X"	"*.rp"		 "realplay"
. "X"	"*.mpeg"	 "xanim +q"
. "X"	"*.mpg"		 "xanim +q"
. "X"	"*.avi"		 "xanim +q"
. } if
% sources - try to extract documentation
. "b"   "*.pm"		 "pod2text"
% python - if the directory is writable, pydoc bytecompiles the file?
. "b"	"*.py"		 "pydoc"
. "f"	"*.sl"		 "tm_view(\"%s\")"
% documents
. "b"	"*.ms"		 "groff -Tascii -ms"
. "b"	"*.man"		 "unix_man (\"-l %s\")"
. "f"	"*.info.gz"	 ". \"(%s)\" info_find_node info_reader"
. "f"	"*.info"	 ". \"(%s)\" info_find_node info_reader"
. "f"	"*.[1-9][tTxX]"	 "unix_man (\"-l %s\")"
. "f"	"*.[1-9nlpo]"	 "unix_man (\"-l %s\")"
. "b"	"*.doc"		 "antiword"
% archives
. "b"	"*.jar"		 "jar tvf"
. "b"	"*.rpm"		 "rpm -qRp"
. "b"	"*.zip"		 "unzip -l"
. "b"	"*.bz2"		 "bzip2 -dc"
. "f"	"*.tar.bz2"	 "tar (\"%s\")"
. "f"	"*.tar.z"	 "tar (\"%s\")"
. "f"	"*.tar.gz"	 "tar (\"%s\")"
. "f"	"*.t[ag]z"	 "tar (\"%s\")"
. "f"	"*.tar"		 "tar (\"%s\")"
. _stkdepth $1 - 3 / {fileview_add_pipe} loop

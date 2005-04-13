# tm.sed  -*- mode: sed -*-
#
# $Id$
# Keywords: doc, slang
# 
# copyright (c) 2004 Paul Boekholt
# Released under the terms of the GNU GPL (version 2 or later).
# 
# This is a 'my first sed script' to extract tm documentation from
# S-Lang sources and render it as ASCII text.

# This matches beginning and end of a tm entry. The entire script
# is in this block.
#/^%!%\+/,/^%!%-/{
/^%!%[+]/,/^%!%-/{
s/%!%[+]//
s/%!%[-]/--------------------------------------------------------------------/
s/^%/  /
# verbatim
/^  #v+/,/  #v-/{
s/^  #v+//
s/^  #v-//
s/^/  /
p
d
}

# \var, \em
s/\\var{\([^}]*\)}/`\1'/g
s/\\em{\([^}]*\)}/_\1_/g

# \function, \variable
s/  \\function{\([^}]*\)}/\1/
s/  \\variable{\([^}]*\)}/\1/

# sections
s/\\seealso{\([^}]*\)}/\
 SEE ALSO\
    \1/
s/\\synopsis{\([^}]*\)}/\
 SYNOPSIS\
    \1/
s/\\usage{\([^}]*\)}/\
 USAGE\
    \1/

s/\\description/\
 DESCRIPTION\
/
s/\\example/\
 EXAMPLE\
/
s/\\notes/\
 NOTES\
/

# undouble \-es
s/\\\\/\\/g
# print it!
p
}
# don't print the rest
d

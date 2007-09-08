#!/bin/sed -f
#
# $Id$
# 
# copyright (c) 2004, 2007 Paul Boekholt
# Released under the terms of the GNU GPL (version 2 or later).
# 
# This is a sed script to extract tm documentation from S-Lang sources and
# render it as ASCII text.

# This matches beginning and end of a tm entry. The entire script
# is in this block.
/^%!%[+]/,/^%!%-/{
s/%!%[+]//
s/%!%[-]/--------------------------------------------------------------/
s/^%/  /
# verbatim
/^  #v+/,/  #v-/{
s/^  #v+//
s/^  #v-//
s/^/  /
p
d
}

# \var, \ivar, \svar, \ifun, \sfun, \exmp
# { and } characters inside parameter lists are escaped
# this scripts supports at most one such character
s/\\\(var\|ivar\|svar\|ifun\|sfun\|exmp\){\([^}]*\)\\}\([^}]*\)}/`\2}\3'/g
s/\\\(var\|ivar\|svar\|ifun\|sfun\|exmp\){\([^}]*\)\\{\([^}]*\)}/`\2{\3'/g
s/\\\(var\|ivar\|svar\|ifun\|sfun\|exmp\){\(\(\\}\|[^}]\)*\)}/`\2'/g

# \em
s/\\em{\(\(\\}\|[^}]\)*\)}/_\1_/g

# \NULL, \slang
s/\\NULL/NULL/g
s/\\slang/S-Lang/g

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
 DESCRIPTION/
s/\\example/\
 EXAMPLE/
s/\\notes/\
 NOTES/


# undouble \-es
s/\\\\/\\/g
# print it!
p
}
# don't print the rest
d

% ------------------------------------------- -*- mode:SLang; mode:folding; -*-
%
% MD5 FOR JED
%
%  Copyright (c) 2001 Johann Gerell, Francesc Rocher
%  Released under the terms of the GNU General Public License (ver. 2 or later)
%
% $Id: md5.sl,v 1.5 2002/03/03 12:50:06 rocher Exp $
%
% --------------------------------------------------------------------- %{{{
%
% DESCRIPTION
%	MD5 message digest algorithm implemented in SLang. It can compute
%	the MD5 finger print of a string, a region or the entire current
%	buffer. For a really accurate description of how it works, see RFC
%	1321 at http://www.ietf.org/rfc/rfc1321.txt.
%
% INSTALLATION
%	Copy this file on a place where JED can load it, e.g. JED_ROOT/lib,
%	and issue the command 'require( "md5" );'. You can also put the
%	'require' command on your '.jedrc' file.
%
% USAGE
%	Once installed, simply invoke any of the public	functions defined
%	below:
%
%		o  String_Type md5_string( String_Type )
%		o  String_Type md5_region()
%		o  String_Type md5_buffer()
%
% CHANGELOG
%
%	March 2002
%		o  First public release.
%
% AUTHOR
%	Francesc Rocher <rocher@users.sf.net>
%	Feel free to send comments, suggestions or improvements.
%
% ------------------------------------------------------------------------ %}}}

implements( "md5" );

%
% Convert a string to an array of 16-word blocks.
% Append padding bits and the length of the original string (see the RFC1321,
% "The MD5 Message-Digest Algorithm").
%
private define get_blocks( str ) %{{{
{
    variable n = (( strlen( str ) + 8 ) shr 6 ) + 1;
    variable block = Integer_Type[n*16];
    variable i, k;

    block[*] = 0;
    i=0;
    loop( strlen( str ))
    {
        k = int( substr( str, 1+i, 1 ));
        block[i shr 2] |= k shl (( i mod 4 ) * 8 );
        i++;
    }
    block[i shr 2] |= 0x80 shl (( i mod 4 ) * 8 );
    block[n*16 - 2] = strlen( str ) * 8;
    return( block );
}
%}}}

%
% Bitwise rotate a 32-bit number to the left.
%
private define rotate_left( x, n ) %{{{
{
    ( x shr ( 32 - n )) & ~( 0xFFFFFFFF shl n );
    return(( x shl n ) | () );
}
%}}}

%
% Transformations.
%
private define FF( a, b, c, d, Xi, s, ac ) %{{{
{
    a + (( b & c ) | ( ~b & d )) + Xi + ac;
    return( rotate_left( (), s ) + b );
}
%}}}
private define GG( a, b, c, d, Xi, s, ac ) %{{{
{
    a + (( b & d ) | ( c & ~d )) + Xi + ac;
    return( rotate_left( (), s ) + b );
}
%}}}
private define HH( a, b, c, d, Xi, s, ac ) %{{{
{
    a + ( b xor c xor d ) + Xi + ac;
    return( rotate_left( (), s ) + b );
}
%}}}
private define II( a, b, c, d, Xi, s, ac ) %{{{
{
    a + ( c xor ( b | ~d )) + Xi + ac;
    return( rotate_left( (), s ) + b );
}
%}}}

%
% Print a message digest in hexadecimal.
%
private define digest( a, b, c, d ) %{{{
{
    variable i, j, str = "";
    variable x = [ a, b, c, d ];

    $0 = "0123456789abcdef";
    for( i = 0; i < 4; ++i )
    {
        for( j = 0; j < 4; j++ )
        {
            $1 = substr( $0, 1 + (( x[i] shr ( j * 8 + 4 )) & 0x0F ), 1 );
            $2 = substr( $0, 1 + (( x[i] shr ( j * 8 )) & 0x0F ), 1 );
            str += $1 + $2;
        }
    }
    return( str );
}
%}}}

%!%+
%\function{md5}
%\synopsis{md5}
%\usage{String_Type md5( String_Type );}
%\description
% Return the hex representation of the MD5 of the given string.
%\seealso{md5_region, md5_buffer}
%!%-
public define md5( str ) %{{{
{
    variable X = get_blocks( str );
    variable a = 0x67452301;
    variable b = 0xefcdab89;
    variable c = 0x98badcfe;
    variable d = 0x10325476;
    variable a0, b0, c0, d0;
    variable i;

    for( i = 0; i < length( X ); i += 16 )
    {
        a0 = a; b0 = b; c0 = c; d0 = d;

        % Round 1
        a = FF( a, b, c, d, X[i+ 0],  7, 0xd76aa478 );
        d = FF( d, a, b, c, X[i+ 1], 12, 0xe8c7b756 );
        c = FF( c, d, a, b, X[i+ 2], 17, 0x242070db );
        b = FF( b, c, d, a, X[i+ 3], 22, 0xc1bdceee );
        a = FF( a, b, c, d, X[i+ 4],  7, 0xf57c0faf );
        d = FF( d, a, b, c, X[i+ 5], 12, 0x4787c62a );
        c = FF( c, d, a, b, X[i+ 6], 17, 0xa8304613 );
        b = FF( b, c, d, a, X[i+ 7], 22, 0xfd469501 );
        a = FF( a, b, c, d, X[i+ 8],  7, 0x698098d8 );
        d = FF( d, a, b, c, X[i+ 9], 12, 0x8b44f7af );
        c = FF( c, d, a, b, X[i+10], 17, 0xffff5bb1 );
        b = FF( b, c, d, a, X[i+11], 22, 0x895cd7be );
        a = FF( a, b, c, d, X[i+12],  7, 0x6b901122 );
        d = FF( d, a, b, c, X[i+13], 12, 0xfd987193 );
        c = FF( c, d, a, b, X[i+14], 17, 0xa679438e );
        b = FF( b, c, d, a, X[i+15], 22, 0x49b40821 );

        % Round 2
        a = GG( a, b, c, d, X[i+ 1],  5, 0xf61e2562 );
        d = GG( d, a, b, c, X[i+ 6],  9, 0xc040b340 );
        c = GG( c, d, a, b, X[i+11], 14, 0x265e5a51 );
        b = GG( b, c, d, a, X[i+ 0], 20, 0xe9b6c7aa );
        a = GG( a, b, c, d, X[i+ 5],  5, 0xd62f105d );
        d = GG( d, a, b, c, X[i+10],  9, 0x2441453  );
        c = GG( c, d, a, b, X[i+15], 14, 0xd8a1e681 );
        b = GG( b, c, d, a, X[i+ 4], 20, 0xe7d3fbc8 );
        a = GG( a, b, c, d, X[i+ 9],  5, 0x21e1cde6 );
        d = GG( d, a, b, c, X[i+14],  9, 0xc33707d6 );
        c = GG( c, d, a, b, X[i+ 3], 14, 0xf4d50d87 );
        b = GG( b, c, d, a, X[i+ 8], 20, 0x455a14ed );
        a = GG( a, b, c, d, X[i+13],  5, 0xa9e3e905 );
        d = GG( d, a, b, c, X[i+ 2],  9, 0xfcefa3f8 );
        c = GG( c, d, a, b, X[i+ 7], 14, 0x676f02d9 );
        b = GG( b, c, d, a, X[i+12], 20, 0x8d2a4c8a );

        % Round 3
        a = HH( a, b, c, d, X[i+ 5],  4, 0xfffa3942 );
        d = HH( d, a, b, c, X[i+ 8], 11, 0x8771f681 );
        c = HH( c, d, a, b, X[i+11], 16, 0x6d9d6122 );
        b = HH( b, c, d, a, X[i+14], 23, 0xfde5380c );
        a = HH( a, b, c, d, X[i+ 1],  4, 0xa4beea44 );
        d = HH( d, a, b, c, X[i+ 4], 11, 0x4bdecfa9 );
        c = HH( c, d, a, b, X[i+ 7], 16, 0xf6bb4b60 );
        b = HH( b, c, d, a, X[i+10], 23, 0xbebfbc70 );
        a = HH( a, b, c, d, X[i+13],  4, 0x289b7ec6 );
        d = HH( d, a, b, c, X[i+ 0], 11, 0xeaa127fa );
        c = HH( c, d, a, b, X[i+ 3], 16, 0xd4ef3085 );
        b = HH( b, c, d, a, X[i+ 6], 23, 0x4881d05  );
        a = HH( a, b, c, d, X[i+ 9],  4, 0xd9d4d039 );
        d = HH( d, a, b, c, X[i+12], 11, 0xe6db99e5 );
        c = HH( c, d, a, b, X[i+15], 16, 0x1fa27cf8 );
        b = HH( b, c, d, a, X[i+ 2], 23, 0xc4ac5665 );

        % Round 4
        a = II( a, b, c, d, X[i+ 0],  6, 0xf4292244 );
        d = II( d, a, b, c, X[i+ 7], 10, 0x432aff97 );
        c = II( c, d, a, b, X[i+14], 15, 0xab9423a7 );
        b = II( b, c, d, a, X[i+ 5], 21, 0xfc93a039 );
        a = II( a, b, c, d, X[i+12],  6, 0x655b59c3 );
        d = II( d, a, b, c, X[i+ 3], 10, 0x8f0ccc92 );
        c = II( c, d, a, b, X[i+10], 15, 0xffeff47d );
        b = II( b, c, d, a, X[i+ 1], 21, 0x85845dd1 );
        a = II( a, b, c, d, X[i+ 8],  6, 0x6fa87e4f );
        d = II( d, a, b, c, X[i+15], 10, 0xfe2ce6e0 );
        c = II( c, d, a, b, X[i+ 6], 15, 0xa3014314 );
        b = II( b, c, d, a, X[i+13], 21, 0x4e0811a1 );
        a = II( a, b, c, d, X[i+ 4],  6, 0xf7537e82 );
        d = II( d, a, b, c, X[i+11], 10, 0xbd3af235 );
        c = II( c, d, a, b, X[i+ 2], 15, 0x2ad7d2bb );
        b = II( b, c, d, a, X[i+ 9], 21, 0xeb86d391 );

        a += a0; b += b0; c += c0; d += d0;
    }

    return( digest( a, b, c, d ));
}
%}}}

%!%+
%\function{md5_region}
%\synopsis{md5_region}
%\usage{String_Type md5_region();}
%\description
% Return the hex representation of the MD5 of the selected region.
%\seealso{md5, md5_buffer}
%!%-
public define md5_region() %{{{
{
    !if( markp )
    {
        error( "Set mark first." );
    }
    else
    {
        return( md5( bufsubstr()));
    }
}
%}}}


%!%+
%\function{md5_buffer}
%\synopsis{md5_buffer}
%\usage{String_Type md5_buffer();}
%\description
% Return the hex representation of the MD5 of the current buffer.
%\seealso{md5, md5_region}
%!%-
public define md5_buffer() %{{{
{
    push_spot();
    bob();
    push_mark();
    eob();
    $0 = md5_region();
    pop_spot();
    return( $0 );
}
%}}}

%
% MD5 Test suite (see RFC1321). It should be:
%
%   md5( "" ) = d41d8cd98f00b204e9800998ecf8427e
%
%   md5( "a" ) = 0cc175b9c0f1b6a831c399e269772661
%
%   md5( "abc" ) = 900150983cd24fb0d6963f7d28e17f72
%
%   md5( "message digest" ) = f96b697d7cb7938d525a2f31aaf161d0
%
%   md5( "abcdefghijklmnopqrstuvwxyz" ) = c3fcd3d76192e4007dfb496cca67e13b
%
%   md5( "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ) =
%         d174ab98d277d9f5a5611c2c9f419d9f
%
%   md5( "12345678901234567890123456789012345678901234567890123456789012345678901234567890" ) =
%         57edf4a22be3c955ac49da2e2107b67a
%

provide( "md5" );
% md5 of this file (not including this line): e615244d73ab7bccab96de5b2938d71c

% URI -- let jed handle Universal Ressource Indicators
%
% Copyright (c) 2003 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% This mode parses the filename and if it forms an URI (scheme:path), calls 
% the appropriate <scheme>_uri_hook or <scheme>_write_uri_hook.
% Drawbacks:  
%   a colon [:] in the path can lead to misinterpretation
% 
% An easily extensible set of such uri_hooks is provided by services.sl.
% 
% see also http://www.w3.org/Addressing/
%          http://www.w3.org/Addressing/URL/URI_Overview.html
%          http://www.w3.org/Addressing/schemes.html
%          
% % Versions:
% 1.0               first public version
% 1.1               outsourced the definition of services to the services.sl 
% 		    file (for faster startup)
%       	    added the provide("uri")
% 1.2  2004-11-25   bugfix: find_uri returned a value if the uri did not 
%      		    contain a scheme: part
% 1.2.1 2005-04-21  parse_uri() code cleanup and additional check: 
%                   if there is a path-separator before the colon,
%                   assume the path to be no URI but a simple path 
%                   containing a colon.
% 1.3 2005-10-14    Bugfix in write_uri() and documentation update
% 
% USAGE:
% 
% Put in the jed_library_path and write in .jedrc/jed.rc:
% 
% * if you only want to use the find_uri/write_uri
%     autoload("find_uri", "uri");
%     autoload("write_uri", "uri");    
%   
%   bind to keys of your choice or use rebind from bufutils.sl
%     rebind("find_file", "find_uri");
%     rebind("save_buffer_as", "write_uri");
%  
% * if you want find_file and related functions to be URI-aware
%   (e.g. to be able to start jed with 'jed locate:foo.sl')
%     autoload("find_uri_hook", "uri");
%     autoload("write_uri_hook", "uri");    
%     add_to_hook("_jed_write_region_hooks", &write_uri_hook);
%     add_to_hook("_jed_find_file_before_hooks", &find_uri_hook);
%   or (to check other write|find-file-hooks first)  
%     append_to_hook("_jed_write_region_hooks", &write_uri_hook);
%     append_to_hook("_jed_find_file_before_hooks", &find_uri_hook);
%     
%   Problem: Currently, a relative filename is expanded before passing 
%   it to the _jed_find_file_before_hooks, with the sideeffect of 
%   "http://host.domain" becoming "/host.domain"
%   -> find_file doesnot work for URIs with a double slash
%
%   If you want to be able to start jed with e.g.
%      jed http://jedmodes.sf.net/mode/uri/
%   you can copy the 194 lines of the command_line_hook from site.sl 
%   to your .jedrc and modify the 6.-last line from
%     () = find_file (next_file_arg);
%   to
%     () = find_uri (next_file_arg);
%     
%   CAUTION: hooks.txt says that this hook should not be customized by
%   	     the user.  

% Requirements
autoload("run_function", "sl_utils");

% _debug_info = 1;

% parse uri and return (scheme, path)
static define parse_uri(uri)
{
   % currently, a filename is expanded before passing it to the
   % _jed_find_file_before_hooks :-(
   
   % hack to undo the change (as far as possible)
   if(is_substr(uri, getcwd) == 1)
     uri = uri[[strlen(getcwd):]];
   % show("parse uri", uri);
   
   % URI = scheme:path (path can be any argument to scheme)
   variable fields = strchop(uri, ':', 0);
   % show(fields);
   % no scheme given
   if (length(fields) == 1)
     return("", uri);
   
   % no scheme given and ":" in a later component of the path
   % (the scheme must not contain a directory separator ("/" or "\")
   if (fields[0] != path_basename(fields[0])) 
     return("", uri);

   return fields[0], strjoin(fields[[1:]],":");
}

%!%+
%\function{find_uri_hook}
%\synopsis{Open a universal ressource indicator}
%\usage{Int_Type find_uri_hook(String_Type uri)}
%\description
%   Open a Universal Ressource Indicator (URI) consisting of a scheme and 
%   a path separated by a colon (":"). 
%   
%   Calls a hook for the scheme with the path as argument. 
%   Defining the appropriate hooks, it is possible to let jed 
%   handle an extensible choice of URI schemes.
%   
%   If no matching <scheme>_uri_hook is found or the argument doesnot 
%   contain a colon, 0 is returned, otherwise 1 is returned. With
%#v+
%      add_to_hook("_jed_find_file_before_hooks", &find_uri_hook);
%#v-
%   the usual file-finding functions become URI-aware.
%   
%\example
%#v+
%   find_uri_hook("floppy:uri.sl");
%#v-
%   calls
%#v+
%   floppy_uri_hook("uri.sl");
%#v-
%   which would load uri.sl from the floppy disk (e.g. using mtools)
%\notes
%   Unfortunately, currently, a relative filename is expanded before 
%   passing it to the  _jed_find_file_before_hooks, with the sideeffect of 
%   "http://example.org" becoming "/example.org" (and no uri opened)

%   A partial workaround is to bind find_uri() or ffap() from ffap.sl 
%   to the key used for find_file() (e.g. using \var{rebind}).
%\seealso{find_uri, ffap, find_file, write_uri_hook}
%!%-
define find_uri_hook(uri)
{
   variable scheme, path;
   (scheme, path) = parse_uri(uri);
   % show("find_uri_hook", scheme, path);
   % call a scheme_uri_hook with the path argument
   return run_function(scheme + "_uri_hook", path);
}

%!%+
%\function{find_uri}
%\synopsis{Open a universal ressource indicator}
%\usage{find_uri(String_Type uri)}
%\description
%   A transparent expansion of find_file to Universal Ressource Indicators 
%   (URIs, http://www.w3.org/Addressing/URL/URI_Overview.html)
%   Open a URI consisting of a scheme and a path separated by
%   a colon (":").
%   
%   If no matching <scheme>_uri_hook is found, a warning message is given.
%   If the argument doesnot contain a colon (i.e. is no URI), it is assumed 
%   to be a filename and handed to find_file().
%
%\notes
%   find_uri() does not return a value, so it can be bound to a key easily.
%   
%   While the intrinsic find_file returns an integer (success or not), 
%   the internal find_file (as called from setkey()) has no return value.
%         
%\seealso{write_uri, ffap, find_file, find_uri_hook}
%!%-
public define find_uri() % (uri=ask)
{
   variable uri;
   if (_NARGS)
     uri = ();
   else
     uri = read_mini("Find URI", "", "");

   !if (find_uri_hook(uri))
     message("No scheme found to open URI " + uri);
   % fallback
   !if(is_substr(uri, ":"))
     () = find_file(uri);
}


%!%+
%\function{write_uri_hook}
%\synopsis{Write to an Universal Ressource Indicator (URI)}
%\usage{Integer write_uri_hook(uri)}
%\description
%  Write to a Universal Ressource Indicator (URI) of the form
%  "scheme:path".
%  
%  Calls a scheme-hook for "scheme" with "path" as argument. 
%  If no scheme-hook is found or the argument doesnot contain 
%  a colon, 0 is returned, otherwise 1 is returned.
%  
%  The scheme-hook is a function whose name consists of the parts
%  "scheme" and "_uri_hook", i.e. a http-hook must be called
%  "http_uri_hook". It must return 1 on success and 0 otherwise.
%  
%  Defining the appropriate hooks, it is possible to let jed 
%  handle an extensible choice of URI schemes.
%\notes
%  With
%#v+
%     append_to_hook("_jed_write_region_hooks", &write_uri_hook);
%#v-
%  jed can be made "URI aware". 
%  
%  However:
%  Unfortunately, currently, a relative filename is expanded before 
%  passing it to the  _jed_write_region_hooks, with the sideeffect of 
%  "http://example.org" becoming "/example.org" (and thus an attempt 
%  is made to write example.org to the root directory).
%\seealso{write_uri, write_buffer, find_uri_hook}
%!%-
define write_uri_hook(uri)
{
   variable scheme, path;
   (scheme, path) = parse_uri(uri);
   % % debugging
   % show("write_uri_hook", uri, scheme, path);
   % show("run_function", scheme + "_write_uri_hook", path);
   % return 1; 
   return run_function(scheme + "_write_uri_hook", path);
}

%!%+
%\function{write_uri}
%\synopsis{Open a universal ressource indicator}
%\usage{write_uri(String_Type uri)}
%\description
%  Save the buffer to a universal resource indicator (URI).
%\seealso{find_uri, write_uri_hook, write_buffer, save_buffer_as}
%!%-
public define write_uri() % (uri=ask)
{
   variable uri;
   if (_NARGS)
     uri = ();
   else
    uri = read_with_completion ("Write to URI:", "", whatbuf, 'f');

   !if (write_uri_hook(uri))
     message("No scheme found for writing URI " + uri);
   !if(is_substr(uri, ":"))
     write_buffer(uri);
}

provide("uri");

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
% 1.0             first pubic version
% 1.1             outsourced the definition of services to the services.sl 
% 		  file (for faster startup)
%       	  added the provide("uri")
% 1.2  2004-11-25 bugfix: find_uri returned a value if the uri did not 
%      		  contain a scheme: part
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
%     rebind("save_buffer", "write_uri");
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
%   -> find_file doesnot work for http/ftp, 
%
%   If you want to be able to start jed with e.g.
%      jed http://jedmodes.sf.net/mode/uri/
%   you can copy the 194 lines of the command_line_hook from site.sl 
%   to your .jedrc and modify the 6.-last line from
%     () = find_file (next_file_arg);
%   to
%     () = find_uri (next_file_arg);

% Requirements
autoload("run_function", "sl_utils");

% _debug_info = 1;

% parse uri and return (scheme, path)
static define parse_uri(uri)
{
   % currently, a relative filename is expanded before passing it to the
   % _jed_find_file_before_hooks :-(
   variable pwd = expand_filename("");
   if(is_substr(uri, pwd) == 1)
     uri = uri[[strlen(pwd):]];
   % show("parse uri", uri);
   
   % URI = scheme:path (path can be any argument to scheme)
   variable sep = is_substr(uri, ":");
   !if (sep)
     return("", uri);
   return(uri[[:sep-2]], uri[[sep:]]);
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
%   A partial workaround is to bind find_uri() to the key used for 
%   find_file().
%\seealso{find_uri, find_file, run_function, runhooks}
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
%\seealso{find_uri_hook, find_file, run_function, runhooks}
%!%-
public define find_uri() % (uri=ask)
{
   variable uri;
   if (_NARGS)
     uri = ();
   else
    uri = read_with_completion ("Find URI", "", "", 'f');

   !if (find_uri_hook(uri))
     message("No scheme found to open URI " + uri);
   % fallback
   !if(is_substr(uri, ":"))
     () = find_file(uri);
}


%!%+
%\function{write_uri_hook}
%\synopsis{Write to an Universal Ressource Indicator (URI)}
%\usage{ write_uri_hook(uri)}
%\description
%   The analogon to find_uri_hook().
%\notes
%   Unfortunately, currently, a relative filename is expanded before 
%   passing it to the  _jed_write_region_hooks, with the sideeffect of 
%   "http://example.org" becoming "/example.org" (and no uri opened)
%\seealso{}
%!%-
define write_uri_hook(uri)
{
   variable scheme, path;
   (scheme, path) = parse_uri(uri);
   % show("write_uri_hook", uri, scheme, path);
   % call scheme_write_uri_hook with the path argument
   % show("run_function", scheme + "_write_uri_hook", path);
   return run_function(scheme + "_write_uri_hook", path);
}

%!%+
%\function{write_uri}
%\synopsis{Open a universal ressource indicator}
%\usage{write_uri(String_Type uri)}
%\description
%  Analogon to find_uri.
%\seealso{find_uri_hook, write_region, write_region_to_file}
%!%-
public define write_uri() % (uri=ask)
{
   variable uri;
   if (_NARGS)
     uri = ();
   else
    uri = read_with_completion ("Write URI", "", whatbuf, 'f');

   !if (write_uri_hook(uri))
     message("No scheme found for writing URI " + uri);
   !if(is_substr(uri, ":"))
     write_buffer(uri);
}

provide("uri");

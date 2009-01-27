% test-browse_url.sl: Test browse_url.sl with unittest.sl
% 
% Copyright © 2006 Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions:
% 0.1 2006-03-03 

require("unittest");

variable test_url = "http://www.example.org";

% find_url(url=read_mini, cmd = Browse_Url_Download_Cmd); Find a file by URL
%  public define find_url() %(url=read_mini, cmd = Browse_Url_Download_Cmd)
test_function("find_url", test_url);
test_last_result();
test_equal(whatbuf(), test_url);
delbuf(test_url);

% view_url(Str url=read_mini, Str cmd= Browse_Url_Viewer); View an ASCII rendering of a URL
%  public define view_url() %(url=read_mini, cmd= Browse_Url_Viewer)
test_function("view_url", test_url);
test_last_result();
test_equal(whatbuf(), "*"+test_url+"*");
delbuf("*"+test_url+"*");

% public  define browse_url_x() %(url, cmd=Browse_Url_X_Browser)
% browse_url_x(Str url=ask, Str cmd=Browse_Url_X_Browser); Open a URL in a browser
testmessage("\n  browse_url_x() needs interactive testing,");
testmessage("\n  (opens a document in an external browser with system())");
%  test_function("browse_url_x", test_url);
% test_last_result();
%   browse_url_x(): OK ()

% public define browse_url() %(url=read_mini, cmd=Browse_Url_Browser)
% browse_url() %(url=read_mini, cmd=Browse_Url_Browser); Open the url in a browser
testmessage("\n  browse_url() needs interactive testing,");
testmessage("\n  (opens a document in an external browser with system())");
% (commented out to prevent side effects)
% test_function("browse_url", test_url);
% test_last_result();
%  browse_url(http://jedmodes.sourceforge.net/mode/cua/index.php): OK ()

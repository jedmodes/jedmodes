% gpg.sl
% Interface to GnuPG
%
% $Id: gpg.sl,v 1.2 2003/11/16 19:55:49 paul Exp paul $
% Keywords: mail
%
% Copyright (c) 2003 Paul Boekholt. No warranty.
% Released under the terms of the GNU GPL (version 2 or later).
%
% Functions like process_region() all read from a temporary file, or from
% the buffer, not safe places to leave your passphrase.  Using
% asynchronous processes is clumsy since JED should wait until gpg is
% finished, so we use a temporary buffer that is deleted in an
% ERROR_BLOCK. notes:
%  - Make sure your library path is not writable.
%  - This would be much safer if were an intrinsic function.

static variable password = "";
static variable pw_time = 0;
custom_variable("Gpg_Comment", "processed by gpg.sl <http://jedmodes.sf.net>");
% comma separated list of recipients
custom_variable("Gpg_Recipients", "");
static define read_password()
{
   variable str = "enter password: ", password = " ", c;
   forever
     {
	c = get_mini_response (str);
	if (c == '') return password[[1:]]; % p[[:-2]] wraps around or something when p has len 1
	if (c == 127) % backspace
	  {
	     password = password[[:-2]];
	     str = str[[:-2]];
	  }
	else
	  {
	     password += char(c);
	     str += "*";
	  }
     }
}

static define gpg(options, give_password, comment)
{
   variable cmd, tmp_file, err_file, buf = whatbuf,
     gbuf = " *gpg*";
   push_narrow;
   if (is_visible_mark) narrow;
   mark_buffer;
   variable contents = bufsubstr;
   if (bufferp(gbuf))
     delbuf(gbuf);

   setbuf(gbuf);
   tmp_file = make_tmp_file (dircat (Jed_Home_Directory, "gpgpipe"));
   err_file = make_tmp_file (dircat (Jed_Home_Directory, "gpgerr"));
   cmd = strcat ("gpg ", options, " > ", tmp_file, " 2> ", err_file);

   ERROR_BLOCK
     {
	() = delete_file (tmp_file);
	delbuf(gbuf);
	sw2buf(buf);
	pop_narrow;
	pop2buf("*gpg errors*");
	erase_buffer;
	()=insert_file(err_file);
	() = delete_file (err_file);
	password = "";
	pop2buf(buf);
     }

   if(give_password)
     {
	if (password == "" or _time - pw_time > 360)
	  password = read_password;
	pw_time = _time();
	insert(password + "\n");
     }
   insert(contents);
   mark_buffer;
   if(pipe_region (cmd) > 1)
     {
	error ("GPG returned an error.");
     }
   delbuf(gbuf);

   setbuf(buf);
   erase_buffer;
   () = insert_file(tmp_file);
   () = delete_file (tmp_file);
   bob;
   if (andelse
       {comment}
	 {bol_fsearch("Comment:")})
     {
	go_right(9);
	del_eol;
	insert(Gpg_Comment);
     }
   pop_narrow;
}

public define gpg_encrypt()
{
   variable Bob = read_with_completion
     (Gpg_Recipients, "Recipients", "", "", 's');
   if (get_y_or_n("Sign the message"))
     gpg
     (sprintf ("-sea --batch --always-trust --no-tty --quiet --passphrase-fd 0 -r %s",
	       Bob), 1, 1);
   else
     gpg(sprintf("-ea --batch --always-trust --no-tty -r %s", Bob), 0, 1);
}

public define gpg_decrypt()
{
   gpg("--no-tty --quiet --passphrase-fd 0", 1, 0);
}

public define gpg_sign()
{
   gpg(sprintf("--clearsign --no-tty --quiet --passphrase-fd 0"), 1, 1);
}

% In case you take a break, or typed a wrong password
public define gpg_forget_password()
{
   password = "";
}

provide ("gpg");

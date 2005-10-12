% mailcrypt.sl
% Interface to GnuPG
%
% $Id: mailcrypt.sl,v 1.3 2005/10/12 18:58:04 paul Exp paul $
% Keywords: mail
%
% Copyright (c) 2003,2005 Paul Boekholt. No warranty.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This was formerly gpg.sl, but that name conflicts with a gpg.sl in the
% standard library.

provide ("mailcrypt");

private variable password = "";
private variable pw_time = 0;
custom_variable("Mailcrypt_Comment", "processed by mailcrypt.sl <http://jedmodes.sf.net>");
% comma separated list of recipients
custom_variable("Mailcrypt_Recipients", "");
private define read_password()
{
   variable str = "enter password: ", password = " ", c;
   forever
     {
	c = get_mini_response (str);
	if (c == '\r') return password[[1:]]; % p[[:-2]] wraps around or something when p has len 1
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

private define gpg(options, give_password, comment)
{
   variable cmd, tmp_file, err_file, buf = whatbuf,
     gbuf = " *mailcrypt*";
   push_narrow;
   if (is_visible_mark) narrow;
   mark_buffer;
   variable contents = bufsubstr;
   if (bufferp(gbuf))
     delbuf(gbuf);

   setbuf(gbuf);
   tmp_file = dircat (Jed_Home_Directory, "gpgpipe");
   err_file = dircat (Jed_Home_Directory, "gpgerr");
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
	insert(Mailcrypt_Comment);
     }
   pop_narrow;
}

public define mc_encrypt()
{
   variable Bob = read_with_completion
     (Mailcrypt_Recipients, "Recipients", "", "", 's');
   if (get_y_or_n("Sign the message"))
     gpg
     (sprintf ("-sea --batch --always-trust --no-tty --quiet --passphrase-fd 0 -r %s",
	       Bob), 1, 1);
   else
     gpg(sprintf("-ea --batch --always-trust --no-tty -r %s", Bob), 0, 1);
}

public define mc_decrypt()
{
   gpg("--no-tty --quiet --passphrase-fd 0", 1, 0);
}

public define mc_sign()
{
   gpg(sprintf("--clearsign --no-tty --quiet --passphrase-fd 0"), 1, 1);
}

% In case you take a break, or typed a wrong password
public define mc_forget_password()
{
   password = "";
}

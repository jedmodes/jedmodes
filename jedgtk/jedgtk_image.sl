#!/usr/bin/env slsh
% jedgtk_image.sl
% gtk image viewer
% 
% $Id: jedgtk_image.sl,v 1.2 2004/06/28 11:04:58 paul Exp paul $
% Keywords: gtk
%
% Copyright (c) 2004 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This works in slsh as well, probably in slrn too.
% to open image files with this in JED, write something like this:
% define jedgtk_image_hook (file)
% {
%    if (is_list_element
%        (".jpeg,.jpg,.png,.gif,.xpm,.bmp,.pbm",path_extname(file), ','))
%      return jedgtk_image(file), 1;
%    return 0;
% }
% add_to_hook ("_jed_find_file_before_hooks", &jedgtk_image_hook);


import ("gtk");

public define jedgtk_image(file)
{
   % read the image - we don't use gtk_image_new_from_file()
   % because we need the width and height
   variable image;
   variable img_error;
   image = gdk_pixbuf_new_from_file (file, &img_error);
   if (img_error != NULL)
     return message (img_error.message);

   % make the top window
   variable window = gtk_window_new (GTK_WINDOW_TOPLEVEL);
   gtk_window_set_default_size (window,
				gdk_pixbuf_get_width (image) + 20,
				gdk_pixbuf_get_height (image) + 45);
   () = g_signal_connect (window, "destroy", &gtk_main_quit);
   gtk_window_set_title (window, file);
   gtk_container_set_border_width (window, 0);
   variable box1 = gtk_vbox_new (FALSE, 0);
   gtk_container_add (window, box1);
   
   % scrollwindow
   variable scrolled_window = gtk_scrolled_window_new (NULL, NULL);
   gtk_container_set_border_width (scrolled_window, 0);
   gtk_scrolled_window_set_policy (scrolled_window,
   				   GTK_POLICY_ALWAYS,
   				   GTK_POLICY_ALWAYS);
   gtk_container_add (box1, scrolled_window);
   
   % image
   image = gtk_image_new_from_pixbuf (__tmp (image));
   gtk_scrolled_window_add_with_viewport (scrolled_window, image);

   % close button
   variable vbox = gtk_vbox_new (FALSE, 5);
   gtk_container_set_border_width (vbox, 0);
   gtk_box_pack_end (box1,vbox,FALSE,FALSE,0);
   variable close_button = gtk_button_new_with_label ("Close");
   () = g_signal_connect_swapped (close_button, "clicked",&gtk_widget_destroy,window);
   gtk_box_pack_start (vbox,close_button,FALSE,FALSE,0);
   
   gtk_widget_show_all (window);
   gtk_widget_grab_focus (close_button);
   gtk_main ();
}

public define slsh_main()
{
   jedgtk_image (__argv[1]);
   exit (0);   
}

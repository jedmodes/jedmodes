% flipper.sl
% 
% $Id: flipper.sl,v 1.1 2004/06/24 21:51:55 paul Exp paul $
% Keywords: gtk, games
%
% Copyright (c) 2004 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% In Emacs this game is called 5x5.

import("gtk");

static variable count, countlabel;
static define field_toggle(w, fields, i)
{
   % increase count
   count++;
   gtk_label_set_text(countlabel, sprintf("%d", count));
   
   % toggle fields
   variable j;
   USER_BLOCK0
     {
	j = ();
	if (gtk_button_get_label(fields[j]) == "   ")
	  gtk_button_set_label(fields[j], " X ");
	else
	  gtk_button_set_label(fields[j], "   ");
     }
   X_USER_BLOCK0(i);
   if (i mod 5)
     X_USER_BLOCK0(i - 1);
   if (i mod 5 < 4)
     X_USER_BLOCK0(i + 1);
   if (i > 4)
     X_USER_BLOCK0(i - 5);
   if(i <20)
     X_USER_BLOCK0(i + 5);
   
   % see if we're finished
   _for(0, 24, 1)
     {
	i = ();
	if (gtk_button_get_label(fields[i]) == "   ") return;
     }
   variable parent = gtk_widget_get_parent(w);
   variable grandparent = gtk_widget_get_parent(parent);
   gtk_object_destroy(parent);
   variable done_label = gtk_label_new(sprintf("done in %d moves\nthanks for playing", count));
   gtk_box_pack_start (grandparent, done_label, TRUE, TRUE, 0);
   gtk_widget_show(done_label);
}

public define flipper ()
{
   
   variable window = gtk_window_new (GTK_WINDOW_TOPLEVEL);
   () = g_signal_connect(window, "destroy", &gtk_main_quit);
   
   gtk_window_set_title ((window), "Flipper");
   gtk_container_set_border_width ( (window), 0);
   
   variable box1 = gtk_vbox_new (FALSE, 0);
   gtk_container_add ( window, box1);
   
   variable table = gtk_table_new (5, 5, FALSE);
   gtk_table_set_row_spacings (table, 5);
   gtk_table_set_col_spacings (table, 5);
   gtk_table_set_homogeneous(table, 1);
   gtk_container_set_border_width ( (table), 10);
   gtk_box_pack_start ( box1, table, TRUE, TRUE, 0);
   
   variable i, fields = GtkWidget[25], row, column;
   _for (0, 24, 1)
     {
	i = ();
	row = i / 5;
	column = i mod 5;
	fields[i] = gtk_button_new_with_label ("   ");
	() = g_signal_connect ( fields[i], "clicked",
				&field_toggle, fields, i);
	gtk_table_attach ( table, fields[i], column, column + 1, row, row +1,
		      GTK_EXPAND | GTK_FILL, GTK_EXPAND | GTK_FILL, 0, 0);
     }

   variable vbox = gtk_vbox_new (FALSE, 5);
   gtk_container_set_border_width (vbox, 5);
   gtk_box_pack_end(box1,vbox,FALSE,FALSE,0);

   count = 0;
   countlabel = gtk_label_new("0");
   gtk_box_pack_start(vbox,countlabel,FALSE,FALSE,0);
   variable button = gtk_button_new_with_label("Close");
   () = g_signal_connect_swapped(button,"clicked",&gtk_widget_destroy,window);
   gtk_box_pack_start(vbox,button,FALSE,FALSE,0);

   gtk_widget_show_all(window);
   gtk_main();
}

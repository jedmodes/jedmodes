% jedgtk_search.sl
% 
% $Id: jedgtk_search.sl,v 1.1 2004/06/27 07:56:19 paul Exp paul $
% Keywords:
%
% Copyright (c) 2004 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% A simple gtk search dialog for JED.  When the end of the buffer is reached,
% it pops up a dialog button asking if it should start from the beginning.  In
% XJED, when the popup window disappears, the area it had occupied is blank -
% it's redrawn when you press enter, but by then the search will have moved on
% to the second match from the beginning.  In JED in xterm it works fine.
import ("gtk");

static define activate_search();
static variable dialog_window, text_entry;

static define search_beginning()
{
   gtk_widget_destroy (dialog_window);
   bob ();
   activate_search (text_entry);
   % Is there a way to redraw the area that was occupied 
   % by the dialog window?
}


static define activate_search(entry)
{
   text_entry = entry;
   variable text = gtk_entry_get_text (entry); 
   if (fsearch (text))
     {
	push_visible_mark ();
	go_right (strlen (text));
	update_sans_update_hook (0);
	pop_mark_0 ();
     }
   else
     {
	dialog_window = gtk_dialog_new ();
	
	() = g_signal_connect (dialog_window,"destroy",
			       &gtk_widget_destroyed,
			       &dialog_window);
	
	gtk_container_set_border_width (dialog_window, 0);
	
	variable label = gtk_label_new ("Search string not found. Continue from beginning?");
	gtk_misc_set_padding (label, 10, 10);
	gtk_box_pack_start (gtk_dialog_get_vbox (dialog_window),
			    label, TRUE, TRUE, 0);
	
	variable button = gtk_button_new_with_label ("Yes");
	() = g_signal_connect_swapped (button,"clicked", &search_beginning,
				       dialog_window);
	variable action_area = gtk_dialog_get_action_area(dialog_window);
	gtk_box_pack_start (action_area,button,TRUE, TRUE, 0);
	
	button = gtk_button_new_with_label ("Close");
	() = g_signal_connect_swapped (button, "clicked", &gtk_widget_destroy, dialog_window);
	gtk_box_pack_start (action_area, button, TRUE, TRUE, 0);
	gtk_widget_show_all (dialog_window);
     }
}


public define jedgtk_search ()
{
   
   variable window = gtk_window_new (GTK_WINDOW_TOPLEVEL);
   () = g_signal_connect (window, "destroy", &gtk_main_quit);
   
   gtk_window_set_title (window, "search");
   gtk_container_set_border_width (window, 0);
   
   variable box1 = gtk_vbox_new (FALSE, 0);
   gtk_container_add (window, box1);
   
   variable search_entry = gtk_entry_new ();
   gtk_container_add (box1, search_entry);
   () = g_signal_connect (search_entry, "activate", &activate_search );
   
   % close button
   variable vbox = gtk_vbox_new (FALSE, 5);
   gtk_container_set_border_width (vbox, 5);
   gtk_box_pack_end (box1,vbox,FALSE,FALSE,0);
   variable close_button = gtk_button_new_with_label ("Close");
   () = g_signal_connect_swapped (close_button,"clicked",&gtk_widget_destroy,window);
   gtk_box_pack_start (vbox,close_button,FALSE,FALSE,0);
   
   gtk_widget_show_all (window);
   gtk_main ();
}

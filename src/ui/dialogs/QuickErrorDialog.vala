/*
This file is part of GameHub.
Copyright (C) 2018-2019 Anatoliy Kashkin

GameHub is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

GameHub is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GameHub.  If not, see <https://www.gnu.org/licenses/>.
*/


namespace GameHub.UI.Dialogs
{
	public class QuickErrorDialog : Gtk.MessageDialog
	{
		[PrintfFormat]
		public QuickErrorDialog(Gtk.Widget? parent, Utils.RunError error, string? text_fmt, ...)
		{
			// Set properties on dialog like `Gtk.MessageDialog.new` does:
			// https://gitlab.gnome.org/GNOME/gtk/-/blob/8cb50ac6e9c6a78f337e4ad2bb61aa0558844904/gtk/gtkmessagedialog.c#L492-552
			Object(
				use_header_bar: 0,
				message_type: Gtk.MessageType.ERROR,
				buttons: Gtk.ButtonsType.OK
			);
			this.set_transient_for(parent.get_toplevel() as Gtk.Window);
			
			// Generate primary error text
			if(text_fmt != null)
			{
				va_list va_list = va_list();
				this.text = text_fmt.vprintf(va_list);
			}
			
			// Generate secondary error text from exception
			if(error.message.last_index_of_char(')', error.message.length - 1) > -1)
			{
				this.format_secondary_text("%s-(%s:%d)", error.message, error.domain.to_string(), error.code);
			}
			else
			{
				this.format_secondary_text("%s (%s:%d)", error.message, error.domain.to_string(), error.code);
			}
		}
		
		
		public static async int display_and_log(Gtk.Widget? parent, Utils.RunError error, string caller_name, string text)
		{
			// Create dialog object
			QuickErrorDialog dialog = new QuickErrorDialog(parent, error, null);
			
			// Format and set primary text
			dialog.text = text;
			
			// Log error message
			warning("[%s] %s – %s", caller_name, text, dialog.secondary_text);
			
			// Display error message
			dialog.show();
			
			// Delay response until dialog is closed
			int response_id = Gtk.ResponseType.NONE;
			dialog.response.connect((response) => {
				response_id = response;
				display_and_log.callback();
			});
			dialog.destroy.connect(() => {
				if(response_id == Gtk.ResponseType.NONE)
				{
					display_and_log.callback();
				}
			});
			yield;
			
			// Clean up and return selected ID
			dialog.destroy();
			return response_id;
		}
	}
}
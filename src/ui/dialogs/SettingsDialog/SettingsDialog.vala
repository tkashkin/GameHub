using Gtk;
using Granite;
using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog
{
	public class SettingsDialog: Dialog
	{
		private static bool restart_msg_shown = false;

		private InfoBar restart_msg;

		private Stack tabs;

		public SettingsDialog(string tab="ui")
		{
			Object(transient_for: Windows.MainWindow.instance, deletable: false, resizable: false, title: _("Settings"));

			gravity = Gdk.Gravity.NORTH;
			modal = true;

			var content = get_content_area();
			content.set_size_request(480, -1);

			restart_msg = new InfoBar();
			restart_msg.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);
			restart_msg.get_content_area().add(new Label(_("Some settings will be applied after application restart")));
			restart_msg.message_type = MessageType.WARNING;
			restart_msg.margin_bottom = 8;
			update_restart_message();

			tabs = new Stack();
			tabs.homogeneous = false;
			tabs.interpolate_size = true;
			tabs.margin_start = tabs.margin_end = 8;

			var tabs_switcher = new StackSwitcher();
			tabs_switcher.stack = tabs;
			tabs_switcher.halign = Align.CENTER;
			tabs_switcher.margin_bottom = 8;

			add_tab("ui", new Tabs.UI(this), _("Interface"));
			add_tab("gs/steam", new Tabs.Steam(this), "Steam", "steam-symbolic");
			add_tab("gs/gog", new Tabs.GOG(this), "GOG", "gog-symbolic");
			add_tab("gs/humble", new Tabs.Humble(this), "Humble Bundle", "humble-symbolic");
			add_tab("collection", new Tabs.Collection(this), _("Collection"));

			content.pack_start(restart_msg, false, false, 0);
			content.pack_start(tabs_switcher, false, false, 0);
			content.pack_start(tabs, false, false, 0);

			response.connect((source, response_id) => {
				switch(response_id)
				{
					case ResponseType.CLOSE:
						destroy();
						break;
				}
			});

			add_button(_("Close"), ResponseType.CLOSE).margin_end = 7;
			show_all();

			tabs.visible_child_name = tab;
		}

		private void add_tab(string id, SettingsDialogTab tab, string title, string? icon=null)
		{
			tabs.add_titled(tab, id, title);
			tabs.child_set_property(tab, "icon-name", icon);
		}

		public void show_restart_message()
		{
			restart_msg_shown = true;
			update_restart_message();
		}

		private void update_restart_message()
		{
			#if GTK_3_22
			restart_msg.revealed = restart_msg_shown;
			#else
			restart_msg.visible = restart_msg_shown;
			#endif
		}
	}
}

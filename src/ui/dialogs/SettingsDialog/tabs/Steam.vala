using Gtk;
using Granite;
using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Tabs
{
	public class Steam: SettingsDialogTab
	{
		public Steam(SettingsDialog dlg)
		{
			Object(orientation: Orientation.VERTICAL, dialog: dlg);
		}

		construct
		{
			var paths = FSUtils.Paths.Settings.get_instance();

			var steam_auth = Settings.Auth.Steam.get_instance();

			add_switch(_("Enabled"), steam_auth.enabled, v => { steam_auth.enabled = v; dialog.show_restart_message(); });

			add_separator();

			add_steam_apikey_entry();
			add_labeled_link(_("Steam API keys have limited number of uses per day"), _("Generate key"), "steam://openurl/https://steamcommunity.com/dev/apikey");

			add_separator();

			add_file_chooser(_("Installation directory"), FileChooserAction.SELECT_FOLDER, paths.steam_home, v => { paths.steam_home = v; dialog.show_restart_message(); }, false);
		}

		protected void add_steam_apikey_entry()
		{
			var steam_auth = Settings.Auth.Steam.get_instance();

			var entry = new Entry();
			entry.placeholder_text = _("Default");
			entry.max_length = 32;
			if(steam_auth.api_key != steam_auth.schema.get_default_value("api-key").get_string())
			{
				entry.text = steam_auth.api_key;
			}
			entry.primary_icon_name = "steam-symbolic";
			entry.secondary_icon_name = "edit-delete-symbolic";
			entry.secondary_icon_tooltip_text = _("Restore default API key");
			entry.set_size_request(280, -1);

			entry.notify["text"].connect(() => { steam_auth.api_key = entry.text; dialog.show_restart_message(); });
			entry.icon_press.connect((pos, e) => {
				if(pos == EntryIconPosition.SECONDARY)
				{
					entry.text = "";
				}
			});

			var label = new Label(_("Steam API key"));
			label.halign = Align.START;
			label.hexpand = true;

			var hbox = new Box(Orientation.HORIZONTAL, 12);
			hbox.add(label);
			hbox.add(entry);
			add_widget(hbox);
		}
	}
}
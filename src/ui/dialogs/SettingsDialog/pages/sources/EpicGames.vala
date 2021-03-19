using Gtk;
using GameHub.UI.Widgets;
using GameHub.UI.Widgets.Settings;

using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.Sources
{
	public class EpicGames: SettingsDialogPage
	{
		private Settings.Auth.EpicGames epicgames_auth = Settings.Auth.EpicGames.instance;
		private Settings.Paths.EpicGames epicgames_paths = Settings.Paths.EpicGames.instance;

		private Widgets.Settings.BaseSetting? account_setting;
		private Button? logout_btn;
		private Gtk.LinkButton? account_link;

		public EpicGames(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				title: "EpicGames",
				description: _("Disabled"),
				icon_name: "source-epicgames-symbolic",
				has_active_switch: true
			);
		}

		construct
		{
			var epicgames = GameHub.Data.Sources.EpicGames.EpicGames.instance;

			epicgames_auth.bind_property("enabled", this, "active", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

			if(Parser.parse_json(epicgames_auth.userdata).get_node_type() != Json.NodeType.NULL)
			{
				var sgrp_account = new SettingsGroup();

				var account_actions_box = new Box(Orientation.HORIZONTAL, 12);
				logout_btn = new Button.from_icon_name("system-log-out-symbolic", IconSize.BUTTON);
				logout_btn.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
				logout_btn.tooltip_text = _("Logout");
				logout_btn.clicked.connect(
					() => {
					epicgames.logout.begin(() => update());
					request_restart();  //  TODO: Requires restart until we're able to reload games from an source
				});
				account_link = new LinkButton.with_label("https://epicgames.com/account/personal", _("View account"));
				account_actions_box.add(logout_btn);
				account_actions_box.add(account_link);

				account_setting = sgrp_account.add_setting(
					new BaseSetting(
						epicgames.user_name != null ? _("Authenticated as <b>%s</b>").printf(epicgames.user_name) : _("Authenticated"),
						_("Legendary"),
						account_actions_box
				));
				account_setting.icon_name = "avatar-default-symbolic";
				account_setting.activatable = true;
				account_setting.setting_activated.connect(() => epicgames.authenticate.begin(() => update()));
				account_link.can_focus = false;
				add_widget(sgrp_account);
			}

			var sgrp_game_dirs = new SettingsGroupBox(_("Game directories"));
			var game_dirs_list = sgrp_game_dirs.add_widget(new DirectoriesList.with_array(epicgames_paths.game_directories, epicgames_paths.default_game_directory, null, false));
			add_widget(sgrp_game_dirs);

			game_dirs_list.notify["directories"].connect(
				() => {
				epicgames_paths.game_directories = game_dirs_list.directories_array;
			});

			game_dirs_list.directory_selected.connect(
				dir => {
				epicgames_paths.default_game_directory = dir;
			});

			notify["active"].connect(
				() => {
				//  request_restart ();
				update();
			});

			update();
		}

		private void update()
		{
			if(logout_btn != null)
			{
				logout_btn.sensitive = epicgames_auth.authenticated;
			}

			//  if(account_link != null)
			//  {
			//  	account_link.sensitive = epicgames_auth.authenticated && epicgames.user_id.length > 0;
			//  }

			var epicgames = GameHub.Data.Sources.EpicGames.EpicGames.instance;

			if(!epicgames.enabled)
			{
				if(account_setting != null)
				{
					account_setting.title = _("Disabled");
				}
				description = _("Disabled");
			}
			else if(!epicgames.is_installed(true))
			{
				if(account_setting != null)
				{
					account_setting.title = _("Not installed");
				}
				description = _("Not installed");
			}
			else if(!epicgames.is_authenticated())
			{
				if(account_setting != null)
				{
					account_setting.title = _("Not authenticated");
				}
				description = _("Not authenticated");
			}
			else
			{
				if(this.account_setting != null)
				{
					account_setting.title = _("Authenticated as <b>%s</b>").printf(epicgames.user_name);
				}
				else
				{
					_("Authenticated");
				}
				description = _("Authenticated");
			}
		}
	}
}

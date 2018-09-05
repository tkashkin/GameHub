using Gtk;
using Gdk;
using Granite;
using GLib;
using Gee;
using GameHub.Utils;
using GameHub.UI.Widgets;

using GameHub.Data;
using GameHub.Data.Sources.Steam;

namespace GameHub.UI.Dialogs
{
	public class ProtonRunDialog: Dialog
	{
		public Game game { get; construct; }

		private Box content;
		private Label title_label;
		private ListBox vars_list;

		private Gtk.ListStore compat_tools_model;
		private ComboBox compat_tools_combo;

		public ProtonRunDialog(Game game)
		{
			Object(game: game, transient_for: Windows.MainWindow.instance, deletable: false, resizable: false, title: _("Run with Proton"));

			modal = true;

			content = new Box(Orientation.VERTICAL, 0);
			content.margin_start = content.margin_end = 8;

			var title_hbox = new Box(Orientation.HORIZONTAL, 16);

			var icon = new AutoSizeImage();
			icon.set_constraint(48, 48, 1);
			icon.set_size_request(48, 48);

			title_label = new Label(game.name);
			title_label.halign = Align.START;
			title_label.hexpand = true;
			title_label.get_style_context().add_class(Granite.STYLE_CLASS_H2_LABEL);

			title_hbox.add(icon);
			title_hbox.add(title_label);

			content.add(title_hbox);

			var tool_box = new Box(Orientation.HORIZONTAL, 8);
			tool_box.margin_start = 64;

			var tool_label = new HeaderLabel(_("Compatibility tool:"));
			tool_label.halign = Align.START;

			tool_box.add(tool_label);

			compat_tools_model = new Gtk.ListStore(1, typeof(string));
			Gtk.TreeIter iter;

			foreach(var appid in Sources.Steam.Steam.PROTON_APPIDS)
			{
				File? proton_dir = null;
				if(Sources.Steam.Steam.find_app_install_dir(appid, out proton_dir))
				{
					if(proton_dir != null)
					{
						compat_tools_model.append(out iter);
						compat_tools_model.set(iter, 0, proton_dir.get_basename());
					}
				}
			}

			compat_tools_model.append(out iter);
			compat_tools_model.set(iter, 0, "wine");

			compat_tools_combo = new ComboBox.with_model(compat_tools_model);
			compat_tools_combo.hexpand = true;
			compat_tools_combo.active = 0;

			CellRendererText renderer = new CellRendererText();
			compat_tools_combo.pack_start(renderer, true);
			compat_tools_combo.add_attribute(renderer, "text", 0);

			tool_box.add(compat_tools_combo);

			content.add(tool_box);

			var vars_header = new HeaderLabel(_("Environment variables"));
			vars_header.margin_start = 64;
			content.add(vars_header);

			vars_list = new ListBox();
			vars_list.margin_start = 56;
			vars_list.get_style_context().add_class("tags-list");
			vars_list.selection_mode = SelectionMode.NONE;

			vars_list.add(new EnvVarRow("PROTON_NO_ESYNC", "1", false));
			vars_list.add(new EnvVarRow("PROTON_NO_D3D11", "1", false));
			vars_list.add(new EnvVarRow("PROTON_USE_WINED3D11", "1", false));
			vars_list.add(new EnvVarRow("DXVK_HUD", "1", true));

			content.add(vars_list);

			Utils.load_image.begin(icon, game.icon, "icon");

			response.connect((source, response_id) => {
				switch(response_id)
				{
					case ResponseType.CANCEL:
						destroy();
						break;

					case ResponseType.ACCEPT:
						run_with_proton.begin();
						//destroy();
						break;
				}
			});

			add_button(_("Cancel"), ResponseType.CANCEL);

			var run_btn = add_button(_("Run"), ResponseType.ACCEPT);
			run_btn.get_style_context().add_class(STYLE_CLASS_SUGGESTED_ACTION);
			run_btn.grab_default();

			get_content_area().add(content);
			get_content_area().set_size_request(340, 96);
			show_all();
		}

		private async void run_with_proton()
		{
			var binary = "wine";
			string[] cmd = { binary, game.executable.get_path() };

			TreeIter iter;
			Value tool_value;

			compat_tools_combo.get_active_iter(out iter);
			compat_tools_model.get_value(iter, 0, out tool_value);

			var tool = (string) tool_value;

			if(tool != "wine")
			{
				foreach(var appid in Sources.Steam.Steam.PROTON_APPIDS)
				{
					File? proton_dir = null;
					if(Sources.Steam.Steam.find_app_install_dir(appid, out proton_dir))
					{
						if(proton_dir != null && proton_dir.get_basename() == tool)
						{
							var proton = FSUtils.file(proton_dir.get_path(), "proton");
							if(proton != null && proton.query_exists())
							{
								binary = proton.get_path();
								cmd = { binary, "run", game.executable.get_path() };
								break;
							}
						}
					}
				}
			}

			var compatdata = FSUtils.mkdir(FSUtils.Paths.Cache.ProtonCompatData, @"$(game.source.id)/$(game.escaped_name)");
			if(compatdata != null && compatdata.query_exists())
			{
				var env = Environ.get();
				env = Environ.set_variable(env, "STEAM_COMPAT_CLIENT_INSTALL_PATH", FSUtils.Paths.Steam.Home);
				env = Environ.set_variable(env, "STEAM_COMPAT_DATA_PATH", compatdata.get_path());
				env = Environ.set_variable(env, "PROTON_LOG", "1");
				env = Environ.set_variable(env, "PROTON_DUMP_DEBUG_COMMANDS", "1");

				vars_list.foreach(r => {
					var row = r as EnvVarRow;
					if(row.active)
					{
						env = Environ.set_variable(env, row.var_name, row.var_value);
					}
				});

				yield Utils.run_thread(cmd, game.install_dir.get_path(), env);
			}
		}

		private class EnvVarRow: ListBoxRow
		{
			public string var_name { get; construct; }
			public string var_value { get; construct; }
			public bool active { get; construct set; }

			public EnvVarRow(string name, string value, bool active)
			{
				Object(var_name: name, var_value: value, active: active);
			}

			construct
			{
				var ebox = new EventBox();
				ebox.above_child = true;

				var box = new Box(Orientation.HORIZONTAL, 8);
				box.margin_start = box.margin_end = 8;
				box.margin_top = box.margin_bottom = 6;

				var check = new CheckButton();
				check.active = active;

				var name = new Label(var_value == "1" ? var_name : @"$(var_name)=$(var_value)");
				name.halign = Align.START;
				name.xalign = 0;
				name.hexpand = true;

				box.add(check);
				box.add(name);

				ebox.add_events(EventMask.ALL_EVENTS_MASK);
				ebox.button_release_event.connect(e => {
					if(e.button == 1)
					{
						check.active = !check.active;
						active = check.active;
					}
					return true;
				});

				ebox.add(box);

				child = ebox;
			}
		}
	}
}

using Gtk;
using Gee;
using GameHub.Utils;

namespace GameHub.Data.Sources.Humble
{
	public class HumbleGame: Game
	{
		private string order_id;

		private bool game_info_updated = false;

		public ArrayList<Game.Installer>? installers { get; protected set; default = new ArrayList<Game.Installer>(); }

		public HumbleGame(Humble src, string order, Json.Node json_node)
		{
			source = src;

			var json_obj = json_node.get_object();

			id = json_obj.get_string_member("machine_name");
			name = json_obj.get_string_member("human_name");
			image = json_obj.get_string_member("icon");
			icon = image;
			order_id = order;

			info = Json.to_string(json_node, false);

			platforms.clear();
			foreach(var dl in json_obj.get_array_member("downloads").get_elements())
			{
				var pl = dl.get_object().get_string_member("platform");
				foreach(var p in Platforms)
				{
					if(pl == p.id())
					{
						platforms.add(p);
					}
				}
			}

			install_dir = FSUtils.file(FSUtils.Paths.Humble.Games, installation_dir_name);
			executable = FSUtils.file(install_dir.get_path(), "start.sh");
			info_detailed = @"{\"order\":\"$(order_id)\",\"executable\":\"$(executable.get_path())\"}";
			update_status();
		}

		public HumbleGame.from_db(Humble src, Sqlite.Statement s)
		{
			source = src;
			id = GamesDB.Tables.Games.ID.get(s);
			name = GamesDB.Tables.Games.NAME.get(s);
			icon = GamesDB.Tables.Games.ICON.get(s);
			image = GamesDB.Tables.Games.IMAGE.get(s);
			install_dir = FSUtils.file(GamesDB.Tables.Games.INSTALL_PATH.get(s)) ?? FSUtils.file(FSUtils.Paths.GOG.Games, installation_dir_name);
			info = GamesDB.Tables.Games.INFO.get(s);
			info_detailed = GamesDB.Tables.Games.INFO_DETAILED.get(s);

			platforms.clear();
			var pls = GamesDB.Tables.Games.PLATFORMS.get(s).split(",");
			foreach(var pl in pls)
			{
				foreach(var p in Platforms)
				{
					if(pl == p.id())
					{
						platforms.add(p);
						break;
					}
				}
			}

			tags.clear();
			var tag_ids = (GamesDB.Tables.Games.TAGS.get(s) ?? "").split(",");
			foreach(var tid in tag_ids)
			{
				foreach(var t in GamesDB.Tables.Tags.TAGS)
				{
					if(tid == t.id)
					{
						if(!tags.contains(t)) tags.add(t);
						break;
					}
				}
			}

			executable = FSUtils.file(install_dir.get_path(), "start.sh");
			status = new Game.Status(executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);

			var json = Parser.parse_json(info_detailed).get_object();
			order_id = json.get_string_member("order");
			install_dir = FSUtils.file(FSUtils.Paths.Humble.Games, installation_dir_name);
			executable = FSUtils.file(json.get_string_member("executable"));
			update_status();
		}

		public bool update_status()
		{
			if(status.state != Game.State.DOWNLOADING)
			{
				status = new Game.Status(executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);
			}
			return executable.query_exists();
		}

		public override async void update_game_info()
		{
			update_status();

			if(game_info_updated) return;

			if(info == null || info.length == 0)
			{
				var token = ((Humble) source).user_token;

				var headers = new HashMap<string, string>();
				headers["Cookie"] = @"$(Humble.AUTH_COOKIE)=\"$(token)\";";

				var root_node = yield Parser.parse_remote_json_file_async(@"https://www.humblebundle.com/api/v1/order/$(order_id)?ajax=true", "GET", null, headers);
				if(root_node == null || root_node.get_node_type() != Json.NodeType.OBJECT) return;
				var root = root_node.get_object();
				if(root == null) return;
				var products = root.get_array_member("subproducts");
				if(products == null) return;
				foreach(var product_node in products.get_elements())
				{
					if(product_node.get_object().get_string_member("machine_name") != id) continue;
					info = Json.to_string(product_node, false);
					break;
				}
			}

			if(installers.size > 0) return;

			var product = Parser.parse_json(info).get_object();
			if(product == null) return;

			foreach(var dl_node in product.get_array_member("downloads").get_elements())
			{
				var dl = dl_node.get_object();
				var id = dl.get_string_member("machine_name");
				var os = dl.get_string_member("platform");
				var platform = CurrentPlatform;
				foreach(var p in Platforms)
				{
					if(os == p.id())
					{
						platform = p;
						break;
					}
				}

				foreach(var dls_node in dl.get_array_member("download_struct").get_elements())
				{
					var installer = new Installer(id, platform, dls_node.get_object());
					installers.add(installer);
				}
			}

			game_info_updated = true;
		}

		public override async void install()
		{
			yield update_game_info();

			if(installers.size < 1) return;

			var wnd = new GameHub.UI.Dialogs.GameInstallDialog(this, installers);

			wnd.cancelled.connect(() => Idle.add(install.callback));

			wnd.install.connect(installer => {
				FSUtils.mkdir(FSUtils.Paths.Humble.Games);
				FSUtils.mkdir(installer.parts.get(0).local.get_parent().get_path());

				installer.install.begin(this, (obj, res) => {
					installer.install.end(res);
					choose_executable();
					update_status();
					Idle.add(install.callback);
				});
			});

			wnd.import.connect(() => {
				choose_executable();
				Idle.add(install.callback);
			});

			wnd.show_all();
			wnd.present();

			yield;
		}

		private void choose_executable()
		{
			var chooser = new FileChooserDialog(_("Select main executable of the game"), GameHub.UI.Windows.MainWindow.instance, FileChooserAction.OPEN);
			var filter = new FileFilter();
			filter.add_mime_type("application/x-executable");
			filter.add_mime_type("application/x-elf");
			filter.add_mime_type("application/x-sh");
			filter.add_mime_type("text/x-shellscript");
			chooser.set_filter(filter);

			try
			{
				chooser.select_file(executable);
			}
			catch(Error e)
			{
				warning(e.message);
			}

			chooser.add_button(_("Cancel"), ResponseType.CANCEL);
			var select_btn = chooser.add_button(_("Select"), ResponseType.ACCEPT);

			select_btn.get_style_context().add_class(STYLE_CLASS_SUGGESTED_ACTION);
			select_btn.grab_default();

			if(chooser.run() == ResponseType.ACCEPT)
			{
				executable = chooser.get_file();
				info_detailed = @"{\"order\":\"$(order_id)\",\"executable\":\"$(executable.get_path())\"}";
				update_status();
				if(executable.query_exists())
				{
					Utils.run({"chmod", "+x", executable.get_path()});
				}
				GamesDB.get_instance().add_game(this);
			}

			chooser.destroy();
		}

		public override async void run()
		{
			if(executable.query_exists())
			{
				var path = executable.get_path();
				var dir = executable.get_parent().get_path();
				yield Utils.run_thread({path}, dir, true);
			}
		}

		public override async void uninstall()
		{
			if(executable.query_exists())
			{
				FSUtils.rm(install_dir.get_path(), "", "-rf");
				update_status();
			}
		}

		public class Installer: Game.Installer
		{
			public string dl_name;

			public override string name { get { return dl_name; } }

			public Installer(string machine_name, Platform platform, Json.Object download)
			{
				id = machine_name;
				this.platform = platform;
				dl_name = download.has_member("name") ? download.get_string_member("name") : "";
				var url_obj = download.has_member("url") ? download.get_object_member("url") : null;
				var url = url_obj != null && url_obj.has_member("web") ? url_obj.get_string_member("web") : "";
				full_size = download.has_member("file_size") ? download.get_int_member("file_size") : 0;
				var remote = File.new_for_uri(url);
				var installers_dir = FSUtils.Paths.Collection.Humble.expand_installers(name);
				var local = FSUtils.file(installers_dir, "humble_" + id);
				parts.add(new Game.Installer.Part(id, url, full_size, remote, local));
			}
		}
	}
}

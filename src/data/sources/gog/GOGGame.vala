using Gee;
using GameHub.Utils;

namespace GameHub.Data.Sources.GOG
{
	public class GOGGame: Game
	{
		public ArrayList<Game.Installer>? installers { get; protected set; default = new ArrayList<Game.Installer>(); }
		public ArrayList<BonusContent>? bonus_content { get; protected set; default = new ArrayList<BonusContent>(); }
		public ArrayList<DLC>? dlc { get; protected set; default = new ArrayList<DLC>(); }

		private bool game_info_updated = false;

		public GOGGame.default(){}

		public GOGGame(GOG src, Json.Node json_node)
		{
			source = src;

			var json_obj = json_node.get_object();

			id = json_obj.get_int_member("id").to_string();
			name = json_obj.get_string_member("title");
			image = "https:" + json_obj.get_string_member("image") + "_392.jpg";
			icon = image;

			info = Json.to_string(json_node, false);

			platforms.clear();
			if(json_obj.get_object_member("worksOn").get_boolean_member("Linux")) platforms.add(Platform.LINUX);
			if(json_obj.get_object_member("worksOn").get_boolean_member("Windows")) platforms.add(Platform.WINDOWS);
			if(json_obj.get_object_member("worksOn").get_boolean_member("Mac")) platforms.add(Platform.MACOS);

			install_dir = FSUtils.file(FSUtils.Paths.GOG.Games, installation_dir_name);
			executable = FSUtils.file(install_dir.get_path(), "start.sh");
			status = new Game.Status(executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);
		}

		public GOGGame.from_db(GOG src, Sqlite.Statement s)
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
		}

		public override async void update_game_info()
		{
			if(status.state != Game.State.DOWNLOADING)
			{
				status = new Game.Status(executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);
			}

			if(game_info_updated) return;

			if(info_detailed == null || info_detailed.length == 0)
			{
				var lang = Intl.setlocale(LocaleCategory.ALL, null).down().substring(0, 2);
				var url = @"https://api.gog.com/products/$(id)?expand=downloads,description,expanded_dlcs" + (lang != null && lang.length > 0 ? "&locale=" + lang : "");
				info_detailed = (yield Parser.load_remote_file_async(url, "GET", ((GOG) source).user_token));
			}

			var root = Parser.parse_json(info_detailed);

			var images = Parser.json_object(root, {"images"});
			var desc = Parser.json_object(root, {"description"});
			var links = Parser.json_object(root, {"links"});

			if(images != null)
			{
				icon = images.get_string_member("icon");
				if(icon != null) icon = "https:" + icon;
				else icon = image;
			}

			if(desc != null)
			{
				description = desc.get_string_member("full");
				var cool = desc.get_string_member("whats_cool_about_it");
				if(cool != null && cool.length > 0)
				{
					description += "<ul><li>" + cool.replace("\n", "</li><li>") + "</li></ul>";
				}
			}

			if(links != null)
			{
				store_page = links.get_string_member("product_card");
			}

			var downloads = Parser.json_object(root, {"downloads"});

			var installers_json = downloads == null || !downloads.has_member("installers") ? null : downloads.get_array_member("installers");
			if(installers_json != null && installers.size == 0)
			{
				foreach(var installer_json in installers_json.get_elements())
				{
					var installer = new Installer(installer_json.get_object());
					installers.add(installer);
				}
			}

			var bonuses_json = downloads == null || !downloads.has_member("bonus_content") ? null : downloads.get_array_member("bonus_content");
			if(bonuses_json != null && bonus_content.size == 0)
			{
				foreach(var bonus_json in bonuses_json.get_elements())
				{
					bonus_content.add(new BonusContent(this, bonus_json.get_object()));
				}
			}

			var dlcs_json = !root.get_object().has_member("expanded_dlcs") ? null : root.get_object().get_array_member("expanded_dlcs");
			if(dlcs_json != null && dlc.size == 0)
			{
				foreach(var dlc_json in dlcs_json.get_elements())
				{
					dlc.add(new GOGGame.DLC(this, dlc_json));
				}
			}

			root = Parser.parse_json(info);

			var tags_json = root == null || root.get_node_type() != Json.NodeType.OBJECT || !root.get_object().has_member("tags") ? null : root.get_object().get_array_member("tags");

			if(tags_json != null)
			{
				foreach(var tag_json in tags_json.get_elements())
				{
					var tid = source.id + ":" + tag_json.get_string();
					foreach(var t in GamesDB.Tables.Tags.TAGS)
					{
						if(tid == t.id)
						{
							if(!tags.contains(t)) tags.add(t);
							break;
						}
					}
				}
			}

			GamesDB.get_instance().add_game(this);

			if(status.state != Game.State.DOWNLOADING)
			{
				status = new Game.Status(executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);
			}

			game_info_updated = true;
		}

		public override async void install()
		{
			yield update_game_info();

			if(installers == null || installers.size < 1) return;

			var wnd = new GameHub.UI.Dialogs.GameInstallDialog(this, installers);

			wnd.cancelled.connect(() => Idle.add(install.callback));

			wnd.install.connect(installer => {
				var root_node = Parser.parse_remote_json_file(installer.file, "GET", ((GOG) source).user_token);
				if(root_node == null || root_node.get_node_type() != Json.NodeType.OBJECT)
				{
					Idle.add(install.callback);
					return;
				}

				var root = root_node.get_object();
				if(root == null || !root.has_member("downlink"))
				{
					Idle.add(install.callback);
					return;
				}

				var link = root.get_string_member("downlink");
				var remote = File.new_for_uri(link);

				string g = name;
				string? d = null;
				if(this is DLC)
				{
					g = (this as DLC).game.name;
					d = name;
				}

				var installers_dir = FSUtils.Paths.Collection.GOG.expand_installers(g, d);
				var local = FSUtils.file(installers_dir, "gog_" + id + "_" + installer.id);

				FSUtils.mkdir(FSUtils.Paths.GOG.Games);
				FSUtils.mkdir(installers_dir);

				installer.install.begin(this, remote, local, (obj, res) => {
					installer.install.end(res);
					Idle.add(install.callback);
				});
			});

			wnd.show_all();
			wnd.present();

			yield;
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
				string? uninstaller = null;
				try
				{
					FileInfo? finfo = null;
					var enumerator = yield install_dir.enumerate_children_async("standard::*", FileQueryInfoFlags.NONE);
					while((finfo = enumerator.next_file()) != null)
					{
						if(finfo.get_name().has_prefix("uninstall-"))
						{
							uninstaller = finfo.get_name();
							break;
						}
					}
				}
				catch(Error e){}

				if(uninstaller != null)
				{
					uninstaller = FSUtils.expand(install_dir.get_path(), uninstaller);
					debug("[GOGGame] Running uninstaller '%s'...", uninstaller);
					yield Utils.run_async({uninstaller, "--noprompt", "--force"}, null, true);
				}
				else
				{
					FSUtils.rm(install_dir.get_path(), "", "-rf");
				}
				status = new Game.Status(executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);
			}
		}

		public class Installer: Game.Installer
		{
			public string lang;
			public string lang_full;

			public override string name { get { return lang_full; } }

			public Installer(Json.Object json)
			{
				id = json.get_string_member("id");
				os = json.get_string_member("os");
				lang = json.get_string_member("language");
				lang_full = json.get_string_member("language_full");
				file = json.get_array_member("files").get_object_element(0).get_string_member("downlink");
				file_size = json.get_int_member("total_size");
			}
		}

		public class BonusContent
		{
			public GOGGame game;

			public string id;
			public string name;
			public string type;
			public int64 count;
			public string file;
			public int64 size;

			protected BonusContent.Status _status = new BonusContent.Status();
			public signal void status_change(BonusContent.Status status);

			public BonusContent.Status status
			{
				get { return _status; }
				set { _status = value; status_change(_status); }
			}

			public Downloader.DownloadInfo dl_info;

			public File? downloaded_file;

			public string text { owned get { return count > 1 ? @"$(count) $(name)" : name; } }

			public string icon
			{
				get
				{
					switch(type)
					{
						case "wallpapers":
						case "images":
						case "avatars":
						case "artworks":
							return "folder-pictures-symbolic";

						case "audio":
						case "soundtrack":
							return "folder-music-symbolic";

						case "video":
							return "folder-videos-symbolic";

						default: return "folder-documents-symbolic";
					}
				}
			}

			public BonusContent(GOGGame game, Json.Object json)
			{
				this.game = game;
				id = json.get_int_member("id").to_string();
				name = json.get_string_member("name");
				type = json.get_string_member("type");
				count = json.get_int_member("count");
				file = json.get_array_member("files").get_object_element(0).get_string_member("downlink");
				size = json.get_int_member("total_size");

				dl_info = new Downloader.DownloadInfo(game.name + ": " + text, game.icon, null, null, icon);
			}

			public async File? download()
			{
				var root_node = yield Parser.parse_remote_json_file_async(file, "GET", ((GOG) game.source).user_token);
				if(root_node == null || root_node.get_node_type() != Json.NodeType.OBJECT) return null;
				var root = root_node.get_object();
				if(root == null || !root.has_member("downlink")) return null;

				var link = root.get_string_member("downlink");
				var remote = File.new_for_uri(link);

				string g = game.name;
				string? d = null;
				if(game is DLC)
				{
					g = (this as DLC).game.name;
					d = game.name;
				}
				debug("G/D: %s / %s", g, d == null ? "null" : d);
				var bonus_dir = FSUtils.Paths.Collection.GOG.expand_bonus(g, d);

				var local = FSUtils.file(bonus_dir, "gog_" + game.id + "_bonus_" + id);

				FSUtils.mkdir(FSUtils.Paths.GOG.Games);
				FSUtils.mkdir(bonus_dir);

				status = new BonusContent.Status(BonusContent.State.DOWNLOADING, null);
				var ds_id = Downloader.get_instance().download_started.connect(dl => {
					if(dl.remote != remote) return;
					status = new BonusContent.Status(BonusContent.State.DOWNLOADING, dl);
					dl.status_change.connect(s => {
						status_change(status);
					});
				});

				var start_date = new DateTime.now_local();

				try
				{
					downloaded_file = yield Downloader.download(remote, local, dl_info);
				}
				catch(Error e){}

				Downloader.get_instance().disconnect(ds_id);

				status = new BonusContent.Status(downloaded_file != null && downloaded_file.query_exists() ? BonusContent.State.DOWNLOADED : BonusContent.State.NOT_DOWNLOADED);

				var elapsed = new DateTime.now_local().difference(start_date);

				if(elapsed <= 10 * TimeSpan.SECOND) open();

				return downloaded_file;
			}

			public void open()
			{
				if(downloaded_file != null && downloaded_file.query_exists())
				{
					Idle.add(() => {
						Utils.open_uri(downloaded_file.get_uri());
						return Source.REMOVE;
					});
				}
			}

			public class Status
			{
				public BonusContent.State state;

				public Downloader.Download? download;

				public Status(BonusContent.State state=BonusContent.State.NOT_DOWNLOADED, Downloader.Download? download=null)
				{
					this.state = state;
					this.download = download;
				}
			}

			public enum State
			{
				NOT_DOWNLOADED, DOWNLOADING, DOWNLOADED;
			}
		}

		public class DLC: GOGGame
		{
			public GOGGame game;

			public DLC(GOGGame game, Json.Node json_node)
			{
				base.default();
				this.game = game;
				source = game.source;

				var json_obj = json_node.get_object();

				id = json_obj.get_int_member("id").to_string();
				name = json_obj.get_string_member("title");
				image = game.image;
				icon = "https:" + json_obj.get_object_member("images").get_string_member("icon");

				info_detailed = Json.to_string(json_node, false);

				platforms.clear();

				is_installable = false;

				install_dir = game.install_dir;
				executable = game.executable;
				status = new Game.Status(Game.State.UNINSTALLED);
			}
		}
	}
}

using Gtk;
using Gee;
using GameHub.Utils;

namespace GameHub.Data.Sources.GOG
{
	public class GOGGame: Game
	{
		private bool _is_for_linux;
		private bool _product_info_updated = false;
		
		public File executable { get; private set; }
		
		private string installation_dir_name
		{
			owned get
			{
				return name.escape().replace(" ", "_").replace(":", "");
			}
		}
		
		public GOGGame(GOG src, Json.Object json)
		{
			source = src;
			id = json.get_int_member("id").to_string();
			name = json.get_string_member("title");
			image = "https:" + json.get_string_member("image") + "_392.jpg";
			icon = image;
			_is_for_linux = json.get_object_member("worksOn").get_boolean_member("Linux");
			
			if(!_is_for_linux)
			{
				GamesDB.get_instance().add_unsupported_game(source, id);
				return;
			}
			
			install_dir = FSUtils.file(FSUtils.Paths.GOG.Games, installation_dir_name);
			executable = FSUtils.file(install_dir.get_path(), "start.sh");
			status = new Game.Status(executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);
			is_installed();
		}
		
		public GOGGame.from_db(GOG src, Sqlite.Statement stmt)
		{
			source = src;
			id = stmt.column_text(1);
			name = stmt.column_text(2);
			icon = stmt.column_text(3);
			image = stmt.column_text(4);
			custom_info = stmt.column_text(5);
			_is_for_linux = true;
			install_dir = FSUtils.file(FSUtils.Paths.GOG.Games, installation_dir_name);
			executable = FSUtils.file(install_dir.get_path(), "start.sh");
			status = new Game.Status(executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);
			is_installed();
		}
		
		public override async bool is_for_linux()
		{
			return _is_for_linux;
		}
		
		public override bool is_installed()
		{
			if(status.state != Game.State.DOWNLOADING)
			{
				status = new Game.Status(executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);
			}
			return executable.query_exists();
		}
		
		public override async void update_game_info()
		{
			if(custom_info == null || custom_info.length == 0 || !_product_info_updated)
			{
				var url = @"https://api.gog.com/products/$(id)?expand=downloads,description";
				custom_info = (yield Parser.load_remote_file_async(url, "GET", ((GOG) source).user_token));
				_product_info_updated = true;
			}

			var root = Parser.parse_json(custom_info);

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

			GamesDB.get_instance().add_game(this);

			if(status.state != Game.State.DOWNLOADING)
			{
				status = new Game.Status(executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);
			}
		}

		public override async void install()
		{
			yield update_game_info();

			var root = Parser.parse_json(custom_info);

			var downloads = Parser.json_object(root, {"downloads"});

			if(downloads == null) return;
			
			var installers_json = downloads.get_array_member("installers");
			
			if(installers_json == null) return;

			var installers = new ArrayList<Game.Installer>();
			
			foreach(var installer_json in installers_json.get_elements())
			{
				var installer = new Installer(installer_json.get_object());
				if(installer.os == "linux") installers.add(installer);
			}
			
			var wnd = new GameHub.UI.Dialogs.GameInstallDialog(this, installers);
			
			wnd.cancelled.connect(() => Idle.add(install.callback));
			
			wnd.install.connect(installer => {
				root = Parser.parse_remote_json_file(installer.file, "GET", ((GOG) source).user_token);
				var link = root.get_object().get_string_member("downlink");
				var remote = File.new_for_uri(link);
				var local = FSUtils.file(FSUtils.Paths.GOG.Installers, "gog_" + id + "_" + installer.id + ".sh");
				
				FSUtils.mkdir(FSUtils.Paths.GOG.Games);
				FSUtils.mkdir(FSUtils.Paths.GOG.Installers);
				
				status = new Game.Status(Game.State.DOWNLOADING, null);
				var ds_id = Downloader.get_instance().download_started.connect(dl => {
					if(dl.remote != remote) return;
					status = new Game.Status(Game.State.DOWNLOADING, dl);
					dl.status_change.connect(s => {
						status_change(status);
					});
				});

				Downloader.download.begin(remote, local, (obj, res) => {
					try
					{
						var file = Downloader.download.end(res).get_path();

						Downloader.get_instance().disconnect(ds_id);

						Utils.run({"chmod", "+x", file});

						status = new Game.Status(Game.State.INSTALLING);
						string[] cmd = {file, "--", "--i-agree-to-all-licenses",
										"--noreadme", "--nooptions", "--noprompt",
										"--destination", install_dir.get_path()};
						Utils.run_async.begin(cmd, null, false, true, (obj, res) => {
							Utils.run_async.end(res);
							status = new Game.Status(executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);
							Idle.add(install.callback);
						});
					}
					catch(IOError.CANCELLED e){}
					catch(Error e)
					{
						warning(e.message);
					}
					status = new Game.Status(executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);
				});
			});
			
			wnd.show_all();
			wnd.present();
			
			yield;
		}
		
		public override async void run()
		{
			if(is_installed())
			{
				var path = executable.get_path();
				yield Utils.run_thread({path}, null, true);
			}
		}

		public override async void uninstall()
		{
			if(is_installed())
			{
				yield Utils.run_async({"sh", "-c", FSUtils.expand(install_dir.get_path(), "uninstall-*.sh")}, null, true);
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
	}
}

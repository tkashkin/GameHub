using Gtk;
using Gee;
using GameHub.Utils;

namespace GameHub.Data.Sources.Humble
{
	public class HumbleGame: Game
	{
		private bool _is_for_linux;
		
		private string order_id;
		public File executable { get; private set; }
		
		private string installation_dir_name
		{
			owned get
			{
				return name.escape().replace(" ", "_").replace(":", "");
			}
		}
		
		public HumbleGame(Humble src, string order, Json.Object json)
		{
			source = src;
			id = json.get_string_member("machine_name");
			name = json.get_string_member("human_name");
			image = json.get_string_member("icon");
			icon = image;
			order_id = order;
			
			_is_for_linux = false;
			
			foreach(var dl in json.get_array_member("downloads").get_elements())
			{
				if(dl.get_object().get_string_member("platform") == "linux")
				{
					_is_for_linux = true;
					break;
				}
			}
			
			if(!_is_for_linux)
			{
				GamesDB.get_instance().add_unsupported_game(source, id);
				return;
			}
			
			install_dir = FSUtils.file(FSUtils.Paths.Humble.Games, installation_dir_name);
			executable = FSUtils.file(install_dir.get_path(), "start.sh");
			status = new Game.Status(executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);
			is_installed();
			
			custom_info = @"{\"order\":\"$(order_id)\",\"executable\":\"$(executable.get_path())\"}";
		}
		
		public HumbleGame.from_db(Humble src, Sqlite.Statement stmt)
		{
			source = src;
			id = stmt.column_text(1);
			name = stmt.column_text(2);
			icon = stmt.column_text(3);
			image = stmt.column_text(4);
			custom_info = stmt.column_text(5);
			_is_for_linux = true;
			
			var custom_json = Parser.parse_json(custom_info).get_object();
			order_id = custom_json.get_string_member("order");
			install_dir = FSUtils.file(FSUtils.Paths.Humble.Games, installation_dir_name);
			executable = FSUtils.file(custom_json.get_string_member("executable"));
			status = new Game.Status(executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);
			is_installed();
		}
		
		public override async bool is_for_linux()
		{
			return _is_for_linux;
		}
		
		public override bool is_installed()
		{
			status = new Game.Status(executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);
			return executable.query_exists();
		}
		
		public override async void install(DownloadProgress progress = (d, t) => {})
		{
			var token = ((Humble) source).user_token;
			
			var headers = new HashMap<string, string>();
			headers["Cookie"] = @"$(Humble.AUTH_COOKIE)=\"$(token)\";";
			
			var root = (yield Parser.parse_remote_json_file_async(@"https://www.humblebundle.com/api/v1/order/$(order_id)?ajax=true", "GET", null, headers)).get_object();
			var products = root.get_array_member("subproducts");
			
			if(products == null) return;
			
			var installers = new ArrayList<Game.Installer>();
			
			foreach(var product_node in products.get_elements())
			{
				var product = product_node.get_object();
				if(product.get_string_member("machine_name") != id) continue;
				
				foreach(var dl_node in product.get_array_member("downloads").get_elements())
				{
					var dl = dl_node.get_object();
					var id = dl.get_string_member("machine_name");
					var os = dl.get_string_member("platform");
					if(os != "linux") continue;
					
					foreach(var dls_node in dl.get_array_member("download_struct").get_elements())
					{
						var installer = new Installer(id, os, dls_node.get_object());
						installers.add(installer);
					}
				}
			}
			
			if(installers.size < 1) return;
			
			var wnd = new GameHub.UI.Dialogs.GameInstallDialog(this, installers);
			
			wnd.canceled.connect(() => Idle.add(install.callback));
			
			wnd.install.connect(installer => {
				var link = installer.file;
				var local = FSUtils.expand(FSUtils.Paths.Humble.Installers, "humble_" + installer.id);
				
				FSUtils.mkdir(FSUtils.Paths.Humble.Games);
				FSUtils.mkdir(FSUtils.Paths.Humble.Installers);
				
				status = new Game.Status(Game.State.DOWNLOAD_STARTED);

				Downloader.get_instance().download.begin(File.new_for_uri(link), { local }, (d, t) => {
					progress(d, t);
					status = new Game.Status(Game.State.DOWNLOADING, d, t);
				}, null, (obj, res) => {
					try
					{
						var file = Downloader.get_instance().download.end(res);
						status = new Game.Status(Game.State.DOWNLOAD_STARTED);
						var path = file.get_path();
						FSUtils.mkdir(install_dir.get_path());
						Utils.run({"chmod", "+x", path});
						
						var info = file.query_info(FileAttribute.STANDARD_CONTENT_TYPE, FileQueryInfoFlags.NONE);
						var type = info.get_content_type();
						
						string[] cmd = {"xdg-open", path};	// unknown type, just open
						
						switch(type)
						{
							case "application/x-executable":
							case "application/x-elf":
							case "application/x-sh":
							case "application/x-shellscript":
								cmd = {path, "--", "--i-agree-to-all-licenses",
										"--noreadme", "--nooptions", "--noprompt",
										"--destination", install_dir.get_path()};	// probably mojosetup
								break;
							
							case "application/zip":
							case "application/x-tar":
							case "application/x-gtar":
							case "application/x-cpio":
							case "application/x-bzip2":
							case "application/gzip":
							case "application/x-lzip":
							case "application/x-lzma":
							case "application/x-7z-compressed":
							case "application/x-rar-compressed":
								cmd = {"file-roller", path, "-e", install_dir.get_path()}; // extract with file-roller
								break;
						}
						
						status = new Game.Status(Game.State.INSTALLING);

						Utils.run_async.begin(cmd, null, false, true, (obj, res) => {
							Utils.run_async.end(res);
							Utils.run({"chmod", "-R", "+x", install_dir.get_path()});

							try
							{
								string? dirname = null;
								FileInfo? finfo = null;
								var enumerator = install_dir.enumerate_children("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
								while((finfo = enumerator.next_file()) != null)
								{
									if(dirname == null)
									{
										dirname = finfo.get_name();
									}
									else
									{
										dirname = null;
									}
								}

								if(dirname != null)
								{
									Utils.run({"bash", "-c", "mv " + dirname + "/* " + dirname + "/.* ."}, install_dir.get_path());
									FSUtils.rm(install_dir.get_path(), dirname, "-rf");
								}
							}
							catch(Error e){}

							choose_executable();
							Idle.add(install.callback);
						});
					}
					catch(Error e)
					{
						warning(e.message);
					}
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
				custom_info = @"{\"order\":\"$(order_id)\",\"executable\":\"$(executable.get_path())\"}";
				status = new Game.Status(executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);
				GamesDB.get_instance().add_game(this);
			}

			chooser.destroy();
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
				FSUtils.rm(install_dir.get_path(), "", "-rf");
				status = new Game.Status(executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);
			}
		}
		
		public class Installer: Game.Installer
		{
			public string dl_name;
			
			public override string name { get { return dl_name; } }
			
			public Installer(string machine_name, string platform, Json.Object download)
			{
				id = machine_name;
				os = platform;
				dl_name = download.get_string_member("name");
				file = download.get_object_member("url").get_string_member("web");
				file_size = download.get_int_member("file_size");
			}
		}
	}
}

using Gee;

using GameHub.Data.DB;
using GameHub.Data.Runnables;
using GameHub.Data.Runnables.Tasks.Install;
using GameHub.Data.Tweaks;
using GameHub.Utils;

namespace GameHub.Data.Sources.EpicGames
{
	//  Each game gets combined through an Asset, Metadata and a Manifest.
	//  These three contain sub information for a game.
	public class EpicGame: Game,
		Traits.HasExecutableFile, Traits.SupportsCompatTools,
		Traits.Game.SupportsTweaks
	{
		// Traits.HasActions
		//  public override ArrayList<Traits.HasActions.Action>? actions { get; protected set; default = new ArrayList<Traits.HasActions.Action>(); }

		// Traits.HasExecutableFile
		public override string? executable_path { owned get; set; }
		public override string? work_dir_path   { owned get; set; }
		public override string? arguments       { owned get; set; }
		public override string? environment     { owned get; set; }

		// Traits.SupportsCompatTools
		public override string? compat_tool          { get; set; }
		public override string? compat_tool_settings { get; set; }

		// Traits.Game.SupportsTweaks
		public override TweakSet? tweaks { get; set; default = null; }

		private bool game_info_updating = false;
		private bool game_info_updated  = false;

		//  Legendary mapping
		internal string            app_name    { get { return id; } }
		internal string            app_title   { get { return name; } }
		internal string?           app_version { get { return version; } }
		internal ArrayList<string> base_urls //  base urls for download, only really used when cached manifest is current
		{
			owned get
			{
				var urls = new ArrayList<string>();
				return_val_if_fail(_metadata.get_node_type() == Json.NodeType.OBJECT, urls); // prevent loop
				return_val_if_fail(metadata.get_object().has_member("base_urls"), urls);

				metadata.get_object().get_array_member("base_urls").foreach_element((array, index, node) => {
					urls.add(node.get_string());
				});

				return urls;
			}
			set
			{
				var urls = new Json.Node(Json.NodeType.ARRAY);
				urls.set_array(new Json.Array());
				value.foreach(url => {
					urls.get_array().add_string_element(url);

					return true;
				});

				metadata.get_object().set_array_member("base_urls", urls.get_array());
				write(FS.Paths.EpicGames.Metadata,
				      get_metadata_filename(),
				      Json.to_string(metadata, true).data);
			}
		}
		internal Asset? asset_info { get; set; default = null; }

		private Json.Node  _metadata = new Json.Node(Json.NodeType.NULL);
		internal Json.Node metadata // FIXME: make a class for easier access?
		{
			owned get
			{
				if(_metadata.get_node_type() == Json.NodeType.NULL)
				{
					//  FIXME: this will never update this way
					//  var f = FS.file(FS.Paths.EpicGames.Metadata, get_metadata_filename());
					_metadata = Parser.parse_json_file(FS.Paths.EpicGames.Metadata, get_metadata_filename());

					if(_metadata.get_node_type() != Json.NodeType.NULL) return _metadata;

					update_metadata();

					if(_metadata.get_node_type() != Json.NodeType.NULL) return _metadata;

					//  create new empty metadata
					_metadata = new Json.Node(Json.NodeType.OBJECT);
					_metadata.set_object(new Json.Object());
				}

				return _metadata;
			}
			set
			{
				return_if_fail(value.get_node_type() == Json.NodeType.OBJECT);

				//  TODO: save and rejoin base_urls?
				_metadata = value;
				write(FS.Paths.EpicGames.Metadata,
				      get_metadata_filename(),
				      Json.to_string(_metadata, true).data);
			}
		}

		internal File? resume_file { get; default = null; }
		internal File? repair_file
		{
			owned get
			{
				return FS.file(Environment.get_tmp_dir(), id + ".repair");
			}
		}

		internal string latest_version { get { return asset_info.build_version; } }
		internal bool   has_updates
		{
			get
			{
				if(version == null) return false;

				return version != latest_version;
			}
		}

		internal bool   needs_verification       { get; set; default = false; }
		internal bool   needs_repair             { get; default = false; }
		internal bool   requires_ownership_token { get; default = false; }
		internal string launch_command
		{
			get
			{
				return manifest.meta.launch_command;
			}
		}
		internal bool can_run_offline
		{
			get
			{
				return_val_if_fail(metadata.get_object().has_member("customAttributes"), false);
				return_val_if_fail(metadata.get_object().get_member("customAttributes").get_node_type() != Json.NodeType.OBJECT, false);
				return_val_if_fail(metadata.get_object().get_object_member("customAttributes").has_member("CanRunOffline"), false);
				return_val_if_fail(metadata.get_object().get_object_member("customAttributes").get_member("CanRunOffline").get_node_type() != Json.NodeType.OBJECT, false);
				return_val_if_fail(metadata.get_object().get_object_member("customAttributes").get_object_member("CanRunOffline").has_member("value"), false);

				return metadata.get_object().get_object_member("customAttributes").get_object_member("CanRunOffline").get_string_member("value") == "true"; // why no boolean?!
			}
		}
		private int64  _install_size = 0;
		internal int64 install_size
		{
			get
			{
				if(_install_size == 0)
				{
					foreach(var element in manifest.file_manifest_list.elements)
					{
						_install_size += element.file_size;
					}
				}

				return _install_size;
			}
		}
		//  internal string egl_guid;
		//  internal Json.Node prereq_info;
		private           Manifest? _manifest = null;
		internal Manifest manifest
		{
			owned get
			{
				if(_manifest == null)
				{
					//  We need a version to load the proper manifest
					//  load_version() has already been called on game init
					if(version != null)
					{
						_manifest = EpicGames.load_manifest(load_manifest_from_disk());
					}
					else
					{
						Bytes data;
						get_cdn_manifest(out data);
						_manifest = EpicGames.load_manifest(data);
					}
				}

				return _manifest;
			}
			set
			{
				_manifest = value;
			}
		}

		public ArrayList<DLC>? dlc { get; protected set; default = null; }

		internal bool is_dlc
		{
			get
			{
				return_val_if_fail(metadata.get_node_type() == Json.NodeType.OBJECT, false);

				return metadata.get_object().has_member("mainGameItem");
			}
		}

		internal bool supports_cloud_saves
		{
			get
			{
				return metadata.get_object().has_member("customAttributes")
				       && metadata.get_object().get_object_member("customAttributes").has_member("CloudSaveFolder");
			}
		}

		public EpicGame(EpicGames source, Asset asset, Json.Node? metadata = null)
		{
			this.source = source;
			id          = asset.asset_id;

			//  this.version = asset.build_version; // Only gets permanently saved for installed games
			//  this.info = asset.to_string(false);
			if(metadata != null) this.metadata = metadata;

			_asset_info = asset;
			load_version();
			name = this.metadata.get_object().get_string_member_with_default("title", "");

			install_dir        = null;
			this.status        = new Game.Status(Game.State.UNINSTALLED, this);
			this.work_dir_path = "";

			update_game_info.begin();
			init_tweaks();
		}

		public EpicGame.from_db(EpicGames src, Sqlite.Statement s)
		{
			source = src;

			//  TODO: verify, add custom values
			dbinit(s);
			dbinit_executable(s);
			dbinit_compat(s);
			dbinit_tweaks(s);

			_asset_info = EpicGames.instance.get_game_asset(id);

			//  update_status();
			update_game_info.begin();
		}

		public override async void update_game_info()
		{
			if(game_info_updating) return;

			game_info_updating = true;

			var meta_object_node = metadata.get_object();

			if(meta_object_node.has_member("keyImages")
			   && meta_object_node.get_member("keyImages").get_node_type() == Json.NodeType.ARRAY)
			{
				meta_object_node.get_array_member("keyImages").foreach_element((array, index, node) =>
				{
					if(node.get_node_type() != Json.NodeType.OBJECT)
					{
						return;
					}

					if(!node.get_object().has_member("type")
					   || !node.get_object().has_member("url"))
					{
						return;
					}

					switch(node.get_object().get_string_member("type"))
					{
						case "DieselGameBox":
							image = node.get_object().get_string_member("url");
							break;
						case "DieselGameBoxTall":
							image_vertical = node.get_object().get_string_member("url");
							break;
						case "Thumbnail":
							icon = node.get_object().get_string_member("url");
							break;
					}
				});
			}

			platforms.clear();

			if(meta_object_node.has_member("releaseInfo")
			   && meta_object_node.get_member("releaseInfo").get_node_type() == Json.NodeType.ARRAY)
			{
				meta_object_node.get_array_member("releaseInfo").foreach_element((array, index, node) => {
					if(node.get_node_type() != Json.NodeType.OBJECT
					   || !node.get_object().has_member("appId")
					   || node.get_object().get_string_member("appId") != this.id
					   || !node.get_object().has_member("platform")
					   || node.get_object().get_member("platform").get_node_type() != Json.NodeType.ARRAY)
					{
						return;
					}

					node.get_object().get_array_member("platform").foreach_element((a, i, n) => {
						if(n.get_node_type() != Json.NodeType.VALUE)
						{
							return;
						}

						foreach(var platform in Platform.PLATFORMS)
						{
							//  Windows, Mac, Win32
							if(n.get_string().down() == platform.id())
							{
								platforms.add(platform);
							}
						}
					});
				});
			}

			if(image == null || image == "")
			{
				image = icon;
			}

			if(image_vertical == null || image_vertical == "")
			{
				image_vertical = icon;
			}

			if(game_info_updated)
			{
				game_info_updating = false;

				return;
			}

			var json = new Json.Node(Json.NodeType.NULL);

			//  This gets only saved for games which results into fetching for DLCs every time
			if(info_detailed == null || info_detailed.length == 0)
			{
				if(this is DLC)
				{
					//  //  FIXME: this will never update
					//  json = Parser.parse_json_file(FS.Paths.EpicGames.Metadata, id + ".dlc.json");

					//  if(json.get_node_type() == Json.NodeType.NULL)
					//  {
					//  	var j = EpicGamesServices.instance.get_dlc_details(asset_info.ns);
					//  	j.get_array().foreach_element((array, index, node) => {
					//  		//  FIXME: wrong id
					//  		if(node.get_object().get_string_member("id") == asset_info.asset_id)
					//  		{
					//  			json = node;
					//  		}
					//  	});
					//  }
				}
				else
				{
					json = EpicGamesServices.instance.get_store_details(asset_info.ns, asset_info.asset_id);
				}

				if(json.get_node_type() != Json.NodeType.NULL)
				{
					info_detailed = Json.to_string(json, false);
				}
			}

			json = Parser.parse_json(info_detailed);

			if(json != null && json.get_node_type() != Json.NodeType.NULL)
			{
				var slug  = json.get_object().get_string_member_with_default("_slug", "");
				var page  = json.get_object().get_array_member("pages").get_object_element(0);
				var about = page.get_object_member("data").get_object_member("about");
				//  var social = page.get_object_member("data").get_object_member("socialLinks");

				if(slug != "")
				{
					//  FIXME: Globify language and merge with …Services
					var language_code = Intl.setlocale(LocaleCategory.ALL, null).down().substring(0, 2);
					store_page = @"https://www.epicgames.com/store/$language_code/p/$slug";
				}

				if(about != null)
				{
					description = about.get_string_member_with_default("shortDescription", "");
					var long_description = about.get_string_member("description");

					if(long_description != null && long_description.length > 0)
					{
						if(description.length > 0) description += "<br><br>";

						long_description.replace("\n", "<br>");
						description += long_description;
					}
				}
			}

			save();
			update_status();

			game_info_updated  = true;
			game_info_updating = false;
		}

		//  TODO: verify and correct this
		public override void update_status()
		{
			if(status.state == Game.State.DOWNLOADING && status.download.status.state != Downloader.Download.State.CANCELLED) return;

			var state = Game.State.UNINSTALLED;

			//  var gameinfo = get_file("gameinfo");
			//  var goggame = get_file(@"goggame-$(id).info");
			var gh_marker = (this is DLC) ? get_file(@"$(FS.GAMEHUB_DIR)/$id.version") : get_file(@"$(FS.GAMEHUB_DIR)/version");

			var files = new ArrayList<File>();

			//  files.add(goggame);
			files.add(gh_marker);

			if(!(this is DLC))
			{
				files.add(executable);
				//  files.add(gameinfo);
			}

			foreach(var file in files)
			{
				if(file != null && file.query_exists())
				{
					state = Game.State.INSTALLED;
					break;
				}
			}

			status = new Game.Status(state, this);

			if(state == Game.State.INSTALLED)
			{
				remove_tag(Tables.Tags.BUILTIN_UNINSTALLED);
				add_tag(Tables.Tags.BUILTIN_INSTALLED);
			}
			else
			{
				add_tag(Tables.Tags.BUILTIN_UNINSTALLED);
				remove_tag(Tables.Tags.BUILTIN_INSTALLED);
			}

			load_version();

			//  actions.clear();
			//  var action = new RunnableAction(this);

			//  //  if(!action.is_hidden)
			//  //  {
			//  actions.add(action);
			//  //  }
		}

		public override async void run()
		{
			//  TODO: this never gets called?
		}

		public override async void pre_run()
		{
			if(is_dlc)
			{
				debug("[Source.EpicGame.pre_run] tried starting dlc");
				//  TODO: launch main game?
			}

			//  TODO: offline?
			assert(can_run_offline || yield EpicGames.instance.authenticate());

			//  TODO: check for updates
			if(latest_version != version)
			{
				debug("[Source.EpicGame.pre_run] game is out of date");
			}

			//  TODO: sync save files? E.g. Rocket League fails if no save was found
			//  the prefix has to exist already for this
		}

		public override ExecTask prepare_exec_task(string[]? cmdline_override = null,
		                                           string[]? args_override    = null)
		{
			string[] cmd      = cmdline_override ?? cmdline;
			string[] full_cmd = cmd;

			var variables = get_variables();
			var args      = args_override ?? Utils.parse_args(arguments);

			if(args != null)
			{
				if("$command" in args || "${command}" in args)
				{
					full_cmd = {};
				}

				foreach(var arg in args)
				{
					if(arg == "$command" || arg == "${command}")
					{
						foreach(var a in cmd)
						{
							full_cmd += a;
						}
					}
					else
					{
						if("$" in arg)
						{
							arg = FS.expand(arg, null, variables);
						}

						full_cmd += arg;
					}
				}
			}

			foreach(var arg in get_launch_parameters())
			{
				full_cmd += arg;
			}

			var task = Utils.exec(full_cmd).override_runtime(true).dir(work_dir.get_path());

			cast<Traits.Game.SupportsTweaks>(game => task.tweaks(game.tweaks, game));

			if(environment != null && environment.length > 0)
			{
				var env = Parser.json_object(Parser.parse_json(environment), {});

				if(env != null)
				{
					env.foreach_member((obj, name, node) => {
						task.env_var(name, node.get_string());
					});
				}
			}

			return task;
		}

		public override async void post_run()
		{
			//  TODO: sync save files?
		}

		//  public void update_info(Json.Node json)
		//  {
		//  	info = Json.to_string(json, false);
		//  }

		public override async void uninstall()
		{
			if(install_dir != null && install_dir.query_exists())
			{
				//  yield umount_overlays();

				FS.rm(install_dir.get_path(), "", "-rf");
				update_status();
			}

			if((install_dir == null || !install_dir.query_exists()) && (executable == null || !executable.query_exists()))
			{
				install_dir = null;
				executable  = null;
				save();
				update_status();
			}
		}

		public override async ArrayList<Tasks.Install.Installer>? load_installers()
		{
			if(installers != null && installers.size > 0) return installers;

			installers = new ArrayList<Tasks.Install.Installer>();

			foreach(var platform in platforms)
			{
				installers.add(new Installer(this, platform));
			}

			is_installable = installers.size > 0;

			return installers;
		}

		public void add_dlc(Asset asset, Json.Node? metadata = null)
		{
			if(dlc == null || dlc.size == 0)
			{
				dlc = new ArrayList<DLC>();
			}

			dlc.add(new DLC(this, asset, metadata));
		}

		public Json.Node to_json()
		{
			var json = new Json.Node(Json.NodeType.OBJECT);
			var urls = new Json.Node(Json.NodeType.ARRAY);
			base_urls.foreach(url => {
				urls.get_array().add_string_element(url);

				return true;
			});

			json.get_object().set_string_member("app_name", id);
			json.get_object().set_string_member("app_title", name);
			json.get_object().set_string_member("app_version", version);
			json.get_object().set_object_member("asset_info", asset_info.to_json().get_object());
			json.get_object().set_array_member("base_urls", urls.get_array());
			json.get_object().set_object_member("metadata", metadata.get_object());

			return json;
		}

		public async bool import(File import_dir, string egl_guid = "")
		{
			//  if(!yield authenticate()) return false;

			//  if(get_game(game, true) == null)
			//  {
			//  	debug("[Source.EpicGames.import] Did not find game \"%s\" on account.", game.name);
			//  	return false;
			//  }

			Manifest manifest;
			_needs_verification  = true;
			Bytes? manifest_data = null;

			//  check if the game is from an EGL installation, load manifest if possible
			var egstore_path = Path.build_filename(import_dir.get_path(), ".egstore");

			if(File.new_for_path(egstore_path).query_exists())
			{
				File? manifest_file = null;

				if(egl_guid != "")
				{
					try
					{
						var egstore_dir = Dir.open(egstore_path);
						string? file_name = null;

						while((file_name = egstore_dir.read_name()) != null)
						{
							if(!(".mancpn" in file_name))
							{
								continue;
							}

							debug("[Source.EpicGames.import_game] Checking mancpn file: %s",
							      file_name);
							var mancpn = Parser.parse_json_file(egstore_path, file_name);

							if(mancpn.get_node_type() == Json.NodeType.OBJECT
							   || mancpn.get_object().has_member("AppName"))
							{
								debug("[Source.EpicGames.import_game] Found EGL install metadata, verifying…");
								manifest_file = FS.file(egstore_path, file_name);
								break;
							}
						}
					}
					catch (Error e)
					{
						debug("[Source.EpicGames.import_game] No EGL data found: %s", e.message);
					}
				}
				else
				{
					manifest_file = File.new_build_filename(egstore_path, egl_guid + ".manifest");
				}

				if(manifest_file != null && manifest_file.query_exists())
				{
					try
					{
						manifest_data = manifest_file.load_bytes();
					}
					catch (Error e)
					{
						debug("[Source.EpicGames.import_game] Error reading manifest file: %s", e.message);
					}
				}
				else
				{
					debug("[Source.EpicGames.import_game] .egstore folder exists but manifest file is missing, continuing as regular import…");
				}

				//  If there's no in-progress installation assume the game doesn't need to be verified
				var bps_path     = Path.build_filename(egstore_path, "bps");
				var pending_path = Path.build_filename(egstore_path, "Pending");

				if(manifest_file != null && File.new_for_path(bps_path).query_exists())
				{
					_needs_verification = false;

					if(File.new_for_path(pending_path).query_exists())
					{
						try
						{
							Dir.open(pending_path);
							_needs_verification = true;
						}
						catch (Error e) {}
					}

					if(!needs_verification)
					{
						debug("[Source.EpicGames.import_game] No in-progress installation found, assuming complete…");
					}
				}
			}

			ArrayList<string> tmp_urls;

			if(manifest_data == null)
			{
				debug("[Source.EpicGames.import_game] Downloading latest manifest for: %s", id);
				get_cdn_manifest(out manifest_data, out tmp_urls);

				if(base_urls.is_empty)
				{
					base_urls = tmp_urls;
					//  save_metadata();
				}
			}
			else
			{
				//  base urls being empty isn't an issue, they'll be fetched when updating/repairing the game
				tmp_urls = base_urls;
			}

			manifest = EpicGames.load_manifest(manifest_data);
			save_manifest(manifest_data, manifest.meta.build_version);
			//  uint install_size = 0;
			//  manifest.file_manifest_list.elements.foreach(file_manifest => {
			//  	install_size += file_manifest.file_size;
			//  	return true;
			//  });

			//  TODO: do we care about these?
			//  var prereq = new Json.Node(Json.NodeType.OBJECT);
			//  prereq.set_object(new Json.Object());
			//  if(manifest.meta.prereq_ids != null)
			//  {
			//  	var prereq_ids = new Json.Node(Json.NodeType.ARRAY);
			//  	prereq_ids.set_array(new Json.Array());
			//  	manifest.meta.prereq_ids.foreach(id => {
			//  		prereq_ids.get_array().add_string_element(id);
			//  		return true;
			//  	});

			//  	prereq.get_object().set_member("ids", prereq_ids);
			//  	prereq.get_object().set_string_member("name", manifest.meta.prereq_name);
			//  	prereq.get_object().set_string_member("path", manifest.meta.prereq_path);
			//  	prereq.get_object().set_string_member("args", manifest.meta.prereq_args);
			//  }

			//  var metadata = Parser.parse_json(info_detailed).get_object();
			//  var offline = metadata.get_object_member("customAttributes").get_boolean_member_with_default("CanRunOffline", true);
			//  var ot = metadata.get_object_member("customAttributes").get_boolean_member_with_default("OwnershipToken", false);

			//  TODO: legendary strips all leading '/' here
			executable_path = FS.file(import_dir.get_path(), manifest.meta.launch_exe).get_path();

			//  check if most files at least exist or if user might have specified the wrong directory
			var total_files = manifest.file_manifest_list.elements.size;
			int found_files = 0;
			manifest.file_manifest_list.elements.foreach(file_manifest =>
			{
				var file = FS.file(import_dir.get_path(), file_manifest.filename);

				if(file.query_exists())
				{
					found_files++;
				}
				else
				{
					warning("[Source.EpicGames.import] File could not be found at: %s", file.get_path());
				}

				return true;
			});

			var exe = FS.file(executable_path);

			if(!exe.query_exists())
			{
				warning("[Source.EpicGames.import] Game executable could not be found at: %s", exe.get_path());

				//  executable_path = null;
				return false;
			}

			var ratio = found_files / total_files;

			if(ratio < 0.95)
			{
				warning(
					"[Source.EpicGames.import] Some files are missing from the game installation, install may not " +
					"match latest Epic Games Store version or might be corrupted.");
				_needs_verification = true;
			}
			else
			{
				GLib.info("[Source.EpicGames.import] Game install appears to be complete.");
			}

			if(needs_verification)
			{
				GLib.info("[Source.EpicGames.import] The game installation will have to be verified before it can be updated");
			}
			else
			{
				GLib.info(
					"[Source.EpicGames.import] Installation had Epic Games Launcher metadata for version %s ".printf(version) +
					"verification will not be required.");
			}

			GLib.info("[Source.EpicGames.import] Game has been imported: %s", id);

			return true;
		}

		internal async void verify()
		{
			var manifest_data = get_installed_manifest();         // FIXME: cdn_manifest?
			var manifest      = EpicGames.load_manifest(manifest_data);

			var files = manifest.file_manifest_list.elements;
			files.sort((a, b) => {
				return strcmp(a.filename, b.filename);
			});

			//  build list of hashes
			var file_list = new HashMap<string, Bytes>();
			files.foreach(file => {
				file_list.set(file.filename, file.sha_hash);

				return true;
			});

			debug(@"[Sources.EpicGames.verify_game] Verifying \"$(id)\" version \"$(latest_version)\"");
			var repair_file = new ArrayList<string>();
			var result      = yield validate_files(install_dir.get_path(), file_list);

			result.matching.foreach(match => {
				repair_file.add(match);

				return true;
			});

			result.failed.foreach(fail => {
				repair_file.add(fail);

				return true;
			});

			//  always write repair file
			try
			{
				var file          = FS.file(Environment.get_tmp_dir(), id + ".repair");
				var io_stream     = file.create_readwrite(FileCreateFlags.REPLACE_DESTINATION);
				var output_stream = new DataOutputStream(io_stream.output_stream);
				foreach(var match in repair_file)
				{
					output_stream.put_string(match + "\n");
				}

				io_stream.close();
				debug(@"[Sources.EpicGames.verify_game] written repair file to: $(file.get_path())");
			}
			catch (Error e) {}

			if(!result.missing.is_empty || !result.failed.is_empty)
			{
				debug(@"[Sources.EpicGames.verify_game] Verification failed, $(result.failed.size) corrupted, $(result.missing.size) missing");
				_needs_repair = true;
			}

			GLib.info("[Sources.EpicGames.verify_game] Verification finished successfully");
		}

		private string[] get_launch_parameters()
		{
			var game_token = "";

			if(EpicGames.instance.is_authenticated())
			{
				debug("[Sources.EpicGames.get_launch_parameters] getting auth token…");
				game_token = EpicGamesServices.instance.get_game_token().get_object().get_string_member("code");
			}

			string[] parameters = {};

			//  FIXME: gives me some random bytes, don't know why
			//  if(game.launch_parameters != "")
			//  {
			//  	parameters = game.launch_parameters.split(" ");
			//  }

			parameters += "-AUTH_LOGIN=unused";
			parameters += @"-AUTH_PASSWORD=$game_token";
			parameters += "-AUTH_TYPE=exchangecode";
			parameters += @"-epicapp=$(id)";
			parameters += "-epicenv=Prod";

			//  TODO: where do we set this?
			if(requires_ownership_token)
			{
				debug("[Sources.EpicGames.get_launch_parameters] getting ownership token…");
				var ownership_token = EpicGamesServices.instance.get_ownership_token(asset_info.ns,
				                                                                     asset_info.catalog_item_id);
				//  TODO: write to tmp path?
				write(FS.Paths.EpicGames.Cache, @"$(asset_info.ns)$(asset_info.catalog_item_id).ovt", ownership_token.get_data());
				//  FIXME: needs wine path format?
				parameters += "-epicovt=%s".printf(FS.file(FS.Paths.EpicGames.Cache, @"$(asset_info.ns)$(asset_info.catalog_item_id).ovt").get_path());
			}

			parameters += "-EpicPortal";
			parameters += @"-epicusername=$(EpicGames.instance.user_name)";
			parameters += @"-epicuserid=$(EpicGames.instance.user_id)";
			parameters += @"-epiclocale=$(EpicGames.instance.language_code)";

			return parameters;
		}

		public int64 get_installation_size(Platform platform)
		{
			if(platform != Platform.WINDOWS)
			{
				Bytes data;
				get_cdn_manifest(out data, null, uppercase_first_character(platform.id()));
				var manifest = EpicGames.load_manifest(data);

				int64 size = 0;
				foreach(var element in manifest.file_manifest_list.elements)
				{
					size += element.file_size;
				}

				return size;
			}

			return install_size;
		}

		//  Hack around inability to use out in async functions
		private class ValidationResult
		{
			public ArrayList<string> matching { get; set; default = new ArrayList<string>(); }
			public ArrayList<string> missing  { get; set; default = new ArrayList<string>(); }
			public ArrayList<string> failed   { get; set; default = new ArrayList<string>(); }
		}

		private static async ValidationResult validate_files(string                                path,
		                                                     HashMap<string, Bytes>                file_list,
		                                                     ChecksumType                          hash_type = ChecksumType.SHA1)
		requires(FS.file(path).query_exists())
		requires(file_list.size > 0)
		{
			var result = new ValidationResult();

			foreach(var entry in file_list)
			{
				var file_path = entry.key;
				var file_hash = entry.value;

				var full_path = FS.file(path, file_path);

				if(!full_path.query_exists())
				{
					result.missing.add(file_path);
					continue;
				}

				//  debug("[Sources.EpicGames.validate_game_files] " + full_path.get_path());
				var real_hash = yield compute_file_checksum(full_path, hash_type);

				if(real_hash != null && real_hash != bytes_to_hex(file_hash))
				{
					debug("failed hash check: %s, %s != %s", file_path, bytes_to_hex(file_hash), real_hash);
					result.failed.add(string.join(":", real_hash, file_path));
				}
				else if(real_hash != null)
				{
					result.matching.add(string.join(":", real_hash, file_path));
				}
				else
				{
					debug(@"[Sources.EpicGames.validate_game_files] Could not verify \"$file_path\"");
					result.missing.add(file_path);
				}
			}

			return result;
		}

		private void get_cdn_urls(out ArrayList<string>  manifest_urls,
		                          out ArrayList<string>? base_urls,
		                          string                 platform_override = "")
		{
			var platform            = platform_override == "" ? "Windows" : platform_override;
			var manifest_api_result = EpicGamesServices.instance.get_game_manifest(asset_info.ns,
			                                                                       asset_info.catalog_item_id,
			                                                                       id,
			                                                                       platform);

			//  never seen this outside the launcher itself, but if it happens: PANIC!
			assert(manifest_api_result.get_object().has_member("elements"));
			var elements_array = manifest_api_result.get_object().get_array_member("elements");
			assert(elements_array.get_length() <= 1);

			base_urls     = new ArrayList<string>();
			manifest_urls = new ArrayList<string>();
			var tmp1 = new ArrayList<string>();
			var tmp2 = new ArrayList<string>();
			elements_array.get_object_element(0).get_array_member("manifests").foreach_element((array, index, node) => {
				var uri      = node.get_object().get_string_member("uri");
				var base_url = uri.substring(0, uri.last_index_of("/"));

				if(!tmp1.contains(base_url))
				{
					tmp1.add(base_url);
				}

				if(node.get_object().has_member("queryParams"))
				{
					var parameters_array = node.get_object().get_array_member("queryParams");
					string parameter     = "";
					parameters_array.foreach_element((a, i, n) => {
						var name  = n.get_object().get_string_member("name");
						var value = n.get_object().get_string_member("value");

						if(i == 0)
						{
							parameter = name + "=" + value;
						}
						else
						{
							parameter = parameter + "&" + name + "=" + value;
						}
					});
					tmp2.add(uri + "?" + parameter);
				}
				else
				{
					tmp2.add(uri);
				}
			});

			//  Hack around inability of using references in lambdas
			base_urls.add_all(tmp1);
			manifest_urls.add_all(tmp2);
		}

		private void get_cdn_manifest(out Bytes              data,
		                              out ArrayList<string>? base_urls         = null,
		                              string                 platform_override = "")
		{
			ArrayList<string> manifest_urls;
			get_cdn_urls(out manifest_urls, out base_urls, platform_override);
			EpicGamesServices.instance.get_cdn_manifest(manifest_urls[0], out data);
		}

		private void save_manifest(Bytes bytes, string version = this.version)
		{
			var name = get_manifest_filename(version);
			write(FS.Paths.EpicGames.Manifests, name, bytes.get_data());
		}

		private Bytes get_installed_manifest() { return load_manifest_from_disk(); }

		internal Bytes? load_manifest_from_disk()
		{
			uint8[] data;
			try
			{
				debug("Loading cached manifest: %s", FS.file(FS.Paths.EpicGames.Manifests, get_manifest_filename()).get_path());
				FileUtils.get_data(FS.file(FS.Paths.EpicGames.Manifests, get_manifest_filename()).get_path(), out data);
			}
			catch (FileError e)
			{
				debug("error: %s", e.message);

				return null;
			}

			return new Bytes(data);
		}

		private string get_manifest_filename(string version = this.version)
		{
			//  TODO: Escape/Normalize filename
			return @"$(id)_$version.manifest";
		}

		private string get_metadata_filename()
		{
			//  TODO: Escape/Normalize filename
			return @"$id.json";
		}

		//  private Json.Node get_metadata()
		//  {
		//  	var json = Parser.parse_json_file(FS.Paths.EpicGames.Metadata, get_metadata_filename());
		//  	if(json.get_node_type() == Json.NodeType.NULL)
		//  	{
		//  		json = new Json.Node(Json.NodeType.OBJECT);
		//  		json.set_object(new Json.Object());
		//  	}
		//  	return json;
		//  }

		//  internal void save_metadata()
		//  {
		//  	//  TODO: Save base_urls in json
		//  	write(FS.Paths.EpicGames.Metadata, get_metadata_filename(), Json.to_string(metadata, true).data);
		//  }

		internal Analysis prepare_download(Runnables.Tasks.Install.InstallTask task)
		{
			ArrayList<string> tmp_urls;
			Bytes             new_bytes;
			Manifest? old_manifest = null;

			var tmp2_urls = base_urls;         //  copy list for manipulation
			var old_bytes = (version != null) ? get_installed_manifest() : null;

			if(old_bytes == null)
			{
				debug("[Sources.EpicGames.prepare_download] Could not load old manifest, patching will not work!");
			}
			else
			{
				old_manifest = EpicGames.load_manifest(old_bytes);
			}

			get_cdn_manifest(out new_bytes, out tmp_urls);

			tmp_urls.foreach(url => {
				if(!tmp2_urls.contains(url))
				{
					tmp2_urls.add(url);
				}

				return true;
			});

			base_urls = tmp2_urls;
			//  save_metadata(); //  save base urls to game metadata

			var new_manifest = EpicGames.load_manifest(new_bytes);
			save_manifest(new_bytes, new_manifest.meta.build_version);

			//  check if we should use a delta manifest or not
			Manifest delta_manifest;

			if(old_manifest != null && new_manifest != null)
			{
				Bytes delta_manifest_data = null;
				var   delta_available     = EpicGamesServices.instance.get_delta_manifest(
					base_urls[Random.int_range(0, base_urls.size - 1)],
					old_manifest.meta.build_id,
					new_manifest.meta.build_id,
					out delta_manifest_data);

				if(delta_available && delta_manifest_data != null)
				{
					delta_manifest = EpicGames.load_manifest(delta_manifest_data);
					debug("[Sources.EpicGames.prepare_download] Using optimized delta manifest to upgrade from build " +
					      @"$(old_manifest.meta.build_id) to $(new_manifest.meta.build_id)");
					new_manifest.combine_manifest(delta_manifest);
				}
				else
				{
					debug("[Sources.EpicGames.prepare_download] No Delta manifest received from CDN");
				}
			}

			var force_update = true;         //  hardcoded for now
			//  var install_path = task.install_dir;
			_resume_file = null;

			if(needs_repair)
			{
				//  use installed manifest for repairs instead of updating
				//  new_manifest = old_manifest;
				//  old_manifest = null;

				_resume_file = FS.file(Environment.get_tmp_dir(), id + ".repair");
				force_update = false;
			}
			else if(force_update)
			{
				_resume_file = FS.file(Environment.get_tmp_dir(), id + ".resume");
			}

			var base_url = base_urls[Random.int_range(0, base_urls.size - 1)];
			debug("[Sources.EpicGames.prepare_download] Using base_url: %s",
			      base_url);

			//  TODO: Download optimizations
			//  var process_opt = false;

			//  FIXME: Things get messy from here on because I had to unscramble Legendarys whole dowload manager

			//  DLM
			var download_task = new Analysis.from_analysis(task,
			                                               base_url,
			                                               new_manifest,
			                                               old_manifest,
			                                               resume_file);

			//  TODO: prereq
			//  var url = base_url + "/" + chunk.path;
			//  TODO:
			return download_task;
		}

		internal void update_metadata()
		{
			var tmp_urls = base_urls;         //  save temporarily from old metadata
			_metadata = EpicGamesServices.instance.get_game_info(asset_info.ns, asset_info.catalog_item_id);

			//  prevent loop by accessing metadata again in set_base_urls
			if(_metadata.get_node_type() == Json.NodeType.NULL)
			{
				_metadata = new Json.Node(Json.NodeType.OBJECT);
				_metadata.set_object(new Json.Object());
			}

			//  FIXME: Setting base_urls also saves
			base_urls = tmp_urls;         //  paste them back into new metadata
			write(FS.Paths.EpicGames.Metadata,
			      get_metadata_filename(),
			      Json.to_string(metadata, true).data);
		}

		public override async void install(InstallTask.Mode                                 install_mode = InstallTask.Mode.INTERACTIVE)
		{
			if(status.state == Game.State.INSTALLED)
			{
				//  Update existing files
				ArrayList<File>? dirs = new ArrayList<File>();
				dirs.add(install_dir);
				var task = new InstallTask(this, installers, dirs, InstallTask.Mode.AUTO_INSTALL, false);
				yield task.start();
			}
			else
			{
				//  Uninstalled, fresh install
				if(status.state != Game.State.UNINSTALLED || !is_installable) return;

				var task = new InstallTask(this, installers, source.game_dirs, install_mode, true);
				yield task.start();
			}
		}

		//  private ArrayList<SaveGameFile> get_save_games()
		//  {
		//  	var savegames = EpicGamesServices.instance.get_user_cloud_saves(id, id != "" ? true : false);
		//  	var saves = new ArrayList<SaveGameFile>();

		//  	debug("json dump: \n%s", Json.to_string(savegames, true));

		//  	savegames.get_object().get_object_member("files").foreach_member(
		//  		(object, name, node) => {
		//  		var filename = node.get_object().get_string_member("fname");
		//  		var file = node.get_object().get_object_member("f");

		//  		if(!filename.contains(".manifest"))
		//  		{
		//  			continue;
		//  		}

		//  		var file_parts = filename.split("/");
		//  		saves.add(new SaveGameFile(file_parts[2], filename, file_parts[4], new DateTime.from_iso8601(file.get_object().get_string_member("lastModified")[: -1])));
		//  	});

		//  	return saves;
		//  }

		//  //  FIXME: requires prefix present!
		//  private async string? get_cloud_save_path()
		//  {
		//  	return_val_if_fail(metadata.get_object().has_member("customAttributes"), null);
		//  	return_val_if_fail(metadata.get_object().get_member("customAttributes").get_node_type() != Json.NodeType.OBJECT, null);
		//  	return_val_if_fail(metadata.get_object().get_object_member("customAttributes").has_member("CloudSaveFolder"), null);
		//  	return_val_if_fail(metadata.get_object().get_object_member("customAttributes").get_member("CloudSaveFolder").get_node_type() != Json.NodeType.OBJECT, null);
		//  	return_val_if_fail(metadata.get_object().get_object_member("customAttributes").get_object_member("CloudSaveFolder").has_member("value"), null);
		//  	var save_path = metadata.get_object().get_object_member("customAttributes").get_object_member("CloudSaveFolder").get_string_member("value");
		//  	save_path.replace("{", "${"); // prepare for FS.expand

		//  	var path_vars = new HashMap<string, string>();
		//  	path_vars.set("{installdir}", install_dir.get_path());
		//  	path_vars.set("{epicid}", EpicGames.instance.user_id);
		//  	path_vars.set("{appdata}", yield convert_path_to_unix(this, yield query_registry(this, "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Shell Folders", "AppData")));
		//  	path_vars.set("{userdir}", yield convert_path_to_unix(this, yield query_registry(this, "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Shell Folders", "Personal")));
		//  	path_vars.set("{usersavedgames}", yield convert_path_to_unix(this, yield query_registry(this, "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Shell Folders", "{4C5C32FF-BB9D-43B0-B5B4-2D72E54EAAA4}")));

		//  	//  not needed
		//  	//  save_path = save_path.replace("\\", "/");

		//  	return FS.expand(save_path, null, path_vars);
		//  }

		//  //  FIXME: where to put this?
		//  private virtual async string convert_path_to_unix(Traits.SupportsCompatTools runnable, string path)
		//  {
		//  	var task = Utils.exec({executable.get_path(), "winepath", "-u", path}).log(false);
		//  	apply_env(runnable, task, null);
		//  	var unix_path = (yield task.sync_thread(true)).output.strip();
		//  	debug("[Wine.convert_path_to_unix] '%s' -> '%s'", path, unix_path);
		//  	return unix_path;
		//  }

		//  //  FIXME: where to put this?
		//  private virtual async string query_registry(Traits.SupportsCompatTools runnable, string path, string value)
		//  {
		//  	var task = Utils.exec({executable.get_path(), "wine", "reg", "query", path, "/v", value}).log(false);
		//  	apply_env(runnable, task, null);
		//  	var result = (yield task.sync_thread(true)).output.strip();
		//  	debug("[Wine.query_registry] result: '%s'", result);
		//  	return result;
		//  }

		//  //  TODO: make SaveGameFile a property of EpicGame
		//  private SaveGameFile.Status check_savegame_state(File path, SaveGameFile? save, out DateTime local, out DateTime remote)
		//  {
		//  	//  legendary does a os.walk here
		//  	var latest = 0;

		//  	if(latest == 0 && save == null) return SaveGameFile.Status.NO_SAVE;

		//  	try {
		//  		local = path.query_info("*", FileQueryInfoFlags.NONE).get_modification_date_time();
		//  	} catch (Error e) {
		//  		debug("error: " + e.message);
		//  	}

		//  	if(save == null)
		//  	{
		//  		return SaveGameFile.Status.LOCAL_NEWER;
		//  	}

		//  	int year, month, day, hour, minute;
		//  	double seconds;
		//  	save.manifest_name.scanf("%Y.%m.%d-%H.%M.%S.manifest", &year, &month, &day, &hour, &minute, &seconds);
		//  	remote = DateTime(TimeZone.utc(), year, month, day, hour, minute, seconds);

		//  	if(latest == 0) return SaveGameFile.Status.REMOTE_NEWER;

		//  	debug("[EpicGame.check_savegame_state] local: %s, remote: %s", local.to_string(), remote.to_string());

		//  	//  Ideally we check the files themselves based on manifest,
		//  	//  this is mostly a guess but should be accurate enough.
		//  	if(local.difference(remote).abs() < TimeSpan.MINUTE)
		//  	{
		//  		return SaveGameFile.Status.SAME_AGE;
		//  	}
		//  	else if(local.compare(remote) > 0)
		//  	{
		//  		return SaveGameFile.Status.LOCAL_NEWER;
		//  	}

		//  	return SaveGameFile.Status.REMOTE_NEWER;
		//  }

		private void upload_save() {}
		private void download_saves() {}

		public class DLC: EpicGame
		{
			public EpicGame game;

			public DLC(EpicGame game, Asset asset, Json.Node? metadata = null)
			{
				base(game.source as EpicGames, asset, metadata);

				icon  = game.icon;
				image = game.image;

				install_dir = game.install_dir;
				work_dir    = game.work_dir;
				executable  = game.executable;

				platforms = game.platforms;

				this.game = game;
				update_status();
			}

			//  Allow saving installed DLC version seperate from main game
			private string?         _version = null;
			public override string? version
			{
				get { return _version; }
				set
				{
					_version = value;

					if(install_dir == null || !install_dir.query_exists()) return;

					var file = get_file(@"$(FS.GAMEHUB_DIR)/$id.version", false);
					try
					{
						FS.mkdir(file.get_parent().get_path());
						FileUtils.set_contents(file.get_path(), _version);
					}
					catch (Error e)
					{
						warning("[Game.version.set] Error while writing game version: %s", e.message);
					}
				}
			}

			protected override void load_version()
			{
				if(install_dir == null || !install_dir.query_exists()) return;

				var file = get_file(@"$(FS.GAMEHUB_DIR)/$id.version");

				if(file != null)
				{
					try
					{
						string ver;
						FileUtils.get_contents(file.get_path(), out ver);
						version = ver;
					}
					catch (Error e)
					{
						warning("[Game.load_version] Error while reading game version: %s", e.message);
					}
				}
			}

			public override void update_status()
			{
				if(game == null) return;

				base.update_status();
			}

			public override async void install(InstallTask.Mode                                 install_mode = InstallTask.Mode.INTERACTIVE)
			{
				if(game.status.state != Game.State.INSTALLED)
				{
					warning("Base game not installed, aborting");

					return;
				}

				ArrayList<File>? dirs = new ArrayList<File>();
				dirs.add(install_dir);
				var task = new InstallTask(this, installers, dirs, InstallTask.Mode.AUTO_INSTALL, false);
				yield task.start();
			}

			public override async void uninstall()
			{
				//  TODO: Only remove DLC files
			}
		}

		public class Asset
		{
			public string app_name;
			public string asset_id;
			public string build_version;
			public string catalog_item_id;
			public string label_name;
			public string ns;
			//  public Json.Node asset;
			public Json.Node metadata;

			//  public GameAsset() {}

			public Asset.from_egs_json(Json.Node json)
			{
				assert(json.get_node_type() == Json.NodeType.OBJECT);

				app_name        = json.get_object().get_string_member_with_default("appName", "");
				asset_id        = json.get_object().get_string_member_with_default("assetId", "");
				build_version   = json.get_object().get_string_member_with_default("buildVersion", "");
				catalog_item_id = json.get_object().get_string_member_with_default("catalogItemId", "");
				label_name      = json.get_object().get_string_member_with_default("labelName", "");
				ns              = json.get_object().get_string_member_with_default("namespace", "");

				//  asset = json;
				if(json.get_object().has_member("metadata"))
				{
					metadata = json.get_object().get_member("metadata");
				}
				else
				{
					metadata = new Json.Node(Json.NodeType.OBJECT);
					metadata.set_object(new Json.Object());
				}

				//  json.get_object().set_object_member("metadata", metadata.get_object());
			}

			public Asset.from_json(Json.Node json)
			{
				assert(json.get_node_type() == Json.NodeType.OBJECT);

				app_name        = json.get_object().get_string_member_with_default("app_name", "");
				asset_id        = json.get_object().get_string_member_with_default("asset_id", "");
				build_version   = json.get_object().get_string_member_with_default("build_version", "");
				catalog_item_id = json.get_object().get_string_member_with_default("catalog_item_id", "");
				label_name      = json.get_object().get_string_member_with_default("label_name", "");
				ns              = json.get_object().get_string_member_with_default("namespace", "");

				if(json.get_object().has_member("metadata"))
				{
					metadata = json.get_object().get_member("metadata");
				}
				else
				{
					metadata = new Json.Node(Json.NodeType.OBJECT);
					metadata.set_object(new Json.Object());
				}
			}

			public Json.Node to_json()
			{
				var json = new Json.Node(Json.NodeType.OBJECT);
				json.set_object(new Json.Object());
				json.get_object().set_string_member("app_name", app_name);
				json.get_object().set_string_member("asset_id", asset_id);
				json.get_object().set_string_member("build_version", build_version);
				json.get_object().set_string_member("catalog_item_id", catalog_item_id);
				json.get_object().set_string_member("label_name", label_name);
				json.get_object().set_object_member("metadata", metadata.get_object());
				json.get_object().set_string_member("namespace", ns);

				return json;
			}

			public string to_string(bool pretty) { return Json.to_string(to_json(), pretty); }

			public static new bool is_equal(Asset a, Asset b)
			{
				if(a.asset_id == b.asset_id)
				{
					return true;
				}

				return false;
			}
		}

		//  public class RunnableAction: Traits.HasActions.Action
		//  {
		//  	public RunnableAction(EpicGame game)
		//  	{
		//  		runnable   = game;
		//  		is_primary = true;
		//  		name       = "Update";
		//  		is_hidden  = !game.has_updates;
		//  	}

		//  	public new bool is_available(GameHub.Data.Compat.CompatTool? tool = null) { return ((EpicGame) runnable).has_updates; }

		//  	public new async void invoke(GameHub.Data.Compat.CompatTool? tool = null) { yield((EpicGame) runnable).install(InstallTask.Mode.AUTO_INSTALL); }
		//  }
	}
}

using Gee;

using GameHub.Utils;

namespace GameHub.Data.Compat
{
	public class DOSBox: CompatTool
	{
		public string binary { get; construct; default = "dosbox"; }

		private File conf_windowed;
		private CompatTool.Option? opt_windowed;

		public DOSBox(string binary="dosbox")
		{
			Object(binary: binary);
		}

		construct
		{
			id = @"dosbox";
			name = @"DOSBox";
			icon = "tool-dosbox-symbolic";

			executable = Utils.find_executable(binary);
			installed = executable != null && executable.query_exists();

			conf_windowed = FSUtils.file(ProjectConfig.DATADIR + "/" + ProjectConfig.PROJECT_NAME, "compat/dosbox/windowed.conf");
			if(conf_windowed.query_exists())
			{
				opt_windowed = new CompatTool.Option(_("Windowed"), _("Disable fullscreen"), true);
				options = { opt_windowed };
			}
		}

		private static ArrayList<string> find_configs(File? dir)
		{
			var configs = new ArrayList<string>();

			if(dir == null || !dir.query_exists())
			{
				return configs;
			}

			try
			{
				FileInfo? finfo = null;
				var enumerator = dir.enumerate_children("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
				while((finfo = enumerator.next_file()) != null)
				{
					var fname = finfo.get_name();
					if(fname.has_suffix(".conf"))
					{
						configs.add(dir.get_child(fname).get_path());
					}
				}
			}
			catch(Error e)
			{
				warning("[DOSBox.find_configs] %s", e.message);
			}
			
                        if (configs.size == 1)
                        {
				return configs;
                        }
                        foreach (string s in configs)
                        {
				if (s.contains("_single.conf")) {
					configs.clear();
					configs.add(s);
					configs.add(s.replace("_single",""));
					return configs;
                                }
                        }
			return configs;
		}

		public override bool can_run(Game game)
		{
			return installed && find_configs(game.install_dir).size > 0;
		}

		public override async void run(Game game)
		{
			if(!can_run(game)) return;

			string[] cmd = { executable.get_path() };

			var wdir = game.install_dir;

			var configs = find_configs(game.install_dir);

			foreach(var conf in configs)
			{
				cmd += "-conf";
				cmd += conf;
			}

			if(conf_windowed.query_exists() && opt_windowed != null && opt_windowed.enabled)
			{
				cmd += "-conf";
				cmd += conf_windowed.get_path();
			}

			if(game.install_dir.get_child("DOSBOX").get_child("DOSBox.exe").query_exists())
			{
				wdir = game.install_dir.get_child("DOSBOX");
			}

			yield Utils.run_thread(cmd, wdir.get_path());
		}
	}
}

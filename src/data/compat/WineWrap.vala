/*
This file is part of GameHub.
Copyright (C) 2018-2019 Anatoliy Kashkin

GameHub is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

GameHub is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GameHub.  If not, see <https://www.gnu.org/licenses/>.
*/

using Gee;

using GameHub.Utils;

using GameHub.Data.Runnables;
using GameHub.Data.Runnables.Tasks.Install;

using GameHub.Data.Sources.GOG;

namespace GameHub.Data.Compat
{
	public class WineWrap: CompatTool
	{
		private const string WRAPPERS_INDEX_URL = "https://dropbox.com/s/dl/kw8t2b5x7b19guz/winewrap_index.json";

		private HashMap<string, string> wrappers = new HashMap<string, string>();

		public WineWrap()
		{
			id = "winewrap";
			name = "WineWrap (by adamhm)";
			icon = "tool-wine-symbolic";
			installed = true;
			update_index.begin();
		}

		private async void update_index()
		{
			if(GameHub.Application.log_verbose)
			{
				debug("[WineWrap] Updating index");
			}

			var root_node = yield Parser.parse_remote_json_file_async(WRAPPERS_INDEX_URL);
			if(root_node == null || root_node.get_node_type() != Json.NodeType.OBJECT) return;
			var root = root_node.get_object();
			if(root == null) return;

			foreach(var id in root.get_members())
			{
				wrappers.set(id, root.get_object_member(id).get_string_member("url"));
			}

			if(wrappers.size > 0)
			{
				actions = {
					new CompatTool.Action("play", _("Run"), r => {
						action.begin(r, "play");
					}),
					new CompatTool.Action("menu", _("Show WineWrap menu"), r => {
						action.begin(r, "menu");
					}),
					new CompatTool.Action("kill", _("Kill apps in prefix"), r => {
						action.begin(r, "kill");
					})
				};
			}
			else
			{
				installed = false;
			}

			if(GameHub.Application.log_verbose)
			{
				debug("[WineWrap] Index updated");
			}
		}

		public override bool can_install(Traits.SupportsCompatTools runnable, InstallTask task)
		{
			return can_run(runnable);
		}

		public override async void install(Traits.SupportsCompatTools runnable, InstallTask task, File installer)
		{
			if(!can_install(runnable, task)) return;

			var wrapper_dir = FS.mkdir(FS.Paths.Cache.WineWrap, runnable.id);

			FS.rm(wrapper_dir.get_path(), "*", "-rf");

			var wrapper_remote = File.new_for_uri(wrappers.get(runnable.id));
			var wrapper_local = FS.file(wrapper_dir.get_path(), @"/winewrap_$(runnable.id).tar.xz");

			try
			{
				var wrapper = yield Downloader.download_file(wrapper_remote, wrapper_local);

				if(wrapper == null || !wrapper.query_exists()) return;

				string[] cmd = { "tar", "xf", wrapper.get_path(), "-C", wrapper_dir.get_path(), "--strip-components=1" };
				yield Utils.exec(cmd).dir(wrapper_dir.get_path()).sync_thread();

				var winewrap_env = Environ.get();
				winewrap_env = Environ.set_variable(winewrap_env, "WINEWRAP_RESPATH", installer.get_parent().get_path());
				winewrap_env = Environ.set_variable(winewrap_env, "WINEWRAP_BUILDPATH", runnable.install_dir.get_parent().get_path());
				winewrap_env = Environ.set_variable(winewrap_env, "WINEWRAP_SKIP_CHECKSUMS", "1");

				FS.rm(runnable.install_dir.get_path(), null, "-rf");

				cmd = { "bash", "-c", "./*_wine.sh -dirname=" + runnable.name_escaped };
				yield Utils.exec(cmd).dir(wrapper_dir.get_path()).env(winewrap_env).sync_thread();

				runnable.executable = runnable.install_dir.get_child("start.sh");
			}
			catch(Error e)
			{
				warning("[WineWrap] %s", e.message);
			}
		}

		public override bool can_run(Traits.SupportsCompatTools runnable)
		{
			return installed && runnable != null && runnable is GOGGame && wrappers.has_key(runnable.id);
		}

		public override async void run(Traits.SupportsCompatTools runnable)
		{
			yield action(runnable, "play");
		}

		private async void action(Traits.SupportsCompatTools runnable, string action)
		{
			if(!can_run(runnable)) return;

			string[] cmd = { runnable.install_dir.get_child("start.sh").get_path(), action };

			var task = Utils.exec(combine_cmd_with_args(cmd, runnable)).dir(runnable.work_dir.get_path());
			runnable.cast<Traits.Game.SupportsTweaks>(game => {
				task.tweaks(game.get_enabled_tweaks(this));
			});
			yield task.sync_thread();
		}
	}
}

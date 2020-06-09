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
					new CompatTool.Action("play", _("Run"), (r, cb) => {
						this.run.begin(r, cb((obj, res) => {
							this.run.end(res);
						}));
					}),
					new CompatTool.Action("menu", _("Show WineWrap menu"), (r, cb) => {
						this.show_menu.begin(r, cb((obj, res) => {
							this.show_menu.end(res);
						}));
					}),
					new CompatTool.Action("kill", _("Kill apps in prefix"), (r, cb) => {
						this.kill.begin(r, cb((obj, res) => {
							this.kill.end(res);
						}));
					}),
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

		public override bool can_install(Runnable runnable)
		{
			return installed && runnable != null && runnable is GOGGame && wrappers.has_key(runnable.id);
		}

		public override async void install(Runnable runnable, File installer) throws Utils.RunError
		{
			if(!can_install(runnable)) return;

			var wrapper_dir = FSUtils.mkdir(FSUtils.Paths.Cache.WineWrap, runnable.id);

			FSUtils.rm(wrapper_dir.get_path(), "*", "-rf");

			var wrapper_remote = File.new_for_uri(wrappers.get(runnable.id));
			var wrapper_local = FSUtils.file(wrapper_dir.get_path(), @"/winewrap_$(runnable.id).tar.xz");

			try
			{
				var wrapper = yield Downloader.download_file(wrapper_remote, wrapper_local);

				if(wrapper == null || !wrapper.query_exists()) return;

				string[] cmd = { "tar", "xf", wrapper.get_path(), "-C", wrapper_dir.get_path(), "--strip-components=1" };
				yield Utils.run(cmd).dir(wrapper_dir.get_path()).run_sync_thread();

				var winewrap_env = Environ.get();
				winewrap_env = Environ.set_variable(winewrap_env, "WINEWRAP_RESPATH", installer.get_parent().get_path());
				winewrap_env = Environ.set_variable(winewrap_env, "WINEWRAP_BUILDPATH", runnable.install_dir.get_parent().get_path());
				winewrap_env = Environ.set_variable(winewrap_env, "WINEWRAP_SKIP_CHECKSUMS", "1");

				FSUtils.rm(runnable.install_dir.get_path(), null, "-rf");

				cmd = { "bash", "-c", "./*_wine.sh -dirname=" + (runnable as GOGGame).escaped_name };
				yield Utils.run(cmd).dir(wrapper_dir.get_path()).env(winewrap_env).run_sync_thread();

				runnable.executable = runnable.install_dir.get_child("start.sh");
			}
			catch(Error e)
			{
				var message = (_("Installing WineWrap from “%s” failed: ") + "%s (%s:%d)").printf(
					wrapper_remote.get_uri(),
					e.message, e.domain.to_string(), e.code
				);
				warning("[WineWrap] %s", message);
				throw new Utils.RunError.FAILED("%s", message);
			}
		}

		public override bool can_run(Runnable runnable)
		{
			return can_install(runnable) || runnable.compat_tool == id;
		}

		public override async void run(Runnable runnable) throws Utils.RunError
		{
			yield action(runnable, "play");
		}

		public async void show_menu(Runnable runnable) throws Utils.RunError
		{
			yield action(runnable, "menu");
		}

		public async void kill(Runnable runnable) throws Utils.RunError
		{
			yield action(runnable, "kill");
		}

		private async void action(Runnable runnable, string action) throws Utils.RunError
		{
			if(!can_run(runnable))
			{
				throw new Utils.RunError.FAILED(
					_("Runnable “%s” does not expect WineWrap as its compat tool"),
					runnable.name
				);
			}

			string[] cmd = { runnable.install_dir.get_child("start.sh").get_path(), action };

			var task = Utils.run(combine_cmd_with_args(cmd, runnable)).dir(runnable.work_dir.get_path());
			if(runnable is TweakableGame)
			{
				task.tweaks(((TweakableGame) runnable).get_enabled_tweaks(this));
			}
			yield task.run_sync_thread();
		}
	}
}

/*
This file is part of GameHub.
Copyright (C) 2018 Anatoliy Kashkin

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
		private const string WRAPPERS_INDEX_URL = "https://gist.githubusercontent.com/tkashkin/10b55144c8bd17f76b5c14d18a658f5f/raw/adamhm_winewrap_index.json";

		private HashMap<string, string> wrappers = new HashMap<string, string>();

		public WineWrap()
		{
			id = @"winewrap";
			name = "WineWrap (by adamhm)";
			icon = "tool-wine-symbolic";
			installed = false;
			update_index.begin();
		}

		private async void update_index()
		{
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
				installed = true;
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
		}

		public override bool can_install(Runnable runnable)
		{
			return installed && runnable != null && runnable is GOGGame && wrappers.has_key(runnable.id);
		}

		public override async void install(Runnable runnable, File installer)
		{
			if(!can_install(runnable)) return;

			var wrapper_dir = FSUtils.mkdir(FSUtils.Paths.Cache.WineWrap, runnable.id);

			FSUtils.rm(wrapper_dir.get_path(), "*", "-rf");

			var wrapper_remote = File.new_for_uri(wrappers.get(runnable.id));
			var wrapper_local = FSUtils.file(wrapper_dir.get_path(), @"/winewrap_$(runnable.id).tar.xz");

			try
			{
				var wrapper = yield Downloader.download(wrapper_remote, wrapper_local);

				if(wrapper == null || !wrapper.query_exists()) return;

				string[] cmd = { "tar", "xf", wrapper.get_path(), "-C", wrapper_dir.get_path(), "--strip-components=1" };
				yield Utils.run_thread(cmd, wrapper_dir.get_path());

				var winewrap_env = Environ.get();
				winewrap_env = Environ.set_variable(winewrap_env, "WINEWRAP_RESPATH", installer.get_parent().get_path());
				winewrap_env = Environ.set_variable(winewrap_env, "WINEWRAP_BUILDPATH", FSUtils.expand(FSUtils.Paths.GOG.Games));

				FSUtils.rm(FSUtils.Paths.GOG.Games, (runnable as GOGGame).escaped_name, "-rf");

				cmd = { "bash", "-c", "./*_wine.sh -dirname=" + (runnable as GOGGame).escaped_name };
				yield Utils.run_thread(cmd, wrapper_dir.get_path(), winewrap_env);

				runnable.executable = runnable.install_dir.get_child("start.sh");
			}
			catch(Error e)
			{
				warning("[WineWrap] %s", e.message);
			}
		}

		public override bool can_run(Runnable runnable)
		{
			return can_install(runnable);
		}

		public override async void run(Runnable runnable)
		{
			yield action(runnable, "play");
		}

		private async void action(Runnable runnable, string action)
		{
			if(!can_run(runnable)) return;
			yield Utils.run_thread({ runnable.install_dir.get_child("start.sh").get_path(), action }, runnable.install_dir.get_path());
		}
	}
}

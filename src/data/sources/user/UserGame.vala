using Gee;
using GameHub.Data.DB;
using GameHub.Utils;

namespace GameHub.Data.Sources.User
{
	public class UserGame: Game
	{
		private bool is_removed = false;
		public signal void removed();

		public UserGame(string name, File dir, File exec, string args)
		{
			source = User.instance;

			this.id = Utils.md5(name + Random.next_int().to_string());
			this.name = name;

			platforms.clear();
			platforms.add(Platform.LINUX);

			install_dir = dir;
			executable = exec;
			arguments = args;
			update_status();
		}

		public UserGame.from_db(User src, Sqlite.Statement s)
		{
			source = src;
			id = Tables.Games.ID.get(s);
			name = Tables.Games.NAME.get(s);
			info = Tables.Games.INFO.get(s);
			info_detailed = Tables.Games.INFO_DETAILED.get(s);
			icon = Tables.Games.ICON.get(s);
			image = Tables.Games.IMAGE.get(s);
			install_dir = FSUtils.file(Tables.Games.INSTALL_PATH.get(s)) ?? FSUtils.file(FSUtils.Paths.GOG.Games, escaped_name);
			executable = FSUtils.file(Tables.Games.EXECUTABLE.get(s)) ?? FSUtils.file(install_dir.get_path(), "start.sh");
			compat_tool = Tables.Games.COMPAT_TOOL.get(s);
			compat_tool_settings = Tables.Games.COMPAT_TOOL_SETTINGS.get(s);
			arguments = Tables.Games.ARGUMENTS.get(s);

			platforms.clear();
			var pls = Tables.Games.PLATFORMS.get(s).split(",");
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
			var tag_ids = (Tables.Games.TAGS.get(s) ?? "").split(",");
			foreach(var tid in tag_ids)
			{
				foreach(var t in Tables.Tags.TAGS)
				{
					if(tid == t.id)
					{
						if(!tags.contains(t)) tags.add(t);
						break;
					}
				}
			}

			update_status();
		}

		public override async void update_game_info()
		{
			update_status();
			save();
		}

		public override async void install(){}

		public override async void uninstall()
		{
			remove();
		}

		public void remove()
		{
			is_removed = true;
			removed();
			Tables.Games.remove(this);
		}

		public override void save()
		{
			if(!is_removed)
			{
				base.save();
			}
		}

		public override void update_status()
		{
			var state = executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED;
			status = new Game.Status(state);
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
		}
	}
}

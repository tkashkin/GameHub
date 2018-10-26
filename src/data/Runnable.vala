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
using Gtk;

using GameHub.Utils;
using GameHub.Data.DB;

namespace GameHub.Data
{
	public abstract class Runnable: Object
	{
		public string id { get; protected set; }
		public string name { get; set; }

		public string? compat_tool { get; set; }
		public string? compat_tool_settings { get; set; }

		public string? arguments { get; set; }

		public ArrayList<Platform> platforms { get; protected set; default = new ArrayList<Platform>(); }
		public virtual bool is_supported(Platform? platform=null, bool with_compat=true)
		{
			platform = platform ?? CurrentPlatform;
			if(platforms == null || platforms.size == 0 || platform in platforms) return true;
			if(!with_compat) return false;
			foreach(var tool in CompatTools)
			{
				if(tool.can_run(this)) return true;
			}
			return false;
		}

		public File executable { get; set; }
		public File install_dir { get; set; }

		public abstract async void run();

		public virtual async void run_with_compat(bool is_opened_from_menu=false)
		{
			if(!RunnableIsLaunched)
			{
				new UI.Dialogs.CompatRunDialog(this, is_opened_from_menu);
			}
		}

		public virtual FileChooserDialog setup_executable_chooser()
		{
			var chooser = new FileChooserDialog(_("Select executable"), GameHub.UI.Windows.MainWindow.instance, FileChooserAction.OPEN);
			var filter = new FileFilter();

			filter.add_mime_type("application/x-executable");
			filter.add_mime_type("application/x-elf");
			filter.add_mime_type("application/x-sh");
			filter.add_mime_type("text/x-shellscript");

			filter.add_mime_type("application/x-dosexec");
			filter.add_mime_type("application/x-ms-dos-executable");
			filter.add_mime_type("application/dos-exe");
			filter.add_mime_type("application/exe");
			filter.add_mime_type("application/msdos-windows");
			filter.add_mime_type("application/x-exe");
			filter.add_mime_type("application/x-msdownload");
			filter.add_mime_type("application/x-winexe");

			chooser.set_filter(filter);

			try
			{
				chooser.set_file(executable);
			}
			catch(Error e)
			{
				warning(e.message);
			}

			chooser.add_button(_("Cancel"), ResponseType.CANCEL);
			var select_btn = chooser.add_button(_("Select"), ResponseType.ACCEPT);

			select_btn.get_style_context().add_class(Gtk.STYLE_CLASS_SUGGESTED_ACTION);
			select_btn.grab_default();

			return chooser;
		}

		public virtual void choose_executable(bool update=true)
		{
			var chooser = setup_executable_chooser();

			if(chooser.run() == ResponseType.ACCEPT)
			{
				set_chosen_executable(chooser, update);
			}

			chooser.destroy();
		}

		public virtual void set_chosen_executable(FileChooserDialog chooser, bool update=true)
		{
			executable = chooser.get_file();
			if(executable.query_exists())
			{
				Utils.run({"chmod", "+x", executable.get_path()});
			}

			if(update)
			{
				update_status();
				save();
			}
		}

		public virtual void save(){}
		public virtual void update_status(){}

		public virtual void import(bool update=true)
		{
			var chooser = new FileChooserDialog(_("Select directory"), GameHub.UI.Windows.MainWindow.instance, FileChooserAction.SELECT_FOLDER);

			var games_dir = "";
			if(this is Sources.GOG.GOGGame)
			{
				games_dir = FSUtils.Paths.GOG.Games;
			}
			else if(this is Sources.Humble.HumbleGame)
			{
				games_dir = FSUtils.Paths.Humble.Games;
			}

			chooser.set_current_folder(games_dir);

			chooser.add_button(_("Cancel"), ResponseType.CANCEL);
			var select_btn = chooser.add_button(_("Select"), ResponseType.ACCEPT);

			select_btn.get_style_context().add_class(Gtk.STYLE_CLASS_SUGGESTED_ACTION);
			select_btn.grab_default();

			if(chooser.run() == ResponseType.ACCEPT)
			{
				install_dir = chooser.get_file();
				executable = FSUtils.file(install_dir.get_path(), "start.sh");

				if(!executable.query_exists())
				{
					choose_executable(false);
				}

				if(install_dir.query_exists())
				{
					Utils.run({"chmod", "-R", "+x", install_dir.get_path()});
				}

				if(update)
				{
					update_status();
					save();
				}
			}

			chooser.destroy();
		}

		public bool use_compat
		{
			get
			{
				return needs_compat || force_compat;
			}
		}

		public bool needs_compat
		{
			get
			{
				return (!is_supported(null, false) && is_supported(null, true)) || (executable != null && executable.get_basename().has_suffix(".exe"));
			}
		}

		public bool force_compat
		{
			get
			{
				if(this is Sources.Steam.SteamGame) return false;
				if(get_compat_option_bool("force_compat") == true) return true;
				return false;
			}
			set
			{
				if(this is Sources.Steam.SteamGame) return;
				set_compat_option_bool("force_compat", value);
				notify_property("use-compat");
			}
		}

		public bool compat_options_saved
		{
			get
			{
				if(this is Sources.Steam.SteamGame) return false;
				return get_compat_option_bool("compat_options_saved") == true;
			}
			set
			{
				if(this is Sources.Steam.SteamGame) return;
				set_compat_option_bool("compat_options_saved", value);
			}
		}

		public Json.Object get_compat_settings(CompatTool tool)
		{
			if(compat_tool_settings != null && compat_tool_settings.length > 0)
			{
				var root = Parser.parse_json(compat_tool_settings);
				var settings = Parser.json_object(root, { tool.id });
				if(settings != null)
				{
					return settings;
				}
			}
			return new Json.Object();
		}

		public void set_compat_settings(CompatTool tool, Json.Object? settings)
		{
			var root_object = new Json.Object();
			if(compat_tool_settings != null && compat_tool_settings.length > 0)
			{
				var root = Parser.parse_json(compat_tool_settings);
				if(root != null && root.get_node_type() == Json.NodeType.OBJECT)
				{
					root_object = root.get_object();
				}
			}

			if(settings == null)
			{
				root_object.remove_member(tool.id);
			}
			else
			{
				root_object.set_object_member(tool.id, settings);
			}

			var root_node = new Json.Node(Json.NodeType.OBJECT);
			root_node.set_object(root_object);
			compat_tool_settings = Json.to_string(root_node, false);
			compat_options_saved = true;
			save();
		}

		public bool? get_compat_option_bool(string key)
		{
			if(compat_tool_settings != null && compat_tool_settings.length > 0)
			{
				var root = Parser.parse_json(compat_tool_settings);
				if(root != null && root.get_node_type() == Json.NodeType.OBJECT)
				{
					var obj = root.get_object();
					if(obj.has_member(key)) return obj.get_boolean_member(key);
				}
			}
			return null;
		}

		public void set_compat_option_bool(string key, bool? value)
		{
			var root_object = new Json.Object();
			if(compat_tool_settings != null && compat_tool_settings.length > 0)
			{
				var root = Parser.parse_json(compat_tool_settings);
				if(root != null && root.get_node_type() == Json.NodeType.OBJECT)
				{
					root_object = root.get_object();
				}
			}
			if(value != null)
			{
				root_object.set_boolean_member(key, value);
			}
			else
			{
				root_object.remove_member(key);
			}
			var root_node = new Json.Node(Json.NodeType.OBJECT);
			root_node.set_object(root_object);
			compat_tool_settings = Json.to_string(root_node, false);
			save();
		}
	}

	public enum Platform
	{
		LINUX, WINDOWS, MACOS;

		public string id()
		{
			switch(this)
			{
				case Platform.LINUX: return "linux";
				case Platform.WINDOWS: return "windows";
				case Platform.MACOS: return "mac";
			}
			assert_not_reached();
		}

		public string name()
		{
			switch(this)
			{
				case Platform.LINUX: return "Linux";
				case Platform.WINDOWS: return "Windows";
				case Platform.MACOS: return "macOS";
			}
			assert_not_reached();
		}

		public string icon()
		{
			switch(this)
			{
				case Platform.LINUX: return "platform-linux-symbolic";
				case Platform.WINDOWS: return "platform-windows-symbolic";
				case Platform.MACOS: return "platform-macos-symbolic";
			}
			assert_not_reached();
		}
	}

	public static Platform[] Platforms;
	public static Platform CurrentPlatform;

	public static bool RunnableIsLaunched = false;
}

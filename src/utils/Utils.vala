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

using Gtk;
using Granite;

namespace GameHub.Utils
{
	public delegate void Future();
	public delegate void FutureBoolean(bool result);
	public delegate void FutureResult<T>(T result);
	public delegate void FutureResult2<T, T2>(T t, T2 t2);
	public delegate Notification NotificationConfigureDelegate(Notification notification);

	private class Worker
	{
		public string name;
		public Future worker;
		public bool log;
		public Worker(string name, owned Future worker, bool log=true)
		{
			this.name = name;
			this.worker = (owned) worker;
			this.log = log;
		}
		public void run()
		{
			bool dbg = GameHub.Application.log_workers && log && !name.has_prefix("Merging-");
			if(dbg) debug("[Worker] %s started", name);
			worker();
			if(dbg) debug("[Worker] %s finished", name);
		}
	}

	private static ThreadPool<Worker>? threadpool = null;

	public static void open_uri(string uri)
	{
		try
		{
			AppInfo.launch_default_for_uri(uri, null);
		}
		catch(Error e)
		{
			warning(e.message);
		}
	}

	public static string[]? parse_args(string? args)
	{
		if(args != null && args.length > 0)
		{
			try
			{
				string[]? argv = null;
				Shell.parse_argv(args, out argv);
				return argv;
			}
			catch(ShellError e)
			{
				warning("[Utils.parse_args] Error parsing args: %s", e.message);
			}
		}
		return null;
	}

	public static string run(string[] cmd, string? dir=null, string[]? env=null, bool override_runtime=false, bool capture_output=false, bool log=true)
	{
		string stdout = "";
		string stderr = "";

		var cdir = dir ?? Environment.get_home_dir();
		var cenv = env ?? Environ.get();

		#if FLATPAK
		if(override_runtime && ProjectConfig.RUNTIME.length > 0)
		{
			cenv = Environ.set_variable(cenv, "LD_LIBRARY_PATH", ProjectConfig.RUNTIME);
		}
		string[] ccmd = { "flatpak-spawn", "--host" };
		foreach(var arg in cmd)
		{
			ccmd += arg;
		}
		#else
		string[] ccmd = cmd;
		#endif

		try
		{
			if(log) debug("[Utils.run] {'%s'}; dir: '%s'", string.joinv("' '", cmd), cdir);

			if(capture_output)
			{
				Process.spawn_sync(cdir, ccmd, cenv, SpawnFlags.SEARCH_PATH, null, out stdout, out stderr);
				stdout = stdout.strip();
				stderr = stderr.strip();
				if(log)
				{
					if(stdout.length > 0) print(stdout + "\n");
					if(stderr.length > 0) warning(stderr);
				}
			}
			else
			{
				Process.spawn_sync(cdir, ccmd, cenv, SpawnFlags.SEARCH_PATH | SpawnFlags.CHILD_INHERITS_STDIN, null);
			}
		}
		catch (Error e)
		{
			warning("[Utils.run] %s", e.message);
		}
		return stdout;
	}

	public static async void run_async(string[] cmd, string? dir=null, string[]? env=null, bool override_runtime=false, bool wait=true, bool log=true)
	{
		Pid pid;

		var cdir = dir ?? Environment.get_home_dir();
		var cenv = env ?? Environ.get();

		#if FLATPAK
		if(override_runtime && ProjectConfig.RUNTIME.length > 0)
		{
			cenv = Environ.set_variable(cenv, "LD_LIBRARY_PATH", ProjectConfig.RUNTIME);
		}
		string[] ccmd = { "flatpak-spawn", "--host" };
		foreach(var arg in cmd)
		{
			ccmd += arg;
		}
		#else
		string[] ccmd = cmd;
		#endif

		try
		{
			if(log) debug("[Utils.run_async] Running {'%s'} in '%s'", string.joinv("' '", cmd), cdir);
			Process.spawn_async(cdir, ccmd, cenv, SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD, null, out pid);

			ChildWatch.add(pid, (pid, status) => {
				Process.close_pid(pid);
				Idle.add(run_async.callback);
			});
		}
		catch (Error e)
		{
			warning("[Utils.run_async] %s", e.message);
		}

		if(wait) yield;
	}

	public static async string run_thread(string[] cmd, string? dir=null, string[]? env=null, bool override_runtime=false, bool capture_output=false, bool log=true)
	{
		string stdout = "";

		Utils.thread("Utils.run_thread", () => {
			stdout = Utils.run(cmd, dir, env, override_runtime, capture_output, log);
			Idle.add(run_thread.callback);
		}, log);

		yield;
		return stdout;
	}

	public static File? find_executable(string? name)
	{
		if(name == null || name.length == 0) return null;
		var which = Environment.find_program_in_path(name) ?? run({ "which", name }, null, null, false, true, false);
		if(which.length == 0 || !which.has_prefix("/"))
		{
			return null;
		}
		return File.new_for_path(which);
	}

	public static void thread(string name, owned Future worker, bool log=true)
	{
		try
		{
			if(threadpool == null)
			{
				threadpool = new ThreadPool<Worker>.with_owned_data(w => w.run(), Application.worker_threads, false);
			}
			threadpool.add(new Worker(name, (owned) worker, log));
		}
		catch(Error e)
		{
			warning(e.message);
		}
	}

	public static string get_distro()
	{
		if(distro != null) return distro;
		distro = Utils.run({"bash", "-c", "lsb_release -ds 2>/dev/null || cat /etc/*release 2>/dev/null | head -n1 || uname -om"}, null, null, false, true, false).replace("\"", "");
		#if APPIMAGE
		distro = "[AppImage] " + distro;
		#elif FLATPAK
		distro = "[Flatpak] " + distro;
		#elif SNAP
		distro = "[Snap] " + distro;
		#endif
		return distro;
	}

	public static string? get_desktop_environment()
	{
		return Environment.get_variable("XDG_CURRENT_DESKTOP");
	}

	public static string get_language_name()
	{
		return Posix.nl_langinfo((Posix.NLItem) 786439); // _NL_IDENTIFICATION_LANGUAGE
	}

	public static bool is_package_installed(string package)
	{
		#if APPIMAGE || FLATPAK || SNAP
		return false;
		#elif PM_APT
		var output = Utils.run({"dpkg-query", "-W", "-f=${Status}", package}, null, null, false, true, false);
		return "install ok installed" in output;
		#else
		return false;
		#endif
	}

	public static async void sleep_async(uint interval, int priority=GLib.Priority.DEFAULT)
	{
		Timeout.add(interval, () => {
			sleep_async.callback();
			return false;
		}, priority);
		yield;
	}

	public static string md5(string s)
	{
		return Checksum.compute_for_string(ChecksumType.MD5, s, s.length);
	}

	public static async string? compute_file_checksum(File file, ChecksumType type=ChecksumType.MD5)
	{
		string? hash = null;
		Utils.thread("Checksum-" + md5(file.get_path()), () => {
			Checksum checksum = new Checksum(type);
			FileStream stream = FileStream.open(file.get_path(), "rb");
			uint8 buf[4096];
			size_t size;
			while((size = stream.read(buf)) > 0)
			{
				checksum.update(buf, size);
			}
			hash = checksum.get_string();
			Idle.add(compute_file_checksum.callback);
		});
		yield;
		return hash;
	}

	public static string get_relative_datetime(GLib.DateTime date_time)
	{
		var schema_source = SettingsSchemaSource.get_default();
		if(schema_source != null)
		{
			var schema = schema_source.lookup("io.elementary.desktop.wingpanel.datetime", true);
			if(schema != null)
			{
				return Granite.DateTime.get_relative_datetime(date_time);
			}
		}
		return date_time.format("%x %R");
	}

	public static void notify(string title, string? body=null, NotificationPriority priority=NotificationPriority.NORMAL, NotificationConfigureDelegate? config=null)
	{
		var notification = new Notification(title);
		notification.set_body(body);
		notification.set_priority(priority);
		if(config != null)
		{
			notification = config(notification);
		}
		GameHub.Application.instance.send_notification(null, notification);
	}

	private const string NAME_CHARS_TO_STRIP = "!@#$%^&*()-_+=:~`;?'\"<>,./\\|’“”„«»™℠®©";
	public static string strip_name(string name, string? keep=null, bool move_the=false)
	{
		if(name == null) return name;
		var n = name.strip();
		if(n.length == 0) return n;
		if(move_the && n.down().has_prefix("the "))
		{
			n = n.substring(4) + ", The";
		}
		unichar c;
		for(int i = 0; NAME_CHARS_TO_STRIP.get_next_char(ref i, out c);)
		{
			if(keep != null && keep != "")
			{
				unichar k;
				for(int j = 0; keep.get_next_char(ref j, out k);)
				{
					if(k == c) break;
				}
				if(k == c) continue;
			}
			n = n.replace(c.to_string(), "");
		}
		try
		{
			n = new Regex(" {2,}").replace(n, n.length, 0, " ");
		}
		catch(Error e){}
		return n.strip();
	}

	public static string? replace_prefix(string? str, string? prefix, string replacement)
	{
		if(str == null || prefix == null || !str.has_prefix(prefix))
		{
			return str;
		}
		return replacement + str.substring(str.index_of_nth_char(prefix.length));
	}

	public static int? compare_versions(int[]? v1, int[]? v2)
	{
		if(v1 == null || v2 == null || v1.length == 0 || v2.length == 0) return null;

		for(int i = 0; i < int.min(v1.length, v2.length); i++)
		{
			if(v1[i] > v2[i]) return 1;
			if(v1[i] < v2[i]) return -1;
		}

		if(v1.length > v2.length) return 1;
		if(v1.length < v2.length) return -1;

		return 0;
	}

	public static int[]? parse_version(string? version, string delimiter=".")
	{
		if(version == null || version.strip().length == 0) return null;
		int[] ver = {};
		var parts = version.split(delimiter);
		foreach(var part in parts)
		{
			ver += int.parse(part);
		}
		return ver;
	}

	public static string? format_version(int[]? version, string delimiter=".")
	{
		if(version == null || version.length == 0) return null;
		string[] ver = {};
		foreach(var part in version)
		{
			ver += part.to_string();
		}
		return string.joinv(delimiter, ver);
	}

	public static void set_accel_tooltip(Widget widget, string tooltip, string accel)
	{
		widget.tooltip_markup = Granite.markup_accel_tooltip({ accel }, tooltip);
	}

	private static string? distro;

	public class Logger: Granite.Services.Logger
	{
		public enum ConsoleColor
		{
			BLACK,
			RED,
			GREEN,
			YELLOW,
			BLUE,
			MAGENTA,
			CYAN,
			WHITE
		}

		const string[] LOG_LEVEL_TO_STRING = {
			"[DEBUG]\x001b[0m ",
			"[INFO]\x001b[0m  ",
			"[NOTIFY]\x001b[0m",
			"[WARN]\x001b[0m  ",
			"[ERROR]\x001b[0m ",
			"[FATAL]\x001b[0m "
		};

		static Mutex write_mutex;

		static Regex msg_file_regex;
		static Regex msg_string_regex;
		static Regex msg_block_regex;

		public static new void initialize(string app_name)
		{
			Granite.Services.Logger.initialize(app_name);
			try
			{
				msg_file_regex = new Regex("^.*\\.vala:\\d+: ");
				msg_string_regex = new Regex("(['\"`].*?['\"`])");
				msg_block_regex = new Regex("^(\\[.*?\\])");
			}
			catch(Error e){}
			Log.set_default_handler((LogFunc) glib_log_func);
		}

		static void write(Granite.Services.LogLevel level, owned string msg)
		{
			if(level < DisplayLevel) return;

			write_mutex.lock();
			set_color_for_level(level);
			stdout.printf(LOG_LEVEL_TO_STRING[level]);

			reset_color();
			stdout.printf(" %s\n", msg);

			write_mutex.unlock();
		}

		static void set_color_for_level(Granite.Services.LogLevel level)
		{
			switch(level)
			{
				case Granite.Services.LogLevel.DEBUG:
					set_foreground(ConsoleColor.GREEN);
					break;
				case Granite.Services.LogLevel.INFO:
					set_foreground(ConsoleColor.BLUE);
					break;
				case Granite.Services.LogLevel.NOTIFY:
					set_foreground(ConsoleColor.MAGENTA);
					break;
				case Granite.Services.LogLevel.WARN:
					set_foreground(ConsoleColor.YELLOW);
					break;
				case Granite.Services.LogLevel.ERROR:
					set_foreground(ConsoleColor.RED);
					break;
				case Granite.Services.LogLevel.FATAL:
					set_background(ConsoleColor.RED);
					set_foreground(ConsoleColor.WHITE);
					break;
			}
		}

		static void reset_color()
		{
			stdout.printf("\x001b[0m");
		}

		static void set_foreground(ConsoleColor color)
		{
			set_color(color, true);
		}

		static void set_background(ConsoleColor color)
		{
			set_color(color, false);
		}

		private static string color(ConsoleColor c, bool foreground)
		{
			var color_code = c + 30 + 60;
			if(!foreground) color_code += 10;
			return "\x001b[%dm".printf(color_code);
		}

		static void set_color(ConsoleColor c, bool foreground)
		{
			stdout.printf(color(c, foreground));
		}

		private static new void glib_log_func(string? d, LogLevelFlags flags, string msg)
		{
			glib_log_func_granite(d, flags, msg);
		}

		private static void glib_log_func_granite(string? d, LogLevelFlags flags, string msg)
		{
			string domain;
			if(d != null)
				domain = "[%s] ".printf(d);
			else
				domain = "";

			var message = "%s%s".printf(domain, msg.strip());

			try
			{
				message = msg_file_regex.replace_literal(message, -1, 0, "");
				message = msg_string_regex.replace(message, -1, 0, color(ConsoleColor.WHITE, true) + "\\1\x001b[0m");
				message = msg_block_regex.replace(message, -1, 0, color(ConsoleColor.BLACK, true) + "\\1\x001b[0m");
			}
			catch(Error e){}

			Granite.Services.LogLevel level;

			// Strip internal flags to make it possible to use a switch statement
			flags = (flags & LogLevelFlags.LEVEL_MASK);

			switch(flags)
			{
				case LogLevelFlags.LEVEL_CRITICAL:
					level = Granite.Services.LogLevel.FATAL;
					break;

				case LogLevelFlags.LEVEL_ERROR:
					level = Granite.Services.LogLevel.ERROR;
					break;

				case LogLevelFlags.LEVEL_INFO:
				case LogLevelFlags.LEVEL_MESSAGE:
					level = Granite.Services.LogLevel.INFO;
					break;

				case LogLevelFlags.LEVEL_DEBUG:
					level = Granite.Services.LogLevel.DEBUG;
					break;

				case LogLevelFlags.LEVEL_WARNING:
				default:
					level = Granite.Services.LogLevel.WARN;
					break;
			}

			write(level, message);
		}
	}
}

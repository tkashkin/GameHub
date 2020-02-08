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

using GameHub.Data;
using GameHub.Data.Tweaks;

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
			warning("[Utils.open_uri] Error while opening '%s': %s", uri, e.message);
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

	public class RunTask
	{
		private string[] _cmd;
		private string? _dir = null;
		private string[]? _env = null;
		private bool _override_runtime = false;
		private bool _log = true;
		private Tweak[]? _tweaks = null;

		public RunTask(string[] cmd) { _cmd = cmd; }

		public RunTask cmd(string[] cmd) { _cmd = cmd; return this; }
		public RunTask dir(string? dir=null) { _dir = dir; return this; }
		public RunTask env(string[]? env=null) { _env = env; return this; }
		public RunTask override_runtime(bool override_runtime=false) { _override_runtime = override_runtime; return this; }
		public RunTask log(bool log=true) { _log = log; return this; }
		public RunTask tweaks(Tweak[]? tweaks=null) { _tweaks = tweaks; return this; }

		private bool _expanded = false;
		private void expand()
		{
			if(_expanded) return;
			_expanded = true;

			var cmd_expanded = false;

			if(_log) debug("[RunTask] {'%s'}", string.joinv("' '", _cmd));

			_dir = _dir ?? Environment.get_home_dir();
			_env = _env ?? Environ.get();

			#if PKG_APPIMAGE
			_env = Environ.unset_variable(_env, "LD_LIBRARY_PATH");
			_env = Environ.unset_variable(_env, "LD_PRELOAD");
			#endif

			if(_tweaks != null)
			{
				foreach(var tweak in _tweaks)
				{
					if(tweak.env != null)
					{
						foreach(var env_var in tweak.env.entries)
						{
							if(env_var.value != null)
							{
								_env = Environ.set_variable(_env, env_var.key, env_var.value);
							}
							else
							{
								_env = Environ.unset_variable(_env, env_var.key);
							}
						}
					}

					if(tweak.command != null && tweak.command.length > 0)
					{
						string[] tweaked_cmd = _cmd;
						var tweak_cmd = Utils.parse_args(tweak.command);
						if(tweak_cmd != null)
						{
							if("$command" in tweak_cmd || "${command}" in tweak_cmd)
							{
								tweaked_cmd = {};
							}
							foreach(var arg in tweak_cmd)
							{
								if(arg == "$command" || arg == "${command}")
								{
									foreach(var a in _cmd)
									{
										tweaked_cmd += a;
									}
								}
								else
								{
									tweaked_cmd += arg;
								}
							}
							cmd_expanded = true;
						}
						_cmd = tweaked_cmd;
					}
				}
			}

			#if PKG_FLATPAK
			if(_override_runtime && ProjectConfig.RUNTIME.length > 0)
			{
				_env = Environ.set_variable(_env, "LD_LIBRARY_PATH", ProjectConfig.RUNTIME);
			}
			string[] cmd = { "flatpak-spawn", "--host" };
			foreach(var arg in _cmd)
			{
				cmd += arg;
			}
			_cmd = cmd;
			cmd_expanded = true;
			#endif

			if(_log && GameHub.Application.log_verbose)
			{
				if(cmd_expanded) debug("     cmd: {'%s'}", string.joinv("' '", _cmd));
				debug("     dir: '%s'", _dir);

				string[] env_diff = {};
				string[] env_clean = Environ.get();
				foreach(var env_var in _env)
				{
					if(!(env_var in env_clean))
					{
						env_diff += env_var;
					}
				}
				if(env_diff.length > 0)
				{
					debug("     env: {\n                  '%s'\n              }", string.joinv("'\n                  '", env_diff));
				}
			}

		}

		public Result? run_sync(bool capture_output=false)
		{
			var is_called_from_thread = _expanded;
			expand();
			try
			{
				if(_log && !is_called_from_thread) debug("     .run_sync()");
				int status;
				if(capture_output)
				{
					string sout;
					string serr;
					Process.spawn_sync(_dir, _cmd, _env, SpawnFlags.SEARCH_PATH, null, out sout, out serr, out status);
					sout = sout.strip();
					serr = serr.strip();
					if(_log)
					{
						if(sout.length > 0) print(sout + "\n");
						if(serr.length > 0) warning(serr);
					}
					return new Result(status, sout, serr);
				}
				else
				{
					Process.spawn_sync(_dir, _cmd, _env, SpawnFlags.SEARCH_PATH | SpawnFlags.CHILD_INHERITS_STDIN | SpawnFlags.STDERR_TO_DEV_NULL, null, null, null, out status);
					return new Result(status);
				}
			}
			catch (Error e)
			{
				warning("[RunTask.run_sync] %s", e.message);
			}
			return null;
		}

		public async Result? run_sync_thread(bool capture_output=false)
		{
			expand();
			Result? result = null;
			Utils.thread("RunTask.run_sync_thread", () => {
				if(_log) debug("     .run_sync_thread()");
				result = run_sync(capture_output);
				Idle.add(run_sync_thread.callback);
			}, _log);
			yield;
			return result;
		}

		public async Result? run_async(bool wait=true)
		{
			expand();
			Result? result = null;
			try
			{
				if(_log) debug("     .run_async()");
				Pid pid;
				Process.spawn_async(_dir, _cmd, _env, SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD, null, out pid);
				ChildWatch.add(pid, (pid, status) => {
					Process.close_pid(pid);
					result = new Result(status);
					Idle.add(run_async.callback);
				});
			}
			catch (Error e)
			{
				warning("[RunTask.run_async] %s", e.message);
			}
			if(wait) yield;
			return result;
		}

		public class Result
		{
			public int? status;
			public int? exit_code;
			public string? output;
			public string? errors;

			public Result(int? status, string? output=null, string? errors=null)
			{
				this.status = status;
				this.output = output;
				this.errors = errors;
				if(this.status != null)
				{
					this.exit_code = Process.exit_status(this.status);
				}
			}

			public bool check_status() throws Error
			{
				if(this.status != null)
				{
					return Process.check_exit_status(this.status);
				}
				return true;
			}
		}
	}

	public static RunTask run(string[] cmd)
	{
		return new RunTask(cmd);
	}

	public static File? find_executable(string? name)
	{
		if(name == null || name.length == 0) return null;
		var which = Environment.find_program_in_path(name) ?? run({"which", name}).log(false).run_sync(true).output;
		if(which == null || which.length == 0 || !which.has_prefix("/"))
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

		#if OS_LINUX
			distro = Utils.run({"bash", "-c", "lsb_release -ds 2>/dev/null || cat /etc/*release 2>/dev/null | head -n1 || uname -om"}).log(false).run_sync(true).output.replace("\"", "");
			#if PKG_APPIMAGE
				distro = "[AppImage] " + distro;
			#elif PKG_FLATPAK
				distro = "[Flatpak] " + distro;
			#endif
		#elif OS_WINDOWS
			distro = "Windows " + win32_get_os_version();
		#elif OS_MACOS
			distro = "macOS";
		#else
			distro = "unknown";
		#endif

		return distro;
	}

	#if OS_WINDOWS
	private struct win32_OSVERSIONINFOW
	{
		uint size;
		uint major;
		uint minor;
		uint build;
		uint platform;
		uint16 sp_version[128];
	}
	[CCode(cname="RtlGetVersion")]
	private static extern uint32 win32_rtl_get_version(out win32_OSVERSIONINFOW ver);
	public static string? win32_get_os_version()
	{
		win32_OSVERSIONINFOW ver = new win32_OSVERSIONINFOW();
		ver.size = (uint) sizeof(win32_OSVERSIONINFOW);
		win32_rtl_get_version(out ver);
		var result = "%u.%u.%u".printf(ver.major, ver.minor, ver.build);
		if(ver.sp_version[0] != 0)
		{
			result += " " + ((string) ver.sp_version);
		}
		return result;
	}
	#endif

	public static string? get_desktop_environment()
	{
		return Environment.get_variable("XDG_CURRENT_DESKTOP");
	}

	public static string get_language_name()
	{
		#if OS_LINUX
		return Posix.nl_langinfo((Posix.NLItem) 786439); // _NL_IDENTIFICATION_LANGUAGE
		#else
		return "English";
		#endif
	}

	public static bool is_package_installed(string package)
	{
		#if PKG_APPIMAGE || PKG_FLATPAK
		return false;
		#elif PM_APT
		var output = Utils.run({"dpkg-query", "-W", "-f=${Status}", package}).log(false).run_sync(true).output;
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
		return date_time.format("%x %R");
	}

	private string minutes_to_string(int64 min)
	{
		int h = (int) min / 60;
		int m = (int) min - (h * 60);
		return (h > 0 ? C_("time", "%dh").printf(h) + " " : "") + C_("time", "%dm").printf(m);
	}

	private string seconds_to_string(int64 sec)
	{
		int h = (int) sec / 3600;
		int m = (int) (sec - (h * 3600)) / 60;
		int s = (int) sec - (h * 3600) - (m * 60);
		return (h > 0 ? C_("time", "%dh").printf(h) + " " : "") + (m > 0 ? C_("time", "%dm").printf(m) + " " : "") + C_("time", "%ds").printf(s);
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

	public static string accel_to_string(string accel)
	{
		uint accel_key;
		Gdk.ModifierType accel_mods;
		Gtk.accelerator_parse(accel, out accel_key, out accel_mods);

		string[] arr = {};
		if(Gdk.ModifierType.SUPER_MASK in accel_mods)   arr += "Super";
		if(Gdk.ModifierType.SHIFT_MASK in accel_mods)   arr += "Shift";
		if(Gdk.ModifierType.CONTROL_MASK in accel_mods) arr += "Ctrl";
		if(Gdk.ModifierType.MOD1_MASK in accel_mods)    arr += "Alt";

		switch(accel_key)
		{
			case Gdk.Key.Up:
				arr += "↑";
				break;
			case Gdk.Key.Down:
				arr += "↓";
				break;
			case Gdk.Key.Left:
				arr += "←";
				break;
			case Gdk.Key.Right:
				arr += "→";
				break;
			case Gdk.Key.Return:
				arr += "Enter";
				break;
			default:
				arr += Gtk.accelerator_get_label(accel_key, 0);
				break;
		}
		return string.joinv(" + ", arr);
	}

	public static string markup_accel_tooltip(string[]? accels, string? description=null)
	{
		string[] parts = {};
		if(description != null && description != "")
		{
			parts += description;
		}
		if(accels != null && accels.length > 0)
		{
			string[] unique_accels = {};
			for(int i = 0; i < accels.length; i++)
			{
				if(accels[i] == "") continue;
				var accel_string = accel_to_string(accels[i]);
				if(!(accel_string in unique_accels))
					unique_accels += accel_string;
			}
			if(unique_accels.length > 0)
			{
				var accel_label = string.joinv(", ", unique_accels);
				var accel_markup = """<span weight="600" size="smaller" alpha="75%">%s</span>""".printf (accel_label);
				parts += accel_markup;
			}
		}
		return string.joinv("\n", parts);
	}

	public static void set_accel_tooltip(Widget widget, string tooltip, string accel)
	{
		widget.tooltip_markup = markup_accel_tooltip({ accel }, tooltip);
	}

	private static string? distro;

	/* Based on Granite.Services.Logger */
	public class Logger: Object
	{
		public enum LogLevel { DEBUG, INFO, NOTIFY, WARN, ERROR, FATAL }
		public enum ConsoleColor { BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, WHITE }

		public static LogLevel DisplayLevel { get; set; default = LogLevel.WARN; }

		private const string[] LOG_LEVEL_TO_STRING = {
			"[DEBUG]\x001b[0m ",
			"[INFO]\x001b[0m  ",
			"[NOTIFY]\x001b[0m",
			"[WARN]\x001b[0m  ",
			"[ERROR]\x001b[0m ",
			"[FATAL]\x001b[0m "
		};

		private const string[] HIDDEN_DOMAINS  = { "GLib", "GLib-GIO", "GdkPixbuf", "Manette" };
		private const string[] HIDDEN_MESSAGES = { "Loading settings from schema" };

		static Mutex write_mutex;

		static Regex msg_file_regex;
		static Regex msg_string_regex;
		static Regex msg_block_regex;

		public static void init()
		{
			try
			{
				msg_file_regex = new Regex("^.*\\.vala:\\d+: ");
				msg_string_regex = new Regex("(['\"`].*?['\"`])");
				msg_block_regex = new Regex("^(\\[.*?\\])");
			}
			catch(Error e){}
			Log.set_default_handler((LogFunc) glib_log_func);
		}

		static void write(LogLevel level, owned string msg)
		{
			if(level < DisplayLevel) return;

			write_mutex.lock();
			set_color_for_level(level);
			stdout.printf(LOG_LEVEL_TO_STRING[level]);

			reset_color();
			stdout.printf(" %s\n", msg);

			write_mutex.unlock();
		}

		static void set_color_for_level(LogLevel level)
		{
			switch(level)
			{
				case LogLevel.DEBUG:
					set_foreground(ConsoleColor.GREEN);
					break;
				case LogLevel.INFO:
					set_foreground(ConsoleColor.BLUE);
					break;
				case LogLevel.NOTIFY:
					set_foreground(ConsoleColor.MAGENTA);
					break;
				case LogLevel.WARN:
					set_foreground(ConsoleColor.YELLOW);
					break;
				case LogLevel.ERROR:
					set_foreground(ConsoleColor.RED);
					break;
				case LogLevel.FATAL:
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

		private static void glib_log_func(string? d, LogLevelFlags flags, string msg)
		{
			if(!log_filter(d, flags, msg)) return;

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

			LogLevel level;

			// Strip internal flags to make it possible to use a switch statement
			flags = (flags & LogLevelFlags.LEVEL_MASK);

			switch(flags)
			{
				case LogLevelFlags.LEVEL_CRITICAL:
					level = LogLevel.FATAL;
					break;

				case LogLevelFlags.LEVEL_ERROR:
					level = LogLevel.ERROR;
					break;

				case LogLevelFlags.LEVEL_INFO:
				case LogLevelFlags.LEVEL_MESSAGE:
					level = LogLevel.INFO;
					break;

				case LogLevelFlags.LEVEL_DEBUG:
					level = LogLevel.DEBUG;
					break;

				case LogLevelFlags.LEVEL_WARNING:
				default:
					level = LogLevel.WARN;
					break;
			}

			write(level, message);
		}

		private static bool log_filter(string? d, LogLevelFlags flags, string msg)
		{
			if(!GameHub.Application.log_no_filters)
			{
				if(d == "GLib-GIO" && msg.has_prefix("Settings schema '")) return true;
				if(d in HIDDEN_DOMAINS) return false;
				foreach(var hidden_msg in HIDDEN_MESSAGES)
				{
					if(hidden_msg in msg) return false;
				}
			}
			return true;
		}
	}
}

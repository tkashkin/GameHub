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

using Gtk;
using Granite;

namespace GameHub.Utils
{
	public delegate void Future();
	public delegate void FutureBoolean(bool result);
	public delegate void FutureResult<T>(T result);
	public delegate void FutureResult2<T, T2>(T t, T2 t2);

	private class Worker
	{
		public string name;
		public Future worker;
		public Worker(string name, owned Future worker)
		{
			this.name = name;
			this.worker = (owned) worker;
		}
		public void run()
		{
			bool dbg = !name.has_prefix("Merging-");
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

	public static string run(string[] cmd, string? dir=null, string[]? env=null, bool override_runtime=false, bool log=true)
	{
		string stdout;

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
			Process.spawn_sync(cdir, ccmd, cenv, SpawnFlags.SEARCH_PATH, null, out stdout);
			stdout = stdout.strip();
			if(log && stdout.length > 0) print(stdout + "\n");
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
			Process.spawn_async(cdir, ccmd, cenv, SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL | SpawnFlags.DO_NOT_REAP_CHILD, null, out pid);

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

	public static async string run_thread(string[] cmd, string? dir=null, string[]? env=null, bool override_runtime=false, bool log=true)
	{
		string stdout = "";

		Utils.thread("Utils.run_thread", () => {
			stdout = Utils.run(cmd, dir, env, override_runtime, log);
			Idle.add(run_thread.callback);
		});

		yield;
		return stdout;
	}

	public static File? find_executable(string? name)
	{
		if(name == null || name.length == 0) return null;
		var which = run({"which", name});
		if(which.length == 0 || !which.has_prefix("/"))
		{
			return null;
		}
		return File.new_for_path(which);
	}

	public static void thread(string name, owned Future worker)
	{
		try
		{
			if(threadpool == null)
			{
				threadpool = new ThreadPool<Worker>.with_owned_data(w => w.run(), -1, false);
			}
			threadpool.add(new Worker(name, (owned) worker));
		}
		catch(Error e)
		{
			warning(e.message);
		}
	}

	public static string get_distro()
	{
		#if APPIMAGE
		return "appimage";
		#elif FLATPAK
		return "flatpak";
		#elif SNAP
		return "snap";
		#else
		if(distro != null) return distro;
		distro = Utils.run({"bash", "-c", "lsb_release -ds 2>/dev/null || cat /etc/*release 2>/dev/null | head -n1 || uname -om"});
		return distro;
		#endif
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
		var output = Utils.run({"dpkg-query", "-W", "-f=${Status}", package});
		return "install ok installed" in output;
		#else
		return false;
		#endif
	}

	public static async void sleep_async(uint interval, int priority = GLib.Priority.DEFAULT)
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

	public static async string? cache_image(string url, string prefix="remote")
	{
		if(url == null || url == "") return null;
		var parts = url.split("?")[0].split(".");
		var ext = parts.length > 1 ? parts[parts.length - 1] : null;
		ext = ext != null && ext.length <= 6 ? "." + ext : null;
		var hash = md5(url);
		var remote = File.new_for_uri(url);
		var cached = FSUtils.file(FSUtils.Paths.Cache.Images, @"$(prefix)_$(hash)$(ext)");
		try
		{
			if(!cached.query_exists())
			{
				yield Downloader.download(remote, cached, null, false);
			}
			return cached.get_path();
		}
		catch(IOError.EXISTS e){}
		catch(Error e)
		{
			warning("Error caching `%s` in `%s`: %s", url, cached.get_path(), e.message);
		}
		return null;
	}

	public static async void load_image(GameHub.UI.Widgets.AutoSizeImage image, string url, string prefix="remote")
	{
		var cached = yield cache_image(url, prefix);
		try
		{
			image.set_source(cached != null ? new Gdk.Pixbuf.from_file(cached) : null);
		}
		catch(Error e){}
		image.queue_draw();
	}

	private const string NAME_CHARS_TO_STRIP = "!@#$%^&*()-_+=:~`;?'\"<>,./\\|’“”„«»™℠®©";
	public static string strip_name(string name, string? keep=null)
	{
		if(name == null) return name;
		var n = name.strip();
		if(n == "") return n;
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

	private static string? distro;
}

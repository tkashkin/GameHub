using Gtk;
using Granite;

namespace GameHub.Utils
{
	public delegate void Future();
	public delegate void FutureBoolean(bool result);
	public delegate void FutureResult<T>(T result);
	
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
	
	public static string run(string[] cmd, string? dir=null, bool override_runtime=false)
	{
		string stdout;

		var cdir = dir ?? Environment.get_home_dir();
		var cenv = Environ.get();
		var ccmd = cmd;

		#if FLATPAK
		if(override_runtime && ProjectConfig.RUNTIME.length > 0)
		{
			cenv = Environ.set_variable(cenv, "LD_LIBRARY_PATH", ProjectConfig.RUNTIME);
		}
		#endif

		try
		{
			Process.spawn_sync(cdir, ccmd, cenv, SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL, null, out stdout);
		}
		catch (Error e)
		{
			warning(e.message);
		}
		return stdout;
	}
	
	public static async void run_async(string[] cmd, string? dir=null, bool override_runtime=false, bool wait=true)
	{
		Pid pid;

		var cdir = dir ?? Environment.get_home_dir();
		var cenv = Environ.get();
		var ccmd = cmd;
		var cwait = wait;

		#if FLATPAK
		if(override_runtime && ProjectConfig.RUNTIME.length > 0)
		{
			cenv = Environ.set_variable(cenv, "LD_LIBRARY_PATH", ProjectConfig.RUNTIME);
		}
		#endif

		try
		{
			Process.spawn_async(cdir, ccmd, cenv, SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL | SpawnFlags.DO_NOT_REAP_CHILD, null, out pid);

			ChildWatch.add(pid, (pid, status) => {
				Process.close_pid(pid);
				Idle.add(run_async.callback);
			});
		}
		catch (Error e)
		{
			warning(e.message);
		}

		if(cwait) yield;
	}

	public static async string run_thread(string[] cmd, string? dir=null, bool override_runtime=false)
	{
		string stdout = "";

		new Thread<void*>("utils-run_thread", () => {
			stdout = Utils.run(cmd, dir, override_runtime);
			Idle.add(run_thread.callback);
			return null;
		});

		yield;
		return stdout;
	}

	public static string get_distro()
	{
		#if FLATPAK
		return "flatpak";
		#else
		return Utils.run({"bash", "-c", "lsb_release -ds 2>/dev/null || cat /etc/*release 2>/dev/null | head -n1 || uname -om"});
		#endif
	}
	
	public static string get_language_name()
	{
		return Posix.nl_langinfo((Posix.NLItem) 786439); // _NL_IDENTIFICATION_LANGUAGE
	}

	public static bool is_package_installed(string package)
	{
		#if FLATPAK || SNAP
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
				if(k == c) break;
			}
			n = n.replace(c.to_string(), "");
		}
		return new Regex(" {2,}").replace(n, n.length, 0, " ").strip();
	}
}

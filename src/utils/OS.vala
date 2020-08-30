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
using Gee;

using GameHub.Data;
using GameHub.Data.Tweaks;

namespace GameHub.Utils.OS
{
	private static string? distro = null;
	public static string get_distro()
	{
		if(distro != null) return distro;

		#if OS_LINUX
			distro = Utils.exec({"bash", "-c", "lsb_release -ds 2>/dev/null || cat /etc/*release 2>/dev/null | head -n1 || uname -om"}).log(false).sync(true).output.replace("\"", "");
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

	#if OS_LINUX

	public static string? get_desktop_environment()
	{
		return Environment.get_variable("XDG_CURRENT_DESKTOP");
	}

	public static bool is_package_installed(string package)
	{
		#if PKG_APPIMAGE || PKG_FLATPAK
		return false;
		#elif PM_APT
		var output = Utils.exec({"dpkg-query", "-W", "-f=${Status}", package}).log(false).sync(true).output;
		return "install ok installed" in output;
		#else
		return false;
		#endif
	}

	private static string[]? kmods = null;
	public static bool is_kernel_module_loaded(string? name)
	{
		if(name == null || name.length == 0) return true;
		if(kmods == null)
		{
			try
			{
				kmods = {};
				string proc_modules;
				FileUtils.get_contents("/proc/modules", out proc_modules);
				var module_lines = proc_modules.split("\n");
				foreach(var line in module_lines)
				{
					kmods += line.split(" ")[0];
				}
			}
			catch(Error e)
			{
				warning("[Utils.OS.is_kernel_module_loaded] Error while reading kernel modules list: %s", e.message);
			}
		}
		return name in kmods;
	}

	#elif OS_WINDOWS

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

	#if PKG_FLATPAK

	namespace Flatpak
	{
		public static bool is_app_path(string path)
		{
			return path.has_prefix("/app/");
		}

		public static bool is_host_path(string path)
		{
			return !is_app_path(path);
		}

		public static string get_sandbox_path(string path)
		{
			if(path.has_prefix("/usr/"))
			{
				// In the Flatpak environment /usr allows refers to the current runtime so search in /run/host/usr instead
				// This should be the only observable difference from using the standard `g_find_program_in_path` below
				return Path.build_filename("/run/host", path);
			}
			return path;
		}

		public static bool check_host_executable(string path)
		{
			// Reject paths not representable on the host
			if(is_app_path(path))
			{
				return false;
			}

			// Fixup path differences between Flatpak environment and host
			var sandbox_path = get_sandbox_path(path);
			return File.new_for_path(sandbox_path).query_exists();
		}

		/**
		 * An extended version of `Environment.find_program_in_path` that takes into
		 * account Flatpak-specific quirks needed when working with host paths from
		 * inside the Flatpak sandbox environment
		 */
		public static string? find_program_in_path(string name)
		{
			string? path = name;

			if(Path.is_absolute(path))
			{
				// Absolute paths: Directly check rather than doing a $PATH search
				if(check_host_executable(path))
				{
					return path;
				}
				return null;
			}
			else if(path.index_of(Path.DIR_SEPARATOR_S) > 0)
			{
				// Make relative paths (ie: paths that contain a slash but don't start with one) absolute
				path = Path.build_filename(Environment.get_current_dir(), name);
			}

			// Search for name in $PATH
			var searchpath = Environment.get_variable("PATH") ?? "/bin:/usr/bin:.";

			foreach(var dir in searchpath.split(Path.SEARCHPATH_SEPARATOR_S))
			{
				// Two adjacent colons, or a colon at the beginning or the end of $PATH means to search the current directory
				if(dir.length > 0)
				{
					path = Path.build_filename(dir, name);
				}

				if(check_host_executable(path))
				{
					return path;
				}
			}
			return null;
		}
	}

	#endif
}

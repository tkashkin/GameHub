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

using GameHub.Data;
using GameHub.Utils;

namespace GameHub.Data.Runnables.Tasks.Install
{
	public enum InstallerType
	{
		EXECUTABLE, WINDOWS_EXECUTABLE, ARCHIVE, WINDOWS_NSIS_INSTALLER, DATA;

		public string to_string()
		{
			switch(this)
			{
				case EXECUTABLE:             return "executable";
				case WINDOWS_EXECUTABLE:     return "windows_executable";
				case ARCHIVE:                return "archive";
				case WINDOWS_NSIS_INSTALLER: return "windows_nsis_installer";
				case DATA:                   return "data";
			}
			assert_not_reached();
		}

		public static InstallerType? from_mime(string? type)
		{
			if(type == null) return null;
			var t = type.strip().down();
			if(t.length == 0) return null;
			if(t in MIME_EXECUTABLE) return InstallerType.EXECUTABLE;
			if(t in MIME_WINDOWS_EXECUTABLE) return InstallerType.WINDOWS_EXECUTABLE;
			if(t in MIME_ARCHIVE) return InstallerType.ARCHIVE;
			return null;
		}

		public static async InstallerType? guess(File? file, bool can_be_data=false)
		{
			var type = yield guess_from_mime_or_extension(file, can_be_data);
			if(type == InstallerType.WINDOWS_EXECUTABLE)
			{
				var desc = Utils.exec({"file", "-b", file.get_path()}).log(false).sync(true).output;
				if(desc != null && DESC_NSIS_INSTALLER in desc)
				{
					return InstallerType.WINDOWS_NSIS_INSTALLER;
				}
			}
			return type;
		}

		private static async InstallerType? guess_from_mime_or_extension(File? file, bool can_be_data=false)
		{
			if(file == null || !file.query_exists()) return null;
			try
			{
				var finfo = yield file.query_info_async(FileAttribute.STANDARD_CONTENT_TYPE, FileQueryInfoFlags.NONE);
				var mime = finfo.get_content_type();
				var type = InstallerType.from_mime(mime);

				if(type != null) return type;

				var info = Utils.exec({"file", "-bi", file.get_path()}).log(false).sync(true).output;
				if(info != null)
				{
					mime = info.split(";")[0];
					if(mime != null)
					{
						type = InstallerType.from_mime(mime);
					}
				}

				if(type != null) return type;

				var filename = file.get_basename().down();

				if(can_be_data)
				{
					foreach(var ext in EXT_DATA)
					{
						if(filename.has_suffix(@".$(ext)")) return InstallerType.DATA;
					}
				}

				foreach(var ext in EXT_EXECUTABLE)
				{
					if(filename.has_suffix(@".$(ext)")) return InstallerType.EXECUTABLE;
				}
				foreach(var ext in EXT_WINDOWS_EXECUTABLE)
				{
					if(filename.has_suffix(@".$(ext)")) return InstallerType.WINDOWS_EXECUTABLE;
				}
				foreach(var ext in EXT_ARCHIVE)
				{
					if(filename.has_suffix(@".$(ext)")) return InstallerType.ARCHIVE;
				}
			}
			catch(Error e){}
			return null;
		}

		private const string[] EXT_EXECUTABLE = {"sh", "elf", "bin", "run"};
		private const string[] EXT_WINDOWS_EXECUTABLE = {"exe", "msi", "bat", "com"};
		private const string[] EXT_ARCHIVE = {"zip", "tar", "cpio", "bz2", "gz", "lz", "lzma", "7z", "rar"};
		private const string[] EXT_DATA = {"bin"};

		private const string[] MIME_EXECUTABLE = {
			"application/x-executable",
			"application/x-elf",
			"application/x-sh",
			"application/x-shellscript"
		};
		private const string[] MIME_WINDOWS_EXECUTABLE = {
			"application/x-dosexec",
			"application/x-ms-dos-executable",
			"application/dos-exe",
			"application/exe",
			"application/msdos-windows",
			"application/x-exe",
			"application/x-msdownload",
			"application/x-winexe",
			"application/x-msi"
		};
		private const string[] MIME_ARCHIVE = {
			"application/zip",
			"application/x-tar",
			"application/x-gtar",
			"application/x-cpio",
			"application/x-bzip2",
			"application/gzip",
			"application/x-lzip",
			"application/x-lzma",
			"application/x-7z-compressed",
			"application/x-rar-compressed",
			"application/x-compressed-tar"
		};

		private const string DESC_NSIS_INSTALLER = "Nullsoft Installer";
	}
}

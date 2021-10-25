/*
This file is part of GameHub.
Copyright (C) Anatoliy Kashkin

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

namespace GameHub.Data
{
	public enum Platform
	{
		LINUX, WINDOWS, MACOS, EMULATED;

		public const Platform[] PLATFORMS = { Platform.LINUX, Platform.WINDOWS, Platform.MACOS, Platform.EMULATED };

		#if OS_LINUX
		public const Platform CURRENT = Platform.LINUX;
		#elif OS_WINDOWS
		public const Platform CURRENT = Platform.WINDOWS;
		#elif OS_MACOS
		public const Platform CURRENT = Platform.MACOS;
		#endif

		public string id()
		{
			switch(this)
			{
				case Platform.LINUX:    return "linux";
				case Platform.WINDOWS:  return "windows";
				case Platform.MACOS:    return "mac";
				case Platform.EMULATED: return "emulated";
			}
			assert_not_reached();
		}

		public string name()
		{
			switch(this)
			{
				case Platform.LINUX:    return "Linux";
				case Platform.WINDOWS:  return "Windows";
				case Platform.MACOS:    return "macOS";
				case Platform.EMULATED: return C_("platform", "Emulated");
			}
			assert_not_reached();
		}

		public string icon()
		{
			switch(this)
			{
				case Platform.LINUX:    return "platform-linux-symbolic";
				case Platform.WINDOWS:  return "platform-windows-symbolic";
				case Platform.MACOS:    return "platform-macos-symbolic";
				case Platform.EMULATED: return "gamehub-symbolic";
			}
			assert_not_reached();
		}
	}
}

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

namespace GameHub.Utils
{
	public class Inhibitor
	{
		private static DBusFreeDesktopScreenSaver? fd_screensaver = null;

		private static uint32? fd_screensaver_inhibit_id = null;
		private static uint? gtk_inhibit_id = null;

		private static void dbus_connect()
		{
			if(fd_screensaver != null) return;
			try
			{
				fd_screensaver = Bus.get_proxy_sync(BusType.SESSION, "org.freedesktop.ScreenSaver", "/ScreenSaver", DBusProxyFlags.NONE);
			}
			catch(Error e)
			{
				warning("[ScreenSaver.dbus_connect] Failed to connect to DBus: %s", e.message);
			}
		}

		public static void inhibit(string? reason = null)
		{
			if(!GameHub.Settings.UI.Behavior.instance.inhibit_screensaver) return;
			reason = reason ?? _("Game is running");
			if(fd_screensaver_inhibit_id == null)
			{
				dbus_connect();
				if(fd_screensaver != null)
				{
					try
					{
						fd_screensaver_inhibit_id = fd_screensaver.inhibit("GameHub", reason);
					}
					catch(Error e)
					{
						warning("[ScreenSaver.inhibit] Failed to inhibit screensaver via DBus: %s", e.message);
					}
				}
			}
			if(gtk_inhibit_id == null)
			{
				gtk_inhibit_id = GameHub.Application.instance.inhibit(GameHub.Application.instance.active_window, ApplicationInhibitFlags.IDLE | ApplicationInhibitFlags.SUSPEND, reason);
			}
		}

		public static void uninhibit()
		{
			if(fd_screensaver_inhibit_id != null)
			{
				dbus_connect();
				if(fd_screensaver != null)
				{
					try
					{
						fd_screensaver.un_inhibit(fd_screensaver_inhibit_id);
						fd_screensaver_inhibit_id = null;
					}
					catch(Error e)
					{
						warning("[ScreenSaver.uninhibit] Failed to uninhibit screensaver via DBus: %s", e.message);
					}
				}
			}
			if(gtk_inhibit_id != null)
			{
				GameHub.Application.instance.uninhibit(gtk_inhibit_id);
				gtk_inhibit_id = null;
			}
		}

		[DBus(name = "org.freedesktop.ScreenSaver")]
		private interface DBusFreeDesktopScreenSaver: Object
		{
			public abstract uint32 inhibit(string app_name, string reason) throws Error;
			public abstract void un_inhibit(uint32 cookie) throws Error;
		}
	}
}

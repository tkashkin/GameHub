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

using Gdk;
using Gee;

namespace GameHub.Utils
{
	public class ImageCache
	{
		public static string DEFAULT_CACHED_FILE_PREFIX = "remote";
		private static HashMap<string, Pixbuf?> cache;

		public static File? local_file(string? url, string prefix=DEFAULT_CACHED_FILE_PREFIX)
		{
			if(url == null || url == "") return null;
			var parts = url.split("?")[0].split(".");
			var ext = parts.length > 1 ? parts[parts.length - 1] : null;
			ext = ext != null && ext.length <= 6 ? "." + ext : null;
			var hash = md5(url);
			return FSUtils.file(FSUtils.Paths.Cache.Images, @"$(prefix)_$(hash)$(ext)");;
		}

		public static async string? cache_image(string? url, string prefix=DEFAULT_CACHED_FILE_PREFIX)
		{
			if(url == null || url == "") return null;
			var remote = File.new_for_uri(url);
			var cached = local_file(url, prefix);
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
				if(GameHub.Application.log_verbose)
				{
					warning("[ImageCache] Error loading image '%s': %s", url, e.message);
				}
			}
			return null;
		}

		public static async Pixbuf? load(string? url, string prefix=DEFAULT_CACHED_FILE_PREFIX)
		{
			if(url == null || url == "") return null;

			if(cache.has_key(url)) return cache.get(url);

			var cached = yield cache_image(url, prefix);
			try
			{
				var pixbuf = cached != null ? new Pixbuf.from_file(cached) : null;
				cache.set(url, pixbuf);
				return pixbuf;
			}
			catch(Error e){}

			return null;
		}

		public static void init()
		{
			cache = new HashMap<string, Pixbuf?>();
		}
	}
}

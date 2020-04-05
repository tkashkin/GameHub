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

using Gee;
using GameHub.Utils;

namespace GameHub.Data.Providers.Images
{
	public class Steam: ImagesProvider
	{
		private const string DOMAIN       = "https://store.steampowered.com/";
		private const string CDN_BASE_URL = "http://cdn.akamai.steamstatic.com/steam/apps/";

		private ImagesProvider.ImageSize?[] SIZES = { ImageSize(460, 215), ImageSize(600, 900) };

		public override string id   { get { return "steam"; } }
		public override string name { get { return "Steam"; } }
		public override string url  { get { return DOMAIN; } }
		public override string icon { get { return "source-steam-symbolic"; } }

		public override bool enabled
		{
			get { return Settings.Providers.Images.Steam.instance.enabled; }
			set { Settings.Providers.Images.Steam.instance.enabled = value; }
		}

		public override async ArrayList<ImagesProvider.Result> images(Game game)
		{
			var results = new ArrayList<ImagesProvider.Result>();
			string? appid = null;

			if(game is GameHub.Data.Sources.Steam.SteamGame)
			{
				appid = game.id;
			}
			else
			{
				appid = yield GameHub.Data.Sources.Steam.Steam.get_appid_from_name(game.name);
			}

			if(appid != null)
			{
				debug("[Provider.Images.Steam] Found appid %s for game %s", appid, game.name);
				foreach(var size in SIZES)
				{
					var needs_check = false;
					var exists = false;
					var result = new ImagesProvider.Result();
					result.image_size = size ?? ImageSize(460, 215);
					result.name = "%s: %s (%d × %d)".printf(name, game.name, result.image_size.width, result.image_size.height);
					result.url = "%sapp/%s".printf(DOMAIN, appid);

					var format = "header.jpg";
					switch (size.width) {
					case 460:
						// Always enforced by steam, exists for everything
						format = "header.jpg";
						exists = true;
						break;
					//  case 920:
						// Higher resolution of the one above at the same location
						//  format = "header.jpg";
						//  break;
					case 600:
						// Enforced since 2019, possibly not available
						format = "library_600x900_2x.jpg";
						needs_check = true;
						break;
					}

					var endpoint = "%s/%s".printf(appid, format);

					result.images = new ArrayList<ImagesProvider.Image>();

					if(needs_check)
					{
						exists = yield image_exists("%s%s".printf(CDN_BASE_URL, endpoint));
					}

					if(exists)
					{
						result.images.add(new Image("%s%s".printf(CDN_BASE_URL, endpoint)));
					}

					if(result.images.size > 0)
					{
						results.add(result);
					}
				}
			}

			return results;
		}

		private async bool image_exists(string url)
		{
			uint status;
			yield Parser.load_remote_file_async(url, "GET", null, null, null, out status);
			if(status == 200)
			{
				return true;
			}
			return false;
		}
	}
}

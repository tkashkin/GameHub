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

namespace GameHub.Data.Providers
{
	public abstract class ImagesProvider: Provider
	{
		public override string icon { get { return "image-x-generic-symbolic"; } }

		public override bool enabled
		{
			get { return !(id in Settings.Providers.Images.get_instance().disabled); }
			set
			{
				var disabled = Settings.Providers.Images.get_instance().disabled;
				if(value && id in disabled)
				{
					string[] new_disabled = {};
					foreach(var p in disabled)
					{
						if(p != id) new_disabled += p;
					}
					Settings.Providers.Images.get_instance().disabled = new_disabled;
				}
				else if(!value && !(id in disabled))
				{
					disabled += id;
					Settings.Providers.Images.get_instance().disabled = disabled;
				}
			}
		}

		public abstract async Result images(Game game);

		public class Result: Object
		{
			public ArrayList<Image>? images { get; set; default = null; }
			public string?           url    { get; set; default = null; }
		}

		public class Image: Object
		{
			public string  url         { get; protected construct set; }
			public string? description { get; protected construct set; default = null; }

			public Image(string url, string? description=null)
			{
				Object(url: url, description: description);
			}
		}
	}

	public static ImagesProvider[] ImageProviders;
}

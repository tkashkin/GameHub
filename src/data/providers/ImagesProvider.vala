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

using Gee;

using GameHub.Data.Runnables;
using GameHub.Utils;

namespace GameHub.Data.Providers
{
	public abstract class ImagesProvider: Provider
	{
		public override string icon { get { return "image-x-generic"; } }

		public abstract async ArrayList<Result> images(Game game);

		public abstract class Result: Object
		{
			public ImagesProvider provider   { get; set; }
			public string?        name       { get; set; default = null; }
			public string?        title      { get; set; default = null; }
			public string?        subtitle   { get; set; default = null; }
			public string?        url        { get; set; default = null; }
			public ImageSize      image_size { get; set; default = ImageSize(460, 215); }

			public abstract async ArrayList<Image>? load_images();
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

		public struct ImageSize
		{
			public int width;
			public int height;

			public ImageSize(int w, int h)
			{
				width = w;
				height = h;
			}
		}
	}

	public static ImagesProvider[] ImageProviders;
}

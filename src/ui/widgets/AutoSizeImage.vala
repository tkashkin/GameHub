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
using Gdk;
using GameHub.Utils;

namespace GameHub.UI.Widgets
{
	public class AutoSizeImage: DrawingArea
	{
		private Pixbuf? src;

		private int cmin = 0;
		private int cmax = 0;
		private float ratio = 1;
		private Orientation constraint = Orientation.HORIZONTAL;

		public int corner_radius = 4;

		public void set_constraint(int min, int max, float ratio = 1, Orientation orientation = Orientation.HORIZONTAL)
		{
			this.constraint = orientation;
			this.ratio = ratio;
			this.cmin = min;
			this.cmax = max;
			switch(constraint)
			{
				case Orientation.HORIZONTAL:
					set_size_request(cmin, (int) (cmin * ratio));
					break;

				case Orientation.VERTICAL:
					set_size_request((int) (cmin / ratio), cmin);
					break;
			}
		}

		public void set_source(Pixbuf? buf)
		{
			src = buf;
			queue_draw();
		}

		public void load(string? url, string cache_prefix=ImageCache.DEFAULT_CACHED_FILE_PREFIX)
		{
			if(url == null || url == "")
			{
				set_source(null);
				return;
			}
			ImageCache.load.begin(url, cache_prefix, (obj, res) => {
				set_source(ImageCache.load.end(res));
			});
		}

		public override SizeRequestMode get_request_mode()
		{
			switch(constraint)
			{
				case Orientation.HORIZONTAL: return SizeRequestMode.HEIGHT_FOR_WIDTH;
				case Orientation.VERTICAL: return SizeRequestMode.WIDTH_FOR_HEIGHT;
				default: return SizeRequestMode.CONSTANT_SIZE;
			}
		}

		public override void get_preferred_width_for_height(int height, out int minimum_width, out int natural_width)
		{
			if(constraint == Orientation.VERTICAL)
			{
				minimum_width = natural_width = (int) (height / ratio);
			}
			else
			{
				base.get_preferred_width_for_height(height, out minimum_width, out natural_width);
			}
		}

		public override void get_preferred_height_for_width(int width, out int minimum_height, out int natural_height)
		{
			if(constraint == Orientation.HORIZONTAL)
			{
				minimum_height = natural_height = (int) (width * ratio);
			}
			else
			{
				base.get_preferred_height_for_width(width, out minimum_height, out natural_height);
			}
		}

		public override bool draw(Cairo.Context ctx)
		{
			ctx.scale(1.0 / scale_factor, 1.0 / scale_factor);

			var width = get_allocated_width() * scale_factor;
			var height = get_allocated_height() * scale_factor;

			if(src != null)
			{
				Pixbuf pixbuf = src;

				if(src.width > cmin || src.height > cmin || src.width != src.height)
				{
					pixbuf = src.scale_simple(width, height, InterpType.BILINEAR);
				}
				Granite.Drawing.Utilities.cairo_rounded_rectangle(ctx, 0, 0, width, height, corner_radius * scale_factor);
				cairo_set_source_pixbuf(ctx, pixbuf, (width - pixbuf.width) / 2, (height - pixbuf.height) / 2);
				ctx.clip();
				ctx.paint();
			}

			return false;
		}
	}
}

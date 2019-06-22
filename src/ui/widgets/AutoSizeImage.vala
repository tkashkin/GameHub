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
		private Pixbuf? scaled;

		private int cmin = 0;
		private int cmax = 0;
		private float ratio = 1;
		private Orientation constraint = Orientation.HORIZONTAL;

		public bool? scale = null;
		private bool _scale = true;

		public int corner_radius = 4;

		public Pixbuf? source
		{
			get
			{
				return src;
			}
			set
			{
				src = value;
				scaled = src;
				if(src != null && src.width > 0 && src.height > 0)
				{
					_scale = scale ?? (src.width > cmin || src.height > cmin || src.width != src.height);
				}
				queue_draw();
			}
		}

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

		public void load(string? url, string cache_prefix=ImageCache.DEFAULT_CACHED_FILE_PREFIX)
		{
			if(url == null || url == "")
			{
				source = null;
				return;
			}
			ImageCache.load.begin(url, cache_prefix, (obj, res) => {
				source = ImageCache.load.end(res);
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

			if(src != null && src.width > 0 && src.height > 0)
			{
				if(_scale)
				{
					var ratio = float.min((float) width / src.width, (float) height / src.height);
					var new_width = (int) (src.width * ratio);
					var new_height = (int) (src.height * ratio);

					if(new_width < width)
					{
						new_height = (int) ((float) new_height / (float) new_width * (float) width);
						new_width = width;
					}

					if(new_height < height)
					{
						new_width = (int) ((float) new_width / (float) new_height * (float) height);
						new_height = height;
					}

					if(scaled.width != new_width || scaled.height != new_height)
					{
						scaled = src.scale_simple(new_width, new_height, InterpType.BILINEAR);
					}
				}

				var x = (width - scaled.width) / 2;
				var y = (height - scaled.height) / 2;

				Granite.Drawing.Utilities.cairo_rounded_rectangle(ctx, int.max(x, 0), int.max(y, 0), int.min(scaled.width, width), int.min(scaled.height, height), corner_radius * scale_factor);
				cairo_set_source_pixbuf(ctx, scaled, x, y);

				ctx.clip();
				ctx.paint();
			}

			return false;
		}
	}
}

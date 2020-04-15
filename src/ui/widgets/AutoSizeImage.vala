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
		private string? url;
		private string? url_vertical;
		private Pixbuf? src;
		private Pixbuf? src_vertical;
		private Pixbuf? scaled;
		private Pixbuf? scaled_vertical;
		private string cache_prefix = ImageCache.DEFAULT_CACHED_FILE_PREFIX;

		private int cmin = 0;
		private int cmax = 0;
		private float ratio = 1;
		private Orientation constraint = Orientation.HORIZONTAL;

		public bool? scale = null;
		private bool _scale = true;
		private bool _scale_vertical = true;

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

		public Pixbuf? source_vertical
		{
			get
			{
				return src_vertical;
			}
			set
			{
				src_vertical = value;
				scaled_vertical = src_vertical;
				if(src_vertical != null && src_vertical.width > 0 && src_vertical.height > 0)
				{
					_scale_vertical = scale ?? (src_vertical.width > cmin || src_vertical.height > cmin || src_vertical.width != src_vertical.height);
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
			load_image(is_vertical);
		}

		private bool is_vertical
		{
			get { return ratio > 1; }
		}

		public void load(string? url, string? url_vertical, string cache_prefix=ImageCache.DEFAULT_CACHED_FILE_PREFIX)
		{
			if(url == this.url && url_vertical == this.url_vertical) return;
			unload();
			this.url = url;
			this.url_vertical = url_vertical;
			this.cache_prefix = cache_prefix;
			load_image(is_vertical);
		}

		private void load_image(bool vertical=false)
		{
			if(vertical && url_vertical != null && url_vertical != "")
			{
				if(src_vertical == null)
				{
					ImageCache.load.begin(url_vertical, cache_prefix, (obj, res) => {
						source_vertical = ImageCache.load.end(res);
						if(src_vertical == null)
						{
							load_image(false);
						}
					});
				}
			}
			else if(url != null && url != "")
			{
				if(src == null)
				{
					ImageCache.load.begin(url, cache_prefix, (obj, res) => {
						source = ImageCache.load.end(res);
					});
				}
			}
		}

		public void unload()
		{
			url = null;
			url_vertical = null;
			cache_prefix = ImageCache.DEFAULT_CACHED_FILE_PREFIX;
			source = null;
			source_vertical = null;
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

			var img = src;
			var scaled_img = scaled;
			var _scale_img = _scale;

			if(is_vertical && src_vertical != null)
			{
				img = src_vertical;
				scaled_img = scaled_vertical;
				_scale_img = _scale_vertical;
			}

			if(img != null && img.width > 0 && img.height > 0)
			{
				if(_scale_img)
				{
					var ratio = float.min((float) width / img.width, (float) height / img.height);
					var new_width = (int) (img.width * ratio);
					var new_height = (int) (img.height * ratio);

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

					if(scaled_img.width != new_width || scaled_img.height != new_height)
					{
						scaled_img = img.scale_simple(new_width, new_height, InterpType.HYPER);

						if(is_vertical && src_vertical != null)
						{
							this.scaled_vertical = scaled_img;
						}
						else
						{
							this.scaled = scaled_img;
						}
					}
				}

				var x = (width - scaled_img.width) / 2;
				var y = (height - scaled_img.height) / 2;

				cairo_rounded_rectangle(ctx, int.max(x, 0), int.max(y, 0), int.min(scaled_img.width, width), int.min(scaled_img.height, height), corner_radius * scale_factor);
				cairo_set_source_pixbuf(ctx, scaled_img, x, y);

				ctx.clip();
				ctx.paint();
			}

			return false;
		}

		private static void cairo_rounded_rectangle(Cairo.Context cr, double x, double y, double width, double height, double radius)
		{
			cr.move_to(x + radius, y);
			cr.arc(x + width - radius, y + radius, radius, Math.PI * 1.5, Math.PI * 2);
			cr.arc(x + width - radius, y + height - radius, radius, 0, Math.PI * 0.5);
			cr.arc(x + radius, y + height - radius, radius, Math.PI * 0.5, Math.PI);
			cr.arc(x + radius, y + radius, radius, Math.PI, Math.PI * 1.5);
			cr.close_path();
		}
	}
}

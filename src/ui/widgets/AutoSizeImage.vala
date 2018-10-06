/*
This file is part of GameHub.
Copyright (C) 2018 Anatoliy Kashkin

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

namespace GameHub.UI.Widgets
{
	public class AutoSizeImage: DrawingArea
	{
		private Pixbuf? src;

		private int cmin = 0;
		private int cmax = 0;
		private float ratio = 1;
		private Orientation constraint = Orientation.HORIZONTAL;

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
		}

		public override bool draw(Cairo.Context ctx)
		{
			Allocation rect;
			get_allocation(out rect);

			int new_width = 0;
			int new_height = 0;

			switch(constraint)
			{
				case Orientation.HORIZONTAL:
					new_width = int.max(cmin, int.min(cmax, rect.width));
					new_height = (int) (new_width * ratio);
					break;

				case Orientation.VERTICAL:
					new_height = int.max(cmin, int.min(cmax, rect.height));
					new_width = (int) (new_height / ratio);
					break;
			}

			if(src != null)
			{
				Pixbuf pixbuf = src;

				if(src.width > cmin || src.height > cmin || src.width != src.height)
				{
					pixbuf = src.scale_simple(new_width, new_height, InterpType.BILINEAR);
				}

				Granite.Drawing.Utilities.cairo_rounded_rectangle(ctx, 0, 0, new_width, new_height, 4);
				cairo_set_source_pixbuf(ctx, pixbuf, (new_width - pixbuf.width) / 2, (new_height - pixbuf.height) / 2);
				ctx.clip();
				ctx.paint();
			}

			switch(constraint)
			{
				case Orientation.HORIZONTAL:
					set_size_request(cmin, new_height);
					break;

				case Orientation.VERTICAL:
					set_size_request(new_width, cmin);
					break;
			}

			return false;
		}
	}
}

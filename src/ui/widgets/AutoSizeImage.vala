using Gtk;
using Gdk;

namespace GameHub.UI.Widgets
{
	public class AutoSizeImage: Image
	{
		private Pixbuf? src;
		
		private int wmin = 0;
		private int wmax = 0;
		
		construct
		{
			size_allocate.connect(on_size_allocate);
		}
		
		public void set_width(int min, int max)
		{
			wmin = min;
			wmax = max;
			set_size_request(wmin, -1);
		}
		
		public void set_source(Pixbuf? buf)
		{
			src = buf;
		}
		
		private void on_size_allocate(Allocation rect)
		{
			var base_pixbuf = get_pixbuf();
			if(src == null) return;

			int new_width = 0;
			int new_height = 0;

			float ratio = (float) src.height / (float) src.width;

			new_width = int.max(wmin, int.min(wmax, rect.width));
			new_height = (int) (new_width * ratio);

			if(base_pixbuf.height == new_height && base_pixbuf.width == new_width) return;

			base_pixbuf = src.scale_simple(new_width, new_height, InterpType.BILINEAR);

			set_from_pixbuf(base_pixbuf);
			set_size_request(-1, new_height);
		}
	}
}

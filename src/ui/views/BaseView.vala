using Gtk;
using Granite;
using GameHub.UI.Windows;

namespace GameHub.UI.Views
{
	public abstract class BaseView: Gtk.Grid
	{
		protected MainWindow window;
		protected HeaderBar titlebar;
		
		construct
		{
			titlebar = new HeaderBar();
			titlebar.title = "GameHub";
			titlebar.show_close_button = true;
			titlebar.has_subtitle = false;
		}
		
		public virtual void attach_to_window(MainWindow wnd)
		{
			window = wnd;
			show();
		}
		
		public virtual void on_show()
		{
			titlebar.show_all();
			window.set_titlebar(titlebar);
		}
		
		public virtual void on_window_focus()
		{
			
		}
	}
}

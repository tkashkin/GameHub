using Gtk;
using GameHub.UI.Views;
using GameHub.Settings;

namespace GameHub.UI.Windows
{
	public class MainWindow: Gtk.ApplicationWindow
	{
		public static MainWindow instance;
		
		private SavedState saved_state;
		
		public HeaderBar titlebar;
		private Stack stack;
		
		public MainWindow(GameHub.Application app)
		{
			Object(application: app);
			instance = this;
		}
		
		construct
		{
			var ui_settings = Settings.UI.get_instance();
			ui_settings.notify["dark-theme"].connect(() => {
				Gtk.Settings.get_default().gtk_application_prefer_dark_theme = ui_settings.dark_theme;
			});
			ui_settings.notify_property("dark-theme");
			
			title = "GameHub";

			titlebar = new HeaderBar();
			titlebar.title = title;
			titlebar.show_close_button = true;
			titlebar.has_subtitle = false;

			set_titlebar(titlebar);

			set_default_size(1108, 720);
			set_size_request(640, 520);
			
			var vbox = new Box(Orientation.VERTICAL, 0);
			
			stack = new Stack();
			stack.transition_type = StackTransitionType.CROSSFADE;
			stack.notify["visible-child"].connect(stack_updated);
			
			add_view(new WelcomeView());
			
			vbox.add(stack);
			
			add(vbox);
			
			notify["has-toplevel-focus"].connect(() => {
				current_view.on_window_focus();
			});
			
			saved_state = SavedState.get_instance();
			
			delete_event.connect(() => { quit(); return false; });
			
			restore_saved_state();
		}
		
		public void add_view(BaseView view, bool show=true)
		{
			view.attach_to_window(this);
			stack.add(view);
			if(show)
			{
				stack.set_visible_child(view);
				view.show();
			}
			stack_updated();
		}
		
		private void stack_updated()
		{
			current_view.on_show();
		}
		
		private void restore_saved_state()
		{
			if(saved_state.window_width > -1)
				default_width = saved_state.window_width;
			if(saved_state.window_height > -1)
				default_height = saved_state.window_height;

			switch(saved_state.window_state)
			{
				case Settings.WindowState.MAXIMIZED:
					maximize();
					break;
				case Settings.WindowState.FULLSCREEN:
					fullscreen();
					break;
				default:
					if(saved_state.window_x > -1 && saved_state.window_y > -1)
						move(saved_state.window_x, saved_state.window_y);
					break;
			}
		}
		
		private void update_saved_state()
		{
			var state = get_window().get_state();
			if(Gdk.WindowState.MAXIMIZED in state)
			{
				saved_state.window_state = Settings.WindowState.MAXIMIZED;
			}
			else if(Gdk.WindowState.FULLSCREEN in state)
			{
				saved_state.window_state = Settings.WindowState.FULLSCREEN;
			}
			else
			{
				saved_state.window_state = Settings.WindowState.NORMAL;
				
				int width, height;
				get_size(out width, out height);
				saved_state.window_width = width;
				saved_state.window_height = height;
			}
			
			int x, y;
			get_position(out x, out y);
			saved_state.window_x = x;
			saved_state.window_y = y;
		}

		private void quit()
		{
			update_saved_state();
		}
		
		public BaseView current_view
		{
			get
			{
				return stack.visible_child as BaseView;
			}
		}
	}
}

using Gtk;
using GameHub.UI.Views;

namespace GameHub.UI.Windows
{
	public class MainWindow: Gtk.ApplicationWindow
	{
		public HeaderBar titlebar;
		
		private Stack stack;
		
		public MainWindow(GameHub.Application app)
		{
			Object(application: app);
		}
		
		construct
		{
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
		}
		
		public void add_view(BaseView view, bool show=true)
		{
			view.attach_to_window(this);
			stack.add(view);
			if(show) stack.set_visible_child(view);
			stack_updated();
		}
		
		private void stack_updated()
		{
			current_view.on_show();
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

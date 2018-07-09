using Gtk;
using Gdk;
using Granite;
using GameHub.Data;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views
{
	public class GameDownloadProgressView: ListBoxRow
	{
		public Game game;
		
		private AutoSizeImage image;
		private ProgressBar progress_bar;
		
		public GameDownloadProgressView(Game game)
		{
			this.game = game;
			
			selectable = false;
			
			var hbox = new Box(Orientation.HORIZONTAL, 16);
			hbox.margin = 8;
			var vbox = new Box(Orientation.VERTICAL, 0);
			
			image = new AutoSizeImage();
			image.set_constraint(48, 48, 1);
			image.set_size_request(48, 48);
			
			hbox.add(image);
			
			var label = new Label(game.name);
			label.halign = Align.START;
			label.get_style_context().add_class("category-label");
			label.ypad = 2;

			var state_label = new Label(null);
			state_label.halign = Align.START;

			progress_bar = new ProgressBar();
			progress_bar.hexpand = true;
			progress_bar.fraction = 0d;
			progress_bar.get_style_context().add_class(Gtk.STYLE_CLASS_OSD);
			
			vbox.add(label);
			vbox.add(state_label);
			vbox.add(progress_bar);
			
			hbox.add(vbox);
			
			child = hbox;
			
			game.status_change.connect(s => {
				state_label.label = s.description;
				if(s.state == DOWNLOADING)
				{
					progress_bar.fraction = (double) s.dl_bytes / s.dl_bytes_total;
				}
			});

			Utils.load_image.begin(image, game.icon, "icon");

			show_all();
		}
	}
}

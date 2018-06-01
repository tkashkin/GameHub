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
		
		private bool image_load_started = false;
		
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
			label.ypad = 8;
			
			progress_bar = new ProgressBar();
			progress_bar.hexpand = true;
			progress_bar.fraction = 0d;
			progress_bar.get_style_context().add_class(Gtk.STYLE_CLASS_OSD);
			
			vbox.add(label);
			vbox.add(progress_bar);
			
			hbox.add(vbox);
			
			child = hbox;
			
			show_all();
		}
		
		private async void load_image()
		{
			image_load_started = true;
			var hash = Checksum.compute_for_string(ChecksumType.MD5, game.icon, game.icon.length);
			var remote = File.new_for_uri(game.icon);
			var cached = FSUtils.file(FSUtils.Paths.Cache.Images, hash + ".jpg");
			try
			{
				if(!cached.query_exists())
				{
					yield remote.copy_async(cached, FileCopyFlags.NONE);
				}
				image.set_source(new Pixbuf.from_file(cached.get_path()));
				image.show_all();
			}
			catch(Error e)
			{
				warning(e.message);
			}
		}
		
		public void set_progress(double progress)
		{
			progress_bar.fraction = progress;
			if(!image_load_started) load_image.begin();
		}
	}
}

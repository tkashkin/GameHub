using Gtk;
using Granite;
using GameHub.Data;
using GameHub.Utils;

namespace GameHub.UI.Views
{
	public class GameCard: FlowBoxChild
	{
		public Game game;
		
		private Overlay content;
		private AsyncImage image;
		private Image src_icon;
		private Label label;
		
		construct
		{
			var wrapper = new Box(Orientation.HORIZONTAL, 0);
			wrapper.halign = Align.CENTER;
			wrapper.valign = Align.CENTER;
			
			var card = new Box(Orientation.VERTICAL, 0);
			card.get_style_context().add_class(Granite.STYLE_CLASS_CARD);
			card.get_style_context().add_class("gamecard");
			
			card.margin = 4;
			card.halign = Align.CENTER;
			card.valign = Align.CENTER;
			
			wrapper.add(card);
			
			child = wrapper;
			
			content = new Overlay();
			
			image = new AsyncImage();
			
			src_icon = new Image();
			src_icon.valign = Align.START;
			src_icon.halign = Align.START;
			src_icon.margin = 8;
			src_icon.opacity = 0.5;
			
			label = new Label("");
			label.xpad = 8;
			label.ypad = 8;
			label.hexpand = true;
			label.valign = Align.END;
			label.justify = Justification.CENTER;
			label.lines = 3;
			label.set_line_wrap(true);
			
			content.add(image);
			content.add_overlay(label);
			content.add_overlay(src_icon);
			
			card.add(content);
			
			show_all();
		}
		
		public GameCard(Game game)
		{
			this.game = game;
			
			label.label = game.name;
			
			src_icon.pixbuf = FSUtils.get_icon(game.source.icon + "-white", 24);
			
			load_image.begin();
		}
		
		private async void load_image()
		{
			var hash = Checksum.compute_for_string(ChecksumType.MD5, game.image, game.image.length);
			var remote = File.new_for_uri(game.image);
			var cached = FSUtils.file(FSUtils.Paths.Cache.Images, hash + ".jpg");
			try
			{
				if(!cached.query_exists())
				{
					image.set_from_file_async.begin(remote, 306, 143, false);
					remote.copy_async.begin(cached, FileCopyFlags.NONE);
				}
				else
				{
					image.set_from_file_async.begin(cached, 306, 143, false);
				}
			}
			catch(Error e)
			{
				error(e.message);
				image.set_from_file_async.begin(remote, -1, -1, true);
			}
		}
	}
}

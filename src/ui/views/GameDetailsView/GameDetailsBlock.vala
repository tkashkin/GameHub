using Gtk;
using Gdk;
using Gee;
using Granite;
using GameHub.Data;

namespace GameHub.UI.Views.GameDetailsView
{
	public abstract class GameDetailsBlock: Box
	{
		public Game game { get; construct; }

		public bool is_dialog { get; construct; }

		public GameDetailsBlock(Game game, bool is_dialog)
		{
			Object(game: game, orientation: Orientation.VERTICAL, is_dialog: is_dialog);
		}

		public abstract bool supports_game { get; }

		protected void add_info_label(string title, string? text, bool multiline=true, bool markup=false)
		{
			if(text == null || text == "") return;

			var title_label = new Granite.HeaderLabel(title);
			title_label.set_size_request(multiline ? -1 : 128, -1);
			title_label.valign = Align.START;

			var text_label = new Label(text);
			text_label.halign = Align.START;
			text_label.hexpand = false;
			text_label.wrap = true;
			text_label.xalign = 0;
			text_label.max_width_chars = is_dialog ? 60 : -1;
			text_label.use_markup = markup;

			if(!multiline)
			{
				text_label.get_style_context().add_class("gameinfo-singleline-value");
			}

			var box = new Box(multiline ? Orientation.VERTICAL : Orientation.HORIZONTAL, 0);
			box.margin_start = box.margin_end = 8;
			box.add(title_label);
			box.add(text_label);
			add(box);
		}
	}
}

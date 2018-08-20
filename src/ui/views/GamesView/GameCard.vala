using Gtk;
using Gdk;
using Gee;
using Granite;
using GameHub.Data;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views
{
	public class GameCard: FlowBoxChild
	{
		public Game game { get; construct; }

		private Frame card;
		private Overlay content;
		private AutoSizeImage image;
		private Label label;
		private Label status_label;
		
		private Box src_icons;
		private Image src_icon;

		private Box actions;
		
		private const int CARD_WIDTH_MIN = 320;
		private const int CARD_WIDTH_MAX = 680;
		private const float CARD_RATIO = 0.467f; // 460x215
		
		private Frame progress_bar;

		construct
		{
			margin = 0;

			card = new Frame(null);
			card.get_style_context().add_class(Granite.STYLE_CLASS_CARD);
			card.get_style_context().add_class("gamecard");
			card.shadow_type = ShadowType.NONE;
			card.margin = 4;
			
			child = card;
			
			content = new Overlay();
			
			image = new AutoSizeImage();
			image.set_constraint(CARD_WIDTH_MIN, CARD_WIDTH_MAX, CARD_RATIO);
			
			src_icons = new Box(Orientation.HORIZONTAL, 4);
			src_icons.valign = Align.START;
			src_icons.halign = Align.START;
			src_icons.margin = 8;
			src_icons.set_events(0);

			src_icon = new Image();
			src_icon.icon_size = IconSize.LARGE_TOOLBAR;
			src_icon.opacity = 0.6;

			label = new Label("");
			label.xpad = 8;
			label.ypad = 4;
			label.hexpand = true;
			label.justify = Justification.CENTER;
			label.lines = 3;
			label.set_line_wrap(true);
			
			status_label = new Label("");
			status_label.get_style_context().add_class("status");
			status_label.xpad = 8;
			status_label.ypad = 2;
			status_label.hexpand = true;
			status_label.justify = Justification.CENTER;
			status_label.lines = 1;

			var info = new Box(Orientation.VERTICAL, 0);
			info.get_style_context().add_class("info");
			info.add(label);
			info.add(status_label);
			info.valign = Align.END;

			actions = new Box(Orientation.VERTICAL, 0);
			actions.get_style_context().add_class("actions");
			actions.hexpand = true;
			actions.vexpand = true;
			
			progress_bar = new Frame(null);
			progress_bar.halign = Align.START;
			progress_bar.valign = Align.END;
			progress_bar.get_style_context().add_class("progress");
			
			content.add(image);
			content.add_overlay(actions);
			content.add_overlay(info);
			content.add_overlay(src_icons);
			content.add_overlay(progress_bar);
			
			card.add(content);
			
			content.add_events(EventMask.ALL_EVENTS_MASK);
			content.enter_notify_event.connect(e => { card.get_style_context().add_class("hover"); });
			content.leave_notify_event.connect(e => { card.get_style_context().remove_class("hover"); });
			content.button_release_event.connect(e => {
				switch(e.button)
				{
					case 1:
						if(game.status.state == Game.State.INSTALLED)
						{
							game.run.begin();
						}
						else if(game.status.state == Game.State.UNINSTALLED)
						{
							game.install.begin();
						}
						break;

					case 3:
						new Dialogs.GameDetailsDialog(game).show_all();
						break;
				}
			});
			
			show_all();
		}
		
		public GameCard(Game game)
		{
			Object(game: game);
			
			label.label = game.name;
			
			src_icon.icon_name = game.source.icon + "-symbolic";
			
			update();

			card.get_style_context().add_class("installed");
			
			game.status_change.connect(s => {
				status_label.label = s.description;
				switch(s.state)
				{
					case Game.State.UNINSTALLED:
						card.get_style_context().remove_class("installed");
						card.get_style_context().remove_class("downloading");
						card.get_style_context().remove_class("installing");
						break;

					case Game.State.INSTALLED:
						card.get_style_context().add_class("installed");
						card.get_style_context().remove_class("downloading");
						card.get_style_context().remove_class("installing");
						break;

					case Game.State.DOWNLOADING:
						card.get_style_context().remove_class("installed");
						card.get_style_context().add_class("downloading");
						card.get_style_context().remove_class("installing");
						Allocation alloc;
						card.get_allocation(out alloc);
						if(s.download != null)
						{
							progress_bar.set_size_request((int) (s.download.status.progress * alloc.width), 8);
						}
						break;

					case Game.State.INSTALLING:
						card.get_style_context().remove_class("installed");
						card.get_style_context().remove_class("downloading");
						card.get_style_context().add_class("installing");
						break;
				}
			});
			game.status_change(game.status);

			Utils.load_image.begin(image, game.image, "image");
		}

		public void update()
		{
			src_icons.foreach(w => src_icons.remove(w));
			src_icons.add(src_icon);

			var merges = GamesDB.get_instance().get_merged_games(game);
			if(merges != null && merges.size > 0)
			{
				foreach(var g in merges)
				{
					var icon_name = g.source.icon + "-symbolic";

					src_icons.foreach(w => { if((w as Image).icon_name == icon_name) src_icons.remove(w); });

					var icon = new Image();
					icon.icon_name = icon_name;
					icon.icon_size = IconSize.LARGE_TOOLBAR;
					icon.opacity = 0.6;
					src_icons.add(icon);
				}
			}
			src_icons.show_all();
		}
	}
}

using Gtk;
using Gdk;
using Gee;
using Granite;

using GameHub.Data;
using GameHub.Data.Sources.GOG;

using GameHub.Utils;

namespace GameHub.UI.Views.GameDetailsView.Blocks
{
	public class GOGDetails: GameDetailsBlock
	{
		public GOGDetails(Game game)
		{
			Object(game: game, orientation: Orientation.VERTICAL);
		}

		construct
		{
			if(!supports_game) return;

			var gog_game = game as GOGGame;

			var root = Parser.parse_json(game.custom_info);

			if(root == null || gog_game == null) return;

			var sys_langs = Intl.get_language_names();
			var langs = root.get_object().get_object_member("languages");
			if(langs != null)
			{
				var langs_string = "";
				foreach(var l in langs.get_members())
				{
					var lang = langs.get_string_member(l);
					if(l in sys_langs) lang = @"<b>$(lang)</b>";
					langs_string += (langs_string.length > 0 ? ", " : "") + lang;
				}
				var langs_label = _("Language");
				if(langs_string.contains(","))
				{
					langs_label = _("Languages");
				}
				add_info_label(langs_label, langs_string, false, true);
			}

			var dlbox = new Box(Orientation.HORIZONTAL, 16);

			var downloads_visible = false;

			if(gog_game.bonus_content != null && gog_game.bonus_content.size > 0)
			{
				var bonusbox = new Box(Orientation.VERTICAL, 0);
				var bonuslist = new ListBox();
				bonuslist.selection_mode = SelectionMode.NONE;
				bonuslist.get_style_context().add_class("gameinfo-content-list");

				foreach(var bonus in gog_game.bonus_content)
				{
					bonuslist.add(new BonusContentRow(bonus));
				}

				var header = new Granite.HeaderLabel(_("Bonus content"));
				header.margin_start = header.margin_end = 8;

				downloads_visible = true;
				bonusbox.add(header);
				bonusbox.add(bonuslist);

				dlbox.add(bonusbox);
			}

			if(gog_game.dlc != null && gog_game.dlc.size > 0)
			{
				var dlcbox = new Box(Orientation.VERTICAL, 0);
				var dlclist = new ListBox();
				dlclist.selection_mode = SelectionMode.NONE;
				dlclist.get_style_context().add_class("gameinfo-content-list");
				dlclist.sensitive = false; // TODO: Implement download

				foreach(var dlc in gog_game.dlc)
				{
					dlclist.add(new DLCRow(dlc));
				}

				var header = new Granite.HeaderLabel(_("DLC"));
				header.margin_start = header.margin_end = 8;

				downloads_visible = true;
				dlcbox.add(header);
				dlcbox.add(dlclist);

				dlbox.add(dlcbox);
			}

			if(downloads_visible)
			{
				add(new Separator(Orientation.HORIZONTAL));
			}

			add(dlbox);
		}

		public override bool supports_game { get { return (game is GOGGame) && game.custom_info != null && game.custom_info.length > 0; } }

		public class BonusContentRow: ListBoxRow
		{
			public GOGGame.BonusContent bonus;

			public BonusContentRow(GOGGame.BonusContent bonus)
			{
				this.bonus = bonus;

				var content = new Overlay();

				var progress_bar = new Frame(null);
				progress_bar.halign = Align.START;
				progress_bar.vexpand = true;
				progress_bar.get_style_context().add_class("progress");

				var box = new Box(Orientation.HORIZONTAL, 8);
				box.margin_start = box.margin_end = 8;
				box.margin_top = box.margin_bottom = 4;

				var icon = new Image.from_icon_name(bonus.icon, IconSize.BUTTON);

				var name = new Label(bonus.text);
				name.hexpand = true;
				name.halign = Align.START;

				var size = new Label(format_size(bonus.size));
				size.halign = Align.END;

				box.add(icon);
				box.add(name);
				box.add(size);

				var event_box = new Box(Orientation.VERTICAL, 0);
				event_box.expand = true;

				content.add(box);
				content.add_overlay(progress_bar);
				content.add_overlay(event_box);

				bonus.status_change.connect(s => {
					switch(s.state)
					{
						case GOGGame.BonusContent.State.DOWNLOADING:
							Allocation alloc;
							content.get_allocation(out alloc);
							if(s.download != null)
							{
								progress_bar.get_style_context().add_class("downloading");
								progress_bar.set_size_request((int) (s.download.status.progress * alloc.width), alloc.height);
							}
							break;

						default:
							progress_bar.get_style_context().remove_class("downloading");
							progress_bar.set_size_request(0, 0);
							break;
					}
				});
				bonus.status_change(bonus.status);

				content.add_events(EventMask.ALL_EVENTS_MASK);
				content.button_release_event.connect(e => {
					if(e.button == 1)
					{
						if(bonus.status.state == GOGGame.BonusContent.State.NOT_DOWNLOADED)
						{
							bonus.download.begin();
						}
						else if(bonus.status.state == GOGGame.BonusContent.State.DOWNLOADED)
						{
							bonus.open();
						}
					}
					return true;
				});

				child = content;
			}
		}

		public class DLCRow: ListBoxRow
		{
			public GOGGame.DLC dlc;

			public DLCRow(GOGGame.DLC dlc)
			{
				this.dlc = dlc;

				var box = new Box(Orientation.HORIZONTAL, 0);
				box.margin_start = box.margin_end = 8;
				box.margin_top = box.margin_bottom = 4;

				var name = new Label(dlc.name);
				name.hexpand = true;
				name.halign = Align.START;

				var dl = new Button.from_icon_name("folder-download-symbolic");
				dl.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
				dl.margin_start = 8;
				dl.halign = Align.END;

				box.add(name);
				box.add(dl);
				child = box;
			}
		}
	}
}

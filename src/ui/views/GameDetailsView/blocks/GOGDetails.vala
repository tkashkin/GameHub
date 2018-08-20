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

			var root = Parser.parse_json(game.custom_info);

			if(root == null) return;

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

			var downloads = Parser.json_object(root, {"downloads"});

			var bonuses_json = downloads == null || !downloads.has_member("bonus_content") ? null : downloads.get_array_member("bonus_content");

			var downloads_visible = false;

			if(bonuses_json != null)
			{
				var bonuses = new ArrayList<GOGGame.BonusContent>();
				foreach(var bonus_json in bonuses_json.get_elements())
				{
					var bonus = new GOGGame.BonusContent(bonus_json.get_object());
					bonuses.add(bonus);
				}

				if(bonuses.size > 0)
				{
					var bonusbox = new Box(Orientation.VERTICAL, 0);
					var bonuslist = new ListBox();
					bonuslist.selection_mode = SelectionMode.NONE;
					bonuslist.get_style_context().add_class("installers-list");
					bonuslist.sensitive = false; // TODO: Implement download

					foreach(var bonus in bonuses)
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
			}

			var dlcs_json = !root.get_object().has_member("expanded_dlcs") ? null : root.get_object().get_array_member("expanded_dlcs");

			if(dlcs_json != null)
			{
				var dlcs = new ArrayList<GOGGame.DLC>();
				foreach(var dlc_json in dlcs_json.get_elements())
				{
					var dlc = new GOGGame.DLC((GOGGame) game, dlc_json.get_object());
					dlcs.add(dlc);
				}

				if(dlcs.size > 0)
				{
					var dlcbox = new Box(Orientation.VERTICAL, 0);
					var dlclist = new ListBox();
					dlclist.selection_mode = SelectionMode.NONE;
					dlclist.get_style_context().add_class("installers-list");
					dlclist.sensitive = false; // TODO: Implement download

					foreach(var dlc in dlcs)
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

				var box = new Box(Orientation.HORIZONTAL, 0);
				box.margin_start = box.margin_end = 8;
				box.margin_top = box.margin_bottom = 4;

				var name = new Label(bonus.text);
				name.hexpand = true;
				name.halign = Align.START;

				var size = new Label(format_size(bonus.size));
				size.halign = Align.END;

				var dl = new Button.from_icon_name("folder-download-symbolic");
				dl.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
				dl.margin_start = 8;
				dl.halign = Align.END;

				box.add(name);
				box.add(size);
				box.add(dl);
				child = box;
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

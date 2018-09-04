using Gtk;
using Gdk;
using Gee;
using Granite;

using GameHub.Data;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Dialogs.GameTagsDialog
{
	public class GameTagsDialog: Dialog
	{
		public Game game;

		private Box content;
		private ListBox tags_list;
		private ScrolledWindow tags_scrolled;
		private Entry new_entry;

		public GameTagsDialog(Game? game)
		{
			Object(transient_for: Windows.MainWindow.instance, deletable: false, resizable: false, title: game.name);

			this.game = game;

			gravity = Gdk.Gravity.CENTER;

			content = new Box(Orientation.VERTICAL, 0);
			content.margin_start = content.margin_end = 8;

			var icon = new AutoSizeImage();
			icon.set_constraint(48, 48, 1);
			icon.set_size_request(48, 48);

			var header = new HeaderLabel(_("Tags"));
			header.xpad = 8;
			content.add(header);

			tags_list = new ListBox();
			tags_list.get_style_context().add_class("tags-list");
			tags_list.selection_mode = SelectionMode.NONE;

			tags_list.set_sort_func((row1, row2) => {
				var item1 = row1 as TagRow;
				var item2 = row2 as TagRow;

				if(row1 != null && row2 != null)
				{
					var t1 = item1.tag.id;
					var t2 = item2.tag.id;

					var b1 = t1.has_prefix(GamesDB.Tables.Tags.Tag.BUILTIN_PREFIX);
					var b2 = t2.has_prefix(GamesDB.Tables.Tags.Tag.BUILTIN_PREFIX);
					if(b1 && !b2) return -1;
					if(!b1 && b2) return 1;

					var u1 = t1.has_prefix(GamesDB.Tables.Tags.Tag.USER_PREFIX);
					var u2 = t2.has_prefix(GamesDB.Tables.Tags.Tag.USER_PREFIX);
					if(u1 && !u2) return -1;
					if(!u1 && u2) return 1;

					return item1.tag.name.collate(item1.tag.name);
				}

				return 0;
			});

			tags_scrolled = new ScrolledWindow(null, null);
			tags_scrolled.margin_bottom = 8;
			#if GTK_3_22
			tags_scrolled.propagate_natural_width = true;
			tags_scrolled.propagate_natural_height = true;
			tags_scrolled.max_content_height = 320;
			#endif
			tags_scrolled.add(tags_list);

			content.add(tags_scrolled);

			new_entry = new Entry();
			new_entry.placeholder_text = _("Add tag...");
			new_entry.primary_icon_name = "tag-symbolic";
			new_entry.primary_icon_activatable = false;
			new_entry.secondary_icon_name = "list-add-symbolic";
			new_entry.secondary_icon_activatable = true;
			new_entry.margin = 4;

			new_entry.icon_press.connect((icon, event) => {
				if(icon == EntryIconPosition.SECONDARY && ((EventButton) event).button == 1)
				{
					add_tag();
				}
			});
			new_entry.activate.connect(add_tag);

			content.add(new_entry);

			response.connect((source, response_id) => {
				switch(response_id)
				{
					case ResponseType.CLOSE:
						destroy();
						break;
				}
			});

			add_button(_("Close"), ResponseType.CLOSE).margin_end = 7;

			get_content_area().add(content);
			get_content_area().set_size_request(340, -1);

			GamesDB.get_instance().tags_updated.connect(update);

			update();

			show_all();
		}

		private void update()
		{
			tags_list.foreach(w => w.destroy());

			foreach(var tag in GamesDB.Tables.Tags.TAGS)
			{
				var row = new TagRow(game, tag);
				tags_list.add(row);
			}

			tags_list.show_all();
		}

		private void add_tag()
		{
			var name = new_entry.text.strip();
			if(name.length == 0) return;

			new_entry.text = "";

			var tag = new GamesDB.Tables.Tags.Tag.from_name(name);
			GamesDB.get_instance().add_tag(tag);
			game.add_tag(tag);
			update();
		}

		public class TagRow: ListBoxRow
		{
			public Game game;
			public GamesDB.Tables.Tags.Tag tag;

			public TagRow(Game game, GamesDB.Tables.Tags.Tag tag)
			{
				this.game = game;
				this.tag = tag;

				var ebox = new EventBox();
				ebox.above_child = true;

				var box = new Box(Orientation.HORIZONTAL, 8);
				box.margin_start = box.margin_end = 8;
				box.margin_top = box.margin_bottom = 6;

				var check = new CheckButton();
				check.active = game.has_tag(tag);

				var name = new Label(tag.name);
				name.halign = Align.START;
				name.xalign = 0;
				name.hexpand = true;

				var icon = new Image.from_icon_name(tag.icon, IconSize.BUTTON);

				box.add(check);
				box.add(name);
				box.add(icon);

				ebox.add_events(EventMask.ALL_EVENTS_MASK);
				ebox.button_release_event.connect(e => {
					if(e.button == 1)
					{
						game.toggle_tag(tag);
						check.active = game.has_tag(tag);
					}
					return true;
				});

				ebox.add(box);

				child = ebox;
			}
		}
	}
}

using Gtk;
using Gdk;
using Gee;
using Granite;
using GameHub.Data;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views.GamesView
{
	public class FiltersPopover: Popover
	{
		public ArrayList<GamesDB.Tables.Tags.Tag> selected_tags { get; private set; }
		public signal void filters_changed(ArrayList<GamesDB.Tables.Tags.Tag> selected_tags);

		private CheckButton tags_header_check;
		private bool is_toggling_all = false;

		public FiltersPopover(Widget? relative_to)
		{
			Object(relative_to: relative_to);
		}

		construct
		{
			selected_tags = new ArrayList<GamesDB.Tables.Tags.Tag>(GamesDB.Tables.Tags.Tag.is_equal);

			set_size_request(220, -1);

			var vbox = new Box(Orientation.VERTICAL, 0);

			var tags_list = new ListBox();
			tags_list.get_style_context().add_class("tags-list");
			tags_list.selection_mode = SelectionMode.NONE;

			var tags_scrolled = new ScrolledWindow(null, null);
			#if GTK_3_22
			tags_scrolled.propagate_natural_width = true;
			tags_scrolled.propagate_natural_height = true;
			tags_scrolled.max_content_height = 440;
			#endif
			tags_scrolled.add(tags_list);
			tags_scrolled.show_all();

			var tebox = new EventBox();
			tebox.get_style_context().add_class("tags-list-header");
			tebox.above_child = true;

			var tbox = new Box(Orientation.HORIZONTAL, 8);
			tbox.margin_start = tbox.margin_end = 8;
			tbox.margin_top = tbox.margin_bottom = 6;

			tags_header_check = new CheckButton();

			var header = new HeaderLabel(_("Tags"));
			header.halign = Align.START;
			header.xalign = 0;
			header.hexpand = true;

			tbox.add(tags_header_check);
			tbox.add(header);

			tebox.add_events(EventMask.ALL_EVENTS_MASK);
			tebox.enter_notify_event.connect(e => { tebox.get_style_context().add_class("hover"); });
			tebox.leave_notify_event.connect(e => { tebox.get_style_context().remove_class("hover"); });
			tebox.button_release_event.connect(e => {
				if(e.button == 1)
				{
					tags_header_check.inconsistent = false;
					tags_header_check.active = !tags_header_check.active;

					is_toggling_all = true;
					foreach(var tag in GamesDB.Tables.Tags.TAGS)
					{
						tag.selected = tags_header_check.active;
					}
					is_toggling_all = false;
					update();
				}
				return true;
			});

			tebox.add(tbox);

			vbox.add(tebox);
			vbox.add(new Separator(Orientation.HORIZONTAL));
			vbox.add(tags_scrolled);

			child = vbox;

			foreach(var tag in GamesDB.Tables.Tags.TAGS)
			{
				tags_list.add(new TagRow(tag));
				tag.notify["selected"].connect(update);
			}

			vbox.show_all();

			update();
		}

		private void update()
		{
			if(is_toggling_all) return;

			selected_tags.clear();

			foreach(var tag in GamesDB.Tables.Tags.TAGS)
			{
				if(tag.selected) selected_tags.add(tag);
				GamesDB.get_instance().add_tag(tag, true);
			}

			tags_header_check.inconsistent = selected_tags.size != 0 && selected_tags.size != GamesDB.Tables.Tags.TAGS.size;
			tags_header_check.active = selected_tags.size > 0;

			filters_changed(selected_tags);
		}

		public class TagRow: ListBoxRow
		{
			public GamesDB.Tables.Tags.Tag tag;

			public TagRow(GamesDB.Tables.Tags.Tag tag)
			{
				this.tag = tag;

				var ebox = new EventBox();
				ebox.above_child = true;

				var box = new Box(Orientation.HORIZONTAL, 8);
				box.margin_start = box.margin_end = 8;
				box.margin_top = box.margin_bottom = 6;

				var check = new CheckButton();
				check.active = tag.selected;

				var name = new Label(tag.name);
				name.halign = Align.START;
				name.xalign = 0;
				name.hexpand = true;

				var icon = new Image.from_icon_name(tag.icon, IconSize.BUTTON);

				box.add(check);
				box.add(name);
				box.add(icon);

				tag.notify["selected"].connect(() => {
					check.active = tag.selected;
				});

				ebox.add_events(EventMask.ALL_EVENTS_MASK);
				ebox.button_release_event.connect(e => {
					if(e.button == 1)
					{
						check.active = !check.active;
						tag.selected = check.active;
					}
					return true;
				});

				ebox.add(box);

				child = ebox;
			}
		}
	}
}
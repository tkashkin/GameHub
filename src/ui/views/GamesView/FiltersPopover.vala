using Gtk;
using Gdk;
using Granite;
using GameHub.Data;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views
{
	public class FiltersPopover: Popover
	{
		public FiltersPopover(Widget? relative_to)
		{
			Object(relative_to: relative_to);
		}

		construct
		{
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

			var tbox = new Box(Orientation.HORIZONTAL, 8);
			tbox.margin_start = tbox.margin_end = 8;
			tbox.margin_top = tbox.margin_bottom = 4;

			var check = new CheckButton();
			check.inconsistent = true;

			var header = new HeaderLabel(_("Tags"));
			header.halign = Align.START;
			header.xalign = 0;
			header.hexpand = true;

			tbox.add(check);
			tbox.add(header);

			vbox.add(tbox);
			vbox.add(new Separator(Orientation.HORIZONTAL));
			vbox.add(tags_scrolled);

			child = vbox;

			foreach(var tag in GamesDB.Tables.Tags.TAGS)
			{
				tags_list.add(new TagRow(tag));
			}

			show_all();
		}

		public class TagRow: ListBoxRow
		{
			public GamesDB.Tables.Tags.Tag tag;

			public TagRow(GamesDB.Tables.Tags.Tag tag)
			{
				this.tag = tag;

				var box = new Box(Orientation.HORIZONTAL, 8);
				box.margin_start = box.margin_end = 8;
				box.margin_top = box.margin_bottom = 4;

				var check = new CheckButton();
				check.active = true;

				var name = new Label(tag.name);
				name.halign = Align.START;
				name.xalign = 0;
				name.hexpand = true;

				var icon = new Image.from_icon_name(tag.icon, IconSize.BUTTON);

				box.add(check);
				box.add(name);
				box.add(icon);

				child = box;
			}
		}
	}
}
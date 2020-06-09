/*
This file is part of GameHub.
Copyright (C) 2018-2019 Anatoliy Kashkin

GameHub is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

GameHub is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GameHub.  If not, see <https://www.gnu.org/licenses/>.
*/

using Gtk;
using Gdk;
using Gee;

using GameHub.Data;
using GameHub.Data.Tweaks;

namespace GameHub.UI.Widgets
{
	public class TweaksList: ListBox
	{
		public TweakableGame? game { get; construct; default = null; }

		public TweaksList(TweakableGame? game=null)
		{
			Object(game: game, selection_mode: SelectionMode.NONE);
		}

		construct
		{
			update();
		}

		public void update(CompatTool? compat_tool=null)
		{
			this.foreach(w => w.destroy());

			var tweaks = Tweak.load_tweaks(game == null);

			foreach(var tweak in tweaks.values)
			{
				if(game == null || tweak.is_applicable_to(game, compat_tool))
				{
					add(new TweakRow(tweak, game));
				}
			}
		}

		private class TweakRow: ListBoxRow
		{
			public Tweak tweak { get; construct; }
			public TweakableGame? game { get; construct; default = null; }

			public TweakRow(Tweak tweak, TweakableGame? game=null)
			{
				Object(tweak: tweak, game: game);
			}

			construct
			{
				var grid = new Grid();
				grid.column_spacing = 12;
				grid.margin_start = grid.margin_end = 8;
				grid.margin_top = grid.margin_bottom = 4;

				var icon = new Image.from_icon_name(tweak.icon, IconSize.LARGE_TOOLBAR);
				icon.valign = Align.CENTER;

				var name = new Label(tweak.name ?? tweak.id);
				name.get_style_context().add_class("category-label");
				name.set_size_request(96, -1);
				name.hexpand = true;
				name.ellipsize = Pango.EllipsizeMode.END;
				name.max_width_chars = 60;
				name.xalign = 0;
				name.valign = Align.CENTER;

				var description = new Label(tweak.description ?? _("No description"));
				description.tooltip_text = tweak.description;
				description.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
				description.hexpand = true;
				description.ellipsize = Pango.EllipsizeMode.END;
				description.max_width_chars = 60;
				description.xalign = 0;
				description.valign = Align.CENTER;

				var install = new Button.with_label(_("Install"));
				install.valign = Align.CENTER;
				install.sensitive = false;

				var enabled = new Switch();
				enabled.active = tweak.is_enabled(game);
				enabled.valign = Align.CENTER;

				grid.attach(icon, 0, 0, 1, 2);
				grid.attach(name, 1, 0);
				grid.attach(description, 1, 1);

				if(tweak.url != null)
				{
					var url = new Button.from_icon_name("web-browser-symbolic", IconSize.SMALL_TOOLBAR);
					url.tooltip_text = tweak.url;
					url.valign = Align.CENTER;
					url.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

					url.clicked.connect(() => {
						try
						{
							Utils.open_uri(tweak.url);
						}
						catch(Utils.RunError error)
						{
							//FIXME [DEV-ART]: Replace this with inline error display?
							GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
								this, error, Log.METHOD,
								_("Opening tweak website “%s” of tweak “%s” failed").printf(
									tweak.url, tweak.name ?? tweak.id
								)
							);
						}
					});

					grid.attach(url, 2, 0, 1, 2);
				}

				if(tweak.file != null && tweak.file.query_exists())
				{
					var edit = new Button.from_icon_name("accessories-text-editor-symbolic", IconSize.SMALL_TOOLBAR);
					edit.tooltip_text = _("Edit file");
					edit.valign = Align.CENTER;
					edit.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

					edit.clicked.connect(() => {
						try
						{
							Utils.open_uri(tweak.file.get_uri());
						}
						catch(Utils.RunError error)
						{
							//FIXME [DEV-ART]: Replace this with inline error display?
							GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
								this, error, Log.METHOD,
								_("Opening editor for tweak file “%s” of tweak “%s” failed").printf(
									tweak.file.get_path(), tweak.name ?? tweak.id
								)
							);
						}
					});

					grid.attach(edit, 3, 0, 1, 2);
				}

				grid.attach(enabled, 4, 0, 1, 2);

				enabled.notify["active"].connect(() => {
					tweak.set_enabled(enabled.active, game);
				});

				child = grid;
			}
		}
	}
}

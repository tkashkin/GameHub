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

using GameHub.Utils;
using GameHub.UI.Widgets;
using GameHub.Data.Providers;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.Providers
{
	public class Providers: SettingsDialogPage
	{
		private Settings.Providers.Data.IGDB igdb;

		private ListBox image_providers;
		private ListBox data_providers;

		public Providers(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				header: _("Data"),
				title: _("Providers"),
				description: _("Third-party data providers"),
				icon_name: "web-browser"
			);
			status = description;
		}

		construct
		{
			root_grid.margin = 0;
			header_grid.margin = 12;
			header_grid.margin_bottom = 0;
			content_area.margin = 0;

			igdb = Settings.Providers.Data.IGDB.instance;

			var image_providers_header = add_header(_("Image providers"));
			image_providers_header.margin_start = image_providers_header.margin_end = 12;

			image_providers = add_widget(new ListBox());
			image_providers.selection_mode = SelectionMode.NONE;
			image_providers.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);
			image_providers.get_style_context().add_class("flat-list");

			image_providers.margin_start = 7;
			image_providers.margin_end = 3;
			image_providers.margin_top = 0;
			image_providers.margin_bottom = 6;

			var data_providers_header = add_header(_("Metadata providers"));
			data_providers_header.margin_start = data_providers_header.margin_end = 12;

			data_providers = add_widget(new ListBox());
			data_providers.selection_mode = SelectionMode.NONE;
			data_providers.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);
			data_providers.get_style_context().add_class("flat-list");

			data_providers.margin_start = 7;
			data_providers.margin_end = 3;
			data_providers.margin_top = 0;
			data_providers.margin_bottom = 6;

			update();
		}

		private void update()
		{
			image_providers.foreach(r => {
				if(r != null) r.destroy();
			});

			foreach(var src in ImageProviders)
			{
				image_providers.add(new ProviderRow(src));
			}

			foreach(var src in DataProviders)
			{
				data_providers.add(new ProviderRow(src));
			}
		}

		private class ProviderRow: ListBoxRow
		{
			public Provider provider { get; construct; }

			public ProviderRow(Provider provider)
			{
				Object(provider: provider);
			}

			construct
			{
				var root_vbox = new Box(Orientation.VERTICAL, 0);

				var grid = new Grid();
				grid.column_spacing = 12;
				grid.margin_start = grid.margin_end = 8;
				grid.margin_top = grid.margin_bottom = 4;

				var icon = new Image.from_icon_name(provider.icon, IconSize.LARGE_TOOLBAR);
				icon.valign = Align.CENTER;

				var name = new Label(provider.name);
				name.get_style_context().add_class("category-label");
				name.hexpand = true;
				name.xalign = 0;
				name.valign = Align.CENTER;

				var url = new Label(provider.url);
				url.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
				url.hexpand = true;
				url.xalign = 0;
				url.valign = Align.CENTER;

				var open = new Button.from_icon_name("web-browser-symbolic", IconSize.SMALL_TOOLBAR);
				open.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
				open.valign = Align.CENTER;
				open.tooltip_text = _("Open website");

				var enabled_switch = new Switch();
				enabled_switch.active = provider.enabled;
				enabled_switch.valign = Align.CENTER;

				grid.attach(icon, 0, 0, 1, 2);
				grid.attach(name, 1, 0);
				grid.attach(url, 1, 1);
				grid.attach(open, 2, 0, 1, 2);
				grid.attach(enabled_switch, 3, 0, 1, 2);

				root_vbox.add(grid);

				Revealer? provider_settings_revealer = null;
				var provider_settings = provider.settings_widget;
				if(provider_settings != null)
				{
					provider_settings_revealer = new Revealer();
					provider_settings_revealer.transition_type = RevealerTransitionType.SLIDE_DOWN;
					provider_settings_revealer.reveal_child = provider.enabled;

					var provider_settings_wrapper = new Box(Orientation.VERTICAL, 0);
					provider_settings_wrapper.get_style_context().add_class("provider-settings");

					provider_settings.margin_top = provider_settings.margin_bottom = 4;
					provider_settings.margin_start = 44;
					provider_settings.margin_end = 8;

					provider_settings_wrapper.add(provider_settings);
					provider_settings_wrapper.show_all();

					provider_settings_revealer.add(provider_settings_wrapper);
					root_vbox.add(provider_settings_revealer);
				}

				child = root_vbox;

				enabled_switch.notify["active"].connect(() => {
					provider.enabled = enabled_switch.active;
					if(provider_settings_revealer != null)
					{
						provider_settings_revealer.reveal_child = provider.enabled;
					}
				});

				open.clicked.connect(() => {
					try
					{
						Utils.open_uri(provider.url);
					}
					catch(Utils.RunError error)
					{
						//FIXME [DEV-ART]: Replace this with inline error display?
						GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
							this, error, Log.METHOD,
							_("Opening provider website “%s” of provider “%s” failed").printf(
								provider.url, provider.name
							)
						);
					}
				});
			}
		}
	}
}

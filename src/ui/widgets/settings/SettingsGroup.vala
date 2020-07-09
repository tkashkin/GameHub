/*
This file is part of GameHub.
Copyright(C) 2018-2019 Anatoliy Kashkin

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

namespace GameHub.UI.Widgets.Settings
{
    public class SettingsGroup: Box
    {
        public string? title { get; construct; }

        private Label? title_label;
        public ListBox settings;

        public SettingsGroup(string? title = null)
        {
            Object(title: title, orientation: Orientation.VERTICAL);
        }

        construct
        {
            get_style_context().add_class("settings-group");

            if(title != null)
            {
                title_label = new Label(title);
                title_label.get_style_context().add_class("title");
                title_label.ellipsize = Pango.EllipsizeMode.END;
                title_label.xalign = 0;
                add(title_label);
            }

            settings = new ListBox();
            settings.get_style_context().add_class("settings-group-frame");
            settings.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);
            settings.get_style_context().add_class(Gtk.STYLE_CLASS_VIEW);
            add(settings);

            settings.row_activated.connect(row => {
                var setting = row as ActivatableSetting;
                if(setting != null)
                {
                    setting.setting_activated();
                }
            });
        }

        public T add_setting<T>(T setting)
        {
            settings.add((Widget) setting);
            return setting;
        }
    }

    public class SettingsGroupBox: Box
    {
        public string? title { get; construct; }

        private Label? title_label;
        public Box container;

        public SettingsGroupBox(string? title = null)
        {
            Object(title: title, orientation: Orientation.VERTICAL);
        }

        construct
        {
            get_style_context().add_class("settings-group");

            if(title != null)
            {
                title_label = new Label(title);
                title_label.get_style_context().add_class("title");
                title_label.ellipsize = Pango.EllipsizeMode.END;
                title_label.xalign = 0;
                add(title_label);
            }

            container = new Box(Orientation.VERTICAL, 0);
            container.get_style_context().add_class("settings-group-frame");
            container.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);
            container.get_style_context().add_class(Gtk.STYLE_CLASS_VIEW);
            add(container);
        }

        public T add_widget<T>(T widget)
        {
            container.add((Widget) widget);
            return widget;
        }
    }
}

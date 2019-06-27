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

namespace GameHub.UI.Widgets
{
	namespace StyleClass
	{
		namespace Label
		{
			public const string H1 = "h1";
			public const string H2 = "h2";
			public const string H3 = "h3";
			public const string H4 = "h4";
		}

		public const string CARD = "card";
		public const string BACK_BUTTON = "back-button";

		public void add(Widget widget, ...)
		{
			add_va(widget, va_list());
		}

		public void remove(Widget widget, ...)
		{
			remove_va(widget, va_list());
		}

		public void add_va(Widget widget, va_list classes)
		{
			var ctx = widget.get_style_context();
			for(string? class = classes.arg<string?>(); class != null; class = classes.arg<string?>())
			{
				ctx.add_class(class);
			}
		}

		public void remove_va(Widget widget, va_list classes)
		{
			var ctx = widget.get_style_context();
			for(string? class = classes.arg<string?>(); class != null; class = classes.arg<string?>())
			{
				ctx.remove_class(class);
			}
		}
	}

	namespace Styled
	{
		public Label Label(string? text, string main_class, va_list classes)
		{
			var label = new Gtk.Label(text);
			StyleClass.add(label, main_class);
			StyleClass.add_va(label, classes);
			return label;
		}

		public Label H1Label(string? text, ...)
		{
			return Styled.Label(text, StyleClass.Label.H1, va_list());
		}
		public Label H2Label(string? text, ...)
		{
			return Styled.Label(text, StyleClass.Label.H2, va_list());
		}
		public Label H3Label(string? text, ...)
		{
			return Styled.Label(text, StyleClass.Label.H3, va_list());
		}
		public Label H4Label(string? text, ...)
		{
			var label = Styled.Label(text, StyleClass.Label.H4, va_list());
			label.halign = Gtk.Align.START;
			label.xalign = 0;
			return label;
		}

		public Frame Card(string main_class, ...)
		{
			var card = new Frame(null);
			card.shadow_type = ShadowType.NONE;
			StyleClass.add(card, StyleClass.CARD);
			StyleClass.add(card, main_class);
			StyleClass.add_va(card, va_list());
			return card;
		}
	}
}

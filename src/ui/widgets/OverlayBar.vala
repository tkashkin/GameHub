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

/* Based on Granite.Widgets.OverlayBar */

using Gtk;

namespace GameHub.UI.Widgets
{
	public class OverlayBar: EventBox
	{
		private Label status_label;
		private Revealer revealer;
		private Spinner spinner;

		public string label
		{
			get
			{
				return status_label.label;
			}
			set
			{
			   status_label.label = value;
			}
		}

		public bool active
		{
			get
			{
				return spinner.active;
			}
			set
			{
				spinner.active = value;
				revealer.reveal_child = value;
			}
		}

		public OverlayBar(Overlay? overlay=null)
		{
			if(overlay != null)
			{
				overlay.add_events(Gdk.EventMask.ENTER_NOTIFY_MASK);
				overlay.add_overlay(this);
			}
		}

		construct
		{
			status_label = new Label("");
			status_label.set_ellipsize(Pango.EllipsizeMode.END);

			spinner = new Spinner();

			revealer = new Revealer();
			revealer.reveal_child = false;
			revealer.transition_type = RevealerTransitionType.SLIDE_LEFT;
			revealer.add(spinner);

			var grid = new Grid();
			StyleClass.add(grid, "overlay-bar");
			grid.add(status_label);
			grid.add(revealer);

			add(grid);

			set_halign(Align.END);
			set_valign(Align.END);

			var ctx = grid.get_style_context();
			var state = ctx.get_state();

			var padding = ctx.get_padding(state);
			status_label.margin_top = padding.top;
			status_label.margin_bottom = padding.bottom;
			status_label.margin_start = padding.left;
			status_label.margin_end = padding.right;
			spinner.margin_end = padding.right;

			var margin = ctx.get_margin(state);
			grid.margin_top = margin.top;
			grid.margin_bottom = margin.bottom;
			grid.margin_start = margin.left;
			grid.margin_end = margin.right;
		}

		public override void parent_set(Widget? old_parent)
		{
			Widget parent = get_parent();

			if(old_parent != null)
				old_parent.enter_notify_event.disconnect(enter_notify_callback);
			if(parent != null)
				parent.enter_notify_event.connect(enter_notify_callback);
		}

		private bool enter_notify_callback(Gdk.EventCrossing event)
		{
			if(get_halign() == Align.START)
				set_halign(Align.END);
			else
				set_halign(Align.START);

			queue_resize();

			return false;
		}
	}
}

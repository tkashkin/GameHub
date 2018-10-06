/*
This file is part of GameHub.
Copyright (C) 2018 Anatoliy Kashkin

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
using Granite;
using GameHub.Data;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views.GamesView
{
	public class DownloadProgressView: ListBoxRow
	{
		public Downloader.DownloadInfo dl_info;

		private Image? icon;
		private AutoSizeImage? image;

		private Image? type_icon;
		private AutoSizeImage? type_image;

		private Overlay image_overlay;

		private ProgressBar progress_bar;

		private Button action_pause;
		private Button action_resume;
		private Button action_cancel;

		public DownloadProgressView(Downloader.DownloadInfo info)
		{
			dl_info = info;

			selectable = false;

			var hbox = new Box(Orientation.HORIZONTAL, 8);
			hbox.margin = 8;
			var hbox_inner = new Box(Orientation.HORIZONTAL, 8);
			var hbox_actions = new Box(Orientation.HORIZONTAL, 0);
			hbox_actions.vexpand = false;
			hbox_actions.valign = Align.CENTER;

			var vbox = new Box(Orientation.VERTICAL, 0);
			var vbox_labels = new Box(Orientation.VERTICAL, 0);
			vbox_labels.hexpand = true;

			image_overlay = new Overlay();
			image_overlay.valign = Align.START;
			image_overlay.set_size_request(48, 48);

			if(dl_info.icon != null)
			{
				image = new AutoSizeImage();
				image.set_constraint(48, 48, 1);
				image.set_size_request(48, 48);
				Utils.load_image.begin(image, dl_info.icon, "icon");
				image_overlay.add(image);
			}
			else if(dl_info.icon_name != null)
			{
				icon = new Image.from_icon_name(dl_info.icon_name, IconSize.DIALOG);
				icon.set_size_request(48, 48);
				image_overlay.add(icon);
			}

			if(dl_info.type_icon != null)
			{
				type_image = new AutoSizeImage();
				type_image.set_constraint(16, 16, 1);
				type_image.set_size_request(16, 16);
				type_image.halign = Align.END;
				type_image.valign = Align.END;
				type_image.get_style_context().add_class("dl-progress-type-icon");
				Utils.load_image.begin(type_image, dl_info.type_icon, "icon");
				image_overlay.add_overlay(type_image);
			}
			else if(dl_info.type_icon_name != null)
			{
				type_icon = new Image.from_icon_name(dl_info.type_icon_name, IconSize.SMALL_TOOLBAR);
				type_icon.set_size_request(16, 16);
				type_icon.halign = Align.END;
				type_icon.valign = Align.END;
				type_icon.get_style_context().add_class("dl-progress-type-icon");
				image_overlay.add_overlay(type_icon);
			}

			hbox.add(image_overlay);

			var label = new Label(dl_info.name);
			label.halign = Align.START;
			label.get_style_context().add_class("category-label");
			label.ypad = 2;

			var desc_label = new Label(dl_info.description);
			desc_label.halign = Align.START;
			desc_label.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
			desc_label.ypad = 2;

			var state_label = new Label(null);
			state_label.halign = Align.START;

			progress_bar = new ProgressBar();
			progress_bar.hexpand = true;
			progress_bar.fraction = 0d;
			progress_bar.get_style_context().add_class(Gtk.STYLE_CLASS_OSD);

			action_pause = new Button.from_icon_name("media-playback-pause-symbolic");
			action_pause.tooltip_text = _("Pause download");
			action_pause.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			action_pause.visible = false;

			action_resume = new Button.from_icon_name("media-playback-start-symbolic");
			action_resume.tooltip_text = _("Resume download");
			action_resume.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			action_resume.visible = false;

			action_cancel = new Button.from_icon_name("process-stop-symbolic");
			action_cancel.tooltip_text = _("Cancel download");
			action_cancel.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			action_cancel.visible = false;

			vbox_labels.add(label);
			vbox_labels.add(desc_label);
			vbox_labels.add(state_label);

			hbox_inner.add(vbox_labels);
			hbox_inner.add(hbox_actions);

			hbox_actions.add(action_pause);
			hbox_actions.add(action_resume);
			hbox_actions.add(action_cancel);

			vbox.add(hbox_inner);
			vbox.add(progress_bar);

			hbox.add(vbox);

			child = hbox;

			dl_info.download.status_change.connect(s => {
				state_label.label = s.description;
				var ds = s.state;

				progress_bar.fraction = s.progress;

				action_cancel.visible = true;
				action_cancel.sensitive = ds == Downloader.DownloadState.DOWNLOADING || ds == Downloader.DownloadState.PAUSED;
				action_pause.visible = dl_info.download is Downloader.PausableDownload && ds != Downloader.DownloadState.PAUSED;
				action_resume.visible = dl_info.download is Downloader.PausableDownload && ds == Downloader.DownloadState.PAUSED;
			});

			action_cancel.clicked.connect(() => {
				dl_info.download.cancel();
			});

			action_pause.clicked.connect(() => {
				if(dl_info.download is Downloader.PausableDownload)
				{
					((Downloader.PausableDownload) dl_info.download).pause();
				}
			});

			action_resume.clicked.connect(() => {
				if(dl_info.download is Downloader.PausableDownload)
				{
					((Downloader.PausableDownload) dl_info.download).resume();
				}
			});

			Downloader.get_instance().dl_ended.connect(dl => {
				if(dl == dl_info) destroy();
			});

			show_all();
		}
	}
}

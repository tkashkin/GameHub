/*
This file is part of GameHub.
Copyright (C) Anatoliy Kashkin

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
using Gee;

using GameHub.Data;
using GameHub.Data.Runnables;
using GameHub.Data.Runnables.Tasks.Install;

using GameHub.Utils;

using GameHub.UI.Widgets;
using GameHub.UI.Widgets.Settings;

namespace GameHub.UI.Dialogs.InstallDialog
{
	public class InstallDialog: Dialog
	{
		public InstallTask task { get; construct; }
		private SourceFunc? callback = null;

		private HeaderBar headerbar;
		private Stack steps_stack;
		private Spinner loading_spinner;
		private Button back_button;
		private Button next_button;

		public InstallDialog(InstallTask task, owned SourceFunc? callback = null)
		{
			Object(resizable: false, use_header_bar: 1, title: task.runnable.name, task: task);
			this.callback = (owned) callback;
		}

		construct
		{
			set_size_request(800, 600);

			headerbar = (HeaderBar) get_header_bar();
			headerbar.has_subtitle = true;
			headerbar.show_close_button = true;

			back_button = new Button.from_icon_name("go-previous" + Settings.UI.Appearance.symbolic_icon_suffix, Settings.UI.Appearance.headerbar_icon_size);
			back_button.get_style_context().add_class("back-button");
			back_button.tooltip_text = _("Back");
			back_button.valign = Align.CENTER;
			back_button.sensitive = task.config_prev_step_available;
			headerbar.pack_start(back_button);

			if(task.runnable != null)
			{
				task.runnable.cast<Game>(game => {
					var icon = new AutoSizeImage();
					icon.valign = Align.CENTER;
					icon.set_constraint(36, 36);
					icon.load(game.icon, null, @"games/$(game.source.id)/$(game.id)/icons/");
					game.notify["icon"].connect(() => {
						Idle.add(() => {
							icon.load(game.icon, null, @"games/$(game.source.id)/$(game.id)/icons/");
							return Source.REMOVE;
						});
					});
					headerbar.pack_start(icon);
				});
			}

			next_button = new Button.with_label(_("Next"));
			next_button.valign = Align.CENTER;
			back_button.sensitive = task.config_next_step_available;
			headerbar.pack_end(next_button);

			steps_stack = new Stack();
			steps_stack.expand = true;
			steps_stack.transition_type = StackTransitionType.SLIDE_LEFT;
			steps_stack.vhomogeneous = false;
			steps_stack.interpolate_size = true;

			loading_spinner = new Spinner();
			loading_spinner.active = true;
			loading_spinner.set_size_request(36, 36);
			loading_spinner.halign = Align.CENTER;
			loading_spinner.valign = Align.CENTER;

			steps_stack.add_named(loading_spinner, InstallTask.ConfigStep.LOADING.to_string());
			steps_stack.visible_child = loading_spinner;

			get_content_area().add(steps_stack);

			show_all();

			task.notify["config-prev-step-available"].connect(() => {
				back_button.sensitive = task.config_prev_step_available;
			});

			task.notify["config-next-step-available"].connect(() => {
				next_button.sensitive = task.config_next_step_available;
			});

			task.notify["config-next-step"].connect(() => {
				if(task.config_next_step == InstallTask.ConfigStep.FINISH)
				{
					next_button.label = _("Install");
					next_button.get_style_context().add_class(Gtk.STYLE_CLASS_SUGGESTED_ACTION);
				}
				else
				{
					next_button.label = _("Next");
					next_button.get_style_context().remove_class(Gtk.STYLE_CLASS_SUGGESTED_ACTION);
				}
			});

			task.notify["config-step"].connect(() => set_step(task.config_step));
			set_step(task.config_step);

			back_button.clicked.connect(() => task.step_prev());
			next_button.clicked.connect(() => task.step_next());

			task.notify["cancelled"].connect(() => destroy());

			task.load_installers.begin();
		}

		private void set_step(InstallTask.ConfigStep step)
		{
			switch(step)
			{
				case InstallTask.ConfigStep.LOADING:
					steps_stack.set_visible_child_full(step.to_string(), StackTransitionType.CROSSFADE);
					headerbar.subtitle = null;
					next_button.visible = false;
					break;

				case InstallTask.ConfigStep.FINISH:
					destroy();
					task.install.begin();
					break;

				default:
					var dlg_step = create_or_find_step(step);
					if(dlg_step != null)
					{
						dlg_step.update();
						dlg_step.show_all();
						headerbar.subtitle = dlg_step.title;

						var transition = StackTransitionType.SLIDE_LEFT;
						if(steps_stack.visible_child == loading_spinner)
						{
							transition = StackTransitionType.CROSSFADE;
						}
						else if(task.config_step_last_change_direction == InstallTask.ConfigStepChangeDirection.PREVIOUS)
						{
							transition = StackTransitionType.SLIDE_RIGHT;
						}

						steps_stack.set_visible_child_full(step.to_string(), transition);
					}
					next_button.visible = true;
					break;
			}
		}

		private InstallDialogStep? create_or_find_step(InstallTask.ConfigStep step)
		{
			var existing_step = steps_stack.get_child_by_name(step.to_string());
			if(existing_step != null && existing_step is InstallDialogStep) return (InstallDialogStep) existing_step;

			InstallDialogStep? new_step = null;

			switch(step)
			{
				case InstallTask.ConfigStep.INSTALLER:
					new_step = new Steps.InstallerStep(task);
					break;

				case InstallTask.ConfigStep.INSTALL_DIR:
					new_step = new Steps.InstallDirStep(task);
					break;

				case InstallTask.ConfigStep.COMPAT_TOOL:
					new_step = new Steps.CompatToolStep(task);
					break;

				default:
					new_step = new DebugDummyStep(task, step);
					break;
			}

			if(new_step != null)
			{
				steps_stack.add_named(new_step, step.to_string());
			}

			return new_step;
		}
	}

	public abstract class InstallDialogStep: Box
	{
		public string title { get; protected construct set; }
		public InstallTask task { get; construct; }

		construct
		{
			orientation = Orientation.VERTICAL;
		}

		public virtual void update(){}

		protected void add_install_dir_import_button(Box parent)
		{
			var sgrp_import = new SettingsGroup();
			var import = sgrp_import.add_setting(new ButtonLabelSetting(_("Import installation directory if game is already installed"), _("Import")));
			parent.add(sgrp_import);

			var install_dir_chooser = new FileChooserNative(_("Select installation directory"), GameHub.UI.Windows.MainWindow.instance, FileChooserAction.SELECT_FOLDER, _("Import"), _("Cancel"));

			import.button.clicked.connect(() => {
				if(install_dir_chooser.run() == ResponseType.ACCEPT)
				{
					task.import_install_dir(install_dir_chooser.get_file());
				}
			});
		}
	}

	public class DebugDummyStep: InstallDialogStep
	{
		public DebugDummyStep(InstallTask task, InstallTask.ConfigStep step)
		{
			Object(task: task, title: step.to_string().replace("GAME_HUB_DATA_RUNNABLES_TASKS_INSTALL_INSTALL_TASK_CONFIG_STEP_", ""));
			warning("[DebugDummyStep] %s", step.to_string());
		}

		construct
		{
			var label = Styled.H1Label(title);
			label.expand = true;
			child = label;
		}
	}
}

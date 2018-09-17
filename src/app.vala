using Gtk;
using Gdk;
using Granite;

using GameHub.Data;
using GameHub.Data.DB;
using GameHub.Data.Sources.Steam;
using GameHub.Data.Sources.GOG;
using GameHub.Data.Sources.Humble;
using GameHub.Utils;

namespace GameHub
{
	public class Application: Granite.Application
	{
		construct
		{
			application_id = ProjectConfig.PROJECT_NAME;
			flags = ApplicationFlags.FLAGS_NONE;
			program_name = "GameHub";
			build_version = ProjectConfig.VERSION;
		}

		protected override void activate()
		{
			info("Distro: %s", Utils.get_distro());

			FSUtils.make_dirs();

			Database.create();

			Platforms = { Platform.LINUX, Platform.WINDOWS, Platform.MACOS };
			CurrentPlatform = Platform.LINUX;

			GameSources = { new Steam(), new GOG(), new Humble(), new Trove() };

			CompatTool[] tools = { new Compat.CustomScript(), new Compat.Innoextract(), new Compat.DOSBox() };
			foreach(var appid in Compat.Proton.APPIDS)
			{
				tools += new Compat.Proton(appid);
			}
			tools += new Compat.Wine("wine64");
			tools += new Compat.Wine("wine");
			CompatTools = tools;

			weak IconTheme default_theme = IconTheme.get_default();
			default_theme.add_resource_path("/com/github/tkashkin/gamehub/icons");

			var provider = new CssProvider();
			provider.load_from_resource("/com/github/tkashkin/gamehub/GameHub.css");
			StyleContext.add_provider_for_screen(Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

			new GameHub.UI.Windows.MainWindow(this).show_all();
		}

		public static int main(string[] args)
		{
			var app = new Application();

			var lang = Environment.get_variable("LC_ALL") ?? "";
			Intl.setlocale(LocaleCategory.ALL, lang);
			Intl.bindtextdomain(ProjectConfig.GETTEXT_PACKAGE, ProjectConfig.GETTEXT_DIR);
			Intl.textdomain(ProjectConfig.GETTEXT_PACKAGE);

			return app.run(args);
		}
	}
}

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
using GLib;
using Soup;
using GameHub.Utils;

#if WEBKIT2GTK
using WebKit;
#endif

namespace GameHub.UI.Windows
{
	public class WebAuthWindow: Window
	{
		#if WEBKIT2GTK
		public WebView webview;
		#endif

		private bool is_finished = false;

		public signal void finished(string url);
		public signal void pageLoaded(string page);
		public signal void canceled();

		private const string GOG_CSS = "body { background-color: #d2d2d2 !important; } ._modal__box { box-shadow: none !important; vertical-align: top !important; margin-top: 0 !important; } ._modal__control, .form__buttons-container, .form__separator { display: none !important; }";
		private const string HUMBLE_CSS = ".banner, .navigation-container-v2, .simple-white-navbar, .tabbar, .site-footer, .evidon-banner, .inner-main-wrapper > *:not(.js-login-form), .options-divider, .ssi-options, .footer-section { display:none !important; } body { overflow: hidden !important; }";

		public WebAuthWindow(string source, string url, string? success_url_prefix=null, string? success_cookie_name=null)
		{
			Object(transient_for: Windows.MainWindow.instance);

			title = source;
			var titlebar = new HeaderBar();
			titlebar.title = title;
			titlebar.show_close_button = true;
			set_titlebar(titlebar);

			var spinner = new Spinner();
			titlebar.pack_end(spinner);

			set_size_request(640, 800);

			set_modal(true);

			if(GameHub.Application.log_auth)
			{
				debug("[WebAuth/%s] Authenticating at `%s`; success_url_prefix: `%s`; success_cookie_name: `%s`", source, url, success_url_prefix, success_cookie_name);
			}

			#if WEBKIT2GTK
			webview = new WebView();

			var cookies_file = FSUtils.expand(FSUtils.Paths.Cache.Cookies);
			webview.web_context.get_cookie_manager().set_persistent_storage(cookies_file, CookiePersistentStorage.TEXT);

			webview.get_settings().enable_mediasource = true;
			webview.get_settings().enable_smooth_scrolling = true;
			webview.get_settings().hardware_acceleration_policy = HardwareAccelerationPolicy.NEVER;

			webview.user_content_manager.add_style_sheet(new UserStyleSheet(GOG_CSS, UserContentInjectedFrames.TOP_FRAME, UserStyleLevel.USER, {"https://*.gog.com/*"}, null));
			webview.user_content_manager.add_style_sheet(new UserStyleSheet(HUMBLE_CSS, UserContentInjectedFrames.TOP_FRAME, UserStyleLevel.USER, {"https://*.humblebundle.com/*"}, null));

			webview.load_changed.connect(e => {
				var uri = webview.get_uri();
				if(uri == null) return;

				titlebar.title = webview.title;
				titlebar.subtitle = uri.split("?")[0];
				titlebar.tooltip_text = uri;

				spinner.active = e != LoadEvent.FINISHED;

				if(GameHub.Application.log_auth)
				{
					debug("[WebAuth/%s] URI: `%s`", source, uri);
				}

				if(!is_finished && success_cookie_name != null)
				{
					webview.web_context.get_cookie_manager().get_cookies.begin(uri, null, (obj, res) => {
						try
						{
							var cookies = webview.web_context.get_cookie_manager().get_cookies.end(res);
							foreach(var cookie in cookies)
							{
								if(GameHub.Application.log_auth)
								{
									debug("[WebAuth/%s] [Cookie] `%s`=`%s`", source, cookie.name, cookie.value);
								}
								if(!is_finished && cookie.name == success_cookie_name && (success_url_prefix == null || uri.has_prefix(success_url_prefix)))
								{
									is_finished = true;
									var token = cookie.value;
									if(GameHub.Application.log_auth)
									{
										debug("[WebAuth/%s] Finished with result `%s`", source, token);
									}
									finished(token);
									destroy();
									break;
								}
							}
						}
						catch(Error e){}
					});
				}
				else if(!is_finished && success_url_prefix != null && uri.has_prefix(success_url_prefix))
				{
					is_finished = true;
					var token = uri.substring(success_url_prefix.length);
					if(GameHub.Application.log_auth)
					{
						debug("[WebAuth/%s] Finished with result `%s`", source, token);
					}
					finished(token);

					//Execute javascript to extract page source
					runJavascript.begin ("document.body.childNodes[0].textContent", (obj, res) => {
						pageLoaded(runJavascript.end (res).get_js_value().to_string());
						destroy();
					});
				}


			});

			webview.load_uri(url);

			add(webview);
			
			#endif

			destroy.connect(() => { if(!is_finished) canceled(); });
		}

		private async WebKit.JavascriptResult runJavascript(string script) {
			return yield webview.run_javascript(script);
		}
		

	}
}

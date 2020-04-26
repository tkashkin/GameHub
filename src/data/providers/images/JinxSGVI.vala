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

using Gee;

using GameHub.Data.Runnables;
using GameHub.Utils;

namespace GameHub.Data.Providers.Images
{
	public class JinxSGVI: ImagesProvider
	{
		private const string BASE_URL = "https://steam.cryotank.net";

		public override string id   { get { return "jinx_sgvi"; } }
		public override string name { get { return "Jinx's Steam Grid View Images"; } }
		public override string url  { get { return BASE_URL; } }

		public override bool enabled
		{
			get { return Settings.Providers.Images.JinxSGVI.instance.enabled; }
			set { Settings.Providers.Images.JinxSGVI.instance.enabled = value; }
		}

		public override async ArrayList<ImagesProvider.Result> images(Game game)
		{
			var results = new ArrayList<ImagesProvider.Result>();
			results.add(new Result(this, game));
			return results;
		}

		public class Result: ImagesProvider.Result
		{
			private Game game;
			private ArrayList<ImagesProvider.Image>? images = null;

			public Result(JinxSGVI source, Game game)
			{
				this.game = game;
				provider = source;
				name = "%s: %s".printf(source.name, game.name);
				title = source.name;
				subtitle = game.name;
				url = JinxSGVI.BASE_URL + "/?s=" + Uri.escape_string(game.name);
			}

			public override async ArrayList<ImagesProvider.Image>? load_images()
			{
				if(images != null) return images;
				images = new ArrayList<ImagesProvider.Image>();
				yield parse_page(url);
				return images;
			}

			private async void parse_page(string url)
			{
				var html = yield Parser.parse_remote_html_file_async(url, "GET");
				if(html == null) return;

				var xpath = new Xml.XPath.Context(html);

				var galleries = xpath.eval("//div[contains(@class,'ngg-galleryoverview')]")->nodesetval;
				if(galleries != null && galleries->length() > 0)
				{
					for(int g = 0; g < galleries->length(); g++)
					{
						var gallery = galleries->item(g);
						xpath.node = gallery;

						var imgs = xpath.eval("div/div[@class='ngg-gallery-thumbnail']/a")->nodesetval;
						if(imgs != null && imgs->length() > 0)
						{
							for(int i = 0; i < imgs->length(); i++)
							{
								var img = imgs->item(i);
								if(img == null) continue;
								this.images.add(new ImagesProvider.Image(img->get_prop("data-src"), img->get_prop("data-title")));
							}
						}

						var next_page = xpath.eval("div[@class='ngg-navigation']/a[@class='next']")->nodesetval;
						if(next_page != null && next_page->length() > 0)
						{
							var next_page_url = next_page->item(0)->get_prop("href").strip();
							if(next_page_url != null)
							{
								yield parse_page(next_page_url);
							}
						}
					}
				}
				delete html;
			}
		}
	}
}

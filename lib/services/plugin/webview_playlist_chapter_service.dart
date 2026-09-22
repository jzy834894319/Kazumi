import 'dart:async';
import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:kazumi/modules/roads/road_module.dart';
import 'package:kazumi/utils/episode_url.dart';
import 'package:kazumi/webview/captcha/captcha_webview_controller.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';

/// Resolves a two-step playlist flow in a real WebView:
///
/// source/watch page -> playlist link -> playlist page -> episode links.
///
/// This is useful for sites whose anti-crawler layer rejects normal HTTP
/// chapter requests even after browser verification.
class WebViewPlaylistChapterService {
  const WebViewPlaylistChapterService();

  Future<List<Road>> resolve({
    required String baseUrl,
    required String source,
    required String playlistLinkXpath,
    required String episodeXpath,
  }) async {
    final sourceUrl = normalizeEpisodeUrl(baseUrl, source);
    final sourceUri = Uri.tryParse(sourceUrl);
    if (sourceUri == null || !sourceUri.hasScheme || sourceUri.host.isEmpty) {
      throw FormatException('播放页地址无效: $sourceUrl');
    }

    final controller = CaptchaWebviewControllerFactory.getController();
    try {
      final initialized = controller.onInitialized.first.timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );
      await controller.init();
      if (!await initialized) {
        throw TimeoutException('WebView 初始化超时');
      }

      final sourceHtml = await _loadAndHarvest(
        controller,
        sourceUrl,
        waitXpath: playlistLinkXpath,
        allowMissingAfter: const Duration(seconds: 2),
      );

      final playlistHref = _firstHref(sourceHtml, playlistLinkXpath);
      if (playlistHref == null || playlistHref.isEmpty) {
        return _singleEpisode(sourceUrl);
      }

      final playlistUrl = normalizeEpisodeUrl(sourceUrl, playlistHref);
      final playlistHtml = await _loadAndHarvest(
        controller,
        playlistUrl,
        waitXpath: episodeXpath,
      );

      final episodes = _episodesFromHtml(
        playlistHtml,
        episodeXpath,
        playlistUrl,
      );
      if (episodes.$1.isEmpty) {
        return _singleEpisode(sourceUrl);
      }

      return [
        Road(
          name: '播放线路1',
          data: episodes.$1,
          identifier: episodes.$2,
        ),
      ];
    } finally {
      controller.dispose();
    }
  }

  Future<String> _loadAndHarvest(
    CaptchaWebviewController controller,
    String url, {
    required String waitXpath,
    Duration? allowMissingAfter,
  }) async {
    final done = controller.onCaptchaDisappeared.first;
    final escapedXpath = jsonEncode(waitXpath);
    final allowMissingMs = allowMissingAfter?.inMilliseconds;

    final script = '''
var __kazumiXpath = $escapedXpath;
var __kazumiStarted = Date.now();
var __kazumiAllowMissingMs = ${allowMissingMs ?? -1};
var __kazumiTimer = setInterval(function() {
  try {
    var result = document.evaluate(
      __kazumiXpath,
      document,
      null,
      XPathResult.FIRST_ORDERED_NODE_TYPE,
      null
    );
    if (result.singleNodeValue ||
        (__kazumiAllowMissingMs >= 0 &&
         Date.now() - __kazumiStarted >= __kazumiAllowMissingMs)) {
      clearInterval(__kazumiTimer);
      KazumiCaptcha.done();
    }
  } catch (e) {
    clearInterval(__kazumiTimer);
    KazumiCaptcha.fail(e && e.message ? e.message : e);
  }
}, 200);
''';

    await controller.loadPageForCustomScript(url, script);
    await done.timeout(const Duration(seconds: 12));
    return controller.getPageHtml();
  }

  String? _firstHref(String raw, String xpath) {
    if (raw.trim().isEmpty || xpath.trim().isEmpty) return null;
    final root = parse(raw).documentElement;
    if (root == null) return null;
    final node = root.queryXPath(xpath).node?.node;
    if (node is! Element) return null;
    return node.attributes['href']?.trim();
  }

  (List<String>, List<String>) _episodesFromHtml(
    String raw,
    String xpath,
    String pageUrl,
  ) {
    if (raw.trim().isEmpty || xpath.trim().isEmpty) {
      return (<String>[], <String>[]);
    }
    final root = parse(raw).documentElement;
    if (root == null) return (<String>[], <String>[]);

    final urls = <String>[];
    final names = <String>[];
    final seen = <String>{};
    final nodes = root.queryXPath(xpath).nodes;

    for (final result in nodes) {
      final node = result.node;
      if (node is! Element) continue;
      final href = node.attributes['href']?.trim() ?? '';
      if (href.isEmpty) continue;
      final url = normalizeEpisodeUrl(pageUrl, href);
      if (!seen.add(url)) continue;

      final title = node.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      urls.add(url);
      names.add(title.isEmpty ? '第${urls.length}集' : title);
    }
    return (urls, names);
  }

  List<Road> _singleEpisode(String url) => [
        Road(
          name: '播放线路1',
          data: [url],
          identifier: const ['第1集'],
        ),
      ];
}

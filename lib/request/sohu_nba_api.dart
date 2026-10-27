import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nba_games/models/third_party_news_model.dart';

/// 搜狐体育 NBA（https://sports.sohu.com/s/nba）
/// 列表走搜狐体育主力号稿件流。
class SohuNbaApi {
  SohuNbaApi._();

  static const authorId = '458722';
  static const _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://sports.sohu.com/s/nba',
      },
    ),
  );

  static Future<ThirdPartyNewsPage> getNews({int page = 1}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://v2.sohu.com/author-page-api/author-articles/pc/$authorId',
        queryParameters: {'pNo': page},
      );
      final body = res.data;
      if (body == null || body['code'] != 200 || body['data'] is! Map) {
        throw StateError('搜狐 NBA 列表异常');
      }
      final data = Map<String, dynamic>.from(body['data'] as Map);
      final raw = data['pcArticleVOS'];
      final items = <ThirdPartyNewsItem>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is! Map) continue;
          final map = Map<String, dynamic>.from(e);
          final id = map['id']?.toString() ?? '';
          final title = (map['title'] ?? map['mobileTitle'] ?? '')
              .toString()
              .trim();
          if (id.isEmpty || title.isEmpty) continue;
          final userId = map['userId']?.toString() ?? authorId;
          var cover = map['cover']?.toString() ?? '';
          if (cover.startsWith('//')) cover = 'https:$cover';
          var link = map['link']?.toString() ?? '';
          if (link.startsWith('www.')) link = 'https://$link';
          if (link.isEmpty) {
            link = 'https://www.sohu.com/a/${id}_$userId';
          }
          DateTime? published;
          final pt = map['publicTime']?.toString();
          if (pt != null && pt.isNotEmpty) {
            published = DateTime.tryParse(pt)?.toLocal();
          }
          items.add(ThirdPartyNewsItem(
            id: id,
            title: title,
            summary: map['brief']?.toString() ?? '',
            pic: cover,
            url: link,
            publishedAt: published,
            source: ThirdPartyNewsSource.sohu,
          ));
        }
      }
      return ThirdPartyNewsPage(
        items: items,
        hasMore: items.length >= 15,
        nextCursor: '${page + 1}',
      );
    } catch (e, st) {
      debugPrint('[SohuNbaApi] getNews failed: $e\n$st');
      rethrow;
    }
  }

  static Future<ThirdPartyNewsDetail> getDetail(ThirdPartyNewsItem item) async {
    try {
      final res = await _dio.get<String>(
        item.url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Accept': 'text/html,application/xhtml+xml'},
        ),
      );
      final html = res.data ?? '';
      final paragraphs = <String>[];
      final images = <String>[];
      final pRe = RegExp(r'<p[^>]*>([\s\S]*?)</p>', caseSensitive: false);
      for (final m in pRe.allMatches(html)) {
        final text = _stripHtml(m.group(1) ?? '').trim();
        if (text.length >= 8) paragraphs.add(text);
      }
      final imgRe = RegExp(
        r'''<img[^>]+src=["']([^"']+)["']''',
        caseSensitive: false,
      );
      for (final m in imgRe.allMatches(html)) {
        var src = m.group(1) ?? '';
        if (src.startsWith('//')) src = 'https:$src';
        if (src.startsWith('http') &&
            (src.contains('itc.cn') || src.contains('sohu'))) {
          if (!images.contains(src)) images.add(src);
        }
      }
      return ThirdPartyNewsDetail(
        id: item.id,
        title: item.title,
        source: ThirdPartyNewsSource.sohu,
        url: item.url,
        author: '搜狐体育',
        publishedAt: item.publishedAt,
        paragraphs: paragraphs.take(40).toList(growable: false),
        images: images.take(12).toList(growable: false),
      );
    } catch (e, st) {
      debugPrint('[SohuNbaApi] getDetail failed: $e\n$st');
      return ThirdPartyNewsDetail(
        id: item.id,
        title: item.title,
        source: ThirdPartyNewsSource.sohu,
        url: item.url,
        author: '搜狐体育',
        publishedAt: item.publishedAt,
        paragraphs: [
          if (item.summary.trim().isNotEmpty) item.summary.trim(),
        ],
        images: item.pic.isNotEmpty ? [item.pic] : const [],
      );
    }
  }

  static String _stripHtml(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nba_games/models/third_party_news_model.dart';

/// 虎扑 NBA（https://m.hupu.com/nba）
class HupuNbaApi {
  HupuNbaApi._();

  static const _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://m.hupu.com/nba',
      },
    ),
  );

  static Future<ThirdPartyNewsPage> getNews({String? cursorNid}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://games.mobileapi.hupu.com/1/7.5.55/nba/getNews',
        queryParameters: {
          'offline': 'json',
          'client': '340',
          if (cursorNid != null && cursorNid.isNotEmpty) ...{
            'direc': 'next',
            'nid': cursorNid,
          },
        },
      );
      final body = res.data;
      final result = body?['data'] is Map
          ? Map<String, dynamic>.from(body!['data'] as Map)['result']
          : null;
      if (result is! Map) throw StateError('虎扑 NBA 列表异常');
      final map = Map<String, dynamic>.from(result);
      final raw = map['data'];
      final items = <ThirdPartyNewsItem>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is! Map) continue;
          final row = Map<String, dynamic>.from(e);
          final nid = row['nid']?.toString() ?? '';
          final title = row['title']?.toString().trim() ?? '';
          if (nid.isEmpty || title.isEmpty) continue;
          final tid = _topicIdFromSchema(
            row['schema']?.toString() ?? row['link']?.toString() ?? '',
          );
          final url = tid.isNotEmpty
              ? 'https://m.hupu.com/bbs/$tid'
              : 'https://m.hupu.com/nba';
          DateTime? published;
          final up = int.tryParse(row['uptime']?.toString() ?? '');
          if (up != null && up > 0) {
            published = DateTime.fromMillisecondsSinceEpoch(
              up * 1000,
              isUtc: true,
            ).toLocal();
          }
          items.add(ThirdPartyNewsItem(
            id: nid,
            title: title,
            summary: (row['summary']?.toString() ?? '').trim(),
            pic: row['img']?.toString() ?? '',
            url: url,
            publishedAt: published,
            source: ThirdPartyNewsSource.hupu,
            replyNum: int.tryParse(row['replies']?.toString() ?? '') ?? 0,
            lights: int.tryParse(row['lights']?.toString() ?? '') ?? 0,
          ));
        }
      }
      final hasMore = map['nextDataExists'] == 1 || map['nextDataExists'] == true;
      return ThirdPartyNewsPage(
        items: items,
        hasMore: hasMore && items.isNotEmpty,
        nextCursor: items.isNotEmpty ? items.last.id : null,
      );
    } catch (e, st) {
      debugPrint('[HupuNbaApi] getNews failed: $e\n$st');
      rethrow;
    }
  }

  static String _topicIdFromSchema(String schema) {
    final m = RegExp(r'topic/(\d+)').firstMatch(schema);
    return m?.group(1) ?? '';
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
        if (src.startsWith('http') && src.contains('hoopchina')) {
          if (!images.contains(src)) images.add(src);
        }
      }
      // 去掉重复标题首段
      final paras = paragraphs
          .where((p) => p != item.title)
          .take(40)
          .toList(growable: false);
      return ThirdPartyNewsDetail(
        id: item.id,
        title: item.title,
        source: ThirdPartyNewsSource.hupu,
        url: item.url,
        author: '虎扑NBA',
        publishedAt: item.publishedAt,
        paragraphs: paras,
        images: images.take(12).toList(growable: false),
      );
    } catch (e, st) {
      debugPrint('[HupuNbaApi] getDetail failed: $e\n$st');
      return ThirdPartyNewsDetail(
        id: item.id,
        title: item.title,
        source: ThirdPartyNewsSource.hupu,
        url: item.url,
        author: '虎扑NBA',
        publishedAt: item.publishedAt,
        paragraphs: [
          if (item.summary.trim().isNotEmpty && item.summary.trim() != '。')
            item.summary.trim(),
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

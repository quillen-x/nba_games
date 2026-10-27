import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nba_games/models/nba_news_model.dart';

/// 腾讯体育 NBA 热点资讯（与 https://sports.qq.com/nba 同源）
class TencentNbaNewsApi {
  TencentNbaNewsApi._();

  /// HotNews 组件 NBA 分类 tabID
  static const nbaTabId = '101';
  static const _base = 'https://app.sports.qq.com';
  /// 社区帖详情（与 fans.sports.qq.com/post.htm 同源）
  static const _shequBase = 'https://shequweb.sports.qq.com';
  static const _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://sports.qq.com/nba',
        'Origin': 'https://sports.qq.com',
        'Content-Type': 'application/json',
      },
    ),
  );

  static final Dio _shequDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://fans.sports.qq.com/',
        'Origin': 'https://fans.sports.qq.com',
      },
    ),
  );

  /// 拉取热点资讯；[contextData] 非空时加载下一页
  static Future<NbaNewsPage> getHotNews({
    String? contextData,
    int listNum = 15,
  }) async {
    try {
      final more = (contextData ?? '').trim().isNotEmpty;
      final res = await _dio.post<Map<String, dynamic>>(
        '$_base/feeds/authority/list',
        data: {
          'tabID': nbaTabId,
          'listNum': more ? '12' : '$listNum',
          if (more) 'contextData': contextData,
        },
      );
      final body = res.data;
      if (body == null || body['code'] != 0 || body['data'] is! Map) {
        throw StateError('腾讯热点资讯接口异常');
      }
      final data = Map<String, dynamic>.from(body['data'] as Map);
      final items = <NbaNewsItem>[];
      final seen = <String>{};

      void addAll(dynamic raw, {required bool hot}) {
        if (raw is! List) return;
        for (final e in raw) {
          if (e is! Map) continue;
          final map = Map<String, dynamic>.from(e);
          final detail = map['type1011'];
          if (detail is! Map) continue;
          final item = NbaNewsItem.fromType1011(
            Map<String, dynamic>.from(detail),
            isHot: hot,
          );
          if (item.id.isEmpty || item.title.isEmpty) continue;
          if (!seen.add(item.id)) continue;
          items.add(item);
        }
      }

      if (!more) {
        addAll(data['topItem'], hot: true);
      }
      addAll(data['list'], hot: false);

      // 按发布时间倒序（新→旧）；无时间的排后面
      items.sort((a, b) {
        final at = a.publishedAt;
        final bt = b.publishedAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });

      final nextCtx = data['contextData']?.toString();
      final hasMore = data['hasMore'] == true &&
          nextCtx != null &&
          nextCtx.trim().isNotEmpty;

      return NbaNewsPage(
        items: items,
        contextData: hasMore ? nextCtx : null,
        hasMore: hasMore,
      );
    } catch (e, st) {
      debugPrint('[TencentNbaNewsApi] getHotNews failed: $e\n$st');
      rethrow;
    }
  }

  /// 社区帖详情：https://fans.sports.qq.com/post.htm?id=...&mid=...
  static Future<NbaTopicDetail> getTopicDetail(String tid) async {
    final id = tid.trim();
    if (id.isEmpty) throw StateError('帖子 id 为空');
    try {
      final res = await _shequDio.get<Map<String, dynamic>>(
        '$_shequBase/topic/detail',
        queryParameters: {'tid': id},
      );
      final body = res.data;
      if (body == null || body['code'] != 0 || body['data'] is! Map) {
        throw StateError('社区帖详情接口异常');
      }
      final detail = NbaTopicDetail.fromApi(
        Map<String, dynamic>.from(body['data'] as Map),
      );
      if (detail.id.isEmpty) throw StateError('帖子不存在');
      return detail;
    } catch (e, st) {
      debugPrint('[TencentNbaNewsApi] getTopicDetail failed: $e\n$st');
      rethrow;
    }
  }
}

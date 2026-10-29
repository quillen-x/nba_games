import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nba_games/models/x_post_model.dart';

class XFeedException implements Exception {
  XFeedException(this.message);
  final String message;

  @override
  String toString() => message;
}

class _UserFeedResult {
  const _UserFeedResult({
    required this.ok,
    required this.posts,
    this.error,
  });

  final bool ok;
  final List<XPost> posts;
  final Object? error;
}

/// 通过 api.fxtwitter.com 拉取 X 动态（与 media_downloader 同源）
class XFeedService {
  XFeedService();

  static const _translateLang = 'zh-cn';
  static const _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  static const _recentBatchSize = 8;

  /// 已探测可用的代理；`null` 表示尚未探测，`''` 表示直连可用
  static String? _resolvedProxy;
  static final Map<String, String> _translationCache = <String, String>{};
  static final Map<String, Future<String>> _translationPending =
      <String, Future<String>>{};

  /// 拉取图片等二进制（走与动态相同的代理探测）
  static Future<Uint8List> fetchBytes(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw XFeedException('无效图片地址');
    }
    final service = XFeedService();
    return service._getBytes(uri);
  }

  static String? cachedTranslation(String postId) {
    final text = _translationCache[postId.trim()];
    if (text == null || text.isEmpty) return null;
    return text;
  }

  /// 按帖拉取中文翻译（fxtwitter /2/status + lang=zh-cn）
  Future<String> fetchPostTranslation(String postId) async {
    final id = postId.trim();
    if (id.isEmpty || !RegExp(r'^\d{2,20}$').hasMatch(id)) return '';
    final cached = cachedTranslation(id);
    if (cached != null) return cached;
    final pending = _translationPending[id];
    if (pending != null) return pending;
    final future = _loadPostTranslation(id);
    _translationPending[id] = future;
    try {
      final text = await future;
      if (text.isNotEmpty) _translationCache[id] = text;
      return text;
    } finally {
      _translationPending.remove(id);
    }
  }

  Future<String> _loadPostTranslation(String id) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
      }
      try {
        final uri = Uri.parse(
          'https://api.fxtwitter.com/2/status/${Uri.encodeComponent(id)}',
        ).replace(queryParameters: _query(const <String, String>{}));
        final body = await _getRaw(uri);
        if (body.trim().isEmpty) continue;
        final json = jsonDecode(body) as Map<String, dynamic>;
        if ((json['code'] as num?)?.toInt() != 200) continue;
        final status = json['status'];
        if (status is! Map) continue;
        final text = _parseTranslation(status['translation']);
        if (text.isNotEmpty) return text;
      } catch (_) {
        // 重试
      }
    }
    return '';
  }

  Map<String, String> _query(Map<String, String> params) {
    return <String, String>{...params, 'lang': _translateLang};
  }

  Future<XPostPage> fetchPostsPage(
    String username, {
    String? cursor,
    int count = 10,
  }) async {
    final current = (cursor ?? '').trim();
    try {
      final query = _query(<String, String>{
        'count': '${count.clamp(1, 100)}',
      });
      if (current.isNotEmpty) {
        query['cursor'] = current;
      }
      final uri = Uri.parse(
        'https://api.fxtwitter.com/2/profile/${Uri.encodeComponent(username)}/statuses',
      ).replace(queryParameters: query);
      final body = await _getRaw(uri);
      if (body.trim().isEmpty) {
        return const XPostPage(posts: <XPost>[], cursor: null);
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      if ((json['code'] as num?)?.toInt() != 200) {
        throw XFeedException('动态请求失败。');
      }
      final posts = _parseStatusList(json['results'], username);
      var next = _cursorBottom(json['cursor']);
      if (posts.isEmpty || next == current) {
        next = null;
      }
      return XPostPage(posts: posts, cursor: next);
    } catch (_) {
      if (current.isNotEmpty) {
        return const XPostPage(posts: <XPost>[], cursor: null);
      }
      rethrow;
    }
  }

  /// 聚合多账号近期动态：按赞数排序，边拉边回调 [onProgress]
  Future<List<XPost>> fetchRecentFeed(
    List<String> usernames, {
    void Function(List<XPost> posts, int done, int total)? onProgress,
    int hours = 24,
    int perUser = 5,
    int minLikes = 0,
  }) async {
    if (usernames.isEmpty) return <XPost>[];

    final maxAge = Duration(hours: hours.clamp(1, 720));
    final cap = perUser.clamp(1, 50);
    final likesMin = minLikes < 0 ? 0 : minLikes;
    final fetchCount = likesMin > 0 ? (cap * 6).clamp(cap, 50) : cap;
    final posts = <XPost>[];
    final seen = <String>{};
    final total = usernames.length;
    var okCount = 0;
    Object? lastError;

    for (var start = 0; start < total; start += _recentBatchSize) {
      final end = start + _recentBatchSize > total
          ? total
          : start + _recentBatchSize;
      final chunk = usernames.sublist(start, end);
      final results = await Future.wait(
        chunk.map((name) async {
          try {
            final page = await fetchPostsPage(name, count: fetchCount);
            final filtered = page.posts.where((post) {
              if (!_isRecent(post, maxAge)) return false;
              if (likesMin > 0 && post.likes <= likesMin) return false;
              return true;
            }).take(cap).toList();
            return _UserFeedResult(ok: true, posts: filtered);
          } catch (e) {
            return _UserFeedResult(ok: false, posts: <XPost>[], error: e);
          }
        }),
      );
      for (final r in results) {
        if (r.ok) {
          okCount++;
        } else {
          lastError = r.error;
        }
        for (final post in r.posts) {
          if (seen.add(post.id)) posts.add(post);
        }
      }
      posts.sort(_compareByLikes);
      onProgress?.call(List<XPost>.from(posts), end, total);
    }

    if (okCount == 0 && lastError != null) {
      final err = lastError;
      if (err is XFeedException) throw err;
      throw XFeedException('成员动态请求失败：$err');
    }
    return posts;
  }

  bool _isRecent(XPost post, Duration maxAge) {
    final time = post.publishedAt;
    if (time == null) return false;
    return !time.isBefore(DateTime.now().subtract(maxAge));
  }

  int _compareByLikes(XPost a, XPost b) {
    final likes = b.likes.compareTo(a.likes);
    if (likes != 0) return likes;
    final at = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bt = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bt.compareTo(at);
  }

  String? _cursorBottom(dynamic raw) {
    if (raw is! Map) return null;
    final bottom = raw['bottom'];
    if (bottom == null) return null;
    final text = '$bottom'.trim();
    if (text.isEmpty || text == 'null') return null;
    return text;
  }

  List<XPost> _parseStatusList(dynamic raw, String username) {
    if (raw is! List) return <XPost>[];
    final posts = <XPost>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      if ('${map['type']}' != 'status') continue;
      final id = '${map['id'] ?? ''}';
      if (id.isEmpty) continue;

      final author = map['author'];
      var handle = username;
      var avatar = '';
      var name = '';
      if (author is Map) {
        if ('${author['screen_name'] ?? ''}'.isNotEmpty) {
          handle = '${author['screen_name']}';
        }
        avatar =
            '${author['avatar_url'] ?? ''}'.replaceFirst('_normal', '_400x400');
        name = '${author['name'] ?? ''}'.trim();
      }

      DateTime? published;
      final timestamp = map['created_timestamp'];
      if (timestamp is num && timestamp > 0) {
        published = DateTime.fromMillisecondsSinceEpoch(
          (timestamp * 1000).round(),
          isUtc: true,
        ).toLocal();
      }

      posts.add(XPost(
        id: id,
        username: handle,
        text: '${map['text'] ?? map['raw_text'] ?? ''}'.trim(),
        url: '${map['url'] ?? 'https://x.com/$handle/status/$id'}',
        publishedAt: published,
        media: _parseMedia(map['media']),
        translation: _parseTranslation(map['translation']),
        lang: '${map['lang'] ?? ''}'.trim(),
        avatarUrl: avatar,
        authorName: name,
        likes: (map['likes'] as num?)?.toInt() ?? 0,
        views: (map['views'] as num?)?.toInt() ?? 0,
      ));
    }
    return posts;
  }

  String _parseTranslation(dynamic raw) {
    if (raw is Map) return '${raw['text'] ?? ''}'.trim();
    return '';
  }

  List<XMedia> _parseMedia(dynamic raw) {
    if (raw is! Map) return const <XMedia>[];
    final items = raw['all'] is List
        ? List<dynamic>.from(raw['all'] as List)
        : <dynamic>[
            ...raw['photos'] is List
                ? List<dynamic>.from(raw['photos'] as List)
                : const <dynamic>[],
            ...raw['videos'] is List
                ? List<dynamic>.from(raw['videos'] as List)
                : const <dynamic>[],
          ];
    final media = <XMedia>[];
    for (final item in items) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final type = '${map['type'] ?? ''}';
      final XMediaKind kind;
      if (type == 'video') {
        kind = XMediaKind.video;
      } else if (type == 'gif') {
        kind = XMediaKind.gif;
      } else {
        kind = XMediaKind.photo;
      }
      final url = '${map['url'] ?? ''}';
      if (url.isEmpty) continue;
      var preview = '${map['thumbnail_url'] ?? ''}'.trim();
      if (preview.isEmpty && url.contains('pbs.twimg.com')) {
        if (url.contains('name=orig')) {
          preview = url.replaceFirst('name=orig', 'name=small');
        } else if (url.contains('?')) {
          preview = '$url&name=small';
        } else {
          preview = '$url?name=small';
        }
      }
      if (preview.isEmpty) preview = url;
      media.add(XMedia(
        kind: kind,
        url: url,
        previewUrl: preview,
        width: (map['width'] as num?)?.toInt() ?? 0,
        height: (map['height'] as num?)?.toInt() ?? 0,
        duration: _parseMediaDuration(map),
      ));
    }
    return media;
  }

  double _parseMediaDuration(Map<String, dynamic> map) {
    final millis = map['duration_millis'];
    if (millis is num && millis > 0) return millis / 1000;
    final seconds = map['duration'];
    if (seconds is num && seconds > 0) return seconds.toDouble();
    return 0;
  }

  /// 桌面端候选代理：环境变量 → 常见 Clash 端口 → 直连
  static List<String?> _proxyCandidates() {
    final fromEnv = _proxyFromEnv();
    return <String?>[
      if (fromEnv != null) fromEnv,
      '127.0.0.1:7897',
      '127.0.0.1:7890',
      '127.0.0.1:1087',
      '127.0.0.1:10809',
      null, // 直连
    ];
  }

  static String? _proxyFromEnv() {
    for (final key in const [
      'https_proxy',
      'HTTPS_PROXY',
      'http_proxy',
      'HTTP_PROXY',
      'all_proxy',
      'ALL_PROXY',
    ]) {
      final raw = Platform.environment[key]?.trim() ?? '';
      if (raw.isEmpty) continue;
      final uri = Uri.tryParse(raw.contains('://') ? raw : 'http://$raw');
      if (uri == null || uri.host.isEmpty) continue;
      final port = uri.hasPort ? uri.port : 7890;
      return '${uri.host}:$port';
    }
    return null;
  }

  Future<String> _getRaw(Uri uri, {String accept = 'application/json'}) async {
    final bytes = await _getBytes(uri, accept: accept);
    return utf8.decode(bytes);
  }

  Future<Uint8List> _getBytes(
    Uri uri, {
    String accept = '*/*',
  }) async {
    if (Platform.isIOS || Platform.isAndroid) {
      return _getBytesWithProxy(uri, proxy: null, accept: accept);
    }

    final cached = _resolvedProxy;
    if (cached != null) {
      try {
        return await _getBytesWithProxy(
          uri,
          proxy: cached.isEmpty ? null : cached,
          accept: accept,
        );
      } catch (_) {
        _resolvedProxy = null;
      }
    }

    Object? lastError;
    for (final proxy in _proxyCandidates()) {
      try {
        final body =
            await _getBytesWithProxy(uri, proxy: proxy, accept: accept);
        _resolvedProxy = proxy ?? '';
        return body;
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError is XFeedException) throw lastError;
    throw XFeedException(
      '无法连接，请开启 VPN/代理（常见端口 7897/7890）。',
    );
  }

  Future<Uint8List> _getBytesWithProxy(
    Uri uri, {
    required String? proxy,
    String accept = '*/*',
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 12);
    client.userAgent = _userAgent;
    if (proxy != null && proxy.isNotEmpty) {
      client.findProxy = (_) => 'PROXY $proxy';
    } else {
      client.findProxy = (_) => 'DIRECT';
    }
    try {
      final request = await client.getUrl(uri);
      request.headers.set('Accept', accept);
      request.headers.set('Referer', 'https://x.com/');
      request.headers.set('Accept-Language', 'zh-CN,zh;q=0.9,en;q=0.8');
      request.followRedirects = true;
      request.maxRedirects = 5;
      final response = await request.close();
      if (response.statusCode == 204) {
        await response.drain<void>();
        return Uint8List(0);
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      final body = builder.takeBytes();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw XFeedException('请求失败（HTTP ${response.statusCode}）。');
      }
      return body;
    } on SocketException {
      throw XFeedException(
        proxy == null ? '直连失败。' : '代理 $proxy 不可用。',
      );
    } finally {
      client.close(force: true);
    }
  }
}

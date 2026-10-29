enum ThirdPartyNewsSource { sohu, hupu }

class ThirdPartyNewsItem {
  final String id;
  final String title;
  final String summary;
  final String pic;
  final String url;
  final DateTime? publishedAt;
  final ThirdPartyNewsSource source;
  final int replyNum;
  final int lights;

  const ThirdPartyNewsItem({
    required this.id,
    required this.title,
    required this.source,
    required this.url,
    this.summary = '',
    this.pic = '',
    this.publishedAt,
    this.replyNum = 0,
    this.lights = 0,
  });

  String get sourceLabel {
    switch (source) {
      case ThirdPartyNewsSource.sohu:
        return '搜狐';
      case ThirdPartyNewsSource.hupu:
        return '虎扑';
    }
  }
}

class ThirdPartyNewsPage {
  final List<ThirdPartyNewsItem> items;
  final bool hasMore;
  /// 虎扑下一页游标（上一页最后一条 nid）
  final String? nextCursor;

  const ThirdPartyNewsPage({
    required this.items,
    this.hasMore = false,
    this.nextCursor,
  });
}

class ThirdPartyNewsDetail {
  final String id;
  final String title;
  final String author;
  final String url;
  final DateTime? publishedAt;
  final List<String> paragraphs;
  final List<String> images;
  final ThirdPartyNewsSource source;

  const ThirdPartyNewsDetail({
    required this.id,
    required this.title,
    required this.source,
    required this.url,
    this.author = '',
    this.publishedAt,
    this.paragraphs = const [],
    this.images = const [],
  });
}

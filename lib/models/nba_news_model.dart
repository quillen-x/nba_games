class NbaNewsItem {
  final String id;
  final String title;
  final String summary;
  final String pic;
  final DateTime? publishedAt;
  final bool isVideo;
  final bool isHot;
  final int pageView;
  final int replyNum;
  /// 社区板块 mid，详情页 URL 用；列表里可能为空
  final String mid;

  const NbaNewsItem({
    required this.id,
    required this.title,
    this.summary = '',
    this.pic = '',
    this.publishedAt,
    this.isVideo = false,
    this.isHot = false,
    this.pageView = 0,
    this.replyNum = 0,
    this.mid = '',
  });

  /// 腾讯体育社区帖详情（与 fans.sports.qq.com/post.htm 同源）
  String get url {
    final m = mid.trim().isEmpty ? '255' : mid.trim().split(',').first;
    return 'https://fans.sports.qq.com/post.htm?id=$id&mid=$m';
  }

  factory NbaNewsItem.fromType1011(
    Map<String, dynamic> raw, {
    bool isHot = false,
  }) {
    final create = raw['createTime'];
    DateTime? published;
    if (create != null) {
      final sec = int.tryParse(create.toString());
      if (sec != null && sec > 0) {
        published = DateTime.fromMillisecondsSinceEpoch(
          sec * 1000,
          isUtc: true,
        ).toLocal();
      }
    }
    return NbaNewsItem(
      id: raw['id']?.toString() ?? '',
      title: raw['title']?.toString() ?? '',
      summary: raw['summary']?.toString() ?? '',
      pic: raw['pic']?.toString() ?? '',
      publishedAt: published,
      isVideo: raw['isVideo'] == 1 || raw['isVideo'] == true,
      isHot: isHot,
      pageView: int.tryParse(raw['pageView']?.toString() ?? '') ?? 0,
      replyNum: int.tryParse(raw['replyNum']?.toString() ?? '') ?? 0,
      mid: raw['moduleIds']?.toString() ?? '',
    );
  }
}

class NbaNewsPage {
  final List<NbaNewsItem> items;
  final String? contextData;
  final bool hasMore;

  const NbaNewsPage({
    required this.items,
    this.contextData,
    this.hasMore = false,
  });
}

/// 社区帖正文块：0 文本 / 1 图片
class NbaTopicBlock {
  final int type;
  final String text;
  final String imageUrl;

  const NbaTopicBlock({
    required this.type,
    this.text = '',
    this.imageUrl = '',
  });

  bool get isText => type == 0 && text.isNotEmpty;
  bool get isImage => type == 1 && imageUrl.isNotEmpty;
}

class NbaTopicDetail {
  final String id;
  final String title;
  final String summary;
  final String mid;
  final String moduleName;
  final String authorName;
  final String authorAvatar;
  final DateTime? publishedAt;
  final int readNum;
  final int replyNum;
  final int supportNum;
  final List<NbaTopicBlock> blocks;

  const NbaTopicDetail({
    required this.id,
    required this.title,
    this.summary = '',
    this.mid = '',
    this.moduleName = '',
    this.authorName = '',
    this.authorAvatar = '',
    this.publishedAt,
    this.readNum = 0,
    this.replyNum = 0,
    this.supportNum = 0,
    this.blocks = const [],
  });

  String get url {
    final m = mid.trim().isEmpty ? '255' : mid.trim().split(',').first;
    return 'https://fans.sports.qq.com/post.htm?id=$id&mid=$m';
  }

  factory NbaTopicDetail.fromApi(Map<String, dynamic> data) {
    final topic = data['topic'] is Map
        ? Map<String, dynamic>.from(data['topic'] as Map)
        : <String, dynamic>{};
    final user = topic['user'] is Map
        ? Map<String, dynamic>.from(topic['user'] as Map)
        : <String, dynamic>{};

    DateTime? published;
    final create = topic['createTime'];
    if (create != null) {
      final sec = int.tryParse(create.toString());
      if (sec != null && sec > 0) {
        published = DateTime.fromMillisecondsSinceEpoch(
          sec * 1000,
          isUtc: true,
        ).toLocal();
      }
    }

    final blocks = <NbaTopicBlock>[];
    final rawBlocks = topic['content'];
    if (rawBlocks is List) {
      for (final e in rawBlocks) {
        if (e is! Map) continue;
        final map = Map<String, dynamic>.from(e);
        final type = int.tryParse(map['type']?.toString() ?? '') ?? 0;
        if (type == 1) {
          var img = '';
          final image = map['image'];
          if (image is Map) {
            final cur = image['cur'];
            final raw = image['raw'];
            if (cur is Map && '${cur['url'] ?? ''}'.isNotEmpty) {
              img = '${cur['url']}';
            } else if (raw is Map && '${raw['url'] ?? ''}'.isNotEmpty) {
              img = '${raw['url']}';
            }
          }
          if (img.isEmpty) img = map['info']?.toString() ?? '';
          if (img.isNotEmpty) {
            blocks.add(NbaTopicBlock(type: 1, imageUrl: img));
          }
        } else {
          final text = map['info']?.toString().trim() ?? '';
          if (text.isNotEmpty) {
            blocks.add(NbaTopicBlock(type: 0, text: text));
          }
        }
      }
    }

    return NbaTopicDetail(
      id: topic['id']?.toString() ?? '',
      title: topic['title']?.toString() ?? '',
      summary: topic['summary']?.toString() ?? '',
      mid: topic['moduleIds']?.toString() ?? '',
      moduleName: topic['moduleName']?.toString() ?? '',
      authorName: user['name']?.toString() ?? '',
      authorAvatar: user['avatar']?.toString() ?? '',
      publishedAt: published,
      readNum: int.tryParse(topic['readNum']?.toString() ?? '') ?? 0,
      replyNum: int.tryParse(topic['replyNum']?.toString() ?? '') ?? 0,
      supportNum: int.tryParse(topic['supportNum']?.toString() ?? '') ?? 0,
      blocks: blocks,
    );
  }
}

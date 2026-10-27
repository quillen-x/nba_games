enum XMediaKind { photo, video, gif }

class XMedia {
  const XMedia({
    required this.kind,
    required this.url,
    this.previewUrl = '',
    this.width = 0,
    this.height = 0,
    this.duration = 0,
  });

  final XMediaKind kind;
  final String url;
  final String previewUrl;
  final int width;
  final int height;
  final double duration;

  bool get isVideo => kind == XMediaKind.video || kind == XMediaKind.gif;

  String get listUrl {
    final raw = previewUrl.trim().isNotEmpty ? previewUrl : url;
    return raw;
  }

  String get durationLabel {
    if (duration <= 0) return '';
    final total = duration > 3600 ? (duration / 1000).round() : duration.round();
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class XPost {
  const XPost({
    required this.id,
    required this.username,
    required this.text,
    required this.url,
    this.publishedAt,
    this.media = const <XMedia>[],
    this.translation = '',
    this.lang = '',
    this.avatarUrl = '',
    this.authorName = '',
    this.likes = 0,
    this.views = 0,
  });

  final String id;
  final String username;
  final String text;
  final String url;
  final DateTime? publishedAt;
  final List<XMedia> media;
  final String translation;
  final String lang;
  final String avatarUrl;
  final String authorName;
  final int likes;
  final int views;

  String get displayName {
    final name = authorName.trim();
    return name.isEmpty ? username : name;
  }

  String get displayText {
    final translated = translation.trim();
    return translated.isEmpty ? text : translated;
  }

  bool get hasTranslation {
    final translated = translation.trim();
    return translated.isNotEmpty && translated != text.trim();
  }

  bool get isChinese {
    final code = lang.trim().toLowerCase();
    if (code == 'zh' || code.startsWith('zh-')) return true;
    final sample = text.trim();
    if (sample.isEmpty) return false;
    var cjk = 0;
    var letters = 0;
    for (final r in sample.runes) {
      if ((r >= 0x4E00 && r <= 0x9FFF) ||
          (r >= 0x3400 && r <= 0x4DBF) ||
          (r >= 0xF900 && r <= 0xFAFF)) {
        cjk++;
      } else if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A)) {
        letters++;
      }
    }
    return cjk > 0 && cjk >= letters;
  }

  XPost copyWith({
    String? avatarUrl,
    String? authorName,
    String? translation,
  }) {
    return XPost(
      id: id,
      username: username,
      text: text,
      url: url,
      publishedAt: publishedAt,
      media: media,
      translation: translation ?? this.translation,
      lang: lang,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      authorName: authorName ?? this.authorName,
      likes: likes,
      views: views,
    );
  }
}

class XPostPage {
  const XPostPage({required this.posts, this.cursor});

  final List<XPost> posts;
  final String? cursor;
}

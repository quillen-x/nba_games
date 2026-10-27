class NbaMembersBundle {
  final String source;
  final String category;
  final String? exportedAt;
  final List<NbaMember> members;

  const NbaMembersBundle({
    required this.source,
    required this.category,
    required this.members,
    this.exportedAt,
  });

  factory NbaMembersBundle.fromJson(Map<String, dynamic> json) {
    final raw = json['members'];
    final list = <NbaMember>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final m = NbaMember.fromJson(Map<String, dynamic>.from(item));
        if (m.username.isEmpty) continue;
        list.add(m);
      }
    }
    return NbaMembersBundle(
      source: json['source']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      exportedAt: json['exportedAt']?.toString(),
      members: list,
    );
  }
}

class NbaMember {
  final String username;
  final String name;
  final String userId;
  final String avatarUrl;
  final String profileUrl;
  final int followers;
  final int following;
  final int tweets;
  final String description;
  final bool special;

  const NbaMember({
    required this.username,
    required this.name,
    this.userId = '',
    this.avatarUrl = '',
    this.profileUrl = '',
    this.followers = 0,
    this.following = 0,
    this.tweets = 0,
    this.description = '',
    this.special = false,
  });

  String get displayName => name.trim().isEmpty ? username : name.trim();

  String get xUrl {
    if (profileUrl.trim().isNotEmpty) return profileUrl.trim();
    return 'https://x.com/$username';
  }

  factory NbaMember.fromJson(Map<String, dynamic> json) {
    return NbaMember(
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      profileUrl: json['profileUrl']?.toString() ?? '',
      followers: (json['followers'] as num?)?.toInt() ?? 0,
      following: (json['following'] as num?)?.toInt() ?? 0,
      tweets: (json['tweets'] as num?)?.toInt() ?? 0,
      description: json['description']?.toString() ?? '',
      special: json['special'] == true,
    );
  }
}

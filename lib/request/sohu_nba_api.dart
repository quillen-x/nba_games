import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nba_games/models/nba_game_model.dart';

/// 搜狐体育 NBA 赛程 / 比赛详情
/// 赛程: https://sports.sohu.com/s/nba
/// 详情: https://www.sohu.com/xtopic/{id}
class SohuNbaApi {
  SohuNbaApi._();

  static const _odinUrl = 'https://odin.sohu.com/odin/api/blockdata';
  static const _briefUrl =
      'https://v2.sohu.com/dis/live/beitai/match/info/brief';
  static const _leagueId = '4353138d-4c22-4396-95d8-5f587d2df25c';
  static const _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static const _periodLabels = [
    '1ST',
    '2ND',
    '3RD',
    '4TH',
    'OT1',
    'OT2',
    'OT3',
    'OT4',
  ];

  static const _teamStatLabels = [
    '得分',
    '篮板',
    '助攻',
    '抢断',
    '盖帽',
    '失误',
    '投篮命中率',
    '罚球命中率',
    '三分球命中率',
  ];

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json, text/plain, */*',
        'Content-Type': 'application/json;charset=UTF-8',
        'Origin': 'https://sports.sohu.com',
        'Referer': 'https://sports.sohu.com/s/nba',
      },
    ),
  );

  /// 获取今日 + 后 [dayCount]-1 日赛程（默认共 5 天）
  static Future<List<NbaScheduleDay>> getSchedule({int dayCount = 5}) async {
    try {
      final dateItems = await _fetchFutureDates(dayCount);
      if (dateItems.isEmpty) return [];

      final resources = <Map<String, dynamic>>[];
      for (var i = 0; i < dateItems.length; i++) {
        resources.add({
          'tplCompKey': 'day_$i',
          'isServerRender': false,
          'isSingleAd': false,
          'configSource': 'mp',
          'content': {
            'productId': '774',
            'productType': '14',
            'size': 40,
            'pro': '',
            'feedType': '',
            'view': '',
            'innerTag': 'dynamic',
            'spm': 'smpc.nba_games.schedule',
            'page': 1,
            'requestId': 'nba_day_$i',
          },
          'adInfo': {},
          'context': {
            'mkey': '',
            'dis_leagueId': _leagueId,
            'dis_yearMonthDay': dateItems[i].date,
            'DIS_ORDER_RULE': 'startTime_asc',
          },
        });
      }

      final data = await _postOdin(
        productId: 282,
        resourceList: resources,
      );

      final today = _todayKey();
      final days = <NbaScheduleDay>[];
      for (var i = 0; i < dateItems.length; i++) {
        final item = dateItems[i];
        final list = (data['day_$i'] as Map?)?['list'] as List? ?? const [];
        final games = list
            .whereType<Map>()
            .map((e) => NbaGame.fromSohu(Map<String, dynamic>.from(e)))
            .where((g) => g.awayTeam.isNotEmpty && g.homeTeam.isNotEmpty)
            .toList();

        days.add(NbaScheduleDay(
          date: item.date,
          weekday: item.weekday,
          label: item.date == today ? '今日' : '${item.monthDay} ${item.weekday}',
          games: games,
        ));
      }
      return days;
    } catch (e, st) {
      debugPrint('[SohuNbaApi] getSchedule failed: $e\n$st');
      rethrow;
    }
  }

  /// 根据比赛专题页 URL / topicId 拉取详情（每节得分、技术统计、球员统计）
  static Future<NbaMatchDetail> getMatchDetail({
    String? url,
    String? topicId,
  }) async {
    final id = topicId ?? _topicIdFromUrl(url);
    if (id == null || id.isEmpty) {
      throw StateError('缺少比赛 topicId');
    }

    // PC 专题页 www.sohu.com/xtopic 常被 CDN 403，改用移动端页面解析 matchId
    final pageUrl = 'https://m.sohu.com/xtopic/$id';
    final meta = await _parseMatchMetaFromPage(pageUrl);
    final brief = await _fetchBrief(meta.matchId);

    final homeId =
        brief.homeTeamId.isNotEmpty ? brief.homeTeamId : meta.homeTeamId;
    final awayId =
        brief.awayTeamId.isNotEmpty ? brief.awayTeamId : meta.awayTeamId;

    final data = await _postOdin(
      productId: 380,
      resourceList: [
        _resource(
          key: 'quarters',
          productId: '213',
          context: {'mkey': '', 'dis_matchId': brief.matchId},
        ),
        _resource(
          key: 'team_stats',
          productId: '214',
          context: {'mkey': '', 'dis_matchId': brief.matchId},
        ),
        _resource(
          key: 'home_players',
          productId: '210',
          size: 30,
          context: {
            'mkey': '',
            'dis_matchId': brief.matchId,
            'dis_teamId': homeId,
          },
        ),
        _resource(
          key: 'away_players',
          productId: '210',
          size: 30,
          context: {
            'mkey': '',
            'dis_matchId': brief.matchId,
            'dis_teamId': awayId,
          },
        ),
      ],
      referer: 'https://sports.sohu.com/s/nba',
    );

    final quarters = _parseQuarters(
      (data['quarters'] as Map?)?['list'] as List? ?? const [],
    );
    final teamStats = _parseTeamStats(
      (data['team_stats'] as Map?)?['list'] as List? ?? const [],
    );

    final homePlayers = ((data['home_players'] as Map?)?['list'] as List? ??
            const [])
        .whereType<Map>()
        .map((e) => NbaPlayerStat.fromSohu(Map<String, dynamic>.from(e)))
        .where((p) => p.name.isNotEmpty && p.name != '-')
        .toList();
    final awayPlayers = ((data['away_players'] as Map?)?['list'] as List? ??
            const [])
        .whereType<Map>()
        .map((e) => NbaPlayerStat.fromSohu(Map<String, dynamic>.from(e)))
        .where((p) => p.name.isNotEmpty && p.name != '-')
        .toList();

    return NbaMatchDetail(
      brief: brief,
      periodLabels: _periodLabels,
      quarters: quarters,
      teamStatLabels: _teamStatLabels,
      teamStats: teamStats,
      playerBoards: [
        NbaTeamPlayerBoard(
          team: brief.homeTeam,
          logo: brief.homeLogo,
          players: homePlayers,
        ),
        NbaTeamPlayerBoard(
          team: brief.awayTeam,
          logo: brief.awayLogo,
          players: awayPlayers,
        ),
      ],
    );
  }

  static Future<List<_DateItem>> _fetchFutureDates(int count) async {
    final data = await _postOdin(
      productId: 282,
      resourceList: [
        {
          'tplCompKey': 'dates',
          'isServerRender': false,
          'isSingleAd': false,
          'configSource': 'mp',
          'content': {
            'productId': '831',
            'productType': '14',
            'size': count,
            'pro': '',
            'feedType': '',
            'view': '',
            'innerTag': 'dynamic',
            'spm': 'smpc.nba_games.dates',
            'page': 1,
            'requestId': 'nba_dates',
          },
          'adInfo': {},
          'context': {
            'mkey': '',
            'dis_leagueId': _leagueId,
            'DIS_FILTER_RULES': [
              {'param': 'NOW_DATE', 'name': 'startTime', 'paramType': '>='},
            ],
            'DIS_AGGS_TERMS_RULE': {
              'groupBy': 'yearMonthDay',
              'innerBucketSort': 'startTime_desc',
              'groupSort': 'asc',
              'groupSize': count,
              'innerSize': 1,
            },
          },
        },
      ],
    );

    final list = (data['dates'] as Map?)?['list'] as List? ?? const [];
    return list.whereType<Map>().map((raw) {
      final map = Map<String, dynamic>.from(raw);
      final monthDay = map['column_1_text']?.toString() ?? '';
      final year = map['column_3_text']?.toString() ?? '';
      final weekday = map['column_2_text']?.toString() ?? '';
      final parts = monthDay.split('-');
      final month = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
      final day = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      final date =
          '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      return _DateItem(date: date, monthDay: monthDay, weekday: weekday);
    }).toList();
  }

  static Future<_MatchMeta> _parseMatchMetaFromPage(String pageUrl) async {
    final response = await _dio.get<String>(
      pageUrl,
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Referer': 'https://sports.sohu.com/s/nba',
        },
        validateStatus: (code) => code != null && code >= 200 && code < 400,
      ),
    );
    final html = response.data ?? '';

    // 兼容正常 JSON 与转义 JSON（sohuMatchId\":\"...\"）
    final matchId = RegExp(
              r'"queryName"\s*:\s*"dis_matchId"\s*,\s*"queryValue"\s*:\s*"([0-9a-f-]{36})"',
            ).firstMatch(html)?.group(1) ??
        RegExp(r'sohuMatchId\\?"\s*:\s*\\?"([0-9a-f-]{36})"')
            .firstMatch(html)
            ?.group(1) ??
        RegExp(r'dis_matchId"\s*:\s*"([0-9a-f-]{36})"')
            .firstMatch(html)
            ?.group(1);

    final teamIds = RegExp(
      r'"queryName"\s*:\s*"dis_teamId"\s*,\s*"queryValue"\s*:\s*"([0-9a-f-]{36})"',
    ).allMatches(html).map((m) => m.group(1)!).toSet().toList();

    if (matchId == null || matchId.isEmpty) {
      throw StateError('无法从比赛页解析 matchId: $pageUrl');
    }

    return _MatchMeta(
      matchId: matchId,
      homeTeamId: teamIds.isNotEmpty ? teamIds.first : '',
      awayTeamId: teamIds.length > 1 ? teamIds[1] : '',
    );
  }

  static Future<NbaMatchBrief> _fetchBrief(String matchId) async {
    final response = await _dio.post(
      _briefUrl,
      data: [
        {
          'sohuMatchId': matchId,
          'sportsType': 1,
          'isSelf': 0,
        }
      ],
      options: Options(headers: {
        'Origin': 'https://www.sohu.com',
        'Referer': 'https://www.sohu.com/',
      }),
    );
    final body = response.data;
    if (body is! Map || body['code'] != 0) {
      throw StateError('brief api error: ${body is Map ? body['message'] : body}');
    }
    final list = body['data'] as List? ?? const [];
    if (list.isEmpty || list.first is! Map) {
      throw StateError('brief api empty for $matchId');
    }
    return NbaMatchBrief.fromJson(Map<String, dynamic>.from(list.first as Map));
  }

  static List<NbaQuarterScore> _parseQuarters(List list) {
    String logo(dynamic v) {
      final s = v?.toString() ?? '';
      if (s.isEmpty) return '';
      if (s.startsWith('http')) return s;
      return 'https://$s';
    }

    String cell(Map map, String key) {
      final v = map[key];
      if (v == null) return '-';
      final s = v.toString().trim();
      return s.isEmpty ? '-' : s;
    }

    return list.whereType<Map>().map((raw) {
      final map = Map<String, dynamic>.from(raw);
      final periods = [
        cell(map, 'column_2_text'),
        cell(map, 'column_3_text'),
        cell(map, 'column_4_text'),
        cell(map, 'column_5_text'),
        cell(map, 'column_6_text'),
        cell(map, 'column_7_text'),
        cell(map, 'column_8_text'),
        cell(map, 'column_9_text'),
      ];
      return NbaQuarterScore(
        team: cell(map, 'column_1_text'),
        logo: logo(map['column_1_image']),
        periods: periods,
        total: cell(map, 'column_10_text'),
      );
    }).where((e) => e.team.isNotEmpty && e.team != '-').toList();
  }

  static List<NbaTeamStat> _parseTeamStats(List list) {
    String logo(dynamic v) {
      final s = v?.toString() ?? '';
      if (s.isEmpty) return '';
      if (s.startsWith('http')) return s;
      return 'https://$s';
    }

    String cell(Map map, String key) {
      final v = map[key];
      if (v == null) return '-';
      final s = v.toString().trim();
      return s.isEmpty ? '-' : s;
    }

    const keys = [
      'column_2_text',
      'column_3_text',
      'column_4_text',
      'column_5_text',
      'column_6_text',
      'column_7_text',
      'column_8_text',
      'column_9_text',
      'column_10_text',
    ];

    return list.whereType<Map>().map((raw) {
      final map = Map<String, dynamic>.from(raw);
      final values = <String, String>{};
      for (var i = 0; i < _teamStatLabels.length; i++) {
        values[_teamStatLabels[i]] = cell(map, keys[i]);
      }
      return NbaTeamStat(
        team: cell(map, 'column_16_text'),
        logo: logo(map['column_1_image']),
        values: values,
      );
    }).where((e) => e.team.isNotEmpty && e.team != '-').toList();
  }

  static Map<String, dynamic> _resource({
    required String key,
    required String productId,
    required Map<String, dynamic> context,
    int size = 20,
  }) {
    return {
      'tplCompKey': key,
      'isServerRender': false,
      'isSingleAd': false,
      'configSource': 'mp',
      'content': {
        'productId': productId,
        'productType': '14',
        'size': size,
        'pro': '',
        'feedType': '',
        'view': '',
        'innerTag': 'dynamic',
        'spm': 'smpc.nba_games.$key',
        'page': 1,
        'requestId': 'nba_$key',
      },
      'adInfo': {},
      'context': context,
    };
  }

  static Future<Map<String, dynamic>> _postOdin({
    required int productId,
    required List<Map<String, dynamic>> resourceList,
    String? referer,
  }) async {
    final response = await _dio.post(
      _odinUrl,
      data: {
        'pvId': 'nba_games',
        'pageId': '${DateTime.now().millisecondsSinceEpoch}_nba',
        'mainContent': {
          'productType': 13,
          'productId': productId,
          'secureScore': 100,
          'categoryId': '40',
          'adTags': '20000118',
        },
        'resourceList': resourceList,
      },
      options: referer == null
          ? null
          : Options(headers: {
              'Referer': referer,
              'Origin': 'https://www.sohu.com',
            }),
    );

    final body = response.data;
    if (body is! Map || (body['code'] != 0 && body['success'] != true)) {
      throw StateError('odin api error: ${body is Map ? body['message'] : body}');
    }
    final data = body['data'];
    if (data is! Map) return {};
    return Map<String, dynamic>.from(data);
  }

  static String? _topicIdFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    return RegExp(r'/xtopic/([A-Za-z0-9_-]+)').firstMatch(url)?.group(1);
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

class _DateItem {
  final String date;
  final String monthDay;
  final String weekday;

  const _DateItem({
    required this.date,
    required this.monthDay,
    required this.weekday,
  });
}

class _MatchMeta {
  final String matchId;
  final String homeTeamId;
  final String awayTeamId;

  const _MatchMeta({
    required this.matchId,
    required this.homeTeamId,
    required this.awayTeamId,
  });
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nba_games/models/nba_game_model.dart';

/// 腾讯体育 NBA：赛程 / 详情 / 排行 / 球队 / 球员
/// 赛程 https://sports.qq.com/kbsweb/index.htm#nba
/// 详情 https://sports.qq.com/kbsweb/game.htm?mid=100000:xxx
/// 排行 https://sports.qq.com/nba/stats/teams
class TencentNbaApi {
  TencentNbaApi._();

  static const _matchWeb = 'https://matchweb.sports.qq.com';
  static const _appWeb = 'https://app.sports.qq.com';
  static const _rankingsPath = '/match/api/v2/statistic/rankings';
  static const competitionId = '100000';
  static const _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static const _typeStandings = 0;
  static const _typePlayer = 2;

  static const playerRankCategories = [
    NbaPlayerRankCategory(label: '得分', code: 'point'),
    NbaPlayerRankCategory(label: '篮板', code: 'rebound'),
    NbaPlayerRankCategory(label: '助攻', code: 'assist'),
    NbaPlayerRankCategory(label: '抢断', code: 'steal'),
    NbaPlayerRankCategory(label: '盖帽', code: 'block'),
  ];

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://sports.qq.com/kbsweb/index.htm',
        'Origin': 'https://sports.qq.com',
      },
    ),
  );

  static final Map<String, Map<String, dynamic>> _standingsCache = {};
  static final Map<String, Map<String, dynamic>> _playerRankCache = {};

  // ───────── 赛程 ─────────

  /// 拉取近 [dayCount] 天赛程（含今日）
  static Future<List<NbaScheduleDay>> getSchedule({int dayCount = 5}) async {
    try {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day)
          .subtract(const Duration(days: 1));
      final end = start.add(Duration(days: dayCount));
      final res = await _dio.get<Map<String, dynamic>>(
        '$_appWeb/match/list',
        queryParameters: {
          'columnId': competitionId,
          'startTime': _ymd(start),
          'endTime': _ymd(end),
        },
      );
      final body = res.data;
      if (body == null || body['code'] != 0 || body['data'] is! Map) {
        throw StateError('腾讯赛程接口异常');
      }
      final data = Map<String, dynamic>.from(body['data'] as Map);
      final matches = data['matches'];
      if (matches is! Map) return const [];

      final todayStr = data['today']?.toString() ?? _ymd(today);
      final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      final days = <NbaScheduleDay>[];

      final dates = matches.keys.map((e) => e.toString()).toList()..sort();
      for (final date in dates) {
        final dayRaw = matches[date];
        final list = dayRaw is Map
            ? (dayRaw['list'] as List? ?? const [])
            : (dayRaw is List ? dayRaw : const []);
        final games = list
            .whereType<Map>()
            .map((e) => NbaGame.fromTencent(Map<String, dynamic>.from(e)))
            .where((g) =>
                g.homeTeam.isNotEmpty &&
                g.awayTeam.isNotEmpty &&
                g.mid != null &&
                g.mid!.isNotEmpty)
            .toList()
          ..sort((a, b) {
            final am = a.startTimeMs ?? 0;
            final bm = b.startTimeMs ?? 0;
            if (am != bm) return am.compareTo(bm);
            return a.timeText.compareTo(b.timeText);
          });
        if (games.isEmpty) continue;

        final dt = DateTime.tryParse(date);
        final weekday = dt == null
            ? ''
            : weekdays[(dt.weekday - 1).clamp(0, 6)];
        final monthDay = date.length >= 10 ? date.substring(5) : date;
        days.add(NbaScheduleDay(
          date: date,
          weekday: weekday,
          label: date == todayStr ? '今日' : '$monthDay $weekday',
          games: games,
        ));
      }
      return days;
    } catch (e, st) {
      debugPrint('[TencentNbaApi] getSchedule failed: $e\n$st');
      rethrow;
    }
  }

  // ───────── 比赛详情 ─────────

  /// [mid] 如 100000:10022600093；也兼容旧的 topicId/url 参数名
  static Future<NbaMatchDetail> getMatchDetail({
    String? mid,
    String? topicId,
    String? url,
  }) async {
    final id = mid ?? topicId ?? _midFromUrl(url);
    if (id == null || id.isEmpty) {
      throw StateError('缺少比赛 mid');
    }

    try {
      final results = await Future.wait([
        _dio.get<Map<String, dynamic>>(
          '$_matchWeb/kbs/matchDetail',
          queryParameters: {'mid': id, 'from': 'sportsh5'},
        ),
        _dio.get<Map<String, dynamic>>(
          '$_matchWeb/kbs/matchStat',
          queryParameters: {'mid': id},
        ),
      ]);

      final detailBody = results[0].data;
      final statBody = results[1].data;
      if (detailBody == null ||
          detailBody['code'] != 0 ||
          detailBody['data'] is! Map) {
        throw StateError('腾讯比赛详情接口异常');
      }
      if (statBody == null ||
          statBody['code'] != 0 ||
          statBody['data'] is! Map) {
        throw StateError('腾讯技术统计接口异常');
      }

      final detailData = Map<String, dynamic>.from(detailBody['data'] as Map);
      final statData = Map<String, dynamic>.from(statBody['data'] as Map);
      final mi = detailData['matchInfo'] is Map
          ? Map<String, dynamic>.from(detailData['matchInfo'] as Map)
          : <String, dynamic>{};
      final teamInfo = statData['teamInfo'] is Map
          ? Map<String, dynamic>.from(statData['teamInfo'] as Map)
          : <String, dynamic>{};

      final leftName =
          mi['leftName']?.toString() ?? teamInfo['leftName']?.toString() ?? '';
      final rightName = mi['rightName']?.toString() ??
          teamInfo['rightName']?.toString() ??
          '';
      final leftLogo =
          mi['leftBadge']?.toString() ?? teamInfo['leftBadge']?.toString();
      final rightLogo =
          mi['rightBadge']?.toString() ?? teamInfo['rightBadge']?.toString();
      final leftGoal =
          mi['leftGoal']?.toString() ?? teamInfo['leftGoal']?.toString();
      final rightGoal =
          mi['rightGoal']?.toString() ?? teamInfo['rightGoal']?.toString();
      final status = _statusFromMatchInfo(mi, teamInfo);

      final brief = NbaMatchBrief(
        matchId: id,
        homeTeamId: mi['leftId']?.toString() ??
            teamInfo['leftId']?.toString() ??
            '',
        awayTeamId: mi['rightId']?.toString() ??
            teamInfo['rightId']?.toString() ??
            '',
        homeTeam: leftName,
        awayTeam: rightName,
        homeScore: leftGoal,
        awayScore: rightGoal,
        homeLogo: leftLogo,
        awayLogo: rightLogo,
        status: status,
        matchType: mi['matchDesc']?.toString() ?? 'NBA',
        periodName: mi['quarter']?.toString() ??
            teamInfo['quarterDesc']?.toString(),
        remainTime: mi['quarterTime']?.toString(),
        startTimeText: mi['startTime']?.toString() ??
            teamInfo['startTime']?.toString(),
        venue: mi['venue']?.toString(),
      );

      final periodGoals = statData['periodGoals'];
      final periodLabels = <String>[];
      final quarters = <NbaQuarterScore>[];
      if (periodGoals is Map) {
        final head = (periodGoals['head'] as List? ?? const [])
            .map((e) => e.toString())
            .toList();
        // head 如 [1st,2nd,3rd,4th,总分]；row 首列常为占位
        periodLabels.addAll(
          head.where((e) => e != '总分' && e.isNotEmpty),
        );
        final rows = periodGoals['rows'] as List? ?? const [];
        for (var i = 0; i < rows.length && i < 2; i++) {
          final row = (rows[i] as List?)?.map((e) => e.toString()).toList() ??
              const <String>[];
          // 跳过首列占位
          final periods = row.length > 1
              ? row.sublist(1, row.length > 1 ? row.length - 1 : 1)
              : const <String>[];
          final total = row.isNotEmpty ? row.last : '-';
          quarters.add(NbaQuarterScore(
            team: i == 0 ? leftName : rightName,
            logo: i == 0 ? leftLogo : rightLogo,
            periods: periods,
            total: total,
          ));
        }
      }

      final teamStatList = statData['teamStats'] as List? ?? const [];
      final teamStatLabels = <String>[];
      final leftValues = <String, String>{};
      final rightValues = <String, String>{};
      for (final item in teamStatList) {
        if (item is! Map) continue;
        final text = item['text']?.toString() ?? '';
        if (text.isEmpty) continue;
        teamStatLabels.add(text);
        leftValues[text] = item['leftVal']?.toString() ?? '-';
        rightValues[text] = item['rightVal']?.toString() ?? '-';
      }

      final playerStats = statData['playerStats'];
      final boards = <NbaTeamPlayerBoard>[];
      if (playerStats is Map) {
        boards.add(_parsePlayerBoard(
          team: leftName,
          logo: leftLogo,
          raw: playerStats['left'],
        ));
        boards.add(_parsePlayerBoard(
          team: rightName,
          logo: rightLogo,
          raw: playerStats['right'],
        ));
      }

      return NbaMatchDetail(
        brief: brief,
        periodLabels: periodLabels.isEmpty
            ? const ['1ST', '2ND', '3RD', '4TH']
            : periodLabels,
        quarters: quarters,
        teamStatLabels: teamStatLabels,
        teamStats: [
          NbaTeamStat(team: leftName, logo: leftLogo, values: leftValues),
          NbaTeamStat(team: rightName, logo: rightLogo, values: rightValues),
        ],
        playerBoards: boards,
      );
    } catch (e, st) {
      debugPrint('[TencentNbaApi] getMatchDetail failed: $e\n$st');
      rethrow;
    }
  }

  static NbaTeamPlayerBoard _parsePlayerBoard({
    required String team,
    required String? logo,
    required dynamic raw,
  }) {
    final list = raw is List ? raw : const [];
    final players = <NbaPlayerStat>[];
    for (final item in list) {
      if (item is! Map) continue;
      if (item.containsKey('head') && !item.containsKey('row')) continue;
      if (!item.containsKey('row')) continue;
      final p = NbaPlayerStat.fromTencent(Map<String, dynamic>.from(item));
      if (p.name.isEmpty || p.name == '-') continue;
      players.add(p);
    }
    return NbaTeamPlayerBoard(team: team, logo: logo, players: players);
  }

  // ───────── 排行 ─────────

  static Future<NbaTeamStandingsResult> getTeamStandings({
    required String conference,
    String? seasonId,
    String? seasonType,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _standingsCacheKey(seasonId, seasonType);
    final data = await _fetchRankings(
      type: _typeStandings,
      cache: () => _standingsCache[cacheKey],
      save: (v) => _standingsCache[cacheKey] = v,
      forceRefresh: forceRefresh,
      seasonId: seasonId,
      seasonType: seasonType,
    );

    final seasons = <NbaRankSeason>[];
    final seasonsRaw = data['seasons'] as List? ?? const [];
    for (final s in seasonsRaw) {
      if (s is! Map) continue;
      final item = NbaRankSeason.fromTencent(Map<String, dynamic>.from(s));
      if (item.seasonId.isEmpty) continue;
      seasons.add(item);
    }

    var selectedIndex = 0;
    final selected = data['selected'];
    if (selected is Map && seasons.isNotEmpty) {
      final sid = selected['seasonId']?.toString() ?? '';
      final st = selected['seasonType']?.toString() ?? '';
      final i = seasons.indexWhere(
        (e) => e.seasonId == sid && e.seasonType == st,
      );
      if (i >= 0) {
        selectedIndex = i;
      } else {
        final j = seasons.indexWhere((e) => e.seasonId == sid);
        if (j >= 0) selectedIndex = j;
      }
    }

    // 无参首次请求也按实际赛季写入缓存，方便切换东西部命中
    if (seasons.isNotEmpty) {
      final resolved = seasons[selectedIndex];
      _standingsCache[_standingsCacheKey(
        resolved.seasonId,
        resolved.seasonType,
      )] = data;
    }

    final groups = data['groups'] as List? ?? const [];
    Map? eastGroup;
    for (final g in groups) {
      if (g is Map && g['code']?.toString() == 'East') {
        eastGroup = g;
        break;
      }
    }
    if (eastGroup == null) {
      throw StateError('未找到东西部排行数据');
    }

    final tables = eastGroup['tables'] as List? ?? const [];
    final keyword = conference.contains('西') ? '西部' : '东部';
    Map? table;
    for (final t in tables) {
      if (t is! Map) continue;
      final headers = t['headers'] as List? ?? const [];
      for (final h in headers) {
        if (h is Map &&
            h['code']?.toString() == 'team' &&
            (h['name']?.toString() ?? '').contains(keyword)) {
          table = t;
          break;
        }
      }
      if (table != null) break;
    }
    if (table == null) {
      throw StateError('未找到$conference排行');
    }

    final rows = table['rows'] as List? ?? const [];
    final list = rows
        .whereType<Map>()
        .map((e) => NbaTeamStanding.fromTencent(Map<String, dynamic>.from(e)))
        .where((e) => e.team.isNotEmpty && e.team != '-')
        .toList();

    return NbaTeamStandingsResult(
      rows: list,
      seasons: seasons,
      selectedSeasonIndex: selectedIndex,
    );
  }

  static Future<NbaPlayerRanksResult> getPlayerRanks({
    required NbaPlayerRankCategory category,
    String? seasonId,
    String? seasonType,
    int size = 50,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _standingsCacheKey(seasonId, seasonType);
    final data = await _fetchRankings(
      type: _typePlayer,
      cache: () => _playerRankCache[cacheKey],
      save: (v) => _playerRankCache[cacheKey] = v,
      forceRefresh: forceRefresh,
      seasonId: seasonId,
      seasonType: seasonType,
    );

    final seasons = <NbaRankSeason>[];
    final seasonsRaw = data['seasons'] as List? ?? const [];
    for (final s in seasonsRaw) {
      if (s is! Map) continue;
      final item = NbaRankSeason.fromTencent(Map<String, dynamic>.from(s));
      if (item.seasonId.isEmpty) continue;
      seasons.add(item);
    }

    var selectedIndex = 0;
    final selected = data['selected'];
    if (selected is Map && seasons.isNotEmpty) {
      final sid = selected['seasonId']?.toString() ?? '';
      final st = selected['seasonType']?.toString() ?? '';
      final i = seasons.indexWhere(
        (e) => e.seasonId == sid && e.seasonType == st,
      );
      if (i >= 0) {
        selectedIndex = i;
      } else {
        final j = seasons.indexWhere((e) => e.seasonId == sid);
        if (j >= 0) selectedIndex = j;
      }
    }

    if (seasons.isNotEmpty) {
      final resolved = seasons[selectedIndex];
      _playerRankCache[_standingsCacheKey(
        resolved.seasonId,
        resolved.seasonType,
      )] = data;
    }

    final groups = data['groups'] as List? ?? const [];
    Map? group;
    for (final g in groups) {
      if (g is Map && g['code']?.toString() == category.code) {
        group = g;
        break;
      }
    }
    if (group == null) {
      throw StateError('未找到${category.label}排行');
    }

    final tables = group['tables'] as List? ?? const [];
    final table = tables.isNotEmpty && tables.first is Map
        ? tables.first as Map
        : null;
    final list = <NbaPlayerRank>[];
    if (table != null) {
      final rows = table['rows'] as List? ?? const [];
      for (final e in rows) {
        if (e is! Map) continue;
        final item = NbaPlayerRank.fromTencent(Map<String, dynamic>.from(e));
        if (item.name.isEmpty || item.name == '-') continue;
        list.add(item);
        if (list.length >= size) break;
      }
    }

    return NbaPlayerRanksResult(
      rows: list,
      seasons: seasons,
      selectedSeasonIndex: selectedIndex,
    );
  }

  // ───────── 球队 / 球员资料 ─────────

  static Future<NbaTeamProfile> getTeamProfile(String teamId) async {
    try {
      final results = await Future.wait([
        _dio.get<Map<String, dynamic>>(
          '$_matchWeb/team/baseInfo',
          queryParameters: {
            'teamId': teamId,
            'competitionId': competitionId,
            'from': 'h5',
          },
        ),
        _dio.get<Map<String, dynamic>>(
          '$_matchWeb/team/players',
          queryParameters: {
            'teamId': teamId,
            'competitionId': competitionId,
          },
        ),
        _dio.get<Map<String, dynamic>>(
          '$_matchWeb/team/stats',
          queryParameters: {
            'teamId': teamId,
            'competitionId': competitionId,
            'from': 'h5',
          },
        ),
      ]);

      final baseBody = results[0].data;
      if (baseBody == null ||
          baseBody['code'] != 0 ||
          baseBody['data'] is! Map) {
        throw StateError('腾讯球队资料异常');
      }
      final data = Map<String, dynamic>.from(baseBody['data'] as Map);
      final base = data['baseInfo'] is Map
          ? Map<String, dynamic>.from(data['baseInfo'] as Map)
          : <String, dynamic>{};
      final rank = data['rankData'] is Map
          ? Map<String, dynamic>.from(data['rankData'] as Map)
          : <String, dynamic>{};

      final playersBody = results[1].data;
      final roster = <NbaTeamRosterPlayer>[];
      final playersRaw = playersBody?['data'];
      if (playersRaw is List) {
        for (final p in playersRaw) {
          if (p is! Map) continue;
          final id = p['playerId']?.toString() ?? '';
          if (id.isEmpty) continue;
          roster.add(NbaTeamRosterPlayer(
            playerId: id,
            name: (p['cnAlias'] ?? p['cnName'] ?? p['enName'] ?? '')
                .toString(),
            logo: p['logo']?.toString(),
            position: p['position']?.toString(),
            jerseyNum: p['jerseyNum']?.toString(),
          ));
        }
      }

      final compares = <NbaStatCompareItem>[];
      final statsBody = results[2].data;
      final compareRaw = (statsBody?['data'] as Map?)?['statsCompare'];
      if (compareRaw is List) {
        for (final c in compareRaw) {
          if (c is! Map) continue;
          compares.add(NbaStatCompareItem(
            type: c['type']?.toString() ?? '',
            value: c['value']?.toString() ?? '-',
            serial: c['serial']?.toString(),
          ));
        }
      }

      final area = rank['area']?.toString() == 'east' ? '东部' : '西部';
      final serial = rank['serial']?.toString() ?? '';
      final wins = rank['wins']?.toString() ?? '';
      final losses = rank['losses']?.toString() ?? '';

      return NbaTeamProfile(
        teamId: teamId,
        name: base['cnName']?.toString() ?? '',
        enName: base['enName']?.toString(),
        logo: base['logo']?.toString(),
        city: base['city']?.toString(),
        venue: base['venue']?.toString(),
        coach: base['coach']?.toString(),
        brief: base['brief']?.toString(),
        record: (wins.isNotEmpty || losses.isNotEmpty) ? '$wins胜$losses负' : null,
        rankText: serial.isNotEmpty ? '$area第$serial' : null,
        roster: roster,
        compares: compares,
      );
    } catch (e, st) {
      debugPrint('[TencentNbaApi] getTeamProfile failed: $e\n$st');
      rethrow;
    }
  }

  static Future<NbaPlayerProfile> getPlayerProfile(String playerId) async {
    try {
      final results = await Future.wait([
        _dio.get<Map<String, dynamic>>(
          '$_matchWeb/player/baseInfo',
          queryParameters: {'playerId': playerId, 'from': 'web'},
        ),
        _dio.get<Map<String, dynamic>>(
          '$_matchWeb/player/stats',
          queryParameters: {'playerId': playerId, 'from': 'web'},
        ),
      ]);

      final baseBody = results[0].data;
      if (baseBody == null ||
          baseBody['code'] != 0 ||
          baseBody['data'] is! Map) {
        throw StateError('腾讯球员资料异常');
      }
      final base = Map<String, dynamic>.from(baseBody['data'] as Map);

      final statsBody = results[1].data;
      final statsData = statsBody?['data'] is Map
          ? Map<String, dynamic>.from(statsBody!['data'] as Map)
          : <String, dynamic>{};

      final compares = <NbaStatCompareItem>[];
      final compareRaw = statsData['statsCompare'];
      if (compareRaw is List) {
        for (final c in compareRaw) {
          if (c is! Map) continue;
          compares.add(NbaStatCompareItem(
            type: c['type']?.toString() ?? '',
            value: c['value']?.toString() ?? '-',
            serial: c['serial']?.toString(),
          ));
        }
      }

      final seasonStat = statsData['seasonStat'];
      var headers = <String>[];
      var rows = <List<String>>[];
      if (seasonStat is Map) {
        headers = (seasonStat['heads'] as List? ?? const []).map((e) {
          final s = e.toString().trim();
          return s.isEmpty ? '阶段' : s;
        }).toList();
        final avg = seasonStat['avg'] as List? ?? const [];
        for (final row in avg) {
          if (row is! List) continue;
          rows.add(row.map((e) => e.toString()).toList());
          if (rows.length >= 16) break;
        }
      }

      return NbaPlayerProfile(
        playerId: playerId,
        name: base['cnName']?.toString() ?? '',
        enName: base['enName']?.toString(),
        logo: base['logo']?.toString(),
        teamId: base['teamId']?.toString(),
        teamName: base['teamName']?.toString(),
        teamLogo: base['teamLogo']?.toString(),
        position: base['position']?.toString(),
        jerseyNum: base['jerseyNum']?.toString(),
        height: base['height']?.toString(),
        weight: base['weight']?.toString(),
        birthDate: base['birthDate']?.toString(),
        compares: compares,
        seasonHeaders: headers,
        seasonAvgRows: rows,
      );
    } catch (e, st) {
      debugPrint('[TencentNbaApi] getPlayerProfile failed: $e\n$st');
      rethrow;
    }
  }

  // ───────── helpers ─────────

  static Future<Map<String, dynamic>> _fetchRankings({
    required int type,
    required Map<String, dynamic>? Function() cache,
    required void Function(Map<String, dynamic>) save,
    bool forceRefresh = false,
    String? seasonId,
    String? seasonType,
  }) async {
    if (!forceRefresh) {
      final cached = cache();
      if (cached != null) return cached;
    }

    try {
      final params = <String, dynamic>{
        'competition_id': competitionId,
        'type': type,
        'scene': 'pc',
      };
      if (seasonId != null && seasonId.isNotEmpty) {
        params['season_id'] = seasonId;
      }
      if (seasonType != null && seasonType.isNotEmpty) {
        params['season_type'] = seasonType;
      }
      final res = await _dio.get<Map<String, dynamic>>(
        '$_matchWeb$_rankingsPath',
        queryParameters: params,
        options: Options(
          headers: {'Referer': 'https://sports.qq.com/nba/stats/teams'},
        ),
      );
      final body = res.data;
      if (body == null || body['code'] != 0 || body['data'] is! Map) {
        throw StateError('腾讯排行接口异常: ${body?['code']} ${body?['msg']}');
      }
      final data = Map<String, dynamic>.from(body['data'] as Map);
      save(data);
      return data;
    } catch (e, st) {
      debugPrint('[TencentNbaApi] rankings type=$type failed: $e\n$st');
      rethrow;
    }
  }

  static String _standingsCacheKey(String? seasonId, String? seasonType) =>
      '${seasonId ?? ''}|${seasonType ?? ''}';

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String? _midFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final m = RegExp(r'mid=([^&]+)').firstMatch(url);
    return m?.group(1);
  }

  static String _statusFromMatchInfo(
    Map<String, dynamic> mi,
    Map<String, dynamic> teamInfo,
  ) {
    final livePeriod = mi['livePeriod']?.toString() ?? '';
    final quarter = mi['quarter']?.toString() ??
        teamInfo['quarterDesc']?.toString() ??
        '';
    if (livePeriod == '0' || quarter.contains('未开始')) return '未开始';
    if (livePeriod == '1' || quarter.contains('进行')) {
      return quarter.isNotEmpty && !quarter.contains('进行') ? quarter : '进行中';
    }
    if (livePeriod == '2') return '已结束';
    if (quarter.isNotEmpty) return quarter;
    return '比赛';
  }
}

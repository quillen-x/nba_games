class NbaGame {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String? homeScore;
  final String? awayScore;
  final String? homeLogo;
  final String? awayLogo;
  final String? homeTeamId;
  final String? awayTeamId;
  final String timeText;
  final String status;
  final String matchType;
  final int? startTimeMs;
  final String? url;
  /// 腾讯 mid，如 100000:10022600093
  final String? mid;

  const NbaGame({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    this.homeScore,
    this.awayScore,
    this.homeLogo,
    this.awayLogo,
    this.homeTeamId,
    this.awayTeamId,
    required this.timeText,
    required this.status,
    required this.matchType,
    this.startTimeMs,
    this.url,
    this.mid,
  });

  factory NbaGame.fromSohu(Map<String, dynamic> json) {
    String? score(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty || s == 'null' || s == 'None') return null;
      return s;
    }

    String logo(dynamic v) {
      final s = v?.toString() ?? '';
      if (s.isEmpty) return '';
      if (s.startsWith('http')) return s;
      return 'https://$s';
    }

    final status = (json['column_11_text'] ??
            json['title'] ??
            json['extraInfo'] ??
            '')
        .toString();

    // 搜狐赛程：column_2/3/1 = 主队名/分/标；column_5/6/4 = 客队名/分/标
    return NbaGame(
      id: json['id']?.toString() ?? '',
      homeTeam: json['column_2_text']?.toString() ?? '',
      awayTeam: json['column_5_text']?.toString() ?? '',
      homeScore: score(json['column_3_text']),
      awayScore: score(json['column_6_text']),
      homeLogo: logo(json['column_1_image']),
      awayLogo: logo(json['column_4_image']),
      timeText: (json['brief'] ?? json['column_10_text'] ?? '').toString(),
      status: status,
      matchType: (json['column_7_text'] ?? '').toString(),
      startTimeMs: json['column_9_text'] is num
          ? (json['column_9_text'] as num).toInt()
          : int.tryParse(json['column_9_text']?.toString() ?? ''),
      url: json['url']?.toString() ?? json['column_1_url']?.toString(),
    );
  }

  bool get isLive => status.contains('进行');
  bool get isFinished => status.contains('结束');
  bool get isUpcoming => status.contains('未开始') || (!isLive && !isFinished);

  /// 详情页请求 key：优先腾讯 mid，其次搜狐 topicId
  String? get topicId {
    if (mid != null && mid!.isNotEmpty) return mid;
    final raw = url;
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'/xtopic/([A-Za-z0-9_-]+)').firstMatch(raw);
    return match?.group(1);
  }

  factory NbaGame.fromTencent(Map<String, dynamic> json) {
    final mi = json['matchInfo'] is Map
        ? Map<String, dynamic>.from(json['matchInfo'] as Map)
        : json;
    final mid = mi['mid']?.toString() ?? '';
    final start = mi['startTime']?.toString() ?? '';
    final timeText = start.length >= 16 ? start.substring(11, 16) : start;

    final status = _tencentStatus(mi);
    String? score(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      if (status.contains('未开始') && (s == '0' || s == '-')) return null;
      return s;
    }

    final startMs = DateTime.tryParse(start.replaceFirst(' ', 'T'))
        ?.millisecondsSinceEpoch;

    return NbaGame(
      id: mid,
      mid: mid.isEmpty ? null : mid,
      homeTeam: mi['leftName']?.toString() ?? '',
      awayTeam: mi['rightName']?.toString() ?? '',
      homeScore: score(mi['leftGoal']),
      awayScore: score(mi['rightGoal']),
      homeLogo: mi['leftBadge']?.toString(),
      awayLogo: mi['rightBadge']?.toString(),
      homeTeamId: mi['leftId']?.toString(),
      awayTeamId: mi['rightId']?.toString(),
      timeText: timeText,
      status: status,
      matchType: mi['matchDesc']?.toString() ?? 'NBA',
      startTimeMs: startMs,
      url: mid.isEmpty
          ? null
          : 'https://sports.qq.com/kbsweb/game.htm?mid=$mid',
    );
  }
}

String _tencentStatus(Map<String, dynamic> mi) {
  final livePeriod = mi['livePeriod']?.toString() ?? '';
  final quarter = mi['quarter']?.toString() ?? '';
  if (livePeriod == '0' || quarter.contains('未开始')) return '未开始';
  if (livePeriod == '1' || quarter.contains('进行')) {
    return quarter.isNotEmpty && quarter != '进行中' ? quarter : '进行中';
  }
  if (livePeriod == '2') return '已结束';
  if (quarter.isNotEmpty) return quarter;
  return mi['matchPeriod']?.toString() ?? '';
}

class NbaScheduleDay {
  final String date;
  final String weekday;
  final String label;
  final List<NbaGame> games;

  const NbaScheduleDay({
    required this.date,
    required this.weekday,
    required this.label,
    required this.games,
  });

  bool get isToday => label == '今日';
}

class NbaMatchBrief {
  final String matchId;
  final String homeTeamId;
  final String awayTeamId;
  final String homeTeam;
  final String awayTeam;
  final String? homeScore;
  final String? awayScore;
  final String? homeLogo;
  final String? awayLogo;
  final String status;
  final String matchType;
  final String? periodName;
  final String? remainTime;
  final String? startTimeText;
  final String? venue;

  const NbaMatchBrief({
    required this.matchId,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeTeam,
    required this.awayTeam,
    this.homeScore,
    this.awayScore,
    this.homeLogo,
    this.awayLogo,
    required this.status,
    required this.matchType,
    this.periodName,
    this.remainTime,
    this.startTimeText,
    this.venue,
  });

  factory NbaMatchBrief.fromJson(Map<String, dynamic> json) {
    String logo(dynamic v) {
      final s = v?.toString() ?? '';
      if (s.isEmpty) return '';
      if (s.startsWith('http')) return s;
      return 'https://$s';
    }

    return NbaMatchBrief(
      matchId: json['sohuMatchId']?.toString() ?? '',
      homeTeamId: json['sohuHomeTeamId']?.toString() ??
          json['beitaiHomeTeamId']?.toString() ??
          '',
      awayTeamId: json['sohuAwayTeamId']?.toString() ??
          json['beitaiAwayTeamId']?.toString() ??
          '',
      homeTeam: json['homeTeamName']?.toString() ?? '',
      awayTeam: json['awayTeamName']?.toString() ?? '',
      homeScore: json['homeScore']?.toString(),
      awayScore: json['awayScore']?.toString(),
      homeLogo: logo(json['homeTeamImage']),
      awayLogo: logo(json['awayTeamImage']),
      status: (json['statusName'] ?? json['viewTime'] ?? '').toString(),
      matchType: (json['matchType'] ?? json['round'] ?? '').toString(),
      periodName: json['periodName']?.toString(),
      remainTime: json['quarterRemainTime']?.toString(),
      startTimeText: json['matchStartTime']?.toString(),
      venue: json['venueName']?.toString(),
    );
  }

  bool get isFinished => status.contains('结束');
  bool get isLive => status.contains('进行');
}

class NbaQuarterScore {
  final String team;
  final String? logo;
  final List<String> periods;
  final String total;

  const NbaQuarterScore({
    required this.team,
    this.logo,
    required this.periods,
    required this.total,
  });
}

class NbaTeamStat {
  final String team;
  final String? logo;
  final Map<String, String> values;

  const NbaTeamStat({
    required this.team,
    this.logo,
    required this.values,
  });
}

class NbaPlayerStat {
  final String name;
  final String? playerId;
  final String? avatar;
  final bool starter;
  final String minutes;
  final String points;
  final String rebounds;
  final String assists;
  final String fieldGoals;
  final String threePointers;
  final String freeThrows;
  final String steals;
  final String blocks;
  final String turnovers;
  final String fouls;

  const NbaPlayerStat({
    required this.name,
    this.playerId,
    this.avatar,
    required this.starter,
    required this.minutes,
    required this.points,
    required this.rebounds,
    required this.assists,
    required this.fieldGoals,
    required this.threePointers,
    required this.freeThrows,
    required this.steals,
    required this.blocks,
    required this.turnovers,
    required this.fouls,
  });

  factory NbaPlayerStat.fromSohu(Map<String, dynamic> json) {
    String v(String key) => json[key]?.toString() ?? '-';
    return NbaPlayerStat(
      name: v('column_1_text'),
      starter: v('column_2_text') == '是',
      minutes: v('column_3_text'),
      points: v('column_4_text'),
      rebounds: v('column_5_text'),
      assists: v('column_6_text'),
      fieldGoals: v('column_7_text'),
      threePointers: v('column_8_text'),
      freeThrows: v('column_9_text'),
      steals: v('column_10_text'),
      blocks: v('column_11_text'),
      turnovers: v('column_12_text'),
      fouls: v('column_13_text'),
    );
  }

  /// 腾讯 playerStats 行：row=[号码,姓名,时间,得分,...]
  factory NbaPlayerStat.fromTencent(Map<String, dynamic> json) {
    final row = (json['row'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];
    String at(int i) => i < row.length && row[i].isNotEmpty ? row[i] : '-';
    return NbaPlayerStat(
      name: at(1),
      playerId: json['playerId']?.toString(),
      avatar: json['pic']?.toString(),
      starter: json['onCrt']?.toString() == '1',
      minutes: at(2),
      points: at(3),
      rebounds: at(4),
      assists: at(5),
      fieldGoals: at(6),
      threePointers: at(7),
      freeThrows: at(8),
      steals: at(9),
      blocks: at(10),
      turnovers: at(11),
      fouls: at(12),
    );
  }
}

class NbaTeamPlayerBoard {
  final String team;
  final String? logo;
  final List<NbaPlayerStat> players;

  const NbaTeamPlayerBoard({
    required this.team,
    this.logo,
    required this.players,
  });
}

class NbaMatchDetail {
  final NbaMatchBrief brief;
  final List<String> periodLabels;
  final List<NbaQuarterScore> quarters;
  final List<String> teamStatLabels;
  final List<NbaTeamStat> teamStats;
  final List<NbaTeamPlayerBoard> playerBoards;

  const NbaMatchDetail({
    required this.brief,
    required this.periodLabels,
    required this.quarters,
    required this.teamStatLabels,
    required this.teamStats,
    required this.playerBoards,
  });
}

/// 排行赛季选项
class NbaRankSeason {
  final String name;
  final String shortName;
  final String seasonId;
  final String seasonType;

  const NbaRankSeason({
    required this.name,
    required this.shortName,
    required this.seasonId,
    required this.seasonType,
  });

  String get label => shortName.isNotEmpty ? shortName : name;

  factory NbaRankSeason.fromTencent(Map<String, dynamic> json) {
    return NbaRankSeason(
      name: json['name']?.toString() ?? '',
      shortName: json['shortName']?.toString() ?? '',
      seasonId: json['seasonId']?.toString() ?? '',
      seasonType: json['seasonType']?.toString() ?? '',
    );
  }
}

/// 球队积分榜（东部 / 西部）
class NbaTeamStanding {
  final int rank;
  final String team;
  final String? teamId;
  final String? logo;
  final String wins;
  final String losses;
  final String winPct;
  final String pointsFor;
  final String pointsAgainst;
  final String pointDiff;
  final String streak;

  const NbaTeamStanding({
    required this.rank,
    required this.team,
    this.teamId,
    this.logo,
    required this.wins,
    required this.losses,
    required this.winPct,
    this.pointsFor = '-',
    this.pointsAgainst = '-',
    this.pointDiff = '-',
    required this.streak,
  });

  factory NbaTeamStanding.fromSohu(Map<String, dynamic> json) {
    String logo(dynamic v) {
      final s = v?.toString() ?? '';
      if (s.isEmpty) return '';
      if (s.startsWith('http')) return s;
      return 'https://$s';
    }

    String cell(String key) {
      final v = json[key];
      if (v == null) return '-';
      final s = v.toString().trim();
      return s.isEmpty ? '-' : s;
    }

    final rankRaw = json['rank'];
    final rank = rankRaw is num
        ? rankRaw.toInt()
        : int.tryParse(rankRaw?.toString() ?? '') ?? 0;

    return NbaTeamStanding(
      rank: rank,
      team: cell('column_1_text'),
      logo: logo(json['column_10_image']),
      wins: cell('column_7_text'),
      losses: cell('column_8_text'),
      winPct: cell('column_3_text'),
      streak: cell('column_9_text'),
    );
  }

  /// 腾讯体育 statistic/rankings type=0 行数据
  factory NbaTeamStanding.fromTencent(Map<String, dynamic> json) {
    final values = _tencentValueMap(json);
    final team = values['team'];
    String teamName = '-';
    String? logo;
    String? teamId;
    if (team is Map) {
      teamName = (team['cnName'] ?? team['fullCnName'] ?? team['enName'] ?? '-')
          .toString();
      final logoRaw = team['logo']?.toString() ?? '';
      logo = logoRaw.isEmpty ? null : logoRaw;
      teamId = team['id']?.toString();
    } else if (team != null) {
      teamName = team.toString();
    }

    String num(dynamic v) {
      final s = '${v ?? ''}'.trim();
      if (s.isEmpty) return '-';
      if (s.endsWith('.0')) return s.substring(0, s.length - 2);
      return s;
    }

    return NbaTeamStanding(
      rank: int.tryParse('${values['rank'] ?? ''}') ?? 0,
      team: teamName,
      teamId: teamId,
      logo: logo,
      wins: '${values['wins'] ?? '-'}',
      losses: '${values['losses'] ?? '-'}',
      winPct: '${values['winRate'] ?? '-'}',
      pointsFor: num(values['pointsPG']),
      pointsAgainst: num(values['oppPointsPG']),
      pointDiff: num(values['pointsDifference']),
      streak: '${values['streak'] ?? values['last10'] ?? '-'}',
    );
  }
}

/// 球队积分榜拉取结果（含赛季列表）
class NbaTeamStandingsResult {
  final List<NbaTeamStanding> rows;
  final List<NbaRankSeason> seasons;
  final int selectedSeasonIndex;

  const NbaTeamStandingsResult({
    required this.rows,
    required this.seasons,
    required this.selectedSeasonIndex,
  });
}

/// 球员排行拉取结果（含赛季列表）
class NbaPlayerRanksResult {
  final List<NbaPlayerRank> rows;
  final List<NbaRankSeason> seasons;
  final int selectedSeasonIndex;

  const NbaPlayerRanksResult({
    required this.rows,
    required this.seasons,
    required this.selectedSeasonIndex,
  });
}

/// 球员数据排行（得分 / 篮板 / …）
class NbaPlayerRank {
  final int rank;
  final String name;
  final String? playerId;
  final String? avatar;
  final String team;
  final String? teamId;
  final String? teamLogo;
  final String games;
  final String value;

  const NbaPlayerRank({
    required this.rank,
    required this.name,
    this.playerId,
    this.avatar,
    required this.team,
    this.teamId,
    this.teamLogo,
    this.games = '-',
    required this.value,
  });

  factory NbaPlayerRank.fromSohu(
    Map<String, dynamic> json, {
    required String valueKey,
    required int index,
  }) {
    String cell(String key) {
      final v = json[key];
      if (v == null) return '-';
      final s = v.toString().trim();
      return s.isEmpty ? '-' : s;
    }

    final rankRaw = json['rank'];
    final rank = rankRaw is num
        ? rankRaw.toInt()
        : int.tryParse(rankRaw?.toString() ?? '') ?? (index + 1);

    return NbaPlayerRank(
      rank: rank <= 0 ? index + 1 : rank,
      name: cell('column_1_text'),
      team: cell('column_3_text'),
      value: cell(valueKey),
    );
  }

  /// 腾讯体育 statistic/rankings type=2 行数据
  factory NbaPlayerRank.fromTencent(Map<String, dynamic> json) {
    final values = _tencentValueMap(json);
    final player = values['player'];
    final team = values['team'];

    String name = '-';
    String? avatar;
    String? playerId;
    if (player is Map) {
      name = (player['cnName'] ??
              player['fullCnName'] ??
              player['enName'] ??
              '-')
          .toString();
      final avatarRaw = player['logo']?.toString() ?? '';
      avatar = avatarRaw.isEmpty ? null : avatarRaw;
      playerId = player['id']?.toString();
    } else if (player != null) {
      name = player.toString();
    }

    String teamName = '-';
    String? teamLogo;
    String? teamId;
    if (team is Map) {
      teamName = (team['cnName'] ?? team['fullCnName'] ?? team['enName'] ?? '-')
          .toString();
      final logoRaw = team['logo']?.toString() ?? '';
      teamLogo = logoRaw.isEmpty ? null : logoRaw;
      teamId = team['id']?.toString();
    } else if (team != null) {
      teamName = team.toString();
    }

    final rank = int.tryParse('${values['rank'] ?? ''}') ?? 0;
    final gamesRaw = '${values['games'] ?? ''}'.trim();

    return NbaPlayerRank(
      rank: rank <= 0 ? 0 : rank,
      name: name,
      playerId: playerId,
      avatar: avatar,
      team: teamName,
      teamId: teamId,
      teamLogo: teamLogo,
      games: gamesRaw.isEmpty ? '-' : gamesRaw,
      value: '${values['rankValue'] ?? '-'}',
    );
  }
}

/// 腾讯球队资料（弹框）
class NbaTeamProfile {
  final String teamId;
  final String name;
  final String? enName;
  final String? logo;
  final String? city;
  final String? venue;
  final String? coach;
  final String? brief;
  final String? record;
  final String? rankText;
  final List<NbaTeamRosterPlayer> roster;
  final List<NbaStatCompareItem> compares;

  const NbaTeamProfile({
    required this.teamId,
    required this.name,
    this.enName,
    this.logo,
    this.city,
    this.venue,
    this.coach,
    this.brief,
    this.record,
    this.rankText,
    this.roster = const [],
    this.compares = const [],
  });
}

class NbaTeamRosterPlayer {
  final String playerId;
  final String name;
  final String? logo;
  final String? position;
  final String? jerseyNum;

  const NbaTeamRosterPlayer({
    required this.playerId,
    required this.name,
    this.logo,
    this.position,
    this.jerseyNum,
  });
}

/// 腾讯球员资料（弹框）
class NbaPlayerProfile {
  final String playerId;
  final String name;
  final String? enName;
  final String? logo;
  final String? teamId;
  final String? teamName;
  final String? teamLogo;
  final String? position;
  final String? jerseyNum;
  final String? height;
  final String? weight;
  final String? birthDate;
  final List<NbaStatCompareItem> compares;
  final List<String> seasonHeaders;
  final List<List<String>> seasonAvgRows;

  const NbaPlayerProfile({
    required this.playerId,
    required this.name,
    this.enName,
    this.logo,
    this.teamId,
    this.teamName,
    this.teamLogo,
    this.position,
    this.jerseyNum,
    this.height,
    this.weight,
    this.birthDate,
    this.compares = const [],
    this.seasonHeaders = const [],
    this.seasonAvgRows = const [],
  });
}

class NbaStatCompareItem {
  final String type;
  final String value;
  final String? serial;

  const NbaStatCompareItem({
    required this.type,
    required this.value,
    this.serial,
  });
}

class NbaPlayerRankCategory {
  final String label;
  /// 腾讯 group code，如 point / rebound / assist
  final String code;

  const NbaPlayerRankCategory({
    required this.label,
    required this.code,
  });
}

Map<String, dynamic> _tencentValueMap(Map<String, dynamic> json) {
  final values = json['values'];
  final map = <String, dynamic>{};
  if (values is! List) return map;
  for (final item in values) {
    if (item is! Map) continue;
    final code = item['code']?.toString();
    if (code == null || code.isEmpty) continue;
    map[code] = item['value'];
  }
  return map;
}

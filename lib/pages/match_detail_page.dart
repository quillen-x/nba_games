import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nba_games/models/nba_game_model.dart';
import 'package:nba_games/request/tencent_nba_api.dart';
import 'package:nba_games/widgets/profile_dialogs.dart';

/// 手机端：独立详情页
class MatchDetailPage extends StatelessWidget {
  final String? url;
  final String? topicId;
  final String? title;

  const MatchDetailPage({
    super.key,
    this.url,
    this.topicId,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title ?? '比赛详情',
          style: theme.textTheme.titleSmall,
        ),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: MatchDetailPanel(
          url: url,
          topicId: topicId,
        ),
      ),
    );
  }
}

/// 嵌入主页右侧 / 详情页的比赛详情面板
class MatchDetailPanel extends StatefulWidget {
  final String? url;
  final String? topicId;

  const MatchDetailPanel({
    super.key,
    this.url,
    this.topicId,
  });

  @override
  State<MatchDetailPanel> createState() => _MatchDetailPanelState();
}

class _MatchDetailPanelState extends State<MatchDetailPanel> {
  static const _detailRefreshInterval = Duration(seconds: 10);
  /// 暂时隐藏每节得分 / 技术统计，改 true 可恢复
  static const _showExtraStats = false;

  NbaMatchDetail? _detail;
  bool _loading = false;
  bool _refreshing = false;
  String? _error;
  int _playerTeamIndex = 0;
  String? _loadedKey;
  Timer? _detailTimer;

  @override
  void initState() {
    super.initState();
    _loadIfNeeded(force: true);
    _startDetailTimer();
  }

  @override
  void dispose() {
    _detailTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MatchDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topicId != widget.topicId || oldWidget.url != widget.url) {
      _startDetailTimer();
      _loadIfNeeded(force: true);
    }
  }

  String? get _requestKey => widget.topicId ?? widget.url;

  bool get _isFinished => _detail?.brief.isFinished == true;

  void _startDetailTimer() {
    _detailTimer?.cancel();
    _detailTimer = Timer.periodic(_detailRefreshInterval, (_) {
      if (_isFinished) {
        _detailTimer?.cancel();
        _detailTimer = null;
        return;
      }
      _loadIfNeeded(force: true, silent: true);
    });
  }

  Future<void> _loadIfNeeded({
    bool force = false,
    bool silent = false,
  }) async {
    final key = _requestKey;
    if (key == null || key.isEmpty) {
      setState(() {
        _detail = null;
        _loading = false;
        _error = null;
        _loadedKey = null;
      });
      return;
    }
    // 已结束比赛：保留已有详情，不再自动刷新
    if (silent && _isFinished) return;
    if (!force && key == _loadedKey && _detail != null) return;
    if (_refreshing) return;
    _refreshing = true;

    final switchGame = key != _loadedKey;
    if (!silent || _detail == null) {
      setState(() {
        _loading = true;
        if (!silent) _error = null;
      });
    }

    try {
      final detail = await TencentNbaApi.getMatchDetail(
        url: widget.url,
        topicId: widget.topicId,
        mid: widget.topicId,
      );
      if (!mounted) return;
      if (_requestKey != key) return;
      setState(() {
        _detail = detail;
        if (switchGame) _playerTeamIndex = 0;
        _loading = false;
        _error = null;
        _loadedKey = key;
      });
      if (detail.brief.isFinished) {
        _detailTimer?.cancel();
        _detailTimer = null;
      } else if (_detailTimer == null) {
        _startDetailTimer();
      }
    } catch (e) {
      if (!mounted) return;
      if (_requestKey != key) return;
      setState(() {
        if (_detail == null) _error = e.toString();
        _loading = false;
        _loadedKey = key;
      });
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_requestKey == null) {
      return Center(
        child: Text('选择左侧比赛查看详情', style: theme.textTheme.bodyMedium),
      );
    }

    return _buildBody(theme);
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading && _detail == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null && _detail == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('加载失败', style: theme.textTheme.titleSmall),
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Text(_error!, style: theme.textTheme.bodyMedium),
            ),
            SizedBox(height: 16.h),
            TextButton(
              onPressed: () => _loadIfNeeded(force: true),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final detail = _detail!;
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
          children: [
            _ScoreHeader(
              brief: detail.brief,
              selectedTeamIndex: _playerTeamIndex,
              onSelectTeam: (i) => setState(() => _playerTeamIndex = i),
              onOpenTeam: (teamId) => showTeamDialog(context, teamId: teamId),
            ),
            SizedBox(height: 8.h),
            if (detail.playerBoards.isNotEmpty)
              _PlayerStatsTable(
                board: detail.playerBoards[
                    _playerTeamIndex.clamp(0, detail.playerBoards.length - 1)],
                onPlayerTap: (playerId) =>
                    showPlayerDialog(context, playerId: playerId),
              ),
            if (_showExtraStats) ...[
              SizedBox(height: 20.h),
              const _SectionTitle('每节得分'),
              SizedBox(height: 8.h),
              _QuarterTable(detail: detail),
              SizedBox(height: 20.h),
              const _SectionTitle('技术统计'),
              SizedBox(height: 8.h),
              _TeamStatsTable(detail: detail),
            ],
          ],
        ),
        if (_loading)
          Positioned(
            top: 8.h,
            right: 20.w,
            child: SizedBox(
              width: 16.w,
              height: 16.w,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 3.w,
          height: 14.h,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 8.w),
        Text(text, style: theme.textTheme.titleSmall),
      ],
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  final NbaMatchBrief brief;
  final int selectedTeamIndex;
  final ValueChanged<int> onSelectTeam;
  final ValueChanged<String> onOpenTeam;

  const _ScoreHeader({
    required this.brief,
    required this.selectedTeamIndex,
    required this.onSelectTeam,
    required this.onOpenTeam,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusExtra = [
      if (brief.periodName != null &&
          brief.periodName!.isNotEmpty &&
          brief.periodName != brief.status)
        brief.periodName!,
      if (brief.remainTime != null && brief.remainTime!.isNotEmpty)
        brief.remainTime!,
    ].join(' · ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14171E) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        child: Column(
          children: [
            Text(
              [
                brief.matchType,
                if (brief.startTimeText != null) brief.startTimeText!,
                if (brief.venue != null && brief.venue!.isNotEmpty) brief.venue!,
              ].where((e) => e.isNotEmpty).join('  ·  '),
              style: theme.textTheme.bodyMedium,
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _HeaderTeam(
                    name: brief.homeTeam,
                    logo: brief.homeLogo,
                    score: brief.homeScore,
                    alignEnd: false,
                    selected: selectedTeamIndex == 0,
                    onTap: () => onSelectTeam(0),
                    onLongPress: brief.homeTeamId.isEmpty
                        ? null
                        : () => onOpenTeam(brief.homeTeamId),
                    onOpen: brief.homeTeamId.isEmpty
                        ? null
                        : () => onOpenTeam(brief.homeTeamId),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  child: Column(
                    children: [
                      Text(
                        brief.status,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: brief.status.contains('进行') ||
                                  brief.status.contains('第')
                              ? const Color(0xFFE53935)
                              : theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (statusExtra.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(statusExtra, style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: _HeaderTeam(
                    name: brief.awayTeam,
                    logo: brief.awayLogo,
                    score: brief.awayScore,
                    alignEnd: true,
                    selected: selectedTeamIndex == 1,
                    onTap: () => onSelectTeam(1),
                    onLongPress: brief.awayTeamId.isEmpty
                        ? null
                        : () => onOpenTeam(brief.awayTeamId),
                    onOpen: brief.awayTeamId.isEmpty
                        ? null
                        : () => onOpenTeam(brief.awayTeamId),
                  ),
                ),
              ],
            ),
           
          ],
        ),
      ),
    );
  }
}

class _HeaderTeam extends StatelessWidget {
  final String name;
  final String? logo;
  final String? score;
  final bool alignEnd;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onOpen;

  const _HeaderTeam({
    required this.name,
    required this.logo,
    required this.score,
    required this.alignEnd,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final logoWidget = GestureDetector(
      onTap: onOpen,
      child: logo != null && logo!.isNotEmpty
          ? Image.network(
              logo!,
              width: 36.w,
              height: 36.w,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.sports_basketball, size: 28.sp),
            )
          : Icon(Icons.sports_basketball, size: 28.sp),
    );

    final children = <Widget>[
      logoWidget,
      SizedBox(width: 8.w),
      Flexible(
        child: Column(
          crossAxisAlignment:
              alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? theme.colorScheme.primary : null,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              score ?? '-',
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ];

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        child: Row(
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: alignEnd ? children.reversed.toList() : children,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14171E) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: child,
    );
  }
}

class _QuarterTable extends StatelessWidget {
  final NbaMatchDetail detail;
  const _QuarterTable({required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cols = <int>[0, 1, 2, 3];
    for (var i = 4; i < detail.periodLabels.length; i++) {
      final hasOt = detail.quarters.any((q) {
        if (i >= q.periods.length) return false;
        final v = q.periods[i];
        return v.isNotEmpty && v != '-' && v != 'null';
      });
      if (hasOt) cols.add(i);
    }

    return _Panel(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.all(12.w),
        child: DataTable(
          headingRowHeight: 36.h,
          dataRowMinHeight: 40.h,
          dataRowMaxHeight: 48.h,
          columnSpacing: 18.w,
          columns: [
            DataColumn(
              label: Text('球队', style: theme.textTheme.labelSmall),
            ),
            ...cols.map(
              (i) => DataColumn(
                label: Text(detail.periodLabels[i],
                    style: theme.textTheme.labelSmall),
              ),
            ),
            DataColumn(
              label: Text('总分', style: theme.textTheme.labelSmall),
            ),
          ],
          rows: detail.quarters
              .map(
                (q) => DataRow(cells: [
                  DataCell(Row(
                    children: [
                      if (q.logo != null && q.logo!.isNotEmpty)
                        Image.network(q.logo!,
                            width: 20.w,
                            height: 20.w,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink()),
                      if (q.logo != null && q.logo!.isNotEmpty)
                        SizedBox(width: 6.w),
                      Text(q.team, style: theme.textTheme.bodyLarge),
                    ],
                  )),
                  ...cols.map(
                    (i) => DataCell(Text(
                      q.periods[i],
                      style: theme.textTheme.bodyLarge,
                    )),
                  ),
                  DataCell(Text(
                    q.total,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  )),
                ]),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _TeamStatsTable extends StatelessWidget {
  final NbaMatchDetail detail;
  const _TeamStatsTable({required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (detail.teamStats.length < 2) {
      return _Panel(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Text('暂无技术统计', style: theme.textTheme.bodyMedium),
        ),
      );
    }

    final left = detail.teamStats.first;
    final right = detail.teamStats.last;

    return _Panel(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    left.team,
                    textAlign: TextAlign.left,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text('对比', style: theme.textTheme.bodyMedium),
                Expanded(
                  child: Text(
                    right.team,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            ...detail.teamStatLabels.map((label) {
              final lv = left.values[label] ?? '-';
              final rv = right.values[label] ?? '-';
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 6.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        lv,
                        textAlign: TextAlign.left,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    SizedBox(
                      width: 100.w,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rv,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PlayerStatsTable extends StatelessWidget {
  final NbaTeamPlayerBoard board;
  final ValueChanged<String>? onPlayerTap;

  const _PlayerStatsTable({
    required this.board,
    this.onPlayerTap,
  });

  static const _headers = [
    '球员',
    '时间',
    '得分',
    '篮板',
    '助攻',
    '投篮',
    '三分',
    '罚球',
    '抢断',
    '盖帽',
    '失误',
    '犯规',
  ];

  static const _widths = [
    150.0,
    44.0,
    44.0,
    44.0,
    44.0,
    58.0,
    58.0,
    58.0,
    44.0,
    44.0,
    44.0,
    44.0,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (board.players.isEmpty) {
      return _Panel(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Text('暂无球员统计', style: theme.textTheme.bodyMedium),
        ),
      );
    }

    final maxPoints = board.players
        .map((p) => int.tryParse(p.points) ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);

    final headStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: theme.textTheme.bodyMedium?.color,
    );
    final cellStyle = theme.textTheme.bodyMedium?.copyWith(fontSize: 12.sp);

    return _Panel(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03),
                child: Row(
                  children: [
                    for (var i = 0; i < _headers.length; i++)
                      SizedBox(
                        width: _widths[i].w,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: i == 0 ? 12.w : 0,
                            vertical: 10.h,
                          ),
                          child: Text(
                            _headers[i],
                            textAlign:
                                i == 0 ? TextAlign.left : TextAlign.center,
                            style: headStyle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ...List.generate(board.players.length, (index) {
                final player = board.players[index];
                final values = [
                  player.starter ? '${player.name}*' : player.name,
                  player.minutes,
                  player.points,
                  player.rebounds,
                  player.assists,
                  player.fieldGoals,
                  player.threePointers,
                  player.freeThrows,
                  player.steals,
                  player.blocks,
                  player.turnovers,
                  player.fouls,
                ];
                final highlightPoints = maxPoints > 0 &&
                    (int.tryParse(player.points) ?? 0) == maxPoints;
                final rowBg = index.isOdd
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.025)
                        : Colors.black.withValues(alpha: 0.015))
                    : Colors.transparent;
                final canOpen = player.playerId != null &&
                    player.playerId!.isNotEmpty &&
                    onPlayerTap != null;

                return ColoredBox(
                  color: rowBg,
                  child: InkWell(
                    onTap: canOpen
                        ? () => onPlayerTap!(player.playerId!)
                        : null,
                    child: Row(
                      children: [
                        for (var i = 0; i < values.length; i++)
                          SizedBox(
                            width: _widths[i].w,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: i == 0 ? 12.w : 0,
                                vertical: 8.h,
                              ),
                              child: i == 0
                                  ? Row(
                                      children: [
                                        if (player.avatar != null &&
                                            player.avatar!.isNotEmpty) ...[
                                          ClipOval(
                                            child: Image.network(
                                              player.avatar!,
                                              width: 20.w,
                                              height: 20.w,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Icon(Icons.person,
                                                      size: 14.sp),
                                            ),
                                          ),
                                          SizedBox(width: 6.w),
                                        ],
                                        Expanded(
                                          child: Text(
                                            _display(values[i]),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                              fontSize: 12.5.sp,
                                              color: canOpen
                                                  ? theme.colorScheme.primary
                                                  : null,
                                              fontWeight: canOpen
                                                  ? FontWeight.w600
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      _display(values[i]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: i == 2
                                          ? cellStyle?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: highlightPoints
                                                  ? theme.colorScheme.primary
                                                  : null,
                                            )
                                          : cellStyle,
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
              SizedBox(height: 4.h),
            ],
          ),
        ),
      ),
    );
  }

  String _display(String value) {
    if (value.isEmpty || value == 'null' || value == 'None') return '-';
    return value;
  }
}

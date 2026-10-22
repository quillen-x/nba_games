import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nba_games/models/nba_game_model.dart';
import 'package:nba_games/pages/match_detail_page.dart';
import 'package:nba_games/request/tencent_nba_api.dart';
import 'package:nba_games/widgets/rank_dialog.dart';
import 'package:nba_games/widgets/theme_settings_button.dart';
import 'package:window_manager/window_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _scheduleRefreshInterval = Duration(seconds: 30);
  /// 今日末场开赛后多久停止赛程自动刷新
  static const _stopAutoRefreshAfterLastGame = Duration(hours: 2, minutes: 30);
  static const _wideBreakpoint = 800.0;

  List<NbaScheduleDay> _days = const [];
  int _mobileTabIndex = 0;
  NbaGame? _selectedGame;
  bool _loading = true;
  bool _refreshing = false;
  bool _autoRefreshStopped = false;
  String? _error;
  Timer? _scheduleTimer;

  bool get _isDesktopOs {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  bool _isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= _wideBreakpoint;

  @override
  void initState() {
    super.initState();
    _load();
    _scheduleTimer = Timer.periodic(_scheduleRefreshInterval, (_) {
      if (_autoRefreshStopped) return;
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _scheduleTimer?.cancel();
    super.dispose();
  }

  /// 今日最后一场已过 2.5 小时，且无进行中/未开始场次 → 停止自动刷新
  bool _shouldStopAutoRefresh(List<NbaScheduleDay> days) {
    final todayIndex = days.indexWhere((d) => d.isToday || d.label == '今日');
    if (todayIndex < 0) return false;

    final games = days[todayIndex].games;
    if (games.isEmpty) return true;

    for (final g in games) {
      if (g.isLive || g.isUpcoming) return false;
    }

    NbaGame? last;
    for (final g in games) {
      if (last == null) {
        last = g;
        continue;
      }
      final a = g.startTimeMs ?? 0;
      final b = last.startTimeMs ?? 0;
      if (a > b) last = g;
    }
    final startMs = last?.startTimeMs;
    if (startMs == null || startMs <= 0) {
      // 无开赛时间时：今日场次均已结束则停止
      return games.every((g) => g.isFinished);
    }

    final deadline = DateTime.fromMillisecondsSinceEpoch(startMs)
        .add(_stopAutoRefreshAfterLastGame);
    return DateTime.now().isAfter(deadline);
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) return;
    if (silent && _autoRefreshStopped) return;
    _refreshing = true;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final days = await TencentNbaApi.getSchedule(dayCount: 5);
      if (!mounted) return;

      NbaGame? selected = _selectedGame;

      if (selected?.topicId != null) {
        NbaGame? updated;
        for (final day in days) {
          for (final game in day.games) {
            if (game.topicId == selected!.topicId) {
              updated = game;
              break;
            }
          }
          if (updated != null) break;
        }
        selected = updated;
      }

      // 静默刷新不自动改选中场次，避免右侧详情跳动
      if (!silent && selected == null && days.isNotEmpty) {
        final todayIndex =
            days.indexWhere((d) => d.isToday || d.label == '今日');
        final preferred = days[todayIndex >= 0 ? todayIndex : 0];
        NbaGame? live;
        for (final g in preferred.games) {
          if (g.isLive) {
            live = g;
            break;
          }
        }
        selected = live ??
            (preferred.games.isNotEmpty ? preferred.games.first : null);
        if (selected == null) {
          for (final day in days) {
            if (day.games.isNotEmpty) {
              selected = day.games.first;
              break;
            }
          }
        }
      }

      final stopAuto = _shouldStopAutoRefresh(days);
      if (stopAuto && !_autoRefreshStopped) {
        _autoRefreshStopped = true;
        _scheduleTimer?.cancel();
        _scheduleTimer = null;
      }

      setState(() {
        _days = days;
        if (selected != null || !silent) {
          _selectedGame = selected;
        }
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent || _days.isEmpty) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _selectGame(NbaGame game) async {
    if (game.topicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该场比赛暂无详情')),
      );
      return;
    }

    if (_isWide(context)) {
      setState(() => _selectedGame = game);
      return;
    }

    setState(() => _selectedGame = game);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchDetailPage(
          url: game.url,
          topicId: game.topicId,
          title: '${game.homeTeam} VS ${game.awayTeam}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);

    if (!wide) {
      return _buildMobileScaffold(context);
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              if (_isDesktopOs)
                _WindowTitleBar(
                  title: 'NBA Games',
                  onOpenRank: () => showRankDialog(context),
                ),
              Expanded(child: _buildDesktopBody(context)),
            ],
          ),
          const ThemeSettingsButton(),
        ],
      ),
    );
  }

  Widget _buildMobileScaffold(BuildContext context) {
    final theme = Theme.of(context);
    final titles = ['赛程', '排行'];

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: _MobileAppBar(
                  title: titles[_mobileTabIndex],
                  showRefresh: _mobileTabIndex == 0,
                  onRefresh: () => _load(),
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _mobileTabIndex,
                  children: [
                    _buildScheduleContent(context, selectedGame: null),
                    const RankBody(),
                  ],
                ),
              ),
            ],
          ),
          ThemeSettingsButton(
            bottomOffset: kBottomNavigationBarHeight + 8.h,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _mobileTabIndex,
        onDestinationSelected: (i) => setState(() => _mobileTabIndex = i),
        height: 64.h,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined, size: 22.sp),
            selectedIcon: Icon(Icons.calendar_month, size: 22.sp),
            label: '赛程',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined, size: 22.sp),
            selectedIcon: Icon(Icons.leaderboard, size: 22.sp),
            label: '排行',
          ),
        ],
        indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      ),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final schedule = _buildScheduleContent(
      context,
      selectedGame: _selectedGame,
    );

    if (_loading || _error != null || _days.isEmpty) {
      return schedule;
    }

    return Row(
      children: [
        SizedBox(
          width: 270.w,
          child: schedule,
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
        Expanded(
          child: MatchDetailPanel(
            key: ValueKey(_selectedGame?.topicId ?? 'empty'),
            url: _selectedGame?.url,
            topicId: _selectedGame?.topicId,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleContent(
    BuildContext context, {
    required NbaGame? selectedGame,
  }) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('加载失败', style: theme.textTheme.titleSmall),
              SizedBox(height: 8.h),
              Text(_error!, style: theme.textTheme.bodyMedium),
              SizedBox(height: 16.h),
              TextButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    if (_days.isEmpty) {
      return Center(child: Text('暂无赛程', style: theme.textTheme.titleSmall));
    }

    return _SchedulePane(
      days: _days,
      selectedGame: selectedGame,
      onSelectGame: _selectGame,
    );
  }
}

class _MobileAppBar extends StatelessWidget {
  final String title;
  final bool showRefresh;
  final VoidCallback onRefresh;

  const _MobileAppBar({
    required this.title,
    required this.showRefresh,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 48.h,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (showRefresh)
            IconButton(
              tooltip: '刷新',
              onPressed: onRefresh,
              icon: Icon(Icons.refresh_rounded, size: 20.sp),
            ),
        ],
      ),
    );
  }
}

class _SchedulePane extends StatefulWidget {
  final List<NbaScheduleDay> days;
  final NbaGame? selectedGame;
  final ValueChanged<NbaGame> onSelectGame;

  const _SchedulePane({
    required this.days,
    required this.selectedGame,
    required this.onSelectGame,
  });

  @override
  State<_SchedulePane> createState() => _SchedulePaneState();
}

class _SchedulePaneState extends State<_SchedulePane> {
  final _todayKey = GlobalKey();
  final _scrollController = ScrollController();
  bool _didScrollToToday = false;

  @override
  void initState() {
    super.initState();
    // 仅首次进入滚到今日，后续刷新保持当前位置
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToToday() {
    if (_didScrollToToday) return;
    final ctx = _todayKey.currentContext;
    if (ctx == null) return;
    _didScrollToToday = true;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  String _dateHeader(NbaScheduleDay day) {
    if (day.isToday || day.label == '今日') {
      final monthDay = day.date.length >= 10 ? day.date.substring(5) : day.date;
      return '今日  $monthDay ${day.weekday}'.trim();
    }
    return day.label;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.days.isEmpty) {
      return Center(child: Text('暂无赛程', style: theme.textTheme.bodyMedium));
    }

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 24.h),
      children: [
        for (var dayIndex = 0; dayIndex < widget.days.length; dayIndex++)
          Builder(
            builder: (context) {
              final day = widget.days[dayIndex];
              final isToday = day.isToday || day.label == '今日';
              return KeyedSubtree(
                key: isToday ? _todayKey : ValueKey('day-${day.date}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        4.w,
                        dayIndex == 0 ? 0 : 16.h,
                        4.w,
                        8.h,
                      ),
                      child: Text(
                        _dateHeader(day),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.sp,
                          color: isToday ? theme.colorScheme.primary : null,
                        ),
                      ),
                    ),
                    if (day.games.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        child: Text(
                          '当日暂无比赛',
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    else
                      for (var i = 0; i < day.games.length; i++) ...[
                        if (i > 0) SizedBox(height: 8.h),
                        _GameCard(
                          game: day.games[i],
                          selected: widget.selectedGame?.topicId != null &&
                              widget.selectedGame!.topicId ==
                                  day.games[i].topicId,
                          onTap: () => widget.onSelectGame(day.games[i]),
                        ),
                      ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _GameCard extends StatelessWidget {
  final NbaGame game;
  final bool selected;
  final VoidCallback onTap;

  const _GameCard({
    required this.game,
    required this.selected,
    required this.onTap,
  });

  Color _statusColor(BuildContext context) {
    final theme = Theme.of(context);
    if (game.isLive) return const Color(0xFFE53935);
    if (game.isFinished) {
      return theme.brightness == Brightness.dark
          ? const Color(0xFF8B929E)
          : const Color(0xFF6B7280);
    }
    return theme.colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = selected
        ? theme.colorScheme.primary
        : (isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.06));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? (isDark
                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                    : theme.colorScheme.primary.withValues(alpha: 0.06))
                : (isDark ? const Color(0xFF14171E) : Colors.white),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: border, width: selected ? 1.5 : 1),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      game.timeText,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      game.status,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _statusColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      game.matchType.replaceFirst('NBA ', ''),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                _TeamRow(
                  name: game.homeTeam,
                  logo: game.homeLogo,
                  score: game.homeScore,
                ),
                SizedBox(height: 6.h),
                _TeamRow(
                  name: game.awayTeam,
                  logo: game.awayLogo,
                  score: game.awayScore,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  final String name;
  final String? logo;
  final String? score;

  const _TeamRow({
    required this.name,
    required this.logo,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (logo != null && logo!.isNotEmpty)
          Image.network(
            logo!,
            width: 22.w,
            height: 22.w,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.sports_basketball, size: 18.sp),
          )
        else
          Icon(Icons.sports_basketball, size: 18.sp),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          score ?? '-',
          style: theme.textTheme.titleSmall?.copyWith(fontSize: 15.sp),
        ),
      ],
    );
  }
}

class _WindowTitleBar extends StatelessWidget {
  final String title;
  final VoidCallback onOpenRank;

  const _WindowTitleBar({
    required this.title,
    required this.onOpenRank,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DragToMoveArea(
      child: Container(
        height: 48.h,
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13.sp,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onOpenRank,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  minimumSize: Size(0, 32.h),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '排行',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

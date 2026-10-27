import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nba_games/models/nba_game_model.dart';
import 'package:nba_games/request/tencent_nba_api.dart';
import 'package:nba_games/widgets/app_cached_image.dart';
import 'package:nba_games/widgets/profile_dialogs.dart';

void showRankDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => const _RankDialog(),
  );
}

class _RankDialog extends StatelessWidget {
  const _RankDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 800;
    final maxW = wide ? 560.0 : size.width * 0.9;
    final maxH = size.height * (wide ? 0.9 : 0.92);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: SizedBox(
        width: maxW,
        height: maxH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 0),
              child: Row(
                children: [
                  Text(
                    '球队 / 球员排行',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, size: 20.sp),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            const Expanded(child: RankBody()),
          ],
        ),
      ),
    );
  }
}

/// 球队 / 球员排行内容（桌面弹窗与手机 Tab 共用）
class RankBody extends StatefulWidget {
  const RankBody({super.key});

  @override
  State<RankBody> createState() => _RankBodyState();
}

class _RankBodyState extends State<RankBody>
    with SingleTickerProviderStateMixin {
  late final TabController _mainTab;

  @override
  void initState() {
    super.initState();
    _mainTab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _mainTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        TabBar(
          controller: _mainTab,
          labelStyle: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: theme.textTheme.bodyLarge,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: '球队'),
            Tab(text: '球员'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _mainTab,
            children: const [
              _TeamStandingsPane(),
              _PlayerRanksPane(),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeamStandingsPane extends StatefulWidget {
  const _TeamStandingsPane();

  @override
  State<_TeamStandingsPane> createState() => _TeamStandingsPaneState();
}

class _TeamStandingsPaneState extends State<_TeamStandingsPane> {
  static const _conferences = ['东部', '西部'];
  int _index = 0;
  int _seasonIndex = 0;
  bool _loading = true;
  String? _error;
  List<NbaTeamStanding> _rows = const [];
  List<NbaRankSeason> _seasons = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  NbaRankSeason? get _season =>
      _seasons.isEmpty ? null : _seasons[_seasonIndex.clamp(0, _seasons.length - 1)];

  Future<void> _load({bool forceSeasonRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final season = _season;
      final result = await TencentNbaApi.getTeamStandings(
        conference: _conferences[_index],
        seasonId: season?.seasonId,
        seasonType: season?.seasonType,
        forceRefresh: forceSeasonRefresh,
      );
      if (!mounted) return;
      setState(() {
        _rows = result.rows;
        if (result.seasons.isNotEmpty) {
          _seasons = result.seasons;
          if (season == null) {
            _seasonIndex = result.selectedSeasonIndex
                .clamp(0, result.seasons.length - 1);
          } else {
            final i = _seasons.indexWhere(
              (e) =>
                  e.seasonId == season.seasonId &&
                  e.seasonType == season.seasonType,
            );
            if (i >= 0) {
              _seasonIndex = i;
            } else {
              _seasonIndex = result.selectedSeasonIndex
                  .clamp(0, result.seasons.length - 1);
            }
          }
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_seasons.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 0),
            child: _SegmentedChips(
              labels: _seasons.map((e) => e.label).toList(),
              selectedIndex: _seasonIndex,
              onSelected: (i) {
                if (i == _seasonIndex) return;
                setState(() => _seasonIndex = i);
                _load(forceSeasonRefresh: true);
              },
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 4.h),
          child: _SegmentedChips(
            labels: _conferences,
            selectedIndex: _index,
            onSelected: (i) {
              if (i == _index) return;
              setState(() => _index = i);
              _load();
            },
          ),
        ),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return _ErrorRetry(message: _error!, onRetry: _load);
    }
    if (_rows.isEmpty) {
      return Center(child: Text('暂无数据', style: theme.textTheme.bodyMedium));
    }

    return Column(
      children: [
        _TableHeader(
          cells: const [
            _HeaderCell('排名', flex: 1),
            _HeaderCell('球队', flex: 3, align: TextAlign.left),
            _HeaderCell('胜', flex: 1),
            _HeaderCell('负', flex: 1),
            _HeaderCell('胜率', flex: 2),
            _HeaderCell('得分', flex: 2),
            _HeaderCell('失分', flex: 2),
            _HeaderCell('净胜', flex: 2),
            _HeaderCell('近况', flex: 2),
          ],
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: 12.h),
            itemCount: _rows.length,
            itemBuilder: (context, index) {
              final row = _rows[index];
              return _TableRow(
                zebra: index.isOdd,
                onTap: row.teamId == null || row.teamId!.isEmpty
                    ? null
                    : () => showTeamDialog(context, teamId: row.teamId!),
                cells: [
                  _DataCell('${row.rank}', flex: 1),
                  _DataCell(
                    row.team,
                    flex: 3,
                    align: TextAlign.left,
                    leading: _Logo(url: row.logo, size: 20),
                    emphasize: true,
                  ),
                  _DataCell(row.wins, flex: 1),
                  _DataCell(row.losses, flex: 1),
                  _DataCell(row.winPct, flex: 2),
                  _DataCell(row.pointsFor, flex: 2),
                  _DataCell(row.pointsAgainst, flex: 2),
                  _DataCell(row.pointDiff, flex: 2, bold: true),
                  _DataCell(row.streak, flex: 2),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlayerRanksPane extends StatefulWidget {
  const _PlayerRanksPane();

  @override
  State<_PlayerRanksPane> createState() => _PlayerRanksPaneState();
}

class _PlayerRanksPaneState extends State<_PlayerRanksPane> {
  int _index = 0;
  int _seasonIndex = 0;
  bool _loading = true;
  String? _error;
  List<NbaPlayerRank> _rows = const [];
  List<NbaRankSeason> _seasons = const [];

  NbaPlayerRankCategory get _category =>
      TencentNbaApi.playerRankCategories[_index];

  NbaRankSeason? get _season =>
      _seasons.isEmpty ? null : _seasons[_seasonIndex.clamp(0, _seasons.length - 1)];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceSeasonRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final season = _season;
      final result = await TencentNbaApi.getPlayerRanks(
        category: _category,
        seasonId: season?.seasonId,
        seasonType: season?.seasonType,
        forceRefresh: forceSeasonRefresh,
      );
      if (!mounted) return;
      setState(() {
        _rows = result.rows;
        if (result.seasons.isNotEmpty) {
          _seasons = result.seasons;
          if (season == null) {
            _seasonIndex = result.selectedSeasonIndex
                .clamp(0, result.seasons.length - 1);
          } else {
            final i = _seasons.indexWhere(
              (e) =>
                  e.seasonId == season.seasonId &&
                  e.seasonType == season.seasonType,
            );
            if (i >= 0) {
              _seasonIndex = i;
            } else {
              _seasonIndex = result.selectedSeasonIndex
                  .clamp(0, result.seasons.length - 1);
            }
          }
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = TencentNbaApi.playerRankCategories;

    return Column(
      children: [
        if (_seasons.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 0),
            child: _SegmentedChips(
              labels: _seasons.map((e) => e.label).toList(),
              selectedIndex: _seasonIndex,
              onSelected: (i) {
                if (i == _seasonIndex) return;
                setState(() => _seasonIndex = i);
                _load(forceSeasonRefresh: true);
              },
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 4.h),
          child: _SegmentedChips(
            labels: cats.map((e) => e.label).toList(),
            selectedIndex: _index,
            onSelected: (i) {
              if (i == _index) return;
              setState(() => _index = i);
              _load();
            },
          ),
        ),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return _ErrorRetry(message: _error!, onRetry: _load);
    }
    if (_rows.isEmpty) {
      return Center(child: Text('暂无数据', style: theme.textTheme.bodyMedium));
    }

    return Column(
      children: [
        _TableHeader(
          cells: [
            const _HeaderCell('排名', flex: 1),
            const _HeaderCell('球员', flex: 4, align: TextAlign.left),
            const _HeaderCell('球队', flex: 3, align: TextAlign.left),
            const _HeaderCell('场次', flex: 1),
            _HeaderCell(_category.label, flex: 2),
          ],
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: 12.h),
            itemCount: _rows.length,
            itemBuilder: (context, index) {
              final row = _rows[index];
              return _TableRow(
                zebra: index.isOdd,
                onTap: row.playerId == null || row.playerId!.isEmpty
                    ? null
                    : () => showPlayerDialog(context, playerId: row.playerId!),
                onSecondaryTap: row.teamId == null || row.teamId!.isEmpty
                    ? null
                    : () => showTeamDialog(context, teamId: row.teamId!),
                cells: [
                  _DataCell('${row.rank}', flex: 1),
                  _DataCell(
                    row.name,
                    flex: 4,
                    align: TextAlign.left,
                    leading: _Logo(url: row.avatar, round: true),
                    emphasize: true,
                  ),
                  _DataCell(
                    row.team,
                    flex: 3,
                    align: TextAlign.left,
                    leading: _Logo(url: row.teamLogo),
                    onTap: row.teamId == null || row.teamId!.isEmpty
                        ? null
                        : () => showTeamDialog(context, teamId: row.teamId!),
                  ),
                  _DataCell(row.games, flex: 1),
                  _DataCell(row.value, flex: 2, bold: true),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SegmentedChips extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _SegmentedChips({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 36.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return ChoiceChip(
            label: Text(labels[index]),
            selected: selected,
            onSelected: (_) => onSelected(index),
            labelStyle: theme.textTheme.bodyMedium?.copyWith(
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            selectedColor: theme.colorScheme.primary,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            side: BorderSide.none,
            showCheckmark: false,
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}

class _HeaderCell {
  final String text;
  final int flex;
  final TextAlign align;

  const _HeaderCell(this.text, {this.flex = 1, this.align = TextAlign.center});
}

class _TableHeader extends StatelessWidget {
  final List<_HeaderCell> cells;

  const _TableHeader({required this.cells});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
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
          for (final cell in cells)
            Expanded(
              flex: cell.flex,
              child: Text(
                cell.text,
                textAlign: cell.align,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final int flex;
  final TextAlign align;
  final bool bold;
  final bool emphasize;
  final Widget? leading;
  final VoidCallback? onTap;

  const _DataCell(
    this.text, {
    this.flex = 1,
    this.align = TextAlign.center,
    this.bold = false,
    this.emphasize = false,
    this.leading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 15.sp,
      fontWeight: (bold || emphasize) ? FontWeight.w700 : FontWeight.w500,
      color: emphasize ? theme.colorScheme.primary : null,
    );

    Widget child = leading == null
        ? Text(text, textAlign: align, overflow: TextOverflow.ellipsis, style: style)
        : Row(
            children: [
              leading!,
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ],
          );

    if (onTap != null) {
      child = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      );
    }

    return Expanded(flex: flex, child: child);
  }
}

class _TableRow extends StatelessWidget {
  final bool zebra;
  final List<_DataCell> cells;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;

  const _TableRow({
    required this.zebra,
    required this.cells,
    this.onTap,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: zebra
          ? (isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.02))
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onSecondaryTap: onSecondaryTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Row(children: cells),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final String? url;
  final bool round;
  final double? size;

  const _Logo({required this.url, this.round = false, this.size});

  @override
  Widget build(BuildContext context) {
    final dim = (size ?? (round ? 22 : 18)).w;
    final fallback = Icon(
      round ? Icons.person : Icons.sports_basketball,
      size: 16.sp,
    );

    if (url == null || url!.isEmpty) return fallback;

    final image = AppCachedImage(
      url: url!,
      width: dim,
      height: dim,
      fit: BoxFit.cover,
      errorWidget: fallback,
    );

    if (!round) return image;
    return ClipOval(child: image);
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('加载失败', style: theme.textTheme.titleSmall),
            SizedBox(height: 8.h),
            Text(message, style: theme.textTheme.bodyMedium),
            SizedBox(height: 16.h),
            TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

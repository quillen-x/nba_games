import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nba_games/models/nba_game_model.dart';
import 'package:nba_games/request/tencent_nba_api.dart';

void showTeamDialog(BuildContext context, {required String teamId}) {
  if (teamId.isEmpty) return;
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _TeamDialog(teamId: teamId),
  );
}

void showPlayerDialog(BuildContext context, {required String playerId}) {
  if (playerId.isEmpty) return;
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _PlayerDialog(playerId: playerId),
  );
}

class _TeamDialog extends StatefulWidget {
  final String teamId;
  const _TeamDialog({required this.teamId});

  @override
  State<_TeamDialog> createState() => _TeamDialogState();
}

class _TeamDialogState extends State<_TeamDialog> {
  bool _loading = true;
  String? _error;
  NbaTeamProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await TencentNbaApi.getTeamProfile(widget.teamId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 800;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: SizedBox(
        width: wide ? 720.0 : size.width * 0.96,
        height: size.height * (wide ? 0.9 : 0.92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DialogTitle(
              title: '球队资料',
              onClose: () => Navigator.of(context).pop(),
            ),
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            Expanded(child: _buildBody(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null || _profile == null) {
      return _ErrorBody(message: _error ?? '', onRetry: _load);
    }

    final p = _profile!;
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      children: [
        Row(
          children: [
            _NetImage(url: p.logo, size: 56, fallback: Icons.sports_basketball),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (p.enName != null && p.enName!.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(p.enName!, style: theme.textTheme.bodyMedium),
                  ],
                  SizedBox(height: 4.h),
                  Text(
                    [
                      if (p.rankText != null) p.rankText!,
                      if (p.record != null) p.record!,
                    ].join(' · '),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 12.w,
          runSpacing: 6.h,
          children: [
            if (p.coach != null && p.coach!.isNotEmpty)
              Text('主教练：${p.coach}', style: theme.textTheme.bodyMedium),
            if (p.venue != null && p.venue!.isNotEmpty)
              Text('主场：${p.venue}', style: theme.textTheme.bodyMedium),
            if (p.city != null && p.city!.isNotEmpty)
              Text('城市：${p.city}', style: theme.textTheme.bodyMedium),
          ],
        ),
        if (p.brief != null && p.brief!.isNotEmpty) ...[
          SizedBox(height: 10.h),
          Text(p.brief!, style: theme.textTheme.bodyMedium),
        ],
        if (p.compares.isNotEmpty) ...[
          SizedBox(height: 16.h),
          Text('赛季数据', style: theme.textTheme.titleSmall),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final c in p.compares)
                _StatChip(label: c.type, value: c.value, serial: c.serial),
            ],
          ),
        ],
        if (p.roster.isNotEmpty) ...[
          SizedBox(height: 16.h),
          Text('阵容', style: theme.textTheme.titleSmall),
          SizedBox(height: 8.h),
          for (final player in p.roster)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: _NetImage(
                url: player.logo,
                size: 36,
                round: true,
                fallback: Icons.person,
              ),
              title: Text(
                [
                  if (player.jerseyNum != null && player.jerseyNum!.isNotEmpty)
                    '#${player.jerseyNum}',
                  player.name,
                ].join(' '),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                player.position ?? '',
                style: theme.textTheme.bodyMedium,
              ),
              trailing: Icon(Icons.chevron_right, size: 18.sp),
              onTap: () {
                Navigator.of(context).pop();
                showPlayerDialog(context, playerId: player.playerId);
              },
            ),
        ],
      ],
    );
  }
}

class _PlayerDialog extends StatefulWidget {
  final String playerId;
  const _PlayerDialog({required this.playerId});

  @override
  State<_PlayerDialog> createState() => _PlayerDialogState();
}

class _PlayerDialogState extends State<_PlayerDialog> {
  bool _loading = true;
  String? _error;
  NbaPlayerProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await TencentNbaApi.getPlayerProfile(widget.playerId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 800;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: SizedBox(
        width: wide ? 760.0 : size.width * 0.96,
        height: size.height * (wide ? 0.9 : 0.92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DialogTitle(
              title: '球员资料',
              onClose: () => Navigator.of(context).pop(),
            ),
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            Expanded(child: _buildBody(theme, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null || _profile == null) {
      return _ErrorBody(message: _error ?? '', onRetry: _load);
    }

    final p = _profile!;
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      children: [
        Row(
          children: [
            _NetImage(
              url: p.logo,
              size: 64,
              round: true,
              fallback: Icons.person,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      if (p.jerseyNum != null && p.jerseyNum!.isNotEmpty)
                        '#${p.jerseyNum}',
                      p.name,
                    ].join(' '),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (p.enName != null && p.enName!.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(p.enName!, style: theme.textTheme.bodyMedium),
                  ],
                  SizedBox(height: 4.h),
                  InkWell(
                    onTap: p.teamId == null || p.teamId!.isEmpty
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            showTeamDialog(context, teamId: p.teamId!);
                          },
                    child: Row(
                      children: [
                        _NetImage(
                          url: p.teamLogo,
                          size: 18,
                          fallback: Icons.sports_basketball,
                        ),
                        SizedBox(width: 4.w),
                        Flexible(
                          child: Text(
                            [
                              p.teamName ?? '',
                              if (p.position != null) p.position!,
                            ].where((e) => e.isNotEmpty).join(' · '),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 12.w,
          runSpacing: 6.h,
          children: [
            if (p.height != null && p.height!.isNotEmpty)
              Text('身高 ${p.height}', style: theme.textTheme.bodyMedium),
            if (p.weight != null && p.weight!.isNotEmpty)
              Text('体重 ${p.weight}', style: theme.textTheme.bodyMedium),
            if (p.birthDate != null && p.birthDate!.isNotEmpty)
              Text('生日 ${p.birthDate}', style: theme.textTheme.bodyMedium),
          ],
        ),
        if (p.compares.isNotEmpty) ...[
          SizedBox(height: 16.h),
          Text('本赛季对比', style: theme.textTheme.titleSmall),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final c in p.compares)
                _StatChip(label: c.type, value: c.value, serial: c.serial),
            ],
          ),
        ],
        if (p.seasonAvgRows.isNotEmpty) ...[
          SizedBox(height: 16.h),
          Text('赛季场均', style: theme.textTheme.titleSmall),
          SizedBox(height: 8.h),
          _SeasonAvgTable(
            headers: p.seasonHeaders,
            rows: p.seasonAvgRows,
          ),
        ],
      ],
    );
  }
}

/// 球员赛季场均表：紧凑横向滚动，突出得分等关键列
class _SeasonAvgTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;

  const _SeasonAvgTable({
    required this.headers,
    required this.rows,
  });

  /// 展示列优先级（空表头已在 API 侧归一为「阶段」）
  static const _preferred = [
    '赛季',
    '阶段',
    '球队',
    '得分',
    '篮板',
    '助攻',
    '抢断',
    '盖帽',
    '分钟',
    '命中%',
    '三分%',
    '罚球%',
    '犯规',
  ];

  static const _highlight = {'得分', '篮板', '助攻'};

  List<int> _visibleIndexes() {
    final byName = <String, int>{};
    for (var i = 0; i < headers.length; i++) {
      final h = headers[i].trim();
      if (h.isEmpty) continue;
      byName[h] = i;
    }
    final indexes = <int>[];
    for (final name in _preferred) {
      final i = byName[name];
      if (i != null) indexes.add(i);
    }
    // 若 preferred 全未命中，回退为全部非空列
    if (indexes.isEmpty) {
      for (var i = 0; i < headers.length; i++) {
        if (headers[i].trim().isNotEmpty) indexes.add(i);
      }
    }
    return indexes;
  }

  int _colFlex(String header) {
    switch (header) {
      case '赛季':
        return 3;
      case '阶段':
        return 4;
      case '球队':
        return 3;
      case '命中%':
      case '三分%':
      case '罚球%':
        return 3;
      default:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final indexes = _visibleIndexes();
    if (indexes.isEmpty) return const SizedBox.shrink();

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final headBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);
    final zebraBg = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.black.withValues(alpha: 0.02);

    Widget rowCells({
      required Color? bg,
      required List<Widget> cells,
    }) {
      return ColoredBox(
        color: bg ?? Colors.transparent,
        child: Row(children: cells),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: borderColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              rowCells(
                bg: headBg,
                cells: [
                  for (final i in indexes)
                    Expanded(
                      flex: _colFlex(headers[i]),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4.w,
                          vertical: 10.h,
                        ),
                        child: Text(
                          headers[i],
                          textAlign:
                              i <= 2 ? TextAlign.left : TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              for (var r = 0; r < rows.length; r++)
                rowCells(
                  bg: r.isOdd ? zebraBg : null,
                  cells: [
                    for (final i in indexes)
                      Expanded(
                        flex: _colFlex(headers[i]),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 9.h,
                          ),
                          child: _cell(
                            theme,
                            header: headers[i],
                            value: i < rows[r].length ? rows[r][i] : '-',
                            alignLeft: i <= 2,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(
    ThemeData theme, {
    required String header,
    required String value,
    required bool alignLeft,
  }) {
    final isPhase = header == '阶段';
    final isHighlight = _highlight.contains(header);
    final isPlayoff = isPhase && value.contains('季后');
    final isRegular = isPhase && value.contains('常规');

    Color? color;
    if (isPlayoff) color = const Color(0xFFE53935);
    if (isRegular) color = theme.colorScheme.primary;

    return Text(
      value.isEmpty ? '-' : value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: alignLeft ? TextAlign.left : TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontSize: 12.sp,
        fontWeight: isHighlight || isPhase ? FontWeight.w700 : FontWeight.w500,
        color: color,
      ),
    );
  }
}

class _DialogTitle extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _DialogTitle({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 0),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '关闭',
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, size: 20.sp),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
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

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final String? serial;

  const _StatChip({
    required this.label,
    required this.value,
    this.serial,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (serial != null && serial!.isNotEmpty)
            Text('联盟 $serial', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _NetImage extends StatelessWidget {
  final String? url;
  final double size;
  final bool round;
  final IconData fallback;

  const _NetImage({
    required this.url,
    required this.size,
    this.round = false,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final icon = Icon(fallback, size: size.sp * 0.7);
    if (url == null || url!.isEmpty) return icon;
    final image = Image.network(
      url!,
      width: size.w,
      height: size.w,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => icon,
    );
    return round ? ClipOval(child: image) : image;
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nba_games/models/nba_member_model.dart';
import 'package:nba_games/models/nba_news_model.dart';
import 'package:nba_games/models/third_party_news_model.dart';
import 'package:nba_games/models/x_post_model.dart';
import 'package:nba_games/request/hupu_nba_api.dart';
import 'package:nba_games/request/nba_members_store.dart';
import 'package:nba_games/request/sohu_nba_api.dart';
import 'package:nba_games/request/tencent_nba_news_api.dart';
import 'package:nba_games/request/x_feed_service.dart';
import 'package:nba_games/widgets/app_cached_image.dart';
import 'package:nba_games/widgets/feed_detail_panel.dart';
import 'package:url_launcher/url_launcher.dart';

void showFeedDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => const _FeedDialog(),
  );
}

class _FeedDialog extends StatelessWidget {
  const _FeedDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 800;
    final maxW = wide ? 640.0 : size.width * 0.94;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: SizedBox(
        width: maxW,
        height: size.height * (wide ? 0.9 : 0.92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 0),
              child: Row(
                children: [
                  Text(
                    '动态',
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
            const Expanded(child: FeedBody()),
          ],
        ),
      ),
    );
  }
}

/// 桌面弹窗与手机 / 左边栏「动态」共用
class FeedBody extends StatefulWidget {
  const FeedBody({super.key});

  @override
  State<FeedBody> createState() => _FeedBodyState();
}

class _FeedBodyState extends State<FeedBody> {
  /// 0 腾讯 / 1 搜狐 / 2 虎扑 / 3 成员动态
  int _tab = 0;
  Object? _detail;

  Future<void> _openNews(NbaNewsItem item) async {
    if (feedDetailUsesSidePanel) {
      setState(() => _detail = item);
      return;
    }
    final uri = Uri.tryParse(item.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openThirdParty(ThirdPartyNewsItem item) async {
    if (feedDetailUsesSidePanel) {
      setState(() => _detail = item);
      return;
    }
    final uri = Uri.tryParse(item.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openPost(XPost post) async {
    if (feedDetailUsesSidePanel) {
      setState(() => _detail = post);
      return;
    }
    final uri = Uri.tryParse(post.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 4.h),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final e in const [
                      (0, '腾讯'),
                      (1, '搜狐'),
                      (2, '虎扑'),
                      (3, '成员动态'),
                    ]) ...[
                      if (e.$1 > 0) SizedBox(width: 8.w),
                      ChoiceChip(
                        label: Text(e.$2),
                        selected: _tab == e.$1,
                        onSelected: (_) => setState(() {
                          _tab = e.$1;
                          _detail = null;
                        }),
                        labelStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: _tab == e.$1
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
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _HotNewsPane(onOpen: _openNews),
                  _ThirdPartyNewsPane(
                    source: ThirdPartyNewsSource.sohu,
                    onOpen: _openThirdParty,
                  ),
                  _ThirdPartyNewsPane(
                    source: ThirdPartyNewsSource.hupu,
                    onOpen: _openThirdParty,
                  ),
                  _MemberFeedPane(onOpen: _openPost),
                ],
              ),
            ),
          ],
        ),
        if (feedDetailUsesSidePanel)
          FeedDetailPanel(
            detail: _detail,
            onClose: () => setState(() => _detail = null),
          ),
      ],
    );
  }
}

class _HotNewsPane extends StatefulWidget {
  final Future<void> Function(NbaNewsItem item) onOpen;

  const _HotNewsPane({required this.onOpen});

  @override
  State<_HotNewsPane> createState() => _HotNewsPaneState();
}

class _HotNewsPaneState extends State<_HotNewsPane> {
  final _scroll = ScrollController();
  List<NbaNewsItem> _items = const [];
  String? _contextData;
  bool _hasMore = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _started = false;
  String? _error;
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || !_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 160) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    final id = ++_loadId;
    setState(() {
      _started = true;
      _loading = true;
      _error = null;
      _contextData = null;
      _hasMore = false;
    });
    try {
      final page = await TencentNbaNewsApi.getHotNews();
      if (!mounted || id != _loadId) return;
      setState(() {
        _items = page.items;
        _contextData = page.contextData;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (!mounted || id != _loadId) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted && id == _loadId) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _contextData == null) return;
    final id = _loadId;
    setState(() => _loadingMore = true);
    try {
      final page = await TencentNbaNewsApi.getHotNews(
        contextData: _contextData,
      );
      if (!mounted || id != _loadId) return;
      final seen = _items.map((e) => e.id).toSet();
      final added =
          page.items.where((e) => seen.add(e.id)).toList(growable: false);
      final merged = [..._items, ...added];
      merged.sort((a, b) {
        final at = a.publishedAt;
        final bt = b.publishedAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
      setState(() {
        _items = merged;
        _contextData = page.contextData;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      // 加载更多失败时保留已有列表
    } finally {
      if (mounted && id == _loadId) setState(() => _loadingMore = false);
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${time.month}/${time.day} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatCount(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(12.w, 4.h, 8.w, 4.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _started
                      ? '来自腾讯体育 · ${_items.length} 条'
                      : '热点资讯',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
              if (_loading)
                Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _load,
                icon: Icon(Icons.refresh_rounded, size: 20.sp),
              ),
            ],
          ),
        ),
        if (_error != null && _items.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('加载失败', style: theme.textTheme.titleSmall),
                    SizedBox(height: 8.h),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    SizedBox(height: 16.h),
                    TextButton(onPressed: _load, child: const Text('重试')),
                  ],
                ),
              ),
            ),
          )
        else if (!_started || (_loading && _items.isEmpty))
          const Expanded(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_items.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                '暂无热点资讯',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 20.h),
              itemCount: _items.length + (_loadingMore ? 1 : 0),
              separatorBuilder: (_, __) => SizedBox(height: 10.h),
              itemBuilder: (context, index) {
                if (index >= _items.length) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final item = _items[index];
                return _NewsCard(
                  item: item,
                  isDark: isDark,
                  timeLabel: item.publishedAt == null
                      ? null
                      : _formatTime(item.publishedAt!),
                  viewsLabel: item.pageView > 0
                      ? _formatCount(item.pageView)
                      : null,
                  onOpen: () => widget.onOpen(item),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NbaNewsItem item;
  final bool isDark;
  final String? timeLabel;
  final String? viewsLabel;
  final VoidCallback onOpen;

  const _NewsCard({
    required this.item,
    required this.isDark,
    required this.timeLabel,
    required this.viewsLabel,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.isHot) ...[
                          Container(
                            margin: EdgeInsets.only(top: 2.h),
                            padding: EdgeInsets.symmetric(
                              horizontal: 5.w,
                              vertical: 1.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935),
                              borderRadius: BorderRadius.circular(3.r),
                            ),
                            child: Text(
                              '热',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: 6.w),
                        ],
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                              fontSize: 16.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (item.summary.isNotEmpty) ...[
                      SizedBox(height: 6.h),
                      Text(
                        item.summary,
                        maxLines: 10,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.55,
                          fontSize: 14.sp,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        if (item.isVideo) ...[
                          Icon(
                            Icons.play_circle_outline,
                            size: 14.sp,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.45),
                          ),
                          SizedBox(width: 4.w),
                        ],
                        if (timeLabel != null)
                          Text(
                            timeLabel!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 11.sp,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        if (viewsLabel != null) ...[
                          SizedBox(width: 10.w),
                          Text(
                            '阅读 $viewsLabel',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 11.sp,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (item.pic.isNotEmpty) ...[
                SizedBox(width: 10.w),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: AppCachedImage(
                    url: item.pic,
                    width: 240.w,
                    height: 170.h,
                    fit: BoxFit.cover,
                    errorWidget: ColoredBox(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.06),
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 20.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ThirdPartyNewsPane extends StatefulWidget {
  final ThirdPartyNewsSource source;
  final Future<void> Function(ThirdPartyNewsItem item) onOpen;

  const _ThirdPartyNewsPane({
    required this.source,
    required this.onOpen,
  });

  @override
  State<_ThirdPartyNewsPane> createState() => _ThirdPartyNewsPaneState();
}

class _ThirdPartyNewsPaneState extends State<_ThirdPartyNewsPane> {
  final _scroll = ScrollController();
  List<ThirdPartyNewsItem> _items = const [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _started = false;
  bool _hasMore = false;
  String? _cursor;
  String? _error;
  int _loadId = 0;
  int _sohuPage = 1;

  String get _sourceName => switch (widget.source) {
        ThirdPartyNewsSource.sohu => '搜狐体育',
        ThirdPartyNewsSource.hupu => '虎扑NBA',
      };

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || !_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 160) {
      _loadMore();
    }
  }

  Future<ThirdPartyNewsPage> _fetch({String? cursor, int sohuPage = 1}) {
    return switch (widget.source) {
      ThirdPartyNewsSource.sohu => SohuNbaApi.getNews(page: sohuPage),
      ThirdPartyNewsSource.hupu => HupuNbaApi.getNews(cursorNid: cursor),
    };
  }

  Future<void> _load() async {
    if (_loading) return;
    final id = ++_loadId;
    setState(() {
      _started = true;
      _loading = true;
      _error = null;
      _cursor = null;
      _sohuPage = 1;
      _hasMore = false;
    });
    try {
      final page = await _fetch(sohuPage: 1);
      if (!mounted || id != _loadId) return;
      setState(() {
        _items = page.items;
        _hasMore = page.hasMore;
        _cursor = page.nextCursor;
        _sohuPage = 1;
      });
    } catch (e) {
      if (!mounted || id != _loadId) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted && id == _loadId) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final id = _loadId;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _sohuPage + 1;
      final page = await _fetch(
        cursor: _cursor,
        sohuPage: nextPage,
      );
      if (!mounted || id != _loadId) return;
      final seen = _items.map((e) => e.id).toSet();
      final added =
          page.items.where((e) => seen.add(e.id)).toList(growable: false);
      setState(() {
        _items = [..._items, ...added];
        _hasMore = page.hasMore && added.isNotEmpty;
        _cursor = page.nextCursor;
        _sohuPage = nextPage;
      });
    } catch (_) {
      // keep list
    } finally {
      if (mounted && id == _loadId) setState(() => _loadingMore = false);
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${time.month}/${time.day} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(12.w, 4.h, 8.w, 4.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _started
                      ? '来自$_sourceName · ${_items.length} 条'
                      : _sourceName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
              if (_loading)
                Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _load,
                icon: Icon(Icons.refresh_rounded, size: 20.sp),
              ),
            ],
          ),
        ),
        if (_error != null && _items.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('加载失败', style: theme.textTheme.titleSmall),
                    SizedBox(height: 8.h),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    SizedBox(height: 16.h),
                    TextButton(onPressed: _load, child: const Text('重试')),
                  ],
                ),
              ),
            ),
          )
        else if (!_started || (_loading && _items.isEmpty))
          const Expanded(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_items.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                '暂无资讯',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 20.h),
              itemCount: _items.length + (_loadingMore ? 1 : 0),
              separatorBuilder: (_, __) => SizedBox(height: 10.h),
              itemBuilder: (context, index) {
                if (index >= _items.length) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final item = _items[index];
                return _ThirdPartyNewsCard(
                  item: item,
                  isDark: isDark,
                  timeLabel: item.publishedAt == null
                      ? null
                      : _formatTime(item.publishedAt!),
                  onOpen: () => widget.onOpen(item),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ThirdPartyNewsCard extends StatelessWidget {
  final ThirdPartyNewsItem item;
  final bool isDark;
  final String? timeLabel;
  final VoidCallback onOpen;

  const _ThirdPartyNewsCard({
    required this.item,
    required this.isDark,
    required this.timeLabel,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        fontSize: 16.sp,
                      ),
                    ),
                    if (item.summary.isNotEmpty && item.summary != '。') ...[
                      SizedBox(height: 6.h),
                      Text(
                        item.summary,
                        maxLines: 10,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.55,
                          fontSize: 14.sp,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Text(
                          item.sourceLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 11.sp,
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (timeLabel != null) ...[
                          SizedBox(width: 10.w),
                          Text(
                            timeLabel!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 11.sp,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                        if (item.replyNum > 0) ...[
                          SizedBox(width: 10.w),
                          Text(
                            '回复 ${item.replyNum}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 11.sp,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (item.pic.isNotEmpty) ...[
                SizedBox(width: 10.w),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: AppCachedImage(
                    url: item.pic,
                    width: 240.w,
                    height: 170.h,
                    fit: BoxFit.cover,
                    errorWidget: ColoredBox(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.06),
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 20.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberFeedPane extends StatefulWidget {
  final Future<void> Function(XPost post) onOpen;

  const _MemberFeedPane({required this.onOpen});

  @override
  State<_MemberFeedPane> createState() => _MemberFeedPaneState();
}

class _MemberFeedPaneState extends State<_MemberFeedPane> {
  final _service = XFeedService();
  final _scroll = ScrollController();

  List<XPost> _posts = const [];
  bool _loading = false;
  bool _started = false;
  String? _error;
  int _done = 0;
  int _total = 0;
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    final id = ++_loadId;
    setState(() {
      _started = true;
      _loading = true;
      _error = null;
      _done = 0;
      _total = 0;
    });

    try {
      final bundle = await NbaMembersStore.load();
      if (!mounted || id != _loadId) return;

      final profiles = <String, NbaMember>{
        for (final m in bundle.members) m.username.toLowerCase(): m,
      };
      var names = bundle.members
          .where((m) => m.special)
          .map((m) => m.username)
          .where((u) => u.isNotEmpty)
          .toList();
      if (names.isEmpty) {
        names = bundle.members
            .map((m) => m.username)
            .where((u) => u.isNotEmpty)
            .toList();
      }

      setState(() => _total = names.length);

      if (names.isEmpty) {
        setState(() {
          _posts = const [];
          _error = '暂无篮球成员数据';
        });
        return;
      }

      final posts = await _service.fetchRecentFeed(
        names,
        hours: 24,
        perUser: 5,
        minLikes: 0,
        onProgress: (items, done, total) {
          if (!mounted || id != _loadId) return;
          setState(() {
            _posts = _withAvatars(items, profiles);
            _done = done;
            _total = total;
          });
        },
      );
      if (!mounted || id != _loadId) return;
      setState(() {
        _posts = _withAvatars(posts, profiles);
        _done = names.length;
        _total = names.length;
      });
    } catch (e) {
      if (!mounted || id != _loadId) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted && id == _loadId) setState(() => _loading = false);
    }
  }

  List<XPost> _withAvatars(
    List<XPost> posts,
    Map<String, NbaMember> profiles,
  ) {
    return posts.map((post) {
      if (post.avatarUrl.isNotEmpty && post.authorName.isNotEmpty) {
        return post;
      }
      final account = profiles[post.username.toLowerCase()];
      if (account == null) return post;
      return post.copyWith(
        avatarUrl:
            post.avatarUrl.isNotEmpty ? post.avatarUrl : account.avatarUrl,
        authorName:
            post.authorName.isNotEmpty ? post.authorName : account.name,
      );
    }).toList();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${time.month}/${time.day} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(12.w, 4.h, 8.w, 4.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _loading && _total > 0
                      ? '拉取中 $_done / $_total · 已 ${_posts.length} 条'
                      : _started
                          ? '近 24 小时 · ${_posts.length} 条'
                          : '成员动态',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
              if (_loading)
                Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _load,
                icon: Icon(Icons.refresh_rounded, size: 20.sp),
              ),
            ],
          ),
        ),
        if (_error != null && _posts.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('加载失败', style: theme.textTheme.titleSmall),
                    SizedBox(height: 8.h),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    SizedBox(height: 16.h),
                    TextButton(onPressed: _load, child: const Text('重试')),
                  ],
                ),
              ),
            ),
          )
        else if (!_started || (_loading && _posts.isEmpty))
          const Expanded(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_posts.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                '近 24 小时暂无动态',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 20.h),
              itemCount: _posts.length,
              separatorBuilder: (_, __) => SizedBox(height: 10.h),
              itemBuilder: (context, index) {
                final post = _posts[index];
                return _PostCard(
                  post: post,
                  isDark: isDark,
                  timeLabel: post.publishedAt == null
                      ? null
                      : _formatTime(post.publishedAt!),
                  likesLabel:
                      post.likes > 0 ? _formatCount(post.likes) : null,
                  onOpen: () => widget.onOpen(post),
                  onOpenAuthor: () =>
                      _openUrl('https://x.com/${post.username}'),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  final XPost post;
  final bool isDark;
  final String? timeLabel;
  final String? likesLabel;
  final VoidCallback onOpen;
  final VoidCallback onOpenAuthor;

  const _PostCard({
    required this.post,
    required this.isDark,
    required this.timeLabel,
    required this.likesLabel,
    required this.onOpen,
    required this.onOpenAuthor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);

    final covers = post.media
        .where((m) => m.kind == XMediaKind.photo || m.isVideo)
        .toList(growable: false);
    final cover = covers.isEmpty ? null : covers.first;
    final hasVideo = cover?.isVideo == true;
    final imgW = 240.w;
    final imgH = 170.h;

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onOpenAuthor,
                      child: Text(
                        post.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          fontSize: 16.sp,
                        ),
                      ),
                    ),
                    if (post.text.isNotEmpty || post.displayText.isNotEmpty) ...[
                      SizedBox(height: 6.h),
                      _HoverTranslateBody(
                        original: post.text.isNotEmpty
                            ? post.text
                            : post.displayText,
                        translation: post.hasTranslation
                            ? post.translation
                            : null,
                      ),
                    ],
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        if (hasVideo) ...[
                          Icon(
                            Icons.play_circle_outline,
                            size: 14.sp,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.45),
                          ),
                          SizedBox(width: 4.w),
                        ],
                        if (timeLabel != null)
                          Text(
                            timeLabel!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 11.sp,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        if (likesLabel != null) ...[
                          SizedBox(width: 10.w),
                          Icon(
                            Icons.favorite_border_rounded,
                            size: 12.sp,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.45),
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            likesLabel!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 11.sp,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (cover != null) ...[
                SizedBox(width: 10.w),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: SizedBox(
                    width: imgW,
                    height: imgH,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _ProxiedNetworkImage(
                          url: cover.listUrl,
                          fit: BoxFit.cover,
                        ),
                        if (hasVideo)
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Container(
                              margin: EdgeInsets.all(6.w),
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    size: 14.sp,
                                    color: Colors.white,
                                  ),
                                  if (cover.durationLabel.isNotEmpty) ...[
                                    SizedBox(width: 2.w),
                                    Text(
                                      cover.durationLabel,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 默认原文；悬停切换为中文翻译
class _HoverTranslateBody extends StatefulWidget {
  final String original;
  final String? translation;

  const _HoverTranslateBody({
    required this.original,
    required this.translation,
  });

  @override
  State<_HoverTranslateBody> createState() => _HoverTranslateBodyState();
}

class _HoverTranslateBodyState extends State<_HoverTranslateBody> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasZh = (widget.translation ?? '').trim().isNotEmpty;
    final showingZh = _hover && hasZh;
    final text = showingZh ? widget.translation!.trim() : widget.original;

    return MouseRegion(
      onEnter: hasZh ? (_) => setState(() => _hover = true) : null,
      onExit: hasZh ? (_) => setState(() => _hover = false) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            maxLines: 10,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.55,
              fontSize: 14.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          if (hasZh) ...[
            SizedBox(height: 4.h),
            Text(
              showingZh ? '原文（移出恢复）' : '悬停查看翻译',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 11.sp,
                color: theme.colorScheme.primary.withValues(alpha: 0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// X/Twitter 媒体需代理，不能用默认 Image.network
class _ProxiedNetworkImage extends StatefulWidget {
  final String url;
  final BoxFit fit;

  const _ProxiedNetworkImage({
    required this.url,
    this.fit = BoxFit.cover,
  });

  @override
  State<_ProxiedNetworkImage> createState() => _ProxiedNetworkImageState();
}

class _ProxiedNetworkImageState extends State<_ProxiedNetworkImage> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = XFeedService.fetchBytes(widget.url);
  }

  @override
  void didUpdateWidget(covariant _ProxiedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _future = XFeedService.fetchBytes(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return ColoredBox(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final bytes = snap.data;
        if (snap.hasError || bytes == null || bytes.isEmpty) {
          return ColoredBox(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            child: Icon(
              Icons.image_not_supported_outlined,
              size: 20.sp,
            ),
          );
        }
        return Image.memory(
          bytes,
          fit: widget.fit,
          gaplessPlayback: true,
        );
      },
    );
  }
}

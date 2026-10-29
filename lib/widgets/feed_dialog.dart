import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nba_games/models/nba_member_model.dart';
import 'package:nba_games/models/nba_news_model.dart';
import 'package:nba_games/models/x_post_model.dart';
import 'package:nba_games/request/nba_members_store.dart';
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
  /// 0 腾讯 / 1 成员动态
  static const _feedTabs = <String>['腾讯', '成员动态'];
  int _tab = 0;
  Object? _detail;
  final _newsKey = GlobalKey<_HotNewsPaneState>();
  final _memberKey = GlobalKey<_MemberFeedPaneState>();
  final _busy = <bool>[false, false];

  bool get _refreshBusy => _busy[_tab];

  Future<void> _openNews(NbaNewsItem item) async {
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

  void _setBusy(int index, bool busy) {
    if (_busy[index] == busy) return;
    setState(() => _busy[index] = busy);
  }

  void _onRefresh() {
    if (_tab == 0) {
      _newsKey.currentState?.reload();
    } else {
      _memberKey.currentState?.reload();
    }
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
              padding: EdgeInsets.fromLTRB(12.w, 10.h, 4.w, 4.h),
              child: Row(
                children: [
                  for (var i = 0; i < _feedTabs.length; i++) ...[
                    if (i > 0) SizedBox(width: 8.w),
                    ChoiceChip(
                      label: Text(_feedTabs[i]),
                      selected: _tab == i,
                      onSelected: (_) => setState(() {
                        _tab = i;
                        _detail = null;
                      }),
                      labelStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: _tab == i
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
                  const Spacer(),
                  if (_refreshBusy)
                    Padding(
                      padding: EdgeInsets.only(right: 4.w),
                      child: SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton(
                    tooltip: '刷新',
                    onPressed: _refreshBusy ? null : _onRefresh,
                    icon: Icon(Icons.refresh_rounded, size: 20.sp),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _HotNewsPane(
                    key: _newsKey,
                    onOpen: _openNews,
                    onBusyChanged: (b) => _setBusy(0, b),
                  ),
                  _MemberFeedPane(
                    key: _memberKey,
                    onOpen: _openPost,
                    onBusyChanged: (b) => _setBusy(1, b),
                  ),
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
  final ValueChanged<bool>? onBusyChanged;

  const _HotNewsPane({
    super.key,
    required this.onOpen,
    this.onBusyChanged,
  });

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

  void reload() => _load();

  void _setBusy(bool busy) {
    if (_loading == busy) return;
    _loading = busy;
    widget.onBusyChanged?.call(busy);
  }

  Future<void> _load() async {
    if (_loading) return;
    final id = ++_loadId;
    setState(() {
      _started = true;
      _error = null;
      _contextData = null;
      _hasMore = false;
    });
    _setBusy(true);
    setState(() {});
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
      if (mounted && id == _loadId) {
        _setBusy(false);
        setState(() {});
      }
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

    if (_error != null && _items.isEmpty) {
      return Center(
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
      );
    }
    if (!_started || (_loading && _items.isEmpty)) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          '暂无热点资讯',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      );
    }

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 8.h),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10.h,
              crossAxisSpacing: 10.w,
              childAspectRatio: 4,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
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
              childCount: _items.length,
            ),
          ),
        ),
        if (_loadingMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          )
        else
          SliverToBoxAdapter(child: SizedBox(height: 12.h)),
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
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    final hasPic = item.pic.isNotEmpty;

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(12.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: EdgeInsets.all(10.w),
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
                                height: 1.3,
                                fontSize: 13.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.summary.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Expanded(
                          child: Text(
                            item.summary,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.35,
                              fontSize: 11.sp,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      Row(
                        children: [
                          if (item.isVideo) ...[
                            Icon(
                              Icons.play_circle_outline,
                              size: 12.sp,
                              color: muted,
                            ),
                            SizedBox(width: 3.w),
                          ],
                          if (timeLabel != null)
                            Flexible(
                              child: Text(
                                timeLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 10.sp,
                                  color: muted,
                                ),
                              ),
                            ),
                          if (viewsLabel != null) ...[
                            if (timeLabel != null) SizedBox(width: 6.w),
                            Text(
                              '$viewsLabel 阅读',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 10.sp,
                                color: muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                SizedBox(
                  width: 140.w,
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (hasPic)
                            AppCachedImage(
                              url: item.pic,
                              fit: BoxFit.cover,
                              errorWidget: ColoredBox(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.06),
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 18.sp,
                                  color: muted,
                                ),
                              ),
                            )
                          else
                            ColoredBox(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.05),
                              child: Icon(
                                Icons.article_outlined,
                                size: 22.sp,
                                color: muted,
                              ),
                            ),
                          if (item.isVideo)
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                padding: EdgeInsets.all(3.w),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  size: 14.sp,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberFeedPane extends StatefulWidget {
  final Future<void> Function(XPost post) onOpen;
  final ValueChanged<bool>? onBusyChanged;

  const _MemberFeedPane({
    super.key,
    required this.onOpen,
    this.onBusyChanged,
  });

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

  void reload() => _load();

  void _setBusy(bool busy) {
    if (_loading == busy) return;
    _loading = busy;
    widget.onBusyChanged?.call(busy);
  }

  Future<void> _load() async {
    if (_loading) return;
    final id = ++_loadId;
    setState(() {
      _started = true;
      _error = null;
    });
    _setBusy(true);
    setState(() {});

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
          setState(() => _posts = _withAvatars(items, profiles));
        },
      );
      if (!mounted || id != _loadId) return;
      setState(() => _posts = _withAvatars(posts, profiles));
    } catch (e) {
      if (!mounted || id != _loadId) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted && id == _loadId) {
        _setBusy(false);
        setState(() {});
      }
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

    if (_error != null && _posts.isEmpty) {
      return Center(
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
      );
    }
    if (!_started || (_loading && _posts.isEmpty)) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_posts.isEmpty) {
      return Center(
        child: Text(
          '近 24 小时暂无动态',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      );
    }

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 8.h),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10.h,
              crossAxisSpacing: 10.w,
              childAspectRatio: 4,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
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
              childCount: _posts.length,
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 12.h)),
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
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.45);

    final covers = post.media
        .where((m) => m.kind == XMediaKind.photo || m.isVideo)
        .toList(growable: false);
    final cover = covers.isEmpty ? null : covers.first;
    final hasVideo = cover?.isVideo == true;
    final body = post.text.isNotEmpty ? post.text : post.displayText;

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(12.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: EdgeInsets.all(10.w),
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
                            height: 1.3,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                      if (body.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Expanded(
                          child: _HoverTranslateBody(
                            original: body,
                            translation: post.hasTranslation
                                ? post.translation
                                : null,
                            compact: true,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      Row(
                        children: [
                          if (hasVideo) ...[
                            Icon(
                              Icons.play_circle_outline,
                              size: 12.sp,
                              color: muted,
                            ),
                            SizedBox(width: 3.w),
                          ],
                          if (timeLabel != null)
                            Flexible(
                              child: Text(
                                timeLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 10.sp,
                                  color: muted,
                                ),
                              ),
                            ),
                          if (likesLabel != null) ...[
                            if (timeLabel != null) SizedBox(width: 6.w),
                            Icon(
                              Icons.favorite_border_rounded,
                              size: 11.sp,
                              color: muted,
                            ),
                            SizedBox(width: 2.w),
                            Text(
                              likesLabel!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 10.sp,
                                color: muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                SizedBox(
                  width: 140.w,
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (cover != null)
                            _ProxiedNetworkImage(
                              url: cover.listUrl,
                              fit: BoxFit.cover,
                            )
                          else if (post.avatarUrl.isNotEmpty)
                            _ProxiedNetworkImage(
                              url: post.avatarUrl,
                              fit: BoxFit.cover,
                            )
                          else
                            ColoredBox(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.05),
                              child: Icon(
                                Icons.person_outline,
                                size: 22.sp,
                                color: muted,
                              ),
                            ),
                          if (hasVideo)
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                padding: EdgeInsets.all(3.w),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  size: 14.sp,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
  final bool compact;

  const _HoverTranslateBody({
    required this.original,
    required this.translation,
    this.compact = false,
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
    final compact = widget.compact;

    return MouseRegion(
      onEnter: hasZh ? (_) => setState(() => _hover = true) : null,
      onExit: hasZh ? (_) => setState(() => _hover = false) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: compact ? 3 : 10,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: compact ? 1.35 : 1.55,
                fontSize: compact ? 11.sp : 14.sp,
                color: theme.colorScheme.onSurface
                    .withValues(alpha: compact ? 0.6 : 0.65),
              ),
            ),
          ),
          if (hasZh && !compact) ...[
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

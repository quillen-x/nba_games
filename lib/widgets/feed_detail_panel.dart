import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nba_games/models/nba_news_model.dart';
import 'package:nba_games/models/third_party_news_model.dart';
import 'package:nba_games/models/x_post_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nba_games/request/hupu_nba_api.dart';
import 'package:nba_games/request/sohu_nba_api.dart';
import 'package:nba_games/request/tencent_nba_news_api.dart';
import 'package:nba_games/request/x_feed_service.dart';
import 'package:nba_games/widgets/app_cached_image.dart';
import 'package:url_launcher/url_launcher.dart';

bool get feedDetailUsesSidePanel {
  if (kIsWeb) return false;
  return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}

/// 桌面端右侧滑出的动态详情
class FeedDetailPanel extends StatelessWidget {
  final Object? detail;
  final VoidCallback onClose;

  const FeedDetailPanel({
    super.key,
    required this.detail,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final panelW = (size.width * 0.46).clamp(380.0, 560.0);
    final open = detail != null;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !open,
            child: AnimatedOpacity(
              opacity: open ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: GestureDetector(
                onTap: onClose,
                behavior: HitTestBehavior.opaque,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.28),
                ),
              ),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          top: 0,
          bottom: 0,
          right: open ? 0 : -panelW - 24,
          width: panelW,
          child: Material(
            elevation: 12,
            color: theme.colorScheme.surface,
            shadowColor: Colors.black.withValues(alpha: 0.35),
            child: switch (detail) {
              final NbaNewsItem news => _NewsDetailBody(item: news),
              final ThirdPartyNewsItem news =>
                _ThirdPartyNewsDetailBody(item: news),
              final XPost post => _PostDetailBody(post: post),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
      ],
    );
  }
}

class _NewsDetailBody extends StatefulWidget {
  final NbaNewsItem item;
  const _NewsDetailBody({required this.item});

  @override
  State<_NewsDetailBody> createState() => _NewsDetailBodyState();
}

class _NewsDetailBodyState extends State<_NewsDetailBody> {
  NbaTopicDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _NewsDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _detail = null;
    });
    try {
      final detail = await TencentNbaNewsApi.getTopicDetail(widget.item.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
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

  String _formatTime(DateTime time) {
    return '${time.year}/'
        '${time.month.toString().padLeft(2, '0')}/'
        '${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openBrowser(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final detail = _detail;
    if (detail == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.title, textAlign: TextAlign.center),
              SizedBox(height: 12.h),
              Text(
                _error ?? '加载失败',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              SizedBox(height: 16.h),
              TextButton(onPressed: _load, child: const Text('重试')),
              TextButton(
                onPressed: () => _openBrowser(item.url),
                child: const Text('浏览器打开'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 28.h),
      children: [
        SelectableText(
          detail.title.isNotEmpty ? detail.title : item.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.35,
            fontSize: 18.sp,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            CircleAvatar(
              radius: 16.r,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.12),
              backgroundImage: detail.authorAvatar.isNotEmpty
                  ? CachedNetworkImageProvider(detail.authorAvatar)
                  : null,
              child: detail.authorAvatar.isEmpty
                  ? Icon(Icons.person, size: 16.sp)
                  : null,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail.authorName.isNotEmpty
                        ? detail.authorName
                        : '腾讯体育',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (detail.publishedAt != null)
                    Text(
                      _formatTime(detail.publishedAt!),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 11.sp,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.45),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 12.w,
          children: [
            if (detail.replyNum > 0)
              Text(
                '回复 ${detail.replyNum}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12.sp,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            if (detail.supportNum > 0)
              Text(
                '赞 ${detail.supportNum}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12.sp,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            if (item.pageView > 0 || detail.readNum > 0)
              Text(
                '阅读 ${item.pageView > 0 ? item.pageView : detail.readNum}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12.sp,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
        SizedBox(height: 16.h),
        if (detail.blocks.isEmpty && detail.summary.isNotEmpty)
          SelectableText(
            detail.summary,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.65,
              fontSize: 15.sp,
            ),
          )
        else
          for (final block in detail.blocks) ...[
            if (block.isText)
              Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: SelectableText(
                  block.text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.65,
                    fontSize: 15.sp,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
            if (block.isImage)
              Padding(
                padding: EdgeInsets.only(bottom: 14.h),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: AppCachedImage(
                    url: block.imageUrl,
                    fit: BoxFit.fitWidth,
                    width: double.infinity,
                    errorWidget: ColoredBox(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.06),
                      child: SizedBox(
                        height: 120.h,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 28.sp,
                        ),
                      ),
                    ),
                  ),
                ),
                  ),
          ],
      ],
    );
  }
}

class _ThirdPartyNewsDetailBody extends StatefulWidget {
  final ThirdPartyNewsItem item;
  const _ThirdPartyNewsDetailBody({required this.item});

  @override
  State<_ThirdPartyNewsDetailBody> createState() =>
      _ThirdPartyNewsDetailBodyState();
}

class _ThirdPartyNewsDetailBodyState extends State<_ThirdPartyNewsDetailBody> {
  ThirdPartyNewsDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ThirdPartyNewsDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.source != widget.item.source) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _detail = null;
    });
    try {
      final detail = switch (widget.item.source) {
        ThirdPartyNewsSource.sohu =>
          await SohuNbaApi.getDetail(widget.item),
        ThirdPartyNewsSource.hupu =>
          await HupuNbaApi.getDetail(widget.item),
      };
      if (!mounted) return;
      setState(() {
        _detail = detail;
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

  String _formatTime(DateTime time) {
    return '${time.year}/'
        '${time.month.toString().padLeft(2, '0')}/'
        '${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final detail = _detail;
    if (detail == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.title, textAlign: TextAlign.center),
              SizedBox(height: 12.h),
              Text(
                _error ?? '加载失败',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              SizedBox(height: 16.h),
              TextButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 28.h),
      children: [
        SelectableText(
          detail.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.35,
            fontSize: 18.sp,
          ),
        ),
        SizedBox(height: 10.h),
        Wrap(
          spacing: 12.w,
          children: [
            Text(
              detail.author.isNotEmpty ? detail.author : item.sourceLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12.sp,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (detail.publishedAt != null)
              Text(
                _formatTime(detail.publishedAt!),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12.sp,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
        if (detail.images.isNotEmpty) ...[
          SizedBox(height: 14.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: AppCachedImage(
              url: detail.images.first,
              fit: BoxFit.fitWidth,
              width: double.infinity,
              errorWidget: const SizedBox.shrink(),
            ),
          ),
        ] else if (item.pic.isNotEmpty) ...[
          SizedBox(height: 14.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: AppCachedImage(
              url: item.pic,
              fit: BoxFit.fitWidth,
              width: double.infinity,
              errorWidget: const SizedBox.shrink(),
            ),
          ),
        ],
        SizedBox(height: 16.h),
        if (detail.paragraphs.isEmpty)
          SelectableText(
            item.summary.isNotEmpty ? item.summary : '暂无正文',
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.65,
              fontSize: 15.sp,
            ),
          )
        else
          for (final p in detail.paragraphs)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: SelectableText(
                p,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.65,
                  fontSize: 15.sp,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                ),
              ),
            ),
        if (detail.images.length > 1) ...[
          SizedBox(height: 8.h),
          for (final img in detail.images.skip(1))
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: AppCachedImage(
                  url: img,
                  fit: BoxFit.fitWidth,
                  width: double.infinity,
                  errorWidget: const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _PostDetailBody extends StatefulWidget {
  final XPost post;
  const _PostDetailBody({required this.post});

  @override
  State<_PostDetailBody> createState() => _PostDetailBodyState();
}

class _PostDetailBodyState extends State<_PostDetailBody> {
  final _service = XFeedService();
  String _translation = '';
  bool _translating = false;

  XPost get post => widget.post;

  bool get _hasTranslation {
    final t = _translation.trim();
    return t.isNotEmpty && t != post.text.trim();
  }

  @override
  void initState() {
    super.initState();
    _translation = post.translation;
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureTranslation());
  }

  @override
  void didUpdateWidget(covariant _PostDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != post.id) {
      _translation = post.translation;
      _translating = false;
      _ensureTranslation();
    }
  }

  Future<void> _ensureTranslation() async {
    if (post.text.trim().isEmpty || post.isChinese || _hasTranslation) {
      return;
    }
    final cached = XFeedService.cachedTranslation(post.id);
    if (cached != null && cached.isNotEmpty) {
      if (mounted) setState(() => _translation = cached);
      return;
    }
    if (_translating) return;
    setState(() => _translating = true);
    try {
      final text = await _service.fetchPostTranslation(post.id);
      if (!mounted || post.id != widget.post.id) return;
      setState(() {
        _translation = text;
        _translating = false;
      });
    } catch (_) {
      if (mounted && post.id == widget.post.id) {
        setState(() => _translating = false);
      }
    }
  }

  String _formatTime(DateTime time) {
    return '${time.year}/'
        '${time.month.toString().padLeft(2, '0')}/'
        '${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = post.media
        .where((m) => m.kind == XMediaKind.photo || m.isVideo)
        .toList(growable: false);

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 28.h),
      children: [
        Row(
          children: [
            _DetailAvatar(url: post.avatarUrl),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16.sp,
                    ),
                  ),
                  Text(
                    '@${post.username}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (post.publishedAt != null) ...[
          SizedBox(height: 8.h),
          Text(
            _formatTime(post.publishedAt!),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
        if (_hasTranslation) ...[
          SizedBox(height: 16.h),
          Text(
            '译文',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          SizedBox(height: 6.h),
          SelectableText(
            _translation.trim(),
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.55,
              fontSize: 15.sp,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            '原文',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          SizedBox(height: 6.h),
          SelectableText(
            post.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              fontSize: 14.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ] else if (post.text.isNotEmpty) ...[
          SizedBox(height: 16.h),
          SelectableText(
            post.text,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.55,
              fontSize: 15.sp,
            ),
          ),
          if (_translating) ...[
            SizedBox(height: 10.h),
            Row(
              children: [
                SizedBox(
                  width: 14.w,
                  height: 14.w,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8.w),
                Text(
                  '正在翻译…',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12.sp,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ],
        if (post.likes > 0 || post.views > 0) ...[
          SizedBox(height: 14.h),
          Row(
            children: [
              if (post.likes > 0) ...[
                Icon(Icons.favorite_border_rounded, size: 14.sp),
                SizedBox(width: 4.w),
                Text('${post.likes}', style: theme.textTheme.bodyMedium),
                SizedBox(width: 14.w),
              ],
              if (post.views > 0) ...[
                Icon(Icons.visibility_outlined, size: 14.sp),
                SizedBox(width: 4.w),
                Text('${post.views}', style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ],
        if (media.isNotEmpty) ...[
          SizedBox(height: 16.h),
          for (final m in media) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: AspectRatio(
                aspectRatio: m.width > 0 && m.height > 0
                    ? m.width / m.height
                    : 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ProxiedImage(url: m.listUrl),
                    if (m.isVideo)
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          margin: EdgeInsets.all(8.w),
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded,
                                  size: 16.sp, color: Colors.white),
                              if (m.durationLabel.isNotEmpty) ...[
                                SizedBox(width: 2.w),
                                Text(
                                  m.durationLabel,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.sp,
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
            SizedBox(height: 10.h),
          ],
        ],
      ],
    );
  }
}

class _DetailAvatar extends StatelessWidget {
  final String url;
  const _DetailAvatar({required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = CircleAvatar(
      radius: 22.r,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
      child: Icon(Icons.person, size: 22.sp),
    );
    if (url.isEmpty) return fallback;
    return ClipOval(
      child: SizedBox(
        width: 44.w,
        height: 44.w,
        child: _ProxiedImage(url: url),
      ),
    );
  }
}

class _ProxiedImage extends StatefulWidget {
  final String url;
  const _ProxiedImage({required this.url});

  @override
  State<_ProxiedImage> createState() => _ProxiedImageState();
}

class _ProxiedImageState extends State<_ProxiedImage> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = XFeedService.fetchBytes(widget.url);
  }

  @override
  void didUpdateWidget(covariant _ProxiedImage oldWidget) {
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
            child: Icon(Icons.image_not_supported_outlined, size: 22.sp),
          );
        }
        return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
      },
    );
  }
}

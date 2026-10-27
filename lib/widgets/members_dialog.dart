import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nba_games/models/nba_member_model.dart';
import 'package:nba_games/request/nba_members_store.dart';
import 'package:nba_games/widgets/app_cached_image.dart';
import 'package:url_launcher/url_launcher.dart';

void showMembersDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => const _MembersDialog(),
  );
}

class _MembersDialog extends StatelessWidget {
  const _MembersDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 800;
    final maxW = wide ? 560.0 : size.width * 0.9;

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
                    'NBA 成员',
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
            const Expanded(child: MembersBody()),
          ],
        ),
      ),
    );
  }
}

/// 桌面弹窗与手机 Tab 共用
class MembersBody extends StatefulWidget {
  const MembersBody({super.key});

  @override
  State<MembersBody> createState() => _MembersBodyState();
}

class _MembersBodyState extends State<MembersBody> {
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String? _error;
  List<NbaMember> _all = const [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bundle = await NbaMembersStore.load();
      if (!mounted) return;
      setState(() {
        _all = bundle.members;
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

  List<NbaMember> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((m) {
      return m.username.toLowerCase().contains(q) ||
          m.name.toLowerCase().contains(q) ||
          m.description.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openProfile(NbaMember member) async {
    final uri = Uri.tryParse(member.xUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
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

    final rows = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: '搜索姓名 / 用户名',
              prefixIcon: Icon(Icons.search_rounded, size: 20.sp),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清除',
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                      icon: Icon(Icons.close_rounded, size: 18.sp),
                    ),
              isDense: true,
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 10.h,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            '共 ${rows.length} 人（media_downloader · 篮球 · 已关注）',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Text(
                    '无匹配成员',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(8.w, 0, 8.w, 16.h),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 64.w,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                  itemBuilder: (context, index) {
                    final m = rows[index];
                    return ListTile(
                      dense: true,
                      leading: _Avatar(url: m.avatarUrl),
                      title: Text(
                        m.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        [
                          '@${m.username}',
                          if (m.followers > 0)
                            '粉丝 ${_formatCount(m.followers)}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                      trailing: Icon(Icons.open_in_new_rounded, size: 16.sp),
                      onTap: () => _openProfile(m),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  const _Avatar({required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = CircleAvatar(
      radius: 18.r,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
      child: Icon(Icons.person, size: 18.sp),
    );
    if (url.isEmpty) return fallback;
    return ClipOval(
      child: AppCachedImage(
        url: url,
        width: 36.w,
        height: 36.w,
        fit: BoxFit.cover,
        errorWidget: fallback,
      ),
    );
  }
}

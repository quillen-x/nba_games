import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 桌面左边栏，风格参考 spat HomeLeftTabBar
class HomeLeftTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabTap;

  const HomeLeftTabBar({
    super.key,
    required this.currentIndex,
    required this.onTabTap,
  });

  static const tabs = <_LeftTabItem>[
    _LeftTabItem(
      icon: Icons.dynamic_feed_outlined,
      selectedIcon: Icons.dynamic_feed,
      label: '动态',
    ),
    _LeftTabItem(
      icon: Icons.sports_basketball_outlined,
      selectedIcon: Icons.sports_basketball,
      label: '比赛',
    ),
    _LeftTabItem(
      icon: Icons.leaderboard_outlined,
      selectedIcon: Icons.leaderboard,
      label: '排行',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      width: 64.w,
      height: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(right: BorderSide(color: border)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < tabs.length; i++)
            _TabButton(
              index: i,
              currentIndex: currentIndex,
              icon: tabs[i].icon,
              selectedIcon: tabs[i].selectedIcon,
              label: tabs[i].label,
              onTap: onTabTap,
            ),
        ],
      ),
    );
  }
}

class _LeftTabItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _LeftTabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class _TabButton extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final ValueChanged<int> onTap;

  const _TabButton({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = currentIndex == index;
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.45);

    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: () => onTap(index),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 6.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: 22.sp,
                color: color,
              ),
              SizedBox(height: 4.h),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11.sp,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

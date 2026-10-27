import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 统一网络图缓存
class AppCachedImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AppCachedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = errorWidget ??
        ColoredBox(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
        );
    final loading = placeholder ??
        ColoredBox(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => SizedBox(
        width: width,
        height: height,
        child: loading,
      ),
      errorWidget: (_, __, ___) => SizedBox(
        width: width,
        height: height,
        child: fallback,
      ),
    );
  }
}

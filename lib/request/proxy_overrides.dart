import 'dart:io';

/// 可选的全局代理（默认不启用，避免腾讯赛程被误转到本机 Clash）。
/// 动态拉取在 [XFeedService] 内单独配置代理。
class ProxyHttpOverrides extends HttpOverrides {
  ProxyHttpOverrides(this.proxyAddress);

  /// `host:port`，为空则走系统环境变量
  final String? proxyAddress;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionTimeout = const Duration(seconds: 20);
    client.idleTimeout = const Duration(minutes: 10);
    client.userAgent = 'NBAGames/1.0 (Flutter)';
    final address = proxyAddress?.trim();
    if (address != null && address.isNotEmpty) {
      client.findProxy = (uri) => 'PROXY $address';
    } else {
      client.findProxy = HttpClient.findProxyFromEnvironment;
    }
    return client;
  }

  static void apply(String? proxyAddress) {
    HttpOverrides.global = ProxyHttpOverrides(proxyAddress);
  }
}

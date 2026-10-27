import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:nba_games/models/nba_member_model.dart';

class NbaMembersStore {
  NbaMembersStore._();

  static const assetPath = 'assets/data/nba_members.json';

  static NbaMembersBundle? _cache;

  static Future<NbaMembersBundle> load({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw);
    if (json is! Map) {
      throw StateError('nba_members.json 格式异常');
    }
    final bundle = NbaMembersBundle.fromJson(Map<String, dynamic>.from(json));
    _cache = bundle;
    return bundle;
  }
}

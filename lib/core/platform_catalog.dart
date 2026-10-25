import 'dart:convert';

import 'package:flutter/services.dart';

class OfficialDestination {
  const OfficialDestination({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.webUrl,
    this.wechatUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final Uri? webUrl;
  final Uri? wechatUrl;

  static final Future<List<OfficialDestination>> catalog = _load();

  static Future<List<OfficialDestination>> _load() async {
    final json =
        jsonDecode(await rootBundle.loadString('assets/platforms.json'))
            as Map<String, dynamic>;
    return List.unmodifiable(
      (json['destinations'] as List).map((item) {
        final value = item as Map<String, dynamic>;
        return OfficialDestination(
          id: value['id'] as String,
          title: value['title'] as String,
          subtitle: value['subtitle'] as String,
          icon: value['icon'] as String,
          webUrl: value['webUrl'] == null
              ? null
              : Uri.parse(value['webUrl'] as String),
          wechatUrl: value['wechatUrl'] == null
              ? null
              : Uri.parse(value['wechatUrl'] as String),
        );
      }),
    );
  }
}

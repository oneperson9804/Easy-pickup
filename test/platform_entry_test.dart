import 'dart:convert';

import 'package:easy_pickup/core/platform_catalog.dart';
import 'package:easy_pickup/services/platform_services.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('官方目录提供七个页面入口，微信取件链接独立于网页备用', () async {
    final entries = await OfficialDestination.catalog;
    expect(entries.length, 7);
    expect(entries.map((entry) => entry.id).toSet().length, entries.length);
    expect(entries.map((entry) => entry.title), containsAll(['抖音订单', '小红书订单']));
    final pinduoduo = entries.singleWhere(
      (entry) => entry.id == 'pinduoduo_pickup',
    );
    expect(pinduoduo.webUrl, isNull);
    expect(pinduoduo.wechatUrl?.host, 'mdkd.pinduoduo.com');
    expect(pinduoduo.wechatUrl?.queryParameters['entry_source'], '24');
  });

  test('淘宝订单使用订单列表地址，抖音渠道包与协议各自配对', () async {
    final json =
        jsonDecode(await rootBundle.loadString('assets/platforms.json'))
            as Map<String, dynamic>;
    final entries = (json['destinations'] as List).cast<Map<String, dynamic>>();
    for (final entry in entries) {
      final routes = (entry['apps'] as List).cast<Map<String, dynamic>>();
      expect(routes, isNotEmpty, reason: entry['id'] as String);
      for (final route in routes) {
        expect(route['package'], isA<String>());
        expect((route['package'] as String).split('.').length, greaterThan(2));
        final uri = Uri.parse(route['uri'] as String);
        expect(uri.isAbsolute, isTrue);
        expect(uri.scheme, isNot(anyOf('http', 'https')));
      }
      for (final key in ['webUrl', 'wechatUrl']) {
        if (entry[key] != null) {
          expect(Uri.parse(entry[key] as String).scheme, 'https');
        }
      }
    }
    final taobao = entries.singleWhere(
      (entry) => entry['id'] == 'taobao_orders',
    );
    final taobaoUrl = Uri.parse(
      (taobao['apps'] as List).single['uri'] as String,
    );
    expect(taobaoUrl.scheme, 'tbopen');
    expect(taobaoUrl.queryParameters['action'], 'ali.open.nav');
    expect(taobaoUrl.queryParameters['module'], 'h5');
    expect(
      taobaoUrl.queryParameters['h5Url'],
      'https://h5.m.taobao.com/mlapp/olist.html',
    );
    final douyin = entries.singleWhere(
      (entry) => entry['id'] == 'douyin_orders',
    );
    final routes = (douyin['apps'] as List).cast<Map<String, dynamic>>();
    expect(
      routes.singleWhere(
        (route) => route['package'] == 'com.ss.android.ugc.aweme',
      )['uri'],
      'snssdk1128://ecom_order_list',
    );
    expect(
      routes.singleWhere(
        (route) => route['package'] == 'com.ss.android.ugc.aweme.mobile',
      )['uri'],
      'snssdk664226://ecom_order_list',
    );
  });

  test('平台调用分别报告系统接受、入口未被接受与权限拒绝', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Map<String, String>? reply;
    messenger.setMockMethodCallHandler(PlatformServices.channel, (call) async {
      expect(call.method, 'openOfficial');
      expect(call.arguments, {'id': 'cainiao_code'});
      return reply;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(PlatformServices.channel, null);
    });
    final platform = PlatformServices();
    reply = {'status': 'app'};
    expect((await platform.openOfficial('cainiao_code')).opened, isTrue);
    reply = {'status': 'unavailable', 'reason': 'access_denied'};
    final blocked = await platform.openOfficial('cainiao_code');
    expect(blocked.opened, isFalse);
    expect(blocked.reason, 'access_denied');
    reply = null;
    expect((await platform.openOfficial('cainiao_code')).opened, isFalse);
  });
}

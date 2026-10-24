import 'package:easy_pickup/main.dart' as application;
import 'package:easy_pickup/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('本机启动、手动取件保存和底部导航', (tester) async {
    await application.main();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-scaffold')), findsOneWidget);

    final controller = tester
        .widget<EasyPickupApp>(find.byType(EasyPickupApp))
        .controller;
    final permissions = await controller.platform.getPermissions();
    expect(permissions['platform'], 'ios');
    expect(controller.error, isNull);
    final path = await controller.platform.databasePath();
    final database = await openDatabase(path, singleInstance: false);
    final station = '青竹路测试站-${DateTime.now().microsecondsSinceEpoch}';

    try {
      await _tap(tester, 'add-parcel');
      await _tap(tester, 'add-manual');
      await tester.enterText(
        find.byKey(const ValueKey('parcel-station')),
        station,
      );
      await tester.enterText(
        find.byKey(const ValueKey('parcel-code')),
        '8-16384',
      );
      await tester.enterText(
        find.byKey(const ValueKey('parcel-detail')),
        '东门二楼',
      );
      await _tap(tester, 'save-parcel');
      await _waitFor(
        tester,
        () => controller.pending.any((parcel) => parcel.station == station),
      );

      final rows = await database.query(
        'parcels',
        where: 'station = ?',
        whereArgs: [station],
      );
      expect(rows, hasLength(1));
      expect(rows.single['code'], '8-16384');
      expect(rows.single['detail_address'], '东门二楼');
      expect(rows.single['collected_at'], isNull);

      for (final key in ['nav-calendar', 'nav-wallet', 'nav-pending']) {
        await _tap(tester, key);
        expect(find.byKey(const ValueKey('main-scaffold')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(find.text('8-16384'), findsOneWidget);
      expect(controller.error, isNull);
    } finally {
      await database.delete(
        'parcels',
        where: 'station = ?',
        whereArgs: [station],
      );
      await database.close();
      await controller.reload();
      await tester.pumpAndSettle();
    }
  });
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _waitFor(WidgetTester tester, bool Function() completed) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (!completed() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(completed(), isTrue, reason: '手动取件应保存到本机记录');
  await tester.pumpAndSettle();
}

import 'package:easy_pickup/core/app_controller.dart';
import 'package:easy_pickup/core/models.dart';
import 'package:easy_pickup/core/repository.dart';
import 'package:easy_pickup/services/platform_services.dart';
import 'package:easy_pickup/ui/settings_pages.dart';
import 'package:easy_pickup/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database database;
  late ParcelRepository repository;
  late AppController app;
  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    repository = await ParcelRepository.forDatabase(database);
    app = AppController(repository: repository, platform: _WidgetPlatform());
    await app.reload();
  });
  tearDown(() async {
    app.dispose();
    await database.close();
  });

  testWidgets('窄屏与大字体下可调玻璃样式、背景浓度和桌面码隐私', (tester) async {
    await tester.runAsync(
      () => app.addParcel(
        Parcel(
          id: 'widget-long-station',
          station: '重庆理工大学花溪京东校园服务站',
          code: 'A3-2-4182',
          arrivedAt: DateTime.now(),
        ),
      ),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: pickupTheme(Brightness.light),
        home: WidgetSettingsPage(app: app),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('A3-2-4182'), findsOneWidget);

    await tester.ensureVisible(find.text('雾白玻璃'));
    await tester.tap(find.text('雾白玻璃'));
    await _settle(tester, () => app.settings.widgetStyle == 'ivory');

    final slider = find.byKey(const ValueKey('widget-opacity'));
    await tester.ensureVisible(slider);
    await tester.drag(slider, const Offset(100, 0));
    await _settle(tester, () => app.settings.widgetOpacity > .42);
    final opacity = app.settings.widgetOpacity;
    expect(opacity, inInclusiveRange(.18, .9));

    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await _settle(tester, () => !app.settings.widgetShowCodes);
    final saved = await tester.runAsync(repository.load);
    expect(saved!.settings.widgetStyle, 'ivory');
    expect(saved.settings.widgetOpacity, opacity);
    expect(saved.settings.widgetShowCodes, isFalse);
    expect(tester.takeException(), isNull);
  });

  test('既有备份的玻璃浓度使用默认值，设置可往返保存', () {
    expect(AppSettings.fromMap({}).widgetOpacity, .42);
    expect(
      AppSettings.fromMap(
        const AppSettings(widgetOpacity: .72).toMap(),
      ).widgetOpacity,
      .72,
    );
  });
}

Future<void> _settle(WidgetTester tester, bool Function() complete) async {
  await tester.pumpAndSettle();
  for (var attempt = 0; attempt < 100 && !complete(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
  expect(complete(), isTrue);
}

class _WidgetPlatform extends PlatformServices {
  @override
  Future<Map<String, dynamic>?> consumeSharedImport() async => null;
  @override
  Future<void> refreshWidgets() async {}
  @override
  Future<void> scheduleReminders(AppSettings settings) async {}
}

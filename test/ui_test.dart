import 'package:barcode_widget/barcode_widget.dart';
import 'package:easy_pickup/core/app_controller.dart';
import 'package:easy_pickup/core/models.dart';
import 'package:easy_pickup/core/repository.dart';
import 'package:easy_pickup/services/platform_services.dart';
import 'package:easy_pickup/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database database;
  late ParcelRepository repository;
  late AppController app;
  late _TestPlatform platform;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    repository = await ParcelRepository.forDatabase(database);
    platform = _TestPlatform();
    app = AppController(repository: repository, platform: platform);
    await app.reload();
  });
  tearDown(() async {
    app.dispose();
    await database.close();
  });

  Future<void> start(
    WidgetTester tester, {
    double width = 400,
    double height = 900,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(EasyPickupApp(controller: app));
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 1.5]) {
    testWidgets('360×640与${scale * 100}%字体下短信入口可滚动并点击', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.resetPadding);
      await start(tester, width: 360, height: 640);
      await _tap(tester, find.byKey(const ValueKey('add-parcel')));
      final sms = find.byKey(const ValueKey('add-sms'));
      await tester.ensureVisible(sms);
      await tester.pumpAndSettle();
      expect(sms.hitTestable(), findsOneWidget);
      expect(tester.getCenter(sms).dy, lessThan(616));
      await _tap(tester, sms);
      expect(platform.smsRequests, 1);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets('底部三页与左上角九项菜单', (tester) async {
    await start(tester);
    for (final tab in ['nav-pending', 'nav-calendar', 'nav-wallet']) {
      expect(find.byKey(ValueKey(tab)), findsOneWidget);
      await tester.tap(find.byKey(ValueKey(tab)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    final drawer = find.byType(Drawer);
    expect(drawer, findsOneWidget);
    const labels = [
      '设置',
      '权限说明',
      '桌面小组件',
      '常见问题',
      '反馈意见',
      '用户协议',
      '隐私政策',
      '检查更新',
      '关于与开源',
    ];
    for (final label in labels) {
      expect(
        find.descendant(of: drawer, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: drawer, matching: find.byType(ListTile)),
      findsNWidgets(9),
    );
  });

  testWidgets('手动录入允许空码，并把详细位置真正保存和显示', (tester) async {
    await start(tester);
    await _tap(tester, find.byKey(const ValueKey('add-parcel')));
    await _tap(tester, find.byKey(const ValueKey('add-manual')));
    await tester.enterText(
      find.byKey(const ValueKey('parcel-station')),
      '学校东门驿站',
    );
    await tester.enterText(
      find.byKey(const ValueKey('parcel-detail')),
      '二楼右侧第三排',
    );
    await _tap(
      tester,
      find.byKey(const ValueKey('save-parcel')),
      until: () =>
          app.parcels.length == 1 && find.text('取件码待补充').evaluate().isNotEmpty,
    );
    expect(app.pending.single.code, isEmpty);
    expect(app.pending.single.detailAddress, '二楼右侧第三排');
    expect(find.text('取件码待补充'), findsOneWidget);
    expect(find.text('二楼右侧第三排'), findsOneWidget);
    final saved = await tester.runAsync(repository.load);
    expect(saved!.parcels.single.detailAddress, '二楼右侧第三排');
    expect(tester.takeException(), isNull);
  });

  testWidgets('整组批量已取和撤销同步真实SQLite，日历保留跨日未取', (tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 2; i++) {
        await app.addParcel(
          Parcel(
            id: 'pending-$i',
            station: '竹林驿站',
            code: '8-${i + 1}',
            arrivedAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        );
      }
    });
    await start(tester);
    await _tap(tester, find.byType(Checkbox).first);
    expect(find.text('选 2 件'), findsOneWidget);
    await _tap(
      tester,
      find.byKey(const ValueKey('mark-selected-collected')),
      until: () =>
          app.pending.isEmpty && find.text('还没有待取件').evaluate().isNotEmpty,
    );
    expect(app.collected.length, 2);
    expect(find.text('还没有待取件'), findsOneWidget);
    await _tap(
      tester,
      find.text('撤销'),
      until: () =>
          app.pending.length == 2 && find.text('8-1').evaluate().isNotEmpty,
    );
    expect(app.pending.every((parcel) => parcel.collectedAt == null), isTrue);
    final restored = await tester.runAsync(repository.load);
    expect(restored!.parcels.where((parcel) => parcel.isCollected), isEmpty);
    await _tap(tester, find.byKey(const ValueKey('nav-calendar')));
    await tester.scrollUntilVisible(
      find.text('跨日未取'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('跨日未取'), findsOneWidget);
    expect(find.text('2 件仍在等你，取完后可标记已取'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('码夹手动保存静态二维码，并可打开真实码图', (tester) async {
    await start(tester);
    await _tap(tester, find.byKey(const ValueKey('nav-wallet')));
    final add = find.byKey(const ValueKey('add-saved-code'));
    await tester.scrollUntilVisible(
      add,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await _tap(tester, add);
    await _tap(tester, find.text('手动输入'));
    await tester.enterText(
      find.byKey(const ValueKey('saved-code-label')),
      '自用固定取件码',
    );
    await tester.enterText(
      find.byKey(const ValueKey('saved-code-value')),
      'local-test-123',
    );
    await _tap(
      tester,
      find.byKey(const ValueKey('save-code')),
      until: () =>
          app.codes.length == 1 && find.text('自用固定取件码').evaluate().isNotEmpty,
    );
    expect(app.codes.single.value, 'local-test-123');
    final label = find.text('自用固定取件码');
    await tester.ensureVisible(label);
    await _tap(tester, label);
    expect(find.byType(BarcodeWidget), findsOneWidget);
    expect(find.text('local-test-123'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360dp与大字体下三页可用，设置切换深色主题', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await start(tester, width: 360);
    for (final tab in ['nav-pending', 'nav-calendar', 'nav-wallet']) {
      await _tap(tester, find.byKey(ValueKey(tab)));
      expect(tester.takeException(), isNull, reason: '$tab 在360dp/150%文字下不应溢出');
    }
    await _tap(tester, find.byIcon(Icons.menu));
    await _tap(
      tester,
      find.descendant(of: find.byType(Drawer), matching: find.text('设置')),
    );
    await _tap(tester, find.text('外观主题'));
    await _tap(
      tester,
      find.text('深色 · 玄青金雷'),
      until: () =>
          app.settings.themeMode == 'dark' &&
          Theme.of(tester.element(find.text('外观主题'))).brightness ==
              Brightness.dark,
    );
    expect(app.settings.themeMode, 'dark');
    expect(
      Theme.of(tester.element(find.text('外观主题'))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('分享只识别出部分通知时保留草稿，未识别内容不会被确认清除', (tester) async {
    const draft = '【中通快递】已到竹林驿站，取件码:6-600。\n\n明天请到食堂参加志愿活动';
    await tester.runAsync(() async {
      await repository.saveDraft(draft);
      await app.reload();
    });
    await start(tester);
    await _tap(tester, find.text('查看'));
    await _tap(
      tester,
      find.byKey(const ValueKey('confirm-import')),
      until: () => find
          .byKey(const ValueKey('save-reviewed-import'))
          .evaluate()
          .isNotEmpty,
    );
    expect(app.parcels, isEmpty);
    expect(
      tester.getTopLeft(find.text('6-600')).dy,
      lessThan(tester.getTopLeft(find.text('未识别文字')).dy),
    );
    await _tap(
      tester,
      find.byKey(const ValueKey('save-reviewed-import')),
      until: () =>
          app.parcels.length == 1 &&
          find.textContaining('其余文字已保留为草稿').evaluate().isNotEmpty,
    );
    expect(app.pending.single.code, '6-600');
    expect(app.sharedText, '明天请到食堂参加志愿活动');
    expect(await tester.runAsync(repository.loadDraft), app.sharedText);
    expect(find.textContaining('其余文字已保留为草稿'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tap(
  WidgetTester tester,
  Finder finder, {
  bool Function()? until,
}) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
  });
  // Complete route animations before waiting for SQLite work that may start
  // after DialogRoute.completed. This mirrors frames progressing on a device.
  if (until == null) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 500));
  }
  if (until != null) {
    final deadline = Stopwatch()..start();
    do {
      // SQLite may assign the controller snapshot before later awaits finish
      // and notifyListeners schedules a frame. Yield real I/O, then render a
      // frame outside runAsync and inspect the visible result, not just data.
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump(const Duration(milliseconds: 16));
      if (until()) break;
    } while (deadline.elapsed < const Duration(seconds: 5));
    expect(until(), isTrue, reason: '操作应实际完成并渲染更新后的界面');
  }
  await tester.pumpAndSettle();
}

class _TestPlatform extends PlatformServices {
  int smsRequests = 0;

  @override
  Future<bool> requestSms() async {
    smsRequests++;
    return false;
  }

  @override
  void setRecordsChangedCallback(Future<void> Function()? callback) {}
  @override
  Future<Map<String, dynamic>?> consumeSharedImport() async => null;
  @override
  Future<void> refreshWidgets() async {}
  @override
  Future<void> scheduleReminders(AppSettings settings) async {}
  @override
  Future<bool> requestNotifications() async => true;
  @override
  Future<Map<String, dynamic>> getPermissions() async => {
    'platform': 'android',
    'readSms': false,
    'receiveSms': false,
    'notifications': false,
    'camera': false,
    'widgetSupported': true,
  };
}

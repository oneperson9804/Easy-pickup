import 'package:easy_pickup/services/page_capture_service.dart';
import 'package:easy_pickup/ui/page_capture.dart';
import 'package:easy_pickup/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'page reading requires consent, platform selection and an explicit session',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <MethodCall>[];
      var native = <String, dynamic>{
        'enabled': true,
        'connected': true,
        'consented': false,
        'running': false,
        'screenshotSupported': true,
        'selectedPackages': <String>[],
        'platforms': {'com.cainiao.wireless': '菜鸟'},
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PageCaptureService.channel, (call) async {
            calls.add(call);
            if (call.method == 'configure') {
              final arguments = Map<String, dynamic>.from(
                call.arguments as Map,
              );
              native = {...native, ...arguments, 'running': false};
            }
            if (call.method == 'startSession') {
              native = {...native, 'running': true};
            }
            if (call.method == 'stopSession') {
              native = {...native, 'running': false};
            }
            return native;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(PageCaptureService.channel, null),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: pickupTheme(Brightness.light),
          home: const PageCapturePage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls.map((call) => call.method), ['state']);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('capture-session')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const ValueKey('capture-consent')));
      await tester.pumpAndSettle();
      expect(native['consented'], isTrue);
      expect(native['running'], isFalse);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('capture-session')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('菜鸟'));
      await tester.pumpAndSettle();
      expect(native['selectedPackages'], ['com.cainiao.wireless']);
      expect(calls.where((call) => call.method == 'startSession'), isEmpty);

      await tester.ensureVisible(find.byKey(const ValueKey('capture-session')));
      await tester.tap(find.byKey(const ValueKey('capture-session')));
      await tester.pumpAndSettle();
      expect(native['running'], isTrue);
      expect(find.text('结束本次识别'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('capture-consent')));
      await tester.tap(find.byKey(const ValueKey('capture-consent')));
      await tester.pumpAndSettle();
      expect(native['consented'], isFalse);
      expect(native['running'], isFalse);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('capture-session')))
            .onPressed,
        isNull,
      );
    },
  );
}

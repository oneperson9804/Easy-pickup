import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:easy_pickup/core/models.dart';
import 'package:easy_pickup/core/parser.dart';
import 'package:easy_pickup/core/repository.dart';
import 'package:easy_pickup/core/app_controller.dart';
import 'package:easy_pickup/services/platform_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('快递短信识别与验证码隔离，共用原生测试样例', () {
    final cases =
        jsonDecode(File('test/fixtures/sms.json').readAsStringSync()) as List;
    for (final c in cases) {
      final result = parseParcelText(c['body'] as String);
      expect(result?.code, c['code'], reason: c['body'] as String);
      if (c['code'] != null) {
        expect(result?.station, c['station']);
        expect(result?.company, c['company']);
      }
    }
  });
  test('自定义纠正规则按文字匹配，不运行用户正则', () {
    final result = parseParcelText(
      '【新快递】已到竹林驿站，取件码:8-9-10。',
      rules: const [
        RecognitionRule(
          id: 'a',
          kind: 'address',
          pattern: '竹林',
          replacement: '学校东门',
        ),
        RecognitionRule(
          id: 'c',
          kind: 'company',
          pattern: '新快递',
          replacement: '新快递公司',
        ),
      ],
    );
    expect(result?.station, '学校东门');
    expect(result?.company, '新快递公司');
  });
  test('按数字自然排序与撤销已取时间', () {
    final codes = ['8-10', '8-2', '8-100']..sort(naturalCompare);
    expect(codes, ['8-2', '8-10', '8-100']);
    final p = Parcel(
      id: 'p',
      station: '东门',
      code: '8-2',
      arrivedAt: DateTime(2026, 1, 1),
      collectedAt: DateTime(2026, 1, 2),
    );
    expect(p.copyWith(collectedAt: null).isCollected, false);
    expect(p.copyWith(station: '西门').collectedAt, p.collectedAt);
  });
  test('拒绝外来或未知版本备份，保持格式边界', () {
    expect(
      () => AppSnapshot.fromMap({
        'format': 'other',
        'schemaVersion': 1,
        'parcels': [],
      }),
      throwsFormatException,
    );
    expect(
      () => AppSnapshot.fromMap({
        'format': 'easy-pickup',
        'schemaVersion': 9,
        'parcels': [],
      }),
      throwsFormatException,
    );
  });

  sqfliteFfiInit();
  group('真实SQLite记录及备份事务', () {
    late Database db;
    late ParcelRepository repository;
    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      repository = await ParcelRepository.forDatabase(db);
    });
    tearDown(() async {
      await db.close();
    });
    test('确认一份分享不会消费或清除下一份，草稿先保存再ACK', () async {
      final platform = TestPlatformServices();
      const a = '【中通快递】已到青竹路菜鸟驿站，取件码:1-100。';
      const b = '【圆通快递】已到学校东门驿站，取件码:2-200。';
      platform.shares.addAll([
        {'draftId': 'a', 'text': a},
        {'draftId': 'b', 'text': b},
      ]);
      final app = AppController(repository: repository, platform: platform);
      await app.reload();
      expect(app.sharedText, a);
      expect(platform.shares.length, 1);
      await app.importText(app.sharedText!, source: 'share');
      expect(app.sharedText, a);
      expect(platform.shares.single['draftId'], 'b');
      await app.clearSharedText();
      expect(app.sharedText, b);
      expect(platform.shares, isEmpty);
      expect(app.parcels.length, 1);
      await app.importText(app.sharedText!, source: 'share');
      await app.clearSharedText();
      expect(app.sharedText, isNull);
      expect(app.parcels.length, 2);
    });
    test('ACK失败不丢持久草稿，重试不重复拼接；空内容保留待忽略', () async {
      final platform = TestPlatformServices()..failAckOnce = true;
      platform.shares.add({'draftId': 'a', 'text': '已到东门驿站，取件码:100-2。'});
      final app = AppController(repository: repository, platform: platform);
      await app.reload();
      expect(app.sharedText, '已到东门驿站，取件码:100-2。');
      expect(app.error, isNotNull);
      expect(platform.shares.length, 1);
      await app.reload();
      expect(platform.shares, isEmpty);
      expect(app.sharedText, '已到东门驿站，取件码:100-2。');
      await app.clearSharedText();
      platform.shares.add({'draftId': 'empty', 'text': ''});
      await app.reload();
      expect(platform.shares.length, 1);
      expect(app.failedSharedImportId, 'empty');
      await app.discardIncomingShare();
      expect(platform.shares, isEmpty);
    });
    test('备份设置先校验，提醒失败不伪装成整次导入失败', () async {
      final platform = TestPlatformServices()..failReminders = true;
      final app = AppController(repository: repository, platform: platform);
      final parcel = Parcel(
        id: 'backup',
        station: '东门',
        code: '',
        arrivedAt: DateTime(2026, 1, 1),
      );
      await expectLater(
        app.importSnapshot(
          AppSnapshot(
            parcels: [parcel],
            settings: const AppSettings(reminderHour: 99),
          ),
        ),
        throwsFormatException,
      );
      expect((await repository.load()).parcels, isEmpty);
      final result = await app.importSnapshot(AppSnapshot(parcels: [parcel]));
      expect(result.added, 1);
      expect(app.parcels.length, 1);
      expect(app.error, contains('备份已导入'));
    });
    test('撤销恢复准确已取时间，未被改为当前时间', () async {
      final parcel = Parcel(
        id: 'time',
        station: '竹林',
        code: '1-2',
        arrivedAt: DateTime(2026, 1, 1),
        collectedAt: DateTime(2026, 1, 2, 12, 30),
      );
      await repository.putParcel(parcel);
      await repository.setCollected(['time'], false);
      await repository.restoreCollectionState([parcel]);
      expect(
        (await repository.load()).parcels.single.collectedAt,
        parcel.collectedAt,
      );
    });
    test('跨日跨月200条批量已取、撤销及回收站，没有商业额度', () async {
      final records = List.generate(
        200,
        (i) => Parcel(
          id: 'p$i',
          station: '站点${i % 4}',
          code: '16-$i',
          arrivedAt: DateTime(2026, 1, 1).add(Duration(days: i)),
          source: 'sms',
          sourceKey: 'sms:sender:$i:body',
        ),
      );
      final imported = await repository.merge(AppSnapshot(parcels: records));
      expect(imported.added, 200);
      await repository.setCollected(records.map((p) => p.id), true);
      var snapshot = await repository.load();
      expect(snapshot.parcels.where((p) => p.isCollected).length, 200);
      expect(
        snapshot.parcels.every(
          (p) => p.collectedAt!.millisecondsSinceEpoch > 0,
        ),
        true,
      );
      await repository.setCollected(['p0', 'p199'], false);
      await repository.setDeleted(['p0'], true);
      snapshot = await repository.load();
      expect(snapshot.parcels.where((p) => !p.isCollected).length, 2);
      expect(
        snapshot.parcels.singleWhere((p) => p.id == 'p0').deletedAt,
        isNotNull,
      );
      await repository.setDeleted(['p0'], false);
      snapshot = await repository.load();
      expect(snapshot.parcels.every((p) => p.deletedAt == null), true);
    });
    test('重复备份不重复入库，保留静态码、规则、站点顺序与时间', () async {
      final original = AppSnapshot(
        parcels: [
          Parcel(
            id: 'old',
            station: '竹林',
            code: '9-9',
            arrivedAt: DateTime(2026, 1, 1),
            collectedAt: DateTime(2026, 1, 2),
            sourceKey: 'sms:a:1:b',
          ),
        ],
        codes: [
          SavedCode(
            id: 'c',
            label: '自用码',
            value: 'test-123',
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
        rules: const [
          RecognitionRule(
            id: 'r',
            kind: 'address',
            pattern: '林',
            replacement: '竹林',
          ),
        ],
        settings: const AppSettings(
          stationOrder: ['竹林'],
          widgetShowCodes: false,
        ),
      );
      final decoded = AppSnapshot.fromMap(
        jsonDecode(original.toJson()) as Map<String, dynamic>,
      );
      await repository.merge(decoded);
      final again = await repository.merge(decoded);
      expect(again.added, 0);
      expect(again.duplicates, 1);
      final restored = await repository.load();
      expect(restored.parcels.length, 1);
      expect(restored.codes.single.value, 'test-123');
      expect(restored.rules.single.pattern, '林');
      expect(restored.settings.stationOrder, ['竹林']);
      expect(restored.settings.widgetShowCodes, false);
      expect(restored.parcels.single.collectedAt, DateTime(2026, 1, 2));
      final sameSource = await repository.merge(
        AppSnapshot(
          parcels: [original.parcels.single.copyWith(id: 'different')],
          settings: original.settings,
        ),
      );
      expect(sameSource.duplicates, 1);
    });
  });
}

class TestPlatformServices extends PlatformServices {
  final shares = <Map<String, dynamic>>[];
  bool failAckOnce = false, failReminders = false;
  @override
  Future<Map<String, dynamic>?> consumeSharedImport() async =>
      shares.isEmpty ? null : shares.first;
  @override
  Future<void> ackSharedImport(String id) async {
    if (failAckOnce) {
      failAckOnce = false;
      throw StateError('temporary ack error');
    }
    shares.removeWhere((s) => s['draftId'] == id);
  }

  @override
  Future<void> refreshWidgets() async {}
  @override
  Future<void> scheduleReminders(AppSettings settings) async {
    if (failReminders) throw StateError('notification permission denied');
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:easy_pickup/core/models.dart';
import 'package:easy_pickup/core/parser.dart';
import 'package:easy_pickup/core/import_review.dart';
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
        expect(result?.detailAddress, c['detailAddress'] ?? '');
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
  test('批量文字区分通知、换行正文和未识别片段', () {
    const a = '【韵达快递】凭A13-1-2030到重庆理工大学快递服务中心取尾号5397包裹';
    const b = '【京东快递】取件码A3-2-2048，您的快件已送达花溪京东校园服务站。';
    expect(splitImportText('$a$b'), [a, b]);
    expect(splitImportText('待整理的文字\n$a\n$b'), ['待整理的文字', a, b]);
    expect(splitImportText('$a\n无法判断的内容\n$b'), [a, '无法判断的内容', b]);
    const multiline = '【圆通速递】\n包裹已到北门快递服务中心\n取件码：\nA13 - 1 - 2030\n请及时领取。';
    expect(splitImportText(multiline), [multiline]);
    expect(splitImportText('$multiline\n$b'), [multiline, b]);
    const multilineAddress =
        '【京东快递】取件码4-301，快件已送达南门校园服务站。\n详细地址：重庆巴南区\n李家沱街道红光大道69号\n联系电话13800138000，取件请提前核对。';
    expect(splitImportText(multilineAddress), [multilineAddress]);
    expect(
      parseParcelText(splitImportText(multilineAddress).single)?.detailAddress,
      '重庆巴南区李家沱街道红光大道69号',
    );
    const fullWidth = '【邮政快递】\n取件码：\n5－06－2018\n包裹已送达南门校园服务站';
    expect(splitImportText(fullWidth), [fullWidth]);
    const codeFirst = '取件码：3-303\n包裹已送达南门校园服务站';
    expect(splitImportText(codeFirst), [codeFirst]);
    const first = '包裹已到东门驿站，取件码1-101。';
    const second = '包裹已到西门驿站，取件码2-202。';
    expect(splitImportText('$first$second'), [first, second]);
    expect(splitImportText('$first\n未识别内容\n$second'), [first, '未识别内容', second]);
    expect(splitImportText('$first\n9999\n$second'), [first, '9999', second]);
    expect(splitImportText('$first\n取件码？？\n$second'), [first, '取件码？？', second]);
    final joined = splitImportText('包裹已到东门驿站，取件码1-101，包裹已到西门驿站，取件码2-202');
    expect(joined.map((s) => parseParcelText(s)?.code), ['1-101', '2-202']);
    expect(joined.map((s) => parseParcelText(s)?.station), ['东门驿站', '西门驿站']);
    final joinedCodeFirst = splitImportText(
      '取件码1-101，包裹已到东门驿站，取件码2-202，包裹已到西门驿站',
    );
    expect(joinedCodeFirst.map((s) => parseParcelText(s)?.code), [
      '1-101',
      '2-202',
    ]);
    expect(joinedCodeFirst.map((s) => parseParcelText(s)?.station), [
      '东门驿站',
      '西门驿站',
    ]);
    expect(splitImportText('  \n\n '), isEmpty);
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
  test('跨来源相似记录可核对，站点、包裹尾号和时间各自区分', () {
    const body =
        '【京东快递】取件码A3-2-2048，您的快件尾号9127已送达重庆理工大学花溪京东校园服务站，地址：重庆巴南区李家沱街道红光大道69号，取件和寄件可咨询 3.cn/3-7nrNp7';
    final now = DateTime(2026, 10, 25);
    final original = reviewImport(body, existing: [], now: now).single.parcel!;
    expect(original.detailAddress, '重庆巴南区李家沱街道红光大道69号');
    final copy = reviewImport(
      body.replaceAll('，', '，\n'),
      existing: [original],
      now: now,
    );
    expect(copy.single.duplicate?.id, original.id);
    expect(
      reviewImport(
        body.replaceFirst('9127', '1234'),
        existing: [original],
        now: now,
      ).single.duplicate,
      isNull,
    );
    expect(
      reviewImport(
        body.replaceAll('花溪京东校园服务站', '北门菜鸟驿站'),
        existing: [original],
        now: now,
      ).single.duplicate,
      isNull,
    );
    expect(
      reviewImport(
        body,
        existing: [
          original.copyWith(arrivedAt: now.subtract(const Duration(days: 8))),
        ],
        now: now,
      ).single.duplicate,
      isNull,
    );
    final old = original.copyWith(
      station: '待确认站点',
      detailAddress: '',
      collectedAt: now,
      source: 'sms',
      sourceKey: 'sms:retained',
    );
    final complete = completeNoticeMetadata(old, const [])!;
    expect(complete.station, '重庆理工大学花溪京东校园服务站');
    expect(complete.detailAddress, original.detailAddress);
    expect(complete.id, old.id);
    expect(complete.sourceKey, old.sourceKey);
    expect(complete.collectedAt, old.collectedAt);
    expect(
      completeNoticeMetadata(old.copyWith(source: 'manual'), const []),
      isNull,
    );
    expect(
      completeNoticeMetadata(
        original.copyWith(detailAddress: '', source: 'sms'),
        const [],
      ),
      isNull,
    );
    const phoneFirst = '手机尾号5397，包裹尾号9127，已到东门驿站，取件码1-101。';
    final first = reviewImport(
      phoneFirst,
      existing: [],
      now: now,
    ).single.parcel!;
    expect(
      reviewImport(
        phoneFirst.replaceFirst('9127', '1234'),
        existing: [first],
        now: now,
      ).single.duplicate,
      isNull,
    );
  });
  test('反馈邮箱和中文草稿URI保持内容', () {
    const message = '型号：手机 A\n系统：Android 16\n取件码 A1+2 & B';
    final uri = AppController.feedbackUri(message);
    expect(uri.path, 'wmiles98@163.com');
    expect(uri.queryParameters['body'], message);
    expect(uri.queryParameters['subject'], contains(AppController.appVersion));
  });
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
      final result = await app.importSnapshot(
        AppSnapshot(
          parcels: [parcel],
          settings: const AppSettings(reminderEnabled: true),
        ),
      );
      expect(result.added, 1);
      expect(app.parcels.length, 1);
      expect(app.error, contains('备份已导入'));
      expect(app.settings.reminderEnabled, false);
      platform.failReminders = false;
      await app.updateSettings(app.settings.copyWith(reminderEnabled: true));
      expect(platform.reminderCalls, 2);
      expect(app.settings.reminderEnabled, true);
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
    test('跨日跨月200条批量已取、撤销及回收站', () async {
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
  int reminderCalls = 0;
  @override
  Future<bool> requestNotifications() async => true;
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
    reminderCalls++;
    if (failReminders) throw StateError('notification permission denied');
  }
}

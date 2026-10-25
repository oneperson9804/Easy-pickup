import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barcode_widget/barcode_widget.dart' show Barcode;
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/platform_services.dart';
import 'models.dart';
import 'import_review.dart';
import 'repository.dart';

class AppController extends ChangeNotifier {
  AppController({required ParcelRepository repository, required this.platform})
    : _repository = repository;
  static const repositoryUrl = 'https://github.com/oneperson9804/Easy-pickup';
  static const appVersion = '1.1.0';
  static const feedbackEmail = 'oneperson9823@gmail.com';
  final ParcelRepository _repository;
  final PlatformServices platform;
  AppSnapshot _snapshot = const AppSnapshot();
  bool busy = false;
  String? error;
  String? sharedText;
  String? failedSharedImportId;
  Future<void> _reloadQueue = Future<void>.value();
  Future<void> clearSharedText() async {
    await _repository.saveDraft(null);
    sharedText = null;
    await reload();
  }

  Future<void> saveImportDraft(String? text) async {
    final value = text == null || text.trim().isEmpty ? null : text.trim();
    await _repository.saveDraft(value);
    sharedText = value;
    notifyListeners();
  }

  Future<void> discardIncomingShare() async {
    final id = failedSharedImportId;
    if (id != null) await platform.ackSharedImport(id);
    failedSharedImportId = null;
    error = null;
    await reload();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  List<Parcel> get parcels =>
      _snapshot.parcels.where((p) => p.deletedAt == null).toList();
  List<Parcel> get pending => parcels.where((p) => !p.isCollected).toList();
  List<Parcel> get collected => parcels.where((p) => p.isCollected).toList();
  List<Parcel> get trash =>
      _snapshot.parcels.where((p) => p.deletedAt != null).toList();
  List<SavedCode> get codes => _snapshot.codes;
  List<RecognitionRule> get rules => _snapshot.rules;
  AppSettings get settings => _snapshot.settings;

  static Future<AppController> create() async {
    final platform = PlatformServices();
    final repository = await ParcelRepository.open(platform);
    final controller = AppController(
      repository: repository,
      platform: platform,
    );
    await controller.reload();
    platform.setRecordsChangedCallback(() async {
      try {
        await controller.reload();
      } catch (exception) {
        controller.error = '记录刷新失败：$exception';
        controller.notifyListeners();
      }
    });
    return controller;
  }

  Future<void> reload() {
    final operation = _reloadQueue.then((_) => _reload());
    _reloadQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _reload() async {
    _snapshot = await _repository.load();
    var completed = false;
    for (final parcel in _snapshot.parcels) {
      final next = completeNoticeMetadata(parcel, _snapshot.rules);
      if (next != null) {
        await _repository.putParcel(next);
        completed = true;
      }
    }
    if (completed) {
      _snapshot = await _repository.load();
      try {
        await platform.refreshWidgets();
      } catch (exception) {
        error = '记录已整理，小组件刷新失败：$exception';
      }
    }
    sharedText = await _repository.loadDraft();
    // A second share stays queued until the visible draft is confirmed/ignored.
    if (sharedText != null) {
      if (failedSharedImportId != null) {
        try {
          await platform.ackSharedImport(failedSharedImportId!);
          failedSharedImportId = null;
          error = null;
        } catch (exception) {
          error = '草稿已保存，临时图片尚未清理：$exception';
        }
      }
      notifyListeners();
      return;
    }
    try {
      while (sharedText == null) {
        final incoming = await platform.consumeSharedImport();
        if (incoming == null) break;
        final id = incoming['draftId'] as String?;
        if (id == null || id.isEmpty) throw const FormatException('分享草稿缺少标识');
        failedSharedImportId = id;
        if (id == await _repository.lastSharedId()) {
          await platform.ackSharedImport(id);
          failedSharedImportId = null;
          continue;
        }
        final text = incoming['text'] as String? ?? '';
        final imagePaths = <String>[
          if (incoming['imagePath'] case final String path) path,
          ...((incoming['imagePaths'] as List?)?.cast<String>() ??
              const <String>[]),
        ];
        final imageTexts = <String>[];
        for (final path in imagePaths) {
          final recognized = await _recognizeImage(path);
          if (recognized.trim().isEmpty) {
            throw const FormatException('有图片未识别出文字，原图片已保留，可重试或重新分享清晰图片');
          }
          imageTexts.add(recognized);
        }
        final draft = [
          if (text.trim().isNotEmpty) text,
          ...imageTexts,
        ].join('\n\n');
        if (draft.isNotEmpty) {
          await _repository.saveDraft(draft, incomingId: id);
          sharedText = draft;
          await platform.ackSharedImport(id);
          failedSharedImportId = null;
        } else {
          throw const FormatException('没有识别到文字，可重试、忽略或手动添加');
        }
      }
    } catch (exception) {
      error = '分享草稿已保留，暂时无法完成处理：$exception';
    }
    notifyListeners();
  }

  Future<void> _changed() async {
    await reload();
    try {
      await platform.refreshWidgets();
    } on PlatformException catch (e) {
      error = '记录已保存，小组件刷新失败：${e.message ?? e.code}';
      notifyListeners();
    }
  }

  Future<void> addParcel(Parcel parcel) async {
    _validateParcel(parcel);
    await _repository.putParcel(parcel);
    await _changed();
  }

  Future<void> updateParcel(Parcel parcel) => addParcel(parcel);
  void _validateParcel(Parcel parcel) {
    if (parcel.station.trim().isEmpty) {
      throw const FormatException('请填写站点');
    }
  }

  Future<void> markCollected(Iterable<String> ids, bool collected) async {
    await _repository.setCollected(ids, collected);
    await _changed();
  }

  Future<void> restoreCollectionState(List<Parcel> previous) async {
    await _repository.restoreCollectionState(previous);
    await _changed();
  }

  Future<void> removeParcels(Iterable<String> ids) async {
    await _repository.setDeleted(ids, true);
    await _changed();
  }

  Future<void> restoreParcels(Iterable<String> ids) async {
    await _repository.setDeleted(ids, false);
    await _changed();
  }

  Future<void> emptyTrash() async {
    await _repository.emptyTrash();
    await _changed();
  }

  Future<void> saveCode(SavedCode code) async {
    _validateCode(code);
    await _repository.putCode(code);
    await reload();
  }

  void _validateCode(SavedCode code) {
    if (code.label.trim().isEmpty || code.value.trim().isEmpty) {
      throw const FormatException('名称和码内容不能为空');
    }
    if (code.format != 'qr' && code.format != 'code128') {
      throw const FormatException('请选择二维码或条形码');
    }
    (code.format == 'qr' ? Barcode.qrCode() : Barcode.code128()).verify(
      code.value,
    );
  }

  Future<void> deleteCode(String id) async {
    await _repository.deleteCode(id);
    await reload();
  }

  Future<void> saveRule(RecognitionRule rule) async {
    if (!['address', 'company'].contains(rule.kind) ||
        rule.pattern.trim().isEmpty ||
        rule.replacement.trim().isEmpty) {
      throw const FormatException('请填写匹配文字和识别结果');
    }
    await _repository.putRule(rule);
    await reload();
  }

  Future<void> deleteRule(String id) async {
    await _repository.deleteRule(id);
    await reload();
  }

  Future<void> updateSettings(AppSettings next) async {
    _validateSettings(next);
    final reminderChanged =
        next.reminderEnabled != settings.reminderEnabled ||
        next.reminderHour != settings.reminderHour ||
        next.reminderMinute != settings.reminderMinute ||
        !listEquals(next.reminderWeekdays, settings.reminderWeekdays);
    if (reminderChanged) {
      if (next.reminderEnabled && !await platform.requestNotifications()) {
        throw StateError('通知权限未开启，请在系统设置中允许后再启用提醒');
      }
      await platform.scheduleReminders(next);
    }
    await _repository.putSettings(next);
    await _changed();
  }

  void _validateSettings(AppSettings next) {
    if (next.reminderHour < 0 ||
        next.reminderHour > 23 ||
        next.reminderMinute < 0 ||
        next.reminderMinute > 59 ||
        next.smsLookbackDays < 1 ||
        next.reminderWeekdays.any((d) => d < 1 || d > 7) ||
        !['system', 'light', 'dark'].contains(next.themeMode) ||
        !['arrival', 'codeAsc', 'codeDesc'].contains(next.sortMode) ||
        !['jade', 'ivory'].contains(next.widgetStyle) ||
        !next.widgetOpacity.isFinite ||
        next.widgetOpacity < .18 ||
        next.widgetOpacity > .9) {
      throw const FormatException('提醒时间或短信导入范围不正确');
    }
    if (next.reminderEnabled && next.reminderWeekdays.isEmpty) {
      throw const FormatException('请选择至少一个提醒日');
    }
  }

  Future<ImportResult> importText(
    String text, {
    String source = 'paste',
  }) async {
    final old = await _repository.load();
    final preview = reviewImport(
      text,
      existing: old.parcels,
      rules: rules,
      source: source,
    );
    final additions = <Parcel>[];
    var duplicates = 0, unrecognized = 0;
    for (final item in preview) {
      if (item.parcel == null) {
        unrecognized++;
        continue;
      }
      if (item.duplicate != null) {
        duplicates++;
        continue;
      }
      additions.add(item.parcel!);
    }
    if (additions.isNotEmpty) {
      await _repository.merge(
        AppSnapshot(parcels: additions, settings: settings),
      );
      await _changed();
    }
    return ImportResult(
      added: additions.length,
      duplicates: duplicates,
      unrecognized: unrecognized,
    );
  }

  List<ImportCandidate> previewImport(String text, {String source = 'paste'}) =>
      reviewImport(
        text,
        existing: _snapshot.parcels,
        rules: rules,
        source: source,
      );

  Future<int> importReviewed(List<Parcel> selected, String remaining) async {
    for (final parcel in selected) {
      _validateParcel(parcel);
    }
    final result = await _repository.merge(
      AppSnapshot(parcels: selected, settings: settings),
    );
    await saveImportDraft(remaining);
    await _changed();
    return result.added;
  }

  Future<ImportResult> importSms() async {
    if (!await platform.requestSms()) {
      throw StateError('短信权限未开启，仍可使用粘贴、截图或手动添加');
    }
    final result = await platform.importSms(
      DateTime.now().subtract(Duration(days: settings.smsLookbackDays)),
    );
    await reload();
    return result;
  }

  Future<bool> exportBackup() async {
    final snapshot = await _repository.load();
    final bytes = Uint8List.fromList(utf8.encode(snapshot.toJson()));
    final name =
        'easy-pickup-${DateTime.now().toIso8601String().substring(0, 10)}.json';
    final result = await FilePicker.platform.saveFile(
      dialogTitle: '保存易取件备份',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    return result != null;
  }

  Future<ImportResult?> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择易取件备份',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null) return null;
    final bytes = result.files.single.bytes;
    if (bytes == null) throw StateError('无法读取所选文件');
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份内容不是有效对象');
    }
    final snapshot = AppSnapshot.fromMap(decoded);
    return importSnapshot(snapshot);
  }

  Future<ImportResult> importSnapshot(AppSnapshot snapshot) async {
    _validateSettings(snapshot.settings);
    for (final parcel in snapshot.parcels) {
      _validateParcel(parcel);
    }
    for (final code in snapshot.codes) {
      _validateCode(code);
    }
    for (final rule in snapshot.rules) {
      if (!['address', 'company'].contains(rule.kind) ||
          rule.pattern.trim().isEmpty ||
          rule.replacement.trim().isEmpty) {
        throw const FormatException('备份中有无效的识别规则');
      }
    }
    final merged = await _repository.merge(snapshot);
    await _changed();
    // Record import succeeds independently of OS notification availability.
    // Restored reminders can be enabled later from settings without reimporting.
    try {
      await platform.scheduleReminders(snapshot.settings);
    } catch (exception) {
      await _repository.putSettings(
        snapshot.settings.copyWith(reminderEnabled: false),
      );
      await reload();
      error = '备份已导入；取件提醒未恢复，请检查通知权限后重新设置：$exception';
      notifyListeners();
    }
    return merged;
  }

  Future<String?> recognizeScreenshot() async {
    if (kIsWeb) throw UnsupportedError('请在 Android 或 iOS App 中使用本机截图识别');
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty) return null;
    final parts = <String>[];
    var failed = 0;
    for (final image in picked) {
      try {
        final text = await _recognizeImage(image.path);
        if (text.trim().isNotEmpty) {
          parts.add(text);
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
    }
    if (parts.isEmpty) throw StateError('图片中未能识别出文字，请检查清晰度后重试');
    if (failed > 0) {
      error = '$failed 张图片未能识别出文字，请单独检查后重新选择';
      notifyListeners();
    }
    return parts.join('\n\n');
  }

  Future<String> _recognizeImage(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    try {
      return (await recognizer.processImage(
        InputImage.fromFilePath(path),
      )).text;
    } finally {
      await recognizer.close();
    }
  }

  Future<void> shareParcels(
    List<Parcel> selected, {
    bool asImage = false,
  }) async {
    if (selected.isEmpty) throw StateError('请先选择要分享的取件信息');
    final text = selected
        .map(
          (p) =>
              '${p.station}${p.detailAddress.isEmpty ? '' : '\n${p.detailAddress}'}\n取件码：${p.code}${p.company.isEmpty ? '' : ' · ${p.company}'}',
        )
        .join('\n\n');
    if (!asImage) {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          title: '取件信息',
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
        ),
      );
      return;
    }
    final files = <XFile>[];
    for (var start = 0; start < selected.length; start += 8) {
      final rows = selected.skip(start).take(8).toList();
      const width = 1000.0;
      final height = 200.0 + rows.length * 190;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xfff1f7f7), BlendMode.src);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width, 16),
        Paint()..color = const Color(0xff147d88),
      );
      void paintText(
        String value,
        double x,
        double y,
        double size,
        Color color, {
        int maxLines = 2,
      }) {
        final painter = TextPainter(
          text: TextSpan(
            text: value,
            style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: maxLines,
          ellipsis: '…',
        )..layout(maxWidth: width - x * 2);
        painter.paint(canvas, Offset(x, y));
      }

      paintText('取件信息', 60, 55, 42, const Color(0xff147d88));
      for (var i = 0; i < rows.length; i++) {
        final p = rows[i];
        final y = 150.0 + i * 190;
        paintText(p.station, 60, y, 28, const Color(0xff435d53), maxLines: 1);
        paintText(p.code, 60, y + 46, 48, const Color(0xff172d28), maxLines: 1);
        paintText(
          [p.company, p.detailAddress].where((s) => s.isNotEmpty).join(' · '),
          60,
          y + 108,
          22,
          const Color(0xff56685e),
          maxLines: 2,
        );
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('未能生成取件图片');
      files.add(
        XFile.fromData(data.buffer.asUint8List(), mimeType: 'image/png'),
      );
      image.dispose();
      picture.dispose();
    }
    await SharePlus.instance.share(
      ShareParams(
        files: files,
        fileNameOverrides: List.generate(
          files.length,
          (i) => '取件信息-${i + 1}.png',
        ),
        title: '取件信息',
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
      ),
    );
  }

  Future<Map<String, dynamic>> checkUpdates() async {
    final response = await http
        .get(
          Uri.parse(
            'https://api.github.com/repos/oneperson9804/Easy-pickup/releases/latest',
          ),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 404) {
      return {
        'hasUpdate': false,
        'version': appVersion,
        'url': '$repositoryUrl/releases',
        'message': '当前版本 $appVersion，暂无新的正式版本',
      };
    }
    if (response.statusCode != 200) {
      throw StateError('检查更新失败（HTTP ${response.statusCode}），稍后重试或打开源码仓库');
    }
    final release = jsonDecode(response.body) as Map<String, dynamic>;
    final version = (release['tag_name'] as String).replaceFirst(
      RegExp(r'^v'),
      '',
    );
    final hasUpdate = _compareVersions(version, appVersion) > 0;
    return {
      'hasUpdate': hasUpdate,
      'version': version,
      'url': '$repositoryUrl/releases',
      'message': hasUpdate ? '发现新版本 $version' : '已是最新正式版本 $appVersion',
    };
  }

  int _compareVersions(String a, String b) {
    final aa = a
        .split('.')
        .map((s) => int.tryParse(s.split('-').first) ?? 0)
        .toList();
    final bb = b
        .split('.')
        .map((s) => int.tryParse(s.split('-').first) ?? 0)
        .toList();
    for (var i = 0; i < 3; i++) {
      final diff = (i < aa.length ? aa[i] : 0).compareTo(
        i < bb.length ? bb[i] : 0,
      );
      if (diff != 0) return diff;
    }
    return 0;
  }

  Future<void> _open(String url) async {
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      throw StateError('未能打开浏览器，请稍后重试');
    }
  }

  static Uri feedbackUri(String message) => Uri(
    scheme: 'mailto',
    path: feedbackEmail,
    query:
        'subject=${Uri.encodeComponent('易取件 $appVersion 使用反馈')}'
        '&body=${Uri.encodeComponent(message)}',
  );

  Future<bool> openFeedback({String message = ''}) =>
      launchUrl(feedbackUri(message), mode: LaunchMode.externalApplication);
  Future<void> openRepository() => _open(repositoryUrl);

  @override
  void dispose() {
    platform.setRecordsChangedCallback(null);
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/models.dart';

enum OfficialLaunchStatus { app, unavailable }

class OfficialLaunchResult {
  const OfficialLaunchResult(this.status, {this.reason});
  final OfficialLaunchStatus status;
  final String? reason;
  bool get opened => status == OfficialLaunchStatus.app;
}

class PlatformServices {
  static const channel = MethodChannel('easy_pickup/platform');
  void setRecordsChangedCallback(Future<void> Function()? callback) {
    channel.setMethodCallHandler(
      callback == null
          ? null
          : (call) async {
              if (call.method == 'recordsChanged') await callback();
            },
    );
  }

  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  Future<String> databasePath() async {
    final path = await channel.invokeMethod<String>('getDatabasePath');
    if (path == null || path.isEmpty) throw StateError('未能打开本机存储');
    return path;
  }

  Future<Map<String, dynamic>?> consumeSharedImport() async {
    if (kIsWeb) return null;
    return await channel.invokeMapMethod<String, dynamic>(
      'consumeSharedImport',
    );
  }

  Future<void> ackSharedImport(String id) async {
    if (!kIsWeb) {
      await channel.invokeMethod<void>('ackSharedImport', {'draftId': id});
    }
  }

  Future<Map<String, dynamic>> getPermissions() async {
    if (kIsWeb) {
      return {
        'platform': 'web',
        'readSms': false,
        'receiveSms': false,
        'notifications': false,
        'camera': false,
        'widgetSupported': false,
        'widgetStatus': '浏览器预览不提供系统短信和桌面小组件',
      };
    }
    return Map<String, dynamic>.from(
      await channel.invokeMapMethod<String, dynamic>('getPermissions') ?? {},
    );
  }

  Future<bool> requestSms() async {
    if (!isAndroid) return false;
    return await channel.invokeMethod<bool>('requestSms') ?? false;
  }

  Future<ImportResult> importSms(DateTime since) async {
    if (!isAndroid) throw UnsupportedError('当前平台请使用粘贴、截图或手动添加');
    return ImportResult.fromMap(
      await channel.invokeMapMethod<String, dynamic>('importSms', {
            'sinceMs': since.millisecondsSinceEpoch,
          }) ??
          {},
    );
  }

  Future<bool> requestNotifications() async =>
      !kIsWeb &&
      (await channel.invokeMethod<bool>('requestNotifications') ?? false);
  Future<bool> pinWidget() async =>
      !kIsWeb && (await channel.invokeMethod<bool>('pinWidget') ?? false);
  Future<void> openSettings() async {
    if (!kIsWeb) await channel.invokeMethod<void>('openSettings');
  }

  Future<OfficialLaunchResult> openOfficial(String id) async {
    if (kIsWeb) {
      return const OfficialLaunchResult(OfficialLaunchStatus.unavailable);
    }
    final result = await channel.invokeMapMethod<String, dynamic>(
      'openOfficial',
      {'id': id},
    );
    return OfficialLaunchResult(
      result?['status'] == 'app'
          ? OfficialLaunchStatus.app
          : OfficialLaunchStatus.unavailable,
      reason: result?['reason'] as String?,
    );
  }

  Future<void> refreshWidgets() async {
    if (!kIsWeb) await channel.invokeMethod<void>('refreshWidgets');
  }

  Future<void> scheduleReminders(AppSettings settings) async {
    if (kIsWeb) {
      if (settings.reminderEnabled) throw UnsupportedError('浏览器预览不支持定时提醒');
      return;
    }
    await channel.invokeMethod<void>('scheduleReminders', {
      'enabled': settings.reminderEnabled,
      'hour': settings.reminderHour,
      'minute': settings.reminderMinute,
      'weekdays': settings.reminderWeekdays,
    });
  }
}

import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/models.dart';

void notice(BuildContext context, String message, {SnackBarAction? action}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: action,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<void> runTask(
  BuildContext context,
  Future<dynamic> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (success != null && context.mounted) notice(context, success);
  } catch (error) {
    if (context.mounted) {
      notice(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String body, {
  String accept = '确认',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(accept),
          ),
        ],
      ),
    ) ??
    false;

String dayLabel(DateTime value, {bool year = false}) =>
    '${year ? '${value.year}年' : ''}${value.month}月${value.day}日';
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String dateTimeLabel(DateTime value) =>
    '${dayLabel(value, year: true)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

Future<void> markWithUndo(
  BuildContext context,
  AppController app,
  List<Parcel> parcels,
  bool collected,
) async {
  if (parcels.isEmpty) return;
  try {
    final ids = parcels.map((p) => p.id).toList();
    await app.markCollected(ids, collected);
    if (!context.mounted) return;
    notice(
      context,
      collected ? '已将 ${ids.length} 件标记为已取' : '已恢复 ${ids.length} 件待取记录',
      action: SnackBarAction(
        label: '撤销',
        onPressed: () =>
            runTask(context, () => app.restoreCollectionState(parcels)),
      ),
    );
  } catch (error) {
    if (context.mounted) {
      notice(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }
}

Future<void> removeWithUndo(
  BuildContext context,
  AppController app,
  List<Parcel> parcels,
) async {
  if (!await confirm(
    context,
    '移入回收站？',
    '${parcels.length} 条记录将从取件列表移除，可在设置的回收站中恢复。',
    accept: '移入回收站',
  )) {
    return;
  }
  if (!context.mounted) return;
  await runTask(context, () async {
    final ids = parcels.map((p) => p.id).toList();
    await app.removeParcels(ids);
    if (context.mounted) {
      notice(
        context,
        '已移入回收站',
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => runTask(context, () => app.restoreParcels(ids)),
        ),
      );
    }
  });
}

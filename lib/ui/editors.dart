import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_controller.dart';
import '../core/models.dart';
import 'actions.dart';

bool get supportsSms =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Future<void> showAddMenu(BuildContext context, AppController app) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '添加取件',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            ListTile(
              key: const ValueKey('add-manual'),
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text('手动填写'),
              subtitle: const Text('填写站点和取件码'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
            ListTile(
              key: const ValueKey('add-paste'),
              leading: const Icon(Icons.content_paste_rounded),
              title: const Text('粘贴取件信息'),
              subtitle: const Text('从短信或聊天中复制文字后识别'),
              onTap: () => Navigator.pop(context, 'paste'),
            ),
            ListTile(
              key: const ValueKey('add-screenshot'),
              leading: const Icon(Icons.image_outlined),
              title: const Text('识别截图'),
              subtitle: const Text('选择图片，在本机识别取件信息'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            if (supportsSms)
              ListTile(
                key: const ValueKey('add-sms'),
                leading: const Icon(Icons.sms_outlined),
                title: const Text('导入短信'),
                subtitle: Text('识别近 ${app.settings.smsLookbackDays} 天的取件短信'),
                onTap: () => Navigator.pop(context, 'sms'),
              ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  switch (choice) {
    case 'manual':
      await editParcel(context, app);
      break;
    case 'paste':
      await importTextDialog(context, app);
      break;
    case 'image':
      await runTask(context, () async {
        final text = await app.recognizeScreenshot();
        if (text != null && context.mounted) {
          await importTextDialog(context, app, initial: text, source: 'ocr');
        }
      });
      break;
    case 'sms':
      await importSms(context, app);
      break;
  }
}

Future<void> importSms(
  BuildContext context,
  AppController app,
) => runTask(context, () async {
  final result = await app.importSms();
  if (context.mounted) {
    notice(
      context,
      '已保存 ${result.added} 件 · 重复 ${result.duplicates} 条 · 未识别 ${result.unrecognized} 条',
    );
  }
});

Future<void> importTextDialog(
  BuildContext context,
  AppController app, {
  String initial = '',
  String source = 'paste',
}) async {
  final text = TextEditingController(text: initial);
  final value = await showSettledDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(source == 'ocr' ? '检查识别文字' : '粘贴取件信息'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('可放入多条取件通知。请保留取件码与站点；识别后可继续编辑记录。'),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('import-text'),
                controller: text,
                minLines: 5,
                maxLines: 10,
                autofocus: initial.isEmpty,
                decoration: const InputDecoration(
                  hintText: '例如：您的快递已到青竹路菜鸟驿站，取件码 3-1024。',
                  labelText: '取件通知文字',
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) text.text = data!.text!;
                },
                icon: const Icon(Icons.content_paste_rounded),
                label: const Text('读取剪贴板'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('confirm-import'),
          onPressed: () {
            if (text.text.trim().isNotEmpty) {
              Navigator.pop(context, text.text.trim());
            }
          },
          child: const Text('识别并添加'),
        ),
      ],
    ),
  );
  text.dispose();
  if (value == null || !context.mounted) return;
  await runTask(context, () async {
    final result = await app.importText(value, source: source);
    if (source == 'share' &&
        result.unrecognized == 0 &&
        (result.added > 0 || result.duplicates > 0)) {
      await app.clearSharedText();
    }
    if (context.mounted) {
      notice(
        context,
        result.added == 0 && result.duplicates == 0
            ? '没有识别到取件信息，可选择手动填写。'
            : '已保存 ${result.added} 件 · 重复 ${result.duplicates} 条${result.unrecognized > 0 ? ' · ${result.unrecognized} 条未识别${source == 'share' ? '，分享草稿已保留' : '，可再次导入或手动填写'}' : ''}',
      );
    }
  });
}

Future<void> editParcel(
  BuildContext context,
  AppController app, {
  Parcel? parcel,
}) async {
  final form = GlobalKey<FormState>();
  final station = TextEditingController(text: parcel?.station ?? '');
  final code = TextEditingController(text: parcel?.code ?? '');
  final company = TextEditingController(text: parcel?.company ?? '');
  final raw = TextEditingController(text: parcel?.rawText ?? '');
  final detail = TextEditingController(text: parcel?.detailAddress ?? '');
  var arrived = parcel?.arrivedAt ?? DateTime.now();
  final saved = await showSettledDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(parcel == null ? '添加取件' : '编辑取件'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const ValueKey('parcel-station'),
                    controller: station,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '取件站点',
                      hintText: '例如：青竹路菜鸟驿站',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '请填写取件站点'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('parcel-code'),
                    controller: code,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '取件码',
                      hintText: '可稍后补充',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('parcel-company'),
                    controller: company,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: '快递公司（选填）'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('parcel-detail'),
                    controller: detail,
                    maxLines: 2,
                    minLines: 1,
                    decoration: const InputDecoration(
                      labelText: '详细位置（选填）',
                      hintText: '例如：东门旁二楼，靠右第3排',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: raw,
                    maxLines: 3,
                    minLines: 1,
                    decoration: const InputDecoration(labelText: '备注或原始通知（选填）'),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('到件日期'),
                    subtitle: Text(dayLabel(arrived, year: true)),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: () async {
                      final day = await showDatePicker(
                        context: context,
                        initialDate: arrived,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (day != null) {
                        setState(
                          () => arrived = DateTime(
                            day.year,
                            day.month,
                            day.day,
                            arrived.hour,
                            arrived.minute,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('save-parcel'),
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
  if (saved == true && context.mounted) {
    final value = Parcel(
      id: parcel?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      station: station.text.trim(),
      code: code.text.trim(),
      company: company.text.trim(),
      rawText: raw.text.trim(),
      detailAddress: detail.text.trim(),
      arrivedAt: arrived,
      collectedAt: parcel?.collectedAt,
      deletedAt: parcel?.deletedAt,
      source: parcel?.source ?? 'manual',
      sourceKey: parcel?.sourceKey,
    );
    await runTask(
      context,
      () => parcel == null ? app.addParcel(value) : app.updateParcel(value),
      success: parcel == null ? '已添加取件' : '记录已更新',
    );
  }
  station.dispose();
  code.dispose();
  company.dispose();
  raw.dispose();
  detail.dispose();
}

Future<void> showParcelDetails(
  BuildContext context,
  AppController app,
  Parcel parcel,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheetContext) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(parcel.station, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SelectableText(
              parcel.code.isEmpty ? '取件码待补充' : parcel.code,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            Text(
              '${parcel.company.isEmpty ? '快递公司未填写' : parcel.company} · ${dayLabel(parcel.arrivedAt, year: true)}到件',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (parcel.collectedAt != null)
              Text(
                '${dateTimeLabel(parcel.collectedAt!)} 已取',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (parcel.rawText.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text('原始通知 / 备注', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SelectableText(parcel.rawText),
            ],
            if (parcel.detailAddress.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('详细位置', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SelectableText(parcel.detailAddress),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    markWithUndo(context, app, [parcel], !parcel.isCollected);
                  },
                  icon: Icon(
                    parcel.isCollected
                        ? Icons.undo_rounded
                        : Icons.done_rounded,
                  ),
                  label: Text(parcel.isCollected ? '恢复为待取' : '标记已取'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: parcel.code));
                    notice(context, '已复制取件码');
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('复制'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    editParcel(context, app, parcel: parcel);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    runTask(context, () => app.shareParcels([parcel]));
                  },
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('分享'),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    removeWithUndo(context, app, [parcel]);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('移入回收站'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ),
);

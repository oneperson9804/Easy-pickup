import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide Barcode;

import '../core/app_controller.dart';
import '../core/models.dart';
import 'actions.dart';
import 'theme.dart';

class CodeWalletPage extends StatelessWidget {
  const CodeWalletPage({super.key, required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
    children: [
      Text('取件码夹', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 6),
      Text(
        '常用的码，随手可取。',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SectionTitle('官方取件入口', subtitle: '打开对应平台，动态身份码由官方提供'),
      LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _official(
              context,
              'cainiao_code',
              '菜鸟身份码',
              '菜鸟',
              Icons.grass_rounded,
              constraints.maxWidth,
            ),
            _official(
              context,
              'taobao_code',
              '淘宝身份码',
              '淘宝',
              Icons.shopping_bag_outlined,
              constraints.maxWidth,
            ),
            _official(
              context,
              'pinduoduo_code',
              '拼多多身份码',
              '拼多多',
              Icons.qr_code_rounded,
              constraints.maxWidth,
            ),
            _official(
              context,
              'pinduoduo_pickup',
              '拼多多待取件',
              '取件列表',
              Icons.inventory_2_outlined,
              constraints.maxWidth,
            ),
            _official(
              context,
              'jd_orders',
              '京东订单',
              '订单列表',
              Icons.local_shipping_outlined,
              constraints.maxWidth,
            ),
            _official(
              context,
              'taobao_orders',
              '淘宝订单',
              '订单列表',
              Icons.receipt_long_outlined,
              constraints.maxWidth,
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
        child: Text(
          '第三方平台可能需要登录自己的账号。易取件不会收集平台账号，也不会生成或保存官方动态身份码。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      SectionTitle(
        '我的静态码',
        subtitle: '${app.codes.length} 张保存在本机',
        trailing: IconButton(
          key: const ValueKey('add-saved-code'),
          tooltip: '添加静态码',
          onPressed: () => _addMenu(context),
          icon: const Icon(Icons.add_rounded),
        ),
      ),
      if (app.codes.isEmpty)
        Card(
          child: QuietEmpty(
            title: '收好常用的静态码',
            description: '扫描或从图片添加二维码、条码，也可以手动输入。动态身份码请使用上方官方入口。',
            action: OutlinedButton.icon(
              onPressed: () => _addMenu(context),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('添加静态码'),
            ),
            illustrated: false,
          ),
        )
      else
        ...app.codes.map(
          (code) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    code.format == 'qr'
                        ? Icons.qr_code_rounded
                        : Icons.barcode_reader,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  code.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  code.format == 'qr' ? '二维码 · 本地保存' : '条形码 · 本地保存',
                ),
                onTap: () => _showCode(context, code),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      editSavedCode(context, app, existing: code);
                    } else {
                      _delete(context, code);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _official(
    BuildContext context,
    String id,
    String title,
    String subtitle,
    IconData icon,
    double width,
  ) => SizedBox(
    width: (width - 10) / 2,
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => runTask(context, () async {
          final opened = await app.platform.openOfficial(id);
          if (!opened && context.mounted) {
            notice(context, '未能打开对应平台，请检查是否已安装官方 App。');
          }
        }),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _addMenu(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_scanner_rounded),
              title: const Text('扫码添加'),
              onTap: () => Navigator.pop(context, 'scan'),
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('从图片添加'),
                onTap: () => Navigator.pop(context, 'image'),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('手动输入'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'manual') {
      await editSavedCode(context, app);
      return;
    }
    if (choice == 'scan') {
      final value = await Navigator.of(context)
          .push<({String value, String format})>(
            MaterialPageRoute(builder: (_) => const ScanCodePage()),
          );
      if (value != null && context.mounted) {
        await editSavedCode(
          context,
          app,
          value: value.value,
          format: value.format,
        );
      }
      return;
    }
    await runTask(context, () async {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final scanner = MobileScannerController(autoStart: false);
      try {
        final result = await scanner.analyzeImage(image.path);
        final codes =
            result?.barcodes
                .where((b) => b.rawValue?.isNotEmpty == true)
                .toList() ??
            [];
        if (codes.isEmpty) throw Exception('没有识别到二维码或条码，请换一张更清晰的图片。');
        var code = codes.first;
        if (codes.length > 1 && context.mounted) {
          final selected = await showDialog<int>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('选择要添加的码'),
              children: [
                for (var i = 0; i < codes.length; i++)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, i),
                    child: Text(
                      codes[i].rawValue!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          );
          if (selected == null) return;
          code = codes[selected];
        }
        if (context.mounted) {
          await editSavedCode(
            context,
            app,
            value: code.rawValue!,
            format: code.format == BarcodeFormat.qrCode ? 'qr' : 'code128',
          );
        }
      } finally {
        await scanner.dispose();
      }
    });
  }

  Future<void> _delete(BuildContext context, SavedCode code) async {
    if (await confirm(
          context,
          '删除这张静态码？',
          '“${code.label}”将从本机移除。',
          accept: '删除',
        ) &&
        context.mounted) {
      await runTask(context, () => app.deleteCode(code.id), success: '已删除静态码');
    }
  }

  void _showCode(BuildContext context, SavedCode original) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ListenableBuilder(
            listenable: app,
            builder: (context, _) {
              final matches = app.codes
                  .where((item) => item.id == original.id)
                  .toList();
              final code = matches.isEmpty ? original : matches.first;
              return PageFrame(
                title: code.label,
                actions: [
                  IconButton(
                    tooltip: '编辑静态码',
                    onPressed: () =>
                        editSavedCode(context, app, existing: code),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 36),
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: BarcodeWidget(
                        barcode: code.format == 'qr'
                            ? Barcode.qrCode()
                            : Barcode.code128(),
                        data: code.value,
                        height: code.format == 'qr' ? 250 : 150,
                        drawText: false,
                        color: Colors.black,
                        errorBuilder: (_, message) => Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '此内容无法生成所选格式，请编辑为二维码。\n$message',
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      code.label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(code.value, textAlign: TextAlign.center),
                    const SizedBox(height: 22),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code.value));
                        notice(context, '已复制码内容');
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('复制内容'),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '这是保存在本机的静态码。请确认它仍然有效；官方动态身份码请从官方 App 打开。',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
}

Future<void> editSavedCode(
  BuildContext context,
  AppController app, {
  SavedCode? existing,
  String? value,
  String format = 'qr',
}) async {
  final name = TextEditingController(text: existing?.label ?? '');
  final content = TextEditingController(text: existing?.value ?? value ?? '');
  var selectedFormat = existing?.format ?? format;
  final form = GlobalKey<FormState>();
  final result = await showSettledDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(existing == null ? '添加静态码' : '编辑静态码'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const ValueKey('saved-code-label'),
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: '名称',
                      hintText: '例如：常用取件码',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '请给这张码起个名字'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('saved-code-value'),
                    controller: content,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: '码内容'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入码内容';
                      }
                      if (value.trim().length > 2000) {
                        return '码内容过长，请缩短到 2000 字符以内';
                      }
                      if (selectedFormat == 'code128') {
                        try {
                          Barcode.code128().verify(value.trim());
                        } catch (_) {
                          return '此内容不适合条形码，请改用二维码';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'qr',
                        label: Text('二维码'),
                        icon: Icon(Icons.qr_code_rounded),
                      ),
                      ButtonSegment(
                        value: 'code128',
                        label: Text('条形码'),
                        icon: Icon(Icons.view_week_outlined),
                      ),
                    ],
                    selected: {selectedFormat},
                    onSelectionChanged: (value) =>
                        setState(() => selectedFormat = value.first),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '保存前请确认内容。易取件不会自动打开扫描到的网址或执行其中的操作。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('save-code'),
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
  if (result == true && context.mounted) {
    await runTask(
      context,
      () => app.saveCode(
        SavedCode(
          id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
          label: name.text.trim(),
          value: content.text.trim(),
          format: selectedFormat,
          createdAt: existing?.createdAt ?? DateTime.now(),
        ),
      ),
      success: '静态码已保存',
    );
  }
  name.dispose();
  content.dispose();
}

class ScanCodePage extends StatefulWidget {
  const ScanCodePage({super.key});
  @override
  State<ScanCodePage> createState() => _ScanCodePageState();
}

class _ScanCodePageState extends State<ScanCodePage>
    with WidgetsBindingObserver {
  final scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool handled = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scanner.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !handled) {
      scanner.start();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      scanner.stop();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text('扫码添加'),
      actions: [
        IconButton(
          tooltip: '开关补光灯',
          onPressed: () => runTask(context, scanner.toggleTorch),
          icon: const Icon(Icons.flash_on_outlined),
        ),
      ],
    ),
    body: Stack(
      children: [
        MobileScanner(
          controller: scanner,
          onDetect: (capture) {
            if (handled) return;
            final found = capture.barcodes
                .where((b) => b.rawValue?.isNotEmpty == true)
                .toList();
            if (found.isEmpty) return;
            handled = true;
            scanner.stop();
            Navigator.pop(context, (
              value: found.first.rawValue!,
              format: found.first.format == BarcodeFormat.qrCode
                  ? 'qr'
                  : 'code128',
            ));
          },
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.no_photography_outlined,
                    color: Colors.white,
                    size: 42,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '无法使用相机。请检查相机权限，或返回后从图片、手动输入添加。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('返回'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Positioned(
          left: 24,
          right: 24,
          bottom: 40,
          child: SafeArea(
            child: Text(
              '对准需要保存的静态二维码或条码\n识别后会先预览，再由你确认保存',
              style: TextStyle(color: Colors.white, fontSize: 15, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    ),
  );
}

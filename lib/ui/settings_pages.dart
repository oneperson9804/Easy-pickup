import 'package:flutter/material.dart';
import '../core/app_controller.dart';
import '../core/models.dart';
import 'actions.dart';
import 'editors.dart';
import 'theme.dart';
import 'page_capture.dart';

void openPage(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: app,
    builder: (context, _) => PageFrame(
      title: '设置',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          const SectionTitle('外观与排列'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('外观主题'),
                  subtitle: Text(
                    {
                          'system': '跟随系统',
                          'light': '浅色',
                          'dark': '深色',
                        }[app.settings.themeMode] ??
                        '跟随系统',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _theme(context),
                ),
                const Divider(indent: 58),
                ListTile(
                  leading: const Icon(Icons.sort_rounded),
                  title: const Text('取件码排序'),
                  subtitle: Text(
                    {
                          'arrival': '按到件时间，新到优先',
                          'codeAsc': '取件码升序',
                          'codeDesc': '取件码降序',
                        }[app.settings.sortMode] ??
                        '按到件时间',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _sort(context),
                ),
                const Divider(indent: 58),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('站点顺序'),
                  subtitle: const Text('把常去的站点排在前面'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openPage(context, StationOrderPage(app: app)),
                ),
              ],
            ),
          ),
          const SectionTitle('识别与提醒'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('识别纠正规则'),
                  subtitle: Text('${app.rules.length} 条本地规则 · 站点与快递公司'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      openPage(context, RecognitionRulesPage(app: app)),
                ),
                if (supportsSms) ...[
                  const Divider(indent: 58),
                  ListTile(
                    leading: const Icon(Icons.screen_search_desktop_rounded),
                    title: const Text('识别平台页面'),
                    subtitle: const Text('选择平台，主动读取当前可见取件信息'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => openPage(context, const PageCapturePage()),
                  ),
                  const Divider(indent: 58),
                  ListTile(
                    leading: const Icon(Icons.sms_outlined),
                    title: const Text('短信导入范围'),
                    subtitle: Text('近 ${app.settings.smsLookbackDays} 天'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _range(context),
                  ),
                ],
                const Divider(indent: 58),
                ListTile(
                  leading: const Icon(Icons.notifications_none_rounded),
                  title: const Text('取件提醒'),
                  subtitle: Text(
                    app.settings.reminderEnabled
                        ? '${app.settings.reminderHour.toString().padLeft(2, '0')}:${app.settings.reminderMinute.toString().padLeft(2, '0')} · 每周 ${app.settings.reminderWeekdays.length} 天'
                        : '未开启',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openPage(context, ReminderPage(app: app)),
                ),
              ],
            ),
          ),
          const SectionTitle('本机数据'),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const ValueKey('export-backup'),
                  leading: const Icon(Icons.file_upload_outlined),
                  title: const Text('导出备份'),
                  subtitle: const Text('保存记录、码夹、规则和设置'),
                  onTap: () => runTask(context, () async {
                    final saved = await app.exportBackup();
                    if (saved && context.mounted) {
                      notice(context, '备份已导出，请妥善保存');
                    }
                  }),
                ),
                const Divider(indent: 58),
                ListTile(
                  key: const ValueKey('import-backup'),
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('导入备份 / 旧版数据'),
                  subtitle: const Text('选择易取件或迁移工具导出的 JSON'),
                  onTap: () => runTask(context, () async {
                    final result = await app.importBackup();
                    if (result == null) return;
                    if (context.mounted) {
                      notice(
                        context,
                        '导入完成 · 已保存 ${result.added} 条 · 重复 ${result.duplicates} 条',
                      );
                    }
                  }),
                ),
                const Divider(indent: 58),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('回收站'),
                  subtitle: Text('${app.trash.length} 条记录'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openPage(context, TrashPage(app: app)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '数据保存在本机。卸载应用可能删除本机记录，换机或卸载前请先导出备份。备份含取件码等信息，请只交给信任的人。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _theme(BuildContext context) async {
    final value = await _choose(context, '外观', app.settings.themeMode, const {
      'system': '跟随系统',
      'light': '浅色 · 灵青映金',
      'dark': '深色 · 玄青金雷',
    });
    if (value != null && context.mounted) {
      await runTask(
        context,
        () => app.updateSettings(app.settings.copyWith(themeMode: value)),
      );
    }
  }

  Future<void> _sort(BuildContext context) async {
    final value = await _choose(context, '取件码排序', app.settings.sortMode, const {
      'arrival': '到件时间 · 新到优先',
      'codeAsc': '取件码 · 数字升序',
      'codeDesc': '取件码 · 数字降序',
    });
    if (value != null && context.mounted) {
      await runTask(
        context,
        () => app.updateSettings(app.settings.copyWith(sortMode: value)),
      );
    }
  }

  Future<void> _range(BuildContext context) async {
    final value = await _choose(
      context,
      '短信导入范围',
      '${app.settings.smsLookbackDays}',
      const {'7': '近 7 天', '30': '近 30 天', '90': '近 90 天', '365': '近 1 年'},
    );
    if (value != null && context.mounted) {
      await runTask(
        context,
        () => app.updateSettings(
          app.settings.copyWith(smsLookbackDays: int.parse(value)),
        ),
      );
    }
  }
}

Future<String?> _choose(
  BuildContext context,
  String title,
  String current,
  Map<String, String> choices,
) => showDialog<String>(
  context: context,
  builder: (context) => SimpleDialog(
    title: Text(title),
    children: choices.entries
        .map(
          (entry) => SimpleDialogOption(
            onPressed: () => Navigator.pop(context, entry.key),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            child: Row(
              children: [
                Expanded(child: Text(entry.value)),
                if (current == entry.key)
                  Icon(
                    Icons.check_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ),
        )
        .toList(),
  ),
);

class StationOrderPage extends StatefulWidget {
  const StationOrderPage({super.key, required this.app});
  final AppController app;
  @override
  State<StationOrderPage> createState() => _StationOrderPageState();
}

class _StationOrderPageState extends State<StationOrderPage> {
  late final List<String> stations = {
    ...widget.app.settings.stationOrder,
    ...widget.app.parcels.map((p) => p.station),
  }.toList();
  @override
  Widget build(BuildContext context) => PageFrame(
    title: '站点顺序',
    actions: [
      TextButton(
        onPressed: () => runTask(context, () async {
          await widget.app.updateSettings(
            widget.app.settings.copyWith(stationOrder: stations.toList()),
          );
          if (context.mounted) Navigator.pop(context);
        }),
        child: const Text('保存'),
      ),
    ],
    child: stations.isEmpty
        ? const QuietEmpty(title: '添加取件后可排列站点', description: '常用站点可以拖动到前面。')
        : Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('长按或拖动右侧手柄调整顺序，完成后点保存。'),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: stations.length,
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  onReorderItem: (oldIndex, newIndex) => setState(() {
                    stations.insert(newIndex, stations.removeAt(oldIndex));
                  }),
                  itemBuilder: (context, index) => Padding(
                    key: ValueKey(stations[index]),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        leading: Text(
                          '${index + 1}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        title: Text(stations[index]),
                        trailing: ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(Icons.drag_handle_rounded),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
  );
}

class RecognitionRulesPage extends StatelessWidget {
  const RecognitionRulesPage({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: app,
    builder: (context, _) => PageFrame(
      title: '识别纠正规则',
      actions: [
        IconButton(
          tooltip: '添加规则',
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('按通知中包含的文字匹配，将识别出的站点或快递公司替换为你填写的名称。规则只保存在本机，对后续导入生效。'),
          const SizedBox(height: 18),
          if (app.rules.isEmpty)
            QuietEmpty(
              title: '还没有纠正规则',
              description: '站点太长或公司识别不准时，可以添加一条。',
              action: OutlinedButton.icon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('添加规则'),
              ),
              illustrated: false,
            ),
          for (final rule in app.rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  leading: Icon(
                    rule.kind == 'company'
                        ? Icons.local_shipping_outlined
                        : Icons.location_on_outlined,
                  ),
                  title: Text(rule.replacement),
                  subtitle: Text(
                    '${rule.kind == 'company' ? '快递公司' : '站点'} · 包含“${rule.pattern}”',
                  ),
                  onTap: () => _edit(context, existing: rule),
                  trailing: IconButton(
                    tooltip: '删除规则',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      if (await confirm(
                            context,
                            '删除这条规则？',
                            '之后导入的通知将不再应用这项纠正。',
                            accept: '删除',
                          ) &&
                          context.mounted) {
                        await runTask(context, () => app.deleteRule(rule.id));
                      }
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Future<void> _edit(BuildContext context, {RecognitionRule? existing}) async {
    final pattern = TextEditingController(text: existing?.pattern ?? '');
    final replacement = TextEditingController(
      text: existing?.replacement ?? '',
    );
    var kind = existing?.kind ?? 'address';
    final form = GlobalKey<FormState>();
    final saved = await showSettledDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? '添加纠正规则' : '编辑纠正规则'),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'address', label: Text('站点')),
                        ButtonSegment(value: 'company', label: Text('快递公司')),
                      ],
                      selected: {kind},
                      onSelectionChanged: (value) =>
                          setState(() => kind = value.first),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: pattern,
                      decoration: const InputDecoration(labelText: '通知包含的文字'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '请填写要匹配的文字'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: replacement,
                      decoration: const InputDecoration(labelText: '显示为'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '请填写替换后的名称'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(context, true);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) {
      await runTask(
        context,
        () => app.saveRule(
          RecognitionRule(
            id:
                existing?.id ??
                DateTime.now().microsecondsSinceEpoch.toString(),
            kind: kind,
            pattern: pattern.text.trim(),
            replacement: replacement.text.trim(),
          ),
        ),
        success: '规则已保存',
      );
    }
    pattern.dispose();
    replacement.dispose();
  }
}

class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key, required this.app});
  final AppController app;
  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  late bool enabled = widget.app.settings.reminderEnabled;
  late TimeOfDay time = TimeOfDay(
    hour: widget.app.settings.reminderHour,
    minute: widget.app.settings.reminderMinute,
  );
  late Set<int> days = widget.app.settings.reminderWeekdays.toSet();
  bool saving = false;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: '取件提醒',
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: SwitchListTile(
            title: const Text('定时提醒我取件'),
            subtitle: const Text('按选择的日期和时间发送本地通知'),
            value: enabled,
            onChanged: (value) => setState(() => enabled = value),
          ),
        ),
        const SectionTitle('提醒时间'),
        Card(
          child: ListTile(
            title: Text(
              time.format(context),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            trailing: const Icon(Icons.schedule_rounded),
            onTap: () async {
              final result = await showTimePicker(
                context: context,
                initialTime: time,
              );
              if (result != null) setState(() => time = result);
            },
          ),
        ),
        const SectionTitle('每周重复'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            7,
            (index) => FilterChip(
              label: Text(['周一', '周二', '周三', '周四', '周五', '周六', '周日'][index]),
              selected: days.contains(index + 1),
              onSelected: (selected) => setState(() {
                if (selected) {
                  days.add(index + 1);
                } else {
                  days.remove(index + 1);
                }
              }),
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: saving ? null : _save,
          icon: const Icon(Icons.check_rounded),
          label: Text(saving ? '保存中…' : '保存提醒'),
        ),
        const SizedBox(height: 20),
        Text(
          '这是本地取件提醒。系统省电、勿扰模式或通知设置可能影响送达时间；你可以随时在权限说明中检查通知状态。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
  Future<void> _save() async {
    if (enabled && days.isEmpty) {
      notice(context, '请至少选择一天');
      return;
    }
    setState(() => saving = true);
    await runTask(context, () async {
      await widget.app.updateSettings(
        widget.app.settings.copyWith(
          reminderEnabled: enabled,
          reminderHour: time.hour,
          reminderMinute: time.minute,
          reminderWeekdays: days.toList()..sort(),
        ),
      );
      if (mounted) notice(context, enabled ? '取件提醒已保存' : '取件提醒已关闭');
    });
    if (mounted) setState(() => saving = false);
  }
}

class TrashPage extends StatelessWidget {
  const TrashPage({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: app,
    builder: (context, _) => PageFrame(
      title: '回收站',
      actions: [
        if (app.trash.isNotEmpty)
          TextButton(
            onPressed: () async {
              if (await confirm(
                    context,
                    '永久清空回收站？',
                    '这 ${app.trash.length} 条记录将无法恢复。',
                    accept: '永久清空',
                  ) &&
                  context.mounted) {
                await runTask(context, app.emptyTrash, success: '回收站已清空');
              }
            },
            child: const Text('清空'),
          ),
      ],
      child: app.trash.isEmpty
          ? const QuietEmpty(
              title: '回收站是空的',
              description: '删除的取件记录会暂存在这里。',
              illustrated: false,
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('恢复后会保留原来的待取 / 已取状态。'),
                const SizedBox(height: 16),
                for (final parcel in app.trash)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: ListTile(
                        title: Text(
                          '${parcel.station} · ${parcel.code.isEmpty ? '无取件码' : parcel.code}',
                        ),
                        subtitle: Text(
                          '${dayLabel(parcel.arrivedAt, year: true)}到件 · ${parcel.isCollected ? '已取' : '待取'}',
                        ),
                        trailing: TextButton(
                          onPressed: () => runTask(
                            context,
                            () => app.restoreParcels([parcel.id]),
                            success: '记录已恢复',
                          ),
                          child: const Text('恢复'),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    ),
  );
}

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key, required this.app});
  final AppController app;
  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage>
    with WidgetsBindingObserver {
  late Future<Map<String, dynamic>> state;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state = widget.app.platform.getPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    if (value == AppLifecycleState.resumed) _reload();
  }

  void _reload() =>
      setState(() => state = widget.app.platform.getPermissions());
  @override
  Widget build(BuildContext context) => PageFrame(
    title: '权限说明',
    actions: [
      IconButton(
        tooltip: '刷新权限状态',
        onPressed: _reload,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
    child: FutureBuilder<Map<String, dynamic>>(
      future: state,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return QuietEmpty(
            title: '无法读取权限状态',
            description: '${snapshot.error}',
            action: OutlinedButton(onPressed: _reload, child: const Text('重试')),
            illustrated: false,
          );
        }
        final p = snapshot.data ?? {};
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('按使用需要开启权限。短信用于整理取件通知，相机用于扫码，通知用于取件提醒；手动添加始终可用。'),
            const SectionTitle('功能与权限'),
            if (supportsSms)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.screen_search_desktop_rounded),
                  title: const Text('平台页面识别'),
                  subtitle: const Text(
                    '辅助功能用于你主动读取的所选平台页面；内容进入草稿，核对后保存。可随时结束会话或在系统关闭。',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openPage(context, const PageCapturePage()),
                ),
              ),
            if (supportsSms)
              _permission(
                context,
                '短信读取与接收',
                '导入已有取件短信，并在收到新通知时归集。不会发送短信，也不会上传短信内容。',
                p['readSms'] == true && p['receiveSms'] == true,
                () => runTask(context, () async {
                  await widget.app.platform.requestSms();
                  _reload();
                }),
              )
            else
              _explanation(
                context,
                '短信导入',
                'iOS 不提供本应用所需的通用短信收件箱访问。请使用粘贴文字、截图识别或手动添加。',
                Icons.sms_outlined,
              ),
            _permission(
              context,
              '通知',
              '用于你主动开启的定时取件提醒。',
              p['notifications'] == true,
              () => runTask(context, () async {
                await widget.app.platform.requestNotifications();
                _reload();
              }),
            ),
            _explanation(
              context,
              '相机',
              '仅在“扫码添加”时请求，用于识别静态二维码和条码。相机画面不会上传。',
              Icons.photo_camera_outlined,
              status: p['camera'] == true ? '已允许' : '使用扫码时申请',
            ),
            _explanation(
              context,
              '选择照片与文件',
              '由系统选择器提供你选中的截图、码图片或备份文件，不需要访问全部照片和文件。',
              Icons.image_outlined,
            ),
            _explanation(
              context,
              '剪贴板',
              '只有点击“读取剪贴板”时才获取文字，不在后台读取。',
              Icons.content_paste_rounded,
            ),
            _explanation(
              context,
              '网络与外部 App',
              '检查更新、反馈及打开官方平台时使用。取件记录、码夹、识别与批量已取在本地完成。',
              Icons.open_in_new_rounded,
            ),
            if (p['platform'] == 'ios' && p['appGroupAvailable'] != true)
              _explanation(
                context,
                'iOS 小组件共享空间',
                '当前签名未启用 App Group。主应用可正常使用；完成开发者账号、App Group 和组件签名配置后才能同步桌面组件。',
                Icons.widgets_outlined,
              ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () =>
                  runTask(context, widget.app.platform.openSettings),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('打开系统应用设置'),
            ),
            if (supportsSms)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  '短信权限也受手机系统和安装器限制。如系统不允许授权，请使用粘贴文字或截图识别。后台接收异常时，检查手机的自启动与电池限制。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        );
      },
    ),
  );
  Widget _permission(
    BuildContext context,
    String title,
    String description,
    bool granted,
    VoidCallback request,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  granted ? '已允许' : '未允许',
                  style: TextStyle(
                    color: granted
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description),
            if (!granted)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton(
                  onPressed: request,
                  child: const Text('申请权限'),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  Widget _explanation(
    BuildContext context,
    String title,
    String description,
    IconData icon, {
    String? status,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (status != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  status,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            Text(description),
          ],
        ),
      ),
    ),
  );
}

class WidgetSettingsPage extends StatefulWidget {
  const WidgetSettingsPage({super.key, required this.app});
  final AppController app;
  @override
  State<WidgetSettingsPage> createState() => _WidgetSettingsPageState();
}

class _WidgetSettingsPageState extends State<WidgetSettingsPage> {
  double? _previewOpacity;
  AppController get app => widget.app;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: app,
    builder: (context, _) {
      final light = app.settings.widgetStyle == 'ivory';
      final opacity = _previewOpacity ?? app.settings.widgetOpacity;
      final foreground = light
          ? const Color(0xFF143A43)
          : const Color(0xFFF7FCFD);
      final secondary = light
          ? const Color(0xFF365861)
          : const Color(0xFFDEEDF0);
      return PageFrame(
        title: '桌面小组件',
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('取件码，抬眼即见', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('站点、取件码与待取数量。轻点勾选，记录已取。'),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF8EADAA),
                    Color(0xFF3E696D),
                    Color(0xFFD8CDAF),
                  ],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: light
                        ? [
                            const Color(
                              0xFFF8FFFF,
                            ).withValues(alpha: (opacity + .15).clamp(0, 1)),
                            const Color(0xFFDEF0F2).withValues(alpha: opacity),
                            const Color(
                              0xFFD0E5E9,
                            ).withValues(alpha: (opacity + .09).clamp(0, 1)),
                          ]
                        : [
                            const Color(
                              0xFF377782,
                            ).withValues(alpha: (opacity + .09).clamp(0, 1)),
                            const Color(0xFF153A46).withValues(alpha: opacity),
                            const Color(
                              0xFF0C2632,
                            ).withValues(alpha: (opacity + .05).clamp(0, 1)),
                          ],
                  ),
                  border: Border.all(
                    color: const Color(0xFFD7F4F5).withValues(alpha: .5),
                  ),
                ),
                child: DefaultTextStyle(
                  style: TextStyle(color: foreground),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '易取件',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${app.pending.length} 件待取',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: light
                                  ? const Color(0xFF476C68)
                                  : const Color(0xFFF4DB9C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (app.pending.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            '都取好了，轻装出发',
                            style: TextStyle(color: secondary, fontSize: 16),
                          ),
                        )
                      else
                        ...app.pending
                            .take(3)
                            .map(
                              (p) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.station,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: secondary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            app.settings.widgetShowCodes
                                                ? (p.code.isEmpty
                                                      ? '待补充'
                                                      : p.code)
                                                : '取件码已隐藏',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color:
                                            (light
                                                    ? Colors.white
                                                    : const Color(0xFF18313B))
                                                .withValues(alpha: .44),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: gold.withValues(alpha: .44),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.check_rounded,
                                        color: light
                                            ? const Color(0xFF476C68)
                                            : const Color(0xFFF4DB9C),
                                        size: 23,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '桌面预览 · 清单可滚动查看',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SectionTitle('玻璃外观'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'jade', label: Text('灵青玻璃')),
                ButtonSegment(value: 'ivory', label: Text('雾白玻璃')),
              ],
              selected: {app.settings.widgetStyle},
              onSelectionChanged: (value) => runTask(
                context,
                () => app.updateSettings(
                  app.settings.copyWith(widgetStyle: value.first),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('背景浓度')),
                        Text(
                          '${(opacity * 100).round()}%',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                    Slider(
                      key: const ValueKey('widget-opacity'),
                      min: .18,
                      max: .9,
                      divisions: 24,
                      value: opacity,
                      label: '${(opacity * 100).round()}%',
                      onChanged: (value) =>
                          setState(() => _previewOpacity = value),
                      onChangeEnd: (value) => runTask(context, () async {
                        await app.updateSettings(
                          app.settings.copyWith(widgetOpacity: value),
                        );
                        if (mounted) setState(() => _previewOpacity = null);
                      }),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '透出壁纸色彩，按桌面背景调节清晰度。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: SwitchListTile(
                title: const Text('在桌面显示取件码'),
                subtitle: const Text('站点与待取数量始终可见'),
                value: app.settings.widgetShowCodes,
                onChanged: (value) => runTask(
                  context,
                  () => app.updateSettings(
                    app.settings.copyWith(widgetShowCodes: value),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              key: const ValueKey('pin-widget'),
              onPressed: () => runTask(context, () async {
                final requested = await app.platform.pinWidget();
                if (context.mounted) {
                  notice(
                    context,
                    requested ? '请在系统弹窗中确认添加' : '请长按桌面空白处，在小组件列表中选择易取件',
                  );
                }
              }),
              icon: const Icon(Icons.add_to_home_screen_rounded),
              label: const Text('添加到桌面'),
            ),
            const SectionTitle('调整大小'),
            Text(
              supportsSms
                  ? '添加后长按小组件，拖动边框调整宽高。清单可上下滑动，轻点标题进入易取件。'
                  : '在系统小组件列表中选择小、中或大尺寸，轻点勾选记录已取。',
            ),
            const SizedBox(height: 16),
            Text(
              '“已取”记录保存在易取件中。桌面仅展示站点与取件码。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    },
  );
}

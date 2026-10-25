import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/page_capture_service.dart';
import 'actions.dart';
import 'theme.dart';

class PageCapturePage extends StatefulWidget {
  const PageCapturePage({super.key});

  @override
  State<PageCapturePage> createState() => _PageCapturePageState();
}

class _PageCapturePageState extends State<PageCapturePage>
    with WidgetsBindingObserver {
  final service = PageCaptureService();
  PageCaptureState state = const PageCaptureState();
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (PageCaptureService.supported) _action(service.state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    if (value == AppLifecycleState.resumed && PageCaptureService.supported) {
      _action(service.state);
    }
  }

  Future<void> _action(Future<PageCaptureState> Function() operation) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final next = await operation();
      if (mounted) setState(() => state = next);
    } catch (exception) {
      if (mounted) {
        setState(
          () => error = exception is PlatformException
              ? exception.message ?? '页面识别操作失败'
              : exception.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _configure({bool? consented, Set<String>? selected}) => _action(
    () => service.configure(
      consented: consented ?? state.consented,
      selectedPackages: selected ?? state.selectedPackages,
    ),
  );

  @override
  Widget build(BuildContext context) => PageFrame(
    title: '页面取件识别',
    actions: [
      if (PageCaptureService.supported)
        IconButton(
          tooltip: '刷新识别状态',
          onPressed: busy ? null : () => _action(service.state),
          icon: const Icon(Icons.refresh_rounded),
        ),
    ],
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.document_scanner_outlined,
                  size: 30,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  '把眼前的取件信息带回来',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                const Text(
                  '在平台的取件或待收货页面，点击“读取本页”提取当前可见文字，回到易取件检查站点、取件码和地址后添加。页面较长时，向下滚动后可继续读取。',
                ),
                const SizedBox(height: 10),
                Text(
                  PageCaptureService.supported && state.screenshotSupported
                      ? '图片中的文字可点击“截图”识别，也可使用系统截图后从相册或分享导入。'
                      : '可将页面截图从相册导入，或选中文字后粘贴、通过系统分享发送到易取件。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        if (PageCaptureService.supported) ...[
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SectionTitle('读取范围'),
          Card(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Text(
                    '页面文字或截图可能包含收件信息。仅在你开始本次识别、打开选定平台并点击浮动按钮时读取；内容在本机处理并暂存为导入草稿，由你预览确认。点击“结束”可停止本次识别。',
                  ),
                ),
                CheckboxListTile(
                  key: const ValueKey('capture-consent'),
                  title: const Text('我已了解并允许本机页面识别'),
                  value: state.consented,
                  onChanged: busy
                      ? null
                      : (value) => _configure(consented: value == true),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          const SectionTitle('允许识别的平台'),
          Card(
            child: Column(
              children: state.platforms.entries
                  .map(
                    (entry) => CheckboxListTile(
                      title: Text(entry.value),
                      value: state.selectedPackages.contains(entry.key),
                      onChanged: busy
                          ? null
                          : (value) {
                              final selected = {...state.selectedPackages};
                              if (value == true) {
                                selected.add(entry.key);
                              } else {
                                selected.remove(entry.key);
                              }
                              _configure(selected: selected);
                            },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SectionTitle('开始取件识别'),
          if (!state.enabled)
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text('若系统提示“受限设置”，可在系统应用信息的菜单中查看“允许受限制的设置”，再返回辅助功能设置。'),
            ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    state.enabled
                        ? Icons.check_circle_outline
                        : Icons.accessibility_new_rounded,
                  ),
                  title: const Text('系统辅助功能'),
                  subtitle: Text(
                    state.enabled
                        ? (state.connected ? '易取件页面识别已开启' : '服务正在连接，可稍后刷新')
                        : '在系统辅助功能中开启“易取件页面识别”',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: busy || !state.consented
                      ? null
                      : () => runTask(context, service.openSettings),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: Icon(
                    state.running
                        ? Icons.pause_circle_outline
                        : Icons.touch_app_outlined,
                  ),
                  title: Text(state.running ? '本次识别进行中' : '本次识别'),
                  subtitle: const Text('开始后，打开选定平台即可看到浮动按钮；拖动标题可调整位置'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('capture-session'),
                      onPressed:
                          busy ||
                              (!state.running &&
                                  (!state.consented ||
                                      !state.connected ||
                                      state.selectedPackages.isEmpty))
                          ? null
                          : () => _action(
                              state.running
                                  ? service.stopSession
                                  : service.startSession,
                            ),
                      icon: Icon(
                        state.running
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(state.running ? '结束本次识别' : '开始本次识别'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

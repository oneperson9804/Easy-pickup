import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/app_controller.dart';
import 'actions.dart';
import 'code_wallet.dart';
import 'documents.dart';
import 'editors.dart';
import 'feedback_page.dart';
import 'parcel_pages.dart';
import 'settings_pages.dart';
import 'theme.dart';

class EasyPickupApp extends StatelessWidget {
  const EasyPickupApp({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      title: '易取件',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: pickupTheme(Brightness.light),
      darkTheme: pickupTheme(Brightness.dark),
      themeMode: switch (controller.settings.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      home: _Home(app: controller),
    ),
  );
}

class _Home extends StatefulWidget {
  const _Home({required this.app});
  final AppController app;
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> with WidgetsBindingObserver {
  int index = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) runTask(context, widget.app.reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('main-scaffold'),
    appBar: AppBar(
      title: Row(
        children: [
          const Flexible(
            child: Text(
              '易取件',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: gold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          if (MediaQuery.sizeOf(context).width >= 420 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.2)
            Flexible(
              child: Text(
                'Easy pickup',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: '刷新记录',
          onPressed: () => runTask(context, widget.app.reload),
          icon: const Icon(Icons.refresh_rounded, size: 21),
        ),
        const SizedBox(width: 8),
      ],
    ),
    drawer: _drawer(context),
    body: SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: [
          if (widget.app.busy) const LinearProgressIndicator(minHeight: 2),
          if (widget.app.sharedText != null)
            MaterialBanner(
              content: const Text('有待确认的取件信息，检查后即可添加'),
              leading: const Icon(Icons.move_to_inbox_outlined),
              actions: [
                TextButton(
                  onPressed: () => runTask(context, widget.app.clearSharedText),
                  child: const Text('忽略'),
                ),
                TextButton(
                  onPressed: () async {
                    final draft = widget.app.sharedText!;
                    await importTextDialog(
                      context,
                      widget.app,
                      initial: draft,
                      source: 'share',
                    );
                  },
                  child: const Text('查看'),
                ),
              ],
            ),
          if (widget.app.error != null)
            MaterialBanner(
              content: Text(widget.app.error!),
              leading: const Icon(Icons.info_outline_rounded),
              actions: [
                if (widget.app.failedSharedImportId != null) ...[
                  TextButton(
                    onPressed: () => runTask(context, widget.app.reload),
                    child: const Text('重试'),
                  ),
                  TextButton(
                    onPressed: () =>
                        runTask(context, widget.app.discardIncomingShare),
                    child: const Text('忽略分享'),
                  ),
                ],
                TextButton(
                  onPressed: widget.app.clearError,
                  child: const Text('知道了'),
                ),
              ],
            ),
          Expanded(
            child: IndexedStack(
              index: index,
              children: [
                PendingPage(app: widget.app),
                CalendarPage(app: widget.app),
                CodeWalletPage(app: widget.app),
              ],
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      key: const ValueKey('bottom-navigation'),
      selectedIndex: index,
      onDestinationSelected: (value) => setState(() => index = value),
      destinations: const [
        NavigationDestination(
          key: ValueKey('nav-pending'),
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2_rounded),
          label: '待取件',
        ),
        NavigationDestination(
          key: ValueKey('nav-calendar'),
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month_rounded),
          label: '取件日历',
        ),
        NavigationDestination(
          key: ValueKey('nav-wallet'),
          icon: Icon(Icons.qr_code_rounded),
          selectedIcon: Icon(Icons.qr_code_2_rounded),
          label: '取件码夹',
        ),
      ],
    ),
  );

  Widget _drawer(BuildContext context) => Drawer(
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    'assets/branding/app_icon.png',
                    width: 54,
                    height: 54,
                    errorBuilder: (_, _, _) => Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.grass_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '易取件',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '取件有序，出门从容',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _menu(
                  context,
                  Icons.settings_outlined,
                  '设置',
                  () => openPage(context, SettingsPage(app: widget.app)),
                ),
                _menu(
                  context,
                  Icons.verified_user_outlined,
                  '权限说明',
                  () => openPage(context, PermissionsPage(app: widget.app)),
                ),
                _menu(
                  context,
                  Icons.widgets_outlined,
                  '桌面小组件',
                  () => openPage(context, WidgetSettingsPage(app: widget.app)),
                ),
                _menu(
                  context,
                  Icons.help_outline_rounded,
                  '常见问题',
                  () => openPage(context, const HelpPage()),
                ),
                _menu(
                  context,
                  Icons.chat_bubble_outline_rounded,
                  '反馈意见',
                  () => openPage(context, FeedbackPage(app: widget.app)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Divider(),
                ),
                _menu(
                  context,
                  Icons.description_outlined,
                  '用户协议',
                  () => openPage(context, const DocumentPage(privacy: false)),
                ),
                _menu(
                  context,
                  Icons.privacy_tip_outlined,
                  '隐私政策',
                  () => openPage(context, const DocumentPage(privacy: true)),
                ),
                _menu(
                  context,
                  Icons.system_update_outlined,
                  '检查更新',
                  () => checkForUpdates(context, widget.app),
                ),
                _menu(
                  context,
                  Icons.code_rounded,
                  '关于与开源',
                  () => openPage(context, AboutPage(app: widget.app)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Icon(Icons.grass_rounded, color: gold, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '取件记录 · 随手可查',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(AppController.appVersion, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _menu(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback action,
  ) => ListTile(
    leading: Icon(icon, size: 22),
    title: Text(label),
    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    onTap: () {
      Navigator.of(context).pop();
      action();
    },
  );
}

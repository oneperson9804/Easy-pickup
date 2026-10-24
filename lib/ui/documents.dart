import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_controller.dart';
import 'actions.dart';
import 'theme.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
    title: '常见问题',
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        _Question(
          '易取件需要登录、会员或邀请好友吗？',
          '不需要。取件管理、批量已取、日历、识别规则和小组件全部免费，不设置商业次数限制。没有账号、会员和邀请解锁功能。',
        ),
        _Question(
          '“标记已取”就是快递正式签收吗？',
          '这项操作只更新易取件本机记录，方便整理已经取走的快递。驿站出库、快递签收状态和官方身份验证仍以对应平台为准。误操作可以撤销，或在日历中打开记录后恢复为待取。',
        ),
        _Question(
          '为什么没有自动出现我的全部网购订单？',
          '易取件根据你授权导入的取件短信、粘贴文字、截图或手动输入整理记录，不会登录电商账号抓取订单。未发送取件通知的包裹，可以手动添加或打开官方平台查看。',
        ),
        _Question(
          'Android 短信导入不成功怎么办？',
          '在权限说明中检查短信读取与接收权限，再确认设置中的导入时间范围。短信格式不统一，识别失败时可以粘贴原文后检查，或手动填写。部分手机和安装器会限制短信权限，此时仍可使用粘贴、截图和手动添加。',
        ),
        _Question(
          '收到短信后，桌面为什么没有更新？',
          '先确认短信权限和手机的自启动、电池设置。系统强制停止应用后可能暂停接收，重新打开后可手动导入补齐。也可以在桌面小组件页调整配置并刷新。不同厂商桌面的后台规则可能不同。',
        ),
        _Question(
          '为什么 iPhone 没有自动读取短信？',
          'iOS 不提供适合本应用的通用短信收件箱读取能力。请主动复制通知文字、选择截图识别或手动填写。支持系统分享的来源也可以通过系统导入。',
        ),
        _Question(
          '重复的通知会变成多个包裹吗？',
          '同一来源短信会按发送方、时间和内容去重。不同来源或多次手动录入的相同取件码可能代表不同包裹，导入后请检查站点和记录；不需要的记录可以移入回收站。',
        ),
        _Question(
          '站点或快递公司识别不准怎么办？',
          '直接编辑这条取件记录。对反复出现的通知，可在设置的识别纠正规则中填写通知包含的文字和希望显示的名称，之后导入时自动应用。',
        ),
        _Question(
          '官方身份码和“我的静态码”有什么区别？',
          '官方身份码可能定期变化，应从对应平台打开；该平台可能要求登录自己的账号。我的静态码只保存你确认过的固定二维码或条码，不能替代已过期的官方动态码。',
        ),
        _Question(
          '日历为什么既能看到到件，又能看到已取？',
          '每条记录分别保存到件日期和标记已取时间。在这两个日期中都可以找到它。跨日未取单独显示，不会因为翻过日期而隐藏；统计也不会把同一件快递当成两件。',
        ),
        _Question(
          '小组件可以调整大小吗？',
          'Android 添加后长按组件，拖动控制点调整宽高；可用尺寸取决于手机桌面。iOS 在系统支持的小、中、大规格中选择。组件默认不显示手机号和短信全文，取件码可以在配置中隐藏。',
        ),
        _Question(
          '换机、卸载或从旧版迁移怎么办？',
          '先在设置导出 JSON 备份，再到新设备导入。备份包含取件记录、码夹、识别规则和设置。旧版需要先使用配套迁移工具导出；图片分享不是记录备份。确认迁移成功后再卸载旧应用。',
        ),
        _Question(
          '识别截图或扫描图片时会上传照片吗？',
          '图片识别在设备上进行。易取件只使用你主动选择的图片，不把图片和取件通知发送到业务服务器。',
        ),
        _Question(
          '如何反馈识别错误？',
          '通过菜单中的反馈意见打开项目 Issues。描述发生步骤、手机系统版本和应用版本；提供样例前请自行遮去手机号、完整取件码、住址等个人信息。',
        ),
      ],
    ),
  );
}

class _Question extends StatelessWidget {
  const _Question(this.question, this.answer);
  final String question, answer;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(question, style: Theme.of(context).textTheme.titleMedium),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(answer)],
      ),
    ),
  );
}

class DocumentPage extends StatelessWidget {
  const DocumentPage({super.key, required this.privacy});
  final bool privacy;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: privacy ? '隐私政策' : '用户协议',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      children: [
        Text(
          privacy ? '你的取件信息，留在你的设备上。' : '让取件更简单。',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          '适用版本：易取件 1.0.0\n更新日期：2026年10月25日',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        ..._sections(privacy).map(
          (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [SectionTitle(s.$1), SelectableText(s.$2)],
          ),
        ),
      ],
    ),
  );

  List<(String, String)> _sections(bool privacy) => privacy
      ? const [
          (
            '1. 我们处理哪些信息',
            '易取件不设置账号，不收集登录信息。你主动添加或授权导入的取件通知、站点、取件码、快递公司、到件时间、已取状态、静态码、规则和设置保存在应用的本机存储中。Android 短信读取范围由导入设置和系统授权共同决定；只把识别出的取件信息保存为记录。',
          ),
          (
            '2. 权限与本地识别',
            'Android 短信权限用于读取取件通知和接收新通知，不用于发送短信。相机用于你主动开启的扫码；照片和文件由系统选择器提供，用于截图识别、静态码导入和备份恢复。通知权限用于你开启的本地提醒。剪贴板只在点击读取按钮后访问。图片和通知文字在本机处理。拒绝可选权限后，你仍可手动管理记录。',
          ),
          (
            '3. 网络与第三方服务',
            '易取件没有账号、会员、广告或邀请服务，不把你的取件记录上传到业务服务器。你主动检查更新时，会向 GitHub 请求公开版本信息；主动反馈、打开源码或官方取件入口时，会打开对应外部服务。截图识别和 Android 扫码使用 Google ML Kit 端侧组件，图片、文字和识别结果在设备上处理；该组件可能按其官方政策发送设备、应用版本、性能和错误等诊断信息。这些诊断不是取件记录或图片内容。外部服务按各自政策处理网络连接信息和你主动提交的内容。',
          ),
          (
            '4. 桌面小组件与分享',
            '桌面小组件使用本机记录显示待取件，并允许标记已取。组件不显示手机号和短信全文，可在设置中隐藏取件码。通过系统分享发送的文字或图片由你选择接收方；请在确认内容后分享。官方平台账号和身份码由对应平台管理，易取件不索取这些账号的密码。',
          ),
          (
            '5. 备份、删除与卸载',
            '你可以导出、导入本地备份，编辑记录，或将记录移入回收站。清空回收站后相关记录会从本机数据库删除。导出文件可能保留在你选择的位置，需要你自行管理和删除。卸载应用通常会删除应用本机数据；卸载前请完成需要的备份。',
          ),
          (
            '6. 儿童、变更与联系',
            '易取件提供通用取件整理功能，不主动收集儿童个人信息。请不要在公开反馈中提交身份证、手机号、完整住址和有效取件码。如未来信息处理方式发生变化，会更新本政策，并在涉及新增权限时由你重新决定。问题可通过菜单“反馈意见”联系项目维护者。',
          ),
        ]
      : const [
          (
            '1. 服务范围',
            '易取件是免费的本地取件整理工具，提供通知识别、手动录入、待取管理、批量标记已取、日历、静态码夹和桌面小组件。全部功能免登录，不通过会员、付款、邀请码或商业次数限制解锁。源码与第三方依赖的使用遵循仓库所列开源许可证。',
          ),
          (
            '2. 本机记录与正式取件',
            '“标记已取”仅改变本机记录，不会向快递公司、电商平台或驿站确认签收和出库。实际取件、身份验证、费用争议和包裹状态请以服务提供方为准。官方取件入口由对应平台提供，其登录、可用性和规则也由该平台决定。',
          ),
          (
            '3. 使用与检查',
            '通知格式、截图质量、系统权限和后台限制可能影响识别结果。请在取件前核对站点、取件码及官方通知，及时纠正识别错误。请只添加、保存和分享你有权处理的信息，不使用本工具冒用他人身份码或干扰第三方服务。',
          ),
          (
            '4. 数据与权限',
            '你可以决定是否授权短信、相机和通知等可选权限。相关用途见权限说明与隐私政策。请妥善保存备份文件，换机或卸载前先完成导出。删除、分享、备份恢复等操作会按界面说明影响本机记录或你选择的接收方。',
          ),
          (
            '5. 更新与开源',
            '你可以选择是否检查并安装新版本。Android 版本通过项目公开发布渠道分发；iOS 按实际签名和发布渠道提供。更新可能修复识别规则、平台兼容性和界面问题。项目不保证第三方深链永久有效，发现失效可通过反馈渠道报告。',
          ),
          (
            '6. 反馈与协议变更',
            '如遇问题，请通过菜单“反馈意见”提交可复现步骤。协议随产品实际功能更新；涉及数据处理的变化以对应版本的隐私政策和系统授权为准。本协议不限制你依法享有的权利。',
          ),
        ];
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.app});
  final AppController app;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: '关于与开源',
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 22),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/branding/app_icon.png',
              width: 92,
              height: 92,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.grass_rounded, size: 72, color: bamboo),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '易取件',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Easy pickup · 1.0.0',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        const Text('取件有序，出门从容。', textAlign: TextAlign.center),
        const SizedBox(height: 30),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.code_rounded),
                title: const Text('查看开源项目'),
                subtitle: const Text('源代码、构建说明与版本发布'),
                onTap: () => runTask(context, app.openRepository),
              ),
              const Divider(indent: 58),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('第三方开源许可证'),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: '易取件',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '完整项目许可证与素材说明见源码仓库。',
                ),
              ),
              const Divider(indent: 58),
              ListTile(
                leading: const Icon(Icons.system_update_outlined),
                title: const Text('检查更新'),
                onTap: () => checkForUpdates(context, app),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '易取件不隶属于任何快递、电商或驿站平台。平台名称仅用于说明对应的外部入口。',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

Future<void> checkForUpdates(BuildContext context, AppController app) =>
    runTask(context, () async {
      final result = await app.checkUpdates();
      if (!context.mounted) return;
      final hasUpdate = result['hasUpdate'] == true;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(hasUpdate ? '有新版本 ${result['version'] ?? ''}' : '检查更新'),
          content: Text(
            result['message']?.toString() ??
                (hasUpdate ? '可前往项目发布页查看版本说明并选择安装。' : '当前没有可用的新版本。'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
            if (hasUpdate)
              FilledButton(
                onPressed: () => runTask(context, () async {
                  final url = Uri.tryParse(result['url']?.toString() ?? '');
                  if (url == null ||
                      url.scheme != 'https' ||
                      url.host != 'github.com') {
                    throw Exception('更新地址无效，请从开源项目页检查版本。');
                  }
                  if (!await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                  )) {
                    throw Exception('无法打开发布页面');
                  }
                }),
                child: const Text('查看发布页'),
              ),
          ],
        ),
      );
    });

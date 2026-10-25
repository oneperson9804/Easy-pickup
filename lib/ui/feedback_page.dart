import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_controller.dart';
import 'actions.dart';
import 'theme.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key, required this.app});
  final AppController app;
  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final message = TextEditingController();
  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: '反馈意见',
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('告诉我你的使用体验', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const SelectableText(AppController.feedbackEmail),
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('feedback-message'),
          controller: message,
          minLines: 5,
          maxLines: 12,
          decoration: const InputDecoration(
            labelText: '问题或建议',
            hintText: '发生了什么？怎样操作可以重现？\n手机型号与系统版本：',
          ),
        ),
        const SizedBox(height: 16),
        const Text('发送前请检查截图和文字，遮去有效取件码、手机号及完整住址。'),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => runTask(context, () async {
            final opened = await widget.app.openFeedback(message: message.text);
            if (!opened && context.mounted) {
              notice(context, '未能打开邮件应用，可复制邮箱后发送');
            }
          }),
          icon: const Icon(Icons.mail_outline_rounded),
          label: const Text('使用邮件应用撰写'),
        ),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              const ClipboardData(text: AppController.feedbackEmail),
            );
            if (context.mounted) notice(context, '邮箱已复制');
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('复制邮箱'),
        ),
      ],
    ),
  );
}

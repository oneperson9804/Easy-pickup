import 'package:flutter/material.dart';
import 'core/app_controller.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final controller = await AppController.create();
    runApp(EasyPickupApp(controller: controller));
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 52,
                    color: Color(0xff147d88),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '本机存储暂时无法打开',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text('请保留现有应用数据，检查可用空间后重新打开。'),
                  const SizedBox(height: 12),
                  SelectableText(error.toString()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

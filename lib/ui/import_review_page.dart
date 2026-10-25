import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/import_review.dart';
import '../core/models.dart';
import 'actions.dart';

class ImportReviewPage extends StatefulWidget {
  const ImportReviewPage({
    super.key,
    required this.app,
    required this.text,
    required this.source,
  });
  final AppController app;
  final String text, source;
  @override
  State<ImportReviewPage> createState() => _ImportReviewPageState();
}

class _ReviewRow {
  _ReviewRow(this.item)
    : station = TextEditingController(text: item.parcel?.station ?? ''),
      code = TextEditingController(text: item.parcel?.code ?? ''),
      company = TextEditingController(text: item.parcel?.company ?? ''),
      address = TextEditingController(text: item.parcel?.detailAddress ?? ''),
      selected = item.parcel != null && item.duplicate == null;
  final ImportCandidate item;
  final TextEditingController station, code, company, address;
  bool selected, ignored = false;
  void dispose() {
    for (final controller in [station, code, company, address]) {
      controller.dispose();
    }
  }
}

class _ImportReviewPageState extends State<ImportReviewPage> {
  final form = GlobalKey<FormState>();
  late final rows = widget.app
      .previewImport(widget.text, source: widget.source)
      .map(_ReviewRow.new)
      .toList();
  bool saving = false;
  @override
  void dispose() {
    for (final row in rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final selected = rows.where((row) => row.selected && !row.ignored).map((
        row,
      ) {
        final parcel =
            row.item.parcel ??
            Parcel(
              id: newId(),
              station: '',
              code: '',
              rawText: row.item.rawText,
              arrivedAt: DateTime.now(),
              source: widget.source,
            );
        return parcel.copyWith(
          station: row.station.text.trim(),
          code: row.code.text.trim(),
          company: row.company.text.trim(),
          detailAddress: row.address.text.trim(),
        );
      }).toList();
      final remaining = rows
          .where(
            (row) =>
                !row.selected && !row.ignored && row.item.duplicate == null,
          )
          .map((row) => row.item.rawText)
          .join('\n\n');
      final count = await widget.app.importReviewed(selected, remaining);
      if (!mounted) return;
      Navigator.pop(context);
      notice(context, '已保存 $count 件${remaining.isEmpty ? '' : '，其余文字已保留为草稿'}');
    } catch (error) {
      if (mounted) notice(context, '保存失败，草稿已保留：$error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('检查取件信息')),
    body: SafeArea(
      child: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const Text('核对站点与取件码后保存。相似记录默认不勾选，可展开核对；未处理的文字会留在草稿中。'),
            const SizedBox(height: 16),
            for (var i = 0; i < rows.length; i++) buildRow(rows[i], i),
            if (rows.isEmpty) const Text('没有可检查的文字，请返回后填写取件信息。'),
          ],
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          key: const ValueKey('save-reviewed-import'),
          onPressed: saving ? null : save,
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: Text(
            '保存 ${rows.where((row) => row.selected && !row.ignored).length} 件',
          ),
        ),
      ),
    ),
  );

  Widget buildRow(_ReviewRow row, int index) => Card(
    child: ExpansionTile(
      key: ValueKey('review-row-$index'),
      initiallyExpanded:
          row.item.parcel == null || row.item.parcel!.station == '待确认站点',
      leading: Checkbox(
        value: row.selected && !row.ignored,
        onChanged: (value) => setState(() {
          row.selected = value!;
          row.ignored = false;
        }),
      ),
      title: Text(
        row.code.text.isEmpty ? '待补充取件码' : row.code.text,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      subtitle: Text(
        row.ignored
            ? '已忽略'
            : row.item.duplicate != null
            ? '可能已存在 · ${row.item.duplicate!.station}${row.item.duplicate!.isCollected ? ' · 已取' : ''}'
            : row.station.text.isEmpty
            ? '请填写站点，或保留这段文字稍后处理'
            : row.station.text,
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: row.station,
          decoration: const InputDecoration(labelText: '取件站点'),
          validator: (value) =>
              row.selected &&
                  !row.ignored &&
                  (value == null || value.trim().isEmpty)
              ? '请填写站点'
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: row.code,
          decoration: const InputDecoration(labelText: '取件码（可稍后补充）'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: row.company,
          decoration: const InputDecoration(labelText: '快递公司'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: row.address,
          maxLines: 2,
          minLines: 1,
          decoration: const InputDecoration(labelText: '详细位置'),
        ),
        const SizedBox(height: 16),
        SelectableText(
          row.item.rawText,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (row.item.duplicate != null)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('确认是另一件包裹时，可勾选并保存。'),
          ),
        TextButton(
          onPressed: () => setState(() {
            row.ignored = !row.ignored;
            row.selected = false;
          }),
          child: Text(row.ignored ? '保留这段文字' : '忽略这段文字'),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_controller.dart';
import '../core/models.dart';
import 'actions.dart';
import 'editors.dart';
import 'theme.dart';

class PendingPage extends StatefulWidget {
  const PendingPage({super.key, required this.app});
  final AppController app;
  @override
  State<PendingPage> createState() => _PendingPageState();
}

class _PendingPageState extends State<PendingPage> {
  final search = TextEditingController();
  final selected = <String>{};
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final pending = app.pending
        .where(
          (p) =>
              '${p.station} ${p.code} ${p.company} ${p.rawText} ${p.detailAddress}'
                  .toLowerCase()
                  .contains(search.text.toLowerCase()),
        )
        .toList();
    final currentIds = app.pending.map((p) => p.id).toSet();
    selected.removeWhere((id) => !currentIds.contains(id));
    final stations = <String>[];
    for (final parcel in pending) {
      if (!stations.contains(parcel.station)) stations.add(parcel.station);
    }
    final allStations = {...app.settings.stationOrder, ...stations}.toList();
    stations.sort(
      (a, b) => allStations.indexOf(a).compareTo(allStations.indexOf(b)),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '待取件',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      app.pending.isEmpty
                          ? '把琐事放下，轻松出门。'
                          : '${app.pending.length} 件快递，分布在 ${app.pending.map((p) => p.station).toSet().length} 个站点',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const ValueKey('add-parcel'),
                onPressed: () => showAddMenu(context, app),
                icon: const Icon(Icons.add_rounded),
                label: const Text('添加'),
              ),
            ],
          ),
        ),
        if (app.pending.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              key: const ValueKey('search-parcels'),
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: '搜索站点、取件码或快递公司',
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除搜索',
                        onPressed: () {
                          search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
        Expanded(
          child: app.pending.isEmpty
              ? RefreshIndicator(
                  onRefresh: app.reload,
                  child: LayoutBuilder(
                    builder: (context, size) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: size.maxHeight),
                        child: QuietEmpty(
                          title: '还没有待取件',
                          description: '添加取件通知后，取件码会按站点整齐收好。',
                          action: OutlinedButton.icon(
                            onPressed: () => showAddMenu(context, app),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('添加第一件快递'),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : pending.isEmpty
              ? const QuietEmpty(
                  title: '没有找到匹配记录',
                  description: '试试站点名、取件码，或清除搜索。',
                  illustrated: false,
                )
              : RefreshIndicator(
                  onRefresh: app.reload,
                  child: ListView.builder(
                    key: const ValueKey('pending-list'),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: stations.length,
                    itemBuilder: (context, i) {
                      final station = stations[i];
                      final items = pending
                          .where((p) => p.station == station)
                          .toList();
                      switch (app.settings.sortMode) {
                        case 'codeAsc':
                          items.sort((a, b) => naturalCompare(a.code, b.code));
                          break;
                        case 'codeDesc':
                          items.sort((a, b) => naturalCompare(b.code, a.code));
                          break;
                        default:
                          items.sort(
                            (a, b) => b.arrivedAt.compareTo(a.arrivedAt),
                          );
                      }
                      final allSelected = items.every(
                        (p) => selected.contains(p.id),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Card(
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  8,
                                  10,
                                  12,
                                  4,
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: allSelected,
                                      onChanged: (_) => setState(() {
                                        if (allSelected) {
                                          selected.removeAll(
                                            items.map((p) => p.id),
                                          );
                                        } else {
                                          selected.addAll(
                                            items.map((p) => p.id),
                                          );
                                        }
                                      }),
                                    ),
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 17,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        station,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${items.length} 件',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              for (var j = 0; j < items.length; j++) ...[
                                if (j > 0)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: Divider(),
                                  ),
                                ParcelTile(
                                  parcel: items[j],
                                  selected: selected.contains(items[j].id),
                                  onSelected: () => setState(() {
                                    if (!selected.add(items[j].id)) {
                                      selected.remove(items[j].id);
                                    }
                                  }),
                                  onTap: () =>
                                      showParcelDetails(context, app, items[j]),
                                  onComplete: () => markWithUndo(context, app, [
                                    items[j],
                                  ], true),
                                ),
                              ],
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        if (selected.isNotEmpty) _selectionBar(app, pending),
      ],
    );
  }

  Widget _selectionBar(AppController app, List<Parcel> visible) {
    final items = app.pending.where((p) => selected.contains(p.id)).toList();
    final all =
        visible.isNotEmpty && visible.every((p) => selected.contains(p.id));
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: Row(
            children: [
              Checkbox(
                value: all,
                onChanged: (_) => setState(() {
                  if (all) {
                    selected.clear();
                  } else {
                    selected.addAll(visible.map((p) => p.id));
                  }
                }),
              ),
              Text(
                '选 ${items.length} 件',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              PopupMenuButton<bool>(
                tooltip: '分享取件信息',
                icon: const Icon(Icons.share_outlined),
                onSelected: (image) => runTask(
                  context,
                  () => app.shareParcels(items, asImage: image),
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: false, child: Text('分享文字')),
                  PopupMenuItem(value: true, child: Text('分享图片')),
                ],
              ),
              IconButton(
                tooltip: '移入回收站',
                onPressed: () => removeWithUndo(context, app, items),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
              FilledButton(
                key: const ValueKey('mark-selected-collected'),
                onPressed: () => markWithUndo(context, app, items, true),
                child: const Text('标记已取'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int naturalCompare(String a, String b) {
  final parts = RegExp(r'\d+|\D+');
  final aa = parts.allMatches(a).map((m) => m.group(0)!).toList();
  final bb = parts.allMatches(b).map((m) => m.group(0)!).toList();
  for (var i = 0; i < aa.length && i < bb.length; i++) {
    final x = int.tryParse(aa[i]);
    final y = int.tryParse(bb[i]);
    final result = x != null && y != null
        ? x.compareTo(y)
        : aa[i].compareTo(bb[i]);
    if (result != 0) return result;
  }
  return aa.length.compareTo(bb.length);
}

class ParcelTile extends StatelessWidget {
  const ParcelTile({
    super.key,
    required this.parcel,
    required this.onTap,
    this.selected,
    this.onSelected,
    this.onComplete,
    this.showStation = false,
  });
  final Parcel parcel;
  final bool? selected;
  final VoidCallback? onSelected;
  final VoidCallback? onComplete;
  final VoidCallback onTap;
  final bool showStation;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    onLongPress: onSelected,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: EdgeInsets.fromLTRB(selected != null ? 6 : 18, 12, 12, 12),
      child: Row(
        children: [
          if (selected != null)
            Checkbox(
              key: ValueKey('select-${parcel.id}'),
              value: selected,
              onChanged: (_) => onSelected?.call(),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showStation)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      parcel.station,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Text(
                  parcel.code.isEmpty ? '取件码待补充' : parcel.code,
                  style: TextStyle(
                    fontSize: parcel.code.length > 15 ? 22 : 29,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .7,
                    height: 1.15,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 7),
                if (parcel.detailAddress.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      parcel.detailAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                Text(
                  '${parcel.company.isEmpty ? '快递' : parcel.company} · ${dayLabel(parcel.arrivedAt)}到件${parcel.isCollected ? ' · 已取' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '复制取件码',
            onPressed: parcel.code.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: parcel.code));
                    notice(context, '已复制取件码');
                  },
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
          if (onComplete != null)
            IconButton(
              key: ValueKey('complete-${parcel.id}'),
              tooltip: '标记已取',
              onPressed: onComplete,
              icon: const Icon(Icons.check_circle_outline_rounded),
            ),
        ],
      ),
    ),
  );
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.app});
  final AppController app;
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime selectedDay = DateTime.now();
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String filter = 'all';
  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final dayItems =
        app.parcels
            .where(
              (p) =>
                  sameDay(p.arrivedAt, selectedDay) ||
                  (p.collectedAt != null &&
                      sameDay(p.collectedAt!, selectedDay)),
            )
            .where(
              (p) =>
                  filter == 'all' ||
                  (filter == 'pending' ? !p.isCollected : p.isCollected),
            )
            .toList()
          ..sort((a, b) => b.arrivedAt.compareTo(a.arrivedAt));
    final overdue = app.pending
        .where(
          (p) => DateTime(p.arrivedAt.year, p.arrivedAt.month, p.arrivedAt.day)
              .isBefore(
                DateTime.now().copyWith(
                  hour: 0,
                  minute: 0,
                  second: 0,
                  millisecond: 0,
                  microsecond: 0,
                ),
              ),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      children: [
        Text('取件日历', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 6),
        Text(
          '到件与已取，都有迹可循。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _stat(
              context,
              '待取件',
              app.pending.length,
              Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            _stat(
              context,
              '今日已取',
              app.collected
                  .where(
                    (p) =>
                        p.collectedAt != null &&
                        sameDay(p.collectedAt!, DateTime.now()),
                  )
                  .length,
              Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 12),
            _stat(
              context,
              '累计已取',
              app.collected.length,
              Theme.of(context).colorScheme.onSurface,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: '上个月',
                      onPressed: () => setState(
                        () => month = DateTime(month.year, month.month - 1),
                      ),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${month.year}年 ${month.month}月',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        selectedDay = DateTime.now();
                        month = DateTime(selectedDay.year, selectedDay.month);
                      }),
                      child: const Text('今天'),
                    ),
                    IconButton(
                      tooltip: '下个月',
                      onPressed: () => setState(
                        () => month = DateTime(month.year, month.month + 1),
                      ),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['一', '二', '三', '四', '五', '六', '日']
                      .map(
                        (day) => Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                _calendarGrid(app),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.circle, color: bamboo, size: 7),
                    const SizedBox(width: 5),
                    Text('到件', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 20),
                    const Icon(Icons.circle, color: gold, size: 7),
                    const SizedBox(width: 5),
                    Text('已取', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (overdue.isNotEmpty) ...[
          SectionTitle('跨日未取', subtitle: '${overdue.length} 件仍在等你，取完后可标记已取'),
          Card(
            child: Column(
              children: [
                for (final item in overdue)
                  ParcelTile(
                    parcel: item,
                    showStation: true,
                    onTap: () => showParcelDetails(context, app, item),
                    onComplete: () => markWithUndo(context, app, [item], true),
                  ),
              ],
            ),
          ),
        ],
        SectionTitle('${dayLabel(selectedDay)}的记录', subtitle: '按到件日或标记已取日显示'),
        Wrap(
          spacing: 8,
          children: [('all', '全部'), ('pending', '待取'), ('collected', '已取')]
              .map(
                (item) => ChoiceChip(
                  label: Text(item.$2),
                  selected: filter == item.$1,
                  onSelected: (_) => setState(() => filter = item.$1),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        if (dayItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: QuietEmpty(
              title: '这一天没有匹配记录',
              description: '跨日未取的快递会单独保留在上方。',
              illustrated: false,
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final item in dayItems)
                  ParcelTile(
                    parcel: item,
                    showStation: true,
                    onTap: () => showParcelDetails(context, app, item),
                    onComplete: item.isCollected
                        ? null
                        : () => markWithUndo(context, app, [item], true),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, int value, Color color) =>
      Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );

  Widget _calendarGrid(AppController app) {
    final offset = month.weekday - 1;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((offset + count) / 7).ceil() * 7;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 48,
      ),
      itemBuilder: (context, index) {
        final day = index - offset + 1;
        if (day < 1 || day > count) return const SizedBox.shrink();
        final date = DateTime(month.year, month.month, day);
        final isSelected = sameDay(date, selectedDay);
        final arrived = app.parcels.any((p) => sameDay(p.arrivedAt, date));
        final collected = app.parcels.any(
          (p) => p.collectedAt != null && sameDay(p.collectedAt!, date),
        );
        final today = sameDay(date, DateTime.now());
        return Semantics(
          label:
              '${dayLabel(date, year: true)}${arrived ? ' 有到件' : ''}${collected ? ' 有已取' : ''}',
          selected: isSelected,
          child: InkWell(
            onTap: () => setState(() => selectedDay = date),
            borderRadius: BorderRadius.circular(13),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : null,
                borderRadius: BorderRadius.circular(13),
                border: today && !isSelected
                    ? Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .5),
                      )
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$day',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected || today
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (arrived)
                        Icon(
                          Icons.circle,
                          size: 4,
                          color: isSelected ? Colors.white : bamboo,
                        ),
                      if (arrived && collected) const SizedBox(width: 3),
                      if (collected)
                        const Icon(Icons.circle, size: 4, color: gold),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

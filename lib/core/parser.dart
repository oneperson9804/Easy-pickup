import 'models.dart';

class ParsedParcel {
  const ParsedParcel({
    required this.station,
    required this.code,
    required this.company,
    required this.rawText,
  });
  final String station, code, company, rawText;
}

/// Only recognizes explicitly labelled pickup codes. Verification/marketing SMS
/// are never treated as parcels just because they contain digits.
ParsedParcel? parseParcelText(
  String text, {
  List<RecognitionRule> rules = const [],
}) {
  final cleaned = text.replaceAll('\u200b', '').replaceAll('：', ':').trim();
  final match = RegExp(
    r'(?:取件|提货|取货|领件|出库|提取)码\s*[:为是]?\s*([A-Za-z0-9][A-Za-z0-9\-－— ]{1,24})',
    caseSensitive: false,
  ).firstMatch(cleaned);
  if (match == null) return null;
  final code = match.group(1)!.trim().replaceAll(RegExp(r'[－—]'), '-');
  if (!RegExp(r'\d').hasMatch(code)) return null;
  String company = '';
  final heading = RegExp(r'【([^】]{1,20})】').firstMatch(cleaned)?.group(1);
  const companies = [
    '中通',
    '圆通',
    '申通',
    '韵达',
    '顺丰',
    '极兔',
    '邮政',
    'EMS',
    '京东',
    '德邦',
    '菜鸟',
    '百世',
    '丰网',
  ];
  for (final name in companies) {
    if ((heading ?? cleaned).contains(name)) {
      company = name;
      break;
    }
  }
  final stationMatch = RegExp(
    r'(?:已到达?|已放至?|送至|存放[于在]?|请到|已入库[至到]?|在)\s*([^，。；;！!\n]{2,60}?(?:菜鸟驿站|驿站|快递柜|丰巢|菜鸟柜|自提柜|服务站|代收点|快递站|超市|便利店|门卫室|门卫|收发室))',
  ).firstMatch(cleaned);
  String station = stationMatch?.group(1)?.trim() ?? '';
  if (station.isEmpty) {
    final fallback = RegExp(
      r'([^，。；;！!\n:]{1,32}(?:驿站|快递柜|丰巢|自提柜|代收点|超市|便利店|门卫室|收发室))',
    ).firstMatch(cleaned);
    station = fallback?.group(1)?.trim() ?? '待确认站点';
  }
  for (final rule in rules) {
    if (rule.pattern.isNotEmpty && cleaned.contains(rule.pattern)) {
      if (rule.kind == 'address') station = rule.replacement;
      if (rule.kind == 'company') company = rule.replacement;
    }
  }
  return ParsedParcel(
    station: station,
    code: code,
    company: company,
    rawText: text.trim(),
  );
}

List<String> splitImportText(String text) {
  final paragraphs = text.split(RegExp(r'\n\s*\n'));
  if (paragraphs.length > 1) {
    return paragraphs.where((s) => s.trim().isNotEmpty).toList();
  }
  final lines = text.split('\n').where((s) => s.trim().isNotEmpty).toList();
  if (lines.length > 1 && lines.every((s) => parseParcelText(s) != null)) {
    return lines;
  }
  return text.trim().isEmpty ? [] : [text];
}

int naturalCompare(String a, String b) {
  final parts = RegExp(r'\d+|\D+');
  final aa = parts.allMatches(a).map((m) => m.group(0)!).toList();
  final bb = parts.allMatches(b).map((m) => m.group(0)!).toList();
  for (var i = 0; i < aa.length && i < bb.length; i++) {
    final na = int.tryParse(aa[i]), nb = int.tryParse(bb[i]);
    final diff = na != null && nb != null
        ? na.compareTo(nb)
        : aa[i].compareTo(bb[i]);
    if (diff != 0) return diff;
  }
  return aa.length.compareTo(bb.length);
}

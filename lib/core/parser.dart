import 'models.dart';

class ParsedParcel {
  const ParsedParcel({
    required this.station,
    required this.code,
    required this.company,
    required this.rawText,
    this.detailAddress = '',
  });
  final String station, code, company, rawText, detailAddress;
}

const _stationSuffix =
    r'(?:快递综合服务站|快递服务中心|物流服务中心|校园服务站|快递服务站|菜鸟驿站|快递中心|物流中心|服务中心|驿站|快递柜|丰巢|菜鸟柜|自提柜|服务站|代收点|快递站|超市|便利店|门卫室|门卫|收发室)';
const _codeToken = r'[A-Za-z0-9]+(?:[ \t]*[-－—][ \t]*[A-Za-z0-9]+)*';
const _codeEnd = r'(?![A-Za-z0-9/@_－—-]|\.[A-Za-z0-9])';
final _labelledCode = RegExp(
  '(?:取件|提货|取货|领件|出库|提取)码(?:\\s*[为是])?\\s*[:：]?\\s*($_codeToken)$_codeEnd',
  caseSensitive: false,
);
final _codeLabel = RegExp(r'(?:取件|提货|取货|领件|出库|提取)码');
final _credentialCode = RegExp(
  '凭\\s*($_codeToken)$_codeEnd(?=\\s*(?:'
  '(?:到|至|在|前往)\\s*[^，。；;！!\\n]{1,80}?(?:取件|取货|领件|提货|(?:领取|提取|取)[^，。；;！!\\n]{0,12}?(?:尾号|包裹|快件|快递))'
  '|(?:到|至|在|前往)\\s*[^，。；;！!\\n]{1,60}?$_stationSuffix\\s*(?:取|领取)(?:[，。；;！!\\n]|\$)'
  '|(?:取件|取货|领件|提货)))',
  caseSensitive: false,
);
final _stationPattern = RegExp(
  '(?:已(?:经)?(?:送达|投递[至到]?|到达?|放[至在]?|入库[至到]?)|送达|送至|存放[于在]?|请(?:到|至)|前往|到)\\s*([^，。；;！!\\n:【】]{1,60}?$_stationSuffix)',
);
final _locatedStation = RegExp(
  '[在于]\\s*([^，。；;！!\\n:【】]{1,60}?$_stationSuffix)',
);
final _namedStation = RegExp(
  '(?:^|[，。；;！!\\n:】])\\s*([^，。；;！!\\n:【】]{1,60}?$_stationSuffix)',
);
const _addressStop =
    r'[，,。；;！!【】]|联系|咨询|电话|客服|热线|(?:取件|寄件)(?:和寄件)?(?:可)?咨询|(?:取件|提货|取货|领件|出库|提取)码|https?://|www\.|[A-Za-z0-9][A-Za-z0-9.-]*\.(?:cn|com|net|org)(?:/|\s|$)|(?:\+?86[- ]?)?1[3-9]\d{9}|0\d{2,3}[-－ ]?\d{7,8}';
final _addressPattern = RegExp(
  '(?:详细地址|取件地址|地址)\\s*[:：]\\s*([\\s\\S]*?)(?=$_addressStop|\$)',
  caseSensitive: false,
);
final _addressStopPattern = RegExp(_addressStop, caseSensitive: false);
final _addressContinuation = RegExp(
  r'^(?=.*(?:路|街|道|区|县|号|栋|楼|单元|室|村|镇|乡|校区|园区))[^，,。；;！!【】]{2,80}$',
);

String _detailAddress(String text) =>
    (_addressPattern.firstMatch(text)?.group(1) ?? '')
        .replaceAll(RegExp(r'[ \t]*\r?\n[ \t]*'), '')
        .trim();

bool _validCode(String code) =>
    code.length >= 2 &&
    code.length <= 24 &&
    RegExp(r'\d').hasMatch(code) &&
    RegExp(r'\d').allMatches(code).length <= 10 &&
    code.split('-').length <= 5 &&
    code.split('-').every((part) => part.length <= 10);

String _normalizeCode(String code) =>
    code.replaceAll(RegExp(r'[－—]'), '-').replaceAll(RegExp(r'\s'), '');

List<RegExpMatch> _pickupMatches(String text) {
  final matches = <RegExpMatch>[];
  for (final pattern in [_labelledCode, _credentialCode]) {
    for (final match in pattern.allMatches(text)) {
      if (_validCode(_normalizeCode(match.group(1)!))) matches.add(match);
    }
  }
  return matches..sort((a, b) => a.start.compareTo(b.start));
}

String? _pickupCode(String text) {
  final matches = _pickupMatches(text);
  return matches.isEmpty ? null : _normalizeCode(matches.first.group(1)!);
}

/// Pickup labels and credential-to-collection phrases identify codes; bare
/// numbers, tracking references and verification messages do not.
ParsedParcel? parseParcelText(
  String text, {
  List<RecognitionRule> rules = const [],
}) {
  final cleaned = text
      .replaceAll(RegExp(r'[\u200b-\u200d\ufeff]'), '')
      .replaceAll('：', ':')
      .trim();
  final code = _pickupCode(cleaned);
  if (code == null) return null;
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
  String station =
      (_stationPattern.firstMatch(cleaned)?.group(1) ??
              _locatedStation.firstMatch(cleaned)?.group(1) ??
              _namedStation.firstMatch(cleaned)?.group(1) ??
              '待确认站点')
          .trim();
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
    detailAddress: _detailAddress(cleaned),
  );
}

List<String> splitImportText(String text) {
  final result = <String>[];
  for (final paragraph
      in text.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'))) {
    final block = paragraph.trim();
    if (block.isEmpty) continue;
    final headings = RegExp(r'【[^】\n]{1,20}】').allMatches(block);
    var start = 0;
    for (final heading in headings) {
      if (heading.start > start) {
        result.addAll(_splitNoticeBlock(block.substring(start, heading.start)));
      }
      start = heading.start;
    }
    result.addAll(_splitNoticeBlock(block.substring(start)));
  }
  return result;
}

final _noticeContext = RegExp(
  r'【[^】]+】|(?:包裹|快件|快递).*(?:已|存放|送|到|取)|(?:已送达|已到|已投递|已入库|请到|请至|前往|地址[:：]|联系电话|取件码|提货码|取货码|领件码|出库码|提取码|请及时(?:取件|领取)|取件和寄件|取件咨询)',
);
List<String> _splitNoticeBlock(String text) {
  final block = text.trim();
  if (block.isEmpty) return [];
  final codes = _pickupMatches(block);
  final starts = [0];
  for (var i = 1; i < codes.length; i++) {
    var start = codes[i].start;
    final prefix = block.substring(starts.last, codes[i - 1].start);
    if (_stationPattern.hasMatch(prefix) ||
        _locatedStation.hasMatch(prefix) ||
        _namedStation.hasMatch(prefix)) {
      final between = block.substring(codes[i - 1].end, codes[i].start);
      final station =
          _stationPattern.firstMatch(between) ??
          _locatedStation.firstMatch(between);
      if (station != null) {
        final separator = RegExp(
          r'[，,。；;\n]',
        ).allMatches(between.substring(0, station.start)).lastOrNull;
        start = codes[i - 1].end + (separator?.end ?? 0);
      }
    }
    starts.add(start);
  }
  starts.add(block.length);
  return [
    for (var i = 0; i < starts.length - 1; i++)
      ..._groupNoticeUnits(block.substring(starts[i], starts[i + 1])),
  ];
}

List<String> _groupNoticeUnits(String text) {
  final block = text.trim();
  final result = <String>[];
  var pending = '';
  var pendingEnd = 0;
  void flush() {
    if (pending.trim().isNotEmpty) result.add(pending.trim());
    pending = '';
  }

  final units = RegExp(r'[^。；;\n]+[。；;]?(?:\n|$)?|[。；;](?:\n|$)?');
  for (final match in units.allMatches(block)) {
    final unit = match.group(0)!.trim();
    if (unit.isEmpty) continue;
    final recognized = parseParcelText(unit) != null;
    final pendingRecognized = parseParcelText(pending) != null;
    final codeLine =
        RegExp('^$_codeToken$_codeEnd\$').hasMatch(unit) &&
        _validCode(_normalizeCode(unit));
    final context =
        _noticeContext.hasMatch(unit) ||
        (codeLine && !pendingRecognized && _codeLabel.hasMatch(pending)) ||
        (_addressPattern.firstMatch(pending)?.end == pending.length &&
            _addressContinuation.hasMatch(unit) &&
            !_addressStopPattern.hasMatch(unit));
    if (pendingRecognized && (recognized || _codeLabel.hasMatch(unit))) {
      flush();
    }
    if (!recognized && !context) {
      flush();
      result.add(unit);
    } else {
      pending += pending.isEmpty
          ? match.group(0)!
          : block.substring(pendingEnd, match.start) + match.group(0)!;
      pendingEnd = match.end;
    }
  }
  flush();
  return result;
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

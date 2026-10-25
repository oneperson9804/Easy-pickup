import 'models.dart';
import 'parser.dart';

class ImportCandidate {
  const ImportCandidate({required this.rawText, this.parcel, this.duplicate});
  final String rawText;
  final Parcel? parcel;
  final Parcel? duplicate;
}

String normalizedNotice(String text) => text
    .replaceAll(RegExp(r'[\s\u200b\uFEFF]+'), '')
    .replaceAll(RegExp('[－—–﹣]'), '-');

String? _tail(String text) {
  final explicit = RegExp(
    r'(?:包裹|快件|运单)(?:号码?)?尾号[：:\s]*([0-9]{4})(?![0-9])',
  ).firstMatch(text);
  if (explicit != null) return explicit.group(1);
  for (final match in RegExp(
    r'尾号[：:\s]*([0-9]{4})(?![0-9])',
  ).allMatches(text)) {
    final prefix = text.substring(0, match.start);
    if (!RegExp(r'(?:手机|手机号|电话|联系号码)[：:\s]*$').hasMatch(prefix)) {
      return match.group(1);
    }
  }
  return null;
}

Parcel? duplicateOf(Parcel candidate, Iterable<Parcel> existing) {
  for (final old in existing) {
    if (old.deletedAt != null ||
        candidate.arrivedAt.difference(old.arrivedAt).abs() >
            const Duration(days: 7)) {
      continue;
    }
    if (candidate.rawText.isNotEmpty &&
        normalizedNotice(candidate.rawText) == normalizedNotice(old.rawText)) {
      return old;
    }
    final tail = _tail(candidate.rawText), oldTail = _tail(old.rawText);
    if (tail != null && oldTail != null && tail != oldTail) continue;
    if (!old.isCollected &&
        candidate.code.isNotEmpty &&
        candidate.code == old.code &&
        candidate.station != '待确认站点' &&
        candidate.station == old.station &&
        (candidate.company.isEmpty ||
            old.company.isEmpty ||
            candidate.company == old.company)) {
      return old;
    }
  }
  return null;
}

List<ImportCandidate> reviewImport(
  String text, {
  required Iterable<Parcel> existing,
  List<RecognitionRule> rules = const [],
  String source = 'paste',
  DateTime? now,
}) {
  final seen = existing.toList();
  return splitImportText(text).map((chunk) {
    final parsed = parseParcelText(chunk, rules: rules);
    if (parsed == null) return ImportCandidate(rawText: chunk);
    final parcel = Parcel(
      id: newId(),
      station: parsed.station,
      code: parsed.code,
      company: parsed.company,
      detailAddress: parsed.detailAddress,
      rawText: parsed.rawText,
      arrivedAt: now ?? DateTime.now(),
      source: source,
    );
    final duplicate = duplicateOf(parcel, seen);
    seen.add(parcel);
    return ImportCandidate(
      rawText: chunk,
      parcel: parcel,
      duplicate: duplicate,
    );
  }).toList();
}

Parcel? completeNoticeMetadata(Parcel parcel, List<RecognitionRule> rules) {
  if (parcel.source == 'manual' || parcel.rawText.isEmpty) return null;
  if (!['待确认站点', '未识别站点', ''].contains(parcel.station)) return null;
  final parsed = parseParcelText(parcel.rawText, rules: rules);
  if (parsed == null || parsed.code != parcel.code) return null;
  final next = parcel.copyWith(
    station: ['待确认站点', '未识别站点', ''].contains(parcel.station)
        ? parsed.station
        : parcel.station,
    company: parcel.company.isEmpty ? parsed.company : parcel.company,
    detailAddress: parcel.detailAddress.isEmpty
        ? parsed.detailAddress
        : parcel.detailAddress,
  );
  return next.station != parcel.station ||
          next.company != parcel.company ||
          next.detailAddress != parcel.detailAddress
      ? next
      : null;
}

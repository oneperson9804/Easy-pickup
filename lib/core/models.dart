import 'dart:convert';

const Object _keep = Object();

class Parcel {
  const Parcel({
    required this.id,
    required this.station,
    required this.code,
    this.company = '',
    this.rawText = '',
    this.detailAddress = '',
    required this.arrivedAt,
    this.collectedAt,
    this.deletedAt,
    this.source = 'manual',
    this.sourceKey,
  });
  final String id, station, code, company, rawText, source, detailAddress;
  final String? sourceKey;
  final DateTime arrivedAt;
  final DateTime? collectedAt, deletedAt;
  bool get isCollected => collectedAt != null;
  Parcel copyWith({
    String? id,
    String? station,
    String? code,
    String? company,
    String? rawText,
    String? detailAddress,
    DateTime? arrivedAt,
    Object? collectedAt = _keep,
    Object? deletedAt = _keep,
    String? source,
    Object? sourceKey = _keep,
  }) => Parcel(
    id: id ?? this.id,
    station: station ?? this.station,
    code: code ?? this.code,
    company: company ?? this.company,
    rawText: rawText ?? this.rawText,
    detailAddress: detailAddress ?? this.detailAddress,
    arrivedAt: arrivedAt ?? this.arrivedAt,
    collectedAt: identical(collectedAt, _keep)
        ? this.collectedAt
        : collectedAt as DateTime?,
    deletedAt: identical(deletedAt, _keep)
        ? this.deletedAt
        : deletedAt as DateTime?,
    source: source ?? this.source,
    sourceKey: identical(sourceKey, _keep)
        ? this.sourceKey
        : sourceKey as String?,
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'station': station,
    'code': code,
    'company': company,
    'raw_text': rawText,
    'detail_address': detailAddress,
    'arrived_at': arrivedAt.millisecondsSinceEpoch,
    'collected_at': collectedAt?.millisecondsSinceEpoch,
    'deleted_at': deletedAt?.millisecondsSinceEpoch,
    'source': source,
    'source_key': sourceKey,
  };
  factory Parcel.fromMap(Map<String, dynamic> m) => Parcel(
    id: m['id'] as String,
    station: m['station'] as String,
    code: m['code'] as String,
    company: m['company'] as String? ?? '',
    rawText: m['raw_text'] as String? ?? '',
    detailAddress: m['detail_address'] as String? ?? '',
    arrivedAt: DateTime.fromMillisecondsSinceEpoch(
      (m['arrived_at'] as num).toInt(),
    ),
    collectedAt: m['collected_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (m['collected_at'] as num).toInt(),
          ),
    deletedAt: m['deleted_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch((m['deleted_at'] as num).toInt()),
    source: m['source'] as String? ?? 'backup',
    sourceKey: m['source_key'] as String?,
  );
}

class SavedCode {
  const SavedCode({
    required this.id,
    required this.label,
    required this.value,
    this.format = 'qr',
    required this.createdAt,
  });
  final String id, label, value, format;
  final DateTime createdAt;
  Map<String, Object?> toMap() => {
    'id': id,
    'label': label,
    'value': value,
    'format': format,
    'created_at': createdAt.millisecondsSinceEpoch,
  };
  factory SavedCode.fromMap(Map<String, dynamic> m) => SavedCode(
    id: m['id'] as String,
    label: m['label'] as String,
    value: m['value'] as String,
    format: m['format'] as String? ?? 'qr',
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (m['created_at'] as num).toInt(),
    ),
  );
}

class RecognitionRule {
  const RecognitionRule({
    required this.id,
    required this.kind,
    required this.pattern,
    required this.replacement,
  });
  final String id, kind, pattern, replacement;
  Map<String, Object?> toMap() => {
    'id': id,
    'kind': kind,
    'pattern': pattern,
    'replacement': replacement,
  };
  factory RecognitionRule.fromMap(Map<String, dynamic> m) => RecognitionRule(
    id: m['id'] as String,
    kind: m['kind'] as String,
    pattern: m['pattern'] as String,
    replacement: m['replacement'] as String,
  );
}

class AppSettings {
  const AppSettings({
    this.themeMode = 'system',
    this.sortMode = 'arrival',
    this.stationOrder = const [],
    this.widgetStyle = 'jade',
    this.widgetShowCodes = true,
    this.reminderEnabled = false,
    this.reminderHour = 18,
    this.reminderMinute = 0,
    this.reminderWeekdays = const [1, 2, 3, 4, 5, 6, 7],
    this.smsLookbackDays = 30,
  });
  final String themeMode, sortMode, widgetStyle;
  final List<String> stationOrder;
  final bool widgetShowCodes, reminderEnabled;
  final int reminderHour, reminderMinute, smsLookbackDays;
  final List<int> reminderWeekdays;
  AppSettings copyWith({
    String? themeMode,
    String? sortMode,
    List<String>? stationOrder,
    String? widgetStyle,
    bool? widgetShowCodes,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    List<int>? reminderWeekdays,
    int? smsLookbackDays,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    sortMode: sortMode ?? this.sortMode,
    stationOrder: stationOrder ?? this.stationOrder,
    widgetStyle: widgetStyle ?? this.widgetStyle,
    widgetShowCodes: widgetShowCodes ?? this.widgetShowCodes,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    reminderWeekdays: reminderWeekdays ?? this.reminderWeekdays,
    smsLookbackDays: smsLookbackDays ?? this.smsLookbackDays,
  );
  Map<String, dynamic> toMap() => {
    'themeMode': themeMode,
    'sortMode': sortMode,
    'stationOrder': stationOrder,
    'widgetStyle': widgetStyle,
    'widgetShowCodes': widgetShowCodes,
    'reminderEnabled': reminderEnabled,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'reminderWeekdays': reminderWeekdays,
    'smsLookbackDays': smsLookbackDays,
  };
  factory AppSettings.fromMap(Map<String, dynamic> m) => AppSettings(
    themeMode: m['themeMode'] as String? ?? 'system',
    sortMode: m['sortMode'] as String? ?? 'arrival',
    stationOrder: (m['stationOrder'] as List?)?.cast<String>() ?? const [],
    widgetStyle: m['widgetStyle'] as String? ?? 'jade',
    widgetShowCodes: m['widgetShowCodes'] as bool? ?? true,
    reminderEnabled: m['reminderEnabled'] as bool? ?? false,
    reminderHour: (m['reminderHour'] as num?)?.toInt() ?? 18,
    reminderMinute: (m['reminderMinute'] as num?)?.toInt() ?? 0,
    reminderWeekdays:
        (m['reminderWeekdays'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        const [1, 2, 3, 4, 5, 6, 7],
    smsLookbackDays: (m['smsLookbackDays'] as num?)?.toInt() ?? 30,
  );
}

class ImportResult {
  const ImportResult({
    this.added = 0,
    this.duplicates = 0,
    this.unrecognized = 0,
  });
  final int added, duplicates, unrecognized;
  factory ImportResult.fromMap(Map<dynamic, dynamic> m) => ImportResult(
    added: (m['added'] as num?)?.toInt() ?? 0,
    duplicates: (m['duplicates'] as num?)?.toInt() ?? 0,
    unrecognized: (m['unrecognized'] as num?)?.toInt() ?? 0,
  );
  @override
  String toString() => '导入 $added 条，重复 $duplicates 条，未识别 $unrecognized 条';
}

class AppSnapshot {
  const AppSnapshot({
    this.parcels = const [],
    this.codes = const [],
    this.rules = const [],
    this.settings = const AppSettings(),
  });
  final List<Parcel> parcels;
  final List<SavedCode> codes;
  final List<RecognitionRule> rules;
  final AppSettings settings;
  Map<String, dynamic> toMap() => {
    'format': 'easy-pickup',
    'schemaVersion': 1,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'parcels': parcels.map((p) => p.toMap()).toList(),
    'codes': codes.map((c) => c.toMap()).toList(),
    'rules': rules.map((r) => r.toMap()).toList(),
    'settings': settings.toMap(),
  };
  String toJson() => const JsonEncoder.withIndent('  ').convert(toMap());
  factory AppSnapshot.fromMap(Map<String, dynamic> m) {
    if (m['format'] != 'easy-pickup' || m['schemaVersion'] != 1) {
      throw const FormatException('不是易取件 v1 备份文件，请选择正确的 JSON 文件');
    }
    return AppSnapshot(
      parcels: (m['parcels'] as List)
          .map((e) => Parcel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      codes: (m['codes'] as List? ?? [])
          .map((e) => SavedCode.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      rules: (m['rules'] as List? ?? [])
          .map(
            (e) => RecognitionRule.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      settings: AppSettings.fromMap(
        Map<String, dynamic>.from(m['settings'] as Map? ?? {}),
      ),
    );
  }
}

String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
int _sequence = 0;

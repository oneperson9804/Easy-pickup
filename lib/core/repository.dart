import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../services/platform_services.dart';
import 'models.dart';

const databaseSchema = <String>[
  "CREATE TABLE IF NOT EXISTS parcels(id TEXT PRIMARY KEY,station TEXT NOT NULL,code TEXT NOT NULL,company TEXT NOT NULL DEFAULT '',raw_text TEXT NOT NULL DEFAULT '',detail_address TEXT NOT NULL DEFAULT '',arrived_at INTEGER NOT NULL,collected_at INTEGER,deleted_at INTEGER,source TEXT NOT NULL DEFAULT 'manual',source_key TEXT UNIQUE)",
  'CREATE INDEX IF NOT EXISTS parcels_state ON parcels(deleted_at,collected_at,arrived_at)',
  "CREATE TABLE IF NOT EXISTS saved_codes(id TEXT PRIMARY KEY,label TEXT NOT NULL,value TEXT NOT NULL,format TEXT NOT NULL DEFAULT 'qr',created_at INTEGER NOT NULL)",
  'CREATE TABLE IF NOT EXISTS rules(id TEXT PRIMARY KEY,kind TEXT NOT NULL,pattern TEXT NOT NULL,replacement TEXT NOT NULL)',
  'CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)',
];

/// SQLite is the device record source. The browser preview persists the same
/// snapshot locally; it never requests mobile-only permissions.
class ParcelRepository {
  ParcelRepository._({Database? database, SharedPreferences? preferences})
    : _db = database,
      _preferences = preferences;
  final Database? _db;
  final SharedPreferences? _preferences;
  AppSnapshot _browser = const AppSnapshot();
  String? _browserDraft;

  Future<String?> loadDraft() async {
    if (_db case final db?) {
      final rows = await db.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['incomingDraft'],
      );
      return rows.isEmpty
          ? null
          : jsonDecode(rows.single['value'] as String) as String?;
    }
    return _browserDraft;
  }

  Future<String?> lastSharedId() async {
    if (_db case final db?) {
      final rows = await db.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['lastSharedId'],
      );
      return rows.isEmpty
          ? null
          : jsonDecode(rows.single['value'] as String) as String?;
    }
    return null;
  }

  Future<void> saveDraft(String? value, {String? incomingId}) async {
    if (_db case final db?) {
      await db.transaction((tx) async {
        await tx.insert('settings', {
          'key': 'incomingDraft',
          'value': jsonEncode(value),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        if (incomingId != null) {
          await tx.insert('settings', {
            'key': 'lastSharedId',
            'value': jsonEncode(incomingId),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } else {
      _browserDraft = value;
    }
  }

  static Future<ParcelRepository> open(PlatformServices platform) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final repository = ParcelRepository._(preferences: prefs);
      final saved = prefs.getString('easy_pickup_snapshot');
      if (saved != null) {
        repository._browser = AppSnapshot.fromMap(
          jsonDecode(saved) as Map<String, dynamic>,
        );
      }
      return repository;
    }
    final path = await platform.databasePath();
    final db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA busy_timeout=5000');
      },
      onCreate: (db, version) async {
        for (final statement in databaseSchema) {
          await db.execute(statement);
        }
      },
      onOpen: (db) async {
        for (final statement in databaseSchema) {
          await db.execute(statement);
        }
      },
    );
    return ParcelRepository._(database: db);
  }

  @visibleForTesting
  static Future<ParcelRepository> forDatabase(Database db) async {
    for (final statement in databaseSchema) {
      await db.execute(statement);
    }
    return ParcelRepository._(database: db);
  }

  Future<AppSnapshot> load() async {
    final db = _db;
    if (db == null) return _browser;
    final rows = await db.query('parcels', orderBy: 'arrived_at DESC');
    final codeRows = await db.query('saved_codes', orderBy: 'created_at DESC');
    final ruleRows = await db.query('rules', orderBy: 'rowid ASC');
    final settingRows = await db.query('settings');
    return AppSnapshot(
      parcels: rows.map(Parcel.fromMap).toList(),
      codes: codeRows.map(SavedCode.fromMap).toList(),
      rules: ruleRows.map(RecognitionRule.fromMap).toList(),
      settings: AppSettings.fromMap({
        for (final row in settingRows)
          row['key'] as String: jsonDecode(row['value'] as String),
      }),
    );
  }

  Future<void> _persistBrowser() async {
    final success = await _preferences!.setString(
      'easy_pickup_snapshot',
      _browser.toJson(),
    );
    if (!success) throw StateError('浏览器未能保存数据，请导出备份后检查可用空间');
  }

  Future<void> putParcel(Parcel parcel) async {
    if (_db case final db?) {
      await db.transaction((tx) async {
        final updated = await tx.update(
          'parcels',
          parcel.toMap(),
          where: 'id = ?',
          whereArgs: [parcel.id],
        );
        if (updated == 0) await tx.insert('parcels', parcel.toMap());
      });
    } else {
      final values = _browser.parcels.where((p) => p.id != parcel.id).toList()
        ..add(parcel);
      _browser = AppSnapshot(
        parcels: values,
        codes: _browser.codes,
        rules: _browser.rules,
        settings: _browser.settings,
      );
      await _persistBrowser();
    }
  }

  Future<void> setCollected(Iterable<String> ids, bool collected) =>
      _setDates(ids, 'collected_at', collected ? DateTime.now() : null);
  Future<void> restoreCollectionState(List<Parcel> previous) async {
    if (_db case final db?) {
      await db.transaction((tx) async {
        final batch = tx.batch();
        for (final parcel in previous) {
          batch.update(
            'parcels',
            {'collected_at': parcel.collectedAt?.millisecondsSinceEpoch},
            where: 'id = ?',
            whereArgs: [parcel.id],
          );
        }
        await batch.commit(noResult: true);
      });
    } else {
      final values = {
        for (final parcel in previous) parcel.id: parcel.collectedAt,
      };
      _browser = AppSnapshot(
        parcels: _browser.parcels
            .map(
              (p) => values.containsKey(p.id)
                  ? p.copyWith(collectedAt: values[p.id])
                  : p,
            )
            .toList(),
        codes: _browser.codes,
        rules: _browser.rules,
        settings: _browser.settings,
      );
      await _persistBrowser();
    }
  }

  Future<void> setDeleted(Iterable<String> ids, bool deleted) =>
      _setDates(ids, 'deleted_at', deleted ? DateTime.now() : null);
  Future<void> _setDates(
    Iterable<String> ids,
    String column,
    DateTime? date,
  ) async {
    final selected = ids.toSet();
    if (selected.isEmpty) return;
    if (_db case final db?) {
      // A transaction and bound IDs work for any batch size without SQLite's
      // bound-parameter limit or partial status updates.
      await db.transaction((tx) async {
        final batch = tx.batch();
        for (final id in selected) {
          batch.update(
            'parcels',
            {column: date?.millisecondsSinceEpoch},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        await batch.commit(noResult: true);
      });
    } else {
      _browser = AppSnapshot(
        parcels: _browser.parcels
            .map(
              (p) => selected.contains(p.id)
                  ? column == 'collected_at'
                        ? p.copyWith(collectedAt: date)
                        : p.copyWith(deletedAt: date)
                  : p,
            )
            .toList(),
        codes: _browser.codes,
        rules: _browser.rules,
        settings: _browser.settings,
      );
      await _persistBrowser();
    }
  }

  Future<void> emptyTrash() async {
    if (_db case final db?) {
      await db.delete('parcels', where: 'deleted_at IS NOT NULL');
    } else {
      _browser = AppSnapshot(
        parcels: _browser.parcels.where((p) => p.deletedAt == null).toList(),
        codes: _browser.codes,
        rules: _browser.rules,
        settings: _browser.settings,
      );
      await _persistBrowser();
    }
  }

  Future<void> putCode(SavedCode code) async {
    if (_db case final db?) {
      await db.insert(
        'saved_codes',
        code.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      _browser = AppSnapshot(
        parcels: _browser.parcels,
        codes: [..._browser.codes.where((c) => c.id != code.id), code],
        rules: _browser.rules,
        settings: _browser.settings,
      );
      await _persistBrowser();
    }
  }

  Future<void> deleteCode(String id) async {
    if (_db case final db?) {
      await db.delete('saved_codes', where: 'id = ?', whereArgs: [id]);
    } else {
      _browser = AppSnapshot(
        parcels: _browser.parcels,
        codes: _browser.codes.where((c) => c.id != id).toList(),
        rules: _browser.rules,
        settings: _browser.settings,
      );
      await _persistBrowser();
    }
  }

  Future<void> putRule(RecognitionRule rule) async {
    if (_db case final db?) {
      await db.insert(
        'rules',
        rule.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      _browser = AppSnapshot(
        parcels: _browser.parcels,
        codes: _browser.codes,
        rules: [..._browser.rules.where((r) => r.id != rule.id), rule],
        settings: _browser.settings,
      );
      await _persistBrowser();
    }
  }

  Future<void> deleteRule(String id) async {
    if (_db case final db?) {
      await db.delete('rules', where: 'id = ?', whereArgs: [id]);
    } else {
      _browser = AppSnapshot(
        parcels: _browser.parcels,
        codes: _browser.codes,
        rules: _browser.rules.where((r) => r.id != id).toList(),
        settings: _browser.settings,
      );
      await _persistBrowser();
    }
  }

  Future<void> putSettings(AppSettings settings) async {
    if (_db case final db?) {
      await db.transaction((tx) async {
        for (final entry in settings.toMap().entries) {
          await tx.insert('settings', {
            'key': entry.key,
            'value': jsonEncode(entry.value),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } else {
      _browser = AppSnapshot(
        parcels: _browser.parcels,
        codes: _browser.codes,
        rules: _browser.rules,
        settings: settings,
      );
      await _persistBrowser();
    }
  }

  /// Merge a fully validated backup atomically; preserve existing records and
  /// source IDs instead of replacing user data with a foreign file.
  Future<ImportResult> merge(AppSnapshot incoming) async {
    final old = await load();
    final ids = old.parcels.map((p) => p.id).toSet();
    final sources = old.parcels
        .map((p) => p.sourceKey)
        .whereType<String>()
        .toSet();
    final additions = <Parcel>[];
    var duplicates = 0;
    for (final parcel in incoming.parcels) {
      if (ids.contains(parcel.id) ||
          (parcel.sourceKey != null && sources.contains(parcel.sourceKey))) {
        duplicates++;
        continue;
      }
      additions.add(parcel);
      ids.add(parcel.id);
      if (parcel.sourceKey != null) sources.add(parcel.sourceKey!);
    }
    if (_db case final db?) {
      await db.transaction((tx) async {
        final batch = tx.batch();
        for (final parcel in additions) {
          batch.insert('parcels', parcel.toMap());
        }
        for (final code in incoming.codes) {
          batch.insert(
            'saved_codes',
            code.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        for (final rule in incoming.rules) {
          batch.insert(
            'rules',
            rule.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        for (final entry in incoming.settings.toMap().entries) {
          batch.insert('settings', {
            'key': entry.key,
            'value': jsonEncode(entry.value),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      });
    } else {
      _browser = AppSnapshot(
        parcels: [...old.parcels, ...additions],
        codes: [
          ...old.codes,
          ...incoming.codes.where((c) => !old.codes.any((o) => o.id == c.id)),
        ],
        rules: [
          ...old.rules,
          ...incoming.rules.where((r) => !old.rules.any((o) => o.id == r.id)),
        ],
        settings: incoming.settings,
      );
      await _persistBrowser();
    }
    return ImportResult(added: additions.length, duplicates: duplicates);
  }
}

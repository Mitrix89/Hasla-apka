import '../models/password_entry.dart';
import '../models/payment.dart';

/// Dane wymieniane podczas synchronizacji.
class SyncData {
  SyncData({required this.passwords, required this.payments, required this.deleted});

  final List<PasswordEntry> passwords;
  final List<Payment> payments;

  /// Usunięte wpisy: id → kiedy usunięto. Dzięki temu usunięcie na jednym
  /// urządzeniu nie „wraca” z drugiego przy następnej synchronizacji.
  final Map<String, DateTime> deleted;

  Map<String, dynamic> toJson() => {
        'passwords': passwords.map((e) => e.toJson()).toList(),
        'payments': payments.map((p) => p.toJson()).toList(),
        'deleted': deleted.map((k, v) => MapEntry(k, v.toUtc().toIso8601String())),
      };

  factory SyncData.fromJson(Map<String, dynamic> json) => SyncData(
        passwords: ((json['passwords'] as List?) ?? const [])
            .map((e) => PasswordEntry.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        payments: ((json['payments'] as List?) ?? const [])
            .map((e) => Payment.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        deleted: decodeTombstones(json['deleted']),
      );
}

Map<String, DateTime> decodeTombstones(Object? raw) {
  if (raw is! Map) return {};
  final out = <String, DateTime>{};
  raw.forEach((k, v) {
    final d = DateTime.tryParse('$v');
    if (d != null) out['$k'] = d.toLocal();
  });
  return out;
}

/// Co zmieniła synchronizacja na tym urządzeniu.
class SyncStats {
  const SyncStats({this.added = 0, this.updated = 0, this.removed = 0});
  final int added;
  final int updated;
  final int removed;
  bool get nothingChanged => added == 0 && updated == 0 && removed == 0;
}

/// Ile trzymać informacje o usuniętych wpisach.
const tombstoneTtl = Duration(days: 365);

/// Scala dane z dwóch urządzeń: dla każdego wpisu wygrywa nowsza zmiana,
/// a usunięcie wygrywa z każdą starszą zmianą.
({SyncData merged, SyncStats stats}) mergeSyncData(SyncData local, SyncData remote, {DateTime? now}) {
  final cutoff = (now ?? DateTime.now()).subtract(tombstoneTtl);
  final deleted = <String, DateTime>{};
  for (final e in [...local.deleted.entries, ...remote.deleted.entries]) {
    if (e.value.isBefore(cutoff)) continue;
    final prev = deleted[e.key];
    if (prev == null || e.value.isAfter(prev)) deleted[e.key] = e.value;
  }

  var added = 0, updated = 0, removed = 0;

  List<T> mergeList<T>(List<T> a, List<T> b, String Function(T) id, DateTime Function(T) at) {
    final localById = {for (final x in a) id(x): x};
    final result = <String, T>{...localById};
    for (final x in b) {
      final cur = result[id(x)];
      if (cur == null || at(x).isAfter(at(cur))) result[id(x)] = x;
    }
    result.removeWhere((key, x) {
      final d = deleted[key];
      return d != null && !at(x).isAfter(d);
    });
    for (final entry in result.entries) {
      final before = localById[entry.key];
      if (before == null) {
        added++;
      } else if (!at(before).isAtSameMomentAs(at(entry.value))) {
        updated++;
      }
    }
    removed += localById.keys.where((k) => !result.containsKey(k)).length;
    return result.values.toList();
  }

  final passwords = mergeList<PasswordEntry>(local.passwords, remote.passwords, (e) => e.id, (e) => e.updatedAt);
  final payments = mergeList<Payment>(local.payments, remote.payments, (p) => p.id, (p) => p.updatedAt);
  return (
    merged: SyncData(passwords: passwords, payments: payments, deleted: deleted),
    stats: SyncStats(added: added, updated: updated, removed: removed),
  );
}

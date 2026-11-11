import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/password_entry.dart';
import '../models/payment.dart';
import 'vault_crypto.dart';
import 'vault_store.dart';

enum VaultStatus { loading, needsSetup, locked, unlocked }

/// Wynik importu haseł z innej aplikacji.
class ImportResult {
  const ImportResult({required this.added, required this.skipped});
  final int added;

  /// Pominięte, bo identyczny wpis już był w sejfie.
  final int skipped;
}

/// Trzyma stan sejfu: zablokowany / odblokowany, lista haseł i zapis na dysk.
class VaultController extends ChangeNotifier {
  VaultController(this._store, {KdfParams Function()? freshParams})
      : _freshParams = freshParams ?? KdfParams.fresh;

  final VaultStore _store;
  final KdfParams Function() _freshParams;

  VaultStatus _status = VaultStatus.loading;
  VaultStatus get status => _status;

  Uint8List? _key;
  KdfParams? _params;
  List<PasswordEntry> _entries = [];
  List<Payment> _payments = [];

  /// Dane, których ta wersja aplikacji nie zna, zachowywane przy zapisie bez zmian.
  Map<String, dynamic> _otherData = {};
  Future<void> _pendingSave = Future.value();

  /// Hasła posortowane alfabetycznie.
  List<PasswordEntry> get entries {
    final list = List<PasswordEntry>.of(_entries);
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Opłaty posortowane po najbliższym terminie.
  List<Payment> get payments {
    final list = List<Payment>.of(_payments);
    list.sort((a, b) {
      final c = a.dueDate.compareTo(b.dueDate);
      return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  /// Klucz odblokowanego sejfu (do zapamiętania pod odciskiem palca).
  Uint8List? get key => _key == null ? null : Uint8List.fromList(_key!);

  Future<void> init() async {
    final raw = await _store.read();
    _status = raw == null ? VaultStatus.needsSetup : VaultStatus.locked;
    notifyListeners();
  }

  /// Tworzy nowy, pusty sejf zabezpieczony hasłem głównym.
  Future<void> create(String masterPassword) async {
    final params = _freshParams();
    _key = await VaultCrypto.deriveKey(masterPassword, params);
    _params = params;
    _entries = [];
    _payments = [];
    _otherData = {};
    _status = VaultStatus.unlocked;
    await _save();
    notifyListeners();
  }

  /// Odblokowuje sejf hasłem głównym. Zwraca false, gdy hasło jest błędne.
  Future<bool> unlock(String masterPassword) async {
    final envelope = await _readEnvelope();
    final params = VaultCrypto.readParams(envelope);
    final key = await VaultCrypto.deriveKey(masterPassword, params);
    return _open(envelope, key, params);
  }

  /// Odblokowuje sejf zapamiętanym kluczem (po odcisku palca).
  Future<bool> unlockWithKey(Uint8List key) async {
    final envelope = await _readEnvelope();
    return _open(envelope, key, VaultCrypto.readParams(envelope));
  }

  Future<bool> _open(Map<String, dynamic> envelope, Uint8List key, KdfParams params) async {
    final Map<String, dynamic> data;
    try {
      data = await VaultCrypto.decrypt(envelope, key);
    } on WrongPasswordException {
      return false;
    }
    _entries = ((data['passwords'] as List?) ?? const [])
        .map((e) => PasswordEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    _payments = ((data['payments'] as List?) ?? const [])
        .map((e) => Payment.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    _otherData = Map.of(data)
      ..remove('passwords')
      ..remove('payments');
    _key = key;
    _params = params;
    _status = VaultStatus.unlocked;
    final rolled = _rollSubscriptions(DateTime.now());
    notifyListeners();
    if (rolled) await _save();
    return true;
  }

  /// Zmienia hasło główne. Wymaga podania obecnego.
  Future<bool> changeMasterPassword(String current, String next) async {
    final envelope = await _readEnvelope();
    final oldParams = VaultCrypto.readParams(envelope);
    final oldKey = await VaultCrypto.deriveKey(current, oldParams);
    try {
      await VaultCrypto.decrypt(envelope, oldKey);
    } on WrongPasswordException {
      return false;
    }
    final params = _freshParams();
    _key = await VaultCrypto.deriveKey(next, params);
    _params = params;
    await _save();
    return true;
  }

  /// Zamyka sejf i usuwa hasła oraz klucz z pamięci.
  Future<void> lock() async {
    if (_status != VaultStatus.unlocked) return;
    await _pendingSave;
    _key = null;
    _entries = [];
    _payments = [];
    _otherData = {};
    _status = VaultStatus.locked;
    notifyListeners();
  }

  PasswordEntry? byId(String id) {
    for (final e in _entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<void> upsert(PasswordEntry entry) async {
    _requireUnlocked();
    final i = _entries.indexWhere((e) => e.id == entry.id);
    if (i == -1) {
      _entries.add(entry);
    } else {
      _entries[i] = entry;
    }
    notifyListeners();
    await _save();
  }

  Future<void> delete(String id) async {
    _requireUnlocked();
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
    await _save();
  }

  Payment? paymentById(String id) {
    for (final p in _payments) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> upsertPayment(Payment payment) async {
    _requireUnlocked();
    final i = _payments.indexWhere((p) => p.id == payment.id);
    if (i == -1) {
      _payments.add(payment);
    } else {
      _payments[i] = payment;
    }
    notifyListeners();
    await _save();
  }

  Future<void> deletePayment(String id) async {
    _requireUnlocked();
    _payments.removeWhere((p) => p.id == id);
    notifyListeners();
    await _save();
  }

  /// Oznacza termin jako zapłacony / załatwiony: powtarzająca się pozycja przechodzi
  /// na kolejny termin, jednorazowa znika.
  Future<void> markPaid(String id) async {
    _requireUnlocked();
    final p = paymentById(id);
    if (p == null) return;
    final next = p.nextDueDate();
    if (next == null) {
      _payments.removeWhere((x) => x.id == id);
    } else {
      _payments[_payments.indexOf(p)] = p.copyWith(dueDate: next);
    }
    notifyListeners();
    await _save();
  }

  /// Subskrypcje pobierają się same, więc ich termin przesuwa się automatycznie.
  /// Rachunki i przypomnienia czekają, aż oznaczysz je jako zapłacone.
  bool _rollSubscriptions(DateTime today) {
    var changed = false;
    for (var i = 0; i < _payments.length; i++) {
      final p = _payments[i];
      if (p.kind != PaymentKind.subscription) continue;
      final r = p.rolledForward(today);
      if (!identical(r, p)) {
        _payments[i] = r;
        changed = true;
      }
    }
    return changed;
  }

  /// Dodaje hasła z importu, pomijając wpisy, które już są w sejfie.
  Future<ImportResult> importEntries(List<PasswordEntry> incoming) async {
    _requireUnlocked();
    String sig(PasswordEntry e) => jsonEncode([
          e.username,
          e.password,
          ([...e.websites]..sort()),
          ([...e.apps]..sort()),
        ]);
    final known = _entries.map(sig).toSet();
    var added = 0;
    var skipped = 0;
    for (final e in incoming) {
      if (known.add(sig(e))) {
        _entries.add(e);
        added++;
      } else {
        skipped++;
      }
    }
    if (added > 0) {
      notifyListeners();
      await _save();
    }
    return ImportResult(added: added, skipped: skipped);
  }

  void _requireUnlocked() {
    if (_status != VaultStatus.unlocked || _key == null) {
      throw StateError('Sejf jest zablokowany');
    }
  }

  Future<Map<String, dynamic>> _readEnvelope() async {
    final raw = await _store.read();
    if (raw == null) throw const VaultFormatException('brak pliku sejfu');
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } on FormatException catch (e) {
      throw VaultFormatException(e.message);
    }
  }

  /// Zapisy idą po kolei, żeby szybkie zmiany nie nadpisały się nawzajem.
  Future<void> _save() {
    final key = _key!;
    final params = _params!;
    final data = <String, dynamic>{
      ..._otherData,
      'passwords': _entries.map((e) => e.toJson()).toList(),
      'payments': _payments.map((p) => p.toJson()).toList(),
    };
    _pendingSave = _pendingSave.then((_) async {
      final envelope = await VaultCrypto.encrypt(data, key, params);
      await _store.write(jsonEncode(envelope));
    });
    return _pendingSave;
  }
}

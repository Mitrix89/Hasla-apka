import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hasla_apka/models/password_entry.dart';
import 'package:hasla_apka/models/payment.dart';
import 'package:hasla_apka/vault/vault_controller.dart';
import 'package:hasla_apka/vault/vault_crypto.dart';
import 'package:hasla_apka/vault/vault_store.dart';

VaultController make(MemoryVaultStore store) =>
    VaultController(store, freshParams: () => KdfParams.fresh(memoryKiB: 256, iterations: 1));

PasswordEntry entry(String id, String name, {String user = 'jan', String pass = 'p'}) =>
    PasswordEntry(id: id, name: name, username: user, password: pass, websites: ['$name.pl']);

void main() {
  test('nowy sejf: setup, zapis, blokada i ponowne otwarcie', () async {
    final store = MemoryVaultStore();
    final vault = make(store);
    await vault.init();
    expect(vault.status, VaultStatus.needsSetup);

    await vault.create('Haslo-Glowne-123');
    expect(vault.status, VaultStatus.unlocked);
    await vault.upsert(entry('1', 'Netflix', pass: 'Kino!2026'));
    await vault.upsert(entry('2', 'allegro'));

    // Na dysku nie ma jawnego tekstu.
    expect(store.contents, isNot(contains('Kino!2026')));
    expect(store.contents, isNot(contains('Netflix')));

    await vault.lock();
    expect(vault.status, VaultStatus.locked);
    expect(vault.entries, isEmpty);
    expect(vault.key, isNull);

    final reopened = make(store);
    await reopened.init();
    expect(reopened.status, VaultStatus.locked);
    expect(await reopened.unlock('zle haslo'), isFalse);
    expect(reopened.status, VaultStatus.locked);
    expect(await reopened.unlock('Haslo-Glowne-123'), isTrue);
    expect(reopened.entries.map((e) => e.name), ['allegro', 'Netflix']);
    expect(reopened.byId('1')!.password, 'Kino!2026');
  });

  test('edycja i usuwanie', () async {
    final store = MemoryVaultStore();
    final vault = make(store);
    await vault.create('Haslo-Glowne-123');
    await vault.upsert(entry('1', 'Steam'));
    await vault.upsert(vault.byId('1')!.copyWith(password: 'nowe', apps: ['Steam']));
    expect(vault.entries.single.password, 'nowe');
    expect(vault.entries.single.hasApp, isTrue);
    await vault.delete('1');
    expect(vault.entries, isEmpty);
  });

  test('odblokowanie zapamiętanym kluczem', () async {
    final store = MemoryVaultStore();
    final vault = make(store);
    await vault.create('Haslo-Glowne-123');
    await vault.upsert(entry('1', 'Bank'));
    final key = vault.key!;
    await vault.lock();
    expect(await vault.unlockWithKey(key), isTrue);
    expect(vault.entries.single.name, 'Bank');
  });

  test('zmiana hasła głównego', () async {
    final store = MemoryVaultStore();
    final vault = make(store);
    await vault.create('Stare-Haslo-123');
    await vault.upsert(entry('1', 'Gmail'));
    final oldKey = vault.key!;
    expect(await vault.changeMasterPassword('zle', 'Nowe-Haslo-456'), isFalse);
    expect(await vault.changeMasterPassword('Stare-Haslo-123', 'Nowe-Haslo-456'), isTrue);
    await vault.lock();
    expect(await vault.unlock('Stare-Haslo-123'), isFalse);
    expect(await vault.unlockWithKey(oldKey), isFalse);
    expect(await vault.unlock('Nowe-Haslo-456'), isTrue);
    expect(vault.entries.single.name, 'Gmail');
  });

  test('import pomija duplikaty', () async {
    final vault = make(MemoryVaultStore());
    await vault.create('Haslo-Glowne-123');
    await vault.upsert(entry('1', 'Netflix'));
    final result = await vault.importEntries([
      entry('a', 'Netflix'), // taki sam login, hasło i strona
      entry('b', 'Vectra'),
      entry('c', 'Vectra'), // duplikat w samym pliku
    ]);
    expect(result.added, 1);
    expect(result.skipped, 2);
    expect(vault.entries.length, 2);
  });

  test('nieznane dane w sejfie (np. z nowszej wersji) nie giną przy zapisie', () async {
    final store = MemoryVaultStore();
    final vault = make(store);
    await vault.create('Haslo-Glowne-123');
    final key = vault.key!;
    final env = jsonDecode(store.contents!) as Map<String, dynamic>;
    final params = VaultCrypto.readParams(env);
    store.contents = jsonEncode(await VaultCrypto.encrypt({
      'passwords': [],
      'sync': {'device': 'telefon'},
    }, key, params));
    await vault.lock();
    await vault.unlock('Haslo-Glowne-123');
    await vault.upsert(entry('1', 'Bank'));
    final data = await VaultCrypto.decrypt(jsonDecode(store.contents!) as Map<String, dynamic>, key);
    expect(data['sync'], {'device': 'telefon'});
    expect((data['passwords'] as List).length, 1);
  });

  test('operacje na zablokowanym sejfie są niedozwolone', () async {
    final vault = make(MemoryVaultStore());
    await vault.init();
    expect(() => vault.upsert(entry('1', 'x')), throwsStateError);
  });

  test('opłaty: zapis, odczyt, zapłacone i usuwanie', () async {
    final store = MemoryVaultStore();
    final vault = make(store);
    await vault.create('Haslo-Glowne-123');
    final future = DateTime.now().add(const Duration(days: 10));
    await vault.upsertPayment(Payment(
      id: 'oc', name: 'Ubezpieczenie OC', kind: PaymentKind.reminder,
      dueDate: future, repeat: Repeat.yearly, amountCents: 124000, remindDaysBefore: 30,
    ));
    await vault.upsertPayment(Payment(
      id: 'jed', name: 'Mandat', kind: PaymentKind.bill, dueDate: future, repeat: Repeat.once,
    ));
    expect(store.contents, isNot(contains('Ubezpieczenie')));

    await vault.lock();
    await vault.unlock('Haslo-Glowne-123');
    expect(vault.payments.length, 2);

    await vault.markPaid('oc');
    expect(vault.paymentById('oc')!.dueDate, addMonths(dateOnly(future), 12));
    await vault.markPaid('jed');
    expect(vault.paymentById('jed'), isNull);
    await vault.deletePayment('oc');
    expect(vault.payments, isEmpty);
  });

  test('przy odblokowaniu subskrypcje przechodzą na kolejny termin, rachunki czekają', () async {
    final store = MemoryVaultStore();
    final vault = make(store);
    await vault.create('Haslo-Glowne-123');
    final past = dateOnly(DateTime.now()).subtract(const Duration(days: 40));
    await vault.upsertPayment(Payment(id: 's', name: 'Netflix', kind: PaymentKind.subscription, dueDate: past));
    await vault.upsertPayment(Payment(id: 'b', name: 'Prąd', kind: PaymentKind.bill, dueDate: past));
    await vault.lock();
    await vault.unlock('Haslo-Glowne-123');
    expect(vault.paymentById('s')!.dueDate.isBefore(dateOnly(DateTime.now())), isFalse);
    expect(vault.paymentById('b')!.dueDate, past);
  });
}

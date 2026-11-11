import 'package:flutter_test/flutter_test.dart';
import 'package:hasla_apka/models/category.dart';
import 'package:hasla_apka/models/password_entry.dart';
import 'package:hasla_apka/sync/sync_merge.dart';
import 'package:hasla_apka/vault/vault_controller.dart';
import 'package:hasla_apka/vault/vault_crypto.dart';
import 'package:hasla_apka/vault/vault_store.dart';

VaultController make(MemoryVaultStore store) =>
    VaultController(store, freshParams: () => KdfParams.fresh(memoryKiB: 256, iterations: 1));

void main() {
  test('wpis pamięta kategorie w JSON, a stary zapis bez nich też się wczytuje', () {
    final e = PasswordEntry(id: '1', name: 'Bank', categoryIds: ['k1', 'k2']);
    expect(PasswordEntry.fromJson(e.toJson()).categoryIds, ['k1', 'k2']);
    expect(PasswordEntry.fromJson({'id': '2', 'name': 'Stary'}).categoryIds, isEmpty);
  });

  test('kategorie: tworzenie, przypisanie, zmiana nazwy, usunięcie i zapis na dysku', () async {
    final store = MemoryVaultStore();
    final vault = make(store);
    await vault.init();
    await vault.create('Haslo-Glowne-123');

    await vault.upsertCategory(PasswordCategory(id: 'k-praca', name: 'Praca'));
    await vault.upsertCategory(PasswordCategory(id: 'k-bank', name: 'bank'));
    expect(vault.categories.map((c) => c.name), ['bank', 'Praca']);

    await vault.upsert(PasswordEntry(id: 'p1', name: 'mBank'));
    await vault.setEntryCategories('p1', ['k-bank', 'k-praca']);
    await vault.upsertCategory(vault.categoryById('k-bank')!.rename('Banki'));

    await vault.lock();
    final reopened = make(store);
    await reopened.init();
    expect(await reopened.unlock('Haslo-Glowne-123'), isTrue);
    expect(reopened.categories.map((c) => c.name), ['Banki', 'Praca']);
    expect(reopened.byId('p1')!.categoryIds, ['k-bank', 'k-praca']);

    // Usunięcie kategorii zostawia hasło, ale zdejmuje je z kategorii.
    await reopened.deleteCategory('k-praca');
    expect(reopened.categoryById('k-praca'), isNull);
    expect(reopened.byId('p1'), isNotNull);
    expect(reopened.byId('p1')!.categoryIds, ['k-bank']);
    expect(reopened.syncSnapshot().deleted.keys, contains('k-praca'));
  });

  test('synchronizacja scala kategorie i uwzględnia ich usunięcie', () {
    final t0 = DateTime(2026, 11, 1);
    final t1 = DateTime(2026, 11, 2);
    final local = SyncData(
      passwords: [],
      payments: [],
      categories: [
        PasswordCategory(id: 'a', name: 'Praca', updatedAt: t0),
        PasswordCategory(id: 'b', name: 'Gry', updatedAt: t0),
      ],
      deleted: {},
    );
    final remote = SyncData(
      passwords: [],
      payments: [],
      categories: [
        PasswordCategory(id: 'a', name: 'Praca i szkoła', updatedAt: t1),
        PasswordCategory(id: 'c', name: 'Bank', updatedAt: t0),
      ],
      deleted: {'b': t1},
    );
    final merged = mergeSyncData(local, remote, now: DateTime(2026, 11, 3)).merged;
    final byId = {for (final c in merged.categories) c.id: c.name};
    expect(byId, {'a': 'Praca i szkoła', 'c': 'Bank'});

    final back = SyncData.fromJson(merged.toJson());
    expect(back.categories.map((c) => c.id).toSet(), {'a', 'c'});
  });
}

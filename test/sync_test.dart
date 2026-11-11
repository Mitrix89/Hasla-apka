import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hasla_apka/models/password_entry.dart';
import 'package:hasla_apka/models/payment.dart';
import 'package:hasla_apka/sync/sync_code.dart';
import 'package:hasla_apka/sync/sync_merge.dart';
import 'package:hasla_apka/sync/sync_service.dart';
import 'package:hasla_apka/vault/vault_controller.dart';
import 'package:hasla_apka/vault/vault_crypto.dart';
import 'package:hasla_apka/vault/vault_store.dart';

PasswordEntry pw(String id, String name, DateTime at, {String pass = 'p'}) =>
    PasswordEntry(id: id, name: name, password: pass, createdAt: at, updatedAt: at);

Future<VaultController> vault(String master) async {
  final v = VaultController(MemoryVaultStore(), freshParams: () => KdfParams.fresh(memoryKiB: 256, iterations: 1));
  await v.create(master);
  return v;
}

void main() {
  group('kod parowania', () {
    test('zapis i odczyt (QR i tekst, małe litery, spacje)', () {
      final code = SyncCode.generate(InternetAddress('192.168.1.23'), 50123);
      for (final input in [code.qrText, code.text, code.text.toLowerCase(), code.text.replaceAll('-', ' ')]) {
        final back = SyncCode.tryParse(input)!;
        expect(back.address.address, '192.168.1.23');
        expect(back.port, 50123);
        expect(back.secret, code.secret);
      }
      expect(code.text.length, lessThan(36));
    });

    test('literówka jest wykrywana', () {
      final code = SyncCode.generate(InternetAddress('10.0.0.5'), 4000);
      final t = code.text;
      final typo = (t[0] == 'A' ? 'B' : 'A') + t.substring(1);
      expect(SyncCode.tryParse(typo), isNull);
      expect(SyncCode.tryParse('ABC'), isNull);
      expect(SyncCode.tryParse(''), isNull);
    });
  });

  group('scalanie', () {
    final t0 = DateTime(2026, 11, 1);
    final t1 = DateTime(2026, 11, 2);
    final t2 = DateTime(2026, 11, 3);

    test('nowsza zmiana wygrywa, nowe wpisy dochodzą z obu stron', () {
      final local = SyncData(passwords: [pw('a', 'Netflix', t1, pass: 'stare'), pw('b', 'Bank', t0)], payments: [], deleted: {});
      final remote = SyncData(passwords: [pw('a', 'Netflix', t2, pass: 'nowe'), pw('c', 'Steam', t0)], payments: [], deleted: {});
      final r = mergeSyncData(local, remote, now: t2);
      final byId = {for (final p in r.merged.passwords) p.id: p};
      expect(byId.keys.toSet(), {'a', 'b', 'c'});
      expect(byId['a']!.password, 'nowe');
      expect((r.stats.added, r.stats.updated, r.stats.removed), (1, 1, 0));

      // Starsza zmiana z drugiej strony nie nadpisuje nowszej.
      final back = mergeSyncData(remote, local, now: t2);
      expect({for (final p in back.merged.passwords) p.id: p}['a']!.password, 'nowe');
    });

    test('usunięcie wygrywa ze starszą wersją, ale nie z późniejszą edycją', () {
      final local = SyncData(passwords: [], payments: [], deleted: {'a': t1, 'b': t1});
      final remote = SyncData(passwords: [pw('a', 'Stare', t0), pw('b', 'Edytowane później', t2)], payments: [], deleted: {});
      final r = mergeSyncData(local, remote, now: t2);
      expect(r.merged.passwords.map((p) => p.id), ['b']);
      expect(r.merged.deleted.keys.toSet(), {'a', 'b'});
      final other = mergeSyncData(remote, local, now: t2);
      expect(other.merged.passwords.map((p) => p.id), ['b']);
      expect(other.stats.removed, 1);
    });

    test('bardzo stare informacje o usunięciu są czyszczone', () {
      final r = mergeSyncData(
        SyncData(passwords: [], payments: [], deleted: {'x': DateTime(2024, 1, 1)}),
        SyncData(passwords: [], payments: [], deleted: {}),
        now: DateTime(2026, 11, 1),
      );
      expect(r.merged.deleted, isEmpty);
    });

    test('opłaty scalają się tak samo', () {
      final p1 = Payment(id: 'n', name: 'Netflix', kind: PaymentKind.subscription, dueDate: DateTime(2026, 12, 15), amountCents: 4900, updatedAt: t0);
      final p2 = Payment(id: 'n', name: 'Netflix', kind: PaymentKind.subscription, dueDate: DateTime(2026, 12, 15), amountCents: 5900, updatedAt: t2);
      final r = mergeSyncData(
        SyncData(passwords: [], payments: [p1], deleted: {}),
        SyncData(passwords: [], payments: [p2], deleted: {}),
        now: t2,
      );
      expect(r.merged.payments.single.amountCents, 5900);
    });
  });

  test('synchronizacja przez sieć między dwoma sejfami', () async {
    final phone = await vault('Telefon-Haslo-123');
    final pc = await vault('Komputer-Haslo-456');
    await phone.upsert(PasswordEntry(id: '1', name: 'Netflix', password: 'z-telefonu'));
    await phone.upsert(PasswordEntry(id: 'x', name: 'Do usunięcia'));
    await pc.upsert(PasswordEntry(id: '2', name: 'Steam', password: 'z-komputera'));
    await pc.upsertPayment(Payment(
      id: 'oc', name: 'OC', kind: PaymentKind.reminder, repeat: Repeat.yearly,
      dueDate: DateTime.now().add(const Duration(days: 30)),
    ));

    // Pierwsza synchronizacja: komputer pokazuje kod, telefon się łączy.
    var host = await SyncHost.start(
      merge: pc.mergeFromRemote,
      advertise: InternetAddress.loopbackIPv4,
      bindAddress: InternetAddress.loopbackIPv4,
    );
    var merged = await syncWithHost(host.code, phone.syncSnapshot());
    final phoneStats = await phone.applySynced(merged);
    final pcStats = await host.done;
    expect((phoneStats.added, pcStats.added), (2, 2));

    for (final v in [phone, pc]) {
      expect(v.entries.map((e) => e.name).toSet(), {'Netflix', 'Steam', 'Do usunięcia'});
      expect(v.payments.single.name, 'OC');
    }

    // Usunięcie na telefonie trafia na komputer.
    await phone.delete('x');
    host = await SyncHost.start(
      merge: pc.mergeFromRemote,
      advertise: InternetAddress.loopbackIPv4,
      bindAddress: InternetAddress.loopbackIPv4,
    );
    merged = await syncWithHost(host.code, phone.syncSnapshot());
    await phone.applySynced(merged);
    expect((await host.done).removed, 1);
    expect(pc.entries.map((e) => e.name).toSet(), {'Netflix', 'Steam'});

    // Dane przetrwały ponowne otwarcie sejfu (zapisane zaszyfrowane hasłem głównym komputera).
    await pc.lock();
    expect(await pc.unlock('Komputer-Haslo-456'), isTrue);
    expect(pc.entries.length, 2);
  });

  test('zły kod jest odrzucany, a host czeka dalej', () async {
    final pc = await vault('Komputer-Haslo-456');
    final phone = await vault('Telefon-Haslo-123');
    final host = await SyncHost.start(
      merge: pc.mergeFromRemote,
      advertise: InternetAddress.loopbackIPv4,
      bindAddress: InternetAddress.loopbackIPv4,
    );
    final wrong = SyncCode(address: host.code.address, port: host.code.port, secret: SyncCode.generate(host.code.address, 1).secret);
    await expectLater(syncWithHost(wrong, phone.syncSnapshot()), throwsA(isA<SyncException>()));
    await syncWithHost(host.code, phone.syncSnapshot());
    await host.done;
  });

  test('brak drugiego urządzenia daje czytelny błąd', () async {
    final phone = await vault('Telefon-Haslo-123');
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    final code = SyncCode.generate(InternetAddress.loopbackIPv4, port);
    await expectLater(syncWithHost(code, phone.syncSnapshot()), throwsA(isA<SyncException>()));
  });
}

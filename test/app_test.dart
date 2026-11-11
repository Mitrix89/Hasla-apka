import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasla_apka/app.dart';
import 'package:hasla_apka/models/password_entry.dart';
import 'package:hasla_apka/vault/vault_controller.dart';
import 'package:hasla_apka/vault/vault_crypto.dart';
import 'package:hasla_apka/vault/vault_store.dart';

void main() {
  late VaultController unlocked;

  setUp(() async {
    unlocked = VaultController(
      MemoryVaultStore(),
      freshParams: () => KdfParams.fresh(memoryKiB: 256, iterations: 1),
    );
    await unlocked.create('Haslo-Glowne-123');
    await unlocked.upsert(PasswordEntry(id: '1', name: 'Netflix', username: 'jan', websites: ['netflix.com']));
    await unlocked.upsert(PasswordEntry(id: '2', name: 'Bank', username: 'ola', apps: ['Bank']));
  });

  testWidgets('pierwsze uruchomienie pokazuje ustawienie hasła głównego', (tester) async {
    final vault = VaultController(MemoryVaultStore());
    await vault.init();
    await tester.pumpWidget(HaslaApp(controller: vault));
    expect(find.text('Ustaw hasło główne'), findsOneWidget);
    expect(find.text('Utwórz sejf'), findsOneWidget);
  });

  testWidgets('odblokowany sejf: start, lista haseł, wyszukiwanie', (tester) async {
    final vault = unlocked;
    await tester.pumpWidget(HaslaApp(controller: vault));
    expect(find.text('Co chcesz otworzyć?'), findsOneWidget);
    expect(find.text('2 zapisane hasła'), findsOneWidget);

    await tester.tap(find.text('Hasła'));
    await tester.pumpAndSettle();
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Bank'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'netf');
    await tester.pump();
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Bank'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.tap(find.text('Aplikacje'));
    await tester.pump();
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text('Netflix'), findsNothing);
  });
}

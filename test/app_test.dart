import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasla_apka/app.dart';
import 'package:hasla_apka/models/category.dart';
import 'package:hasla_apka/models/password_entry.dart';
import 'package:hasla_apka/models/payment.dart';
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
    final today = dateOnly(DateTime.now());
    await unlocked.upsertPayment(Payment(
      id: 'n', name: 'Netflix', kind: PaymentKind.subscription,
      dueDate: today.add(const Duration(days: 5)), amountCents: 4900, remindDaysBefore: 1,
    ));
    await unlocked.upsertPayment(Payment(
      id: 'oc', name: 'Ubezpieczenie OC', kind: PaymentKind.reminder, repeat: Repeat.yearly,
      dueDate: today.add(const Duration(days: 20)), amountCents: 124000, remindDaysBefore: 30,
    ));
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

  testWidgets('opłaty: przypomnienie na starcie, suma, lista i kalendarz', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(HaslaApp(controller: unlocked));
    expect(find.text('Ubezpieczenie OC za 20 dni'), findsOneWidget);
    expect(find.textContaining('49,00'), findsOneWidget);

    await tester.tap(find.text('Opłaty i przypomnienia'));
    await tester.pumpAndSettle();
    expect(find.text('Stałe opłaty miesięcznie'), findsOneWidget);
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Ubezpieczenie OC'), findsOneWidget);

    await tester.tap(find.text('Przypomnienia'));
    await tester.pump();
    expect(find.text('Netflix'), findsNothing);

    await tester.tap(find.byTooltip('Kalendarz'));
    await tester.pumpAndSettle();
    expect(find.text('Nadchodzące terminy (90 dni)'), findsOneWidget);
  });

  testWidgets('kategorie: „Dodaj do” w haśle i filtr na liście', (tester) async {
    final vault = unlocked;
    await tester.runAsync(() => vault.upsertCategory(PasswordCategory(id: 'k1', name: 'Finanse')));
    await tester.pumpWidget(HaslaApp(controller: vault));
    await tester.tap(find.text('Hasła'));
    await tester.pumpAndSettle();
    expect(find.text('Finanse'), findsOneWidget);

    await tester.tap(find.text('Bank'));
    await tester.pumpAndSettle();
    expect(find.text('Bez kategorii'), findsOneWidget);
    await tester.ensureVisible(find.text('Dodaj do…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dodaj do…'));
    await tester.pumpAndSettle();
    expect(find.text('Nowa kategoria'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Finanse'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Gotowe'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(vault.byId('2')!.categoryIds, ['k1']);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Finanse'));
    await tester.pump();
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text('Netflix'), findsNothing);
  });
}

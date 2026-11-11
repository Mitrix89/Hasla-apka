import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hasla_apka/import/bank_csv.dart';
import 'package:hasla_apka/import/csv.dart';
import 'package:hasla_apka/models/payment.dart';

void main() {
  test('odczyt Windows-1250 z polskimi znakami', () {
    // "Płatność" w cp1250: P, 0xB3 (ł), a, t, n, o, 0x9C (ś), 0xE6 (ć)
    expect(decodeBankFile([0x50, 0xB3, 0x61, 0x74, 0x6E, 0x6F, 0x9C, 0xE6]), 'Płatność');
    expect(decodeBankFile(utf8.encode('zażółć')), 'zażółć');
  });

  test('daty w różnych formatach', () {
    expect(parseBankDate('2026-10-15'), DateTime(2026, 10, 15));
    expect(parseBankDate('15.10.2026'), DateTime(2026, 10, 15));
    expect(parseBankDate('15-10-2026'), DateTime(2026, 10, 15));
    expect(parseBankDate('cokolwiek'), isNull);
  });

  test('wyciąg z nagłówkiem po kilku liniach i średnikami (styl mBanku)', () {
    const csv = 'mBank S.A.;\n'
        '#Za okres:;01.05.2026;31.10.2026;\n'
        '\n'
        '#Data operacji;#Opis operacji;#Rachunek;#Kategoria;#Kwota;\n'
        '2026-10-15;"NETFLIX.COM  AMSTERDAM";"eKonto";"Rozrywka";-49,00 PLN;\n'
        '2026-10-03;"Wynagrodzenie";"eKonto";"Wpływy";5 000,00 PLN;\n';
    final t = parseBankCsv(csv);
    expect(t.length, 2);
    expect(t.first.date, DateTime(2026, 10, 15));
    expect(t.first.amountCents, -4900);
    expect(t.first.description, contains('NETFLIX'));
    expect(t.last.amountCents, 500000);
  });

  test('wyciąg z przecinkami (styl PKO)', () {
    const csv = '"Data operacji","Data waluty","Typ transakcji","Kwota","Waluta","Opis transakcji"\n'
        '"2026-10-20","2026-10-20","Polecenie zapłaty","-89.00","PLN","Odbiorca: VECTRA S.A."\n';
    final t = parseBankCsv(csv).single;
    expect(t.amountCents, -8900);
    expect(t.description, contains('VECTRA'));
  });

  test('plik bez kolumn daty i kwoty jest odrzucany', () {
    expect(() => parseBankCsv('a;b\n1;2'), throwsA(isA<CsvImportException>()));
  });

  group('wykrywanie stałych płatności', () {
    final today = DateTime(2026, 11, 11);
    List<BankTransaction> monthly(String desc, int cents, int day, int months, {int lastMonth = 10}) => [
          for (var m = lastMonth - months + 1; m <= lastMonth; m++)
            BankTransaction(date: DateTime(2026, m, day), amountCents: -cents, description: desc),
        ];

    test('Netflix co miesiąc, Vectra co miesiąc, OC co rok', () {
      final found = findRecurringPayments([
        ...monthly('NETFLIX.COM AMSTERDAM NL', 4900, 15, 6),
        ...monthly('Polecenie zapłaty VECTRA S.A. faktura 123/2026', 8900, 20, 4),
        BankTransaction(date: DateTime(2025, 12, 9), amountCents: -118000, description: 'PZU ubezpieczenie OC polisa 1'),
        BankTransaction(date: DateTime(2024, 12, 9), amountCents: -112000, description: 'PZU ubezpieczenie OC polisa 2'),
        BankTransaction(date: DateTime(2026, 10, 1), amountCents: 500000, description: 'Wynagrodzenie'),
      ], today: today);
      final byName = {for (final c in found) c.name: c};

      expect(byName['Netflix']!.repeat, Repeat.monthly);
      expect(byName['Netflix']!.amountCents, 4900);
      expect(byName['Netflix']!.kind, PaymentKind.subscription);
      expect(byName['Netflix']!.nextDue, DateTime(2026, 11, 15));
      expect(byName['Netflix']!.occurrences, 6);

      expect(byName['Vectra']!.kind, PaymentKind.bill);
      expect(byName['Vectra']!.nextDue, DateTime(2026, 11, 20));

      expect(byName['Ubezpieczenie']!.repeat, Repeat.yearly);
      expect(byName['Ubezpieczenie']!.nextDue, DateTime(2026, 12, 9));

      expect(found.map((c) => c.name), isNot(contains('Wynagrodzenie')));
    });

    test('jednorazowy zakup i nieregularne zakupy w sklepie są pomijane', () {
      final found = findRecurringPayments([
        BankTransaction(date: DateTime(2026, 10, 2), amountCents: -2500, description: 'Kino Helios'),
        BankTransaction(date: DateTime(2026, 9, 1), amountCents: -12000, description: 'BIEDRONKA 1234 KRAKOW'),
        BankTransaction(date: DateTime(2026, 10, 1), amountCents: -4300, description: 'BIEDRONKA 1234 KRAKOW'),
        BankTransaction(date: DateTime(2026, 10, 30), amountCents: -27100, description: 'BIEDRONKA 1234 KRAKOW'),
      ], today: today);
      expect(found, isEmpty);
    });

    test('nieznany odbiorca z równą kwotą co miesiąc jest wykrywany', () {
      final found = findRecurringPayments(monthly('Siłownia FitZone abonament', 12900, 5, 3), today: today);
      expect(found.single.name, 'Siłownia Fitzone Abonament');
      expect(found.single.nextDue, DateTime(2026, 12, 5));
    });

    test('rachunek o zmiennej kwocie od znanego dostawcy (prąd) jest wykrywany', () {
      final found = findRecurringPayments([
        BankTransaction(date: DateTime(2026, 6, 10), amountCents: -15000, description: 'TAURON Sprzedaż'),
        BankTransaction(date: DateTime(2026, 8, 10), amountCents: -21000, description: 'TAURON Sprzedaż'),
        BankTransaction(date: DateTime(2026, 10, 10), amountCents: -18000, description: 'TAURON Sprzedaż'),
      ], today: today);
      // co 2 miesiące to nie jest żaden ze wspieranych cykli
      expect(found, isEmpty);
      final monthlyFound = findRecurringPayments([
        for (final (m, a) in [(7, 15000), (8, 21000), (9, 18000), (10, 16000)])
          BankTransaction(date: DateTime(2026, m, 10), amountCents: -a, description: 'TAURON Sprzedaż'),
      ], today: today);
      expect(monthlyFound.single.name, 'Tauron (prąd)');
      expect(monthlyFound.single.amountCents, 18333);
    });
  });
}

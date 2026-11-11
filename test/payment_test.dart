import 'package:flutter_test/flutter_test.dart';
import 'package:hasla_apka/models/payment.dart';
import 'package:hasla_apka/util/format.dart';
import 'package:hasla_apka/util/reminders.dart';

Payment pay(
  String name,
  DateTime due, {
  PaymentKind kind = PaymentKind.subscription,
  Repeat repeat = Repeat.monthly,
  int? amount,
  int remind = 3,
}) =>
    Payment(id: name, name: name, kind: kind, dueDate: due, repeat: repeat, amountCents: amount, remindDaysBefore: remind);

void main() {
  group('daty', () {
    test('dodawanie miesięcy przycina dzień do długości miesiąca', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
      expect(addMonths(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
      expect(addMonths(DateTime(2026, 2, 28), 1, 31), DateTime(2026, 3, 31));
    });

    test('płatność z 31. wraca na 31. po krótkim miesiącu', () {
      final p = pay('x', DateTime(2026, 1, 31));
      expect(p.occurrences().take(4).toList(), [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
      ]);
      final next = p.copyWith(dueDate: p.nextDueDate());
      expect(next.nextDueDate(), DateTime(2026, 3, 31));
    });

    test('jednorazowa płatność nie ma kolejnego terminu', () {
      final p = pay('x', DateTime(2026, 5, 1), repeat: Repeat.once);
      expect(p.nextDueDate(), isNull);
      expect(p.occurrences().toList(), [DateTime(2026, 5, 1)]);
    });

    test('przesunięcie terminu z przeszłości na najbliższy przyszły', () {
      final p = pay('Netflix', DateTime(2026, 8, 15));
      expect(p.rolledForward(DateTime(2026, 11, 11)).dueDate, DateTime(2026, 11, 15));
      expect(p.rolledForward(DateTime(2026, 11, 16)).dueDate, DateTime(2026, 12, 15));
      final future = pay('x', DateTime(2026, 12, 1));
      expect(identical(future.rolledForward(DateTime(2026, 11, 11)), future), isTrue);
    });
  });

  test('suma miesięczna: miesięczne całe, kwartalne /3, roczne osobno', () {
    expect(pay('a', DateTime(2026), amount: 4900).monthlyCents, 4900);
    expect(pay('b', DateTime(2026), amount: 9000, repeat: Repeat.quarterly).monthlyCents, 3000);
    expect(pay('c', DateTime(2026), amount: 124000, repeat: Repeat.yearly).monthlyCents, isNull);
    expect(pay('d', DateTime(2026)).monthlyCents, isNull);
  });

  test('zapis i odczyt JSON', () {
    final p = pay('OC', DateTime(2026, 12, 9), kind: PaymentKind.reminder, repeat: Repeat.yearly, amount: 124000, remind: 30);
    final back = Payment.fromJson(p.toJson());
    expect(back.name, 'OC');
    expect(back.kind, PaymentKind.reminder);
    expect(back.repeat, Repeat.yearly);
    expect(back.dueDate, DateTime(2026, 12, 9));
    expect(back.amountCents, 124000);
    expect(back.remindDaysBefore, 30);
  });

  group('przypomnienia', () {
    final today = DateTime(2026, 11, 11);
    final oc = pay('OC', DateTime(2026, 12, 9), kind: PaymentKind.reminder, repeat: Repeat.yearly, remind: 30);
    final przeglad = pay('Przegląd', DateTime(2027, 1, 14), kind: PaymentKind.reminder, repeat: Repeat.yearly, remind: 30);
    final netflix = pay('Netflix', DateTime(2026, 11, 15), remind: 3);
    final prad = pay('Prąd', DateTime(2026, 11, 5), kind: PaymentKind.bill, remind: 3);

    test('aktywne: w oknie przypomnienia albo po terminie', () {
      final active = activeReminders([oc, przeglad, netflix, prad], today);
      expect(active.map((r) => r.payment.name), ['Prąd', 'OC']);
      expect(active.first.daysLeft, -6);
      expect(active.last.daysLeft, 28);
      expect(activeReminders([netflix], DateTime(2026, 11, 12)).single.daysLeft, 3);
    });

    test('kalendarz miesiąca uwzględnia powtórzenia', () {
      final days = dueDaysInMonth([netflix, oc], 2026, 12);
      expect(days.keys.toSet(), {9, 15});
      expect(dueDaysInMonth([oc], 2027, 12).keys, [9]);
      expect(dueDaysInMonth([oc], 2027, 6), isEmpty);
    });

    test('plan powiadomień: data przypomnienia, bez przeszłych i bez wyłączonych', () {
      final planned = plannedNotifications(
        [oc, netflix, pay('Cicha', DateTime(2026, 11, 20), remind: 0)],
        today,
        perPayment: 2,
      );
      expect(planned.map((n) => (n.payment.name, n.notifyOn)).toList(), [
        ('Netflix', DateTime(2026, 11, 12)),
        ('Netflix', DateTime(2026, 12, 12)),
        ('OC', DateTime(2027, 11, 9)),
      ]);
    });
  });

  group('kwoty', () {
    test('parsowanie', () {
      expect(parseMoney('49,99'), 4999);
      expect(parseMoney('49'), 4900);
      expect(parseMoney('1 234,50 zł'), 123450);
      expect(parseMoney('-89,00'), -8900);
      expect(parseMoney('−12.5'), -1250);
      expect(parseMoney('1.234,56'), 123456);
      expect(parseMoney('1,234.56'), 123456);
      expect(parseMoney('abc'), isNull);
      expect(parseMoney(''), isNull);
    });

    test('formatowanie', () {
      expect(formatMoney(4999), '49,99 zł');
      expect(formatMoney(123450), '1 234,50 zł');
      expect(formatMoney(18299.0), '182,99 zł');
      expect(formatMoney(4900, withCurrency: false), '49,00');
    });
  });
}

import '../models/payment.dart';

/// Przypomnienie do pokazania: termin płatności, który wypada w oknie „przypomnij X dni przed”.
class DueReminder {
  const DueReminder(this.payment, this.daysLeft);
  final Payment payment;

  /// Dni do terminu (ujemne = po terminie).
  final int daysLeft;
}

/// Pozycje, o których trzeba teraz przypomnieć: po terminie albo w oknie przypomnienia.
List<DueReminder> activeReminders(List<Payment> payments, DateTime today) {
  final t = dateOnly(today);
  final result = <DueReminder>[];
  for (final p in payments) {
    final days = p.daysUntil(t);
    final overdue = days < 0 && p.kind != PaymentKind.subscription;
    final inWindow = p.hasReminder && days >= 0 && days <= p.remindDaysBefore;
    if (overdue || inWindow) result.add(DueReminder(p, days));
  }
  result.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
  return result;
}

/// Terminy w danym miesiącu (z uwzględnieniem powtórzeń), np. do kalendarza.
Map<int, List<Payment>> dueDaysInMonth(List<Payment> payments, int year, int month) {
  final first = DateTime(year, month);
  final last = DateTime(year, month + 1, 0);
  final map = <int, List<Payment>>{};
  for (final p in payments) {
    for (final d in p.occurrences()) {
      if (d.isAfter(last)) break;
      if (d.isBefore(first)) continue;
      map.putIfAbsent(d.day, () => []).add(p);
    }
  }
  return map;
}

/// Powiadomienia do zaplanowania: data przypomnienia dla najbliższych terminów.
List<({Payment payment, DateTime due, DateTime notifyOn})> plannedNotifications(
  List<Payment> payments,
  DateTime today, {
  int horizonDays = 400,
  int perPayment = 3,
}) {
  final t = dateOnly(today);
  final horizon = t.add(Duration(days: horizonDays));
  final result = <({Payment payment, DateTime due, DateTime notifyOn})>[];
  for (final p in payments) {
    if (!p.hasReminder) continue;
    var count = 0;
    for (final due in p.occurrences()) {
      if (due.isAfter(horizon) || count >= perPayment) break;
      final notifyOn = due.subtract(Duration(days: p.remindDaysBefore));
      if (!notifyOn.isBefore(t)) {
        result.add((payment: p, due: due, notifyOn: notifyOn));
        count++;
      }
    }
  }
  result.sort((a, b) => a.notifyOn.compareTo(b.notifyOn));
  return result;
}

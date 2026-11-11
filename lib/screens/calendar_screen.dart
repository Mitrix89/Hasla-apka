import 'package:flutter/material.dart';

import '../app.dart';
import '../models/payment.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/reminders.dart';
import '../widgets/payment_tile.dart';
import 'payment_edit_screen.dart';

/// Kalendarz terminów z listą nadchodzących przypomnień.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selectedDay = now.day;
  }

  void _shift(int months) {
    setState(() {
      _month = DateTime(_month.year, _month.month + months);
      _selectedDay = 1;
    });
  }

  void _open(Payment p) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentEditScreen(paymentId: p.id)));
  }

  @override
  Widget build(BuildContext context) {
    final vault = AppScope.of(context).vault;
    return Theme(
      data: paymentsTheme(Theme.of(context)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Przypomnienia'),
          actions: [
            IconButton(
              tooltip: 'Dodaj przypomnienie',
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const PaymentEditScreen(initialKind: PaymentKind.reminder),
              )),
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: vault,
          builder: (context, _) {
            final today = dateOnly(DateTime.now());
            final payments = vault.payments;
            final byDay = dueDaysInMonth(payments, _month.year, _month.month);
            final selected = byDay[_selectedDay] ?? const <Payment>[];
            final upcoming = payments.where((p) => p.daysUntil(today) <= 90).toList();
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _MonthGrid(
                          month: _month,
                          today: today,
                          selectedDay: _selectedDay,
                          dueDays: byDay.keys.toSet(),
                          onPrev: () => _shift(-1),
                          onNext: () => _shift(1),
                          onSelect: (d) => setState(() => _selectedDay = d),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: selected.isEmpty
                          ? ListTile(
                              title: Text('$_selectedDay ${monthNames[_month.month - 1].toLowerCase()}'),
                              subtitle: const Text('Brak terminów'),
                            )
                          : Column(
                              children: [
                                for (final p in selected)
                                  ListTile(
                                    onTap: () => _open(p),
                                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Text('$_selectedDay ${monthNames[_month.month - 1].toLowerCase()} · ${p.kind.label}'),
                                    trailing: Text(p.amountCents == null ? '' : formatMoney(p.amountCents!)),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 18),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text('Nadchodzące terminy (90 dni)', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    if (upcoming.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Nic w najbliższym czasie', style: TextStyle(color: AppColors.muted)),
                      )
                    else
                      for (final p in upcoming) ...[
                        ReminderBanner(payment: p, daysLeft: p.daysUntil(today), onTap: () => _open(p)),
                        const SizedBox(height: 8),
                      ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.selectedDay,
    required this.dueDays,
    required this.onPrev,
    required this.onNext,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime today;
  final int selectedDay;
  final Set<int> dueDays;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = DateTime(month.year, month.month).weekday - 1; // poniedziałek = 0
    final isThisMonth = today.year == month.year && today.month == month.month;
    return Column(
      children: [
        Row(
          children: [
            IconButton(tooltip: 'Poprzedni miesiąc', onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Text(
                '${monthNames[month.month - 1]} ${month.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            IconButton(tooltip: 'Następny miesiąc', onPressed: onNext, icon: const Icon(Icons.chevron_right)),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.05,
          children: [
            for (final w in const ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'So', 'Nd'])
              Center(
                child: Text(w, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
              ),
            for (var i = 0; i < leading; i++) const SizedBox.shrink(),
            for (var d = 1; d <= daysInMonth; d++)
              _DayCell(
                day: d,
                selected: d == selectedDay,
                today: isThisMonth && d == today.day,
                hasDue: dueDays.contains(d),
                onTap: () => onSelect(d),
              ),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.hasDue,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final bool today;
  final bool hasDue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.ink : (today ? AppColors.paymentsSoft : Colors.transparent);
    final fg = selected ? Colors.white : (today ? const Color(0xFF8A3F06) : AppColors.ink);
    return Semantics(
      button: true,
      selected: selected,
      label: '$day${hasDue ? ', termin płatności' : ''}',
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$day',
                    style: TextStyle(color: fg, fontWeight: selected || today ? FontWeight.w600 : FontWeight.normal)),
                const SizedBox(height: 3),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasDue ? (selected ? Colors.white : AppColors.payments) : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

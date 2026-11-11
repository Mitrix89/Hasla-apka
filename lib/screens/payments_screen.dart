import 'package:flutter/material.dart';

import '../app.dart';
import '../models/payment.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/payment_tile.dart';
import 'bank_import_screen.dart';
import 'calendar_screen.dart';
import 'payment_edit_screen.dart';

/// Lista opłat: suma miesięczna, filtry i najbliższe terminy.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  PaymentKind? _filter;

  void _open(Payment? p) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentEditScreen(paymentId: p?.id)));
  }

  @override
  Widget build(BuildContext context) {
    final vault = AppScope.of(context).vault;
    return Theme(
      data: paymentsTheme(Theme.of(context)),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Opłaty'),
            actions: [
              IconButton(
                tooltip: 'Kalendarz',
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
              ),
              PopupMenuButton<String>(
                tooltip: 'Więcej',
                onSelected: (v) {
                  if (v == 'import') {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BankImportScreen()));
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'import', child: Text('Importuj wyciąg z banku (CSV)')),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _open(null),
            icon: const Icon(Icons.add),
            label: const Text('Dodaj'),
          ),
          body: ListenableBuilder(
            listenable: vault,
            builder: (context, _) {
              final today = DateTime.now();
              final all = vault.payments;
              final visible = _filter == null ? all : all.where((p) => p.kind == _filter).toList();
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      _SummaryCard(payments: all, today: today),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Wszystko'),
                            selected: _filter == null,
                            onSelected: (_) => setState(() => _filter = null),
                          ),
                          for (final (k, label) in const [
                            (PaymentKind.subscription, 'Subskrypcje'),
                            (PaymentKind.bill, 'Rachunki'),
                            (PaymentKind.reminder, 'Przypomnienia'),
                          ])
                            ChoiceChip(
                              label: Text(label),
                              selected: _filter == k,
                              onSelected: (_) => setState(() => _filter = k),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (all.isEmpty)
                        _Empty(
                          onAdd: () => _open(null),
                          onImport: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => const BankImportScreen())),
                        )
                      else if (visible.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Brak pozycji w tej kategorii',
                              textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                        )
                      else ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 8),
                          child: Text('Najbliższe terminy', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (final (i, p) in visible.indexed) ...[
                                if (i > 0) const Divider(height: 1, color: Color(0xFFEEF0F4)),
                                PaymentTile(payment: p, today: today, onTap: () => _open(p)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.payments, required this.today});
  final List<Payment> payments;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final monthly = payments.map((p) => p.monthlyCents ?? 0).fold<double>(0, (a, b) => a + b);
    final endOfMonth = DateTime(today.year, today.month + 1, 0);
    final t = dateOnly(today);
    var leftThisMonth = 0;
    for (final p in payments) {
      final a = p.amountCents;
      if (a == null) continue;
      for (final d in p.occurrences()) {
        if (d.isAfter(endOfMonth)) break;
        if (!d.isBefore(t) || p.kind != PaymentKind.subscription) leftThisMonth += a;
      }
    }
    final yearly = payments
        .where((p) => p.repeat == Repeat.yearly && p.amountCents != null)
        .fold<int>(0, (a, p) => a + p.amountCents!);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stałe opłaty miesięcznie', style: TextStyle(color: Color(0xFFC9CED8), fontSize: 13)),
          const SizedBox(height: 4),
          Text(formatMoney(monthly),
              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Stat(label: 'Do końca ${_monthGenitive(today.month)}', value: formatMoney(leftThisMonth))),
              const SizedBox(width: 10),
              Expanded(child: _Stat(label: 'Opłaty roczne', value: formatMoney(yearly))),
            ],
          ),
        ],
      ),
    );
  }

  static String _monthGenitive(int m) => const [
        'stycznia', 'lutego', 'marca', 'kwietnia', 'maja', 'czerwca',
        'lipca', 'sierpnia', 'września', 'października', 'listopada', 'grudnia',
      ][m - 1];
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF262A33), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFFC9CED8), fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd, required this.onImport});
  final VoidCallback onAdd;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.payments),
            const SizedBox(height: 12),
            const Text('Nie masz jeszcze opłat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              'Dodaj subskrypcję, rachunek albo termin (np. przegląd auta), '
              'albo wczytaj wyciąg z banku, a aplikacja sama znajdzie stałe płatności.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton(onPressed: onAdd, child: const Text('Dodaj')),
                OutlinedButton(onPressed: onImport, child: const Text('Wczytaj wyciąg')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

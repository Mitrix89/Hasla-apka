import 'package:flutter/material.dart';

import '../app.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/reminders.dart';
import '../widgets/brand_header.dart';
import '../widgets/payment_tile.dart';
import 'calendar_screen.dart';
import 'passwords_screen.dart';
import 'payment_edit_screen.dart';
import 'payments_screen.dart';
import 'settings_screen.dart';

/// Ekran startowy: wybór między hasłami a opłatami.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vault = AppScope.of(context).vault;
    return Scaffold(
      appBar: AppBar(
        title: const BrandHeader(),
        actions: [
          IconButton(
            tooltip: 'Ustawienia',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          IconButton(tooltip: 'Zablokuj', icon: const Icon(Icons.lock_outline), onPressed: vault.lock),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text('Co chcesz otworzyć?',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                ListenableBuilder(
                  listenable: vault,
                  builder: (context, _) => _SectionCard(
                    icon: Icons.key_outlined,
                    color: AppColors.passwords,
                    softColor: AppColors.passwordsSoft,
                    title: 'Hasła',
                    subtitle: _countLabel(vault.entries.length),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const PasswordsScreen())),
                  ),
                ),
                const SizedBox(height: 16),
                ListenableBuilder(
                  listenable: vault,
                  builder: (context, _) {
                    final payments = vault.payments;
                    final monthly = payments.map((p) => p.monthlyCents ?? 0).fold<double>(0, (a, b) => a + b);
                    final reminders = activeReminders(payments, DateTime.now());
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionCard(
                          icon: Icons.credit_card_outlined,
                          color: AppColors.payments,
                          softColor: AppColors.paymentsSoft,
                          title: 'Opłaty i przypomnienia',
                          subtitle: payments.isEmpty
                              ? 'Subskrypcje, rachunki i ważne terminy'
                              : '${formatMoney(monthly)} miesięcznie · ${payments.length} poz.',
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => const PaymentsScreen())),
                        ),
                        for (final r in reminders.take(3)) ...[
                          const SizedBox(height: 12),
                          ReminderBanner(
                            payment: r.payment,
                            daysLeft: r.daysLeft,
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => PaymentEditScreen(paymentId: r.payment.id),
                            )),
                          ),
                        ],
                        if (reminders.length > 3) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
                            child: Text('Pokaż wszystkie przypomnienia (${reminders.length})'),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _countLabel(int n) {
    if (n == 0) return 'Brak zapisanych haseł';
    if (n == 1) return '1 zapisane hasło';
    final lastTwo = n % 100;
    final last = n % 10;
    final few = last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14);
    return '$n ${few ? 'zapisane hasła' : 'zapisanych haseł'}';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.color,
    required this.softColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color softColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: softColor, borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

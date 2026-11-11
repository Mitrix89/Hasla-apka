import 'package:flutter/material.dart';

import '../models/payment.dart';
import '../theme.dart';
import '../util/format.dart';
import 'letter_avatar.dart';

class PaymentTile extends StatelessWidget {
  const PaymentTile({super.key, required this.payment, required this.today, this.onTap});
  final Payment payment;
  final DateTime today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final days = p.daysUntil(today);
    final overdue = days < 0;
    final soon = days >= 0 && days <= 7;
    final dueText = overdue
        ? 'po terminie ${-days} ${-days == 1 ? 'dzień' : 'dni'}'
        : '${formatDateShort(p.dueDate)} · ${formatDaysUntil(days)}';
    return ListTile(
      onTap: onTap,
      leading: LetterAvatar(p.name),
      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${p.kind.label} · ${p.repeat.label}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            p.amountCents == null ? '—' : formatMoney(p.amountCents!),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            dueText,
            style: TextStyle(
              fontSize: 12,
              color: overdue || soon ? AppColors.danger : AppColors.muted,
              fontWeight: overdue ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Karta z przypomnieniem (np. „Ubezpieczenie OC za 28 dni”).
class ReminderBanner extends StatelessWidget {
  const ReminderBanner({super.key, required this.payment, required this.daysLeft, this.onTap});
  final Payment payment;
  final int daysLeft;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final overdue = daysLeft < 0;
    final when = overdue ? 'po terminie' : formatDaysUntil(daysLeft);
    final amount = payment.amountCents == null ? '' : ' · ${formatMoney(payment.amountCents!)}';
    return Material(
      color: overdue ? const Color(0xFFFEF3F2) : const Color(0xFFFFF7ED),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: overdue ? const Color(0xFFF1B8B2) : const Color(0xFFF5D3B3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.notifications_active_outlined, color: overdue ? AppColors.danger : AppColors.payments),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${payment.name} $when', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${formatDate(payment.dueDate)}$amount',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

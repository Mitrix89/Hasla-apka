import 'package:flutter/material.dart';

import '../app.dart';
import '../models/payment.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/ids.dart';

/// Dodawanie i edycja opłaty lub przypomnienia.
class PaymentEditScreen extends StatefulWidget {
  const PaymentEditScreen({super.key, this.paymentId, this.initialKind});
  final String? paymentId;
  final PaymentKind? initialKind;

  static const remindOptions = [0, 1, 3, 7, 14, 30];

  @override
  State<PaymentEditScreen> createState() => _PaymentEditScreenState();
}

class _PaymentEditScreenState extends State<PaymentEditScreen> {
  final _form = GlobalKey<FormState>();
  Payment? _existing;
  late PaymentKind _kind;
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late DateTime _due;
  late Repeat _repeat;
  late int _remind;
  bool _initialized = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final p = widget.paymentId == null ? null : AppScope.of(context).vault.paymentById(widget.paymentId!);
    _existing = p;
    _kind = p?.kind ?? widget.initialKind ?? PaymentKind.subscription;
    _name.text = p?.name ?? '';
    _amount.text = p?.amountCents == null ? '' : formatMoney(p!.amountCents!, withCurrency: false);
    _note.text = p?.note ?? '';
    _due = p?.dueDate ?? dateOnly(DateTime.now());
    _repeat = p?.repeat ?? (_kind == PaymentKind.reminder ? Repeat.yearly : Repeat.monthly);
    _remind = p?.remindDaysBefore ?? (_kind == PaymentKind.reminder ? 30 : 3);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _setKind(PaymentKind k) {
    setState(() {
      // Przy nowej pozycji podpowiadamy sensowne ustawienia dla rodzaju.
      if (_existing == null && k != _kind) {
        _repeat = k == PaymentKind.reminder ? Repeat.yearly : Repeat.monthly;
        _remind = k == PaymentKind.reminder ? 30 : 3;
      }
      _kind = k;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Termin',
    );
    if (picked != null) setState(() => _due = dateOnly(picked));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final scope = AppScope.of(context);
    final amount = parseMoney(_amount.text);
    final base = _existing ??
        Payment(id: newId(), name: '', kind: _kind, dueDate: _due);
    final payment = base.copyWith(
      name: _name.text.trim(),
      kind: _kind,
      dueDate: _due,
      dayOfMonth: _due.day,
      amountCents: amount,
      clearAmount: amount == null,
      repeat: _repeat,
      remindDaysBefore: _remind,
      note: _note.text.trim(),
    );
    await scope.vault.upsertPayment(payment);
    if (_remind > 0) {
      await scope.notifications?.requestPermission().catchError((Object _) => false);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _markPaid() async {
    final p = _existing!;
    final next = p.nextDueDate();
    await AppScope.of(context).vault.markPaid(p.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(next == null ? 'Gotowe, pozycja usunięta' : 'Następny termin: ${formatDate(next, withYear: true)}'),
    ));
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final p = _existing!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usunąć?'),
        content: Text('„${p.name}” zniknie z listy opłat i przypomnień.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Anuluj')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AppScope.of(context).vault.deletePayment(p.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = _existing != null;
    final remindHint = _remind == 0
        ? 'Bez powiadomienia, tylko na liście i w kalendarzu'
        : 'Przypomnienie ${formatDate(_due.subtract(Duration(days: _remind)), withYear: true)}';
    return Theme(
      data: paymentsTheme(Theme.of(context)),
      child: Scaffold(
        appBar: AppBar(title: Text(editing ? _existing!.name : 'Nowa pozycja')),
        body: Form(
          key: _form,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SegmentedButton<PaymentKind>(
                    segments: [
                      for (final k in PaymentKind.values) ButtonSegment(value: k, label: Text(k.label)),
                    ],
                    selected: {_kind},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => _setKind(s.first),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Nazwa', hintText: 'np. Netflix, prąd, przegląd auta'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Podaj nazwę' : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Kwota (zł)', hintText: 'opcjonalnie'),
                          validator: (v) => (v ?? '').trim().isEmpty || parseMoney(v!) != null
                              ? null
                              : 'Wpisz kwotę, np. 49,99',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Termin', suffixIcon: Icon(Icons.event)),
                            child: Text(formatDate(_due, withYear: true)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text('Powtarzaj', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in Repeat.values)
                        ChoiceChip(
                          label: Text(r.label[0].toUpperCase() + r.label.substring(1)),
                          selected: _repeat == r,
                          onSelected: (_) => setState(() => _repeat = r),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text('Przypomnij mi', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final d in PaymentEditScreen.remindOptions)
                        ChoiceChip(
                          label: Text(_remindLabel(d)),
                          selected: _remind == d,
                          onSelected: (_) => setState(() => _remind = d),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(remindHint, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _note,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Notatka', hintText: 'np. numer polisy'),
                  ),
                  const SizedBox(height: 20),
                  if (editing) ...[
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _markPaid,
                      icon: const Icon(Icons.check),
                      label: Text(_kind == PaymentKind.reminder ? 'Załatwione' : 'Zapłacone'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      if (editing) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: Color(0xFFF1B8B2)),
                          ),
                          onPressed: _busy ? null : _delete,
                          child: const Text('Usuń'),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton(onPressed: _busy ? null : _save, child: const Text('Zapisz')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _remindLabel(int d) => switch (d) {
        0 => 'Nie przypominaj',
        1 => '1 dzień przed',
        7 => 'tydzień przed',
        14 => '2 tygodnie przed',
        30 => 'miesiąc przed',
        _ => '$d dni przed',
      };
}

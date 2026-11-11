import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../import/bank_csv.dart';
import '../import/csv.dart';
import '../models/payment.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/ids.dart';

/// Wczytuje wyciąg z banku i podpowiada stałe płatności do dodania.
class BankImportScreen extends StatefulWidget {
  const BankImportScreen({super.key});

  @override
  State<BankImportScreen> createState() => _BankImportScreenState();
}

class _BankImportScreenState extends State<BankImportScreen> {
  List<RecurringCandidate>? _found;
  final Set<int> _chosen = {};
  Set<String> _existingNames = {};
  int _transactions = 0;
  String? _error;
  bool _busy = false;

  Future<void> _pick() async {
    final vault = AppScope.of(context).vault;
    setState(() {
      _error = null;
      _found = null;
    });
    final file = await FilePicker.pickFile(dialogTitle: 'Wybierz wyciąg z banku (CSV)');
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final text = decodeBankFile(await file.xFile.readAsBytes());
      final transactions = parseBankCsv(text);
      final found = findRecurringPayments(transactions);
      final existing = vault.payments.map((p) => p.name.toLowerCase()).toSet();
      setState(() {
        _transactions = transactions.length;
        _found = found;
        _existingNames = existing;
        _chosen
          ..clear()
          ..addAll([
            for (var i = 0; i < found.length; i++)
              if (!existing.contains(found[i].name.toLowerCase())) i,
          ]);
      });
    } on CsvImportException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Nie udało się odczytać pliku. Upewnij się, że to wyciąg w formacie CSV.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final found = _found!;
    final vault = AppScope.of(context).vault;
    setState(() => _busy = true);
    for (final i in _chosen.toList()..sort()) {
      final c = found[i];
      await vault.upsertPayment(Payment(
        id: newId(),
        name: c.name,
        kind: c.kind,
        dueDate: c.nextDue,
        amountCents: c.amountCents,
        repeat: c.repeat,
        remindDaysBefore: c.kind == PaymentKind.subscription ? 1 : 3,
        note: 'Wykryte w wyciągu (${c.occurrences}× , ostatnio ${formatDate(c.lastDate, withYear: true)})',
      ));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dodano: ${_chosen.length}')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final found = _found;
    return Theme(
      data: paymentsTheme(Theme.of(context)),
      child: Scaffold(
        appBar: AppBar(title: const Text('Wyciąg z banku')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (found == null) ...[
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Jak to działa', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          SizedBox(height: 8),
                          Text(
                            '1. W bankowości internetowej otwórz historię rachunku (lub karty), '
                            'wybierz ostatnie 6–12 miesięcy i pobierz ją jako plik CSV.',
                          ),
                          SizedBox(height: 6),
                          Text('2. Wybierz ten plik tutaj. Aplikacja znajdzie płatności, które powtarzają się '
                              'co miesiąc, kwartał lub rok (np. Netflix, Vectra, Sklep Play).'),
                          SizedBox(height: 6),
                          Text('3. Zaznacz, które dodać. Kwoty i terminy możesz potem poprawić.'),
                          SizedBox(height: 12),
                          Text(
                            'Plik jest czytany tylko na tym urządzeniu i nigdzie nie jest wysyłany. '
                            'Po imporcie możesz go usunąć.',
                            style: TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    onPressed: _busy ? null : _pick,
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('Wybierz plik CSV'),
                  ),
                ] else ...[
                  Text(
                    found.isEmpty
                        ? 'Przejrzano $_transactions operacji, ale nie znaleziono powtarzających się płatności. '
                            'Spróbuj wyciągu z dłuższego okresu (np. 12 miesięcy).'
                        : 'Przejrzano $_transactions operacji. Znalezione stałe płatności:',
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  if (found.isNotEmpty)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (final (i, c) in found.indexed)
                            CheckboxListTile(
                              value: _chosen.contains(i),
                              onChanged: (v) => setState(() => v == true ? _chosen.add(i) : _chosen.remove(i)),
                              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${formatMoney(c.amountCents)} ${c.repeat.label} · następnie ${formatDate(c.nextDue)}'
                                '${_existingNames.contains(c.name.toLowerCase()) ? '\nJuż masz pozycję o tej nazwie' : ''}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (found.isNotEmpty)
                    FilledButton(
                      onPressed: _busy || _chosen.isEmpty ? null : _add,
                      child: Text('Dodaj zaznaczone (${_chosen.length})'),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _busy ? null : _pick, child: const Text('Wybierz inny plik')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

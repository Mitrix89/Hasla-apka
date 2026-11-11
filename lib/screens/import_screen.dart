import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../import/google_csv.dart';
import '../models/password_entry.dart';
import '../theme.dart';
import '../vault/vault_controller.dart';

/// Import haseł z pliku CSV wyeksportowanego z Haseł Google.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  List<PasswordEntry>? _parsed;
  String? _fileName;
  String? _filePath;
  String? _error;
  bool _busy = false;

  Future<void> _pick() async {
    setState(() {
      _error = null;
      _parsed = null;
    });
    final file = await FilePicker.pickFile(dialogTitle: 'Wybierz plik z hasłami (CSV)');
    if (file == null) return;
    setState(() => _busy = true);
    try {
      final text = await file.xFile.readAsString();
      final entries = parseGooglePasswordsCsv(text);
      setState(() {
        _parsed = entries;
        _fileName = file.name;
        _filePath = file.path;
      });
    } on CsvImportException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Nie udało się odczytać pliku. Upewnij się, że to plik CSV z Haseł Google.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final entries = _parsed;
    if (entries == null) return;
    setState(() => _busy = true);
    final result = await AppScope.of(context).vault.importEntries(entries);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _parsed = null;
    });
    await showDialog<void>(
      context: context,
      builder: (context) => _DoneDialog(result: result, filePath: _filePath, fileName: _fileName),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    return Scaffold(
      appBar: AppBar(title: const Text('Import z Haseł Google')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. Wyeksportuj hasła z Google', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Na komputerze: wejdź na passwords.google.com, otwórz Ustawienia i wybierz „Eksportuj hasła”.'),
                  SizedBox(height: 6),
                  Text('Na telefonie: Ustawienia › Google › Menedżer haseł › ikona ustawień › „Eksportuj hasła”.'),
                  SizedBox(height: 14),
                  Text('2. Wybierz zapisany plik', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Plik nazywa się zwykle „Hasła Google.csv” i trafia do folderu Pobrane.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              border: Border.all(color: const Color(0xFFF5D3B3)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.payments),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ten plik zawiera wszystkie hasła zwykłym tekstem. Nie wysyłaj go nikomu '
                    'i usuń go zaraz po imporcie.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 12),
          ],
          if (parsed == null)
            FilledButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Wybierz plik CSV'),
            )
          else ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(_fileName ?? 'Plik CSV'),
                subtitle: Text('Znaleziono haseł: ${parsed.length}'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy || parsed.isEmpty ? null : _import,
              child: Text('Importuj ${parsed.length}'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _busy ? null : _pick, child: const Text('Wybierz inny plik')),
          ],
        ],
      ),
    );
  }
}

class _DoneDialog extends StatefulWidget {
  const _DoneDialog({required this.result, this.filePath, this.fileName});
  final ImportResult result;
  final String? filePath;
  final String? fileName;

  @override
  State<_DoneDialog> createState() => _DoneDialogState();
}

class _DoneDialogState extends State<_DoneDialog> {
  bool _deleted = false;
  String? _deleteError;

  bool get _canDelete => widget.filePath != null && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  Future<void> _deleteFile() async {
    try {
      await File(widget.filePath!).delete();
      setState(() => _deleted = true);
    } catch (_) {
      setState(() => _deleteError = 'Nie udało się usunąć pliku. Usuń go ręcznie.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return AlertDialog(
      title: const Text('Import zakończony'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dodano: ${r.added}'),
          if (r.skipped > 0) Text('Pominięto, bo już były w sejfie: ${r.skipped}'),
          const SizedBox(height: 14),
          if (_deleted)
            const Text('Plik CSV został usunięty.', style: TextStyle(fontWeight: FontWeight.w600))
          else
            Text(
              'Teraz usuń plik ${widget.fileName ?? 'CSV'}'
              '${_canDelete ? '.' : ' z folderu Pobrane (np. w aplikacji Pliki).'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          if (_deleteError != null) Text(_deleteError!, style: const TextStyle(color: AppColors.danger)),
        ],
      ),
      actions: [
        if (_canDelete && !_deleted)
          TextButton(onPressed: _deleteFile, child: const Text('Usuń plik teraz')),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Gotowe')),
      ],
    );
  }
}

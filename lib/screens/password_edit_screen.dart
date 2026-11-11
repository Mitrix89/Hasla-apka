import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../models/password_entry.dart';
import '../theme.dart';
import '../util/ids.dart';
import '../util/password_generator.dart';
import '../widgets/letter_avatar.dart';

/// Ekran dodawania / edycji hasła na telefonie.
class PasswordEditScreen extends StatelessWidget {
  const PasswordEditScreen({super.key, this.entryId});
  final String? entryId;

  @override
  Widget build(BuildContext context) {
    final entry = entryId == null ? null : AppScope.of(context).vault.byId(entryId!);
    return Scaffold(
      appBar: AppBar(title: Text(entry == null ? 'Nowe hasło' : entry.name)),
      body: PasswordForm(
        entry: entry,
        onSaved: (_) => Navigator.of(context).pop(),
        onDeleted: () => Navigator.of(context).pop(),
      ),
    );
  }
}

/// Kopiuje tekst do schowka i czyści go po 30 sekundach, jeśli nic innego nie zostało skopiowane.
Future<void> copySecret(BuildContext context, String text, String what) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Skopiowano $what. Schowek wyczyści się za 30 s.')),
    );
  }
  Timer(const Duration(seconds: 30), () async {
    final current = await Clipboard.getData(Clipboard.kTextPlain);
    if (current?.text == text) await Clipboard.setData(const ClipboardData(text: ''));
  });
}

/// Formularz hasła: nazwa, login, hasło, przypisane aplikacje i strony, notatka.
class PasswordForm extends StatefulWidget {
  const PasswordForm({super.key, this.entry, required this.onSaved, required this.onDeleted});

  final PasswordEntry? entry;
  final ValueChanged<PasswordEntry> onSaved;
  final VoidCallback onDeleted;

  @override
  State<PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<PasswordForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.entry?.name ?? '');
  late final _username = TextEditingController(text: widget.entry?.username ?? '');
  late final _password = TextEditingController(text: widget.entry?.password ?? '');
  late final _note = TextEditingController(text: widget.entry?.note ?? '');
  late List<String> _apps = [...?widget.entry?.apps];
  late List<String> _websites = [...?widget.entry?.websites];
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final vault = AppScope.of(context).vault;
    final base = widget.entry ?? PasswordEntry(id: newId(), name: '');
    final entry = base.copyWith(
      name: _name.text.trim(),
      username: _username.text.trim(),
      password: _password.text,
      apps: _apps,
      websites: _websites,
      note: _note.text.trim(),
    );
    await vault.upsert(entry);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zapisano')));
    widget.onSaved(entry);
  }

  Future<void> _delete() async {
    final entry = widget.entry;
    if (entry == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usunąć hasło?'),
        content: Text('Hasło „${entry.name}” zostanie trwale usunięte.'),
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
    if (confirmed != true || !mounted) return;
    await AppScope.of(context).vault.delete(entry.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usunięto')));
    widget.onDeleted();
  }

  Future<void> _addLink({required bool app}) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(app ? 'Przypisz aplikację' : 'Przypisz stronę'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: app ? TextInputType.text : TextInputType.url,
          decoration: InputDecoration(hintText: app ? 'np. Netflix' : 'np. netflix.com'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Dodaj')),
        ],
      ),
    );
    controller.dispose();
    final v = value?.trim() ?? '';
    if (v.isEmpty) return;
    setState(() {
      final list = app ? _apps : _websites;
      if (!list.contains(v)) {
        if (app) {
          _apps = [..._apps, v];
        } else {
          _websites = [..._websites, v];
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.entry != null;
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (editing) ...[
            Row(
              children: [
                LetterAvatar(widget.entry!.name, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(widget.entry!.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nazwa', hintText: 'np. Netflix'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Podaj nazwę' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _username,
            decoration: InputDecoration(
              labelText: 'Login lub e-mail',
              suffixIcon: IconButton(
                tooltip: 'Kopiuj login',
                icon: const Icon(Icons.copy_outlined),
                onPressed: () => copySecret(context, _username.text, 'login'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            enableSuggestions: false,
            autocorrect: false,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Hasło',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _obscure ? 'Pokaż hasło' : 'Ukryj hasło',
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  IconButton(
                    tooltip: 'Kopiuj hasło',
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () => copySecret(context, _password.text, 'hasło'),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _password.text = generatePassword();
                _obscure = false;
              }),
              icon: const Icon(Icons.autorenew),
              label: const Text('Wygeneruj silne hasło'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: AppColors.background,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Przypisane do', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_apps.isEmpty && _websites.isEmpty)
                    const Text('Nic jeszcze nie przypisano', style: TextStyle(color: AppColors.muted)),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in _apps)
                        InputChip(
                          avatar: const Icon(Icons.phone_android, size: 18),
                          label: Text(a),
                          deleteButtonTooltipMessage: 'Usuń przypisanie',
                          onDeleted: () => setState(() => _apps = _apps.where((x) => x != a).toList()),
                        ),
                      for (final w in _websites)
                        InputChip(
                          avatar: const Icon(Icons.language, size: 18),
                          label: Text(w),
                          deleteButtonTooltipMessage: 'Usuń przypisanie',
                          onDeleted: () => setState(() => _websites = _websites.where((x) => x != w).toList()),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => _addLink(app: true),
                        icon: const Icon(Icons.add),
                        label: const Text('Aplikacja'),
                      ),
                      TextButton.icon(
                        onPressed: () => _addLink(app: false),
                        icon: const Icon(Icons.add),
                        label: const Text('Strona'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _note,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Notatka', alignLabelWithHint: true),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (editing) ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: Color(0xFFF1B8B2)),
                  ),
                  onPressed: _saving ? null : _delete,
                  child: const Text('Usuń'),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(editing ? 'Zapisz zmiany' : 'Zapisz'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

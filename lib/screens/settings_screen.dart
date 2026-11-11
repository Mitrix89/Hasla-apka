import 'package:flutter/material.dart';

import '../app.dart';
import '../theme.dart';
import 'setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _bioAvailable;
  bool _bioEnabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bioAvailable == null) _loadBiometrics();
  }

  Future<void> _loadBiometrics() async {
    final bio = AppScope.of(context).biometrics;
    final available = bio != null && await bio.isAvailable();
    final enabled = available && await bio.isEnabled();
    if (!mounted) return;
    setState(() {
      _bioAvailable = available;
      _bioEnabled = enabled;
    });
  }

  Future<void> _toggleBiometrics(bool value) async {
    final scope = AppScope.of(context);
    final bio = scope.biometrics!;
    if (value) {
      final key = scope.vault.key;
      if (key == null) return;
      final ok = await bio.enable(key);
      if (!mounted) return;
      setState(() => _bioEnabled = ok);
    } else {
      await bio.disable();
      if (!mounted) return;
      setState(() => _bioEnabled = false);
    }
  }

  Future<void> _changeMasterPassword() async {
    final changed = await showDialog<bool>(context: context, builder: (_) => const _ChangePasswordDialog());
    if (changed != true || !mounted) return;
    // Stary klucz pod odciskiem palca jest już nieważny.
    final bio = AppScope.of(context).biometrics;
    if (_bioEnabled && bio != null) {
      await bio.disable();
      if (mounted) setState(() => _bioEnabled = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_bioAvailable == true
            ? 'Hasło główne zmienione. Włącz ponownie odcisk palca.'
            : 'Hasło główne zmienione.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                if (_bioAvailable == true)
                  SwitchListTile(
                    value: _bioEnabled,
                    onChanged: _toggleBiometrics,
                    secondary: const Icon(Icons.fingerprint),
                    title: const Text('Odblokowanie odciskiem palca'),
                  ),
                ListTile(
                  leading: const Icon(Icons.password),
                  title: const Text('Zmień hasło główne'),
                  onTap: _changeMasterPassword,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Sejf blokuje się sam po minucie w tle. Synchronizacja z komputerem pojawi się w kolejnej wersji.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await AppScope.of(context).vault.changeMasterPassword(_current.text, _next.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = 'Obecne hasło jest nieprawidłowe';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Zmień hasło główne'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Obecne hasło', errorText: _error),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nowe hasło'),
              validator: (v) => (v ?? '').length < SetupScreen.minLength
                  ? 'Co najmniej ${SetupScreen.minLength} znaków'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _repeat,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Powtórz nowe hasło'),
              validator: (v) => v != _next.text ? 'Hasła nie są takie same' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Anuluj')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Zmień')),
      ],
    );
  }
}

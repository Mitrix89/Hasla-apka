import 'package:flutter/material.dart';

import '../app.dart';
import '../theme.dart';
import '../widgets/brand_header.dart';

/// Pierwsze uruchomienie: ustawienie hasła głównego.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  static const minLength = 10;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  bool _obscure = true;
  bool _understood = false;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_understood) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Potwierdź, że zapamiętasz hasło główne.')),
      );
      return;
    }
    setState(() => _busy = true);
    await AppScope.of(context).vault.create(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BrandHeader(),
                    const SizedBox(height: 24),
                    Text('Ustaw hasło główne', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text(
                      'Tym jednym hasłem odblokujesz wszystkie pozostałe. Użyj co najmniej 10 znaków, '
                      'najlepiej kilku słów, np. „Zielony-Rower-Nad-Wisłą”.',
                      style: TextStyle(color: AppColors.muted, fontSize: 15),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Hasło główne',
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Pokaż hasło' : 'Ukryj hasło',
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v ?? '').length < SetupScreen.minLength
                          ? 'Hasło musi mieć co najmniej ${SetupScreen.minLength} znaków'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _repeat,
                      obscureText: _obscure,
                      decoration: const InputDecoration(labelText: 'Powtórz hasło główne'),
                      validator: (v) => v != _password.text ? 'Hasła nie są takie same' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      value: _understood,
                      onChanged: (v) => setState(() => _understood = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Rozumiem, że jeśli zapomnę hasła głównego, nie da się odzyskać zapisanych haseł.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : const Text('Utwórz sejf'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

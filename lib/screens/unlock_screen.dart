import 'package:flutter/material.dart';

import '../app.dart';
import '../theme.dart';
import '../widgets/brand_header.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _biometricEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBiometrics());
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final bio = AppScope.of(context).biometrics;
    if (bio == null) return;
    final enabled = await bio.isEnabled();
    if (!mounted) return;
    setState(() => _biometricEnabled = enabled);
    if (enabled) await _unlockWithBiometrics();
  }

  Future<void> _unlockWithBiometrics() async {
    final scope = AppScope.of(context);
    final key = await scope.biometrics!.unlock();
    if (key == null || !mounted) return;
    setState(() => _busy = true);
    final ok = await scope.vault.unlockWithKey(key);
    if (!ok) {
      // Zapamiętany klucz jest nieaktualny (np. po zmianie hasła głównego).
      await scope.biometrics!.disable();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _biometricEnabled = false;
        _error = 'Odcisk palca wymaga ponownego włączenia. Wpisz hasło główne.';
      });
    }
  }

  Future<void> _unlock() async {
    if (_password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await AppScope.of(context).vault.unlock(_password.text);
    if (!ok && mounted) {
      setState(() {
        _busy = false;
        _error = 'Nieprawidłowe hasło główne';
      });
      _password.clear();
    }
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandHeader(),
                  const SizedBox(height: 24),
                  Text('Sejf jest zablokowany',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    autofocus: !_biometricEnabled,
                    enabled: !_busy,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _unlock(),
                    decoration: InputDecoration(
                      labelText: 'Hasło główne',
                      errorText: _error,
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Pokaż hasło' : 'Ukryj hasło',
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _unlock,
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('Odblokuj'),
                  ),
                  if (_biometricEnabled) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _unlockWithBiometrics,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Użyj odcisku palca'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Hasło główne nie jest nigdzie zapisane, więc nie da się go odzyskać.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

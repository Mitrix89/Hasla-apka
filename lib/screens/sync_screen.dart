import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app.dart';
import '../sync/sync_code.dart';
import '../sync/sync_merge.dart';
import '../sync/sync_service.dart';
import '../theme.dart';

/// Synchronizacja haseł i opłat z drugim urządzeniem w tej samej sieci Wi-Fi.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

enum _Mode { choose, hosting, connecting, done, error }

class _SyncScreenState extends State<SyncScreen> {
  _Mode _mode = _Mode.choose;
  SyncHost? _host;
  SyncStats? _stats;
  String? _error;
  Timer? _ticker;
  DateTime? _hostStarted;
  final _codeField = TextEditingController();

  @override
  void dispose() {
    _host?.cancel();
    _ticker?.cancel();
    _codeField.dispose();
    super.dispose();
  }

  Future<void> _startHost() async {
    final vault = AppScope.of(context).vault;
    try {
      final host = await SyncHost.start(merge: vault.mergeFromRemote);
      if (!mounted) {
        host.cancel();
        return;
      }
      setState(() {
        _host = host;
        _hostStarted = DateTime.now();
        _mode = _Mode.hosting;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      final stats = await host.done;
      _show(stats: stats);
    } on SyncException catch (e) {
      if (e.message != 'Anulowano') _show(error: e.message);
    } catch (e) {
      _show(error: 'Nie udało się uruchomić synchronizacji: $e');
    }
  }

  Future<void> _connect(String input) async {
    final code = SyncCode.tryParse(input);
    if (code == null) {
      setState(() => _error = 'Nieprawidłowy kod. Sprawdź, czy przepisałeś go dokładnie.');
      return;
    }
    final vault = AppScope.of(context).vault;
    setState(() {
      _error = null;
      _mode = _Mode.connecting;
    });
    try {
      final merged = await syncWithHost(code, vault.syncSnapshot());
      final stats = await vault.applySynced(merged);
      _show(stats: stats);
    } on SyncException catch (e) {
      _show(error: e.message);
    }
  }

  Future<void> _scan() async {
    final value = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _ScannerPage()));
    if (value != null && mounted) await _connect(value);
  }

  void _show({SyncStats? stats, String? error}) {
    _ticker?.cancel();
    if (!mounted) return;
    setState(() {
      _host = null;
      _stats = stats;
      _error = error;
      _mode = error == null ? _Mode.done : _Mode.error;
    });
  }

  void _reset() {
    _host?.cancel();
    _ticker?.cancel();
    setState(() {
      _host = null;
      _error = null;
      _stats = null;
      _mode = _Mode.choose;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Synchronizacja')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: switch (_mode) {
              _Mode.choose => _choose(),
              _Mode.hosting => _hosting(),
              _Mode.connecting => [
                  const SizedBox(height: 80),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                  const Text('Łączenie z drugim urządzeniem…', textAlign: TextAlign.center),
                ],
              _Mode.done => _done(),
              _Mode.error => _failed(),
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _choose() {
    final canScan = Platform.isAndroid;
    return [
      const Text(
        'Hasła i opłaty z obu urządzeń zostaną połączone: nowe wpisy dojdą, a przy zmianach '
        'wygrywa nowsza wersja. Oba urządzenia muszą być w tej samej sieci Wi-Fi.',
        style: TextStyle(color: AppColors.muted, fontSize: 15),
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Na tym urządzeniu pokaż kod', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                Platform.isWindows
                    ? 'Najwygodniej na komputerze: telefon zeskanuje kod QR z ekranu.'
                    : 'Drugie urządzenie zeskanuje kod albo go przepisze.',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: _startHost, icon: const Icon(Icons.qr_code_2), label: const Text('Pokaż kod')),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Połącz z urządzeniem, które pokazuje kod',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 12),
              if (canScan) ...[
                FilledButton.icon(
                  onPressed: _scan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Zeskanuj kod QR'),
                ),
                const SizedBox(height: 12),
                const Text('albo wpisz kod:', style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _codeField,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 16, letterSpacing: 1),
                decoration: InputDecoration(hintText: 'XXXX-XXXX-XXXX-…', errorText: _error),
                onSubmitted: _connect,
              ),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => _connect(_codeField.text), child: const Text('Połącz')),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _hosting() {
    final host = _host!;
    final left = SyncHost.timeout - DateTime.now().difference(_hostStarted!);
    final secs = left.inSeconds.clamp(0, 999);
    return [
      const Text('Zeskanuj ten kod telefonem (Ustawienia › Synchronizacja › Zeskanuj kod QR) albo przepisz go na drugim urządzeniu.',
          style: TextStyle(fontSize: 15)),
      const SizedBox(height: 16),
      Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: QrImageView(data: host.code.qrText, size: 240, semanticsLabel: 'Kod QR do synchronizacji'),
        ),
      ),
      const SizedBox(height: 16),
      SelectableText(
        host.code.text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 1.5),
      ),
      const SizedBox(height: 8),
      Text('Kod ważny jeszcze ${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
          textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
      if (Platform.isWindows) ...[
        const SizedBox(height: 16),
        const Text(
          'Jeśli Windows zapyta o zaporę sieciową, zezwól aplikacji na dostęp w sieciach prywatnych.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ],
      const SizedBox(height: 20),
      OutlinedButton(onPressed: _reset, child: const Text('Anuluj')),
    ];
  }

  List<Widget> _done() {
    final s = _stats!;
    return [
      const SizedBox(height: 40),
      const Icon(Icons.check_circle_outline, size: 56, color: Color(0xFF0F766E)),
      const SizedBox(height: 12),
      const Text('Zsynchronizowano', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(
        s.nothingChanged
            ? 'Na tym urządzeniu wszystko było już aktualne.'
            : 'Na tym urządzeniu: nowe ${s.added}, zmienione ${s.updated}, usunięte ${s.removed}.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted, fontSize: 15),
      ),
      const SizedBox(height: 24),
      FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Gotowe')),
    ];
  }

  List<Widget> _failed() => [
        const SizedBox(height: 40),
        const Icon(Icons.wifi_off, size: 56, color: AppColors.danger),
        const SizedBox(height: 12),
        Text(_error ?? 'Coś poszło nie tak', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 24),
        FilledButton(onPressed: _reset, child: const Text('Spróbuj ponownie')),
      ];
}

class _ScannerPage extends StatefulWidget {
  const _ScannerPage();

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zeskanuj kod')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) return;
          for (final b in capture.barcodes) {
            final v = b.rawValue;
            if (v != null && v.startsWith(SyncCode.prefix)) {
              _handled = true;
              Navigator.of(context).pop(v);
              return;
            }
          }
        },
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';

import '../app.dart';
import '../theme.dart';
import 'app_updater.dart';

/// Karta na ekranie startowym, gdy na GitHubie jest nowsza wersja.
class UpdateCard extends StatefulWidget {
  const UpdateCard({super.key});

  @override
  State<UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<UpdateCard> {
  Future<ReleaseInfo?>? _future;
  bool _dismissed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final updater = AppScope.of(context).updater;
    if (_future == null && updater != null && updater.supported) _future = updater.checkOnce();
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null || _dismissed) return const SizedBox.shrink();
    return FutureBuilder<ReleaseInfo?>(
      future: future,
      builder: (context, snap) {
        final release = snap.data;
        if (release == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            color: AppColors.passwordsSoft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
              child: Row(
                children: [
                  const Icon(Icons.system_update_alt, color: AppColors.passwords),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Dostępna nowa wersja ${release.version}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                  TextButton(onPressed: () => setState(() => _dismissed = true), child: const Text('Później')),
                  FilledButton(onPressed: () => showUpdateDialog(context, release), child: const Text('Zaktualizuj')),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Wiersz w ustawieniach: wersja aplikacji i ręczne sprawdzenie aktualizacji.
class UpdateSettingsTile extends StatefulWidget {
  const UpdateSettingsTile({super.key});

  @override
  State<UpdateSettingsTile> createState() => _UpdateSettingsTileState();
}

class _UpdateSettingsTileState extends State<UpdateSettingsTile> {
  String? _version;
  bool _checking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final updater = AppScope.of(context).updater;
    if (_version == null && updater != null) {
      updater
          .currentVersion()
          .then((v) {
            if (mounted) setState(() => _version = '$v');
          })
          .catchError((Object _) {});
    }
  }

  Future<void> _check() async {
    final updater = AppScope.of(context).updater;
    if (updater == null || !updater.supported) return;
    setState(() => _checking = true);
    ReleaseInfo? release;
    String? error;
    try {
      release = await updater.check();
    } on UpdateException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Nie udało się sprawdzić aktualizacji.';
    }
    if (!mounted) return;
    setState(() => _checking = false);
    if (release != null) {
      await showUpdateDialog(context, release);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Masz najnowszą wersję.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final updater = AppScope.of(context).updater;
    if (updater == null || !updater.supported) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.system_update_alt),
      title: const Text('Sprawdź aktualizacje'),
      subtitle: Text(_version == null ? 'Wersja aplikacji' : 'Zainstalowana wersja $_version'),
      trailing: _checking
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      onTap: _checking ? null : _check,
    );
  }
}

Future<void> showUpdateDialog(BuildContext context, ReleaseInfo release) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(release: release),
  );
}

enum _Stage { ready, downloading, needsPermission, installing, error }

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.release});
  final ReleaseInfo release;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _Stage _stage = _Stage.ready;
  double? _progress;
  String? _error;
  File? _file;

  AppUpdater get _updater => AppScope.of(context).updater!;

  Future<void> _start() async {
    final updater = _updater;
    setState(() {
      _stage = _Stage.downloading;
      _progress = null;
      _error = null;
    });
    try {
      _file ??= await updater.download(
        widget.release,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      await _install();
    } on UpdateException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Nie udało się pobrać aktualizacji.');
    }
  }

  Future<void> _install() async {
    final updater = _updater;
    final vault = AppScope.of(context).vault;
    if (!await updater.canInstall()) {
      if (mounted) setState(() => _stage = _Stage.needsPermission);
      return;
    }
    if (!mounted) return;
    setState(() => _stage = _Stage.installing);
    await updater.install(_file!);
    if (updater.platform == UpdatePlatform.windows) {
      // Instalator podmienia pliki programu, więc aplikacja musi się zamknąć.
      await vault.lock();
      exit(0);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _stage = _Stage.error;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.release;
    final isWindows = _updater.platform == UpdatePlatform.windows;
    final sizeMb = r.size > 0 ? ' (${(r.size / 1024 / 1024).toStringAsFixed(0)} MB)' : '';
    final Widget content = switch (_stage) {
      _Stage.ready => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pobiorę wersję ${r.version}$sizeMb i ${isWindows ? 'uruchomię instalator. Aplikacja na chwilę się zamknie i otworzy ponownie.' : 'otworzę instalację. Twoje hasła i opłaty zostaną na miejscu.'}',
          ),
          if (r.notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Co nowego', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Text(r.notes, style: const TextStyle(color: AppColors.muted)),
              ),
            ),
          ],
        ],
      ),
      _Stage.downloading => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_progress == null ? 'Pobieranie…' : 'Pobieranie… ${(_progress! * 100).round()}%'),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: _progress),
        ],
      ),
      _Stage.needsPermission => const Text(
        'Android musi pozwolić tej aplikacji instalować aktualizacje. Otwórz ustawienia, włącz „Zezwalaj z tego źródła”, '
        'wróć tutaj i naciśnij „Zainstaluj”.',
      ),
      _Stage.installing => Text(
        isWindows
            ? 'Uruchamiam instalator…'
            : 'Potwierdź instalację w oknie Androida. Jeśli pojawi się komunikat o konflikcie pakietu, '
                  'ta wersja ma inny podpis niż zainstalowana i trzeba ją raz zainstalować ręcznie.',
      ),
      _Stage.error => Text(_error ?? 'Coś poszło nie tak.', style: const TextStyle(color: AppColors.danger)),
    };

    final busy = _stage == _Stage.downloading || (_stage == _Stage.installing && isWindows);
    final List<Widget> actions = switch (_stage) {
      _Stage.ready => [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Później')),
        FilledButton(onPressed: _start, child: const Text('Zaktualizuj')),
      ],
      _Stage.needsPermission => [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anuluj')),
        OutlinedButton(onPressed: _updater.openInstallPermissionSettings, child: const Text('Ustawienia')),
        FilledButton(onPressed: _install, child: const Text('Zainstaluj')),
      ],
      _Stage.installing => [
        if (!isWindows) TextButton(onPressed: _install, child: const Text('Otwórz ponownie')),
        if (!isWindows) FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Zamknij')),
      ],
      _Stage.error => [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Zamknij')),
        FilledButton(onPressed: _start, child: const Text('Spróbuj ponownie')),
      ],
      _Stage.downloading => const [],
    };

    return PopScope(
      canPop: !busy,
      child: AlertDialog(title: Text('Nowa wersja ${r.version}'), content: content, actions: actions),
    );
  }
}

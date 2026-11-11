import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/unlock_screen.dart';
import 'theme.dart';
import 'vault/biometric_unlock.dart';
import 'vault/vault_controller.dart';

/// Udostępnia sejf i biometrię wszystkim ekranom.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.vault, required this.biometrics, required super.child});
  final VaultController vault;
  final BiometricUnlock? biometrics;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      vault != oldWidget.vault || biometrics != oldWidget.biometrics;
}

class HaslaApp extends StatefulWidget {
  const HaslaApp({super.key, required this.controller, this.biometrics});
  final VaultController controller;
  final BiometricUnlock? biometrics;

  /// Po tylu sekundach w tle sejf sam się zablokuje.
  static const autoLockAfter = Duration(seconds: 60);

  @override
  State<HaslaApp> createState() => _HaslaAppState();
}

class _HaslaAppState extends State<HaslaApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  DateTime? _hiddenAt;
  VaultStatus? _lastStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onVaultChanged);
    _lastStatus = widget.controller.status;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onVaultChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onVaultChanged() {
    final status = widget.controller.status;
    if (status != _lastStatus) {
      _lastStatus = status;
      // Po zablokowaniu wracamy do ekranu odblokowania, zamykając wszystkie otwarte ekrany.
      _navigatorKey.currentState?.popUntil((r) => r.isFirst);
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _hiddenAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final hiddenAt = _hiddenAt;
        _hiddenAt = null;
        if (hiddenAt != null && DateTime.now().difference(hiddenAt) >= HaslaApp.autoLockAfter) {
          unawaited(widget.controller.lock());
        }
      case AppLifecycleState.detached:
        unawaited(widget.controller.lock());
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget home = switch (widget.controller.status) {
      VaultStatus.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
      VaultStatus.needsSetup => const SetupScreen(),
      VaultStatus.locked => const UnlockScreen(),
      VaultStatus.unlocked => const HomeScreen(),
    };
    return AppScope(
      vault: widget.controller,
      biometrics: widget.biometrics,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Hasła apka',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: KeyedSubtree(key: ValueKey(widget.controller.status), child: home),
      ),
    );
  }
}

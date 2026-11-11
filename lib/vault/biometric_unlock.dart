import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Odblokowanie odciskiem palca na Androidzie.
///
/// Klucz sejfu jest trzymany w bezpiecznym magazynie systemu (Android Keystore),
/// a dostęp do niego wymaga potwierdzenia biometrią.
class BiometricUnlock {
  BiometricUnlock({LocalAuthentication? auth, FlutterSecureStorage? storage})
      : _auth = auth ?? LocalAuthentication(),
        _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'vault_key_v1';
  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  Future<bool> isAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    if (!await isAvailable()) return false;
    try {
      return await _storage.containsKey(key: _keyName);
    } on PlatformException {
      return false;
    }
  }

  Future<bool> _confirm(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true);
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }

  /// Zapamiętuje klucz sejfu po potwierdzeniu odciskiem palca.
  Future<bool> enable(Uint8List key) async {
    if (!await _confirm('Potwierdź, aby włączyć odblokowanie odciskiem palca')) return false;
    await _storage.write(key: _keyName, value: base64Encode(key));
    return true;
  }

  Future<void> disable() => _storage.delete(key: _keyName);

  /// Pyta o odcisk palca i zwraca zapamiętany klucz (albo null).
  Future<Uint8List?> unlock() async {
    if (!await _confirm('Odblokuj Hasła apka')) return null;
    final value = await _storage.read(key: _keyName);
    return value == null ? null : base64Decode(value);
  }
}

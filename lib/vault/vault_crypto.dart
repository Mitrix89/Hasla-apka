import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Rzucany, gdy hasło główne (lub zapamiętany klucz) nie pasuje do sejfu.
class WrongPasswordException implements Exception {
  const WrongPasswordException();
  @override
  String toString() => 'Nieprawidłowe hasło główne';
}

/// Rzucany, gdy plik sejfu jest uszkodzony lub w nieznanym formacie.
class VaultFormatException implements Exception {
  const VaultFormatException(this.message);
  final String message;
  @override
  String toString() => 'Uszkodzony plik sejfu: $message';
}

/// Parametry funkcji Argon2id, która zamienia hasło główne na klucz szyfrujący.
class KdfParams {
  const KdfParams({
    required this.salt,
    this.memoryKiB = 19456,
    this.iterations = 2,
    this.parallelism = 1,
  });

  /// Zalecenia OWASP dla Argon2id: 19 MiB pamięci, 2 iteracje, 1 wątek.
  factory KdfParams.fresh({int memoryKiB = 19456, int iterations = 2, int parallelism = 1}) {
    return KdfParams(
      salt: randomBytes(16),
      memoryKiB: memoryKiB,
      iterations: iterations,
      parallelism: parallelism,
    );
  }

  final Uint8List salt;
  final int memoryKiB;
  final int iterations;
  final int parallelism;

  KdfParams withFreshSalt() => KdfParams(
        salt: randomBytes(16),
        memoryKiB: memoryKiB,
        iterations: iterations,
        parallelism: parallelism,
      );

  Map<String, dynamic> toJson() => {
        'name': 'argon2id',
        'memoryKiB': memoryKiB,
        'iterations': iterations,
        'parallelism': parallelism,
        'salt': base64Encode(salt),
      };

  factory KdfParams.fromJson(Map<String, dynamic> json) {
    if (json['name'] != 'argon2id') {
      throw VaultFormatException('nieznana funkcja KDF ${json['name']}');
    }
    return KdfParams(
      salt: base64Decode(json['salt'] as String),
      memoryKiB: json['memoryKiB'] as int,
      iterations: json['iterations'] as int,
      parallelism: json['parallelism'] as int,
    );
  }
}

Uint8List randomBytes(int length) {
  final rnd = Random.secure();
  return Uint8List.fromList(List<int>.generate(length, (_) => rnd.nextInt(256)));
}

/// Szyfrowanie sejfu: klucz z Argon2id, dane szyfrowane AES-256-GCM.
///
/// Plik sejfu to JSON z parametrami KDF, losowym nonce i zaszyfrowaną treścią.
/// Nic poza tymi metadanymi nie jest zapisywane jawnym tekstem.
class VaultCrypto {
  static const format = 'hasla-apka-vault';
  static const version = 1;
  static final _aes = AesGcm.with256bits();

  /// Wylicza klucz z hasła głównego. Działa w osobnym wątku, żeby nie blokować ekranu.
  static Future<Uint8List> deriveKey(String masterPassword, KdfParams params) {
    final passwordBytes = utf8.encode(masterPassword);
    final salt = params.salt;
    final memory = params.memoryKiB;
    final iterations = params.iterations;
    final parallelism = params.parallelism;
    return Isolate.run(() async {
      final algo = Argon2id(
        parallelism: parallelism,
        memory: memory,
        iterations: iterations,
        hashLength: 32,
      );
      final key = await algo.deriveKey(secretKey: SecretKey(passwordBytes), nonce: salt);
      return Uint8List.fromList(await key.extractBytes());
    });
  }

  /// Szyfruje dane sejfu. Za każdym razem używa nowego, losowego nonce.
  static Future<Map<String, dynamic>> encrypt(
    Map<String, dynamic> data,
    Uint8List key,
    KdfParams params,
  ) async {
    final nonce = _aes.newNonce();
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(data)),
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: utf8.encode('$format/$version'),
    );
    return {
      'format': format,
      'version': version,
      'kdf': params.toJson(),
      'cipher': 'aes-256-gcm',
      'nonce': base64Encode(box.nonce),
      'data': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  /// Odczytuje parametry KDF z pliku sejfu (potrzebne, by wyliczyć klucz).
  static KdfParams readParams(Map<String, dynamic> envelope) {
    _checkHeader(envelope);
    return KdfParams.fromJson((envelope['kdf'] as Map).cast<String, dynamic>());
  }

  /// Odszyfrowuje sejf. Rzuca [WrongPasswordException], gdy klucz nie pasuje.
  static Future<Map<String, dynamic>> decrypt(Map<String, dynamic> envelope, Uint8List key) async {
    _checkHeader(envelope);
    final SecretBox box;
    try {
      box = SecretBox(
        base64Decode(envelope['data'] as String),
        nonce: base64Decode(envelope['nonce'] as String),
        mac: Mac(base64Decode(envelope['mac'] as String)),
      );
    } catch (e) {
      throw VaultFormatException('$e');
    }
    final List<int> clear;
    try {
      clear = await _aes.decrypt(
        box,
        secretKey: SecretKey(key),
        aad: utf8.encode('$format/$version'),
      );
    } on SecretBoxAuthenticationError {
      throw const WrongPasswordException();
    }
    return (jsonDecode(utf8.decode(clear)) as Map).cast<String, dynamic>();
  }

  static void _checkHeader(Map<String, dynamic> envelope) {
    if (envelope['format'] != format) {
      throw const VaultFormatException('to nie jest plik sejfu Hasła apka');
    }
    if (envelope['version'] != version) {
      throw VaultFormatException('nieobsługiwana wersja ${envelope['version']}');
    }
  }
}

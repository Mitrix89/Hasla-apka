import 'package:flutter_test/flutter_test.dart';
import 'package:hasla_apka/vault/vault_crypto.dart';

KdfParams fastParams() => KdfParams.fresh(memoryKiB: 256, iterations: 1);

void main() {
  test('szyfrowanie i odszyfrowanie zwraca te same dane', () async {
    final params = fastParams();
    final key = await VaultCrypto.deriveKey('Zielony-Rower', params);
    final env = await VaultCrypto.encrypt({'passwords': ['a', 'ż']}, key, params);
    expect(env['data'], isNot(contains('passwords')));
    final data = await VaultCrypto.decrypt(env, key);
    expect(data['passwords'], ['a', 'ż']);
  });

  test('złe hasło rzuca WrongPasswordException', () async {
    final params = fastParams();
    final key = await VaultCrypto.deriveKey('dobre-haslo', params);
    final env = await VaultCrypto.encrypt({'x': 1}, key, params);
    final wrong = await VaultCrypto.deriveKey('zle-haslo', VaultCrypto.readParams(env));
    expect(() => VaultCrypto.decrypt(env, wrong), throwsA(isA<WrongPasswordException>()));
  });

  test('każdy zapis ma inny nonce', () async {
    final params = fastParams();
    final key = await VaultCrypto.deriveKey('haslo', params);
    final a = await VaultCrypto.encrypt({'x': 1}, key, params);
    final b = await VaultCrypto.encrypt({'x': 1}, key, params);
    expect(a['nonce'], isNot(b['nonce']));
  });

  test('to samo hasło i sól dają ten sam klucz, inna sól inny', () async {
    final params = fastParams();
    final k1 = await VaultCrypto.deriveKey('haslo', params);
    final k2 = await VaultCrypto.deriveKey('haslo', params);
    final k3 = await VaultCrypto.deriveKey('haslo', params.withFreshSalt());
    expect(k1, k2);
    expect(k1, isNot(k3));
  });

  test('zmieniony szyfrogram jest odrzucany', () async {
    final params = fastParams();
    final key = await VaultCrypto.deriveKey('haslo', params);
    final env = await VaultCrypto.encrypt({'x': 1}, key, params);
    final data = env['data'] as String;
    env['data'] = (data[0] == 'A' ? 'B' : 'A') + data.substring(1);
    expect(() => VaultCrypto.decrypt(env, key), throwsA(isA<WrongPasswordException>()));
  });

  test('obcy plik jest odrzucany', () {
    expect(() => VaultCrypto.readParams({'format': 'cos-innego'}), throwsA(isA<VaultFormatException>()));
  });
}

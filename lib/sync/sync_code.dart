import 'dart:io';
import 'dart:typed_data';

import '../vault/vault_crypto.dart';

/// Jednorazowy kod parowania: adres urządzenia, port i tajny klucz sesji.
///
/// Kod jest pokazywany jako QR i jako tekst do przepisania, np.
/// `K4ZQ-2B7M-…`. Zawiera sumę kontrolną, więc literówka zostanie wykryta.
class SyncCode {
  SyncCode({required this.address, required this.port, required this.secret})
      : assert(secret.length == secretLength);

  factory SyncCode.generate(InternetAddress address, int port) =>
      SyncCode(address: address, port: port, secret: randomBytes(secretLength));

  static const secretLength = 10;
  static const prefix = 'HASLA1:';

  final InternetAddress address;
  final int port;
  final Uint8List secret;

  /// Tekst w kodzie QR.
  String get qrText => '$prefix$text';

  /// Tekst do przepisania (grupy po 4 znaki).
  String get text {
    final raw = BytesBuilder()
      ..add(address.rawAddress)
      ..add([port >> 8, port & 0xff])
      ..add(secret);
    final bytes = raw.toBytes();
    final withSum = Uint8List.fromList([...bytes, _checksum(bytes)]);
    final b32 = _base32(withSum);
    final groups = <String>[];
    for (var i = 0; i < b32.length; i += 4) {
      groups.add(b32.substring(i, i + 4 > b32.length ? b32.length : i + 4));
    }
    return groups.join('-');
  }

  /// Odczytuje kod z QR albo wpisany ręcznie. Zwraca null, gdy kod jest błędny.
  static SyncCode? tryParse(String input) {
    var s = input.trim().toUpperCase();
    if (s.startsWith(prefix)) s = s.substring(prefix.length);
    s = s.replaceAll(RegExp(r'[\s-]'), '').replaceAll('0', 'O').replaceAll('1', 'I').replaceAll('8', 'B');
    final bytes = _unbase32(s);
    if (bytes == null || bytes.length != 4 + 2 + secretLength + 1) return null;
    final data = bytes.sublist(0, bytes.length - 1);
    if (_checksum(data) != bytes.last) return null;
    return SyncCode(
      address: InternetAddress.fromRawAddress(Uint8List.fromList(data.sublist(0, 4))),
      port: (data[4] << 8) | data[5],
      secret: Uint8List.fromList(data.sublist(6)),
    );
  }
}

const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

int _checksum(List<int> bytes) {
  var a = 0x5A;
  for (final b in bytes) {
    a = ((a * 31) + b) & 0xff;
  }
  return a;
}

String _base32(List<int> bytes) {
  final sb = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final b in bytes) {
    buffer = (buffer << 8) | b;
    bits += 8;
    while (bits >= 5) {
      sb.write(_alphabet[(buffer >> (bits - 5)) & 31]);
      bits -= 5;
    }
  }
  if (bits > 0) sb.write(_alphabet[(buffer << (5 - bits)) & 31]);
  return sb.toString();
}

List<int>? _unbase32(String s) {
  final out = <int>[];
  var buffer = 0;
  var bits = 0;
  for (final c in s.split('')) {
    final v = _alphabet.indexOf(c);
    if (v == -1) return null;
    buffer = ((buffer << 5) | v) & 0xffff;
    bits += 5;
    if (bits >= 8) {
      out.add((buffer >> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return out;
}

/// Najbardziej prawdopodobny adres w sieci domowej (192.168.x.x, potem 10.x, potem 172.16–31.x).
Future<InternetAddress?> localNetworkAddress() async {
  final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
  final candidates = [for (final i in interfaces) ...i.addresses].where((a) => !a.isLoopback).toList();
  int rank(InternetAddress a) {
    final b = a.rawAddress;
    if (b[0] == 192 && b[1] == 168) return 0;
    if (b[0] == 10) return 1;
    if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return 2;
    return 3;
  }
  candidates.sort((a, b) => rank(a).compareTo(rank(b)));
  return candidates.isEmpty ? null : candidates.first;
}

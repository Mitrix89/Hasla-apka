import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'sync_code.dart';
import 'sync_merge.dart';

/// Błąd synchronizacji z komunikatem do pokazania użytkownikowi.
class SyncException implements Exception {
  const SyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Szyfrowany kanał oparty na tajnym kluczu z kodu parowania.
/// Dane w sieci są zaszyfrowane AES-256-GCM, więc nikt w tej samej sieci ich nie odczyta.
class SyncChannel {
  SyncChannel(this._secret);
  final Uint8List _secret;
  static final _aes = AesGcm.with256bits();
  SecretKey? _key;

  Future<SecretKey> _deriveKey() async => _key ??= await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
        secretKey: SecretKey(_secret),
        nonce: utf8.encode('hasla-apka-sync'),
        info: utf8.encode('v1'),
      );

  Future<String> seal(Map<String, dynamic> message, String direction) async {
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(message)),
      secretKey: await _deriveKey(),
      aad: utf8.encode(direction),
    );
    return jsonEncode({
      'nonce': base64Encode(box.nonce),
      'data': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  /// Rzuca [SyncException], gdy wiadomość nie pochodzi od sparowanego urządzenia.
  Future<Map<String, dynamic>> open(String body, String direction) async {
    try {
      final j = (jsonDecode(body) as Map).cast<String, dynamic>();
      final clear = await _aes.decrypt(
        SecretBox(
          base64Decode(j['data'] as String),
          nonce: base64Decode(j['nonce'] as String),
          mac: Mac(base64Decode(j['mac'] as String)),
        ),
        secretKey: await _deriveKey(),
        aad: utf8.encode(direction),
      );
      return (jsonDecode(utf8.decode(clear)) as Map).cast<String, dynamic>();
    } catch (_) {
      throw const SyncException('Nieprawidłowy kod parowania');
    }
  }
}

const _toHost = 'do-hosta';
const _toClient = 'do-klienta';
/// 2: kategorie haseł. Starsza wersja na drugim urządzeniu zgubiłaby je, więc odmawiamy.
const _protocol = 2;

/// Urządzenie, które czeka na połączenie (pokazuje kod QR).
class SyncHost {
  SyncHost._(this._server, this.code);

  final HttpServer _server;
  final SyncCode code;
  final _done = Completer<SyncStats>();
  int _failedAttempts = 0;
  Timer? _timeout;

  /// Po tylu nieudanych próbach (zły kod) host przestaje nasłuchiwać.
  static const maxFailedAttempts = 5;
  static const timeout = Duration(minutes: 3);

  /// Uruchamia nasłuch w sieci lokalnej. [merge] dostaje dane z drugiego urządzenia,
  /// zapisuje scalony wynik u siebie i zwraca go, żeby odesłać drugiemu urządzeniu.
  static Future<SyncHost> start({
    required Future<({SyncData merged, SyncStats stats})> Function(SyncData remote) merge,
    InternetAddress? advertise,
    InternetAddress? bindAddress,
  }) async {
    final address = advertise ?? await localNetworkAddress();
    if (address == null) {
      throw const SyncException('Brak połączenia z siecią. Połącz urządzenie z domowym Wi-Fi.');
    }
    final server = await HttpServer.bind(bindAddress ?? InternetAddress.anyIPv4, 0);
    final host = SyncHost._(server, SyncCode.generate(address, server.port));
    host._listen(merge);
    return host;
  }

  /// Kończy się, gdy synchronizacja się uda (albo błędem / po czasie).
  Future<SyncStats> get done => _done.future;

  void _listen(Future<({SyncData merged, SyncStats stats})> Function(SyncData remote) merge) {
    final channel = SyncChannel(code.secret);
    _timeout = Timer(timeout, () => _finish(error: const SyncException('Minął czas na połączenie. Spróbuj ponownie.')));
    _server.listen((request) async {
      final response = request.response;
      if (request.method != 'POST' || request.uri.path != '/sync' || _done.isCompleted) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      try {
        final body = await utf8.decodeStream(request).timeout(const Duration(seconds: 30));
        final msg = await channel.open(body, _toHost);
        if (msg['protocol'] != _protocol) {
          throw const SyncException('Zaktualizuj aplikację na obu urządzeniach do tej samej wersji.');
        }
        final result = await merge(SyncData.fromJson((msg['data'] as Map).cast<String, dynamic>()));
        response.headers.contentType = ContentType.json;
        response.write(await channel.seal({'protocol': _protocol, 'data': result.merged.toJson()}, _toClient));
        await response.close();
        _finish(stats: result.stats);
      } on SyncException catch (e) {
        response.statusCode = HttpStatus.forbidden;
        await response.close();
        if (++_failedAttempts >= maxFailedAttempts) _finish(error: e);
      } catch (_) {
        response.statusCode = HttpStatus.internalServerError;
        await response.close();
      }
    });
  }

  void _finish({SyncStats? stats, Object? error}) {
    _timeout?.cancel();
    unawaited(_server.close(force: true));
    if (_done.isCompleted) return;
    if (error != null) {
      _done.completeError(error);
    } else {
      _done.complete(stats);
    }
  }

  /// Przerywa czekanie (np. po wyjściu z ekranu).
  void cancel() => _finish(error: const SyncException('Anulowano'));
}

/// Łączy się z urządzeniem, które pokazuje kod, i zwraca scalone dane.
Future<SyncData> syncWithHost(SyncCode code, SyncData local) async {
  final channel = SyncChannel(code.secret);
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final request = await client.post(code.address.address, code.port, '/sync');
    request.headers.contentType = ContentType.json;
    request.write(await channel.seal({'protocol': _protocol, 'data': local.toJson()}, _toHost));
    final response = await request.close().timeout(const Duration(seconds: 60));
    final body = await utf8.decodeStream(response);
    if (response.statusCode == HttpStatus.forbidden) {
      throw const SyncException(
        'Drugie urządzenie odrzuciło połączenie. Sprawdź, czy kod jest przepisany dokładnie '
        'i czy na obu urządzeniach jest ta sama wersja aplikacji.',
      );
    }
    if (response.statusCode != HttpStatus.ok) {
      throw const SyncException('Drugie urządzenie nie czeka już na połączenie. Pokaż nowy kod.');
    }
    final msg = await channel.open(body, _toClient);
    return SyncData.fromJson((msg['data'] as Map).cast<String, dynamic>());
  } on SocketException {
    throw const SyncException(
      'Nie udało się połączyć. Oba urządzenia muszą być w tej samej sieci Wi-Fi, '
      'a na komputerze zapora Windows musi zezwolić aplikacji na połączenia.',
    );
  } on TimeoutException {
    throw const SyncException('Drugie urządzenie nie odpowiada.');
  } finally {
    client.close(force: true);
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Repozytorium, z którego aplikacja pobiera nowe wersje (wydania na GitHubie).
/// Można je zmienić przy budowaniu: --dart-define=UPDATE_REPO=wlasciciel/repo
const updateRepo = String.fromEnvironment('UPDATE_REPO', defaultValue: 'Mitrix89/Hasla-apka');

/// Numer wersji w postaci 1.2.3 (bez numeru kompilacji).
@immutable
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  /// Przyjmuje „1.2.3”, „v1.2.3” albo „1.2.3+4”. Zwraca null dla innych napisów.
  static AppVersion? tryParse(String text) {
    final m = RegExp(r'^v?(\d+)\.(\d+)(?:\.(\d+))?(?:[+-].*)?$').firstMatch(text.trim());
    if (m == null) return null;
    return AppVersion(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3] ?? '0'));
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

enum UpdatePlatform { android, windows }

/// Nowa wersja gotowa do pobrania.
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.notes,
    required this.downloadUrl,
    required this.fileName,
    required this.size,
    this.sha256,
  });

  final AppVersion version;
  final String notes;
  final Uri downloadUrl;
  final String fileName;
  final int size;

  /// Suma kontrolna pliku podana przez GitHuba (małe litery, hex), jeśli jest.
  final String? sha256;
}

class UpdateException implements Exception {
  UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Odczytuje wydanie z odpowiedzi GitHuba (/releases/latest) i wybiera plik dla danej platformy.
/// Zwraca null, gdy wydanie nie ma pliku dla tej platformy albo ma dziwny numer.
ReleaseInfo? parseRelease(Map<String, dynamic> json, UpdatePlatform platform) {
  if (json['draft'] == true || json['prerelease'] == true) return null;
  final version = AppVersion.tryParse('${json['tag_name'] ?? ''}');
  if (version == null) return null;
  final assets = (json['assets'] as List? ?? const []).whereType<Map<String, dynamic>>();
  for (final a in assets) {
    final name = '${a['name'] ?? ''}';
    final lower = name.toLowerCase();
    final fits = switch (platform) {
      UpdatePlatform.android => lower.endsWith('.apk'),
      UpdatePlatform.windows => lower.endsWith('.exe') && lower.contains('setup'),
    };
    if (!fits) continue;
    final url = Uri.tryParse('${a['browser_download_url'] ?? ''}');
    if (url == null || url.scheme != 'https') continue;
    final digest = '${a['digest'] ?? ''}';
    return ReleaseInfo(
      version: version,
      notes: cleanReleaseNotes('${json['body'] ?? ''}'),
      downloadUrl: url,
      fileName: name,
      size: (a['size'] as num?)?.toInt() ?? 0,
      sha256: digest.startsWith('sha256:') ? digest.substring(7).toLowerCase() : null,
    );
  }
  return null;
}

/// Z automatycznych notatek GitHuba zostawia same tytuły zmian, bez linków i autorów.
String cleanReleaseNotes(String body) {
  final lines = <String>[];
  var skipSection = false;
  for (var line in const LineSplitter().convert(body)) {
    line = line.trim();
    if (line.startsWith('#')) {
      // Sekcja „New Contributors” nie mówi nic o zmianach w aplikacji.
      skipSection = line.toLowerCase().contains('contributor');
      continue;
    }
    if (skipSection || line.isEmpty || line.startsWith('**Full Changelog')) continue;
    line = line.replaceFirst(RegExp(r'\s+by @\S+ in https://\S+$'), '');
    line = line.replaceFirst(RegExp(r'^[*-]\s+'), '• ');
    lines.add(line);
  }
  return lines.join('\n');
}

/// Sprawdza, pobiera i uruchamia instalację nowej wersji aplikacji.
class AppUpdater {
  AppUpdater({this.repo = updateRepo, UpdatePlatform? platform, Future<AppVersion> Function()? currentVersion})
    : platform = platform ?? _hostPlatform(),
      _currentVersion = currentVersion ?? _installedVersion;

  final String repo;
  final UpdatePlatform? platform;
  final Future<AppVersion> Function() _currentVersion;

  static const _channel = MethodChannel('hasla/update');

  Future<ReleaseInfo?>? _cached;

  bool get supported => platform != null;

  static UpdatePlatform? _hostPlatform() {
    if (kIsWeb) return null;
    if (Platform.isAndroid) return UpdatePlatform.android;
    if (Platform.isWindows) return UpdatePlatform.windows;
    return null;
  }

  static Future<AppVersion> _installedVersion() async {
    final info = await PackageInfo.fromPlatform();
    return AppVersion.tryParse(info.version) ?? const AppVersion(0, 0, 0);
  }

  Future<AppVersion> currentVersion() => _currentVersion();

  /// Sprawdza raz na uruchomienie aplikacji; błędy (np. brak internetu) dają null.
  Future<ReleaseInfo?> checkOnce() => _cached ??= check().catchError((Object _) => null);

  /// Zwraca nowszą wersję, jeśli jest; null, gdy aplikacja jest aktualna.
  Future<ReleaseInfo?> check() async {
    final target = platform;
    if (target == null) return null;
    final json = await _getJson(Uri.https('api.github.com', '/repos/$repo/releases/latest'));
    final release = parseRelease(json, target);
    final current = await _currentVersion();
    final result = release != null && release.version > current ? release : null;
    _cached = Future.value(result);
    return result;
  }

  Future<Map<String, dynamic>> _getJson(Uri url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(url);
      req.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'hasla-apka');
      final res = await req.close().timeout(const Duration(seconds: 20));
      final body = await utf8.decodeStream(res);
      if (res.statusCode == 404) {
        throw UpdateException('Nie znaleziono wydań aplikacji na GitHubie.');
      }
      if (res.statusCode != 200) {
        throw UpdateException('GitHub odpowiedział błędem ${res.statusCode}.');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) throw UpdateException('Nieczytelna odpowiedź GitHuba.');
      return decoded;
    } on SocketException {
      throw UpdateException('Brak połączenia z internetem.');
    } on TimeoutException {
      throw UpdateException('GitHub nie odpowiada. Spróbuj później.');
    } finally {
      client.close(force: true);
    }
  }

  /// Pobiera plik instalacyjny i sprawdza jego rozmiar oraz sumę kontrolną.
  Future<File> download(ReleaseInfo release, {void Function(double progress)? onProgress}) async {
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}aktualizacje');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final safeName = release.fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${dir.path}${Platform.pathSeparator}$safeName');

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(release.downloadUrl);
      req.headers.set(HttpHeaders.userAgentHeader, 'hasla-apka');
      final res = await req.close();
      if (res.statusCode != 200) throw UpdateException('Pobieranie nie powiodło się (błąd ${res.statusCode}).');
      final total = release.size > 0 ? release.size : res.contentLength;
      final sink = file.openWrite();
      final hasher = Sha256().newHashSink();
      var received = 0;
      try {
        await for (final chunk in res) {
          sink.add(chunk);
          hasher.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call((received / total).clamp(0, 1).toDouble());
        }
      } finally {
        await sink.close();
      }
      hasher.close();
      if (release.size > 0 && received != release.size) {
        throw UpdateException('Plik pobrał się niekompletnie. Spróbuj jeszcze raz.');
      }
      final expected = release.sha256;
      if (expected != null) {
        final actual = (await hasher.hash()).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        if (actual != expected) {
          throw UpdateException('Pobrany plik jest uszkodzony (zła suma kontrolna).');
        }
      }
      return file;
    } on SocketException {
      if (file.existsSync()) file.deleteSync();
      throw UpdateException('Przerwane połączenie z internetem.');
    } on UpdateException {
      if (file.existsSync()) file.deleteSync();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  /// Android: czy aplikacja ma zgodę na instalowanie plików APK.
  Future<bool> canInstall() async {
    if (platform != UpdatePlatform.android) return true;
    return await _channel.invokeMethod<bool>('canInstall') ?? false;
  }

  /// Android: otwiera ustawienia, w których można zezwolić na instalowanie aplikacji.
  Future<void> openInstallPermissionSettings() => _channel.invokeMethod('openInstallSettings');

  /// Android: otwiera systemowe okno instalacji.
  /// Windows: uruchamia instalator w tle; aplikację trzeba zaraz potem zamknąć.
  Future<void> install(File file) async {
    switch (platform) {
      case UpdatePlatform.android:
        await _channel.invokeMethod('installApk', {'path': file.path});
      case UpdatePlatform.windows:
        await Process.start(file.path, const [
          '/SILENT',
          '/SUPPRESSMSGBOXES',
          '/CLOSEAPPLICATIONS',
          '/NORESTART',
        ], mode: ProcessStartMode.detached);
      case null:
        throw UpdateException('Aktualizacje nie są dostępne na tym urządzeniu.');
    }
  }
}

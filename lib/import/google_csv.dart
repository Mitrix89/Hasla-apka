import '../models/password_entry.dart';
import '../util/ids.dart';

/// Błąd odczytu pliku z eksportu haseł.
class CsvImportException implements Exception {
  const CsvImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Parser CSV zgodny z RFC 4180: pola w cudzysłowach, przecinki i nowe linie w polach,
/// podwójny cudzysłów jako znak cudzysłowu.
List<List<String>> parseCsv(String input) {
  var text = input;
  if (text.startsWith('﻿')) text = text.substring(1);
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var i = 0;
  while (i < text.length) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
      } else {
        field.write(c);
      }
      i++;
      continue;
    }
    switch (c) {
      case '"':
        inQuotes = true;
      case ',':
        row.add(field.toString());
        field.clear();
      case '\r':
        break;
      case '\n':
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
      default:
        field.write(c);
    }
    i++;
  }
  if (inQuotes) throw const CsvImportException('Plik CSV jest niekompletny (niezamknięty cudzysłów).');
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows.where((r) => !(r.length == 1 && r.first.trim().isEmpty)).toList();
}

/// Zamienia plik CSV wyeksportowany z Menedżera haseł Google na wpisy sejfu.
///
/// Google eksportuje kolumny: name, url, username, password, note.
/// Adres w formie `android://...@com.przyklad.app/` oznacza aplikację na Androida.
List<PasswordEntry> parseGooglePasswordsCsv(String csv, {DateTime? now}) {
  final rows = parseCsv(csv);
  if (rows.isEmpty) throw const CsvImportException('Plik jest pusty.');
  final header = rows.first.map((h) => h.trim().toLowerCase()).toList();
  final iName = header.indexOf('name');
  final iUrl = header.indexOf('url');
  final iUser = header.indexOf('username');
  final iPass = header.indexOf('password');
  final iNote = header.indexOf('note');
  if (iUrl == -1 || iUser == -1 || iPass == -1) {
    throw const CsvImportException(
      'To nie wygląda na eksport z Haseł Google (brak kolumn url, username, password).',
    );
  }
  String at(List<String> r, int i) => (i >= 0 && i < r.length) ? r[i].trim() : '';

  final result = <PasswordEntry>[];
  for (final r in rows.skip(1)) {
    final url = at(r, iUrl);
    final username = at(r, iUser);
    final password = at(r, iPass);
    if (url.isEmpty && username.isEmpty && password.isEmpty) continue;
    final app = androidPackageFromUrl(url);
    final site = app == null ? websiteFromUrl(url) : null;
    var name = at(r, iName);
    if (name.isEmpty) name = app ?? site ?? 'Bez nazwy';
    result.add(PasswordEntry(
      id: newId(),
      name: name,
      username: username,
      password: password,
      apps: app == null ? const [] : [app],
      websites: (site == null || site.isEmpty) ? const [] : [site],
      note: at(r, iNote),
      createdAt: now,
    ));
  }
  return result;
}

/// `android://HASH@com.netflix.mediaclient/` -> `com.netflix.mediaclient`
String? androidPackageFromUrl(String url) {
  if (!url.toLowerCase().startsWith('android://')) return null;
  var rest = url.substring('android://'.length);
  final at = rest.lastIndexOf('@');
  if (at != -1) rest = rest.substring(at + 1);
  rest = rest.split('/').first.trim();
  return rest.isEmpty ? null : rest;
}

/// `https://www.netflix.com/login?x=1` -> `netflix.com`
String? websiteFromUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed.contains('://') ? trimmed : 'https://$trimmed');
  var host = uri?.host ?? '';
  if (host.isEmpty) return trimmed;
  if (host.startsWith('www.')) host = host.substring(4);
  return host;
}

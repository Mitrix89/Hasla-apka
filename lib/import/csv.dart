/// Błąd odczytu pliku CSV.
class CsvImportException implements Exception {
  const CsvImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Parser CSV zgodny z RFC 4180: pola w cudzysłowach, przecinki i nowe linie w polach,
/// podwójny cudzysłów jako znak cudzysłowu.
List<List<String>> parseCsv(String input, {String delimiter = ','}) {
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
      case _ when c == delimiter:
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


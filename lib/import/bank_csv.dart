import 'dart:convert';

import '../models/payment.dart';
import '../util/format.dart';
import 'csv.dart';

/// Jedna operacja z wyciągu bankowego.
class BankTransaction {
  const BankTransaction({required this.date, required this.amountCents, required this.description});
  final DateTime date;

  /// Ujemna kwota = wydatek.
  final int amountCents;
  final String description;
}

/// Wykryta stała płatność, którą można dodać do opłat.
class RecurringCandidate {
  const RecurringCandidate({
    required this.name,
    required this.kind,
    required this.amountCents,
    required this.repeat,
    required this.nextDue,
    required this.occurrences,
    required this.lastDate,
  });

  final String name;
  final PaymentKind kind;
  final int amountCents;
  final Repeat repeat;
  final DateTime nextDue;
  final int occurrences;
  final DateTime lastDate;
}

/// Odczyt pliku z banku: najpierw UTF-8, a gdy się nie da, Windows-1250
/// (tak eksportuje część polskich banków).
String decodeBankFile(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return _decodeCp1250(bytes);
  }
}

String _decodeCp1250(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.writeCharCode(b < 0x80 ? b : _cp1250[b - 0x80]);
  }
  return sb.toString();
}

const _cp1250 = <int>[
  0x20AC, 0xFFFD, 0x201A, 0xFFFD, 0x201E, 0x2026, 0x2020, 0x2021, 0xFFFD, 0x2030, 0x0160, 0x2039, 0x015A, 0x0164, 0x017D, 0x0179, //
  0xFFFD, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0xFFFD, 0x2122, 0x0161, 0x203A, 0x015B, 0x0165, 0x017E, 0x017A, //
  0x00A0, 0x02C7, 0x02D8, 0x0141, 0x00A4, 0x0104, 0x00A6, 0x00A7, 0x00A8, 0x00A9, 0x015E, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x017B, //
  0x00B0, 0x00B1, 0x02DB, 0x0142, 0x00B4, 0x00B5, 0x00B6, 0x00B7, 0x00B8, 0x0105, 0x015F, 0x00BB, 0x013D, 0x02DD, 0x013E, 0x017C, //
  0x0154, 0x00C1, 0x00C2, 0x0102, 0x00C4, 0x0139, 0x0106, 0x00C7, 0x010C, 0x00C9, 0x0118, 0x00CB, 0x011A, 0x00CD, 0x00CE, 0x010E, //
  0x0110, 0x0143, 0x0147, 0x00D3, 0x00D4, 0x0150, 0x00D6, 0x00D7, 0x0158, 0x016E, 0x00DA, 0x0170, 0x00DC, 0x00DD, 0x0162, 0x00DF, //
  0x0155, 0x00E1, 0x00E2, 0x0103, 0x00E4, 0x013A, 0x0107, 0x00E7, 0x010D, 0x00E9, 0x0119, 0x00EB, 0x011B, 0x00ED, 0x00EE, 0x010F, //
  0x0111, 0x0144, 0x0148, 0x00F3, 0x00F4, 0x0151, 0x00F6, 0x00F7, 0x0159, 0x016F, 0x00FA, 0x0171, 0x00FC, 0x00FD, 0x0163, 0x02D9, //
];

String _norm(String s) => s
    .toLowerCase()
    .replaceAll('#', '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _isDateHeader(String h) {
  final n = _norm(h);
  return n == 'data' || n.startsWith('data operacji') || n.startsWith('data transakcji') ||
      n.startsWith('data księgowania') || n.startsWith('data ksiegowania') || n == 'date';
}

bool _isAmountHeader(String h) {
  final n = _norm(h);
  return n == 'kwota' || n.startsWith('kwota operacji') || n.startsWith('kwota transakcji') ||
      n.startsWith('kwota w walucie rachunku') || n == 'amount' || n.startsWith('kwota (');
}

bool _isDescriptionHeader(String h) {
  final n = _norm(h);
  const keys = ['opis', 'tytuł', 'tytul', 'kontrahent', 'odbiorca', 'nadawca', 'nazwa', 'szczegóły', 'description', 'title'];
  return keys.any(n.contains);
}

String _detectDelimiter(String text) {
  final sample = text.split('\n').take(40).join('\n');
  int count(String c) => c.allMatches(sample).length;
  final counts = {';': count(';'), ',': count(','), '\t': count('\t')};
  return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

DateTime? parseBankDate(String s) {
  final t = s.trim();
  var m = RegExp(r'^(\d{4})[-./](\d{1,2})[-./](\d{1,2})').firstMatch(t);
  if (m != null) return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  m = RegExp(r'^(\d{1,2})[-./](\d{1,2})[-./](\d{4})').firstMatch(t);
  if (m != null) return DateTime(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  return null;
}

/// Czyta operacje z pliku CSV z banku. Rozpoznaje kolumny po nagłówkach
/// (data, kwota, opis/tytuł/kontrahent), więc działa z eksportami większości banków.
List<BankTransaction> parseBankCsv(String text) {
  final delimiter = _detectDelimiter(text);
  final rows = parseCsv(text, delimiter: delimiter);
  var headerIndex = -1;
  for (var i = 0; i < rows.length && i < 60; i++) {
    if (rows[i].any(_isDateHeader) && rows[i].any(_isAmountHeader)) {
      headerIndex = i;
      break;
    }
  }
  if (headerIndex == -1) {
    throw const CsvImportException(
      'Nie rozpoznano kolumn z datą i kwotą. Wyeksportuj historię rachunku jako CSV.',
    );
  }
  final header = rows[headerIndex];
  final iDate = header.indexWhere(_isDateHeader);
  final iAmount = header.indexWhere(_isAmountHeader);
  final iDesc = [
    for (var i = 0; i < header.length; i++)
      if (i != iDate && i != iAmount && _isDescriptionHeader(header[i])) i,
  ];

  final result = <BankTransaction>[];
  for (final r in rows.skip(headerIndex + 1)) {
    if (r.length <= iDate || r.length <= iAmount) continue;
    final date = parseBankDate(r[iDate]);
    final amount = parseMoney(r[iAmount]);
    if (date == null || amount == null) continue;
    final desc = iDesc.where((i) => i < r.length).map((i) => r[i].trim()).where((s) => s.isNotEmpty).join(' ');
    result.add(BankTransaction(date: date, amountCents: amount, description: desc));
  }
  if (result.isEmpty) throw const CsvImportException('W pliku nie ma żadnych operacji.');
  return result;
}

class _Known {
  const _Known(this.pattern, this.name, this.kind);
  final String pattern;
  final String name;
  final PaymentKind kind;
}

const _known = [
  _Known('netflix', 'Netflix', PaymentKind.subscription),
  _Known('spotify', 'Spotify', PaymentKind.subscription),
  _Known('youtube', 'YouTube Premium', PaymentKind.subscription),
  _Known('google one', 'Google One', PaymentKind.subscription),
  _Known('google play', 'Sklep Play', PaymentKind.subscription),
  _Known('google *', 'Sklep Play', PaymentKind.subscription),
  _Known('disney', 'Disney+', PaymentKind.subscription),
  _Known('hbo', 'Max (HBO)', PaymentKind.subscription),
  _Known('max.com', 'Max (HBO)', PaymentKind.subscription),
  _Known('amazon prime', 'Amazon Prime', PaymentKind.subscription),
  _Known('primevideo', 'Amazon Prime', PaymentKind.subscription),
  _Known('apple.com', 'Apple', PaymentKind.subscription),
  _Known('microsoft', 'Microsoft', PaymentKind.subscription),
  _Known('xbox', 'Xbox', PaymentKind.subscription),
  _Known('playstation', 'PlayStation', PaymentKind.subscription),
  _Known('canal+', 'Canal+', PaymentKind.subscription),
  _Known('player.pl', 'Player', PaymentKind.subscription),
  _Known('polsat box go', 'Polsat Box Go', PaymentKind.subscription),
  _Known('multisport', 'Multisport', PaymentKind.subscription),
  _Known('chatgpt', 'ChatGPT', PaymentKind.subscription),
  _Known('openai', 'ChatGPT', PaymentKind.subscription),
  _Known('claude', 'Claude', PaymentKind.subscription),
  _Known('anthropic', 'Claude', PaymentKind.subscription),
  _Known('vectra', 'Vectra', PaymentKind.bill),
  _Known('upc', 'UPC', PaymentKind.bill),
  _Known('orange', 'Orange', PaymentKind.bill),
  _Known('t-mobile', 'T-Mobile', PaymentKind.bill),
  _Known('plus', 'Plus', PaymentKind.bill),
  _Known('p4 sp', 'Play', PaymentKind.bill),
  _Known('pge', 'PGE (prąd)', PaymentKind.bill),
  _Known('tauron', 'Tauron (prąd)', PaymentKind.bill),
  _Known('enea', 'Enea (prąd)', PaymentKind.bill),
  _Known('energa', 'Energa (prąd)', PaymentKind.bill),
  _Known('e.on', 'E.ON (prąd)', PaymentKind.bill),
  _Known('pgnig', 'PGNiG (gaz)', PaymentKind.bill),
  _Known('ubezpiecz', 'Ubezpieczenie', PaymentKind.bill),
];

/// Słowa, które nic nie mówią o odbiorcy (typ operacji, waluta itp.).
const _noise = {
  'płatność', 'platnosc', 'kartą', 'karta', 'karty', 'zakup', 'transakcja', 'blik', 'pln', 'eur', 'usd',
  'przelew', 'zlecenie', 'stałe', 'stale', 'polecenie', 'zapłaty', 'zaplaty', 'obciążenie', 'obciazenie',
  'tytuł', 'tytul', 'nr', 'ref', 'operacja', 'internetowy', 'wychodzący', 'wychodzacy', 'na', 'rachunek',
  'adres', 'miasto', 'kraj', 'pol', 'poland', 'polska', 'lokalizacja', 'oryginalna', 'kwota', 'data', 'wykonania',
  'do', 'z', 'w', 'i', 'od',
};

({String key, String name, PaymentKind kind}) _merchant(String description) {
  final d = description.toLowerCase();
  for (final k in _known) {
    if (k.pattern == 'plus' ? RegExp(r'\bplus\b').hasMatch(d) : d.contains(k.pattern)) {
      return (key: 'k:${k.name}', name: k.name, kind: k.kind);
    }
  }
  final words = d
      .replaceAll(RegExp(r'[0-9]'), ' ')
      .split(RegExp(r'[^a-ząćęłńóśźż.+*-]+'))
      .map((w) => w.replaceAll(RegExp(r'^[.*+-]+|[.*+-]+$'), ''))
      .where((w) => w.length > 1 && !_noise.contains(w))
      .take(3)
      .toList();
  final key = words.join(' ');
  final name = words.isEmpty
      ? 'Stała płatność'
      : words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  return (key: key, name: name, kind: PaymentKind.bill);
}

/// Szuka w wydatkach płatności, które powtarzają się co miesiąc, kwartał lub rok.
List<RecurringCandidate> findRecurringPayments(List<BankTransaction> transactions, {DateTime? today}) {
  final now = dateOnly(today ?? DateTime.now());
  final groups = <String, List<BankTransaction>>{};
  final info = <String, ({String key, String name, PaymentKind kind})>{};
  for (final t in transactions) {
    if (t.amountCents >= 0) continue;
    final m = _merchant(t.description);
    if (m.key.isEmpty) continue;
    groups.putIfAbsent(m.key, () => []).add(t);
    info[m.key] = m;
  }

  final result = <RecurringCandidate>[];
  groups.forEach((key, list) {
    list.sort((a, b) => a.date.compareTo(b.date));
    final months = list.map((t) => t.date.year * 12 + t.date.month).toSet();
    if (months.length < 2) return;

    final gaps = <int>[];
    for (var i = 1; i < list.length; i++) {
      final g = list[i].date.difference(list[i - 1].date).inDays;
      if (g > 3) gaps.add(g);
    }
    if (gaps.isEmpty) return;
    gaps.sort();
    final median = gaps[gaps.length ~/ 2];
    final Repeat repeat;
    if (median >= 25 && median <= 35) {
      repeat = Repeat.monthly;
    } else if (median >= 80 && median <= 100) {
      repeat = Repeat.quarterly;
    } else if (median >= 340 && median <= 390) {
      repeat = Repeat.yearly;
    } else {
      return;
    }

    final amounts = list.map((t) => -t.amountCents).toList();
    final min = amounts.reduce((a, b) => a < b ? a : b);
    final max = amounts.reduce((a, b) => a > b ? a : b);
    final m = info[key]!;
    final isKnown = key.startsWith('k:');
    // Nieznany odbiorca z bardzo różnymi kwotami to raczej zwykłe zakupy (np. sklep).
    if (!isKnown && max > min * 1.25) return;
    // Ostatnie kwoty mówią najwięcej o bieżącej cenie.
    final recent = amounts.reversed.take(3).toList();
    final amount = (recent.reduce((a, b) => a + b) / recent.length).round();

    final last = list.last.date;
    var next = addMonths(last, repeat.months, last.day);
    var step = 1;
    while (next.isBefore(now)) {
      step++;
      next = addMonths(last, repeat.months * step, last.day);
    }
    result.add(RecurringCandidate(
      name: m.name,
      kind: m.kind,
      amountCents: amount,
      repeat: repeat,
      nextDue: next,
      occurrences: list.length,
      lastDate: last,
    ));
  });
  result.sort((a, b) => a.nextDue.compareTo(b.nextDue));
  return result;
}

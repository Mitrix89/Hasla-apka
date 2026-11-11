const _months = [
  'stycznia', 'lutego', 'marca', 'kwietnia', 'maja', 'czerwca',
  'lipca', 'sierpnia', 'września', 'października', 'listopada', 'grudnia',
];
const _monthsShort = ['sty', 'lut', 'mar', 'kwi', 'maj', 'cze', 'lip', 'sie', 'wrz', 'paź', 'lis', 'gru'];
const monthNames = [
  'Styczeń', 'Luty', 'Marzec', 'Kwiecień', 'Maj', 'Czerwiec',
  'Lipiec', 'Sierpień', 'Wrzesień', 'Październik', 'Listopad', 'Grudzień',
];

/// 1234.5 zł -> "1 234,50 zł"
String formatMoney(num cents, {bool withCurrency = true}) {
  final negative = cents < 0;
  final abs = cents.abs().round();
  final zl = abs ~/ 100;
  final gr = (abs % 100).toString().padLeft(2, '0');
  final digits = zl.toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(' ');
    grouped.write(digits[i]);
  }
  return '${negative ? '-' : ''}$grouped,$gr${withCurrency ? ' zł' : ''}';
}

/// "49,99" / "1 234.5" / "49" -> grosze. Zwraca null, gdy tekst nie jest kwotą.
int? parseMoney(String input) {
  var s = input.trim().replaceAll(RegExp(r'[\s ]'), '').replaceAll(RegExp(r'(zł|PLN|zl)$', caseSensitive: false), '');
  if (s.isEmpty) return null;
  s = s.replaceAll('−', '-');
  // "1.234,56" -> "1234,56"; "1,234.56" -> "1234.56"
  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  if (lastComma != -1 && lastDot != -1) {
    if (lastComma > lastDot) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else {
    s = s.replaceAll(',', '.');
  }
  if (!RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(s)) return null;
  final v = double.parse(s);
  return (v * 100).round();
}

/// "9 grudnia 2026" (rok pomijany, gdy bieżący i [withYear] = false)
String formatDate(DateTime d, {DateTime? today, bool withYear = false}) {
  final t = today ?? DateTime.now();
  final y = (withYear || d.year != t.year) ? ' ${d.year}' : '';
  return '${d.day} ${_months[d.month - 1]}$y';
}

String formatDateShort(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]}';

/// "dziś", "jutro", "za 5 dni", "3 dni temu"
String formatDaysUntil(int days) {
  if (days == 0) return 'dziś';
  if (days == 1) return 'jutro';
  if (days == -1) return 'wczoraj';
  if (days < 0) return '${-days} dni temu';
  return 'za $days dni';
}

/// Rodzaj pozycji w części „Opłaty”.
enum PaymentKind {
  subscription('Subskrypcja'),
  bill('Rachunek'),
  reminder('Przypomnienie');

  const PaymentKind(this.label);
  final String label;
}

/// Jak często powtarza się płatność.
enum Repeat {
  monthly('co miesiąc', 1),
  quarterly('co kwartał', 3),
  yearly('co rok', 12),
  once('jednorazowo', 0);

  const Repeat(this.label, this.months);
  final String label;

  /// Odstęp w miesiącach (0 = jednorazowo).
  final int months;
}

/// Subskrypcja, rachunek albo przypomnienie o terminie (np. przegląd auta).
class Payment {
  Payment({
    required this.id,
    required this.name,
    required this.kind,
    required this.dueDate,
    this.amountCents,
    this.repeat = Repeat.monthly,
    this.remindDaysBefore = 3,
    this.note = '',
    int? dayOfMonth,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : dayOfMonth = dayOfMonth ?? dueDate.day,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  final String id;
  final String name;
  final PaymentKind kind;

  /// Najbliższy termin (sama data, bez godziny).
  final DateTime dueDate;

  /// Kwota w groszach; null, gdy nieznana (np. przegląd auta).
  final int? amountCents;
  final Repeat repeat;

  /// Ile dni przed terminem przypomnieć (0 = bez przypomnienia).
  final int remindDaysBefore;
  final String note;

  /// Dzień miesiąca, w którym przypada płatność. Pamiętany osobno, żeby płatność
  /// z 31. dnia wracała na 31. po krótszym miesiącu (31 sty → 28 lut → 31 mar).
  final int dayOfMonth;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasReminder => remindDaysBefore > 0;

  /// Kwota przeliczona na jeden miesiąc (dla płatności co miesiąc i co kwartał).
  /// Płatności roczne i jednorazowe nie wchodzą do sumy miesięcznej.
  double? get monthlyCents {
    final a = amountCents;
    if (a == null) return null;
    return switch (repeat) {
      Repeat.monthly => a.toDouble(),
      Repeat.quarterly => a / 3,
      Repeat.yearly || Repeat.once => null,
    };
  }

  /// Dzień, w którym pokazać przypomnienie.
  DateTime? get reminderDate =>
      hasReminder ? dateOnly(dueDate).subtract(Duration(days: remindDaysBefore)) : null;

  int daysUntil(DateTime today) => dateOnly(dueDate).difference(dateOnly(today)).inDays;

  /// Następny termin po obecnym (null dla jednorazowych).
  DateTime? nextDueDate() {
    if (repeat == Repeat.once) return null;
    return addMonths(dueDate, repeat.months, dayOfMonth);
  }

  /// Kolejne terminy, zaczynając od obecnego.
  Iterable<DateTime> occurrences() sync* {
    var d = dateOnly(dueDate);
    yield d;
    if (repeat == Repeat.once) return;
    var step = 1;
    while (true) {
      yield addMonths(dueDate, repeat.months * step, dayOfMonth);
      step++;
    }
  }

  /// Termin przesunięty tak, żeby nie był w przeszłości (dla powtarzających się płatności).
  Payment rolledForward(DateTime today) {
    if (repeat == Repeat.once) return this;
    final t = dateOnly(today);
    var d = dateOnly(dueDate);
    var step = 0;
    while (d.isBefore(t)) {
      step++;
      d = addMonths(dueDate, repeat.months * step, dayOfMonth);
    }
    return step == 0 ? this : copyWith(dueDate: d, keepUpdatedAt: true);
  }

  Payment copyWith({
    String? name,
    PaymentKind? kind,
    DateTime? dueDate,
    int? amountCents,
    bool clearAmount = false,
    Repeat? repeat,
    int? remindDaysBefore,
    String? note,
    int? dayOfMonth,
    bool keepUpdatedAt = false,
  }) {
    return Payment(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      dueDate: dateOnly(dueDate ?? this.dueDate),
      amountCents: clearAmount ? null : (amountCents ?? this.amountCents),
      repeat: repeat ?? this.repeat,
      remindDaysBefore: remindDaysBefore ?? this.remindDaysBefore,
      note: note ?? this.note,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      createdAt: createdAt,
      updatedAt: keepUpdatedAt ? updatedAt : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'dueDate': _ymd(dueDate),
        'dayOfMonth': dayOfMonth,
        'amountCents': amountCents,
        'repeat': repeat.name,
        'remindDaysBefore': remindDaysBefore,
        'note': note,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      kind: PaymentKind.values.asNameMap()[json['kind']] ?? PaymentKind.bill,
      dueDate: DateTime.parse(json['dueDate'] as String),
      dayOfMonth: json['dayOfMonth'] as int?,
      amountCents: json['amountCents'] as int?,
      repeat: Repeat.values.asNameMap()[json['repeat']] ?? Repeat.monthly,
      remindDaysBefore: json['remindDaysBefore'] as int? ?? 0,
      note: json['note'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toLocal(),
    );
  }
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Dodaje miesiące, przycinając dzień do długości miesiąca (31 sty + 1 = 28/29 lut).
DateTime addMonths(DateTime from, int months, [int? preferredDay]) {
  final total = from.year * 12 + (from.month - 1) + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = (preferredDay ?? from.day).clamp(1, lastDay);
  return DateTime(year, month, day);
}

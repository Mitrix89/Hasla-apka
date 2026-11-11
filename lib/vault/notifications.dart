import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/payment.dart';
import '../util/format.dart';
import '../util/reminders.dart';

/// Powiadomienia systemowe o zbliżających się terminach (Android).
///
/// Na Windowsie aplikacja nie ma tożsamości pakietu MSIX, więc system nie pozwala
/// odwołać zaplanowanych powiadomień. Tam przypomnienia widać w aplikacji (ekran startowy).
class PaymentNotifications {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Godzina, o której pokazuje się przypomnienie.
  static const hour = 9;
  static const _maxScheduled = 60;

  bool get supported => Platform.isAndroid;

  Future<void> init() async {
    if (!supported || _ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Planuje od nowa wszystkie przypomnienia. Wywoływane po każdej zmianie opłat.
  Future<void> reschedule(List<Payment> payments) async {
    if (!supported) return;
    await init();
    await _plugin.cancelAll();
    final now = DateTime.now();
    final planned = plannedNotifications(payments, now).take(_maxScheduled);
    var id = 1;
    for (final n in planned) {
      final at = DateTime(n.notifyOn.year, n.notifyOn.month, n.notifyOn.day, hour);
      if (!at.isAfter(now)) continue;
      final p = n.payment;
      final days = n.due.difference(dateOnly(n.notifyOn)).inDays;
      final amount = p.amountCents == null ? '' : ' · ${formatMoney(p.amountCents!)}';
      await _plugin.zonedSchedule(
        id: id++,
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        title: '${p.name}: ${formatDaysUntil(days)}',
        body: '${formatDate(n.due, withYear: true)}$amount',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'terminy',
            'Terminy płatności',
            channelDescription: 'Przypomnienia o opłatach i ważnych terminach',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}

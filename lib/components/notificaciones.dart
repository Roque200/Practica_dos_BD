import 'package:alacena/components/fechas.dart';
import 'package:alacena/components/global_values.dart';
import 'package:alacena/database/alacena_db.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class Notificaciones {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const NotificationDetails _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'caducidades',
      'Caducidades',
      channelDescription: 'Avisos de productos que caducan',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> inicializar() async {
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _alTocarNotificacion,
    );
  }

  static void _alTocarNotificacion(NotificationResponse respuesta) {
    _abrirCaducanHoy(respuesta.payload);
  }

  static void _abrirCaducanHoy(String? fecha) {
    GlobalValues.navigatorKey.currentState
        ?.pushNamed('/caducan', arguments: fecha ?? Fechas.hoyDb());
  }

  /// Pide permiso (Android 13+) y si la app se abrió desde una
  /// notificación, muestra la pantalla de productos que caducan ese día.
  static Future<void> revisarLanzamiento() async {
    await _android?.requestNotificationsPermission();
    final detalles = await _plugin.getNotificationAppLaunchDetails();
    if (detalles != null && detalles.didNotificationLaunchApp) {
      _abrirCaducanHoy(detalles.notificationResponse?.payload);
    }
  }

  /// Vuelve a programar todas las alarmas según los lotes guardados.
  /// Se llama al abrir la app y cada vez que cambian productos, lotes o compras.
  static Future<void> reprogramar() async {
    try {
      bool exacta = true;
      final android = _android;
      if (android != null) {
        exacta = await android.canScheduleExactNotifications() ?? false;
      }
      final modo = exacta
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _plugin.cancelAllPendingNotifications();

      final alarmas = await AlacenaDB().alarmasPendientes(Fechas.hoyDb());
      final ahora = DateTime.now();

      for (final alarma in alarmas) {
        final String fechaTexto = alarma['fecha'] as String;
        final fecha = Fechas.deDb(fechaTexto);
        final partes = (alarma['hora'] as String).split(':');
        final momento = DateTime(
          fecha.year,
          fecha.month,
          fecha.day,
          int.parse(partes[0]),
          int.parse(partes[1]),
        );
        if (!momento.isAfter(ahora)) continue;

        final int total = alarma['total'] as int;
        final String nombres =
            ((alarma['nombres'] as String?) ?? '').replaceAll(',', ', ');
        final int id = Fechas.diasDesdeEpoch(fecha) * 1440 +
            momento.hour * 60 +
            momento.minute;

        await _plugin.zonedSchedule(
          id: id,
          title: total == 1
              ? 'Hoy caduca 1 producto'
              : 'Hoy caducan $total productos',
          body: nombres,
          scheduledDate: tz.TZDateTime.from(momento, tz.UTC),
          notificationDetails: _detalles,
          androidScheduleMode: modo,
          payload: fechaTexto,
        );
      }
    } catch (e) {
      debugPrint('No se pudieron programar las alarmas: $e');
    }
  }
}

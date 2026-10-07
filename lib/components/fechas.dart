import 'package:intl/intl.dart';

class Fechas {
  static final DateFormat _formatoDB = DateFormat('yyyy-MM-dd');
  static final DateFormat _formatoLegible = DateFormat('d MMM yyyy', 'es_MX');
  static final DateFormat _formatoLargo =
      DateFormat("EEEE d 'de' MMMM", 'es_MX');

  static String aDb(DateTime fecha) => _formatoDB.format(fecha);

  static DateTime deDb(String fecha) => DateTime.parse(fecha);

  static String hoyDb() => aDb(DateTime.now());

  static DateTime hoy() {
    final ahora = DateTime.now();
    return DateTime(ahora.year, ahora.month, ahora.day);
  }

  static String legible(String? fecha) {
    if (fecha == null) return 'Sin fecha';
    return _formatoLegible.format(deDb(fecha));
  }

  static String largo(String fecha) => _formatoLargo.format(deDb(fecha));

  /// Días que faltan para la fecha (negativo si ya pasó)
  static int diasRestantes(String fecha) {
    final f = deDb(fecha);
    final h = DateTime.now();
    final a = DateTime.utc(f.year, f.month, f.day);
    final b = DateTime.utc(h.year, h.month, h.day);
    return a.difference(b).inDays;
  }

  static int diasDesdeEpoch(DateTime fecha) {
    return DateTime.utc(fecha.year, fecha.month, fecha.day)
            .millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
  }

  static String textoDias(int dias) {
    if (dias < -1) return 'Caducó hace ${-dias} días';
    if (dias == -1) return 'Caducó ayer';
    if (dias == 0) return 'Caduca hoy';
    if (dias == 1) return 'Caduca mañana';
    return 'Caduca en $dias días';
  }
}

import 'package:sqflite/sqflite.dart';

/// Traduce los errores de SQLite a mensajes entendibles para el usuario.
/// [entidad] va con artículo: 'una categoría', 'una tienda'.
String mensajeErrorBD(Object error, {required String entidad}) {
  if (error is DatabaseException) {
    if (error.isUniqueConstraintError()) {
      return 'Ya existe $entidad con ese nombre.';
    }
    final texto = error.toString();
    if (texto.contains('FOREIGN KEY')) {
      return 'No se puede completar: hay registros que dependen de este.';
    }
    if (texto.contains('CHECK')) {
      return 'Revisa las longitudes: el nombre admite hasta 40 caracteres.';
    }
  }
  return 'Ocurrió un error inesperado. Intenta de nuevo.';
}
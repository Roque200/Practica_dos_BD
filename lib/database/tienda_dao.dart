class TiendaDAO {
  int? idTienda;
  String nombre;
  String? direccion;
  int totalCompras;

  TiendaDAO({
    this.idTienda,
    required this.nombre,
    this.direccion,
    this.totalCompras = 0,
  });

  factory TiendaDAO.fromMap(Map<String, dynamic> map) {
    return TiendaDAO(
      idTienda: map['id_tienda'] as int?,
      nombre: map['nombre'] as String,
      direccion: map['direccion'] as String?,
      totalCompras: (map['total_compras'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id_tienda': idTienda,
      'nombre': nombre.trim(),
      'direccion': (direccion == null || direccion!.trim().isEmpty)
          ? null
          : direccion!.trim(),
    };
  }
}

class CategoriaDAO {
  int? idCategoria;
  String nombre;
  String? descripcion;
  int totalProductos;

  CategoriaDAO({
    this.idCategoria,
    required this.nombre,
    this.descripcion,
    this.totalProductos = 0,
  });

  factory CategoriaDAO.fromMap(Map<String, dynamic> map) {
    return CategoriaDAO(
      idCategoria: map['id_categoria'] as int?,
      nombre: map['nombre'] as String,
      descripcion: map['descripcion'] as String?,
      totalProductos: (map['total_productos'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id_categoria': idCategoria,
      'nombre': nombre.trim(),
      'descripcion': (descripcion == null || descripcion!.trim().isEmpty)
          ? null
          : descripcion!.trim(),
    };
  }
}

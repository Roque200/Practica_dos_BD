import 'package:alacena/components/db_errores.dart';
import 'package:alacena/components/dialogos_catalogo.dart';
import 'package:alacena/database/alacena_db.dart';
import 'package:alacena/database/categoria_dao.dart';
import 'package:flutter/material.dart';

class CategoriasPage extends StatefulWidget {
  const CategoriasPage({super.key});

  @override
  State<CategoriasPage> createState() => _CategoriasPageState();
}

class _CategoriasPageState extends State<CategoriasPage> {
  final _db = AlacenaDB();
  late Future<List<CategoriaDAO>> _futuro = _db.categorias();

  void _recargar() => setState(() => _futuro = _db.categorias());

  String _error(Object e) => mensajeErrorBD(e, entidad: 'una categoría');

  // CREATE y UPDATE comparten formulario
  Future<void> _abrirFormulario([CategoriaDAO? existente]) async {
    final guardado = await mostrarFormularioCatalogo(
      context: context,
      titulo: existente == null ? 'Nueva categoría' : 'Editar categoría',
      etiquetaDetalle: 'Descripción (opcional)',
      nombreInicial: existente?.nombre ?? '',
      detalleInicial: existente?.descripcion ?? '',
      mensajeError: _error,
      guardar: (nombre, descripcion) async {
        final cat = CategoriaDAO(
          idCategoria: existente?.idCategoria,
          nombre: nombre,
          descripcion: descripcion,
        );
        if (existente == null) {
          await _db.insertar('categoria', cat.toMap());
        } else {
          await _db.actualizar('categoria', cat.toMap(), 'id_categoria');
        }
      },
    );
    if (guardado) _recargar();
  }

  // DELETE: primero se revisa la dependencia para dar un mensaje claro;
  // la FK con ON DELETE RESTRICT sigue siendo la garantía final.
  Future<void> _eliminar(CategoriaDAO cat) async {
    final productos = await _db.contarProductosCategoria(cat.idCategoria!);
    if (!mounted) return;
    if (productos > 0) {
      await avisarBloqueo(
        context,
        titulo: 'No se puede eliminar',
        mensaje: '"${cat.nombre}" tiene $productos '
            '${productos == 1 ? 'producto' : 'productos'}. '
            'Mueve esos productos a otra categoría y vuelve a intentarlo.',
      );
      return;
    }
    final acepta = await confirmarEliminar(
      context,
      titulo: 'Eliminar categoría',
      mensaje: '¿Eliminar "${cat.nombre}"?',
    );
    if (!acepta) return;
    try {
      await _db.eliminar('categoria', 'id_categoria', cat.idCategoria!);
      _recargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_error(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva categoría'),
      ),
      body: FutureBuilder<List<CategoriaDAO>>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(_error(snap.error!)));
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(
                child: Text('Aún no hay categorías. Agrega la primera.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = items[i];
              final n = c.totalProductos;
              return ListTile(
                title: Text(c.nombre),
                subtitle: Text([
                  if (c.descripcion != null) c.descripcion!,
                  '$n ${n == 1 ? 'producto' : 'productos'}',
                ].join('\n')),
                isThreeLine: c.descripcion != null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _abrirFormulario(c),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _eliminar(c),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
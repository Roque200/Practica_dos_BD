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

  void _recargar() {
    if (!mounted) return;
    setState(() => _futuro = _db.categorias());
  }

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
    if (!mounted) return;
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva categoría'),
      ),
      body: FutureBuilder<List<CategoriaDAO>>(
        future: _futuro,
        builder: (context, snap) {
          return CustomScrollView(
            slivers: [
              const SliverAppBar(
                pinned: true,
                title: Text('Categorías'),
              ),
              ..._contenido(snap),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _contenido(AsyncSnapshot<List<CategoriaDAO>> snap) {
    if (snap.hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text(_error(snap.error!))),
        ),
      ];
    }
    if (!snap.hasData) {
      return const [
        SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    final items = snap.data!;
    if (items.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text('Aún no hay categorías. Agrega la primera.'),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.only(bottom: 88),
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) => _item(items[i]),
        ),
      ),
    ];
  }

  Widget _item(CategoriaDAO c) {
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
  }
}

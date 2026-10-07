import 'dart:io';

import 'package:alacena/components/imagen_producto.dart';
import 'package:alacena/components/notificaciones.dart';
import 'package:alacena/database/alacena_db.dart';
import 'package:alacena/database/categoria_dao.dart';
import 'package:alacena/database/producto_dao.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AddProductoScreen extends StatefulWidget {
  const AddProductoScreen({super.key});

  @override
  State<AddProductoScreen> createState() => _AddProductoScreenState();
}

class _AddProductoScreenState extends State<AddProductoScreen> {
  static const List<String> _unidades = [
    'pza',
    'kg',
    'g',
    'l',
    'ml',
    'paq',
    'lata',
    'caja',
  ];

  final AlacenaDB _db = AlacenaDB();
  final _formKey = GlobalKey<FormState>();
  final _conNombre = TextEditingController();
  final _conDescripcion = TextEditingController();
  final _conStockMinimo = TextEditingController(text: '1');
  final _conDiasAviso = TextEditingController(text: '3');

  ProductoDAO? _original;
  List<CategoriaDAO> _categorias = [];
  bool _cargando = true;
  bool _inicializado = false;
  bool _guardando = false;

  int? _idCategoria;
  String _unidad = 'pza';
  bool _alarmaActiva = true;
  TimeOfDay _horaAlarma = const TimeOfDay(hour: 9, minute: 0);
  String? _imagen;
  String? _errorCategoria;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inicializado) return;
    _inicializado = true;

    final argumento = ModalRoute.of(context)!.settings.arguments;
    if (argumento is ProductoDAO) {
      _original = argumento;
      _conNombre.text = argumento.nombre;
      _conDescripcion.text = argumento.descripcion ?? '';
      _conStockMinimo.text = '${argumento.stockMinimo}';
      _conDiasAviso.text = '${argumento.diasAviso}';
      _idCategoria = argumento.idCategoria;
      _unidad = argumento.unidad;
      _alarmaActiva = argumento.alarmaActiva;
      final partes = argumento.horaAlarma.split(':');
      _horaAlarma = TimeOfDay(
        hour: int.parse(partes[0]),
        minute: int.parse(partes[1]),
      );
      _imagen = argumento.imagen;
    }
    _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
    final lista = await _db.categorias();
    if (!mounted) return;
    setState(() {
      _categorias = lista;
      _cargando = false;
    });
  }

  @override
  void dispose() {
    _conNombre.dispose();
    _conDescripcion.dispose();
    _conStockMinimo.dispose();
    _conDiasAviso.dispose();
    super.dispose();
  }

  String get _horaTexto =>
      '${_horaAlarma.hour.toString().padLeft(2, '0')}:'
      '${_horaAlarma.minute.toString().padLeft(2, '0')}';

  Future<void> _elegirImagen(ImageSource fuente) async {
    final XFile? archivo = await ImagePicker().pickImage(
      source: fuente,
      maxWidth: 900,
      imageQuality: 80,
    );
    if (archivo == null) return;

    // Se copia a la carpeta de la app para que no se pierda si se limpia la caché
    final carpeta = await getApplicationDocumentsDirectory();
    final destino = p.join(
      carpeta.path,
      'producto_${DateTime.now().millisecondsSinceEpoch}${p.extension(archivo.path)}',
    );
    await File(archivo.path).copy(destino);
    if (!mounted) return;
    setState(() => _imagen = destino);
  }

  void _opcionesImagen() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _elegirImagen(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(context);
                _elegirImagen(ImageSource.gallery);
              },
            ),
            if (_imagen != null)
              ListTile(
                leading: const Icon(Icons.hide_image),
                title: const Text('Quitar imagen'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _imagen = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _elegirHora() async {
    final hora = await showTimePicker(context: context, initialTime: _horaAlarma);
    if (hora != null && mounted) setState(() => _horaAlarma = hora);
  }

  Future<void> _guardar() async {
    final formularioOk = _formKey.currentState!.validate();
    setState(() {
      _errorCategoria = _idCategoria == null ? 'Selecciona una categoría' : null;
    });
    if (!formularioOk || _idCategoria == null) return;

    setState(() => _guardando = true);

    final producto = ProductoDAO(
      idProducto: _original?.idProducto,
      nombre: _conNombre.text,
      descripcion: _conDescripcion.text,
      unidad: _unidad,
      stockMinimo: int.parse(_conStockMinimo.text),
      diasAviso: int.parse(_conDiasAviso.text),
      alarmaActiva: _alarmaActiva,
      horaAlarma: _horaTexto,
      imagen: _imagen,
      idCategoria: _idCategoria!,
    );

    try {
      if (_original == null) {
        await _db.insertar('producto', producto.toMap());
      } else {
        await _db.actualizar('producto', producto.toMap(), 'id_producto');
        // Si cambió la imagen se borra la anterior
        final anterior = _original!.imagen;
        if (anterior != null && anterior != _imagen) {
          final archivo = File(anterior);
          if (await archivo.exists()) await archivo.delete();
        }
      }
      await Notificaciones.reprogramar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto guardado correctamente'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, true);
    } on DatabaseException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    }
  }

  InputDecoration _decoracion(String etiqueta, IconData icono,
      {String? sufijo}) {
    return InputDecoration(
      labelText: etiqueta,
      prefixIcon: Icon(icono),
      suffixText: sufijo,
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_original == null ? 'Nuevo producto' : 'Editar producto'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _opcionesImagen,
                      child: Stack(
                        children: [
                          ImagenProducto(ruta: _imagen, size: 130, radio: 20),
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: CircleAvatar(
                              radius: 18,
                              child: Icon(
                                _imagen == null ? Icons.add_a_photo : Icons.edit,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_categorias.isEmpty)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('No hay categorías registradas'),
                        trailing: TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/categorias')
                                .then((_) => _cargarCategorias());
                          },
                          child: const Text('Crear'),
                        ),
                      ),
                    )
                  else
                    DropdownMenu<int>(
                      initialSelection: _idCategoria,
                      expandedInsets: EdgeInsets.zero,
                      label: const Text('Categoría'),
                      leadingIcon: const Icon(Icons.category),
                      errorText: _errorCategoria,
                      dropdownMenuEntries: _categorias
                          .map((c) => DropdownMenuEntry<int>(
                                value: c.idCategoria!,
                                label: c.nombre,
                              ))
                          .toList(),
                      onSelected: (valor) {
                        setState(() {
                          _idCategoria = valor;
                          _errorCategoria = null;
                        });
                      },
                    ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _conNombre,
                    maxLength: 50,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _decoracion('Nombre', Icons.label),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'El nombre es obligatorio'
                        : null,
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _conDescripcion,
                    maxLength: 200,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _decoracion('Descripción (opcional)', Icons.notes),
                  ),
                  const SizedBox(height: 6),
                  DropdownMenu<String>(
                    initialSelection: _unidad,
                    expandedInsets: EdgeInsets.zero,
                    label: const Text('Unidad de medida'),
                    leadingIcon: const Icon(Icons.straighten),
                    dropdownMenuEntries: _unidades
                        .map((u) => DropdownMenuEntry<String>(value: u, label: u))
                        .toList(),
                    onSelected: (valor) {
                      if (valor != null) setState(() => _unidad = valor);
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _conStockMinimo,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: _decoracion('Stock mínimo', Icons.inventory,
                              sufijo: _unidad),
                          validator: (v) => (v == null || int.tryParse(v) == null)
                              ? 'Requerido'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _conDiasAviso,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: _decoracion('Avisar antes', Icons.timer,
                              sufijo: 'días'),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null) return 'Requerido';
                            if (n > 60) return 'Máximo 60';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: const Icon(Icons.alarm),
                          title: const Text('Alarma de caducidad'),
                          subtitle: const Text(
                              'Te avisa el día que caduque algún lote'),
                          value: _alarmaActiva,
                          onChanged: (v) => setState(() => _alarmaActiva = v),
                        ),
                        ListTile(
                          enabled: _alarmaActiva,
                          leading: const Icon(Icons.schedule),
                          title: const Text('Hora de la alarma'),
                          trailing: Text(
                            _horaTexto,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          onTap: _elegirHora,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    icon: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Guardar producto'),
                    onPressed: _guardando || _categorias.isEmpty ? null : _guardar,
                  ),
                ],
              ),
            ),
    );
  }
}

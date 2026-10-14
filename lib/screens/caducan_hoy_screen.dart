import 'package:alacena/components/fechas.dart';
import 'package:alacena/components/lista_dia.dart';
import 'package:flutter/material.dart';

/// Pantalla que abre la alarma local: productos que caducan en la fecha
/// recibida como argumento (yyyy-MM-dd). Si no llega fecha, usa hoy.
///
/// Reutiliza AlertaDia y DiaAlertasScreen del calendario, así se ve igual
/// que el modal de un día.
class CaducanHoyScreen extends StatefulWidget {
  const CaducanHoyScreen({super.key});

  @override
  State<CaducanHoyScreen> createState() => _CaducanHoyScreenState();
}

class _CaducanHoyScreenState extends State<CaducanHoyScreen> {
  DateTime? _dia;
  Future<List<AlertaDia>>? _futuro;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dia != null) return;

    final argumento = ModalRoute.of(context)?.settings.arguments;
    final texto = argumento is String ? argumento : Fechas.hoyDb();
    final f = Fechas.deDb(texto);
    // Mismo formato que usa el calendario: UTC a medianoche
    _dia = DateTime.utc(f.year, f.month, f.day);
    _futuro = _cargar();
  }

  /// Solo las alertas de caducidad cuyo lote vence ese día.
  Future<List<AlertaDia>> _cargar() async {
    final todas = await AlertaDia.cargarTodas();
    return todas
        .where((a) =>
            (a.tipo == TipoAlerta.caducado ||
                a.tipo == TipoAlerta.porCaducar) &&
            a.fecha == _dia)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AlertaDia>>(
      future: _futuro,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Caducan hoy')),
            body: Center(
              child: Text('No se pudieron cargar: ${snapshot.error}'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Caducan hoy')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return DiaAlertasScreen(dia: _dia!, alertas: snapshot.data!);
      },
    );
  }
}

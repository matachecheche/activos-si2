import 'package:flutter/material.dart';
import '../models/ficha.dart';
import '../screens/estado_util.dart';
import 'comunes.dart';

/// Tabla de depreciacion por periodo (linea recta). Se desplaza horizontalmente en pantallas angostas.
class TablaDepreciacion extends StatelessWidget {
  final List<FilaDepreciacion> filas;

  const TablaDepreciacion(this.filas, {super.key});

  @override
  Widget build(BuildContext context) {
    if (filas.isEmpty) return const MensajeVacio('Todavía no hay periodos calculados.');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 22,
        headingRowHeight: 40,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 38,
        columns: const [
          DataColumn(label: Text('Periodo')),
          DataColumn(label: Text('Dep. del periodo'), numeric: true),
          DataColumn(label: Text('Dep. acumulada'), numeric: true),
          DataColumn(label: Text('Valor en libros'), numeric: true),
        ],
        rows: [
          for (final f in filas)
            DataRow(
              cells: [
                DataCell(Text(f.periodo, style: estiloMono)),
                DataCell(Text(formatoMonto(f.depreciacionPeriodo))),
                DataCell(Text(formatoMonto(f.depreciacionAcumulada))),
                DataCell(Text(formatoMonto(f.valorEnLibros))),
              ],
            ),
        ],
      ),
    );
  }
}

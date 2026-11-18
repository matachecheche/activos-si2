import 'package:flutter/material.dart';
import '../screens/estado_util.dart';

// Componentes visuales compartidos por todas las pantallas (equivalen a los estilos globales de la web).

const Color colorTexto = Color(0xFF172033);
const Color colorBorde = Color(0xFFE5EAF1);
const TextStyle estiloMuted = TextStyle(fontSize: 12.5, color: Color(0xFF6B7280));
const TextStyle estiloMono = TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700);

InputDecoration decoracion(String etiqueta, {String? ayuda, String? sugerencia}) {
  return InputDecoration(
    labelText: etiqueta,
    helperText: ayuda,
    helperMaxLines: 3,
    hintText: sugerencia,
    border: const OutlineInputBorder(),
    isDense: true,
  );
}

AppBar barra(String titulo, {List<Widget>? acciones, PreferredSizeWidget? abajo}) {
  return AppBar(
    title: Text(titulo),
    actions: acciones,
    bottom: abajo,
    backgroundColor: Colors.white,
    foregroundColor: colorTexto,
    surfaceTintColor: Colors.transparent,
    elevation: 1,
  );
}

BoxDecoration decoracionTarjeta() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: colorBorde),
  );
}

/// Tarjeta blanca con borde suave (la clase .card de la web).
class Tarjeta extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margen;
  final EdgeInsetsGeometry relleno;

  const Tarjeta({
    super.key,
    required this.child,
    this.onTap,
    this.margen = const EdgeInsets.only(bottom: 10),
    this.relleno = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margen,
      decoration: decoracionTarjeta(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(padding: relleno, child: child),
        ),
      ),
    );
  }
}

/// Tarjeta con titulo y contenido.
class TarjetaSeccion extends StatelessWidget {
  final String? titulo;
  final Widget? accion;
  final List<Widget> hijos;

  const TarjetaSeccion({super.key, this.titulo, this.accion, required this.hijos});

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titulo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(titulo!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colorTexto)),
                  ),
                  ?accion,
                ],
              ),
            ),
          ...hijos,
        ],
      ),
    );
  }
}

enum TipoBanner { error, ok, aviso }

/// Mensaje de error / exito / aviso (alert-error, alert-ok, alert-warn de la web).
class BannerMensaje extends StatelessWidget {
  final String texto;
  final TipoBanner tipo;

  const BannerMensaje(this.texto, {super.key, this.tipo = TipoBanner.error});

  @override
  Widget build(BuildContext context) {
    Color fondo;
    Color borde;
    Color frente;
    IconData icono;
    switch (tipo) {
      case TipoBanner.ok:
        fondo = const Color(0xFFE7F6EC);
        borde = const Color(0xFFB7E1C4);
        frente = const Color(0xFF14653A);
        icono = Icons.check_circle_outline;
        break;
      case TipoBanner.aviso:
        fondo = const Color(0xFFFFF6E0);
        borde = const Color(0xFFF3D98B);
        frente = const Color(0xFF7A5300);
        icono = Icons.warning_amber_outlined;
        break;
      case TipoBanner.error:
        fondo = const Color(0xFFFDECEC);
        borde = const Color(0xFFF5C2C2);
        frente = const Color(0xFF9B1C1C);
        icono = Icons.error_outline;
        break;
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: fondo, border: Border.all(color: borde), borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: frente),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: TextStyle(color: frente, fontSize: 13.5))),
        ],
      ),
    );
  }
}

/// Distintivo redondeado (badge).
class Insignia extends StatelessWidget {
  final String texto;
  final Color fondo;
  final Color colorLetra;

  const Insignia({super.key, required this.texto, required this.fondo, required this.colorLetra});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(12)),
      child: Text(texto, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: colorLetra)),
    );
  }
}

/// Distintivo para un estado/tipo conocido (En uso, Aprobado, Preventivo...).
Widget insigniaDe(String? valor, {String? texto}) {
  return Insignia(
    texto: texto ?? etiqueta(valor),
    fondo: colorEstado(valor),
    colorLetra: colorTextoEstado(valor),
  );
}

enum TonoKpi { normal, bien, alerta, mal }

/// Indicador numerico con borde de color (la clase .kpi de la web).
class TarjetaKpi extends StatelessWidget {
  final String etiquetaKpi;
  final String valor;
  final TonoKpi tono;

  const TarjetaKpi({super.key, required this.etiquetaKpi, required this.valor, this.tono = TonoKpi.normal});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (tono) {
      case TonoKpi.bien:
        color = const Color(0xFF1B9A55);
        break;
      case TonoKpi.alerta:
        color = const Color(0xFFE0A100);
        break;
      case TonoKpi.mal:
        color = const Color(0xFFD64545);
        break;
      case TonoKpi.normal:
        color = const Color(0xFF1769E0);
        break;
    }
    return Container(
      decoration: decoracionTarjeta(),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(etiquetaKpi, style: estiloMuted),
                    const SizedBox(height: 4),
                    Text(valor, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: colorTexto)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Acomoda los indicadores de dos en dos.
class GrillaKpi extends StatelessWidget {
  final List<TarjetaKpi> items;

  const GrillaKpi({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, restricciones) {
          final ancho = (restricciones.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in items) SizedBox(width: ancho, child: k),
            ],
          );
        },
      ),
    );
  }
}

/// Fila "etiqueta: valor" de una ficha.
class FilaDato extends StatelessWidget {
  final String etiquetaDato;
  final String? valor;
  final Widget? widgetValor;

  const FilaDato(this.etiquetaDato, this.valor, {super.key, this.widgetValor});

  @override
  Widget build(BuildContext context) {
    final v = valor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 132, child: Text(etiquetaDato, style: estiloMuted)),
          Expanded(child: widgetValor ?? Text(v == null || v.isEmpty ? '-' : v)),
        ],
      ),
    );
  }
}

/// Barra de avance de ejecucion presupuestaria (verde, amarillo desde 80 %, rojo al llegar a 100 %).
class BarraEjecucion extends StatelessWidget {
  final double porcentaje;

  const BarraEjecucion(this.porcentaje, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = porcentaje.isNaN ? 0.0 : porcentaje;
    final avance = (p > 100 ? 100.0 : (p < 0 ? 0.0 : p)) / 100;
    final Color color = p >= 100 ? Colors.red.shade600 : (p >= 80 ? Colors.amber.shade700 : Colors.green.shade600);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: avance,
              minHeight: 8,
              backgroundColor: colorBorde,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${formatoPorcentaje(p)} %', style: estiloMuted),
      ],
    );
  }
}

class MensajeVacio extends StatelessWidget {
  final String texto;

  const MensajeVacio(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(child: Text(texto, textAlign: TextAlign.center, style: estiloMuted)),
    );
  }
}

class Cargando extends StatelessWidget {
  const Cargando({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Subtitulo gris bajo el titulo de una pantalla.
class Subtitulo extends StatelessWidget {
  final String texto;

  const Subtitulo(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(texto, style: const TextStyle(fontSize: 13.5, color: Color(0xFF6B7280))),
    );
  }
}

// ---------------- selector (lista desplegable) ----------------

class OpcionSeleccion<T> {
  final T valor;
  final String etiquetaOpcion;

  const OpcionSeleccion(this.valor, this.etiquetaOpcion);
}

class _Eleccion<T> {
  final T? valor;

  const _Eleccion(this.valor);
}

/// Campo de seleccion que abre una hoja con las opciones (con buscador si son muchas).
/// Se usa en lugar de DropdownButton porque se adapta mejor a pantallas pequenas y textos largos.
class CampoSeleccion<T> extends StatelessWidget {
  final String etiquetaCampo;
  final T? valor;
  final List<OpcionSeleccion<T>> opciones;
  final ValueChanged<T?> onChanged;
  final String textoVacio;
  final String? textoLimpiar; // si se indica, agrega una opcion para dejar el campo sin valor ("Todos", "Ninguno")
  final bool habilitado;
  final String? ayuda;

  const CampoSeleccion({
    super.key,
    required this.etiquetaCampo,
    required this.valor,
    required this.opciones,
    required this.onChanged,
    this.textoVacio = 'Seleccione...',
    this.textoLimpiar,
    this.habilitado = true,
    this.ayuda,
  });

  @override
  Widget build(BuildContext context) {
    String? elegido;
    for (final o in opciones) {
      if (o.valor == valor) {
        elegido = o.etiquetaOpcion;
        break;
      }
    }
    final String mostrado = elegido ?? ((valor == null && textoLimpiar != null) ? textoLimpiar! : textoVacio);
    final bool conValor = elegido != null || (valor == null && textoLimpiar != null);
    return InkWell(
      onTap: habilitado ? () => _abrir(context) : null,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: etiquetaCampo,
          helperText: ayuda,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
          isDense: true,
          enabled: habilitado,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          mostrado,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: conValor ? null : const Color(0xFF8490A3)),
        ),
      ),
    );
  }

  Future<void> _abrir(BuildContext context) async {
    final eleccion = await showModalBottomSheet<_Eleccion<T>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => _HojaSeleccion<T>(titulo: etiquetaCampo, opciones: opciones, valor: valor, textoLimpiar: textoLimpiar),
    );
    if (eleccion != null) onChanged(eleccion.valor);
  }
}

class _HojaSeleccion<T> extends StatefulWidget {
  final String titulo;
  final List<OpcionSeleccion<T>> opciones;
  final T? valor;
  final String? textoLimpiar;

  const _HojaSeleccion({required this.titulo, required this.opciones, required this.valor, required this.textoLimpiar});

  @override
  State<_HojaSeleccion<T>> createState() => _HojaSeleccionState<T>();
}

class _HojaSeleccionState<T> extends State<_HojaSeleccion<T>> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final f = _filtro.trim().toLowerCase();
    final visibles = widget.opciones.where((o) => f.isEmpty || o.etiquetaOpcion.toLowerCase().contains(f)).toList();
    final altoMaximo = MediaQuery.of(context).size.height * 0.7;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: altoMaximo),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(widget.titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            if (widget.opciones.length > 7)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: decoracion('Buscar'),
                  onChanged: (v) => setState(() => _filtro = v),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (widget.textoLimpiar != null)
                    ListTile(
                      title: Text(widget.textoLimpiar!),
                      trailing: widget.valor == null ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.pop(context, _Eleccion<T>(null)),
                    ),
                  for (final o in visibles)
                    ListTile(
                      title: Text(o.etiquetaOpcion),
                      trailing: o.valor == widget.valor ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.pop(context, _Eleccion<T>(o.valor)),
                    ),
                  if (visibles.isEmpty && widget.textoLimpiar == null) const MensajeVacio('Sin resultados.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- fecha ----------------

/// Campo de fecha que abre el selector del sistema y entrega el valor como yyyy-MM-dd.
class CampoFecha extends StatelessWidget {
  final String etiquetaCampo;
  final String? valor;
  final ValueChanged<String?> onChanged;
  final String? ayuda;
  final bool permitirLimpiar;

  const CampoFecha({
    super.key,
    required this.etiquetaCampo,
    required this.valor,
    required this.onChanged,
    this.ayuda,
    this.permitirLimpiar = false,
  });

  DateTime? _parsear(String? v) {
    if (v == null || v.length < 10) return null;
    return DateTime.tryParse(v.substring(0, 10));
  }

  Future<void> _elegir(BuildContext context) async {
    final minimo = DateTime(2000);
    final maximo = DateTime(2100, 12, 31);
    var inicial = _parsear(valor) ?? DateTime.now();
    if (inicial.isBefore(minimo)) inicial = minimo;
    if (inicial.isAfter(maximo)) inicial = maximo;
    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: minimo,
      lastDate: maximo,
      helpText: etiquetaCampo,
    );
    if (elegida != null) onChanged(fechaIso(elegida));
  }

  @override
  Widget build(BuildContext context) {
    final v = valor;
    final bool tiene = v != null && v.isNotEmpty;
    return InkWell(
      onTap: () => _elegir(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: etiquetaCampo,
          helperText: ayuda,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: (permitirLimpiar && tiene)
              ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () => onChanged(null))
              : const Icon(Icons.calendar_today, size: 20),
        ),
        child: Text(
          tiene ? formatoFecha(v) : 'Seleccione fecha',
          style: TextStyle(color: tiene ? null : const Color(0xFF8490A3)),
        ),
      ),
    );
  }
}

// ---------------- dialogos ----------------

Future<bool> confirmar(
  BuildContext context,
  String mensaje, {
  String titulo = 'Confirmar',
  String textoSi = 'Aceptar',
  bool peligro = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: peligro ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(textoSi),
        ),
      ],
    ),
  );
  return r == true;
}

void avisar(BuildContext context, String texto) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
}

/// Abre una hoja inferior para un formulario; sube sola cuando aparece el teclado.
Future<T?> abrirHoja<T>(BuildContext context, Widget contenido) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: contenido,
    ),
  );
}

/// Dialogo con un campo de texto. Devuelve el texto (puede ser vacio si no es obligatorio) o null si se cancela.
Future<String?> pedirTexto(
  BuildContext context, {
  required String titulo,
  required String etiquetaCampo,
  String? mensaje,
  bool obligatorio = false,
  int maxLength = 500,
  String textoConfirmar = 'Aceptar',
  String textoVolver = 'Cancelar',
  bool peligro = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _DialogoTexto(
      titulo: titulo,
      etiquetaCampo: etiquetaCampo,
      mensaje: mensaje,
      obligatorio: obligatorio,
      maxLength: maxLength,
      textoConfirmar: textoConfirmar,
      textoVolver: textoVolver,
      peligro: peligro,
    ),
  );
}

class _DialogoTexto extends StatefulWidget {
  final String titulo;
  final String etiquetaCampo;
  final String? mensaje;
  final bool obligatorio;
  final int maxLength;
  final String textoConfirmar;
  final String textoVolver;
  final bool peligro;

  const _DialogoTexto({
    required this.titulo,
    required this.etiquetaCampo,
    required this.mensaje,
    required this.obligatorio,
    required this.maxLength,
    required this.textoConfirmar,
    required this.textoVolver,
    required this.peligro,
  });

  @override
  State<_DialogoTexto> createState() => _DialogoTextoState();
}

class _DialogoTextoState extends State<_DialogoTexto> {
  final TextEditingController _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _aceptar() {
    final t = _ctrl.text.trim();
    if (widget.obligatorio && t.isEmpty) {
      setState(() => _error = 'Este campo es obligatorio.');
      return;
    }
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    final mensaje = widget.mensaje;
    return AlertDialog(
      title: Text(widget.titulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mensaje != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(mensaje)),
            TextField(
              controller: _ctrl,
              maxLength: widget.maxLength,
              minLines: 1,
              maxLines: 4,
              autofocus: true,
              decoration: decoracion(widget.etiquetaCampo),
            ),
            if (_error != null) Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12.5)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.textoVolver)),
        FilledButton(
          style: widget.peligro ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700) : null,
          onPressed: _aceptar,
          child: Text(widget.textoConfirmar),
        ),
      ],
    );
  }
}

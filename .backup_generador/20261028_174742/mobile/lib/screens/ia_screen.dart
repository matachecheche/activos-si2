import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/ia_service.dart';
import '../widgets/comunes.dart';
import 'navegacion.dart';

/// HU-14: asistente en lenguaje natural en el movil, con entrada por voz
/// (speech_to_text) y teclado como alternativa si se deniega el microfono.
/// Igual que la web: memoria de la conversacion, diagnostico de conexion y
/// respuestas conversacionales sin tabla ni SQL.
class IaScreen extends StatefulWidget {
  const IaScreen({super.key});

  @override
  State<IaScreen> createState() => _IaScreenState();
}

class _Mensaje {
  final bool esUsuario;
  final String texto;
  final String? modo;
  final List<String> columnas;
  final List<dynamic> filas;
  final String? sql;
  final List<String> diagnostico;
  final bool error;

  const _Mensaje(
    this.esUsuario,
    this.texto, {
    this.modo,
    this.columnas = const [],
    this.filas = const [],
    this.sql,
    this.diagnostico = const [],
    this.error = false,
  });
}

class _IaScreenState extends State<IaScreen> {
  final IaService _servicio = IaService();
  final SpeechToText _voz = SpeechToText();
  final TextEditingController _pregunta = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<_Mensaje> _mensajes = [];
  Map<String, dynamic> _estado = {};
  bool _enviando = false;
  bool _vozDisponible = false;
  bool _escuchando = false;
  bool _probando = false;
  String _ayudaVoz = '';

  final List<String> _ejemplos = [
    '¿Cuántos activos tiene la empresa?',
    'Lista los activos con valor mayor a 5000',
    '¿Qué mantenimientos están pendientes?',
  ];

  @override
  void initState() {
    super.initState();
    _inicializarVoz();
    _cargarEstado();
  }

  @override
  void dispose() {
    _pregunta.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargarEstado() async {
    try {
      final estado = await _servicio.estado();
      if (mounted) setState(() => _estado = estado);
    } catch (_) {
      // el banner es informativo: si falla, la pantalla sigue usable
    }
  }

  Future<void> _inicializarVoz() async {
    try {
      _vozDisponible = await _voz.initialize(
        // speech_to_text 7.x: el listener de errores se registra en
        // initialize(onError:); listen() NO admite ese parametro.
        onError: (error) {
          if (!mounted) return;
          final mensaje = _textoErrorVoz(error);
          setState(() {
            _escuchando = false;
            _ayudaVoz = mensaje.isEmpty
                ? 'No se pudo usar el micrófono. Escribe la pregunta o reintenta.'
                : 'No se pudo escuchar ($mensaje). Escribe la pregunta o reintenta.';
          });
        },
        onStatus: (estado) {
          if ((estado == 'notListening' || estado == 'done') && mounted) {
            setState(() => _escuchando = false);
          }
        },
      );
    } catch (_) {
      _vozDisponible = false; // sin microfono o permiso denegado: entrada manual
    }
    if (mounted) setState(() {});
  }

  /// Texto del error de voz. No se nombra el tipo del paquete (es interno) y
  /// se lee de forma defensiva: si el tipo cambia, se cae al ultimo error.
  String _textoErrorVoz(Object? error) {
    if (error != null) {
      try {
        final valor = (error as dynamic).errorMsg;
        if (valor != null) return valor.toString().trim();
      } catch (_) {
        // se intenta el ultimo error conocido
      }
    }
    try {
      final ultimo = _voz.lastError;
      if (ultimo != null) return ultimo.errorMsg.trim();
    } catch (_) {
      // sin detalle
    }
    return '';
  }

  /// Elige el locale de voz en español disponible en el dispositivo.
  Future<String> _localeEspanol() async {
    try {
      final locales = await _voz.locales();
      final es = locales.where((l) => l.localeId.toLowerCase().startsWith('es')).toList();
      if (es.isNotEmpty) return es.first.localeId;
    } catch (_) {
      // sin catalogo de locales: se usa el valor por defecto
    }
    return 'es_ES';
  }

  Future<void> _alternarVoz() async {
    if (_escuchando) {
      await _voz.stop();
      if (mounted) setState(() => _escuchando = false);
      return;
    }
    if (!_vozDisponible) {
      setState(() => _ayudaVoz =
          'El reconocimiento de voz no está disponible (micrófono denegado o sin servicio). Escribe tu pregunta.');
      return;
    }
    final locale = await _localeEspanol();
    if (!mounted) return;
    setState(() {
      _ayudaVoz = 'Escuchando… habla ahora.';
      _escuchando = true;
    });
    try {
      await _voz.listen(
        // speech_to_text 7.x: todas las opciones van en SpeechListenOptions.
        listenOptions: SpeechListenOptions(
          localeId: locale,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
        onResult: (resultado) {
          if (!mounted) return;
          setState(() {
            _pregunta.text = resultado.recognizedWords;
            if (resultado.finalResult) {
              _escuchando = false;
              _ayudaVoz = resultado.recognizedWords.trim().isEmpty
                  ? 'No se entendió la pregunta. Intenta de nuevo o escríbela.'
                  : '';
            }
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _escuchando = false;
        _ayudaVoz = 'El micrófono no está disponible ahora. Escribe tu pregunta.';
      });
    }
  }

  /// Ultimos turnos utiles para que el modelo recuerde el contexto.
  List<Map<String, String>> _historial() {
    final utiles = _mensajes.where((m) => !m.error && m.texto.trim().isNotEmpty).toList();
    final recorte = utiles.length > 6 ? utiles.sublist(utiles.length - 6) : utiles;
    return recorte
        .map((m) => {
              'rol': m.esUsuario ? 'usuario' : 'asistente',
              'texto': m.texto.length > 500 ? m.texto.substring(0, 500) : m.texto,
            })
        .toList();
  }

  String _etiquetaModo(String? modo, List<String> diagnostico) {
    switch (modo) {
      case 'GROQ':
        return 'Groq (IA en la nube)';
      case 'GEMINI':
        return 'Gemini (respaldo)';
      case 'GUIADO':
        return diagnostico.isEmpty ? 'Modo guiado (sin clave de IA)' : 'Modo guiado (la IA no respondió)';
      default:
        return '';
    }
  }

  Future<void> _probarConexion() async {
    if (_probando) return;
    setState(() => _probando = true);
    try {
      final resultados = await _servicio.probar();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
            const Text('Diagnóstico de conexión con las IA',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            ...resultados.map((p) {
              final m = Map<String, dynamic>.from(p as Map);
              final ok = m['ok'] == true;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(ok ? Icons.check_circle : Icons.error,
                    color: ok ? const Color(0xFF15803D) : const Color(0xFFB42318)),
                title: Text('${m['proveedor']} · ${m['modelo']}'),
                subtitle: Text('${ok ? 'OK' : 'HTTP ${m['httpStatus']}'} — ${m['detalle'] ?? ''}'),
              );
            }),
            const SizedBox(height: 6),
            const Text(
              'HTTP 401/403 = clave inválida o revocada. HTTP 0 = sin internet, firewall o proxy. '
              'La clave de Gemini debe empezar por AIza (los tokens AQ./ya29. son OAuth y no sirven).',
              style: estiloMuted,
            ),
          ]),
        ),
      );
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _probando = false);
    }
  }

  Future<void> _preguntar([String? texto]) async {
    final pregunta = (texto ?? _pregunta.text).trim();
    if (pregunta.isEmpty || _enviando) return;
    if (_escuchando) {
      await _voz.stop();
      setState(() => _escuchando = false);
    }
    final historial = _historial();
    setState(() {
      _mensajes.add(_Mensaje(true, pregunta));
      _pregunta.clear();
      _enviando = true;
      _ayudaVoz = '';
    });
    _bajarAlFinal();
    try {
      final r = await _servicio.preguntar(pregunta, historial: historial);
      if (!mounted) return;
      setState(() {
        _mensajes.add(_Mensaje(
          false,
          (r['explicacion'] ?? '').toString(),
          modo: r['modo']?.toString(),
          columnas: (r['columnas'] as List?)?.map((e) => e.toString()).toList() ?? const [],
          filas: (r['filas'] as List?) ?? const [],
          sql: r['sqlEjecutado']?.toString(),
          diagnostico: (r['diagnostico'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        ));
        _enviando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mensajes.add(_Mensaje(false, '$e', error: true));
        _enviando = false;
      });
    }
    _bajarAlFinal();
  }

  void _bajarAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _snack(String texto) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

  String? get _bannerIa {
    if (_estado.isEmpty) return null;
    final groq = _estado['groqConfigurado'] == true;
    final gemini = _estado['geminiConfigurado'] == true;
    if (!groq && !gemini) return 'Sin claves de IA: responde en modo guiado con consultas seguras.';
    final partes = <String>[
      if (groq) 'Groq: sí (${_estado['modeloGroq'] ?? 'modelo actual'})',
      if (gemini) 'Gemini: sí (${_estado['modeloGemini'] ?? 'modelo actual'})',
    ];
    final formatoInvalido = (groq && _estado['groqFormatoValido'] == false) ||
        (gemini && _estado['geminiFormatoValido'] == false);
    final aviso = formatoInvalido
        ? ' · Aviso: una clave no tiene el formato esperado (Groq gsk_ / Gemini AIza).'
        : '';
    return 'IA configurada. ${partes.join(' · ')}$aviso';
  }

  @override
  Widget build(BuildContext context) {
    final banner = _bannerIa;
    return Scaffold(
      drawer: const MenuLateral(rutaActual: '/ia'),
      appBar: barraModulo('Asistente IA', '/ia', acciones: [
        IconButton(
          tooltip: 'Probar conexión con las IA',
          icon: _probando
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.network_check),
          onPressed: _probando ? null : _probarConexion,
        ),
      ]),
      body: Column(children: [
        if (banner != null)
          Container(
            width: double.infinity,
            color: const Color(0xFFF0FDF4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(banner, style: const TextStyle(fontSize: 12.5, color: Color(0xFF166534))),
          ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(14),
            children: [
              if (_mensajes.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'Pregunta en lenguaje natural. Puedes usar la voz o el teclado. También conversa: saluda, '
                    'pregunta de qué va el proyecto o pide aclaraciones. Sin clave de IA responde en modo guiado '
                    'con consultas seguras.',
                    style: estiloMuted,
                  ),
                ),
                ..._ejemplos.map((e) => Card(
                      child: ListTile(
                        title: Text(e),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _preguntar(e),
                      ),
                    )),
              ],
              ..._mensajes.map(_burbuja),
              if (_enviando)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_ayudaVoz.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_ayudaVoz, style: estiloMuted),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          color: Colors.white,
          child: SafeArea(
            child: Row(children: [
              IconButton(
                tooltip: _vozDisponible ? 'Preguntar por voz' : 'Voz no disponible: escribe la pregunta',
                icon: Icon(_escuchando ? Icons.mic : Icons.mic_none,
                    color: _escuchando ? Colors.red : null),
                onPressed: _alternarVoz,
              ),
              Expanded(
                child: TextField(
                  controller: _pregunta,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _preguntar(),
                  decoration: decoracion('Escribe tu pregunta...'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                color: Theme.of(context).colorScheme.primary,
                onPressed: () => _preguntar(),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _burbuja(_Mensaje m) {
    final alineacion = m.esUsuario ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final etiqueta = _etiquetaModo(m.modo, m.diagnostico);
    return Column(crossAxisAlignment: alineacion, children: [
      Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: m.esUsuario
              ? Theme.of(context).colorScheme.primaryContainer
              : (m.error ? const Color(0xFFFEF2F2) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorBorde),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (etiqueta.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Chip(
                label: Text(etiqueta, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          SelectableText(m.texto),
          if (m.diagnostico.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...m.diagnostico.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $d',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8A4B08))),
                )),
          ],
          if (m.columnas.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 34,
                dataRowMinHeight: 34,
                dataRowMaxHeight: 48,
                columns: m.columnas.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                rows: m.filas.map((f) {
                  final mapa = Map<String, dynamic>.from(f as Map);
                  return DataRow(
                    cells: m.columnas
                        .map((c) => DataCell(Text('${mapa[c] ?? ''}', style: const TextStyle(fontSize: 12))))
                        .toList(),
                  );
                }).toList(),
              ),
            ),
          ],
          if (m.sql != null) ...[
            const SizedBox(height: 8),
            SelectableText(m.sql!, style: estiloMono.copyWith(fontSize: 11)),
          ],
        ]),
      ),
    ]);
  }
}

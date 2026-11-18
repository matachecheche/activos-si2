import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/comunes.dart';
import 'navegacion.dart';

/// Pantalla de inicio de la app movil: es la "casa" de la aplicacion.
///
/// En la web el menu lateral siempre esta visible, asi que desde cualquier
/// modulo se puede saltar a otro. En el movil el menu es un drawer, por eso
/// esta pantalla lista todos los modulos permitidos como tarjetas: nunca se
/// queda encerrado en una pantalla suelta y siempre se ve a donde ir.
class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final modulos = modulosPermitidos();
    return Scaffold(
      drawer: const MenuLateral(rutaActual: '/inicio'),
      appBar: barra('Activos Fijos SP3'),
      body: modulos.isEmpty
          ? const _SinModulos()
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 26),
              children: [
                _saludo(auth),
                const SizedBox(height: 16),
                const Subtitulo('Modulos disponibles: toca uno para abrirlo.'),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.15,
                  children: [for (final m in modulos) _TarjetaModulo(item: m)],
                ),
                const SizedBox(height: 18),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.menu, size: 16, color: Color(0xFF8490A3)),
                    SizedBox(width: 6),
                    Text('Tambien puedes abrir el menu con el boton de la esquina superior izquierda.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF8490A3))),
                  ],
                ),
              ],
            ),
    );
  }

  /// Tarjeta de saludo con el usuario, el rol y el nivel.
  Widget _saludo(AuthService auth) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1769E0), Color(0xFF0B47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Activos Fijos y Presupuestos',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Hola, ${auth.nombre}',
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            _chip(auth.rol),
            const SizedBox(width: 8),
            _chip(auth.nivel),
          ]),
        ],
      ),
    );
  }

  Widget _chip(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(9)),
      child: Text(texto.isEmpty ? 'REGULAR' : texto,
          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }

}

/// Tarjeta de un modulo: al tocarla abre el modulo.
class _TarjetaModulo extends StatelessWidget {
  final ItemMenu item;

  const _TarjetaModulo({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => irAModulo(context, item.ruta),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: decoracionTarjeta(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icono, color: const Color(0xFF1769E0), size: 26),
            const SizedBox(height: 8),
            Text(item.etiquetaMenu,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.2)),
            const SizedBox(height: 3),
            Expanded(
              child: Text(
                descripcionModulo(item.ruta),
                style: estiloMuted,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso cuando el rol no tiene ningun modulo asignado.
class _SinModulos extends StatelessWidget {
  const _SinModulos();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Color(0xFF8490A3)),
            const SizedBox(height: 12),
            const Text(
              'Tu rol todavia no tiene permisos para ningun modulo. Pide al administrador que los configure.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: () => cerrarSesion(context), child: const Text('Cerrar sesion')),
          ],
        ),
      ),
    );
  }
}

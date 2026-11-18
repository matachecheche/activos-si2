import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/comunes.dart';
import 'activos_screen.dart';
import 'bitacora_screen.dart';
import 'depreciacion_screen.dart';
import 'empresas_screen.dart';
import 'ia_screen.dart';
import 'inicio_screen.dart';
import 'inventario_screen.dart';
import 'login_screen.dart';
import 'mantenimientos_screen.dart';
import 'personalizacion_screen.dart';
import 'presupuestos_screen.dart';
import 'registro_empresa_screen.dart';
import 'reportes_screen.dart';
import 'respaldos_screen.dart';
import 'roles_screen.dart';
import 'suscripcion_screen.dart';
import 'usuarios_screen.dart';

/// Opcion del menu lateral (equivale a core/menu.ts de la web).
class ItemMenu {
  final String etiquetaMenu;
  final String ruta;
  final IconData icono;
  final String? permiso; // permiso MODULO_ACCION requerido
  final bool soloAdmin;
  final bool soloSuperAdmin; // HU-12: nivel SUPER_ADMIN de la plataforma

  const ItemMenu(this.etiquetaMenu, this.ruta, this.icono,
      {this.permiso, this.soloAdmin = false, this.soloSuperAdmin = false});
}

/// HU-01/HU-04/HU-11…HU-17: el menu se arma segun el nivel, el rol y los permisos.
const List<ItemMenu> menuApp = [
  // Inicio: pantalla con todas las funcionalidades (la "casa" de la app).
  ItemMenu('Inicio', '/inicio', Icons.home_outlined),
  // HU-12: solo visible para el Super Admin de la plataforma.
  ItemMenu('Administración de plataforma', '/plataforma/empresas', Icons.cloud_outlined, soloSuperAdmin: true),
  ItemMenu('Activos', '/activos', Icons.inventory_2_outlined, permiso: 'ACTIVOS_LEER'),
  ItemMenu('Mantenimientos', '/mantenimientos', Icons.build_outlined, permiso: 'MANTENIMIENTO_LEER'),
  ItemMenu('Depreciación', '/depreciacion', Icons.trending_down, permiso: 'DEPRECIACION_LEER'),
  ItemMenu('Presupuestos', '/presupuestos', Icons.account_balance_wallet_outlined, permiso: 'PRESUPUESTO_LEER'),
  // Sprint 3.
  ItemMenu('Inventario físico', '/inventario', Icons.fact_check_outlined, permiso: 'INVENTARIO_LEER'),
  ItemMenu('Reportes y BI', '/reportes', Icons.bar_chart_outlined, permiso: 'REPORTES_LEER'),
  ItemMenu('Asistente IA', '/ia', Icons.auto_awesome_outlined, permiso: 'IA_CONSULTAR'),
  ItemMenu('Usuarios', '/usuarios', Icons.people_outline, permiso: 'USUARIOS_LEER'),
  ItemMenu('Roles y permisos', '/roles', Icons.admin_panel_settings_outlined, soloAdmin: true),
  ItemMenu('Suscripción', '/suscripcion', Icons.card_membership_outlined, permiso: 'SUSCRIPCION_LEER'),
  ItemMenu('Respaldos', '/respaldos', Icons.backup_outlined, permiso: 'RESPALDO_GESTIONAR'),
  ItemMenu('Auditoría', '/auditoria', Icons.verified_outlined, permiso: 'AUDITORIA_LEER'),
  ItemMenu('Personalización', '/configuracion', Icons.palette_outlined, permiso: 'CONFIG_EMPRESA_EDITAR'),
];

List<ItemMenu> menuPermitido() {
  final auth = AuthService();
  return menuApp.where((i) {
    if (i.soloSuperAdmin) return auth.isSuperAdmin;
    if (i.soloAdmin) return auth.isAdmin;
    final permiso = i.permiso;
    return permiso == null || auth.hasPermission(permiso);
  }).toList();
}

/// Barra de un modulo: suma el boton de Inicio (la casa) para poder volver al
/// menu de funcionalidades desde cualquier pantalla. En la web el menu
/// lateral esta siempre visible; en el movil el drawer y este boton hacen el
/// mismo papel, para no quedar encerrado en una pantalla.
AppBar barraModulo(String titulo, String ruta,
    {List<Widget>? acciones, PreferredSizeWidget? abajo}) {
  return AppBar(
    title: Text(titulo),
    actions: [
      if (ruta != '/inicio')
        Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Inicio',
            icon: const Icon(Icons.home_outlined),
            onPressed: () => irAModulo(ctx, '/inicio'),
          ),
        ),
      ...?acciones,
    ],
    bottom: abajo,
    backgroundColor: Colors.white,
    foregroundColor: colorTexto,
    surfaceTintColor: Colors.transparent,
    elevation: 1,
  );
}

/// Modulos de trabajo (sin la entrada Inicio) permitidos al usuario actual.
List<ItemMenu> modulosPermitidos() {
  return menuPermitido().where((i) => i.ruta != '/inicio').toList();
}

/// Texto corto de cada modulo (se muestra en las tarjetas del Inicio).
String descripcionModulo(String ruta) {
  switch (ruta) {
    case '/activos':
      return 'Alta, edicion, QR y depreciacion';
    case '/mantenimientos':
      return 'Ordenes de mantenimiento';
    case '/depreciacion':
      return 'Calculo y tabla de depreciacion';
    case '/presupuestos':
      return 'Presupuestos, partidas y ejecuciones';
    case '/inventario':
      return 'Toma fisica y conteo de activos';
    case '/reportes':
      return 'Tablero BI, consultas y PDF/Excel';
    case '/ia':
      return 'Consultas en lenguaje natural';
    case '/usuarios':
      return 'Usuarios de la empresa';
    case '/roles':
      return 'Roles y permisos por modulo';
    case '/suscripcion':
      return 'Plan, pagos y facturacion';
    case '/respaldos':
      return 'Respaldos y programacion automatica';
    case '/auditoria':
      return 'Bitacora e integridad de datos';
    case '/configuracion':
      return 'Logo, colores y datos de la empresa';
    case '/plataforma/empresas':
      return 'Empresas de la plataforma';
    default:
      return '';
  }
}

/// Pantalla de un modulo segun su ruta.
Widget pantallaPara(String ruta) {
  switch (ruta) {
    case '/inicio':
      return const InicioScreen();
    case '/mantenimientos':
      return const MantenimientosScreen();
    case '/depreciacion':
      return const DepreciacionScreen();
    case '/presupuestos':
      return const PresupuestosScreen();
    case '/usuarios':
      return const UsuariosScreen();
    case '/roles':
      return const RolesScreen();
    case '/inventario':
      return const InventarioScreen();
    case '/ia':
      return const IaScreen();
    case '/reportes':
      return const ReportesScreen();
    case '/respaldos':
      return const RespaldosScreen();
    case '/auditoria':
      return const BitacoraScreen();
    case '/configuracion':
      return const PersonalizacionScreen();
    case '/suscripcion':
      return const SuscripcionScreen();
    case '/plataforma/empresas':
      return const EmpresasScreen();
    case '/activos':
    default:
      return const ActivosScreen();
  }
}

/// Primera pantalla a la que el usuario tiene acceso: el Inicio con todos los
/// modulos. Antes se abria el primer modulo del menu (que para un Super Admin
/// era "Administracion de plataforma"), y desde ahi no se podia volver.
Widget pantallaInicial() {
  if (modulosPermitidos().isEmpty) return const SinAccesoScreen();
  return const InicioScreen();
}

/// Envoltorio de un modulo: el boton "Atras" del sistema vuelve al Inicio en
/// lugar de cerrar la app, para no perder el camino de las funcionalidades.
class ModuloShell extends StatelessWidget {
  final Widget child;

  const ModuloShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        irAModulo(context, '/inicio');
      },
      child: child,
    );
  }
}

/// Cambia de modulo dejando la pila de navegacion limpia (como navegar a otra ruta en la web).
void irAModulo(BuildContext context, String ruta) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => ruta == '/inicio'
          ? pantallaPara(ruta)
          : ModuloShell(child: pantallaPara(ruta)),
    ),
    (ruta) => false,
  );
}

Future<void> cerrarSesion(BuildContext context) async {
  await AuthService().logout();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (ruta) => false,
  );
}

/// Cambia de empresa: el backend emite un token nuevo con el rol de esa
/// empresa y la app vuelve al Inicio para que todo se recargue con los
/// datos de la nueva empresa.
Future<void> _cambiarEmpresa(BuildContext context, Map<String, dynamic> empresa) async {
  final id = empresa['empresaId'];
  if (id is! num) return;
  Navigator.pop(context);
  final error = await AuthService().cambiarEmpresa(id.toInt());
  if (!context.mounted) return;
  if (error != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    return;
  }
  irAModulo(context, '/inicio');
}

/// Menu lateral con los modulos permitidos, el usuario y el cierre de sesion.
class MenuLateral extends StatelessWidget {
  final String rutaActual;

  const MenuLateral({super.key, required this.rutaActual});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final items = menuPermitido();
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFF1769E0),
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: const Text('AF', style: TextStyle(color: Color(0xFF1769E0), fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Activos Fijos', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(auth.nombre, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(auth.rol, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: auth.isSuperAdmin ? const Color(0xFFFDE68A) : Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        auth.nivel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: auth.isSuperAdmin ? const Color(0xFF78350F) : Colors.white,
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Sprint 3 / multiempresa: selector de empresa.
                  if (auth.empresas.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 4),
                      child: Text('MIS EMPRESAS',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .8,
                              color: Colors.white.withValues(alpha: .7))),
                    ),
                    for (final empresa in auth.empresas)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          empresa['actual'] == true ? Icons.business : Icons.business_outlined,
                          color: Colors.white70,
                        ),
                        title: Text(
                          '${empresa['empresaNombre'] ?? 'Empresa'}'
                          '${empresa['actual'] == true ? ' ·' : ''}',
                          style: const TextStyle(color: Colors.white, fontSize: 13.5),
                        ),
                        subtitle: Text(
                          '${empresa['rol'] ?? ''}',
                          style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                        ),
                        onTap: () => _cambiarEmpresa(context, empresa),
                      ),
                    const Divider(color: Colors.white24, height: 18),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.add_business, color: Colors.white70),
                      title: const Text('Agregar empresa',
                          style: TextStyle(color: Colors.white, fontSize: 13.5)),
                      subtitle: const Text('Registra otra empresa a tu cuenta',
                          style: TextStyle(color: Colors.white60, fontSize: 11.5)),
                      onTap: () {
                        Navigator.pop(context);
                        irAModulo(context, '/registro-empresa');
                      },
                    ),
                  ],
                  for (final item in items)
                    ListTile(
                      leading: Icon(item.icono),
                      title: Text(item.etiquetaMenu),
                      selected: item.ruta == rutaActual,
                      onTap: () {
                        Navigator.pop(context);
                        if (item.ruta != rutaActual) irAModulo(context, item.ruta);
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () => cerrarSesion(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Se muestra si el rol del usuario no tiene permiso para ningun modulo.
class SinAccesoScreen extends StatelessWidget {
  const SinAccesoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: barra('Activos Fijos'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: Color(0xFF8490A3)),
              const SizedBox(height: 12),
              const Text(
                'Tu rol todavía no tiene permisos para ningún módulo. Pide al administrador que los configure.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton(onPressed: () => cerrarSesion(context), child: const Text('Cerrar sesión')),
            ],
          ),
        ),
      ),
    );
  }
}

#
# crear_app_movil.ps1
# Genera la app movil (Flutter) del Sistema de Activos Fijos y Presupuestos,
# con el mismo alcance del frontend web: login, listado de activos y
# registro de activos, consumiendo la misma API del backend.
# Idempotente.
#

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

function Write-Step($msg) { Write-Host ""; Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "    AVISO: $msg" -ForegroundColor Yellow }

function Write-FileNoBom($path, $content) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}
function Remove-Bom($path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        [System.IO.File]::WriteAllBytes($path, $bytes[3..($bytes.Length - 1)])
    }
}
function Remove-BomFromFolder($folder, $extensions) {
    if (-not (Test-Path $folder)) { return }
    Get-ChildItem -Path $folder -Recurse -File | Where-Object { $extensions -contains $_.Extension } | ForEach-Object {
        Remove-Bom $_.FullName
    }
}

# ---------------------------------------------------------------------------
# 1. Verificar Flutter SDK
# ---------------------------------------------------------------------------
Write-Step "Verificando Flutter SDK"

$hasFlutter = $null -ne (Get-Command flutter -ErrorAction SilentlyContinue)

if (-not $hasFlutter) {
    Write-Warn2 "No se encontro 'flutter' en el PATH. Todavia no se puede generar la app movil."
    Write-Host ""
    Write-Host "===========================================================" -ForegroundColor Yellow
    Write-Host " Como instalar Flutter en Windows" -ForegroundColor Yellow
    Write-Host "===========================================================" -ForegroundColor Yellow
    Write-Host " 1) Descarga el SDK (zip) desde:"
    Write-Host "    https://docs.flutter.dev/get-started/install/windows/mobile"
    Write-Host " 2) Descomprimilo en, por ejemplo, C:\src\flutter"
    Write-Host "    (evita rutas con espacios o dentro de Program Files)"
    Write-Host " 3) Agrega C:\src\flutter\bin al PATH del sistema"
    Write-Host "    (Panel de control > Sistema > Variables de entorno)"
    Write-Host " 4) Instala Android Studio (para el SDK de Android y un emulador):"
    Write-Host "    https://developer.android.com/studio"
    Write-Host " 5) Abre una consola NUEVA y corre:  flutter doctor"
    Write-Host "    Segui las indicaciones hasta que los puntos criticos queden en verde (Android toolchain, etc.)"
    Write-Host " 6) Volve a ejecutar este .bat: va a detectar Flutter y generar la app"
    Write-Host "==========================================================="
    Write-Host ""
    Read-Host "Presiona Enter para salir"
    exit 0
}

$verFlutter = "version no determinada"
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $verFlutter = (& flutter --version 2>&1 | Where-Object { $_ -match "Flutter " } | Select-Object -First 1)
    if (-not $verFlutter) { $verFlutter = "detectado (no se pudo leer la version exacta)" }
} catch {
    $verFlutter = "detectado (no se pudo leer la version exacta)"
} finally {
    $ErrorActionPreference = $prevEAP
}
Write-Ok "Flutter detectado: $verFlutter"

# ---------------------------------------------------------------------------
# 2. Crear el proyecto Flutter si no existe
# ---------------------------------------------------------------------------
Write-Step "Proyecto Flutter (mobile/)"

$mobileDir = Join-Path $root "mobile"
$libDir = Join-Path $mobileDir "lib"

if (Test-Path (Join-Path $mobileDir "pubspec.yaml")) {
    Write-Ok "mobile/ ya existe, se omite 'flutter create'"
} else {
    Write-Host "    Ejecutando 'flutter create mobile' (puede tardar unos minutos)..."
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & flutter create --project-name activos_fijos_app --org com.uagrm.activos mobile 2>&1 | Write-Host
    $codigoSalida = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
    if ($codigoSalida -ne 0) {
        Write-Warn2 "flutter create fallo. Revisa 'flutter doctor' y volve a intentar."
        Read-Host "Presiona Enter para salir"
        exit 1
    }
    Write-Ok "Proyecto Flutter base generado en mobile/"
}

if (-not (Test-Path $libDir)) { New-Item -ItemType Directory -Path $libDir -Force | Out-Null }

# ---------------------------------------------------------------------------
# 3. pubspec.yaml: agregar dependencias (http, shared_preferences)
# ---------------------------------------------------------------------------
Write-Step "Configurando dependencias (pubspec.yaml)"

$pubspecPath = Join-Path $mobileDir "pubspec.yaml"
if (Test-Path $pubspecPath) {
    $pubContent = Get-Content $pubspecPath -Raw
    if ($pubContent -notmatch "http:") {
        $pubContent = $pubContent -replace "dependencies:\r?\n", "dependencies:`r`n  http: ^1.2.0`r`n  shared_preferences: ^2.2.0`r`n"
        Set-Content $pubspecPath $pubContent -Encoding UTF8
        Remove-Bom $pubspecPath
        Write-Ok "Dependencias http y shared_preferences agregadas"
    } else {
        Write-Ok "Dependencias ya estaban presentes"
    }
}

# ---------------------------------------------------------------------------
# 4. Codigo fuente Dart
# ---------------------------------------------------------------------------
Write-Step "Generando codigo fuente de la app"

$dirs = @("config", "models", "services", "screens")
foreach ($d in $dirs) {
    $full = Join-Path $libDir $d
    if (-not (Test-Path $full)) { New-Item -ItemType Directory -Path $full | Out-Null }
}

# --- config/api_config.dart ---
@'
// Cambia esta URL segun donde corras la app:
//  - Emulador Android          -> http://10.0.2.2:8080/api
//  - Dispositivo fisico (WiFi) -> http://<IP-de-tu-PC-en-la-red>:8080/api
//  - Chrome / Windows (debug)  -> http://localhost:8080/api
class ApiConfig {
  static const String baseUrl = 'http://10.0.2.2:8080/api';
}
'@ | Set-Content (Join-Path $libDir "config\api_config.dart") -Encoding UTF8

# --- models ---
@'
class Categoria {
  final int id;
  final String nombre;

  Categoria({required this.id, required this.nombre});

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(id: json['id'], nombre: json['nombre']);
  }
}
'@ | Set-Content (Join-Path $libDir "models\categoria.dart") -Encoding UTF8

@'
class Activo {
  final int? id;
  final String? codigo;
  final String nombre;
  final int categoriaId;
  final double valor;
  final String fechaAdquisicion; // yyyy-MM-dd
  final String? proveedor;
  final String? observaciones;
  final String? estado;

  Activo({
    this.id,
    this.codigo,
    required this.nombre,
    required this.categoriaId,
    required this.valor,
    required this.fechaAdquisicion,
    this.proveedor,
    this.observaciones,
    this.estado,
  });

  factory Activo.fromJson(Map<String, dynamic> json) {
    return Activo(
      id: json['id'],
      codigo: json['codigo'],
      nombre: json['nombre'],
      categoriaId: json['categoria'] != null ? json['categoria']['id'] : 0,
      valor: (json['valor'] as num).toDouble(),
      fechaAdquisicion: json['fechaAdquisicion'] ?? '',
      proveedor: json['proveedor'],
      observaciones: json['observaciones'],
      estado: json['estado'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'categoriaId': categoriaId,
      'valor': valor,
      'fechaAdquisicion': fechaAdquisicion,
      'proveedor': proveedor,
      'observaciones': observaciones,
    };
  }
}
'@ | Set-Content (Join-Path $libDir "models\activo.dart") -Encoding UTF8

# --- services/auth_service.dart (HU-01) ---
@'
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AuthService {
  Future<String?> login(String correo, String password) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'correo': correo, 'password': password}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('nombre', data['nombre']);
      await prefs.setString('rol', data['rol']);
      return null; // sin error
    }

    if (res.statusCode == 423) {
      return 'Cuenta bloqueada temporalmente. Intenta mas tarde.';
    }
    return 'Credenciales invalidas';
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('nombre');
    await prefs.remove('rol');
  }
}
'@ | Set-Content (Join-Path $libDir "services\auth_service.dart") -Encoding UTF8

# --- services/categoria_service.dart ---
@'
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/categoria.dart';
import 'auth_service.dart';

class CategoriaService {
  final AuthService _auth = AuthService();

  Future<List<Categoria>> listar() async {
    final token = await _auth.getToken();
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/categorias'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Categoria.fromJson(e)).toList();
    }
    throw Exception('No se pudieron cargar las categorias');
  }
}
'@ | Set-Content (Join-Path $libDir "services\categoria_service.dart") -Encoding UTF8

# --- services/activo_service.dart (HU-02) ---
@'
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/activo.dart';
import 'auth_service.dart';

class ActivoService {
  final AuthService _auth = AuthService();

  Future<List<Activo>> listar() async {
    final token = await _auth.getToken();
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/activos'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Activo.fromJson(e)).toList();
    }
    throw Exception('No se pudieron cargar los activos');
  }

  Future<void> registrar(Activo activo) async {
    final token = await _auth.getToken();
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/activos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(activo.toJson()),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('No se pudo registrar el activo');
    }
  }
}
'@ | Set-Content (Join-Path $libDir "services\activo_service.dart") -Encoding UTF8

# --- screens/login_screen.dart ---
@'
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'activos_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _cargando = false;

  Future<void> _iniciarSesion() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    final error = await _authService.login(
      _correoController.text.trim(),
      _passwordController.text,
    );

    setState(() => _cargando = false);

    if (error == null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ActivosScreen()),
      );
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesion')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Activos Fijos y Presupuestos',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _correoController,
              decoration: const InputDecoration(
                labelText: 'Correo institucional',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Contrasena',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _cargando ? null : _iniciarSesion,
                child: _cargando
                    ? const CircularProgressIndicator()
                    : const Text('Ingresar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
'@ | Set-Content (Join-Path $libDir "screens\login_screen.dart") -Encoding UTF8

# --- screens/activos_screen.dart (HU-02 listado + registro) ---
@'
import 'package:flutter/material.dart';
import '../models/activo.dart';
import '../models/categoria.dart';
import '../services/activo_service.dart';
import '../services/categoria_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ActivosScreen extends StatefulWidget {
  const ActivosScreen({super.key});

  @override
  State<ActivosScreen> createState() => _ActivosScreenState();
}

class _ActivosScreenState extends State<ActivosScreen> {
  final _activoService = ActivoService();
  final _categoriaService = CategoriaService();
  final _authService = AuthService();

  List<Activo> _activos = [];
  List<Categoria> _categorias = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final activos = await _activoService.listar();
      final categorias = await _categoriaService.listar();
      setState(() {
        _activos = activos;
        _categorias = categorias;
      });
    } catch (_) {
      // Si falla (por ejemplo token vencido), no rompemos la pantalla
    } finally {
      setState(() => _cargando = false);
    }
  }

  String _nombreCategoria(int id) {
    final match = _categorias.where((c) => c.id == id);
    return match.isEmpty ? '-' : match.first.nombre;
  }

  Color _colorEstado(String? estado) {
    switch (estado) {
      case 'EN_USO':
        return Colors.green.shade100;
      case 'MANTENIMIENTO':
        return Colors.amber.shade100;
      case 'BAJA':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade300;
    }
  }

  Future<void> _cerrarSesion() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _abrirFormularioNuevoActivo() {
    final nombreCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
    final proveedorCtrl = TextEditingController();
    final fechaCtrl = TextEditingController();
    int? categoriaSeleccionada = _categorias.isNotEmpty ? _categorias.first.id : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Nuevo activo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: categoriaSeleccionada,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: _categorias
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)))
                      .toList(),
                  onChanged: (v) => categoriaSeleccionada = v,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valorCtrl,
                  decoration: const InputDecoration(labelText: 'Valor (Bs)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: fechaCtrl,
                  decoration: const InputDecoration(labelText: 'Fecha adquisicion (AAAA-MM-DD)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: proveedorCtrl,
                  decoration: const InputDecoration(labelText: 'Proveedor (opcional)'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    if (nombreCtrl.text.isEmpty ||
                        categoriaSeleccionada == null ||
                        valorCtrl.text.isEmpty ||
                        fechaCtrl.text.isEmpty) {
                      return;
                    }
                    final nuevo = Activo(
                      nombre: nombreCtrl.text,
                      categoriaId: categoriaSeleccionada!,
                      valor: double.tryParse(valorCtrl.text) ?? 0,
                      fechaAdquisicion: fechaCtrl.text,
                      proveedor: proveedorCtrl.text.isEmpty ? null : proveedorCtrl.text,
                    );
                    try {
                      await _activoService.registrar(nuevo);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _cargarDatos();
                    } catch (_) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('No se pudo registrar el activo')),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar activo'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activos fijos'),
        actions: [
          IconButton(onPressed: _cerrarSesion, icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirFormularioNuevoActivo,
        child: const Icon(Icons.add),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: _activos.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No hay activos registrados todavia.')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _activos.length,
                      itemBuilder: (context, index) {
                        final a = _activos[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            title: Text(a.nombre),
                            subtitle: Text(
                              '${a.codigo ?? ''} - ${_nombreCategoria(a.categoriaId)}\nBs ${a.valor.toStringAsFixed(2)}',
                            ),
                            isThreeLine: true,
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _colorEstado(a.estado),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(a.estado ?? 'SIN_ASIGNAR', style: const TextStyle(fontSize: 11)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
'@ | Set-Content (Join-Path $libDir "screens\activos_screen.dart") -Encoding UTF8

# --- main.dart ---
@'
import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/activos_screen.dart';

void main() {
  runApp(const ActivosFijosApp());
}

class ActivosFijosApp extends StatelessWidget {
  const ActivosFijosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Activos Fijos y Presupuestos',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const _ArrancarApp(),
    );
  }
}

class _ArrancarApp extends StatelessWidget {
  const _ArrancarApp();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService().isLoggedIn(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data! ? const ActivosScreen() : const LoginScreen();
      },
    );
  }
}
'@ | Set-Content (Join-Path $libDir "main.dart") -Encoding UTF8

Remove-BomFromFolder $libDir @(".dart")
Write-Ok "Codigo fuente de la app movil generado (login, listado y registro de activos)"

# ---------------------------------------------------------------------------
# 5. Permitir HTTP sin cifrar en Android (solo para desarrollo local)
# ---------------------------------------------------------------------------
Write-Step "Configurando permisos de red en Android (solo desarrollo)"

$manifestPath = Join-Path $mobileDir "android\app\src\main\AndroidManifest.xml"
$resXmlDir = Join-Path $mobileDir "android\app\src\main\res\xml"

if (Test-Path $manifestPath) {
    if (-not (Test-Path $resXmlDir)) { New-Item -ItemType Directory -Path $resXmlDir -Force | Out-Null }

@'
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true" />
</network-security-config>
'@ | Set-Content (Join-Path $resXmlDir "network_security_config.xml") -Encoding UTF8
    Remove-Bom (Join-Path $resXmlDir "network_security_config.xml")

    $manifestContent = Get-Content $manifestPath -Raw
    if ($manifestContent -notmatch "networkSecurityConfig") {
        $manifestContent = $manifestContent -replace '<application', '<application android:networkSecurityConfig="@xml/network_security_config" android:usesCleartextTraffic="true"'
        Set-Content $manifestPath $manifestContent -Encoding UTF8
        Remove-Bom $manifestPath
        Write-Ok "AndroidManifest.xml actualizado para permitir HTTP en desarrollo"
    } else {
        Write-Ok "AndroidManifest.xml ya estaba configurado"
    }
} else {
    Write-Warn2 "No se encontro AndroidManifest.xml (¿se genero bien el proyecto Android?)"
}

# ---------------------------------------------------------------------------
# 6. flutter pub get
# ---------------------------------------------------------------------------
Write-Step "Instalando dependencias (flutter pub get)"
Push-Location $mobileDir
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& flutter pub get 2>&1 | Write-Host
$ErrorActionPreference = $prevEAP
Pop-Location
Write-Ok "Dependencias instaladas"

Write-Host ""
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " App movil lista" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " Antes de correrla:"
Write-Host " 1) Asegurate de que el backend este corriendo (mvn spring-boot:run)"
Write-Host " 2) Revisa mobile\lib\config\api_config.dart y ajusta la URL segun donde"
Write-Host "    vayas a probar la app (emulador Android = 10.0.2.2, celular fisico"
Write-Host "    = la IP de tu PC en la red WiFi, Windows/Chrome = localhost)"
Write-Host " 3) cd mobile"
Write-Host "    flutter devices        (para ver los dispositivos/emuladores disponibles)"
Write-Host "    flutter run"
Write-Host ""

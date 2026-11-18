// URL del backend. Se puede cambiar al compilar, sin editar este archivo:
//   flutter run --dart-define=API_URL=http://192.168.1.10:8080/api
//
// Valores habituales:
//  - Emulador Android          -> http://10.0.2.2:8080/api
//  - Dispositivo fisico (WiFi) -> http://<IP-de-tu-PC-en-la-red>:8080/api
//  - Chrome / Windows (debug)  -> http://localhost:8080/api   (valor por defecto)
//
// El lanzador del proyecto (iniciar_proyecto.bat -> opcion movil) elige y pasa la URL correcta solo.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080/api',
  );
}

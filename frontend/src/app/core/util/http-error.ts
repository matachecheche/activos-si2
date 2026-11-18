/**
 * Extrae el mensaje {"message": "..."} que devuelve el backend (o un texto
 * por defecto).
 *
 * Ronda 11: antes se perdia la causa real de los errores (por ejemplo al
 * cambiar de empresa). Ahora el mensaje del servidor se muestra siempre y,
 * cuando no hay, se explica el codigo HTTP para que el usuario (y el
 * administrador) sepa que paso.
 */
export function mensajeError(err: any, porDefecto = 'Ocurrió un error inesperado. Intenta nuevamente.'): string {
  if (!err) return porDefecto;
  if (err.status === 0) return 'No se pudo conectar con el servidor. Revisa tu conexión e intenta de nuevo.';
  const cuerpo = err.error;
  if (typeof cuerpo === 'string' && cuerpo.trim()) {
    // El backend puede responder con texto plano (por ejemplo "Invalid CORS request").
    return cuerpo.trim();
  }
  if (cuerpo && typeof cuerpo === 'object' && !(cuerpo instanceof Blob)) {
    const mensaje = cuerpo.message || cuerpo.detail || cuerpo.error;
    if (typeof mensaje === 'string' && mensaje.trim()) return mensaje.trim();
    if (cuerpo.descripcion) return cuerpo.descripcion;
  }
  switch (err.status) {
    case 400:
      return 'La solicitud no fue válida. Revisa los datos e intenta de nuevo.';
    case 401:
      return 'Tu sesión venció. Vuelve a iniciar sesión.';
    case 403:
      return 'No tienes permiso para realizar esta operación.';
    case 404:
      return 'No se encontró lo que se buscaba. Actualiza la lista e intenta de nuevo.';
    case 409:
      return 'Ya existe un registro con esos datos.';
    case 429:
      return 'Demasiados intentos. Espera unos segundos e intenta de nuevo.';
    case 502:
    case 503:
    case 504:
      return `El servidor no pudo responder ahora (HTTP ${err.status}). Intenta de nuevo en unos segundos.`;
    case 500:
      return `El servidor tuvo un error (HTTP 500). Intenta de nuevo en unos segundos.`;
    default:
      return err.status ? `Error del servidor (HTTP ${err.status}). ${porDefecto}` : porDefecto;
  }
}

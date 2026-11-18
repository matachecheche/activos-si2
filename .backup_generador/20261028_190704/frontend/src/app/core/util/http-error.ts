/** Extrae el mensaje {"message": "..."} que devuelve el backend (o un texto por defecto). */
export function mensajeError(err: any, porDefecto = 'Ocurrió un error inesperado. Intenta nuevamente.'): string {
  if (!err) return porDefecto;
  if (err.status === 0) return 'No se pudo conectar con el servidor.';
  const cuerpo = err.error;
  if (typeof cuerpo === 'string' && cuerpo.trim()) return cuerpo;
  if (cuerpo && typeof cuerpo === 'object' && !(cuerpo instanceof Blob)) {
    return cuerpo.message || cuerpo.detail || porDefecto;
  }
  if (err.status === 403) return 'No tienes permiso para realizar esta operación.';
  return porDefecto;
}

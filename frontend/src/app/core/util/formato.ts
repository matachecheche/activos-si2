const ETIQUETAS: Record<string, string> = {
  DISPONIBLE: 'Disponible', EN_USO: 'En uso', EN_MANTENIMIENTO: 'En mantenimiento', INACTIVO: 'Inactivo', DADO_DE_BAJA: 'Dado de baja',
  PROGRAMADO: 'Programado', EN_EJECUCION: 'En ejecución', FINALIZADO: 'Finalizado', CANCELADO: 'Cancelado',
  PREVENTIVO: 'Preventivo', CORRECTIVO: 'Correctivo',
  BORRADOR: 'Borrador', APROBADO: 'Aprobado', CERRADO: 'Cerrado',
  COMPROMISO: 'Compromiso', EJECUCION: 'Ejecución'
};

export function etiqueta(valor?: string | null): string {
  if (!valor) return '-';
  return ETIQUETAS[valor] ?? valor;
}

/** Clase CSS del distintivo de estado: badge badge-en-uso, badge-aprobado, etc. */
export function claseBadge(valor?: string | null): string {
  return 'badge badge-' + (valor ?? 'ninguno').toLowerCase().replace(/_/g, '-');
}

export function descargarBlob(blob: Blob, nombreArchivo: string): void {
  const url = URL.createObjectURL(blob);
  const enlace = document.createElement('a');
  enlace.href = url;
  enlace.download = nombreArchivo;
  document.body.appendChild(enlace);
  enlace.click();
  enlace.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

export function hoyISO(): string {
  const d = new Date();
  const mes = String(d.getMonth() + 1).padStart(2, '0');
  const dia = String(d.getDate()).padStart(2, '0');
  return `${d.getFullYear()}-${mes}-${dia}`;
}

export function gestionActual(): number {
  return new Date().getFullYear();
}

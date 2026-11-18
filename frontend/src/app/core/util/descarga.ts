/**
 * HU-13/HU-14: descarga un binario (PDF, Excel, respaldo .afb) como adjunto.
 * El token va en cabecera porque no es una navegacion comun del navegador.
 */
export async function descargarBinario(
  url: string,
  nombreArchivo: string,
  method: 'GET' | 'POST' = 'GET',
  body?: unknown
): Promise<void> {
  const token = localStorage.getItem('token');
  const init: RequestInit = {
    method,
    headers: { Authorization: token ? `Bearer ${token}` : '' }
  };
  if (body !== undefined) {
    init.headers = { ...init.headers, 'Content-Type': 'application/json' };
    init.body = JSON.stringify(body);
  }
  // El init (cabecera Authorization, metodo y cuerpo) debe pasarse al fetch;
  // sin él la petición salía como GET sin token y el backend devolvía 401/405.
  const respuesta = await fetch(url, init);
  if (!respuesta.ok) {
    let detalle = '';
    try {
      const data = await respuesta.json();
      detalle = data?.message ? `: ${data.message}` : '';
    } catch {
      // la respuesta de error no traía JSON
    }
    throw new Error(`Descarga fallida (HTTP ${respuesta.status})${detalle}`);
  }
  const blob = await respuesta.blob();
  const enlace = document.createElement('a');
  enlace.href = URL.createObjectURL(blob);
  enlace.download = nombreArchivo;
  document.body.appendChild(enlace);
  enlace.click();
  enlace.remove();
  URL.revokeObjectURL(enlace.href);
}

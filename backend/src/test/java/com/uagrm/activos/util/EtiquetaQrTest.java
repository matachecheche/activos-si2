package com.uagrm.activos.util;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** HU-05: el QR y la etiqueta se generan sin AWT ni fuentes del sistema. */
class EtiquetaQrTest {

    @Test
    void elQrEsUnaMatrizCuadrada() {
        boolean[][] modulos = QrCodigo.modulos("ACT-2026-0001");
        assertEquals(modulos.length, modulos[0].length);
        assertTrue(modulos.length >= 21);
    }

    @Test
    void elPngTieneFirmaYTamanoEsperado() {
        boolean[][] modulos = QrCodigo.modulos("ACT-2026-0001");
        byte[] png = PngUtil.qrComoPng(modulos, 4, 4);
        assertEquals((byte) 0x89, png[0]);
        assertEquals('P', png[1]);
        assertEquals('N', png[2]);
        assertEquals('G', png[3]);
        // el ancho y el alto estan en los bytes 16..23 del IHDR
        int ancho = ((png[16] & 0xFF) << 24) | ((png[17] & 0xFF) << 16) | ((png[18] & 0xFF) << 8) | (png[19] & 0xFF);
        assertEquals((modulos.length + 8) * 4, ancho);
    }

    @Test
    void elPdfEsValidoYNoSePartePorLosAcentos() {
        boolean[][] modulos = QrCodigo.modulos("ACT-2026-0001");
        byte[] pdf = PdfEtiqueta.generar(modulos, "ACT-2026-0001", "Cámara (ñandú) \\ prueba", "Activos Fijos - UAGRM");
        String texto = new String(pdf, StandardCharsets.ISO_8859_1);
        assertTrue(texto.startsWith("%PDF-1.4"));
        assertTrue(texto.contains("ACT-2026-0001"));
        assertTrue(texto.trim().endsWith("%%EOF"));
    }
}

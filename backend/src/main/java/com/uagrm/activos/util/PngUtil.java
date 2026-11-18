package com.uagrm.activos.util;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.util.zip.CRC32;
import java.util.zip.Deflater;

/** Escritor PNG minimo (escala de grises de 8 bits) para no depender de AWT en el servidor. */
public final class PngUtil {

    private static final byte[] FIRMA = {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A};

    private PngUtil() {
    }

    /**
     * Dibuja los modulos del QR.
     *
     * @param escala pixeles por modulo
     * @param margen modulos blancos alrededor (zona de silencio)
     */
    public static byte[] qrComoPng(boolean[][] modulos, int escala, int margen) {
        int n = modulos.length;
        int lado = (n + 2 * margen) * escala;
        byte[] crudo = new byte[(lado + 1) * lado];
        int pos = 0;
        for (int py = 0; py < lado; py++) {
            crudo[pos++] = 0; // filtro "none"
            int my = py / escala - margen;
            for (int px = 0; px < lado; px++) {
                int mx = px / escala - margen;
                boolean oscuro = my >= 0 && my < n && mx >= 0 && mx < n && modulos[my][mx];
                crudo[pos++] = (byte) (oscuro ? 0 : 255);
            }
        }
        try {
            ByteArrayOutputStream salida = new ByteArrayOutputStream();
            salida.write(FIRMA);
            ByteArrayOutputStream cabecera = new ByteArrayOutputStream();
            DataOutputStream datos = new DataOutputStream(cabecera);
            datos.writeInt(lado);
            datos.writeInt(lado);
            datos.writeByte(8); // profundidad de bits
            datos.writeByte(0); // escala de grises
            datos.writeByte(0); // compresion
            datos.writeByte(0); // filtro
            datos.writeByte(0); // sin entrelazado
            bloque(salida, "IHDR", cabecera.toByteArray());
            bloque(salida, "IDAT", comprimir(crudo));
            bloque(salida, "IEND", new byte[0]);
            return salida.toByteArray();
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo generar la imagen PNG", e);
        }
    }

    private static byte[] comprimir(byte[] datos) {
        Deflater deflater = new Deflater(Deflater.BEST_COMPRESSION);
        deflater.setInput(datos);
        deflater.finish();
        ByteArrayOutputStream salida = new ByteArrayOutputStream();
        byte[] buffer = new byte[8192];
        while (!deflater.finished()) {
            int n = deflater.deflate(buffer);
            salida.write(buffer, 0, n);
        }
        deflater.end();
        return salida.toByteArray();
    }

    private static void bloque(ByteArrayOutputStream salida, String tipo, byte[] datos) throws IOException {
        DataOutputStream out = new DataOutputStream(salida);
        out.writeInt(datos.length);
        byte[] tipoBytes = tipo.getBytes(java.nio.charset.StandardCharsets.US_ASCII);
        out.write(tipoBytes);
        out.write(datos);
        CRC32 crc = new CRC32();
        crc.update(tipoBytes);
        crc.update(datos);
        out.writeInt((int) crc.getValue());
    }
}

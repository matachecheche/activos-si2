package com.uagrm.activos.util;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.EncodeHintType;
import com.google.zxing.WriterException;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel;

import java.util.EnumMap;
import java.util.Map;

/** HU-05: genera la matriz de modulos del QR con ZXing (sin depender de AWT ni de fuentes). */
public final class QrCodigo {

    private QrCodigo() {
    }

    /** Devuelve la matriz [fila][columna] de modulos (true = modulo oscuro), sin zona de silencio. */
    public static boolean[][] modulos(String contenido) {
        Map<EncodeHintType, Object> hints = new EnumMap<>(EncodeHintType.class);
        hints.put(EncodeHintType.ERROR_CORRECTION, ErrorCorrectionLevel.M);
        hints.put(EncodeHintType.CHARACTER_SET, "UTF-8");
        hints.put(EncodeHintType.MARGIN, 0);
        try {
            BitMatrix matriz = new QRCodeWriter().encode(contenido, BarcodeFormat.QR_CODE, 0, 0, hints);
            boolean[][] modulos = new boolean[matriz.getHeight()][matriz.getWidth()];
            for (int y = 0; y < matriz.getHeight(); y++) {
                for (int x = 0; x < matriz.getWidth(); x++) {
                    modulos[y][x] = matriz.get(x, y);
                }
            }
            return modulos;
        } catch (WriterException e) {
            throw new IllegalStateException("No se pudo generar el código QR", e);
        }
    }
}

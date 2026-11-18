package com.uagrm.activos.util;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * HU-05: etiqueta del activo en PDF (QR vectorial + codigo + nombre). Escribe el PDF a mano con
 * fuentes base-14 (Helvetica), por lo que no necesita librerias ni fuentes instaladas en el servidor.
 */
public final class PdfEtiqueta {

    private static final double ANCHO = 226.77;  // 80 mm
    private static final double ALTO = 283.46;   // 100 mm
    private static final Charset WIN_ANSI = Charset.forName("windows-1252");

    // Anchos de Helvetica (AFM) para los caracteres 32..126, en milesimas de em.
    private static final int[] HELVETICA = {
            278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278,
            556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556,
            1015, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778,
            667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278, 278, 278, 469, 556,
            333, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556,
            556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334, 260, 334, 584};

    // Anchos de Helvetica-Bold para los caracteres 32..126.
    private static final int[] HELVETICA_BOLD = {
            278, 333, 474, 556, 556, 889, 722, 238, 333, 333, 389, 584, 278, 333, 278, 278,
            556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 333, 333, 584, 584, 584, 611,
            975, 722, 722, 722, 722, 667, 611, 778, 722, 278, 556, 722, 611, 833, 722, 778,
            667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 333, 278, 333, 584, 556,
            333, 556, 611, 556, 611, 556, 333, 611, 611, 278, 278, 556, 278, 889, 611, 611,
            611, 611, 389, 556, 333, 611, 556, 778, 556, 556, 500, 389, 280, 389, 584};

    private PdfEtiqueta() {
    }

    public static byte[] generar(boolean[][] modulos, String codigo, String nombre, String entidad) {
        try {
            byte[] contenido = contenido(modulos, codigo, nombre, entidad);
            return ensamblar(contenido);
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo generar la etiqueta PDF", e);
        }
    }

    private static byte[] contenido(boolean[][] modulos, String codigo, String nombre, String entidad) throws IOException {
        ByteArrayOutputStream cs = new ByteArrayOutputStream();
        escribir(cs, "q\n");
        // marco
        escribir(cs, "0.6 w 0.2 G 8 8 " + num(ANCHO - 16) + " " + num(ALTO - 16) + " re S\n");
        // entidad (cabecera)
        texto(cs, entidad, "F1", 9, ANCHO / 2, ALTO - 28, true);
        // QR
        double lado = 168;
        int n = modulos.length;
        int zona = 2; // modulos de zona de silencio
        double modulo = lado / (n + 2.0 * zona);
        double x0 = (ANCHO - lado) / 2;
        double yTop = ALTO - 42;
        escribir(cs, "0 g\n");
        for (int fila = 0; fila < n; fila++) {
            int col = 0;
            while (col < n) {
                if (modulos[fila][col]) {
                    int inicio = col;
                    while (col < n && modulos[fila][col]) {
                        col++;
                    }
                    double x = x0 + (zona + inicio) * modulo;
                    double y = yTop - (zona + fila + 1) * modulo;
                    escribir(cs, num(x) + " " + num(y) + " " + num((col - inicio) * modulo) + " " + num(modulo) + " re\n");
                } else {
                    col++;
                }
            }
        }
        escribir(cs, "f\n");
        // codigo y nombre
        double yCodigo = yTop - lado - 22;
        texto(cs, codigo, "F2", 16, ANCHO / 2, yCodigo, true);
        List<String> lineas = partir(nombre == null ? "" : nombre, 10, ANCHO - 36, 2);
        double y = yCodigo - 18;
        for (String linea : lineas) {
            texto(cs, linea, "F1", 10, ANCHO / 2, y, false);
            y -= 13;
        }
        escribir(cs, "Q\n");
        return cs.toByteArray();
    }

    private static void texto(ByteArrayOutputStream cs, String texto, String fuente, double tam, double centroX, double y, boolean negrita) throws IOException {
        String limpio = texto == null ? "" : texto;
        double ancho = ancho(limpio, "F2".equals(fuente), tam);
        double x = centroX - ancho / 2;
        escribir(cs, "BT /" + fuente + " " + num(tam) + " Tf " + num(x) + " " + num(y) + " Td (");
        cs.write(escapar(limpio));
        escribir(cs, ") Tj ET\n");
    }

    private static byte[] escapar(String texto) {
        byte[] bytes = texto.getBytes(WIN_ANSI);
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        for (byte b : bytes) {
            if (b == '(' || b == ')' || b == '\\') {
                out.write('\\');
            }
            out.write(b);
        }
        return out.toByteArray();
    }

    static double ancho(String texto, boolean negrita, double tam) {
        int[] tabla = negrita ? HELVETICA_BOLD : HELVETICA;
        double total = 0;
        for (int i = 0; i < texto.length(); i++) {
            char c = texto.charAt(i);
            total += (c >= 32 && c <= 126) ? tabla[c - 32] : 556;
        }
        return total * tam / 1000.0;
    }

    static List<String> partir(String texto, double tam, double anchoMax, int maxLineas) {
        List<String> lineas = new ArrayList<>();
        StringBuilder actual = new StringBuilder();
        String[] palabras = texto.trim().split("\\s+");
        boolean truncado = false;
        for (String palabra : palabras) {
            if (palabra.isEmpty()) {
                continue;
            }
            String candidato = actual.length() == 0 ? palabra : actual + " " + palabra;
            if (ancho(candidato, false, tam) <= anchoMax) {
                actual = new StringBuilder(candidato);
            } else {
                if (actual.length() > 0) {
                    lineas.add(actual.toString());
                    if (lineas.size() == maxLineas) {
                        truncado = true;
                        actual = new StringBuilder();
                        break;
                    }
                }
                actual = new StringBuilder(recortar(palabra, tam, anchoMax));
            }
        }
        if (actual.length() > 0 && lineas.size() < maxLineas) {
            lineas.add(actual.toString());
        } else if (actual.length() > 0) {
            truncado = true;
        }
        if (truncado && !lineas.isEmpty()) {
            int ultima = lineas.size() - 1;
            lineas.set(ultima, recortar(lineas.get(ultima) + "...", tam, anchoMax));
        }
        return lineas;
    }

    private static String recortar(String texto, double tam, double anchoMax) {
        String t = texto;
        while (t.length() > 1 && ancho(t, false, tam) > anchoMax) {
            t = t.substring(0, t.length() - 1);
        }
        return t;
    }

    private static byte[] ensamblar(byte[] contenido) throws IOException {
        ByteArrayOutputStream pdf = new ByteArrayOutputStream();
        List<Integer> offsets = new ArrayList<>();
        escribir(pdf, "%PDF-1.4\n");
        offsets.add(pdf.size());
        escribir(pdf, "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n");
        offsets.add(pdf.size());
        escribir(pdf, "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n");
        offsets.add(pdf.size());
        escribir(pdf, "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 " + num(ANCHO) + " " + num(ALTO)
                + "] /Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >>\nendobj\n");
        offsets.add(pdf.size());
        escribir(pdf, "4 0 obj\n<< /Length " + contenido.length + " >>\nstream\n");
        pdf.write(contenido);
        escribir(pdf, "endstream\nendobj\n");
        offsets.add(pdf.size());
        escribir(pdf, "5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\nendobj\n");
        offsets.add(pdf.size());
        escribir(pdf, "6 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>\nendobj\n");
        int xref = pdf.size();
        escribir(pdf, "xref\n0 " + (offsets.size() + 1) + "\n");
        escribir(pdf, "0000000000 65535 f \n");
        for (int offset : offsets) {
            escribir(pdf, String.format(Locale.ROOT, "%010d 00000 n \n", offset));
        }
        escribir(pdf, "trailer\n<< /Size " + (offsets.size() + 1) + " /Root 1 0 R >>\nstartxref\n" + xref + "\n%%EOF\n");
        return pdf.toByteArray();
    }

    private static void escribir(ByteArrayOutputStream out, String texto) throws IOException {
        out.write(texto.getBytes(StandardCharsets.ISO_8859_1));
    }

    private static String num(double valor) {
        return String.format(Locale.ROOT, "%.2f", valor);
    }
}

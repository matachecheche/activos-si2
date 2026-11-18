package com.uagrm.activos.service;

import com.uagrm.activos.model.Activo;
import com.uagrm.activos.repository.ActivoRepository;
import com.uagrm.activos.util.PdfEtiqueta;
import com.uagrm.activos.util.PngUtil;
import com.uagrm.activos.util.QrCodigo;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * HU-05: el QR se genera bajo demanda a partir del codigo unico del activo; no se guardan
 * imagenes en la base de datos y el codigo nunca se modifica.
 */
@Service
public class EtiquetaService {

    private static final String ENTIDAD = "Activos Fijos - UAGRM";

    private final ActivoRepository activoRepository;

    public EtiquetaService(ActivoRepository activoRepository) {
        this.activoRepository = activoRepository;
    }

    @Transactional(readOnly = true)
    public byte[] qrPng(Long activoId, Integer tamano) {
        Activo activo = activo(activoId);
        boolean[][] modulos = QrCodigo.modulos(activo.getCodigo());
        int objetivo = tamano == null ? 320 : Math.max(120, Math.min(1000, tamano));
        int escala = Math.max(1, objetivo / (modulos.length + 8));
        return PngUtil.qrComoPng(modulos, escala, 4);
    }

    @Transactional(readOnly = true)
    public byte[] etiquetaPdf(Long activoId) {
        Activo activo = activo(activoId);
        return PdfEtiqueta.generar(QrCodigo.modulos(activo.getCodigo()), activo.getCodigo(), activo.getNombre(), ENTIDAD);
    }

    @Transactional(readOnly = true)
    public String codigo(Long activoId) {
        return activo(activoId).getCodigo();
    }

    private Activo activo(Long id) {
        return activoRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Activo no encontrado"));
    }
}

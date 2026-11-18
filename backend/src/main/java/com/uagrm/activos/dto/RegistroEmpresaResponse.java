package com.uagrm.activos.dto;

import lombok.*;
import java.time.LocalDateTime;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class RegistroEmpresaResponse {
    private Long empresaId;
    private String nombreEmpresa;
    private String estado;
    private Long suscripcionId;
    private String plan;
    private LocalDateTime vencimiento;
    private Long pagoId;
    private String referenciaPago;
    private String estadoPago;
    private String correoAdmin;
    private String mensaje;
    /** Metodo de pago elegido al crear la empresa (STRIPE, QR, TRANSFERENCIA...). */
    private String metodoPago;
    /** true si se genero un checkout real de pago (o una orden de transferencia). */
    private Boolean pagoDisponible;
    /** URL de la pasarela para completar el pago (Stripe, PayPal, Mercado Pago). */
    private String checkoutUrl;
    /** Codigo QR en base64 (data URL) cuando el metodo es QR. */
    private String qrImagen;
    /** Datos de la cuenta bancaria cuando el metodo es transferencia. */
    private java.util.Map<String, String> datosBancarios;
    /** Instrucciones de pago (transferencia bancaria). */
    private String instrucciones;
    /** Monto a pagar. */
    private java.math.BigDecimal monto;
    /** Mensaje del sistema de pagos (por que no se pudo abrir el cobro). */
    private String mensajePago;
}

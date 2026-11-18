package com.uagrm.activos.ia;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Valida la interpretacion de las respuestas del LLM sin llamadas HTTP:
 * mensajes conversacionales, especificaciones de consulta, compatibilidad
 * con el formato antiguo y rechazo de JSON invalido.
 */
class IaServiceTest {

    private IaService iaService;
    private MotorConsultaSql motor;

    @BeforeEach
    void preparar() {
        CatalogoSql catalogo = new CatalogoSql();
        motor = mock(MotorConsultaSql.class);
        IaConfigLoader loader = mock(IaConfigLoader.class);
        when(loader.formatoGroqValido()).thenReturn(true);
        when(loader.formatoGeminiValido()).thenReturn(true);
        iaService = new IaService(catalogo, motor, loader);
    }

    @Test
    void unSaludoDevuelveMensajeConversacionalSinSql() {
        String json = "{\"tipo\":\"mensaje\",\"texto\":\"Hola. ¿En qué puedo ayudarte?\"}";

        RespuestaIa r = iaService.interpretarContenido(json, "GROQ");

        assertEquals("GROQ", r.getModo());
        assertEquals("Hola. ¿En qué puedo ayudarte?", r.getExplicacion());
        assertNull(r.getSqlEjecutado());
        assertTrue(r.getFilas().isEmpty());
        verifyNoInteractions(motor);
    }

    @Test
    void unaPreguntaDeDatosEjecutaElMotor() {
        when(motor.ejecutar(any(ConsultaEspec.class))).thenReturn(new ResultadoConsulta(
                "SELECT id FROM activo WHERE valor > ?",
                List.of("id"),
                List.of(Map.of("id", 8))));
        String json = """
                {"tipo":"consulta","entidad":"activo","columnas":["id"],
                 "filtros":[{"campo":"valor","operador":">","valor":5000}],
                 "orden":[],"limite":100}
                """;

        RespuestaIa r = iaService.interpretarContenido(json, "GROQ");

        assertEquals("GROQ", r.getModo());
        assertEquals(1, r.getFilas().size());
        assertNotNull(r.getSqlEjecutado());
        assertTrue(r.getExplicacion().contains("1 fila"));
        verify(motor).ejecutar(any(ConsultaEspec.class));
    }

    @Test
    void elFormatoAntiguoSinCampoTipoSigueFuncionando() {
        when(motor.ejecutar(any(ConsultaEspec.class))).thenReturn(new ResultadoConsulta(
                "SELECT * FROM categoria", List.of("id"), List.of()));
        String json = "{\"entidad\":\"categoria\",\"columnas\":[\"id\"],\"limite\":10}";

        RespuestaIa r = iaService.interpretarContenido(json, "GEMINI");

        assertEquals("GEMINI", r.getModo());
        verify(motor).ejecutar(any(ConsultaEspec.class));
    }

    @Test
    void textoSinJsonLanzaBadGateway() {
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> iaService.interpretarContenido("lo siento, no puedo ayudar", "GROQ"));
        assertEquals(HttpStatus.BAD_GATEWAY, ex.getStatusCode());
    }

    @Test
    void mensajeVacioSeRechaza() {
        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> iaService.interpretarContenido("{\"tipo\":\"mensaje\",\"texto\":\"  \"}", "GROQ"));
        assertEquals(HttpStatus.BAD_GATEWAY, ex.getStatusCode());
    }

    @Test
    void elCatalogoDelPromptIncluyeDescripcionesDeColumnas() {
        String descripcion = new CatalogoSql().describir();
        assertTrue(descripcion.contains("DISPONIBLE"), "los valores del ENUM estado deben llegar al modelo");
        assertTrue(descripcion.contains("activo"));
    }
}

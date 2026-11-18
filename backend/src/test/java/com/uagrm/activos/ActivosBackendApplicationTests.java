package com.uagrm.activos;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

/**
 * Prueba de arranque: comprueba que toda la configuracion de Spring (seguridad,
 * JPA, pasarelas de pago, IA, respaldos...) se levanta sin errores.
 *
 * <p>La base de datos de pruebas la prepara {@link DbDePrueba}, de modo que el
 * test se puede ejecutar en un equipo limpio sin crear las bases a mano.</p>
 */
@SpringBootTest
class ActivosBackendApplicationTests {

    @DynamicPropertySource
    static void propiedadesDePrueba(DynamicPropertyRegistry registro) {
        registro.add("spring.datasource.url", DbDePrueba::urlDePrueba);
    }

    @Test
    void contextLoads() {
    }
}

<#
  setup.ps1
  Genera el proyecto "Sistema de Activos Fijos y Presupuestos" (Grupo 7 - UAGRM)
  hasta el alcance comprometido en el Sprint 1 (HU-01, HU-02, HU-03):
    - Backend Spring Boot + PostgreSQL + JWT
    - Frontend Angular (standalone)
    - Script de base de datos
  Idempotente: puede volver a ejecutarse sin romper lo ya generado.
#>

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

function Write-Step($msg) { Write-Host ""; Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "    AVISO: $msg" -ForegroundColor Yellow }

# Escribe un archivo en UTF-8 SIN BOM (psql y algunas herramientas fallan si hay BOM)
function Write-FileNoBom($path, $content) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

# Elimina el BOM UTF-8 de un archivo si lo tiene (javac, entre otros, lo rechaza)
function Remove-Bom($path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        [System.IO.File]::WriteAllBytes($path, $bytes[3..($bytes.Length - 1)])
    }
}

function Remove-BomFromFolder($folder, $extensions) {
    if (-not (Test-Path $folder)) { return }
    Get-ChildItem -Path $folder -Recurse -File | Where-Object { $extensions -contains $_.Extension } | ForEach-Object {
        Remove-Bom $_.FullName
    }
}

# ---------------------------------------------------------------------------
# 0. Verificación de herramientas
# ---------------------------------------------------------------------------
Write-Step "Verificando herramientas necesarias"

function Test-Cmd($name) {
    $null = Get-Command $name -ErrorAction SilentlyContinue
    return $?
}

$hasJava = Test-Cmd "java"
$hasMvn  = Test-Cmd "mvn"
$hasNode = Test-Cmd "node"
$hasNpm  = Test-Cmd "npm"
$hasGit  = Test-Cmd "git"
$hasCurl = Test-Cmd "curl"
$hasPsql = Test-Cmd "psql"

if (-not $hasCurl) { Write-Warn2 "No se encontró 'curl'. Windows 10/11 lo trae integrado; si falla, instálalo." }
if (-not $hasJava)  { Write-Warn2 "No se encontró 'java'. Necesario para correr el backend (JDK 17+)." }
if (-not $hasMvn)   { Write-Warn2 "No se encontró 'mvn' (Maven). Necesario para compilar/correr el backend." }
if (-not $hasNode)  { Write-Warn2 "No se encontró 'node'. Necesario para el frontend Angular." }
if (-not $hasNpm)   { Write-Warn2 "No se encontró 'npm'. Necesario para el frontend Angular." }
if (-not $hasPsql)  { Write-Warn2 "No se encontró 'psql'. No se podrá crear la base de datos automáticamente (necesitas el cliente de PostgreSQL en el PATH)." }
if (-not $hasGit)   { Write-Warn2 "No se encontró 'git'. Se omitirá 'git init'." }

if ($hasJava) { Write-Ok "java detectado" }
if ($hasMvn)  { Write-Ok "maven detectado" }
if ($hasNode) { Write-Ok "node detectado" }

# ---------------------------------------------------------------------------
# 1. Estructura raíz
# ---------------------------------------------------------------------------
Write-Step "Creando estructura del proyecto"

$dirs = @("database", "docs")
foreach ($d in $dirs) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
}
Write-Ok "Carpetas base listas"

# ---------------------------------------------------------------------------
# 2. Backend: Spring Boot vía Spring Initializr
# ---------------------------------------------------------------------------
Write-Step "Backend (Spring Boot)"

$backendDir = Join-Path $root "backend"

if (Test-Path (Join-Path $backendDir "pom.xml")) {
    Write-Ok "backend/ ya existe, se omite la generación"
} else {
    Write-Host "    Generando estructura Maven del backend (sin depender de start.spring.io)..."

    $javaDir = Join-Path $backendDir "src\main\java\com\uagrm\activos"
    $resDir  = Join-Path $backendDir "src\main\resources"
    $testDir = Join-Path $backendDir "src\test\java\com\uagrm\activos"
    New-Item -ItemType Directory -Path $javaDir -Force | Out-Null
    New-Item -ItemType Directory -Path $resDir -Force | Out-Null
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

@'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
	<modelVersion>4.0.0</modelVersion>
	<parent>
		<groupId>org.springframework.boot</groupId>
		<artifactId>spring-boot-starter-parent</artifactId>
		<version>3.3.4</version>
		<relativePath/>
	</parent>
	<groupId>com.uagrm.activos</groupId>
	<artifactId>activos-backend</artifactId>
	<version>0.0.1-SNAPSHOT</version>
	<name>activos-backend</name>
	<description>Sistema de Activos Fijos y Presupuestos - Grupo 7</description>

	<properties>
		<java.version>17</java.version>
	</properties>

	<dependencies>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-web</artifactId>
		</dependency>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-data-jpa</artifactId>
		</dependency>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-security</artifactId>
		</dependency>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-validation</artifactId>
		</dependency>
		<dependency>
			<groupId>org.postgresql</groupId>
			<artifactId>postgresql</artifactId>
			<scope>runtime</scope>
		</dependency>
		<dependency>
			<groupId>org.projectlombok</groupId>
			<artifactId>lombok</artifactId>
			<optional>true</optional>
		</dependency>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-test</artifactId>
			<scope>test</scope>
		</dependency>
		<dependency>
			<groupId>org.springframework.security</groupId>
			<artifactId>spring-security-test</artifactId>
			<scope>test</scope>
		</dependency>
	</dependencies>

	<build>
		<plugins>
			<plugin>
				<groupId>org.springframework.boot</groupId>
				<artifactId>spring-boot-maven-plugin</artifactId>
				<configuration>
					<excludes>
						<exclude>
							<groupId>org.projectlombok</groupId>
							<artifactId>lombok</artifactId>
						</exclude>
					</excludes>
				</configuration>
			</plugin>
		</plugins>
	</build>

</project>
'@ | Set-Content (Join-Path $backendDir "pom.xml") -Encoding UTF8

@'
package com.uagrm.activos;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class ActivosBackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(ActivosBackendApplication.class, args);
    }
}
'@ | Set-Content (Join-Path $javaDir "ActivosBackendApplication.java") -Encoding UTF8

@'
package com.uagrm.activos;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class ActivosBackendApplicationTests {

    @Test
    void contextLoads() {
    }
}
'@ | Set-Content (Join-Path $testDir "ActivosBackendApplicationTests.java") -Encoding UTF8

    Write-Ok "Estructura Maven del backend creada manualmente (pom.xml + clase principal)"
}

$srcMain = Join-Path $backendDir "src\main\java\com\uagrm\activos"
$resourcesDir = Join-Path $backendDir "src\main\resources"

if (Test-Path $srcMain) {

    $pkgDirs = @("model", "repository", "security", "dto", "service", "controller")
    foreach ($p in $pkgDirs) {
        $full = Join-Path $srcMain $p
        if (-not (Test-Path $full)) { New-Item -ItemType Directory -Path $full | Out-Null }
    }

    # --- pom.xml: agregar dependencia JJWT si falta ---
    $pomPath = Join-Path $backendDir "pom.xml"
    if ((Test-Path $pomPath) -and ((Get-Content $pomPath -Raw) -notmatch "jjwt-api")) {
        $jjwt = @'
		<dependency>
			<groupId>io.jsonwebtoken</groupId>
			<artifactId>jjwt-api</artifactId>
			<version>0.12.5</version>
		</dependency>
		<dependency>
			<groupId>io.jsonwebtoken</groupId>
			<artifactId>jjwt-impl</artifactId>
			<version>0.12.5</version>
			<scope>runtime</scope>
		</dependency>
		<dependency>
			<groupId>io.jsonwebtoken</groupId>
			<artifactId>jjwt-jackson</artifactId>
			<version>0.12.5</version>
			<scope>runtime</scope>
		</dependency>
	</dependencies>
'@
        (Get-Content $pomPath -Raw) -replace '\t</dependencies>', $jjwt | Set-Content $pomPath -Encoding UTF8
        Write-Ok "Dependencia JJWT agregada al pom.xml"
    }

    # --- application.properties ---
@'
spring.application.name=activos-backend

spring.datasource.url=jdbc:postgresql://localhost:5432/activos_fijos_db
spring.datasource.username=postgres
spring.datasource.password=postgres

spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect

server.port=8080

# Sprint 1 - HU-01: JWT
app.jwt.secret=CambiarEstaClaveSecretaPorUnaSeguraDeAlMenos256Bits123456
app.jwt.expiration-ms=3600000
app.jwt.max-intentos-fallidos=5
app.jwt.minutos-bloqueo=15
'@ | Set-Content (Join-Path $resourcesDir "application.properties") -Encoding UTF8
    Write-Ok "application.properties configurado"

    # =========================================================
    # MODEL
    # =========================================================
@'
package com.uagrm.activos.model;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "rol")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Rol {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 50)
    private String nombre; // ADMINISTRADOR, ENCARGADO_ACTIVOS, CONTADOR, RESPONSABLE_FINANCIERO
}
'@ | Set-Content (Join-Path $srcMain "model\Rol.java") -Encoding UTF8

@'
package com.uagrm.activos.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "usuario")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Usuario {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String nombre;

    @Column(nullable = false, unique = true, length = 150)
    private String correo; // correo institucional (HU-01)

    @Column(nullable = false)
    private String password; // almacenado con BCrypt

    @ManyToOne(optional = false)
    @JoinColumn(name = "rol_id")
    private Rol rol;

    @Builder.Default
    private Integer intentosFallidos = 0;

    private LocalDateTime bloqueadoHasta; // HU-01: bloqueo temporal tras 5 intentos

    @Builder.Default
    private Boolean activo = true;
}
'@ | Set-Content (Join-Path $srcMain "model\Usuario.java") -Encoding UTF8

@'
package com.uagrm.activos.model;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "categoria")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Categoria {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // HU-02: Mobiliario, Equipos informaticos, Vehiculos, Maquinaria, Inmuebles
    @Column(nullable = false, unique = true, length = 100)
    private String nombre;
}
'@ | Set-Content (Join-Path $srcMain "model\Categoria.java") -Encoding UTF8

@'
package com.uagrm.activos.model;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "ubicacion")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Ubicacion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String nombre; // ej. area/departamento/oficina
}
'@ | Set-Content (Join-Path $srcMain "model\Ubicacion.java") -Encoding UTF8

@'
package com.uagrm.activos.model;

public enum EstadoActivo {
    SIN_ASIGNAR,
    EN_USO,
    MANTENIMIENTO,
    BAJA
}
'@ | Set-Content (Join-Path $srcMain "model\EstadoActivo.java") -Encoding UTF8

@'
package com.uagrm.activos.model;

import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "activo")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Activo {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 30)
    private String codigo; // HU-02: codigo unico generado por el sistema

    @Column(nullable = false, length = 150)
    private String nombre;

    @ManyToOne(optional = false)
    @JoinColumn(name = "categoria_id")
    private Categoria categoria;

    @Column(nullable = false)
    private BigDecimal valor; // HU-02: no puede ser negativo ni cero

    @Column(name = "fecha_adquisicion", nullable = false)
    private LocalDate fechaAdquisicion;

    @Column(length = 150)
    private String proveedor;

    private String observaciones;

    @Enumerated(EnumType.STRING)
    @Builder.Default
    private EstadoActivo estado = EstadoActivo.SIN_ASIGNAR;

    @ManyToOne
    @JoinColumn(name = "responsable_id")
    private Usuario responsable; // HU-03

    @ManyToOne
    @JoinColumn(name = "ubicacion_id")
    private Ubicacion ubicacion; // HU-03
}
'@ | Set-Content (Join-Path $srcMain "model\Activo.java") -Encoding UTF8

@'
package com.uagrm.activos.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "asignacion")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Asignacion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "activo_id")
    private Activo activo;

    @ManyToOne(optional = false)
    @JoinColumn(name = "responsable_id")
    private Usuario responsable;

    @ManyToOne(optional = false)
    @JoinColumn(name = "ubicacion_id")
    private Ubicacion ubicacion;

    @Column(name = "fecha_asignacion", nullable = false)
    private LocalDateTime fechaAsignacion;

    // HU-03: se conserva historial; solo una asignacion "activa" por activo
    @Builder.Default
    private Boolean activa = true;
}
'@ | Set-Content (Join-Path $srcMain "model\Asignacion.java") -Encoding UTF8

    # =========================================================
    # REPOSITORY
    # =========================================================
@'
package com.uagrm.activos.repository;

import com.uagrm.activos.model.Rol;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface RolRepository extends JpaRepository<Rol, Long> {
    Optional<Rol> findByNombre(String nombre);
}
'@ | Set-Content (Join-Path $srcMain "repository\RolRepository.java") -Encoding UTF8

@'
package com.uagrm.activos.repository;

import com.uagrm.activos.model.Usuario;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface UsuarioRepository extends JpaRepository<Usuario, Long> {
    Optional<Usuario> findByCorreo(String correo);
}
'@ | Set-Content (Join-Path $srcMain "repository\UsuarioRepository.java") -Encoding UTF8

@'
package com.uagrm.activos.repository;

import com.uagrm.activos.model.Categoria;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CategoriaRepository extends JpaRepository<Categoria, Long> {
}
'@ | Set-Content (Join-Path $srcMain "repository\CategoriaRepository.java") -Encoding UTF8

@'
package com.uagrm.activos.repository;

import com.uagrm.activos.model.Ubicacion;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UbicacionRepository extends JpaRepository<Ubicacion, Long> {
}
'@ | Set-Content (Join-Path $srcMain "repository\UbicacionRepository.java") -Encoding UTF8

@'
package com.uagrm.activos.repository;

import com.uagrm.activos.model.Activo;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ActivoRepository extends JpaRepository<Activo, Long> {
    boolean existsByCodigo(String codigo);
}
'@ | Set-Content (Join-Path $srcMain "repository\ActivoRepository.java") -Encoding UTF8

@'
package com.uagrm.activos.repository;

import com.uagrm.activos.model.Asignacion;
import com.uagrm.activos.model.Activo;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface AsignacionRepository extends JpaRepository<Asignacion, Long> {
    Optional<Asignacion> findByActivoAndActivaTrue(Activo activo);
    List<Asignacion> findByActivoOrderByFechaAsignacionDesc(Activo activo);
}
'@ | Set-Content (Join-Path $srcMain "repository\AsignacionRepository.java") -Encoding UTF8

    # =========================================================
    # DTO
    # =========================================================
@'
package com.uagrm.activos.dto;

import lombok.*;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor
public class LoginRequest {
    private String correo;
    private String password;
}
'@ | Set-Content (Join-Path $srcMain "dto\LoginRequest.java") -Encoding UTF8

@'
package com.uagrm.activos.dto;

import lombok.*;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class LoginResponse {
    private String token;
    private String nombre;
    private String rol;
}
'@ | Set-Content (Join-Path $srcMain "dto\LoginResponse.java") -Encoding UTF8

@'
package com.uagrm.activos.dto;

import lombok.*;
import java.math.BigDecimal;
import java.time.LocalDate;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ActivoRequest {
    private String nombre;
    private Long categoriaId;
    private BigDecimal valor;
    private LocalDate fechaAdquisicion;
    private String proveedor;
    private String observaciones;
}
'@ | Set-Content (Join-Path $srcMain "dto\ActivoRequest.java") -Encoding UTF8

@'
package com.uagrm.activos.dto;

import lombok.*;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class AsignacionRequest {
    private Long activoId;
    private Long responsableId;
    private Long ubicacionId;
}
'@ | Set-Content (Join-Path $srcMain "dto\AsignacionRequest.java") -Encoding UTF8

    # =========================================================
    # SECURITY (JWT - HU-01)
    # =========================================================
@'
package com.uagrm.activos.security;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

@Component
public class JwtUtil {

    @Value("${app.jwt.secret}")
    private String secret;

    @Value("${app.jwt.expiration-ms}")
    private long expirationMs;

    private SecretKey key() {
        return Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    public String generarToken(String correo, String rol) {
        Date ahora = new Date();
        Date expira = new Date(ahora.getTime() + expirationMs);
        return Jwts.builder()
                .subject(correo)
                .claim("rol", rol)
                .issuedAt(ahora)
                .expiration(expira)
                .signWith(key(), SignatureAlgorithm.HS256)
                .compact();
    }

    public String extraerCorreo(String token) {
        return Jwts.parser().verifyWith(key()).build()
                .parseSignedClaims(token).getPayload().getSubject();
    }

    public boolean esValido(String token) {
        try {
            Jwts.parser().verifyWith(key()).build().parseSignedClaims(token);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
'@ | Set-Content (Join-Path $srcMain "security\JwtUtil.java") -Encoding UTF8

@'
package com.uagrm.activos.security;

import com.uagrm.activos.repository.UsuarioRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;
    private final UsuarioRepository usuarioRepository;

    public JwtAuthFilter(JwtUtil jwtUtil, UsuarioRepository usuarioRepository) {
        this.jwtUtil = jwtUtil;
        this.usuarioRepository = usuarioRepository;
    }

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request,
                                     @NonNull HttpServletResponse response,
                                     @NonNull FilterChain filterChain)
            throws ServletException, IOException {

        String header = request.getHeader("Authorization");

        if (header != null && header.startsWith("Bearer ")) {
            String token = header.substring(7);
            if (jwtUtil.esValido(token)) {
                String correo = jwtUtil.extraerCorreo(token);
                usuarioRepository.findByCorreo(correo).ifPresent(usuario -> {
                    var auth = new UsernamePasswordAuthenticationToken(
                            usuario.getCorreo(), null,
                            List.of(() -> "ROLE_" + usuario.getRol().getNombre()));
                    SecurityContextHolder.getContext().setAuthentication(auth);
                });
            }
        }
        filterChain.doFilter(request, response);
    }
}
'@ | Set-Content (Join-Path $srcMain "security\JwtAuthFilter.java") -Encoding UTF8

@'
package com.uagrm.activos.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;

    public SecurityConfig(JwtAuthFilter jwtAuthFilter) {
        this.jwtAuthFilter = jwtAuthFilter;
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .cors(cors -> cors.configurationSource(corsConfigurationSource()))
            .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/auth/**").permitAll()
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(List.of("http://localhost:4200"));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
'@ | Set-Content (Join-Path $srcMain "security\SecurityConfig.java") -Encoding UTF8

    # =========================================================
    # SERVICE
    # =========================================================
@'
package com.uagrm.activos.service;

import com.uagrm.activos.dto.LoginRequest;
import com.uagrm.activos.dto.LoginResponse;
import com.uagrm.activos.model.Usuario;
import com.uagrm.activos.repository.UsuarioRepository;
import com.uagrm.activos.security.JwtUtil;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.LockedException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

// HU-01: Iniciar sesion en el sistema
@Service
public class AuthService {

    private final UsuarioRepository usuarioRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;

    @Value("${app.jwt.max-intentos-fallidos}")
    private int maxIntentos;

    @Value("${app.jwt.minutos-bloqueo}")
    private int minutosBloqueo;

    public AuthService(UsuarioRepository usuarioRepository, PasswordEncoder passwordEncoder, JwtUtil jwtUtil) {
        this.usuarioRepository = usuarioRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil = jwtUtil;
    }

    public LoginResponse login(LoginRequest request) {
        Usuario usuario = usuarioRepository.findByCorreo(request.getCorreo())
                .orElseThrow(() -> new BadCredentialsException("Credenciales invalidas"));

        if (usuario.getBloqueadoHasta() != null && usuario.getBloqueadoHasta().isAfter(LocalDateTime.now())) {
            throw new LockedException("Cuenta bloqueada temporalmente. Intente mas tarde.");
        }

        if (!passwordEncoder.matches(request.getPassword(), usuario.getPassword())) {
            usuario.setIntentosFallidos(usuario.getIntentosFallidos() + 1);
            if (usuario.getIntentosFallidos() >= maxIntentos) {
                usuario.setBloqueadoHasta(LocalDateTime.now().plusMinutes(minutosBloqueo));
            }
            usuarioRepository.save(usuario);
            throw new BadCredentialsException("Credenciales invalidas");
        }

        usuario.setIntentosFallidos(0);
        usuario.setBloqueadoHasta(null);
        usuarioRepository.save(usuario);

        String token = jwtUtil.generarToken(usuario.getCorreo(), usuario.getRol().getNombre());

        return LoginResponse.builder()
                .token(token)
                .nombre(usuario.getNombre())
                .rol(usuario.getRol().getNombre())
                .build();
    }
}
'@ | Set-Content (Join-Path $srcMain "service\AuthService.java") -Encoding UTF8

@'
package com.uagrm.activos.service;

import com.uagrm.activos.dto.ActivoRequest;
import com.uagrm.activos.model.Activo;
import com.uagrm.activos.model.Categoria;
import com.uagrm.activos.model.EstadoActivo;
import com.uagrm.activos.repository.ActivoRepository;
import com.uagrm.activos.repository.CategoriaRepository;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.Year;
import java.util.List;

// HU-02: Registrar activos fijos por categoria
@Service
public class ActivoService {

    private final ActivoRepository activoRepository;
    private final CategoriaRepository categoriaRepository;

    public ActivoService(ActivoRepository activoRepository, CategoriaRepository categoriaRepository) {
        this.activoRepository = activoRepository;
        this.categoriaRepository = categoriaRepository;
    }

    public List<Activo> listar() {
        return activoRepository.findAll();
    }

    public Activo obtener(Long id) {
        return activoRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Activo no encontrado"));
    }

    public Activo registrar(ActivoRequest req) {
        if (req.getValor() == null || req.getValor().compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("El valor de adquisicion no puede ser negativo ni cero");
        }
        Categoria categoria = categoriaRepository.findById(req.getCategoriaId())
                .orElseThrow(() -> new IllegalArgumentException("Categoria no encontrada"));

        Activo activo = Activo.builder()
                .codigo(generarCodigo())
                .nombre(req.getNombre())
                .categoria(categoria)
                .valor(req.getValor())
                .fechaAdquisicion(req.getFechaAdquisicion())
                .proveedor(req.getProveedor())
                .observaciones(req.getObservaciones())
                .estado(EstadoActivo.SIN_ASIGNAR)
                .build();

        return activoRepository.save(activo);
    }

    public Activo actualizar(Long id, ActivoRequest req) {
        Activo activo = obtener(id);
        if (activo.getResponsable() != null) {
            throw new IllegalStateException("No se puede editar un activo que ya tiene movimientos asociados");
        }
        Categoria categoria = categoriaRepository.findById(req.getCategoriaId())
                .orElseThrow(() -> new IllegalArgumentException("Categoria no encontrada"));

        activo.setNombre(req.getNombre());
        activo.setCategoria(categoria);
        activo.setValor(req.getValor());
        activo.setFechaAdquisicion(req.getFechaAdquisicion());
        activo.setProveedor(req.getProveedor());
        activo.setObservaciones(req.getObservaciones());
        return activoRepository.save(activo);
    }

    private String generarCodigo() {
        String anio = String.valueOf(Year.now().getValue());
        long consecutivo = activoRepository.count() + 1;
        String codigo;
        do {
            codigo = "ACT-" + anio + "-" + String.format("%04d", consecutivo);
            consecutivo++;
        } while (activoRepository.existsByCodigo(codigo));
        return codigo;
    }
}
'@ | Set-Content (Join-Path $srcMain "service\ActivoService.java") -Encoding UTF8

@'
package com.uagrm.activos.service;

import com.uagrm.activos.dto.AsignacionRequest;
import com.uagrm.activos.model.*;
import com.uagrm.activos.repository.*;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

// HU-03: Asignar activos a responsables y ubicaciones
@Service
public class AsignacionService {

    private final AsignacionRepository asignacionRepository;
    private final ActivoRepository activoRepository;
    private final UsuarioRepository usuarioRepository;
    private final UbicacionRepository ubicacionRepository;

    public AsignacionService(AsignacionRepository asignacionRepository,
                              ActivoRepository activoRepository,
                              UsuarioRepository usuarioRepository,
                              UbicacionRepository ubicacionRepository) {
        this.asignacionRepository = asignacionRepository;
        this.activoRepository = activoRepository;
        this.usuarioRepository = usuarioRepository;
        this.ubicacionRepository = ubicacionRepository;
    }

    public List<Asignacion> historial(Long activoId) {
        Activo activo = activoRepository.findById(activoId)
                .orElseThrow(() -> new IllegalArgumentException("Activo no encontrado"));
        return asignacionRepository.findByActivoOrderByFechaAsignacionDesc(activo);
    }

    public Asignacion asignar(AsignacionRequest req) {
        Activo activo = activoRepository.findById(req.getActivoId())
                .orElseThrow(() -> new IllegalArgumentException("Activo no encontrado"));

        if (activo.getEstado() == EstadoActivo.BAJA) {
            throw new IllegalStateException("No se puede asignar un activo dado de baja");
        }

        Usuario responsable = usuarioRepository.findById(req.getResponsableId())
                .orElseThrow(() -> new IllegalArgumentException("Responsable no encontrado"));
        Ubicacion ubicacion = ubicacionRepository.findById(req.getUbicacionId())
                .orElseThrow(() -> new IllegalArgumentException("Ubicacion no encontrada"));

        // Solo un responsable activo a la vez: cierra la asignacion previa (conserva historial)
        asignacionRepository.findByActivoAndActivaTrue(activo).ifPresent(anterior -> {
            anterior.setActiva(false);
            asignacionRepository.save(anterior);
        });

        Asignacion nueva = Asignacion.builder()
                .activo(activo)
                .responsable(responsable)
                .ubicacion(ubicacion)
                .fechaAsignacion(LocalDateTime.now())
                .activa(true)
                .build();
        asignacionRepository.save(nueva);

        activo.setResponsable(responsable);
        activo.setUbicacion(ubicacion);
        activo.setEstado(EstadoActivo.EN_USO);
        activoRepository.save(activo);

        return nueva;
    }
}
'@ | Set-Content (Join-Path $srcMain "service\AsignacionService.java") -Encoding UTF8

    # =========================================================
    # CONTROLLER
    # =========================================================
@'
package com.uagrm.activos.controller;

import com.uagrm.activos.dto.LoginRequest;
import com.uagrm.activos.dto.LoginResponse;
import com.uagrm.activos.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    // HU-01: iniciar sesion con correo institucional y contrasena
    @PostMapping("/login")
    public LoginResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request);
    }
}
'@ | Set-Content (Join-Path $srcMain "controller\AuthController.java") -Encoding UTF8

@'
package com.uagrm.activos.controller;

import com.uagrm.activos.dto.ActivoRequest;
import com.uagrm.activos.model.Activo;
import com.uagrm.activos.service.ActivoService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/activos")
public class ActivoController {

    private final ActivoService activoService;

    public ActivoController(ActivoService activoService) {
        this.activoService = activoService;
    }

    // HU-02: registrar / listar / editar activos fijos por categoria
    @GetMapping
    public List<Activo> listar() {
        return activoService.listar();
    }

    @GetMapping("/{id}")
    public Activo obtener(@PathVariable Long id) {
        return activoService.obtener(id);
    }

    @PostMapping
    public Activo registrar(@Valid @RequestBody ActivoRequest request) {
        return activoService.registrar(request);
    }

    @PutMapping("/{id}")
    public Activo actualizar(@PathVariable Long id, @Valid @RequestBody ActivoRequest request) {
        return activoService.actualizar(id, request);
    }
}
'@ | Set-Content (Join-Path $srcMain "controller\ActivoController.java") -Encoding UTF8

@'
package com.uagrm.activos.controller;

import com.uagrm.activos.dto.AsignacionRequest;
import com.uagrm.activos.model.Asignacion;
import com.uagrm.activos.service.AsignacionService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/asignaciones")
public class AsignacionController {

    private final AsignacionService asignacionService;

    public AsignacionController(AsignacionService asignacionService) {
        this.asignacionService = asignacionService;
    }

    // HU-03: asignar activo a responsable y ubicacion
    @PostMapping
    public Asignacion asignar(@Valid @RequestBody AsignacionRequest request) {
        return asignacionService.asignar(request);
    }

    @GetMapping("/activo/{activoId}")
    public List<Asignacion> historial(@PathVariable Long activoId) {
        return asignacionService.historial(activoId);
    }
}
'@ | Set-Content (Join-Path $srcMain "controller\AsignacionController.java") -Encoding UTF8

    Write-Ok "Codigo fuente del backend generado (model, repository, security, dto, service, controller)"
} else {
    Write-Warn2 "No existe backend/src/main/java/... ; se omite la generacion de codigo Java"
}

# Se ejecuta siempre (backend nuevo o ya existente de una corrida previa) por si
# quedaron archivos con BOM de una version anterior del script.
Remove-BomFromFolder $backendDir @(".java", ".properties", ".xml")
Write-Ok "BOM eliminado de los archivos del backend (si tenian)"

# ---------------------------------------------------------------------------
# 3. Frontend: Angular
# ---------------------------------------------------------------------------
Write-Step "Frontend (Angular)"

$frontendDir = Join-Path $root "frontend"

if (Test-Path (Join-Path $frontendDir "package.json")) {
    Write-Ok "frontend/ ya existe, se omite 'ng new'"
} else {
    if (-not $hasNpm) {
        Write-Warn2 "No se puede crear el frontend sin 'npm'. Saltando frontend."
    } else {
        Write-Host "    Generando proyecto Angular (puede tardar varios minutos)..."
        try {
            npx --yes -p @angular/cli@18 ng new frontend --routing --style=scss --skip-git --defaults
            Write-Ok "Proyecto Angular generado en frontend/"
        } catch {
            Write-Warn2 "No se pudo generar el proyecto Angular. $_"
        }
    }
}

$appDir = Join-Path $frontendDir "src\app"

if (Test-Path $appDir) {

    $feDirs = @(
        "core\auth", "core\models",
        "features\login", "features\activos", "features\asignaciones"
    )
    foreach ($d in $feDirs) {
        $full = Join-Path $appDir $d
        if (-not (Test-Path $full)) { New-Item -ItemType Directory -Path $full | Out-Null }
    }

    # environments
    $envDir = Join-Path $frontendDir "src\environments"
    if (-not (Test-Path $envDir)) { New-Item -ItemType Directory -Path $envDir | Out-Null }

@'
export const environment = {
  production: false,
  apiUrl: 'http://localhost:8080/api'
};
'@ | Set-Content (Join-Path $envDir "environment.ts") -Encoding UTF8

    # modelos
@'
export interface Usuario {
  id: number;
  nombre: string;
  correo: string;
  rol: string;
}
'@ | Set-Content (Join-Path $appDir "core\models\usuario.model.ts") -Encoding UTF8

@'
export interface Activo {
  id?: number;
  codigo?: string;
  nombre: string;
  categoriaId: number;
  valor: number;
  fechaAdquisicion: string;
  proveedor?: string;
  observaciones?: string;
  estado?: string;
}
'@ | Set-Content (Join-Path $appDir "core\models\activo.model.ts") -Encoding UTF8

    # auth service (HU-01)
@'
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, tap } from 'rxjs';
import { environment } from '../../../environments/environment';

interface LoginResponse {
  token: string;
  nombre: string;
  rol: string;
}

@Injectable({ providedIn: 'root' })
export class AuthService {

  constructor(private http: HttpClient) {}

  login(correo: string, password: string): Observable<LoginResponse> {
    return this.http
      .post<LoginResponse>(`${environment.apiUrl}/auth/login`, { correo, password })
      .pipe(
        tap((res) => {
          localStorage.setItem('token', res.token);
          localStorage.setItem('rol', res.rol);
          localStorage.setItem('nombre', res.nombre);
        })
      );
  }

  logout(): void {
    localStorage.removeItem('token');
    localStorage.removeItem('rol');
    localStorage.removeItem('nombre');
  }

  getToken(): string | null {
    return localStorage.getItem('token');
  }

  isLoggedIn(): boolean {
    return !!this.getToken();
  }
}
'@ | Set-Content (Join-Path $appDir "core\auth\auth.service.ts") -Encoding UTF8

@'
import { CanActivateFn, Router } from '@angular/router';
import { inject } from '@angular/core';
import { AuthService } from './auth.service';

export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  if (auth.isLoggedIn()) return true;
  router.navigate(['/login']);
  return false;
};
'@ | Set-Content (Join-Path $appDir "core\auth\auth.guard.ts") -Encoding UTF8

@'
import { HttpInterceptorFn } from '@angular/common/http';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const token = localStorage.getItem('token');
  if (token) {
    req = req.clone({ setHeaders: { Authorization: `Bearer ${token}` } });
  }
  return next(req);
};
'@ | Set-Content (Join-Path $appDir "core\auth\auth.interceptor.ts") -Encoding UTF8

    # login component (HU-01)
@'
import { Component } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { AuthService } from '../../core/auth/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './login.component.html',
  styleUrl: './login.component.scss'
})
export class LoginComponent {
  correo = '';
  password = '';
  errorMsg = '';

  constructor(private authService: AuthService, private router: Router) {}

  onSubmit(): void {
    this.errorMsg = '';
    this.authService.login(this.correo, this.password).subscribe({
      next: () => this.router.navigate(['/activos']),
      error: () => (this.errorMsg = 'Credenciales invalidas o cuenta bloqueada')
    });
  }
}
'@ | Set-Content (Join-Path $appDir "features\login\login.component.ts") -Encoding UTF8

@'
<div class="login-container">
  <h2>Iniciar sesion</h2>
  <form (ngSubmit)="onSubmit()">
    <label>Correo institucional</label>
    <input type="email" name="correo" [(ngModel)]="correo" required />

    <label>Contrasena</label>
    <input type="password" name="password" [(ngModel)]="password" required />

    <p class="error" *ngIf="errorMsg">{{ errorMsg }}</p>

    <button type="submit">Ingresar</button>
  </form>
</div>
'@ | Set-Content (Join-Path $appDir "features\login\login.component.html") -Encoding UTF8

@'
.login-container {
  max-width: 360px;
  margin: 80px auto;
  padding: 24px;
  border: 1px solid #ddd;
  border-radius: 8px;

  form {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .error {
    color: #c0392b;
  }

  button {
    margin-top: 12px;
    padding: 8px;
    cursor: pointer;
  }
}
'@ | Set-Content (Join-Path $appDir "features\login\login.component.scss") -Encoding UTF8

    # activo service + componente (HU-02)
@'
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Activo } from '../../core/models/activo.model';

@Injectable({ providedIn: 'root' })
export class ActivoService {
  constructor(private http: HttpClient) {}

  listar(): Observable<Activo[]> {
    return this.http.get<Activo[]>(`${environment.apiUrl}/activos`);
  }

  registrar(activo: Activo): Observable<Activo> {
    return this.http.post<Activo>(`${environment.apiUrl}/activos`, activo);
  }

  actualizar(id: number, activo: Activo): Observable<Activo> {
    return this.http.put<Activo>(`${environment.apiUrl}/activos/${id}`, activo);
  }
}
'@ | Set-Content (Join-Path $appDir "features\activos\activo.service.ts") -Encoding UTF8

@'
import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivoService } from './activo.service';
import { Activo } from '../../core/models/activo.model';

@Component({
  selector: 'app-activos',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './activos.component.html',
  styleUrl: './activos.component.scss'
})
export class ActivosComponent implements OnInit {
  activos: Activo[] = [];

  nuevo: Activo = {
    nombre: '',
    categoriaId: 1,
    valor: 0,
    fechaAdquisicion: ''
  };

  constructor(private activoService: ActivoService) {}

  ngOnInit(): void {
    this.cargar();
  }

  cargar(): void {
    this.activoService.listar().subscribe((data) => (this.activos = data));
  }

  registrar(): void {
    this.activoService.registrar(this.nuevo).subscribe(() => {
      this.nuevo = { nombre: '', categoriaId: 1, valor: 0, fechaAdquisicion: '' };
      this.cargar();
    });
  }
}
'@ | Set-Content (Join-Path $appDir "features\activos\activos.component.ts") -Encoding UTF8

@'
<h2>Activos fijos</h2>

<form (ngSubmit)="registrar()">
  <input placeholder="Nombre" name="nombre" [(ngModel)]="nuevo.nombre" required />
  <input placeholder="ID Categoria" type="number" name="categoriaId" [(ngModel)]="nuevo.categoriaId" required />
  <input placeholder="Valor" type="number" name="valor" [(ngModel)]="nuevo.valor" required />
  <input placeholder="Fecha adquisicion" type="date" name="fechaAdquisicion" [(ngModel)]="nuevo.fechaAdquisicion" required />
  <button type="submit">Registrar</button>
</form>

<table>
  <thead>
    <tr><th>Codigo</th><th>Nombre</th><th>Valor</th><th>Estado</th></tr>
  </thead>
  <tbody>
    <tr *ngFor="let a of activos">
      <td>{{ a.codigo }}</td>
      <td>{{ a.nombre }}</td>
      <td>{{ a.valor }}</td>
      <td>{{ a.estado }}</td>
    </tr>
  </tbody>
</table>
'@ | Set-Content (Join-Path $appDir "features\activos\activos.component.html") -Encoding UTF8

@'
form {
  display: flex;
  gap: 8px;
  margin-bottom: 16px;
}

table {
  width: 100%;
  border-collapse: collapse;
}

th, td {
  border: 1px solid #ddd;
  padding: 6px 10px;
  text-align: left;
}
'@ | Set-Content (Join-Path $appDir "features\activos\activos.component.scss") -Encoding UTF8

    # asignacion service (HU-03)
@'
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface AsignacionRequest {
  activoId: number;
  responsableId: number;
  ubicacionId: number;
}

@Injectable({ providedIn: 'root' })
export class AsignacionService {
  constructor(private http: HttpClient) {}

  asignar(req: AsignacionRequest): Observable<any> {
    return this.http.post(`${environment.apiUrl}/asignaciones`, req);
  }

  historial(activoId: number): Observable<any[]> {
    return this.http.get<any[]>(`${environment.apiUrl}/asignaciones/activo/${activoId}`);
  }
}
'@ | Set-Content (Join-Path $appDir "features\asignaciones\asignacion.service.ts") -Encoding UTF8

    # rutas
@'
import { Routes } from '@angular/router';
import { LoginComponent } from './features/login/login.component';
import { ActivosComponent } from './features/activos/activos.component';
import { authGuard } from './core/auth/auth.guard';

export const routes: Routes = [
  { path: '', redirectTo: 'login', pathMatch: 'full' },
  { path: 'login', component: LoginComponent },
  { path: 'activos', component: ActivosComponent, canActivate: [authGuard] },
  { path: '**', redirectTo: 'login' }
];
'@ | Set-Content (Join-Path $appDir "app.routes.ts") -Encoding UTF8

    # app.config.ts: agrega HttpClient + interceptor si el archivo existe
    $configPath = Join-Path $appDir "app.config.ts"
    if (Test-Path $configPath) {
@'
import { ApplicationConfig, provideZoneChangeDetection } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient, withInterceptors } from '@angular/common/http';

import { routes } from './app.routes';
import { authInterceptor } from './core/auth/auth.interceptor';

export const appConfig: ApplicationConfig = {
  providers: [
    provideZoneChangeDetection({ eventCoalescing: true }),
    provideRouter(routes),
    provideHttpClient(withInterceptors([authInterceptor]))
  ]
};
'@ | Set-Content $configPath -Encoding UTF8
    }

    Write-Ok "Codigo fuente del frontend generado (auth, login, activos, asignaciones)"
} else {
    Write-Warn2 "No existe frontend/src/app ; se omite la generacion de codigo Angular"
}

Remove-BomFromFolder $appDir @(".ts", ".html", ".scss")
Remove-BomFromFolder (Join-Path $frontendDir "src\environments") @(".ts")
Write-Ok "BOM eliminado de los archivos del frontend (si tenian)"

# ---------------------------------------------------------------------------
# 4. Base de datos
# ---------------------------------------------------------------------------
Write-Step "Script de base de datos (PostgreSQL)"

$schemaContent = @'
-- Sistema de Activos Fijos y Presupuestos - Grupo 7
-- Modelo conceptual inicial del Sprint 1 (Usuario, Rol, Activo, Categoria, Ubicacion, Asignacion)
-- Nota: la base de datos "activos_fijos_db" ya se crea desde setup.ps1 antes de correr este script.

CREATE TABLE IF NOT EXISTS rol (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS usuario (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    correo VARCHAR(150) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    rol_id BIGINT NOT NULL REFERENCES rol(id),
    intentos_fallidos INT NOT NULL DEFAULT 0,
    bloqueado_hasta TIMESTAMP NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS categoria (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS ubicacion (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL
);

CREATE TABLE IF NOT EXISTS activo (
    id BIGSERIAL PRIMARY KEY,
    codigo VARCHAR(30) NOT NULL UNIQUE,
    nombre VARCHAR(150) NOT NULL,
    categoria_id BIGINT NOT NULL REFERENCES categoria(id),
    valor NUMERIC(14,2) NOT NULL CHECK (valor > 0),
    fecha_adquisicion DATE NOT NULL,
    proveedor VARCHAR(150),
    observaciones TEXT,
    estado VARCHAR(20) NOT NULL DEFAULT 'SIN_ASIGNAR',
    responsable_id BIGINT REFERENCES usuario(id),
    ubicacion_id BIGINT REFERENCES ubicacion(id)
);

CREATE TABLE IF NOT EXISTS asignacion (
    id BIGSERIAL PRIMARY KEY,
    activo_id BIGINT NOT NULL REFERENCES activo(id),
    responsable_id BIGINT NOT NULL REFERENCES usuario(id),
    ubicacion_id BIGINT NOT NULL REFERENCES ubicacion(id),
    fecha_asignacion TIMESTAMP NOT NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE
);

-- Datos semilla
INSERT INTO rol (nombre) VALUES
    ('ADMINISTRADOR'),
    ('ENCARGADO_ACTIVOS'),
    ('CONTADOR'),
    ('RESPONSABLE_FINANCIERO')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO categoria (nombre) VALUES
    ('Mobiliario'),
    ('Equipos informaticos'),
    ('Vehiculos'),
    ('Maquinaria'),
    ('Inmuebles')
ON CONFLICT (nombre) DO NOTHING;

-- Usuario de prueba (password: "admin123" ya cifrado con BCrypt)
-- Generar el hash real con BCrypt antes de usar en produccion.
-- INSERT INTO usuario (nombre, correo, password, rol_id)
-- VALUES ('Administrador', 'admin@uagrm.edu.bo', '<hash_bcrypt>', 1);
'@
Write-FileNoBom (Join-Path $root "database\schema.sql") $schemaContent

Write-Ok "database/schema.sql generado"

# ---------------------------------------------------------------------------
# 5. Archivos raíz
# ---------------------------------------------------------------------------
Write-Step "Archivos raíz del proyecto"

if (-not (Test-Path (Join-Path $root ".gitignore"))) {
@'
# Backend
backend/target/
backend/.mvn/
*.class

# Frontend
frontend/node_modules/
frontend/dist/
frontend/.angular/

# IDE / SO
.idea/
.vscode/
*.iml
.DS_Store
Thumbs.db
'@ | Set-Content (Join-Path $root ".gitignore") -Encoding UTF8
    Write-Ok ".gitignore creado"
}

if (-not (Test-Path (Join-Path $root "README.md"))) {
@'
# Sistema de Activos Fijos y Presupuestos - Grupo 7 (UAGRM - FICCT)

Proyecto generado automaticamente hasta el alcance del **Sprint 1**
(HU-01 Iniciar sesion, HU-02 Registrar activos por categoria, HU-03 Asignar activos a responsables y ubicaciones).

## Estructura

- `backend/`  -> Spring Boot + PostgreSQL + JWT (puerto 8080)
- `frontend/` -> Angular standalone (puerto 4200)
- `database/schema.sql` -> script de creacion de la base de datos

## Como correr el backend

```
cd backend
mvn spring-boot:run
```

(Si no tenes Maven instalado: instalalo desde https://maven.apache.org/download.cgi
o con `choco install maven` / `winget install Apache.Maven`.)

Antes, crear la base de datos ejecutando `database/schema.sql` en PostgreSQL
y ajustar usuario/clave en `backend/src/main/resources/application.properties`.

## Como correr el frontend

```
cd frontend
npm install
npm start
```

Luego abrir http://localhost:4200
'@ | Set-Content (Join-Path $root "README.md") -Encoding UTF8
    Write-Ok "README.md creado"
}

if ($hasGit -and -not (Test-Path (Join-Path $root ".git"))) {
    git init | Out-Null
    Write-Ok "Repositorio git inicializado"
}

# ---------------------------------------------------------------------------
# 6. Configuración interactiva: base de datos, credenciales y arranque
# ---------------------------------------------------------------------------
Write-Step "Configuración de base de datos"

$dbName = "activos_fijos_db"
$dbUser = Read-Host "Usuario de PostgreSQL [postgres]"
if ([string]::IsNullOrWhiteSpace($dbUser)) { $dbUser = "postgres" }

$dbPassSecure = Read-Host "Contraseña de PostgreSQL para '$dbUser'" -AsSecureString
$dbPassBstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($dbPassSecure)
$dbPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto($dbPassBstr)

$dbHost = Read-Host "Host de PostgreSQL [localhost]"
if ([string]::IsNullOrWhiteSpace($dbHost)) { $dbHost = "localhost" }

$dbPort = Read-Host "Puerto de PostgreSQL [5432]"
if ([string]::IsNullOrWhiteSpace($dbPort)) { $dbPort = "5432" }

$dbCreada = $false

if ($hasPsql) {
    $env:PGPASSWORD = $dbPass
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        # ¿Existe la base? (devuelve "1" si existe)
        $existe = & psql -h $dbHost -p $dbPort -U $dbUser -tAc "SELECT 1 FROM pg_database WHERE datname='$dbName'" postgres 2>&1
        if ($existe -match "1") {
            Write-Ok "La base de datos '$dbName' ya existe"
            $dbCreada = $true
        } else {
            & psql -h $dbHost -p $dbPort -U $dbUser -c "CREATE DATABASE $dbName;" postgres 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "Base de datos '$dbName' creada"
                $dbCreada = $true
            } else {
                Write-Warn2 "No se pudo crear la base de datos (revisa usuario/contraseña/host)"
            }
        }

        if ($dbCreada) {
            & psql -h $dbHost -p $dbPort -U $dbUser -d $dbName -v ON_ERROR_STOP=1 -f (Join-Path $root "database\schema.sql") 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "Tablas y datos semilla aplicados en '$dbName'"
            } else {
                Write-Warn2 "psql se conectó pero hubo errores al aplicar database\schema.sql (revisa el detalle arriba)"
            }
        }
    } catch {
        Write-Warn2 "Error al conectar con PostgreSQL: $_"
    } finally {
        Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
        $ErrorActionPreference = $prevEAP
    }
} else {
    Write-Warn2 "Sin 'psql' en el PATH no se puede crear la base de datos automáticamente."
    Write-Warn2 "Instálalo (viene con PostgreSQL) o ejecutá manualmente database\schema.sql."
}

# --- Actualizar application.properties con las credenciales ingresadas ---
$propsPath = Join-Path $backendDir "src\main\resources\application.properties"
if (Test-Path $propsPath) {
    $jdbcUrl = "jdbc:postgresql://${dbHost}:${dbPort}/${dbName}"
    (Get-Content $propsPath -Raw) `
        -replace 'spring\.datasource\.url=.*', "spring.datasource.url=$jdbcUrl" `
        -replace 'spring\.datasource\.username=.*', "spring.datasource.username=$dbUser" `
        -replace 'spring\.datasource\.password=.*', "spring.datasource.password=$dbPass" |
        Set-Content $propsPath -Encoding UTF8
    Write-Ok "application.properties actualizado con las credenciales ingresadas"
} else {
    Write-Warn2 "No se encontró application.properties para actualizar (¿el backend no se generó?)"
}

# ---------------------------------------------------------------------------
# 7. Instalación de dependencias y arranque opcional
# ---------------------------------------------------------------------------
Write-Step "Dependencias e inicio de los servidores"

if ((Test-Path (Join-Path $frontendDir "package.json")) -and -not (Test-Path (Join-Path $frontendDir "node_modules"))) {
    if ($hasNpm) {
        Write-Host "    Instalando dependencias del frontend (npm install)..."
        Push-Location $frontendDir
        npm install
        Pop-Location
        Write-Ok "Dependencias del frontend instaladas"
    }
}

$iniciarBackend = Read-Host "¿Querés iniciar el backend ahora con 'mvn spring-boot:run'? (S/N) [N]"
if ($iniciarBackend -match '^[SsYy]') {
    if ($hasMvn -and (Test-Path (Join-Path $backendDir "pom.xml"))) {
        Write-Host "    Abriendo el backend en una nueva ventana..."
        Start-Process cmd.exe -ArgumentList "/k", "cd /d `"$backendDir`" && mvn spring-boot:run"
    } else {
        Write-Warn2 "No se puede iniciar el backend (falta Maven o backend/pom.xml)"
    }
}

$iniciarFrontend = Read-Host "¿Querés iniciar el frontend ahora con 'npm start'? (S/N) [N]"
if ($iniciarFrontend -match '^[SsYy]') {
    if ($hasNpm -and (Test-Path (Join-Path $frontendDir "package.json"))) {
        Write-Host "    Abriendo el frontend en una nueva ventana..."
        Start-Process cmd.exe -ArgumentList "/k", "cd /d `"$frontendDir`" && npm start"
    } else {
        Write-Warn2 "No se puede iniciar el frontend (falta npm o frontend/package.json)"
    }
}

Write-Host ""
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " Proyecto generado y configurado (alcance Sprint 1)"  -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " Backend:  http://localhost:8080"
Write-Host " Frontend: http://localhost:4200"
Write-Host " Si no iniciaste los servidores recién, podés hacerlo con:"
Write-Host "   cd backend  ; mvn spring-boot:run"
Write-Host "   cd frontend ; npm start"
Write-Host ""

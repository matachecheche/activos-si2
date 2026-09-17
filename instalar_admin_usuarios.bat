@echo off
setlocal EnableExtensions

set "PSFILE=%TEMP%\activos_si2_admin_usuarios.ps1"

> "%PSFILE%" (
  echo $ErrorActionPreference = "Stop"
  echo $root = (Get-Location).Path
  echo if (-not (Test-Path (Join-Path $root "backend"))) { throw "No se encontro la carpeta backend. Ejecuta este BAT desde la raiz del repositorio." }
  echo if (-not (Test-Path (Join-Path $root "frontend"))) { throw "No se encontro la carpeta frontend. Ejecuta este BAT desde la raiz del repositorio." }
  echo $javaRoot = Join-Path $root "backend\src\main\java\com\uagrm\activos"
  echo $frontendApp = Join-Path $root "frontend\src\app"
  echo $backupRoot = Join-Path $root (".backup_admin_usuarios_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
  echo function Backup-File { param([string]$Path) if (Test-Path $Path) { $relative = $Path.Substring($root.Length).TrimStart('\'); $dest = Join-Path $backupRoot $relative; $dir = Split-Path $dest -Parent; New-Item -ItemType Directory -Force -Path $dir ^| Out-Null; Copy-Item $Path $dest -Force } }
  echo function Write-ProjectFile { param([string]$Path,[string]$Content) Backup-File $Path; $dir = Split-Path $Path -Parent; New-Item -ItemType Directory -Force -Path $dir ^| Out-Null; $utf8NoBom = New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom) }
  echo function Patch-File { param([string]$Path,[string]$Old,[string]$New) if (-not (Test-Path $Path)) { throw "No se encontro: $Path" }; $content = Get-Content -Raw -LiteralPath $Path; if ($content.Contains($New)) { return }; if (-not $content.Contains($Old)) { throw "No se encontro el texto esperado en: $Path" }; Backup-File $Path; $content = $content.Replace($Old,$New); $utf8NoBom = New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($Path, $content, $utf8NoBom) }
  echo New-Item -ItemType Directory -Force -Path $backupRoot ^| Out-Null
  echo Write-ProjectFile (Join-Path $javaRoot "dto\UsuarioRequest.java") @'
  echo package com.uagrm.activos.dto;
  echo 
  echo import jakarta.validation.constraints.Email;
  echo import jakarta.validation.constraints.NotBlank;
  echo import lombok.*;
  echo 
  echo @Getter
  echo @Setter
  echo @NoArgsConstructor
  echo @AllArgsConstructor
  echo @Builder
  echo public class UsuarioRequest {
  echo 
  echo     @NotBlank
  echo     private String nombre;
  echo 
  echo     @NotBlank
  echo     @Email
  echo     private String correo;
  echo 
  echo     private String password;
  echo 
  echo     @NotBlank
  echo     private String rol;
  echo 
  echo     private Boolean activo;
  echo }
  echo '@
  echo Write-ProjectFile (Join-Path $javaRoot "dto\UsuarioResponse.java") @'
  echo package com.uagrm.activos.dto;
  echo 
  echo import lombok.*;
  echo 
  echo @Getter
  echo @Setter
  echo @NoArgsConstructor
  echo @AllArgsConstructor
  echo @Builder
  echo public class UsuarioResponse {
  echo     private Long id;
  echo     private String nombre;
  echo     private String correo;
  echo     private String rol;
  echo     private Boolean activo;
  echo }
  echo '@
  echo Write-ProjectFile (Join-Path $javaRoot "service\UsuarioService.java") @'
  echo package com.uagrm.activos.service;
  echo 
  echo import com.uagrm.activos.dto.UsuarioRequest;
  echo import com.uagrm.activos.dto.UsuarioResponse;
  echo import com.uagrm.activos.model.Rol;
  echo import com.uagrm.activos.model.Usuario;
  echo import com.uagrm.activos.repository.RolRepository;
  echo import com.uagrm.activos.repository.UsuarioRepository;
  echo import org.springframework.http.HttpStatus;
  echo import org.springframework.security.crypto.password.PasswordEncoder;
  echo import org.springframework.stereotype.Service;
  echo import org.springframework.transaction.annotation.Transactional;
  echo import org.springframework.web.server.ResponseStatusException;
  echo 
  echo import java.util.List;
  echo 
  echo @Service
  echo @Transactional
  echo public class UsuarioService {
  echo 
  echo     private final UsuarioRepository usuarioRepository;
  echo     private final RolRepository rolRepository;
  echo     private final PasswordEncoder passwordEncoder;
  echo 
  echo     public UsuarioService(UsuarioRepository usuarioRepository, RolRepository rolRepository, PasswordEncoder passwordEncoder) {
  echo         this.usuarioRepository = usuarioRepository;
  echo         this.rolRepository = rolRepository;
  echo         this.passwordEncoder = passwordEncoder;
  echo     }
  echo 
  echo     @Transactional(readOnly = true)
  echo     public List<UsuarioResponse> listar() {
  echo         return usuarioRepository.findAll().stream().map(this::toResponse).toList();
  echo     }
  echo 
  echo     public UsuarioResponse crear(UsuarioRequest request) {
  echo         if (request.getPassword() == null || request.getPassword().isBlank()) {
  echo             throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La contraseña es obligatoria al crear un usuario");
  echo         }
  echo         if (usuarioRepository.findByCorreo(request.getCorreo()).isPresent()) {
  echo             throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe un usuario con ese correo");
  echo         }
  echo         Rol rol = buscarRol(request.getRol());
  echo         Usuario usuario = Usuario.builder()
  echo                 .nombre(request.getNombre().trim())
  echo                 .correo(request.getCorreo().trim().toLowerCase())
  echo                 .password(passwordEncoder.encode(request.getPassword()))
  echo                 .rol(rol)
  echo                 .intentosFallidos(0)
  echo                 .bloqueadoHasta(null)
  echo                 .activo(request.getActivo() == null || request.getActivo())
  echo                 .build();
  echo         return toResponse(usuarioRepository.save(usuario));
  echo     }
  echo 
  echo     public UsuarioResponse actualizar(Long id, UsuarioRequest request) {
  echo         Usuario usuario = obtener(id);
  echo         usuarioRepository.findByCorreo(request.getCorreo())
  echo             .filter(otro -> !otro.getId().equals(id))
  echo             .ifPresent(otro -> { throw new ResponseStatusException(HttpStatus.CONFLICT, "Ya existe otro usuario con ese correo"); });
  echo         usuario.setNombre(request.getNombre().trim());
  echo         usuario.setCorreo(request.getCorreo().trim().toLowerCase());
  echo         usuario.setRol(buscarRol(request.getRol()));
  echo         if (request.getPassword() != null && !request.getPassword().isBlank()) {
  echo             usuario.setPassword(passwordEncoder.encode(request.getPassword()));
  echo             usuario.setIntentosFallidos(0);
  echo             usuario.setBloqueadoHasta(null);
  echo         }
  echo         if (request.getActivo() != null) {
  echo             validarNoEliminarUltimoAdministrador(usuario, request.getActivo());
  echo             usuario.setActivo(request.getActivo());
  echo         }
  echo         return toResponse(usuarioRepository.save(usuario));
  echo     }
  echo 
  echo     public void eliminar(Long id) {
  echo         Usuario usuario = obtener(id);
  echo         validarNoEliminarUltimoAdministrador(usuario, false);
  echo         usuario.setActivo(false);
  echo         usuarioRepository.save(usuario);
  echo     }
  echo 
  echo     private Usuario obtener(Long id) {
  echo         return usuarioRepository.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Usuario no encontrado"));
  echo     }
  echo 
  echo     private Rol buscarRol(String nombre) {
  echo         return rolRepository.findAll().stream()
  echo                 .filter(rol -> rol.getNombre().equalsIgnoreCase(nombre))
  echo                 .findFirst()
  echo                 .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "El rol no existe: " + nombre));
  echo     }
  echo 
  echo     private void validarNoEliminarUltimoAdministrador(Usuario usuario, Boolean nuevoEstadoActivo) {
  echo         boolean esAdministrador = usuario.getRol() != null && "ADMINISTRADOR".equalsIgnoreCase(usuario.getRol().getNombre());
  echo         if (!esAdministrador || Boolean.TRUE.equals(nuevoEstadoActivo)) return;
  echo         long administradoresActivos = usuarioRepository.findAll().stream()
  echo                 .filter(u -> Boolean.TRUE.equals(u.getActivo()))
  echo                 .filter(u -> u.getRol() != null)
  echo                 .filter(u -> "ADMINISTRADOR".equalsIgnoreCase(u.getRol().getNombre()))
  echo                 .count();
  echo         if (administradoresActivos <= 1) {
  echo             throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "No se puede dejar el sistema sin un administrador activo");
  echo         }
  echo     }
  echo 
  echo     private UsuarioResponse toResponse(Usuario usuario) {
  echo         return UsuarioResponse.builder()
  echo                 .id(usuario.getId())
  echo                 .nombre(usuario.getNombre())
  echo                 .correo(usuario.getCorreo())
  echo                 .rol(usuario.getRol().getNombre())
  echo                 .activo(usuario.getActivo())
  echo                 .build();
  echo     }
  echo }
  echo '@
  echo Write-ProjectFile (Join-Path $javaRoot "controller\UsuarioController.java") @'
  echo package com.uagrm.activos.controller;
  echo 
  echo import com.uagrm.activos.dto.UsuarioRequest;
  echo import com.uagrm.activos.dto.UsuarioResponse;
  echo import com.uagrm.activos.service.UsuarioService;
  echo import jakarta.validation.Valid;
  echo import org.springframework.http.HttpStatus;
  echo import org.springframework.web.bind.annotation.*;
  echo 
  echo import java.util.List;
  echo 
  echo @RestController
  echo @RequestMapping("/api/usuarios")
  echo public class UsuarioController {
  echo     private final UsuarioService usuarioService;
  echo 
  echo     public UsuarioController(UsuarioService usuarioService) {
  echo         this.usuarioService = usuarioService;
  echo     }
  echo 
  echo     @GetMapping
  echo     public List<UsuarioResponse> listar() {
  echo         return usuarioService.listar();
  echo     }
  echo 
  echo     @PostMapping
  echo     @ResponseStatus(HttpStatus.CREATED)
  echo     public UsuarioResponse crear(@Valid @RequestBody UsuarioRequest request) {
  echo         return usuarioService.crear(request);
  echo     }
  echo 
  echo     @PutMapping("/{id}")
  echo     public UsuarioResponse actualizar(@PathVariable Long id, @Valid @RequestBody UsuarioRequest request) {
  echo         return usuarioService.actualizar(id, request);
  echo     }
  echo 
  echo     @DeleteMapping("/{id}")
  echo     @ResponseStatus(HttpStatus.NO_CONTENT)
  echo     public void eliminar(@PathVariable Long id) {
  echo         usuarioService.eliminar(id);
  echo     }
  echo }
  echo '@
  echo $securityPath = Join-Path $javaRoot "security\SecurityConfig.java"
  echo if (Test-Path $securityPath) {
  echo     $content = Get-Content -Raw -LiteralPath $securityPath
  echo     if ($content.Contains('.requestMatchers("/api/usuarios/**").hasRole("ADMINISTRADOR")')) { } else {
  echo         $old = '.requestMatchers("/api/auth/**").permitAll()'
  echo         $new = '.requestMatchers("/api/auth/**").permitAll()' + [Environment]::NewLine + '                .requestMatchers("/api/usuarios/**").hasRole("ADMINISTRADOR")'
  echo         if ($content.Contains($old)) { Backup-File $securityPath; $content = $content.Replace($old,$new); $utf8NoBom = New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($securityPath, $content, $utf8NoBom) }
  echo     }
  echo }
  echo $authPath = Join-Path $javaRoot "service\AuthService.java"
  echo if (Test-Path $authPath) {
  echo     $content = Get-Content -Raw -LiteralPath $authPath
  echo     if (-not $content.Contains('.filter(Usuario::getActivo)')) {
  echo         $old = 'Usuario usuario = usuarioRepository.findByCorreo(request.getCorreo())'
  echo         $new = 'Usuario usuario = usuarioRepository.findByCorreo(request.getCorreo())' + [Environment]::NewLine + '                .filter(Usuario::getActivo)'
  echo         if ($content.Contains($old)) { Backup-File $authPath; $content = $content.Replace($old,$new); $utf8NoBom = New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($authPath, $content, $utf8NoBom) }
  echo     }
  echo }
  echo Write-ProjectFile (Join-Path $frontendApp "core\models\usuario.model.ts") @'
  echo export interface Usuario {
  echo   id: number;
  echo   nombre: string;
  echo   correo: string;
  echo   rol: string;
  echo   activo: boolean;
  echo }
  echo '@
  echo Write-ProjectFile (Join-Path $frontendApp "features\usuarios\usuario.service.ts") @'
  echo import { Injectable } from '@angular/core';
  echo import { HttpClient } from '@angular/common/http';
  echo import { Observable } from 'rxjs';
  echo import { environment } from '../../environments/environment';
  echo import { Usuario } from '../../core/models/usuario.model';
  echo 
  echo export interface UsuarioRequest {
  echo   nombre: string;
  echo   correo: string;
  echo   password?: string;
  echo   rol: string;
  echo   activo: boolean;
  echo }
  echo 
  echo @Injectable({ providedIn: 'root' })
  echo export class UsuarioService {
  echo   private readonly url = `${environment.apiUrl}/usuarios`;
  echo 
  echo   constructor(private http: HttpClient) {}
  echo 
  echo   listar(): Observable<Usuario[]> { return this.http.get<Usuario[]>(this.url); }
  echo   crear(request: UsuarioRequest): Observable<Usuario> { return this.http.post<Usuario>(this.url, request); }
  echo   actualizar(id: number, request: UsuarioRequest): Observable<Usuario> { return this.http.put<Usuario>(`${this.url}/${id}`, request); }
  echo   eliminar(id: number): Observable<void> { return this.http.delete<void>(`${this.url}/${id}`); }
  echo }
  echo '@
  echo Write-ProjectFile (Join-Path $frontendApp "features\usuarios\usuarios.component.ts") @'
  echo import { Component, OnInit } from '@angular/core';
  echo import { CommonModule } from '@angular/common';
  echo import { FormsModule } from '@angular/forms';
  echo import { UsuarioRequest, UsuarioService } from './usuario.service';
  echo import { Usuario } from '../../core/models/usuario.model';
  echo 
  echo @Component({
  echo   selector: 'app-usuarios',
  echo   standalone: true,
  echo   imports: [CommonModule, FormsModule],
  echo   templateUrl: './usuarios.component.html',
  echo   styleUrl: './usuarios.component.scss'
  echo })
  echo export class UsuariosComponent implements OnInit {
  echo   usuarios: Usuario[] = [];
  echo   editandoId: number | null = null;
  echo   mensaje = '';
  echo   error = '';
  echo   formulario: UsuarioRequest = this.formularioInicial();
  echo   readonly roles = ['ADMINISTRADOR', 'ENCARGADO_ACTIVOS', 'CONTADOR', 'RESPONSABLE_FINANCIERO'];
  echo 
  echo   constructor(private usuarioService: UsuarioService) {}
  echo 
  echo   ngOnInit(): void { this.cargar(); }
  echo 
  echo   cargar(): void { this.usuarioService.listar().subscribe({ next: usuarios => this.usuarios = usuarios, error: () => this.error = 'No se pudieron cargar los usuarios.' }); }
  echo 
  echo   guardar(): void {
  echo     this.mensaje = '';
  echo     this.error = '';
  echo     const request = { ...this.formulario };
  echo     if (this.editandoId === null) {
  echo       if (!request.password) { this.error = 'La contraseña es obligatoria para un usuario nuevo.'; return; }
  echo       this.usuarioService.crear(request).subscribe({
  echo         next: () => { this.mensaje = 'Usuario creado correctamente.'; this.limpiar(); this.cargar(); },
  echo         error: err => this.error = err.error?.message ?? 'No se pudo crear el usuario.'
  echo       });
  echo       return;
  echo     }
  echo     this.usuarioService.actualizar(this.editandoId, request).subscribe({
  echo       next: () => { this.mensaje = 'Usuario actualizado correctamente.'; this.limpiar(); this.cargar(); },
  echo       error: err => this.error = err.error?.message ?? 'No se pudo actualizar el usuario.'
  echo     });
  echo   }
  echo 
  echo   editar(usuario: Usuario): void {
  echo     this.editandoId = usuario.id;
  echo     this.formulario = { nombre: usuario.nombre, correo: usuario.correo, password: '', rol: usuario.rol, activo: usuario.activo };
  echo     this.mensaje = '';
  echo     this.error = '';
  echo   }
  echo 
  echo   eliminar(usuario: Usuario): void {
  echo     if (!confirm(`¿Desactivar a ${usuario.nombre}?`)) return;
  echo     this.usuarioService.eliminar(usuario.id).subscribe({
  echo       next: () => { this.mensaje = 'Usuario desactivado correctamente.'; this.cargar(); },
  echo       error: err => this.error = err.error?.message ?? 'No se pudo desactivar el usuario.'
  echo     });
  echo   }
  echo 
  echo   limpiar(): void { this.editandoId = null; this.formulario = this.formularioInicial(); }
  echo 
  echo   private formularioInicial(): UsuarioRequest {
  echo     return { nombre: '', correo: '', password: '', rol: 'ENCARGADO_ACTIVOS', activo: true };
  echo   }
  echo }
  echo '@
  echo Write-ProjectFile (Join-Path $frontendApp "features\usuarios\usuarios.component.html") @'
  echo <div class="page-header">
  echo   <h2>Administración de usuarios</h2>
  echo </div>
  echo 
  echo <div class="card">
  echo   <h3>{{ editandoId === null ? 'Crear usuario' : 'Editar usuario' }}</h3>
  echo   <form (ngSubmit)="guardar()" class="form-grid">
  echo     <div class="field">
  echo       <label>Nombre</label>
  echo       <input name="nombre" [(ngModel)]="formulario.nombre" required />
  echo     </div>
  echo     <div class="field">
  echo       <label>Correo</label>
  echo       <input type="email" name="correo" [(ngModel)]="formulario.correo" required />
  echo     </div>
  echo     <div class="field">
  echo       <label>Contraseña</label>
  echo       <input type="password" name="password" [(ngModel)]="formulario.password" [required]="editandoId === null" />
  echo     </div>
  echo     <div class="field">
  echo       <label>Rol</label>
  echo       <select name="rol" [(ngModel)]="formulario.rol" required>
  echo         <option *ngFor="let rol of roles" [value]="rol">{{ rol }}</option>
  echo       </select>
  echo     </div>
  echo     <div class="field">
  echo       <label>Estado</label>
  echo       <select name="activo" [(ngModel)]="formulario.activo">
  echo         <option [ngValue]="true">Activo</option>
  echo         <option [ngValue]="false">Inactivo</option>
  echo       </select>
  echo     </div>
  echo     <div class="actions">
  echo       <button type="submit" class="btn-primary">{{ editandoId === null ? 'Crear usuario' : 'Guardar cambios' }}</button>
  echo       <button *ngIf="editandoId !== null" type="button" (click)="limpiar()">Cancelar</button>
  echo     </div>
  echo   </form>
  echo </div>
  echo 
  echo <p class="success" *ngIf="mensaje">{{ mensaje }}</p>
  echo <p class="error" *ngIf="error">{{ error }}</p>
  echo 
  echo <div class="card">
  echo   <table>
  echo     <thead>
  echo       <tr>
  echo         <th>Nombre</th>
  echo         <th>Correo</th>
  echo         <th>Rol</th>
  echo         <th>Estado</th>
  echo         <th>Acciones</th>
  echo       </tr>
  echo     </thead>
  echo     <tbody>
  echo       <tr *ngFor="let usuario of usuarios">
  echo         <td>{{ usuario.nombre }}</td>
  echo         <td>{{ usuario.correo }}</td>
  echo         <td>{{ usuario.rol }}</td>
  echo         <td>{{ usuario.activo ? 'Activo' : 'Inactivo' }}</td>
  echo         <td>
  echo           <button type="button" (click)="editar(usuario)">Editar</button>
  echo           <button type="button" *ngIf="usuario.activo" (click)="eliminar(usuario)">Desactivar</button>
  echo         </td>
  echo       </tr>
  echo       <tr *ngIf="!usuarios.length"><td colspan="5">No hay usuarios registrados.</td></tr>
  echo     </tbody>
  echo   </table>
  echo </div>
  echo '@
  echo Write-ProjectFile (Join-Path $frontendApp "features\usuarios\usuarios.component.scss") @'
  echo .card { margin-bottom: 1rem; }
  echo .success { color: #187a35; }
  echo .error { color: #b42318; }
  echo .actions { display: flex; gap: 0.75rem; align-items: center; }
  echo '@
  echo $authServicePath = Join-Path $frontendApp "core\auth\auth.service.ts"
  echo if (Test-Path $authServicePath) {
  echo   $content = Get-Content -Raw -LiteralPath $authServicePath
  echo   if (-not $content.Contains('esAdministrador')) {
  echo     $old = '  isLoggedIn(): boolean {' + [Environment]::NewLine + '    return !!this.getToken();' + [Environment]::NewLine + '  }'
  echo     $new = '  isLoggedIn(): boolean {' + [Environment]::NewLine + '    return !!this.getToken();' + [Environment]::NewLine + '  }' + [Environment]::NewLine + [Environment]::NewLine + '  esAdministrador(): boolean {' + [Environment]::NewLine + '    return localStorage.getItem("rol") === "ADMINISTRADOR";' + [Environment]::NewLine + '  }'
  echo     if ($content.Contains('  isLoggedIn(): boolean {')) { Backup-File $authServicePath; $content = $content.Replace($old,$new); $utf8NoBom = New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($authServicePath, $content, $utf8NoBom) }
  echo   }
  echo }
  echo $routesPath = Join-Path $frontendApp "app.routes.ts"
  echo if (Test-Path $routesPath) {
  echo   $content = Get-Content -Raw -LiteralPath $routesPath
  echo   if (-not $content.Contains("UsuariosComponent")) {
  echo     $content = $content.Replace("import { authGuard } from './core/auth/auth.guard';", "import { authGuard } from './core/auth/auth.guard';`nimport { UsuariosComponent } from './features/usuarios/usuarios.component';")
  echo     $content = $content.Replace("  { path: 'activos', component: ActivosComponent, canActivate: [authGuard] },", "  { path: 'activos', component: ActivosComponent, canActivate: [authGuard] },`n  { path: 'usuarios', component: UsuariosComponent, canActivate: [authGuard] },")
  echo     Backup-File $routesPath
  echo     $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  echo     [System.IO.File]::WriteAllText($routesPath, $content, $utf8NoBom)
  echo   }
  echo }
  echo $appHtmlPath = Join-Path $frontendApp "app.component.html"
  echo if (Test-Path $appHtmlPath) {
  echo   $content = Get-Content -Raw -LiteralPath $appHtmlPath
  echo   if (-not $content.Contains('routerLink="/usuarios"')) {
  echo     $old = '<a routerLink="/activos">Activos</a>'
  echo     $new = '<a routerLink="/activos">Activos</a>' + [Environment]::NewLine + '    <a *ngIf="authService.esAdministrador()" routerLink="/usuarios">Usuarios</a>'
  echo     if ($content.Contains($old)) { Backup-File $appHtmlPath; $content = $content.Replace($old,$new); $utf8NoBom = New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($appHtmlPath, $content, $utf8NoBom) }
  echo   }
  echo }
  echo Write-Host ""
  echo Write-Host "============================================================"
  echo Write-Host "Instalacion de admin de usuarios completada."
  echo Write-Host "Respaldos: $backupRoot"
  echo Write-Host "Ahora ejecuta:"
  echo Write-Host "  cd backend"
  echo Write-Host "  mvn clean test"
  echo Write-Host "  mvn spring-boot:run"
  echo Write-Host "  cd ..\frontend"
  echo Write-Host "  npm install"
  echo Write-Host "  npm start"
  echo Write-Host "  Ingresa como ADMINISTRADOR y abre /usuarios"
  echo Write-Host "============================================================"
)

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PSFILE%"
set "EXITCODE=%ERRORLEVEL%"

del /f /q "%PSFILE%" 2>nul
exit /b %EXITCODE%
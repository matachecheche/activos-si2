# -*- coding: utf-8 -*-
"""
Aplica, en esta carpeta del proyecto, las correcciones del despliegue:

  1) database/schema.sql  -> las semillas ya no usan "ON CONFLICT (nombre)", asi que
     el esquema se puede aplicar tanto en una base NUEVA como en una base que el
     backend ya migró (multiempresa: la unicidad pasa a ser por empresa). Esto es lo
     que hacia fallar el despliegue con:
        "there is no unique or exclusion constraint matching the ON CONFLICT specification"

  2) desplegar_azure.py   -> lee "pasarelas.env" (ya no hace falta el setx) y
     agrega el flag "--sitio" para desplegar en una web que YA existe.

Uso (Windows o Linux, solo Python 3):

    python aplicar_correcciones_despliegue.py

Es idempotente: si ya esta aplicado, no cambia nada. Antes de tocar nada hace
una copia en .backup_correcciones/<marca-de-tiempo>/.
"""

import datetime
import os
import shutil
import sys

RAIZ = os.path.dirname(os.path.abspath(__file__))
MARCA = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
BACKUP = os.path.join(RAIZ, ".backup_correcciones", MARCA)

CAMBIOS = [
    # (archivo, texto viejo, texto nuevo, descripcion)
    ("database/schema.sql", "-- Datos semilla\nINSERT INTO rol (nombre) VALUES\n    ('ADMINISTRADOR'),\n    ('ENCARGADO_ACTIVOS'),\n    ('CONTADOR'),\n    ('RESPONSABLE_FINANCIERO')\nON CONFLICT (nombre) DO NOTHING;\n\nINSERT INTO categoria (nombre) VALUES\n    ('Mobiliario'),\n    ('Equipos informaticos'),\n    ('Vehiculos'),\n    ('Maquinaria'),\n    ('Inmuebles')\nON CONFLICT (nombre) DO NOTHING;", '-- Datos semilla\n-- Se insertan con "WHERE NOT EXISTS" y no con ON CONFLICT porque este archivo\n-- tiene que funcionar en los DOS casos:\n--   1) base nueva: la tabla se crea aqui con UNIQUE(nombre)\n--   2) base ya migrada por el backend (Sprint 3): la unicidad pasa a ser\n--      UNIQUE(empresa_id, nombre) y "ON CONFLICT (nombre)" ya no valida.\n-- Asi el despliegue en Azure nunca se detiene por esto.\nINSERT INTO rol (nombre)\n    SELECT \'ADMINISTRADOR\' WHERE NOT EXISTS (SELECT 1 FROM rol WHERE nombre = \'ADMINISTRADOR\')\n    UNION ALL SELECT \'ENCARGADO_ACTIVOS\' WHERE NOT EXISTS (SELECT 1 FROM rol WHERE nombre = \'ENCARGADO_ACTIVOS\')\n    UNION ALL SELECT \'CONTADOR\' WHERE NOT EXISTS (SELECT 1 FROM rol WHERE nombre = \'CONTADOR\')\n    UNION ALL SELECT \'RESPONSABLE_FINANCIERO\' WHERE NOT EXISTS (SELECT 1 FROM rol WHERE nombre = \'RESPONSABLE_FINANCIERO\');\n\nINSERT INTO categoria (nombre)\n    SELECT \'Mobiliario\' WHERE NOT EXISTS (SELECT 1 FROM categoria WHERE nombre = \'Mobiliario\')\n    UNION ALL SELECT \'Equipos informaticos\' WHERE NOT EXISTS (SELECT 1 FROM categoria WHERE nombre = \'Equipos informaticos\')\n    UNION ALL SELECT \'Vehiculos\' WHERE NOT EXISTS (SELECT 1 FROM categoria WHERE nombre = \'Vehiculos\')\n    UNION ALL SELECT \'Maquinaria\' WHERE NOT EXISTS (SELECT 1 FROM categoria WHERE nombre = \'Maquinaria\')\n    UNION ALL SELECT \'Inmuebles\' WHERE NOT EXISTS (SELECT 1 FROM categoria WHERE nombre = \'Inmuebles\');\n',
     "schema.sql: semillas sin ON CONFLICT (nombre)"),
    ("database/schema.sql", "INSERT INTO permiso (modulo, accion, descripcion) VALUES\n    ('ACTIVOS', 'LEER', 'Consultar activos registrados'), ('ACTIVOS', 'CREAR', 'Registrar activos nuevos'), ('ACTIVOS', 'EDITAR', 'Modificar datos de activos'), ('ACTIVOS', 'ELIMINAR', 'Dar de baja activos'),\n    ('PRESUPUESTO', 'LEER', 'Consultar presupuestos'), ('PRESUPUESTO', 'CREAR', 'Registrar presupuesto anual'), ('PRESUPUESTO', 'EDITAR', 'Modificar presupuesto'), ('PRESUPUESTO', 'ELIMINAR', 'Eliminar presupuesto'),\n    ('REPORTES', 'LEER', 'Consultar reportes y estadisticas'), ('USUARIOS', 'LEER', 'Consultar usuarios'), ('USUARIOS', 'CREAR', 'Crear usuarios'), ('USUARIOS', 'EDITAR', 'Modificar usuarios'), ('USUARIOS', 'ELIMINAR', 'Desactivar usuarios')\nON CONFLICT (modulo, accion) DO NOTHING;", "INSERT INTO permiso (modulo, accion, descripcion)\n    SELECT 'ACTIVOS', 'LEER', 'Consultar activos registrados' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'ACTIVOS' AND accion = 'LEER')\n    UNION ALL SELECT 'ACTIVOS', 'CREAR', 'Registrar activos nuevos' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'ACTIVOS' AND accion = 'CREAR')\n    UNION ALL SELECT 'ACTIVOS', 'EDITAR', 'Modificar datos de activos' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'ACTIVOS' AND accion = 'EDITAR')\n    UNION ALL SELECT 'ACTIVOS', 'ELIMINAR', 'Dar de baja activos' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'ACTIVOS' AND accion = 'ELIMINAR')\n    UNION ALL SELECT 'PRESUPUESTO', 'LEER', 'Consultar presupuestos' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'PRESUPUESTO' AND accion = 'LEER')\n    UNION ALL SELECT 'PRESUPUESTO', 'CREAR', 'Registrar presupuesto anual' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'PRESUPUESTO' AND accion = 'CREAR')\n    UNION ALL SELECT 'PRESUPUESTO', 'EDITAR', 'Modificar presupuesto' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'PRESUPUESTO' AND accion = 'EDITAR')\n    UNION ALL SELECT 'PRESUPUESTO', 'ELIMINAR', 'Eliminar presupuesto' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'PRESUPUESTO' AND accion = 'ELIMINAR')\n    UNION ALL SELECT 'REPORTES', 'LEER', 'Consultar reportes y estadisticas' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'REPORTES' AND accion = 'LEER')\n    UNION ALL SELECT 'USUARIOS', 'LEER', 'Consultar usuarios' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'USUARIOS' AND accion = 'LEER')\n    UNION ALL SELECT 'USUARIOS', 'CREAR', 'Crear usuarios' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'USUARIOS' AND accion = 'CREAR')\n    UNION ALL SELECT 'USUARIOS', 'EDITAR', 'Modificar usuarios' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'USUARIOS' AND accion = 'EDITAR')\n    UNION ALL SELECT 'USUARIOS', 'ELIMINAR', 'Desactivar usuarios' WHERE NOT EXISTS (SELECT 1 FROM permiso WHERE modulo = 'USUARIOS' AND accion = 'ELIMINAR');\n",
     "schema.sql: permisos sin ON CONFLICT (modulo, accion)"),
    ("desplegar_azure.py", 'def ajustes_pagos():\n    """\n    Variables de entorno de la pasarela de pagos REAL.\n\n    Se leen del entorno de Windows (MERCADOPAGO_ACCESS_TOKEN, PAYPAL_CLIENT_ID,\n    PAYPAL_CLIENT_SECRET, MERCADOPAGO_WEBHOOK_SECRET, APP_PAGOS_PROVEEDOR...). Si\n    no hay ninguna, el backend queda en modo "sin pasarela": avisa con claridad y\n    NO simula los pagos.\n    """\n    ajustes = []\n    proveedor = (os.environ.get("APP_PAGOS_PROVEEDOR") or "").strip()\n    if proveedor:\n        ajustes.append("APP_PAGOS_PROVEEDOR=%s" % proveedor)\n    for nombre in ("MERCADOPAGO_ACCESS_TOKEN", "MERCADOPAGO_WEBHOOK_SECRET",\n                   "PAYPAL_CLIENT_ID", "PAYPAL_CLIENT_SECRET", "PAYPAL_AMBIENTE",\n                   "STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET", "STRIPE_MONEDA",\n                   "STRIPE_FACTOR_CONVERSION",\n                   "APP_PAGOS_QR_CLIENT_ID", "APP_PAGOS_QR_CLIENT_SECRET",\n                   "APP_PAGOS_QR_BASE_URL", "APP_PAGOS_QR_ID_ESTABLECIMIENTO",\n                   "APP_PAGOS_QR_NOMBRE_ESTABLECIMIENTO", "APP_PAGOS_QR_VIGENCIA",\n                   "APP_PAGOS_QR_WEBHOOK_KEY", "APP_PAGOS_QR_WEBHOOK_VALUE",\n                   "APP_PAGOS_MONEDA", "APP_PAGOS_FACTOR_CONVERSION"):\n        valor = (os.environ.get(nombre) or "").strip()\n        if valor:\n            ajustes.append("%s=%s" % (nombre, valor))\n    if os.environ.get("APP_PAGOS_SANDBOX", "").strip().lower() in ("1", "true", "si", "yes"):\n        ajustes.append("APP_PAGOS_SANDBOX=true")\n    return ajustes', 'def leer_pasarelas_env():\n    """\n    Lee pasarelas.env (el archivo que escribe configurar_pasarelas.py).\n\n    Es el mismo archivo que lee el backend al arrancar, asi que la pasarela\n    que funciona en local funciona tambien en Azure sin tener que hacer\n    \'setx\' ni reiniciar la terminal. Prioridad: variable de entorno de Windows\n    > archivo pasarelas.env.\n    """\n    datos = {}\n    for carpeta in (RAIZ_PROYECTO, os.path.dirname(RAIZ_PROYECTO)):\n        ruta = os.path.join(carpeta, "pasarelas.env")\n        if not os.path.isfile(ruta):\n            continue\n        try:\n            with open(ruta, encoding="utf-8") as f:\n                for linea in f:\n                    linea = linea.strip()\n                    if not linea or linea.startswith("#") or "=" not in linea:\n                        continue\n                    clave, valor = linea.split("=", 1)\n                    clave = clave.strip()\n                    valor = valor.strip().strip(\'"\').strip("\'")\n                    if clave and valor:\n                        datos[clave] = valor\n        except Exception:\n            continue\n    return datos\n\n\ndef ajustes_pagos():\n    """\n    Variables de entorno de la pasarela de pagos REAL.\n\n    Se leen del archivo pasarelas.env y del entorno de Windows\n    (MERCADOPAGO_ACCESS_TOKEN, PAYPAL_CLIENT_ID, PAYPAL_CLIENT_SECRET,\n    MERCADOPAGO_WEBHOOK_SECRET, APP_PAGOS_PROVEEDOR...). Si no hay ninguna,\n    el backend queda en modo "sin pasarela": avisa con claridad y NO simula los\n    pagos.\n    """\n    archivo = leer_pasarelas_env()\n    ajustes = []\n\n    def valor_de(nombre):\n        # El entorno de Windows manda; el archivo es el respaldo (asi funciona\n        # sin tener que cerrar y abrir la terminal despues del \'setx\').\n        return (os.environ.get(nombre) or archivo.get(nombre) or "").strip()\n\n    proveedor = valor_de("APP_PAGOS_PROVEEDOR")\n    if proveedor:\n        ajustes.append("APP_PAGOS_PROVEEDOR=%s" % proveedor)\n    for nombre in ("MERCADOPAGO_ACCESS_TOKEN", "MERCADOPAGO_WEBHOOK_SECRET",\n                   "PAYPAL_CLIENT_ID", "PAYPAL_CLIENT_SECRET", "PAYPAL_AMBIENTE",\n                   "STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET", "STRIPE_MONEDA",\n                   "STRIPE_FACTOR_CONVERSION",\n                   "APP_PAGOS_QR_CLIENT_ID", "APP_PAGOS_QR_CLIENT_SECRET",\n                   "APP_PAGOS_QR_BASE_URL", "APP_PAGOS_QR_ID_ESTABLECIMIENTO",\n                   "APP_PAGOS_QR_NOMBRE_ESTABLECIMIENTO", "APP_PAGOS_QR_VIGENCIA",\n                   "APP_PAGOS_QR_WEBHOOK_KEY", "APP_PAGOS_QR_WEBHOOK_VALUE",\n                   "APP_PAGOS_MONEDA", "APP_PAGOS_FACTOR_CONVERSION"):\n        valor = valor_de(nombre)\n        if valor:\n            ajustes.append("%s=%s" % (nombre, valor))\n    sandbox = valor_de("APP_PAGOS_SANDBOX")\n    if sandbox:\n        # Se copia tal cual (incluido "false"): queda explicito en App Service\n        # que la pasarela NO esta en modo demostracion.\n        ajustes.append("APP_PAGOS_SANDBOX=%s"\n                       % ("true" if sandbox.lower() in ("1", "true", "si", "yes") else "false"))\n    return ajustes\n',
     "desplegar_azure.py: leer pasarelas.env"),
    ("desplegar_azure.py", '    parser.add_argument("--perfil", default=PERFIL_DEFECTO,\n                        help="carpeta de perfil aislada de este despliegue (defecto: %s). "\n                             "Cada perfil genera su propia web Azure y su propia Neon con sufijo propio."\n                             % PERFIL_DEFECTO)\n', '    parser.add_argument("--sitio", metavar="NOMBRE",\n                        help="despliega en una aplicacion web que YA existe (por ejemplo "\n                             "waf-activosfijos-cpejk6): reutiliza su grupo de recursos, su "\n                             "plan y su URL, en vez de crear una web nueva.")\n    parser.add_argument("--perfil", default=PERFIL_DEFECTO,\n                        help="carpeta de perfil aislada de este despliegue (defecto: %s). "\n                             "Cada perfil genera su propia web Azure y su propia Neon con sufijo propio."\n                             % PERFIL_DEFECTO)\n',
     "desplegar_azure.py: flag --sitio"),
    ("desplegar_azure.py", '\n\ndef construir_config(region, tipo_bd=TIPO_BD_NEON):', '\n\ndef adoptar_sitio_existente(cfg, nombre):\n    """\n    Reutiliza una aplicacion web que YA existe en Azure (por ejemplo\n    "waf-activosfijos-cpejk6"): lee su grupo de recursos, su plan y su URL,\n    los guarda en la configuracion del perfil y devuelve la config.\n\n    Con esto el despliegue actualiza la web que ya tenes (misma URL, misma\n    Neon) en vez de crear una nueva con otro sufijo.\n    """\n    info("Buscando la aplicacion web existente \'%s\'..." % nombre)\n    codigo, salida = capturar([*az_cmd(), "webapp", "show", "-n", nombre,\n                                "--query", "{rg:resourceGroup,host:defaultHostName,"\n                                "plan:serverFarmId,estado:state}",\n                                "--only-show-errors"])\n    if codigo != 0:\n        fatal("No existe la aplicacion web \'%s\' en tu suscripcion. "\n              "Revisa el nombre o desplega sin --sitio para crear una nueva." % nombre)\n    datos = json_tolerante(salida) or {}\n    if not isinstance(datos, dict) or not datos.get("rg"):\n        fatal("No pude leer los datos de la aplicacion web \'%s\'." % nombre)\n    cfg["webapp"] = nombre\n    cfg["resource_group"] = datos.get("rg")\n    plan = (datos.get("plan") or "").rstrip("/").split("/")[-1]\n    if plan:\n        cfg["app_service_plan"] = plan\n    host = datos.get("host") or (nombre + ".azurewebsites.net")\n    cfg["webapp_url"] = "https://%s" % host\n    cfg["reutilizar_sitio"] = True\n    guardar_config(cfg)\n    ok("Se va a actualizar la web existente: %s" % cfg["webapp_url"])\n    info("Grupo de recursos: %s | Plan: %s" % (cfg["resource_group"], cfg.get("app_service_plan")))\n    return cfg\n\n\ndef construir_config(region, tipo_bd=TIPO_BD_NEON):',
     "desplegar_azure.py: adoptar sitio existente"),
    ("desplegar_azure.py", 'def flujo_completo(args):\n    java_local = comprobar_requisitos()\n    actualizar_gitignore()\n    cfg = construir_config(args.region, args.bd)\n', 'def flujo_completo(args):\n    java_local = comprobar_requisitos()\n    actualizar_gitignore()\n    cfg = construir_config(args.region, args.bd)\n    if getattr(args, "sitio", None):\n        asegurar_login()\n        cfg = adoptar_sitio_existente(cfg, args.sitio)\n',
     "desplegar_azure.py: usar el sitio existente en el flujo completo"),
    ("desplegar_azure.py", 'def flujo_solo_app(args):\n    java_local = comprobar_requisitos()\n    actualizar_gitignore()\n    cfg = cargar_config()\n    if not cfg:\n        fatal("Aun no existe un despliegue (no encontre %s). Ejecuta primero el despliegue completo."\n              % ARCHIVO_CONFIG)\n    asegurar_login()', 'def flujo_solo_app(args):\n    java_local = comprobar_requisitos()\n    actualizar_gitignore()\n    cfg = cargar_config()\n    if not cfg and not getattr(args, "sitio", None):\n        fatal("Aun no existe un despliegue (no encontre %s). Ejecuta primero el despliegue completo."\n              % ARCHIVO_CONFIG)\n    asegurar_login()\n    if getattr(args, "sitio", None):\n        cfg = cfg or {}\n        cfg = adoptar_sitio_existente(cfg, args.sitio)\n',
     "desplegar_azure.py: --solo-app con --sitio"),
]


def main():
    cambios = 0
    ya_hechos = 0
    for relativo, viejo, nuevo, descripcion in CAMBIOS:
        ruta = os.path.join(RAIZ, *relativo.split("/"))
        if not os.path.isfile(ruta):
            print("  [AVISO] No existe " + relativo + ": se omite.")
            continue
        with open(ruta, "r", encoding="utf-8") as f:
            texto = f.read()
        # Primero se comprueba si ya esta aplicado (el texto viejo puede estar
        # dentro del nuevo: en ese caso se revisaria al reves).
        if nuevo in texto:
            print("  [YA]   " + descripcion + " (ya estaba aplicado)")
            ya_hechos += 1
        elif viejo in texto:
            copia = os.path.join(BACKUP, *relativo.split("/"))
            os.makedirs(os.path.dirname(copia), exist_ok=True)
            shutil.copy2(ruta, copia)
            texto = texto.replace(viejo, nuevo, 1)
            with open(ruta, "w", encoding="utf-8", newline="") as f:
                f.write(texto)
            print("  [OK]   " + descripcion)
            cambios += 1
        else:
            print("  [AVISO] No encontre el texto esperado de: " + descripcion)
            print("          (puede que tu copia ya sea otra version; revisa a mano)")
    # comprobacion final: el script de despliegue debe seguir siendo Python valido
    ruta_dep = os.path.join(RAIZ, "desplegar_azure.py")
    if os.path.isfile(ruta_dep):
        with open(ruta_dep, "r", encoding="utf-8") as f:
            try:
                compile(f.read(), ruta_dep, "exec")
                print("  [OK]   desplegar_azure.py sigue siendo Python valido")
            except SyntaxError as e:
                print("  [ERROR] desplegar_azure.py quedo con un error de sintaxis: " + str(e))
                print("          Restaura la copia de .backup_correcciones/" + MARCA)
                return 1
    print("")
    print("Cambios aplicados: %d | ya estaban: %d" % (cambios, ya_hechos))
    if cambios:
        print("Copia de lo original: .backup_correcciones/" + MARCA)
    print("")
    print("Siguiente paso:")
    print('  python desplegar_azure.py --sitio waf-activosfijos-cpejk6 --neon-cadena "postgresql://..."')
    return 0


if __name__ == "__main__":
    sys.exit(main())

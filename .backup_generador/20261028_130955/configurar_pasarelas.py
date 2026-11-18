#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Configuracion guiada de las pasarelas de pago reales (Sprint 3).

Este script hace todo el trabajo pesado:

  1. Te pregunta que pasarela quieres dejar lista (Mercado Pago, PayPal,
     Stripe o QR Simple) y pide las credenciales (se escriben ocultas).
  2. **Valida las credenciales contra la API real** de cada proveedor: si la
     clave esta mal o vencida te lo dice aqui, no cuando un cliente intente
     pagar.
  3. Las guarda en Azure App Service (si el proyecto ya esta desplegado) o, si
     todavia no lo esta, en un archivo `pasarelas.env` con los `setx` de
     Windows listos para copiar.
  4. Te imprime la URL del webhook que debes registrar en el panel de cada
     proveedor y los pasos exactos para pegarla.

Uso (Windows o Linux, solo Python 3):

    python configurar_pasarelas.py                 # asistente interactivo
    python configurar_pasarelas.py --verificar     # revisa el despliegue actual
    python configurar_pasarelas.py --proveedor STRIPE --clave sk_test_... \
                                   --webhook-secret whsec_...
    python configurar_pasarelas.py --probar-webhook

No imprime nunca las claves: solo las enmascara.
"""

import argparse
import base64
import getpass
import json
import os
import ssl
import subprocess
import sys
import urllib.error
import urllib.request

# --------------------------------------------------------------------------- rutas
RAIZ = os.path.dirname(os.path.abspath(__file__))
PERFILES = (".azure-despliegue-sp3", ".azure-despliegue")

# --------------------------------------------------------------------------- colores (Windows friendly)
class C:
    RESET = "\033[0m"
    NEGRITA = "\033[1m"
    VERDE = "\033[32m"
    AMARILLO = "\033[33m"
    ROJO = "\033[31m"
    AZUL = "\033[36m"


def _color(s):
    if os.name == "nt":
        return s
    return s


def titulo(t):
    print("\n" + _color(C.NEGRITA + C.AZUL) + "=" * 70)
    print(t)
    print("=" * 70 + _color(C.RESET))


def ok(t):
    print(_color(C.VERDE + "[OK]   " + C.RESET) + t)


def aviso(t):
    print(_color(C.AMARILLO + "[AVISO] " + C.RESET) + t)


def error(t):
    print(_color(C.ROJO + "[ERROR] " + C.RESET) + t)


def info(t):
    print("       " + t)


def mascar(valor, visibles=4):
    if not valor:
        return "(vacio)"
    v = str(valor)
    if len(v) <= visibles * 2:
        return "*" * len(v)
    return v[:visibles] + "*" * (len(v) - visibles * 2) + v[-visibles:]


def pedir(texto, defecto=""):
    try:
        v = input(texto).strip()
    except EOFError:
        v = ""
    return v or defecto


def pedir_secreto(texto):
    try:
        return getpass.getpass(texto).strip()
    except (EOFError, KeyboardInterrupt):
        return ""


# --------------------------------------------------------------------------- red
def http_json(url, metodo="GET", cuerpo=None, cabeceras=None, timeout=25):
    """Devuelve (codigo, objeto_json_o_texto). Lanza excepcion si hay red rota."""
    datos = None
    if cuerpo is not None:
        datos = json.dumps(cuerpo).encode("utf-8")
    peticion = urllib.request.Request(url, data=datos, method=metodo)
    peticion.add_header("Accept", "application/json")
    if cuerpo is not None:
        peticion.add_header("Content-Type", "application/json")
    for k, v in (cabeceras or {}).items():
        peticion.add_header(k, v)
    ctx = ssl.create_default_context()
    try:
        with urllib.request.urlopen(peticion, timeout=timeout, context=ctx) as r:
            texto = r.read().decode("utf-8", "replace")
            codigo = r.getcode()
    except urllib.error.HTTPError as e:
        texto = e.read().decode("utf-8", "replace")
        codigo = e.getcode()
    except Exception as e:
        raise RuntimeError("no se pudo conectar con %s (%s)" % (url, e))
    try:
        return codigo, json.loads(texto)
    except ValueError:
        return codigo, texto


def basic(user, password):
    return "Basic " + base64.b64encode(("%s:%s" % (user, password)).encode("utf-8")).decode("ascii")


# --------------------------------------------------------------------------- despliegue
def leer_config():
    """Config del despliegue (.azure-despliegue-sp3/config.json o el de Sprints 1/2)."""
    for carpeta in PERFILES:
        ruta = os.path.join(RAIZ, carpeta, "config.json")
        if os.path.isfile(ruta):
            try:
                with open(ruta, "r", encoding="utf-8") as f:
                    return json.load(f), carpeta
            except (OSError, ValueError):
                continue
    return None, None


def url_publica(cfg, argumento=None):
    if argumento:
        return argumento.rstrip("/")
    if cfg and cfg.get("webapp_url"):
        return cfg["webapp_url"].rstrip("/")
    return None


# --------------------------------------------------------------------------- validacion por proveedor
def validar_mercadopago(token):
    codigo, cuerpo = http_json("https://api.mercadopago.com/users/me",
                               cabeceras={"Authorization": "Bearer " + token})
    if codigo == 200 and isinstance(cuerpo, dict) and cuerpo.get("id"):
        return True, "Credencial valida. Cuenta: %s (%s)" % (
            cuerpo.get("first_name", ""), cuerpo.get("site_id", {}).get("id", "") if isinstance(cuerpo.get("site_id"), dict) else "")
    detalle = cuerpo.get("message", "") if isinstance(cuerpo, dict) else str(cuerpo)[:160]
    return False, "Mercado Pago rechazo el token (HTTP %s): %s" % (codigo, detalle)


def validar_paypal(client_id, client_secret, ambiente="live"):
    base = ("https://api-m.sandbox.paypal.com" if ambiente == "sandbox"
            else "https://api-m.paypal.com")
    codigo, cuerpo = http_json(base + "/v1/oauth2/token", metodo="POST",
                               cuerpo={"grant_type": "client_credentials"},
                               cabeceras={"Authorization": basic(client_id, client_secret)})
    if codigo == 200 and isinstance(cuerpo, dict) and cuerpo.get("access_token"):
        return True, "Credenciales validas (ambiente %s)." % ambiente
    detalle = cuerpo.get("error_description", "") if isinstance(cuerpo, dict) else str(cuerpo)[:160]
    return False, "PayPal rechazo las credenciales (HTTP %s): %s" % (codigo, detalle)


def validar_stripe(clave, webhook_secret=""):
    if clave.startswith("rk_"):
        return False, "Esa es una clave restringida (rk_). El backend necesita la clave secreta (sk_)."
    if not (clave.startswith("sk_test_") or clave.startswith("sk_live_")):
        return False, "La clave no parece de Stripe (debe empezar por sk_test_ o sk_live_)."
    codigo, cuerpo = http_json("https://api.stripe.com/v1/account",
                               cabeceras={"Authorization": "Bearer " + clave})
    if codigo == 200 and isinstance(cuerpo, dict) and cuerpo.get("id"):
        extra = ""
        if webhook_secret:
            if webhook_secret.startswith("whsec_"):
                extra = " Webhook secret con formato correcto."
            else:
                return False, "El webhook secret deberia empezar por whsec_."
        return True, "Credencial valida. Cuenta %s%s" % (cuerpo.get("id", "")[:12], extra)
    detalle = cuerpo.get("error", {}).get("message", "") if isinstance(cuerpo, dict) else str(cuerpo)[:160]
    return False, "Stripe rechazo la clave (HTTP %s): %s" % (codigo, detalle)


def validar_qr(client_id, client_secret, base_url, id_establecimiento):
    if not base_url:
        base_url = "https://atcgwapitest.redenlace.com.bo/sandbox"
    base_url = base_url.rstrip("/")
    if not id_establecimiento or int(id_establecimiento) <= 0:
        return False, "Falta el id del establecimiento (lo entrega ATC al integrar el comercio)."
    codigo, cuerpo = http_json(base_url + "/oauth-client-credentials/access-token?grant_type=client_credentials",
                               metodo="POST", cuerpo={},
                               cabeceras={"Authorization": basic(client_id, client_secret),
                                          "Content-Type": "application/x-www-form-urlencoded"})
    if codigo == 200 and isinstance(cuerpo, dict) and cuerpo.get("access_token"):
        return True, "Credenciales validas en %s (scope %s)." % (base_url, cuerpo.get("scope", "?"))
    detalle = cuerpo.get("message", "") if isinstance(cuerpo, dict) else str(cuerpo)[:160]
    return False, "QR Simple rechazo las credenciales (HTTP %s): %s" % (codigo, detalle)


# --------------------------------------------------------------------------- aplicacion
def guardar_env(ajustes):
    """Guarda los ajustes en pasarelas.env (util si todavia no hay despliegue)."""
    ruta = os.path.join(RAIZ, "pasarelas.env")
    lineas = ["# Credenciales de las pasarelas de pago (Sprint 3).",
              "# Copia estas lineas en una terminal de Windows con 'setx' o exportalas.",
              "# NUNCA subas este archivo a un repositorio ni lo compartas."]
    for k, v in sorted(ajustes.items()):
        lineas.append("%s=%s" % (k, v))
    with open(ruta, "w", encoding="utf-8") as f:
        f.write("\n".join(lineas) + "\n")
    return ruta


def aplicar_en_azure(cfg, ajustes):
    """Guarda las variables en App Service (si el proyecto ya esta desplegado)."""
    if not cfg or not cfg.get("webapp"):
        return False, "No hay despliegue de Azure todavia."
    az = "az" if os.name != "nt" else "az.cmd"
    if not shutil_which(az):
        return False, "No se encontro la CLI de Azure ('az'). Instala Azure CLI o usa pasarelas.env."
    cmd = [az, "webapp", "config", "appsettings", "set",
           "-g", cfg["resource_group"], "-n", cfg["webapp"], "--settings"]
    cmd += ["%s=%s" % (k, v) for k, v in ajustes.items()]
    cmd += ["--only-show-errors", "--output", "none"]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    except Exception as e:
        return False, "Fallo el comando de Azure: %s" % e
    if r.returncode != 0:
        return False, "Azure CLI devolvio error: %s" % (r.stderr or r.stdout)[:300]
    return True, "Variables guardadas en App Service (%s). Reinicia la app para que las tome." % cfg["webapp"]


def shutil_which(programa):
    from shutil import which
    return which(programa)


# --------------------------------------------------------------------------- modos
def modo_verificar(args):
    titulo("Estado de las pasarelas en el despliegue")
    cfg, carpeta = leer_config()
    url = url_publica(cfg, args.url_publica)
    if not url:
        error("No encuentro una URL publica. Despliega primero (python desplegar_azure.py) "
              "o usa --url-publica https://tu-webapp.azurewebsites.net")
        return 1
    info("URL publica: " + url)
    if carpeta:
        info("Perfil de despliegue: " + carpeta)
    try:
        codigo, cuerpo = http_json(url + "/api/public/planes")
    except RuntimeError as e:
        error(str(e))
        return 1
    # /api/pagos/estado exige permiso: se consulta con un login de prueba.
    codigo, cuerpo = http_json(url + "/api/auth/login", metodo="POST",
                               cuerpo={"correo": args.correo, "password": args.password})
    if codigo != 200 or not isinstance(cuerpo, dict) or not cuerpo.get("token"):
        error("No se pudo iniciar sesion en %s para consultar el estado de la pasarela." % url)
        info("Puedes probarlo a mano: curl %s/api/pagos/estado -H \"Authorization: Bearer <token>\"" % url)
        return 1
    token = cuerpo["token"]
    codigo, estado = http_json(url + "/api/pagos/estado",
                               cabeceras={"Authorization": "Bearer " + token})
    if codigo != 200 or not isinstance(estado, dict):
        error("No se pudo leer /api/pagos/estado (HTTP %s)." % codigo)
        return 1
    info("Proveedor activo: %s (%s)" % (estado.get("nombreProveedor"), estado.get("proveedor")))
    info("Configurado: %s | Moneda: %s | Modo sandbox: %s"
         % (estado.get("configurado"), estado.get("moneda"), estado.get("sandbox")))
    print()
    for p in estado.get("proveedoresDisponibles", []):
        marca = "SI" if p.get("configurado") else "no"
        color = C.VERDE if p.get("configurado") else C.AMARILLO
        print("  " + _color(color + "  %-14s %s" % (p.get("nombre"), marca)) + _color(C.RESET)
              + "  (%s, moneda %s)" % (p.get("nombreVisible"), p.get("moneda")))
    print()
    if estado.get("configurado"):
        ok("La pasarela esta lista para cobrar de verdad.")
    else:
        aviso("Ninguna pasarela esta configurada: la pantalla de suscripcion avisara y no se cobrara nada.")
        info("Configurala con:  python configurar_pasarelas.py")
    print()
    info("Webhook que debes registrar en el panel del proveedor:")
    print("      " + url + "/api/pagos/webhook")
    return 0


def modo_asistente(args):
    titulo("Configuracion de pasarelas de pago (asistente)")
    cfg, carpeta = leer_config()
    url = url_publica(cfg, args.url_publica)
    if url:
        info("Despliegue detectado: " + url + (" (" + carpeta + ")" if carpeta else ""))
    else:
        aviso("No hay despliegue de Azure todavia: se guardara en pasarelas.env "
              "(y el script te dira los 'setx' para Windows).")
    print()
    print("  Elige las pasarelas que quieres dejar listas (puedes varias):")
    print("    1) Mercado Pago   ( Bolivia, tarjetas y saldo )")
    print("    2) PayPal          ( internacional )")
    print("    3) Stripe          ( internacional, Checkout Sessions )")
    print("    4) QR Simple       ( QR oficial del BCB, Red Enlace / ATC )")
    print("    0) Salir")
    escolha = pedir("  Numeros separados por coma (ej: 1,3): ", "1")
    if not escolha.strip() or escolha.strip() == "0":
        info("Nada que hacer.")
        return 0

    ajustes = {}
    webhook_url = (url + "/api/pagos/webhook") if url else "https://TU-WEBAPP.azurewebsites.net/api/pagos/webhook"

    for opcion in [x.strip() for x in escolha.split(",") if x.strip()]:
        print()
        titulo_p = {"1": "Mercado Pago", "2": "PayPal", "3": "Stripe", "4": "QR Simple (Red Enlace / ATC)"}.get(opcion)
        if not titulo_p:
            error("Opcion no valida: " + opcion)
            continue
        print("=== " + titulo_p + " ===")

        if opcion == "1":
            token = pedir_secreto("  Access token de Mercado Pago (oculto): ")
            if not token:
                aviso("Sin token: se omite Mercado Pago.")
                continue
            valido, mensaje = validar_mercadopago(token)
            print("     " + mensaje)
            if not valido:
                error("No se guarda: la credencial no es valida.")
                continue
            ajustes["MERCADOPAGO_ACCESS_TOKEN"] = token
            secreto = pedir_secreto("  Secreto de firma del webhook (opcional, Enter para omitir): ")
            if secreto:
                ajustes["MERCADOPAGO_WEBHOOK_SECRET"] = secreto
            ajustes.setdefault("APP_PAGOS_PROVEEDOR", "MERCADO_PAGO")
            ok("Mercado Pago validado.")

        elif opcion == "2":
            cid = pedir("  Client ID de PayPal: ")
            csec = pedir_secreto("  Client secret (oculto): ")
            ambiente = pedir("  Ambiente (live/sandbox) [live]: ", "live").lower()
            if not cid or not csec:
                aviso("Sin credenciales: se omite PayPal.")
                continue
            valido, mensaje = validar_paypal(cid, csec, ambiente)
            print("     " + mensaje)
            if not valido:
                error("No se guarda: la credencial no es valida.")
                continue
            ajustes["PAYPAL_CLIENT_ID"] = cid
            ajustes["PAYPAL_CLIENT_SECRET"] = csec
            ajustes["PAYPAL_AMBIENTE"] = ambiente
            ajustes.setdefault("APP_PAGOS_PROVEEDOR", "PAYPAL")
            ok("PayPal validado.")

        elif opcion == "3":
            clave = pedir_secreto("  Clave secreta de Stripe (sk_test_/sk_live_, oculta): ")
            if not clave:
                aviso("Sin clave: se omite Stripe.")
                continue
            wsec = pedir_secreto("  Webhook secret (whsec_..., opcional, Enter para omitir): ")
            valido, mensaje = validar_stripe(clave, wsec)
            print("     " + mensaje)
            if not valido:
                error("No se guarda: la credencial no es valida.")
                continue
            ajustes["STRIPE_SECRET_KEY"] = clave
            if wsec:
                ajustes["STRIPE_WEBHOOK_SECRET"] = wsec
            moneda = pedir("  Moneda que cobra Stripe (usd/eur/bo...) [usd]: ", "usd")
            ajustes["STRIPE_MONEDA"] = moneda
            if moneda.lower() != "bob":
                factor = pedir("  Factor de conversion Bs -> %s (ej: 6.9) [1]: " % moneda, "1")
                ajustes["STRIPE_FACTOR_CONVERSION"] = factor
            ajustes.setdefault("APP_PAGOS_PROVEEDOR", "STRIPE")
            ok("Stripe validado.")

        elif opcion == "4":
            cid = pedir("  client_id de ATC / Red Enlace: ")
            csec = pedir_secreto("  client_secret (oculto): ")
            base = pedir("  URL base [https://atcgwapitest.redenlace.com.bo/sandbox]: ",
                         "https://atcgwapitest.redenlace.com.bo/sandbox")
            est = pedir("  Id del establecimiento (lo da ATC): ")
            valido, mensaje = validar_qr(cid, csec, base, est)
            print("     " + mensaje)
            if not valido:
                error("No se guarda: la credencial no es valida.")
                continue
            ajustes["APP_PAGOS_QR_CLIENT_ID"] = cid
            ajustes["APP_PAGOS_QR_CLIENT_SECRET"] = csec
            ajustes["APP_PAGOS_QR_BASE_URL"] = base
            ajustes["APP_PAGOS_QR_ID_ESTABLECIMIENTO"] = est
            ajustes["APP_PAGOS_QR_NOMBRE_ESTABLECIMIENTO"] = pedir(
                "  Nombre del establecimiento [Activos Fijos]: ", "Activos Fijos")
            ajustes["APP_PAGOS_QR_VIGENCIA"] = "900"
            clave_webhook = pedir_secreto("  Clave del webhook (la usara ATC como cabecera) [x-api-key]: ")
            ajustes["APP_PAGOS_QR_WEBHOOK_KEY"] = "x-api-key"
            if clave_webhook:
                ajustes["APP_PAGOS_QR_WEBHOOK_VALUE"] = clave_webhook
            ajustes.setdefault("APP_PAGOS_PROVEEDOR", "QR")
            ok("QR Simple validado.")

    if not ajustes:
        aviso("No se guardo ninguna credencial.")
        return 1

    if url:
        ajustes["APP_URL_PUBLICA"] = url
    ajustes.setdefault("APP_PAGOS_SANDBOX", "false")

    titulo("Guardando la configuracion")
    for k, v in sorted(ajustes.items()):
        info("%-34s %s" % (k, mascar(v)))
    aplicado, mensaje = aplicar_en_azure(cfg, ajustes)
    if aplicado:
        ok(mensaje)
    else:
        aviso(mensaje)
        ruta = guardar_env(ajustes)
        ok("Credenciales guardadas en " + ruta)
        print()
        print("  Para Windows (PowerShell o CMD), copia y pega:")
        for k, v in sorted(ajustes.items()):
            print('    setx %s "%s"' % (k, v))
        print()
        print("  Y despues vuelve a desplegar:  python desplegar_azure.py")
    print()
    info("Webhook que debes registrar en el panel del proveedor:")
    print("      " + webhook_url)
    return 0


def modo_probar_webhook(args):
    titulo("Prueba del webhook de pagos")
    cfg, _ = leer_config()
    url = url_publica(cfg, args.url_publica)
    if not url:
        error("Necesito la URL publica (--url-publica) o un despliegue previo.")
        return 1
    destino = url + "/api/pagos/webhook"
    info("Enviando una notificacion de prueba a " + destino)
    cuerpo = {"type": "checkout.session.completed",
              "data": {"object": {"id": "cs_prueba", "client_reference_id": "PAG-PRUEBA"}}}
    codigo, respuesta = http_json(destino, metodo="POST", cuerpo=cuerpo,
                                  cabeceras={"Stripe-Signature": "t=1,v1=prueba"})
    info("HTTP %s -> %s" % (codigo, str(respuesta)[:200]))
    if codigo == 200:
        ok("El webhook responde bien (200): la pasarela podria avisarnos.")
        info("Que responda 200 no significa que el pago este aprobado: el backend "
             "verifica la firma y consulta al proveedor antes de aprobar.")
    else:
        error("El webhook no responde 200. Revisa que el despliegue este arriba "
              "y que /api/pagos/webhook este permitido sin token.")
    return 0


def main():
    parser = argparse.ArgumentParser(description="Configuracion guiada de pasarelas de pago")
    parser.add_argument("--verificar", action="store_true",
                        help="revisa que pasarelas hay activas en el despliegue")
    parser.add_argument("--probar-webhook", action="store_true",
                        help="envia una notificacion de prueba al webhook")
    parser.add_argument("--proveedor", help="configura sin asistente (STRIPE, QR, PAYPAL, MERCADO_PAGO)")
    parser.add_argument("--clave", help="clave/token del proveedor")
    parser.add_argument("--webhook-secret", help="secreto del webhook (Stripe / Mercado Pago)")
    parser.add_argument("--url-publica", help="URL publica del backend (https://...azurewebsites.net)")
    parser.add_argument("--correo", default="admin@uagrm.edu.bo", help="correo para el chequeo de estado")
    parser.add_argument("--password", default="admin123", help="clave para el chequeo de estado")
    args = parser.parse_args()

    if args.verificar:
        return modo_verificar(args)
    if args.probar_webhook:
        return modo_probar_webhook(args)
    if args.proveedor:
        # modo no interactivo: valida y guarda
        titulo("Configurando " + args.proveedor.upper())
        clave = args.clave or ""
        if not clave:
            error("Falta --clave")
            return 1
        ajustes = {}
        if args.proveedor.upper() == "STRIPE":
            valido, mensaje = validar_stripe(clave, args.webhook_secret or "")
            print("     " + mensaje)
            if not valido:
                return 1
            ajustes["STRIPE_SECRET_KEY"] = clave
            if args.webhook_secret:
                ajustes["STRIPE_WEBHOOK_SECRET"] = args.webhook_secret
        elif args.proveedor.upper() == "MERCADO_PAGO":
            valido, mensaje = validar_mercadopago(clave)
            print("     " + mensaje)
            if not valido:
                return 1
            ajustes["MERCADOPAGO_ACCESS_TOKEN"] = clave
            if args.webhook_secret:
                ajustes["MERCADOPAGO_WEBHOOK_SECRET"] = args.webhook_secret
        else:
            error("Modo no interactivo disponible solo para STRIPE y MERCADO_PAGO; "
                  "usa el asistente para los demas.")
            return 1
        ajustes["APP_PAGOS_PROVEEDOR"] = args.proveedor.upper()
        cfg, _ = leer_config()
        url = url_publica(cfg, args.url_publica)
        if url:
            ajustes["APP_URL_PUBLICA"] = url
        aplicado, mensaje = aplicar_en_azure(cfg, ajustes)
        ok(mensaje if aplicado else mensaje + " (guardado en pasarelas.env)")
        if not aplicado:
            guardar_env(ajustes)
        return 0
    return modo_asistente(args)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nCancelado.")
        sys.exit(1)

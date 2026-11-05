"""
Pruebas automatizadas de extremo a extremo (HTTP real contra Apache + PHP +
SQL Server). Cubren flujo normal, errores, accesos sin sesión, límite de 10
boletos, doble venta concurrente, SQL Injection, CSRF, XSS y cabeceras.

Requisitos: la base recién creada con los scripts 01..08 y el sitio en BASE.
Uso:  python3 tests/pruebas_web.py
Variables opcionales: BASE (http://127.0.0.1/cine/), SQLCMD_ADMIN (comando
sqlcmd con un login administrador para verificar en la base).
"""
import os
import re
import subprocess
import sys
import threading
from datetime import date

import requests

BASE = os.environ.get("BASE", "http://127.0.0.1/cine/")
SQLCMD = os.environ.get(
    "SQLCMD_ADMIN",
    "/opt/mssql-tools18/bin/sqlcmd -S 127.0.0.1 -C -W -h -1 -U dba_prueba -P Dba_Prueba#2026 -d CineAuroraDB")
SQLCMD_APP = "/opt/mssql-tools18/bin/sqlcmd -S 127.0.0.1 -C -W -h -1 -U cine_app -P C1ne#Aurora_App2026 -d CineAuroraDB"

resultados = []


def prueba(nombre, ok, detalle=""):
    resultados.append((nombre, bool(ok), detalle))
    print(("  OK   " if ok else "  FALLA") + "  " + nombre + (f"  [{detalle}]" if detalle and not ok else ""))


def sql(consulta, cmd=SQLCMD):
    r = subprocess.run(cmd.split() + ["-Q", "SET NOCOUNT ON; " + consulta], capture_output=True, text=True)
    return (r.stdout + r.stderr).strip()


def sesion():
    s = requests.Session()
    s.headers["User-Agent"] = "pruebas-cine-aurora"
    return s


def csrf(html):
    m = re.search(r'name="csrf" value="([0-9a-f]{64})"', html)
    return m.group(1) if m else ""


def login(s, correo, password):
    r = s.get(BASE + "login.php")
    return s.post(BASE + "login.php", data={"csrf": csrf(r.text), "correo": correo, "password": password, "volver": "index.php"})


def funcion_id(sala, dia_offset, hora):
    q = (f"SELECT f.FuncionID FROM dbo.Funciones f JOIN dbo.Salas s ON s.SalaID=f.SalaID "
         f"WHERE s.Nombre=N'{sala}' AND f.FechaHora = DATEADD(MINUTE, DATEDIFF(MINUTE,'00:00',CAST('{hora}' AS TIME)), "
         f"CAST(DATEADD(DAY,{dia_offset},CAST(SYSDATETIME() AS DATE)) AS DATETIME2(0)))")
    return int(sql(q).splitlines()[0])


def asientos_libres(s, fid, n, saltar=0):
    r = s.get(BASE + f"asientos.php?funcion={fid}")
    libres = re.findall(r'<label class="asiento libre[^"]*"[^>]*>\s*<input type="checkbox" name="asientos\[\]" value="(\d+)"', r.text)
    return r, libres[saltar:saltar + n]


def comprar(s, fid, ids, numero="4111111111111111", marca="VISA", cvv="123", mes="12", anio="2029", titular="Prueba Uno"):
    r, _ = asientos_libres(s, fid, 0)
    t = csrf(r.text)
    r = s.post(BASE + "pago.php", data={"csrf": t, "paso": "resumen", "funcion": fid, "asientos[]": ids})
    if "token_pago" not in r.text:
        return r
    tok = re.search(r'name="token_pago" value="([0-9a-f]+)"', r.text).group(1)
    return s.post(BASE + "pago.php", data={
        "csrf": csrf(r.text), "paso": "pagar", "funcion": fid, "asientos": ",".join(ids), "token_pago": tok,
        "marca": marca, "numero": numero, "titular": titular, "mes": mes, "anio": anio, "cvv": cvv})


def main():
    print("\n== 1. Cartelera y páginas públicas")
    a = sesion()
    r = a.get(BASE)
    prueba("Cartelera visible sin sesión (200)", r.status_code == 200 and "En cartelera" in r.text)
    prueba("Título y favicon propios", "<title>Cartelera | Cine Aurora</title>" in r.text and "favicon.ico" in r.text)
    prueba("Favicon responde 200", a.get(BASE + "favicon.ico").status_code == 200)
    r = a.get(BASE + "pelicula.php?id=1")
    prueba("Página de película con horarios", r.status_code == 200 and 'class="horario"' in r.text)

    print("\n== 2. Bloqueo de compra sin sesión (servidor)")
    fid = funcion_id("Sala 1", 1, "18:30")
    r = a.get(BASE + f"asientos.php?funcion={fid}", allow_redirects=False)
    prueba("asientos.php sin sesión redirige a login", r.status_code == 302 and "login.php" in r.headers.get("Location", ""))
    r = a.post(BASE + "pago.php", data={"paso": "pagar", "funcion": fid, "asientos": "1"}, allow_redirects=False)
    prueba("pago.php sin token CSRF -> 400", r.status_code == 400)
    t = csrf(a.get(BASE + "login.php").text)
    r = a.post(BASE + "pago.php", data={"csrf": t, "paso": "pagar", "funcion": fid, "asientos": "1"}, allow_redirects=False)
    prueba("pago.php con CSRF válido pero sin sesión -> login", r.status_code == 302 and "login.php" in r.headers.get("Location", ""))
    r = a.get(BASE + "boletos.php?compra=1", allow_redirects=False)
    prueba("boletos.php sin sesión -> login", r.status_code == 302)
    out = sql("EXEC app.sp_ComprarBoletos NULL, %d, '1', '4111111111111111', N'X Y Z', 12, 2030" % fid, SQLCMD_APP)
    prueba("Base de datos rechaza compra sin usuario (Resultado 10)", out.startswith("10"), out)

    print("\n== 3. Registro, trigger de log y login")
    correo = f"nuevo.{os.getpid()}@correo.test"
    r = a.get(BASE + "registro.php")
    r = a.post(BASE + "registro.php", data={"csrf": csrf(r.text), "nombre": "Mariana", "apellidos": "López Ruiz", "correo": correo,
                                            "telefono": "8111111111", "password": "Nueva#2026", "password2": "Nueva#2026"})
    prueba("Registro crea la cuenta", "Tu cuenta quedó creada" in r.text)
    fila = sql(f"SELECT CAST(DATALENGTH(PasswordHash) AS VARCHAR)+'|'+CAST(DATALENGTH(Sal) AS VARCHAR) FROM dbo.Usuarios WHERE Correo='{correo}'")
    prueba("Contraseña guardada como hash de 64 bytes con sal de 32", fila == "64|32", fila)
    log = sql(f"SELECT COUNT(*) FROM dbo.LogUsuarios WHERE Correo='{correo}'")
    prueba("Trigger anotó el usuario en LogUsuarios", log == "1", log)
    cols = sql("SELECT STRING_AGG(name, ',') FROM sys.columns WHERE object_id = OBJECT_ID('dbo.LogUsuarios')")
    prueba("LogUsuarios no tiene columnas de contraseña", not re.search(r"pass|hash|sal\b|,Sal,", cols, re.I), cols)
    r = a.post(BASE + "registro.php", data={"csrf": csrf(a.get(BASE + "registro.php").text), "nombre": "Otra", "apellidos": "Persona",
                                            "correo": correo, "telefono": "", "password": "Nueva#2026", "password2": "Nueva#2026"})
    prueba("Correo duplicado rechazado", "ya está registrado" in r.text)
    r = a.post(BASE + "registro.php", data={"csrf": csrf(a.get(BASE + "registro.php").text), "nombre": "Debil", "apellidos": "Clave",
                                            "correo": "debil@correo.test", "telefono": "", "password": "12345678", "password2": "12345678"})
    prueba("Contraseña débil rechazada", "mayúscula" in r.text)

    s = sesion()
    s.get(BASE)
    antes = s.cookies.get("CINEAURORA_SID")
    r = login(s, correo, "Incorrecta#1")
    prueba("Login con contraseña incorrecta falla", "Correo o contraseña incorrectos" in r.text)
    r = login(s, correo, "Nueva#2026")
    despues = s.cookies.get("CINEAURORA_SID")
    prueba("Login correcto", "Iniciaste sesión correctamente" in r.text)
    prueba("ID de sesión regenerado al iniciar sesión", antes and despues and antes != despues)

    print("\n== 4. SQL Injection")
    for carga in ["' OR '1'='1' --", "admin@cineaurora.test' --", "'; DROP TABLE dbo.Usuarios; --", "\" OR 1=1 --"]:
        x = sesion()
        r = login(x, carga, "' OR '1'='1")
        prueba(f"Login con {carga!r} no entra", "Correo o contraseña incorrectos" in r.text and "Cerrar sesión" not in r.text)
    for url in ["pelicula.php?id=1%20OR%201=1", "pelicula.php?id=1;DROP%20TABLE%20dbo.Peliculas", "pelicula.php?id=-1", "pelicula.php?id='"]:
        r = a.get(BASE + url)
        prueba(f"GET {url} -> 404 sin error SQL", r.status_code == 404 and "SQLSTATE" not in r.text and "SQL Server" not in r.text)
    r = a.get(BASE + "registro.php")
    r = a.post(BASE + "registro.php", data={"csrf": csrf(r.text), "nombre": "Robert'); DROP TABLE dbo.Usuarios;--", "apellidos": "Tablas",
                                            "correo": "bobby@correo.test", "telefono": "", "password": "Bobby#2026", "password2": "Bobby#2026"})
    prueba("Nombre con inyección rechazado por la validación", "Revisa los campos marcados" in r.text)
    rara = f"o'conner--{os.getpid()}@correo.test"
    r = a.post(BASE + "registro.php", data={"csrf": csrf(a.get(BASE + "registro.php").text), "nombre": "Liam", "apellidos": "O'Conner",
                                            "correo": rara, "telefono": "", "password": "Liam#2026a", "password2": "Liam#2026a"})
    guardado = sql(f"SELECT Correo FROM dbo.Usuarios WHERE Correo = '{rara.replace(chr(39), chr(39) * 2)}'")
    prueba("Comillas y -- se guardan como texto literal (consulta parametrizada)", guardado == rara, guardado)
    prueba("Tablas intactas", sql("SELECT COUNT(*) FROM sys.tables WHERE name IN ('Usuarios','Peliculas','Boletos')") == "3")

    print("\n== 5. Compra normal y validaciones de tarjeta")
    fid2 = funcion_id("Sala 2", 2, "18:30")
    _, ids = asientos_libres(s, fid2, 2)
    r = comprar(s, fid2, ids, numero="4111111111111112")
    prueba("Luhn inválido rechazado", "dígito verificador" in r.text)
    r = comprar(s, fid2, ids, numero="4111111111111111", marca="AMEX")
    prueba("Marca distinta al número rechazada", "no coincide" in r.text)
    r = comprar(s, fid2, ids, numero="6011111111111117", marca="VISA")
    prueba("Discover (marca no aceptada) rechazada", "Solo se aceptan" in r.text)
    r = comprar(s, fid2, ids, mes="1", anio=str(date.today().year))
    prueba("Tarjeta vencida rechazada" if date.today().month > 1 else "Vencimiento (mes actual) aceptado", ("vencida" in r.text) == (date.today().month > 1))
    r = comprar(s, fid2, ids, numero="378282246310005", marca="AMEX", cvv="123")
    prueba("AMEX exige CVV de 4 dígitos", "4 dígitos" in r.text)
    r = comprar(s, fid2, ids, numero="4000000000000002")
    prueba("Tarjeta de rechazo simulado", "rechazado por el banco" in r.text)
    r = comprar(s, fid2, ids, numero="5555 5555 5555 4444", marca="MASTERCARD")
    prueba("Compra con Mastercard exitosa", "Compra realizada" in r.text and "boletos.php" in r.url, r.url)
    compra_id = int(re.search(r"compra=(\d+)", r.url).group(1)) if "compra=" in r.url else 0
    prueba("Boletos imprimibles con código de barras", 'class="boleto"' in r.text and "data-imprimir" in r.text and "<svg class=\"barras\"" in r.text)
    prueba("Tarjeta enmascarada en el recibo", "•••• 4444" in r.text and "5555555555554444" not in r.text)
    ocup = sql(f"SELECT COUNT(*) FROM dbo.Boletos WHERE FuncionID={fid2} AND AsientoID IN ({','.join(ids)})")
    prueba("Asientos pasan a ocupados", ocup == "2", ocup)
    r = s.get(BASE + f"asientos.php?funcion={fid2}")
    prueba("Mapa los muestra como comprados por el usuario", r.text.count('<label class="asiento mio') == 2, f"{r.status_code} {r.url} {r.text.count('class=\"asiento mio')}")
    cvv = sql("SELECT COUNT(*) FROM sys.columns WHERE object_id=OBJECT_ID('dbo.Tarjetas') AND name LIKE '%cvv%'")
    prueba("No existe columna CVV", cvv == "0")
    plano = sql("SELECT COUNT(*) FROM dbo.Tarjetas WHERE CHARINDEX(CAST('5555555555554444' AS VARBINARY(19)), NumeroCifrado) > 0 "
                "OR CHARINDEX(CAST(N'5555555555554444' AS VARBINARY(40)), NumeroCifrado) > 0")
    prueba("SELECT sobre Tarjetas no muestra el número en claro", plano == "0", plano)
    otro = sesion()
    login(otro, "ana.garcia@correo.test", "Cliente#Ana2026")
    r = otro.get(BASE + f"boletos.php?compra={compra_id}")
    prueba("Otro cliente no puede ver boletos ajenos (404)", r.status_code == 404)
    r = s.post(BASE + "pago.php", data={"csrf": csrf(s.get(BASE).text), "paso": "pagar", "funcion": fid2, "asientos": ",".join(ids),
                                         "token_pago": "00", "marca": "VISA", "numero": "4111111111111111", "titular": "X Y", "mes": "12", "anio": "2030", "cvv": "123"})
    prueba("Reenvío del pago (token de un solo uso) no duplica", "ya se usó" in r.text or "acaban de ser vendidos" in r.text or "acaba de ocuparse" in r.text)

    print("\n== 6. Límite de 10 boletos por usuario y función")
    luis = sesion()
    login(luis, "luis.hernandez@correo.test", "Cliente#Luis2026")
    fid1 = funcion_id("Sala 1", 1, "18:30")
    r, ids3 = asientos_libres(luis, fid1, 3)
    prueba("Luis ve que ya tiene 8 y puede comprar 2", "Ya tienes 8 boleto(s)" in r.text and 'data-max="2"' in r.text)
    r = comprar(luis, fid1, ids3)
    prueba("Comprar 3 más (8+3) rechazado en el servidor", "Límite de 10" in r.text and "Compra realizada" not in r.text)
    r = comprar(luis, fid1, ids3[:2])
    prueba("Comprar 2 (8+2=10) permitido", "Compra realizada" in r.text)
    r, ids1 = asientos_libres(luis, fid1, 1)
    prueba("Con 10 boletos el mapa queda bloqueado", "que es el máximo permitido" in r.text)
    luis_id = sql("SELECT UsuarioID FROM dbo.Usuarios WHERE Correo='luis.hernandez@correo.test'")
    libre = sql(f"SELECT TOP 1 a.AsientoID FROM dbo.Asientos a JOIN dbo.Funciones f ON f.SalaID=a.SalaID WHERE f.FuncionID={fid1} "
                f"AND NOT EXISTS (SELECT 1 FROM dbo.Boletos b WHERE b.FuncionID={fid1} AND b.AsientoID=a.AsientoID)")
    out = sql(f"EXEC app.sp_ComprarBoletos {luis_id}, {fid1}, '{libre}', '4111111111111111', N'LUIS H', 12, 2030", SQLCMD_APP)
    prueba("La base (procedimiento) rechaza el boleto 11 (Resultado 14)", out.startswith("14"), out)
    out = sql(f"""BEGIN TRY BEGIN TRAN;
        DECLARE @c INT = (SELECT TOP 1 CompraID FROM dbo.Compras WHERE UsuarioID={luis_id} AND FuncionID={fid1});
        INSERT dbo.Boletos (CompraID, FuncionID, SalaID, AsientoID, Precio, Codigo)
        SELECT @c, {fid1}, a.SalaID, a.AsientoID, 75, 'ZZZZZZZZZ1' FROM dbo.Asientos a WHERE a.AsientoID={libre};
        COMMIT; SELECT 'INSERTADO'; END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; SELECT CAST(ERROR_NUMBER() AS VARCHAR); END CATCH""")
    prueba("El trigger trg_Boletos_Max10 bloquea un INSERT directo (error 50010)", out.strip().endswith("50010"), out)
    r = luis.post(BASE + "pago.php", data={"csrf": csrf(luis.get(BASE).text), "paso": "resumen", "funcion": fid1, "asientos[]": [str(i) for i in range(1, 12)]})
    prueba("Más de 10 asientos en una sola petición rechazado", "Selecciona entre 1 y 10" in r.text)

    print("\n== 7. Doble venta del mismo asiento (concurrencia)")
    ana = otro
    sofia = sesion()
    login(sofia, "sofia.martinez@correo.test", "Cliente#Sofia2026")
    fid3 = funcion_id("Sala VIP", 3, "21:15")
    exitos_totales = 0
    rondas = 5
    for k in range(rondas):
        _, (asiento,) = asientos_libres(ana, fid3, 1, saltar=k)
        preparados = []
        for cli in (ana, sofia, s):
            r, _ = asientos_libres(cli, fid3, 0)
            r = cli.post(BASE + "pago.php", data={"csrf": csrf(r.text), "paso": "resumen", "funcion": fid3, "asientos[]": [asiento]})
            tok = re.search(r'name="token_pago" value="([0-9a-f]+)"', r.text).group(1)
            preparados.append((cli, {"csrf": csrf(r.text), "paso": "pagar", "funcion": fid3, "asientos": asiento, "token_pago": tok,
                                     "marca": "VISA", "numero": "4242424242424242", "titular": "Concurrente", "mes": "11", "anio": "2030", "cvv": "321"}))
        barrera = threading.Barrier(len(preparados))
        salida = []

        def pagar(cli, datos):
            barrera.wait()
            salida.append(cli.post(BASE + "pago.php", data=datos))
        hilos = [threading.Thread(target=pagar, args=p) for p in preparados]
        [h.start() for h in hilos]
        [h.join() for h in hilos]
        exitos = sum("Compra realizada" in x.text for x in salida)
        rechazos = sum(("acaban de ser vendidos" in x.text) or ("acaba de ocuparse" in x.text) for x in salida)
        exitos_totales += exitos
        prueba(f"Ronda {k + 1}: 3 clientes pagan el asiento {asiento} a la vez -> 1 compra, 2 rechazos", exitos == 1 and rechazos == 2, f"{exitos} éxitos, {rechazos} rechazos")
    dup = sql(f"SELECT COUNT(*) FROM (SELECT AsientoID FROM dbo.Boletos WHERE FuncionID={fid3} GROUP BY AsientoID HAVING COUNT(*)>1) x")
    prueba("Ningún asiento vendido dos veces en la base", dup == "0", dup)
    out = sql(f"INSERT dbo.Boletos (CompraID,FuncionID,SalaID,AsientoID,Precio,Codigo) SELECT TOP 1 CompraID,FuncionID,SalaID,AsientoID,Precio,'DUPLICADO1' FROM dbo.Boletos WHERE FuncionID={fid3}")
    prueba("UNIQUE(FuncionID, AsientoID) rechaza un INSERT duplicado directo", "UQ_Boletos_Funcion_Asiento" in out, out[:120])

    print("\n== 8. Administrador")
    r = s.get(BASE + "admin/index.php")
    prueba("Cliente en admin -> 403", r.status_code == 403)
    r = s.get(BASE + "admin/api_resumen.php")
    prueba("Cliente en API del panel -> 403", r.status_code == 403)
    r = a.get(BASE + "admin/funciones.php", allow_redirects=False)
    prueba("Anónimo en admin -> login", r.status_code == 302)
    adm = sesion()
    r = login(adm, "admin@cineaurora.test", "Admin#Aurora2026")
    prueba("Admin entra al panel", "Panel en vivo" in r.text)
    j = adm.get(BASE + "admin/api_resumen.php").json()
    total_bd = sql("SELECT FORMAT(SUM(Total), 'N2', 'en-US') FROM dbo.Compras")
    prueba("API en vivo: total recaudado coincide con la base", j["kpi"]["TotalRecaudado"] == "$" + total_bd, f'{j["kpi"]["TotalRecaudado"]} vs {total_bd}')
    prueba("API en vivo lista funciones vendidas", len(j["vendidas"]) >= 4)
    nuevo = sql(f"SELECT CONVERT(VARCHAR(10), DATEADD(DAY, 5, CAST(SYSDATETIME() AS DATE)), 23)")
    r = adm.get(BASE + "admin/funcion_form.php")
    datos = {"csrf": csrf(r.text), "pelicula": "1", "sala": "1", "fechahora": f"{nuevo}T19:00", "precio": "80", "formato": "2D", "idioma": "DOBLADA", "activa": "1"}
    r = adm.post(BASE + "admin/funcion_form.php", data=datos)
    prueba("Alta de función que se encima con otra -> rechazada", "se encimen" in r.text or "otra función en ese horario" in r.text)
    datos["fechahora"] = f"{nuevo}T23:45"
    r = adm.post(BASE + "admin/funcion_form.php", data=datos)
    prueba("Alta de función válida (23:45)", "Función guardada" in r.text)
    nf = sql(f"SELECT FuncionID FROM dbo.Funciones WHERE SalaID=1 AND FechaHora='{nuevo}T23:45:00'")
    r = adm.get(BASE + f"admin/funcion_form.php?id={nf}")
    datos.update({"csrf": csrf(r.text), "funcion": nf, "fechahora": f"{nuevo}T23:50", "precio": "85.50"})
    r = adm.post(BASE + f"admin/funcion_form.php?id={nf}", data=datos)
    mod = sql(f"SELECT CONVERT(VARCHAR(16), FechaHora, 120)+'|'+CAST(Precio AS VARCHAR) FROM dbo.Funciones WHERE FuncionID={nf}")
    prueba("Modificación de horario y precio", mod == f"{nuevo} 23:50|85.50", mod)
    r = adm.post(BASE + "admin/funciones.php", data={"csrf": csrf(r.text), "accion": "eliminar", "funcion": nf})
    prueba("Borrar función sin ventas", "Función eliminada" in r.text and sql(f"SELECT COUNT(*) FROM dbo.Funciones WHERE FuncionID={nf}") == "0")
    r = adm.post(BASE + "admin/funciones.php", data={"csrf": csrf(r.text), "accion": "eliminar", "funcion": fid2})
    prueba("Borrar función con ventas la retira y conserva ventas", "se retiró de la cartelera" in r.text
           and sql(f"SELECT CAST(Activa AS VARCHAR) FROM dbo.Funciones WHERE FuncionID={fid2}") == "0")
    r = adm.post(BASE + "admin/funciones.php", data={"accion": "eliminar", "funcion": fid1})
    prueba("Acción de admin sin CSRF -> 400", r.status_code == 400)
    r = adm.get(BASE + "admin/pelicula_form.php?id=2")
    p = {k: v for k, v in re.findall(r'name="(titulo|genero|director|duracion|estreno)"[^>]*? value="([^"]*)"', r.text)}
    sinop = re.search(r'<textarea name="sinopsis"[^>]*>(.*?)</textarea>', r.text, re.S).group(1)
    import html as h
    nombre = "El Último Faro & 'Sus Ecos'"
    r = adm.post(BASE + "admin/pelicula_form.php?id=2", data={"csrf": csrf(r.text), "pelicula": "2", "titulo": nombre, "sinopsis": h.unescape(sinop),
                                                              "genero": h.unescape(p["genero"]), "director": h.unescape(p["director"]), "clasificacion": "B15",
                                                              "duracion": p["duracion"], "estreno": p["estreno"], "imagen": "ultimo-faro.svg", "activa": "1"})
    prueba("Renombrar película", "Película guardada" in r.text)
    r = a.get(BASE)
    prueba("Nuevo nombre visible en cartelera y escapado (htmlspecialchars)", "El Último Faro &amp; &apos;Sus Ecos&apos;" in r.text)
    r = adm.get(BASE + "admin/ventas.php")
    prueba("Ventas muestran tarjeta enmascarada", re.search(r"(VISA|MASTERCARD|AMEX) •••• \d{4}", r.text) is not None)
    r = adm.get(BASE + "admin/log_usuarios.php")
    prueba("Log de usuarios visible para admin", correo in r.text)

    print("\n== 9. Archivos protegidos, cabeceras y errores")
    for ruta in ["includes/config.php", "includes/db.php", "logs/php_errores.log", "includes/"]:
        r = a.get(BASE + ruta)
        prueba(f"{ruta} bloqueado", r.status_code in (403, 404) and "DB_PASS" not in r.text)
    r = sesion().get(BASE)
    hd = r.headers
    prueba("CSP, X-Frame-Options y nosniff presentes", "default-src 'self'" in hd.get("Content-Security-Policy", "")
           and hd.get("X-Frame-Options") == "DENY" and hd.get("X-Content-Type-Options") == "nosniff")
    ck = r.headers.get("Set-Cookie", "") or ""
    prueba("Cookie de sesión HttpOnly y SameSite", "HttpOnly" in ck and "SameSite=Lax" in ck, ck)
    r = a.get(BASE + "assets/")
    prueba("Sin listado de directorios", r.status_code == 403)

    ok = sum(1 for _, b, _ in resultados if b)
    print(f"\nResultado: {ok}/{len(resultados)} pruebas correctas")
    return 0 if ok == len(resultados) else 1


if __name__ == "__main__":
    sys.exit(main())

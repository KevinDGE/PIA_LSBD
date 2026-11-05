# Cine Aurora · PIA Laboratorio de Seguridad en Bases de Datos

UANL · FCFM · **Equipo 3** · Agosto-Diciembre 2026 · Proceso de negocio: *Compra de boletos para cine*

Portal web de un cine ficticio con cartelera, registro e inicio de sesión, página por película con todos sus horarios, mapa de asientos, pago simulado con tarjeta Visa / Mastercard / American Express, boletos imprimibles y módulo de administrador en tiempo real. Corre en **Windows Server 2022 (VM) + SQL Server 2022 Express + Apache de XAMPP + PHP con `pdo_sqlsrv`**.

## Contenido del repositorio

| Ruta | Qué es |
|---|---|
| `htdocs/cine/` | El sitio completo. Se copia a `C:\xampp\htdocs\cine` |
| `sql/01…12_*.sql` | Scripts numerados en orden de ejecución (base, tablas, datos, cifrado, procedimientos, triggers, datos demo, usuarios y permisos, respaldo, restauración, evidencias, preparación de la revisión) |
| `GUIA_INSTALACION.md` | VM, SQL Server (modo mixto, TCP/IP), XAMPP, drivers de PHP, versiones compatibles, respaldo de llaves y restauración |
| `GUIA_REVISION.md` | Guion R1 a R19: qué abrir, qué ejecutar y qué resultado mostrar |
| `CREDENCIALES_PRUEBA.md` | Usuarios ficticios, tarjetas de prueba, logins y contraseñas de llaves |
| `presentacion/Presentación_Proyecto_3.pptx` | Presentación (13 diapositivas con notas del orador) |
| `entregables/Paginas_Proyecto_3.zip` | Zip para Teams: carpeta `cine/` + `scripts_sql/` |
| `tests/` | Pruebas automatizadas de extremo a extremo y banco de pruebas en Linux |
| `herramientas/` | Generador de pósters/íconos y empaquetado del zip |

## Datos que faltan por llenar

El enunciado traía marcadores sin llenar. Se tomaron estas decisiones:

| Marcador | Decisión |
|---|---|
| `[NOMBRE DEL CINE]` | **Cine Aurora** (constante `SITIO_NOMBRE` en `includes/config.php`) |
| `[NOMBRE DE LA BASE DE DATOS]` | **CineAuroraDB** |
| `[NOMBRES Y MATRÍCULAS]` | **Pendiente.** Escríbanlos en `presentacion/equipo.json` y regeneren la presentación (`cd presentacion && npm install && node construir_presentacion.js`) o edítenlos directo en la diapositiva 2 |

## Decisiones técnicas

- **Todo acceso a datos por procedimientos almacenados** del esquema `app`, llamados con `EXEC app.sp_X @P = ?` y `bindValue` (`includes/db.php`). No existe SQL armado con texto del usuario. Las tablas están en `dbo` y `cine_app` tiene `DENY` sobre ellas.
- **Compra en una sola transacción** (`app.sp_ComprarBoletos`): bloquea la fila de la función con `UPDLOCK, HOLDLOCK`, valida asientos y el máximo de 10 (contando compras anteriores), cifra la tarjeta, registra compra y boletos. `UQ_Boletos_Funcion_Asiento` y el trigger `trg_Boletos_Max10` son la última barrera aunque alguien insertara directo.
- **Cifrado por columna compatible con Express**: DMK → certificado → `SK_Tarjetas` AES_256 → `ENCRYPTBYKEY` sobre `VARBINARY`. Se cifran número, titular y vencimiento con autenticador `UsuarioID`. La llave solo se abre dentro de procedimientos `WITH EXECUTE AS OWNER`; `cine_app` no tiene permisos sobre llave ni certificado. Una restricción `CHECK` exige que el valor empiece con el GUID de la llave (no se puede guardar en claro). El CVV se valida en PHP y se descarta.
- **Dueño de la base = `sa`** (desactivado). Se descubrió en las pruebas que, al restaurar en otra instancia, `EXECUTE AS OWNER` falla si el dueño es un usuario de Windows que no existe ahí; `sa` tiene el mismo SID en todas las instancias.
- **Contraseñas**: sal aleatoria de 32 bytes por usuario y `HASHBYTES('SHA2_512', sal + contraseña)`; la comparación ocurre dentro de `app.sp_Login`. Bloqueo de 5 minutos tras 5 intentos fallidos.
- **Administrador** solo se crea por script; el registro web siempre crea clientes. Cada página de administración revalida el rol contra la base y cada procedimiento de administración vuelve a comprobarlo.
- **Borrar una función con ventas** no destruye el historial: se retira de la cartelera (`Activa = 0`) y se conserva lo vendido. Una función sin ventas se elimina.
- **Sesiones**: `session.use_strict_mode`, cookie `HttpOnly` + `SameSite=Lax`, `session_regenerate_id(true)` al iniciar sesión, expiración por 30 min de inactividad. **CSRF** en todos los formularios que modifican datos y un token de un solo uso en el pago (evita doble cobro por doble clic).
- **Salida y errores**: `htmlspecialchars` en toda salida (función `e()`), CSP sin scripts en línea, `X-Frame-Options`, errores de PHP/SQL solo a `logs/php_errores.log` y errores internos de procedimientos a `dbo.LogErrores`.
- **Pósters**: ilustraciones SVG abstractas hechas por el equipo (`herramientas/generar_imagenes.py`), sin texto, personajes ni carteles con derechos de autor. Las 6 películas y los directores son inventados.
- **Funciones de ejemplo** calculadas desde la fecha de instalación (21 días). El día de la revisión, `12_preparar_revision.sql` completa las que falten sin duplicar.
- **Nombres de entrega**: el enunciado del equipo pide `Paginas_Proyecto_3.zip` y `Respaldo_Proyecto_3.BAK`; la rúbrica general del PIA menciona `PIA_(#Equipo)_LSBD.zip` y `BD_(#Equipo)_LSBD.BAK`. Se usaron los primeros; conviene confirmar con el profesor.

## Cómo se probó

No había Windows Server en el entorno de desarrollo, así que se montó un **banco de pruebas en Linux** con los mismos componentes de Microsoft: SQL Server 2022 **Express** (16.0.4305.5, contenedor oficial), ODBC Driver 18, **Microsoft Drivers for PHP 5.12** compilados para PHP 8.3, y Apache 2.4 con `mod_php`. Los scripts SQL se ejecutaron sin cambios, excepto dos ajustes propios de Linux documentados en `tests/entorno_linux/preparar_bd.sh` (no existe Autenticación de Windows; rutas de respaldo).

- `tests/pruebas_web.py`: **81 de 81 pruebas correctas** (`tests/resultado_pruebas_web.txt`), por HTTP real: flujo normal, validaciones de tarjeta, accesos sin sesión, límite de 10, doble venta concurrente (3 sesiones en 5 rondas: siempre 1 compra y 2 rechazos), SQL Injection, CSRF, XSS, acceso de cliente a administración, archivos protegidos y cabeceras.
- Se probó además: respaldo y **restauración en una segunda instancia** con descifrado correcto, base de datos caída (la página muestra un mensaje genérico; el detalle queda en el log), bloqueo por 5 intentos, que el código de barras se lee (`zbarimg`: `CODE-39`), `php -l` de todos los archivos, `11_consultas_revision.sql` y `12_preparar_revision.sql` (dos veces seguidas, sin duplicar).

## Cumplimiento R1 a R19

| Req | Cumplido | Archivo o evidencia | ¿Probado? |
|---|---|---|---|
| R1 Presentación | Sí | `presentacion/Presentación_Proyecto_3.pptx` (13 diapositivas, notas del orador) | Validada y revisada visualmente con LibreOffice. **Falta:** abrirla en PowerPoint y llenar nombres/matrículas |
| R2 Windows Server 2022 en VM | Preparado | `GUIA_INSTALACION.md` §1 | **Falta probar en su VM** (no se puede ejecutar aquí) |
| R3 SQL Server 2022 Express | Sí | `sql/01…12` | Probado en SQL Server 2022 Express sobre Linux. **Falta:** ejecutar los scripts en la VM Windows |
| R4 Apache activo | Sí | `htdocs/cine/.htaccess`, `GUIA_INSTALACION.md` §4 | Probado en Apache 2.4 (Linux). **Falta:** XAMPP en Windows |
| R5 Diseño agradable | Sí | `assets/css/estilos.css`, `presentacion/capturas/` | Probado (capturas escritorio y celular) |
| R6 Todas las páginas | Sí | 17 páginas PHP en `htdocs/cine` | Probado |
| R7 PHP/HTML | Sí | `htdocs/cine/*.php`, `admin/*.php` | Probado (`php -l` y ejecución) |
| R8 Cartelera | Sí | `index.php`, `app.sp_Cartelera` | Probado |
| R9 Registro y login | Sí | `registro.php`, `login.php`, `app.sp_RegistrarUsuario`, `app.sp_Login` | Probado |
| R10 Película, asientos, pago, boletos; bloqueo sin sesión | Sí | `pelicula.php`, `asientos.php`, `pago.php`, `boletos.php`; `requerir_login()` y validación en `app.sp_ComprarBoletos` | Probado (incluye bloqueo en servidor y en la base) |
| R11 Administrador | Sí | `admin/index.php` (en vivo), `admin/funciones.php`, `funcion_form.php`, `peliculas.php`, `pelicula_form.php`, `ventas.php` | Probado |
| R12 Favicon y títulos | Sí | `favicon.ico`, `assets/img/favicon.svg`, `encabezado()` en `includes/plantilla.php` | Probado |
| R13 PK, FK, índices, restricciones, UNIQUE de asiento | Sí | `sql/02_tablas.sql`; bloque R13 de `sql/11` | Probado (INSERT duplicado → error 2627) |
| R14 SQL Injection | Sí | `includes/db.php`, `includes/validacion.php`, `sql/05`; bloque R14 de `sql/11` | Probado (11 pruebas de inyección) |
| R15 Trigger de log sin contraseñas | Sí | `sql/06_triggers.sql`, `dbo.LogUsuarios`, `admin/log_usuarios.php` | Probado |
| R16 sa desactivado, un login SQL de mínimo privilegio | Sí | `sql/08_usuarios_permisos.sql`, `includes/config.php` | Probado en Linux (sa rechazado, `cine_app` sin acceso a tablas ni llave). **Falta:** la validación de "login de Windows sysadmin" del script 08 solo se puede probar en Windows |
| R17 Cifrado de tarjetas | Sí | `sql/04_cifrado.sql`, `app.sp_ComprarBoletos`; bloque R17 de `sql/11` | Probado (SELECT muestra solo VARBINARY, NULL sin llave, cine_app no abre la llave, CHECK impide texto en claro, sin CVV) |
| R18 Login por procedimiento con sal y SHA2_512 | Sí | `app.sp_Login`, `dbo.fn_HashPassword` | Probado |
| R19 Respaldo .BAK en vivo | Sí | `sql/09_respaldo.sql`, `sql/10_restaurar_otra_instancia.sql` | Probado respaldo, verificación y restauración en otra instancia (rutas Linux). **Falta:** ensayarlo en la VM con `C:\Respaldos` o el asistente de SSMS |

## Qué deben probar ustedes en la VM

1. Seguir `GUIA_INSTALACION.md` completa (VM, SQL Server en modo mixto con TCP/IP 1433, XAMPP 8.2, ODBC 18, `php_pdo_sqlsrv_82_ts_x64.dll`).
2. Ejecutar `sql/01` a `sql/08` **con Autenticación de Windows**, con snapshot antes del 08, y confirmar que el 08 no se detiene (debe encontrar su usuario de Windows como sysadmin).
3. Abrir `http://localhost/cine/` y recorrer `GUIA_REVISION.md` completa una vez antes del día de la revisión.
4. Ejecutar `sql/09_respaldo.sql` y subir el `.BAK` generado en **su** VM (el respaldo debe salir de su instancia).
5. Llenar nombres y matrículas en la presentación.

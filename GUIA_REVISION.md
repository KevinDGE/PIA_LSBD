# Guion de revisión R1 a R19 · Cine Aurora (Equipo 3)

Revisión presencial: **jueves 19 de noviembre de 2026, desde las 6:00 PM**. Duración sugerida: 15 a 20 minutos.

## Antes de empezar (ese día, antes de las 6:00 PM)

1. Encender la VM y comprobar que **Apache** (XAMPP) y **SQL Server (SQLEXPRESS)** están en ejecución.
2. En SSMS (Autenticación de Windows) ejecutar **`sql/12_preparar_revision.sql`**. Agrega las funciones que falten, desbloquea cuentas y deja a Luis con 8 boletos en una función de las 21:15. **Anotar la URL que imprime** (`asientos.php?funcion=N`).
3. Tener abiertos:
   - Navegador A (normal): `http://localhost/cine/` sin sesión.
   - Navegador B (ventana privada): para el administrador.
   - SSMS con `sql/11_consultas_revision.sql` abierto (se ejecuta por bloques: seleccionar el bloque y F5).
   - PowerPoint con `Presentación_Proyecto_3.pptx`.
   - Explorador de archivos en `C:\Respaldos\CineAurora\`.
4. Tener a la mano `CREDENCIALES_PRUEBA.md` (impreso o en el celular).

---

## Criterio 1 · Documentación

### R1. Presentación con diseño adecuado
- **Abrir:** `Presentación_Proyecto_3.pptx` en modo presentación (F5).
- **Mostrar:** portada, equipo, objetivo, arquitectura, modelo de datos, flujo de compra, transacción, cifrado, medidas de seguridad, administrador, respaldo, pruebas y conclusiones. Las notas del orador traen qué decir en cada diapositiva.

## Criterio 2 · Infraestructura

### R2. Windows Server 2022 en una VM local
- **Mostrar:** la ventana de VirtualBox/VMware con la VM encendida. Dentro de la VM, `Win + R` > `winver` (debe decir *Microsoft Windows Server 2022*). Opcional: *Administrador del servidor* > *Servidor local*.

### R3. SQL Server 2022 Express
- **Ejecutar en SSMS:** `SELECT @@VERSION, SERVERPROPERTY('Edition');`
- **Resultado esperado:** *Microsoft SQL Server 2022 … Express Edition (64-bit) … on Windows Server 2022*.

### R4. Apache activo
- **Mostrar:** XAMPP Control Panel con **Apache** en verde (y como servicio). En PowerShell: `Get-Service Apache2.4` muestra *Running*.
- **Abrir:** `http://localhost/cine/`.

## Criterio 3 · Páginas y diseño

### R5. Diseño agradable
- **Mostrar:** cartelera con pósters, la página de una película y el mapa de asientos. Reducir el ancho de la ventana (o `F12` > modo dispositivo) para mostrar que es responsivo.

### R6. Todas las páginas necesarias
Recorrer o mencionar: `index.php` (cartelera), `pelicula.php`, `registro.php`, `login.php`, `asientos.php`, `pago.php`, `boletos.php`, `mis_compras.php`, `logout.php` y en `admin/`: `index.php` (panel en vivo), `funciones.php`, `funcion_form.php`, `peliculas.php`, `pelicula_form.php`, `ventas.php`, `log_usuarios.php`, `api_resumen.php`.

### R7. Hechas con PHP/HTML
- **Abrir:** `C:\xampp\htdocs\cine\` en el explorador y abrir `pelicula.php` en el Bloc de notas: PHP con HTML, conexión `pdo_sqlsrv` en `includes\db.php`.
- **Mostrar:** `includes\config.php`, el único archivo con credenciales.

## Criterio 4 · Funcionalidad

### R8. Cartelera desde el inicio
- **Navegador A, sin sesión:** `http://localhost/cine/` muestra las películas en exhibición con próximos horarios.

### R9. Registro e inicio de sesión
1. *Crear cuenta*: Nombre `Revisor`, Apellidos `De Prueba`, correo `revisor@correo.test`, contraseña `Revisor#2026` (dos veces).
2. Mensaje: *Tu cuenta quedó creada*. Iniciar sesión con esos datos.
3. **En SSMS:** `SELECT UsuarioID, Correo, Rol, PasswordHash, Sal, FechaRegistro FROM CineAuroraDB.dbo.Usuarios WHERE Correo = 'revisor@correo.test';` → el registro existe y la contraseña está como hash.
4. Probar una contraseña incorrecta: *Correo o contraseña incorrectos*.

### R10. Página de película, asientos, pago y boletos; nada se vende sin sesión
1. **Sin sesión (navegador A):** abrir una película y pulsar un horario → redirige a *Iniciar sesión* con el aviso *Inicia sesión o crea una cuenta para comprar boletos*. Escribir a mano `http://localhost/cine/asientos.php?funcion=1` → también pide sesión (bloqueo en el servidor, no solo en el botón).
2. Iniciar sesión con `sofia.martinez@correo.test` / `Cliente#Sofia2026`.
3. Abrir una película: se ven **todos** sus horarios agrupados por día, con sala, formato, precio y lugares disponibles.
4. Elegir un horario: el mapa distingue **disponible**, **tu selección**, **ocupado** y **comprado por ti**. Elegir 3 asientos.
5. *Continuar al pago*: escoger **Visa**, número `4111 1111 1111 1111`, titular `SOFIA MARTINEZ`, vencimiento futuro, CVV `123`. Mostrar antes un error: `4111 1111 1111 1112` → *falla el dígito verificador* (Luhn).
6. *Pagar*: aparecen los boletos con código de barras. Pulsar **Imprimir boletos** (vista de impresión limpia).
7. Volver al mapa de esa función: los 3 asientos aparecen como ocupados (★ tuyos).
8. **Límite de 10:** cerrar sesión, entrar como `luis.hernandez@correo.test` / `Cliente#Luis2026`, abrir la URL anotada en el paso 2 de la preparación. Aviso: *Ya tienes 8 boleto(s) … Puedes comprar 2 más*; el mapa no deja elegir un tercero. Comprar 2 → después el mapa queda bloqueado (*que es el máximo permitido*).

### R11. Módulo de administrador
1. **Navegador B:** entrar con `admin@cineaurora.test` / `Admin#Aurora2026` → *Panel en vivo*.
2. **Tiempo real:** con el panel visible, hacer una compra en el navegador A. En menos de 5 segundos cambian *Total recaudado*, *Boletos vendidos* y la tabla *Funciones vendidas*.
3. *Funciones y horarios* > **Agregar función**: elegir película, *Sala 1*, mañana a las 23:45, precio 80 → *Función guardada*. Intentar otra en la misma sala a las 19:00 → la base la rechaza por encimarse.
4. **Editar** esa función: cambiar la hora a 23:50 y el precio → guardado.
5. **Borrar** esa función (no tiene ventas) → *Función eliminada*. Borrar una con ventas → se **retira** y conserva el historial.
6. *Películas* > **Editar** una película y cambiar su **nombre** → la cartelera (navegador A, recargar) muestra el nombre nuevo.
7. *Ventas*: lista de compras con la tarjeta enmascarada (`VISA •••• 1111`).

### R12. Favicon, título propio y apariencia
- **Mostrar:** la pestaña del navegador con el ícono de Cine Aurora y títulos distintos por página (*Cartelera | Cine Aurora*, *Asientos · … | Cine Aurora*, *Panel de administración | Cine Aurora*).

## Criterio 5 · Seguridad y base de datos

### R13. Llaves, índices y restricciones; UNIQUE contra doble venta
- **Ejecutar** el bloque **R13** de `11_consultas_revision.sql`.
- **Resultado:** lista de PK, FK (incluidas las compuestas de `Boletos`), UNIQUE, CHECK e índices. La última consulta intenta insertar un boleto repetido y SQL Server responde **error 2627: Violation of UNIQUE KEY constraint 'UQ_Boletos_Funcion_Asiento'**.
- Opcional: SSMS > *CineAuroraDB* > *Diagramas de base de datos* > *Nuevo diagrama* con todas las tablas.

### R14. Protección contra SQL Injection
1. **En la web (navegador A):** *Iniciar sesión* con correo **`' OR '1'='1' --`** y contraseña **`' OR '1'='1`** → *Correo o contraseña incorrectos*. Repetir con `admin@cineaurora.test' --`.
2. URL manipulada: `http://localhost/cine/pelicula.php?id=1 OR 1=1` → *Película no encontrada* (el parámetro se valida como entero; no aparece ningún error de SQL).
3. **En SSMS:** bloque **R14**: el mismo texto pasado a `app.sp_Login` regresa *Resultado 1*; la tabla `Usuarios` sigue intacta; `cine_app` recibe *SELECT permission was denied* si intenta leer una tabla.
4. **Explicar:** `includes\db.php` arma `EXEC app.sp_X @Param = ?` y enlaza cada valor con `bindValue`; no hay SQL con texto del usuario. Además cada entrada se valida en PHP (`includes\validacion.php`).

### R15. Trigger de log de usuarios nuevos
- **Ejecutar** el bloque **R15**: muestra el trigger `trg_Usuarios_LogAlta`, registra un usuario y consulta `dbo.LogUsuarios`.
- **Resultado:** el usuario nuevo (y `revisor@correo.test` del paso R9, con `LoginBD = cine_app`) aparece en el log con fecha, login, equipo y aplicación. **No hay columnas de contraseña, hash ni sal.**
- También visible en la web: *Administración > Log de usuarios*.

### R16. Usuarios privilegiados desactivados; un solo login SQL para la app
1. **Ejecutar** el bloque **R16**: `sa` aparece con `is_disabled = 1`; el único `SQL_LOGIN` activo es `cine_app` (sin sysadmin); los registros hechos desde la web tienen `LoginBD = cine_app`.
2. **Demostrar:** SSMS > *Conectar* > Autenticación de SQL Server con `sa` → *Login failed for user 'sa'. Reason: The account is disabled.*
3. Mostrar `includes\config.php`: `DB_USER = 'cine_app'`.
4. Explicar permisos: `GRANT EXECUTE ON SCHEMA::app` y `DENY SELECT, INSERT, UPDATE, DELETE` sobre `dbo`. La administración se hace con Autenticación de Windows.

### R17. Tarjetas cifradas (mayor peso)
**Ejecutar** el bloque **R17** paso a paso:
1. `SELECT * FROM dbo.Tarjetas;` → `NumeroCifrado`, `TitularCifrado` y `VencimientoCifrado` solo muestran `0x00…` (VARBINARY). **No hay columna CVV.**
2. Sin abrir la llave, `DECRYPTBYKEY` devuelve **NULL**.
3. Como `cine_app`, `OPEN SYMMETRIC KEY` falla: *Cannot find the symmetric key 'SK_Tarjetas', because it does not exist or you do not have permission.*
4. `app.sp_AdminUltimasVentas` (abre la llave dentro del procedimiento) devuelve solo marca y últimos 4 dígitos.
5. `sys.symmetric_keys` y `sys.certificates`: `SK_Tarjetas` **AES_256** protegida por `Cert_Tarjetas`, que está protegido por la llave maestra.
6. Intentar guardar un número sin cifrar → **error 547**, restricción `CK_Tarjetas_NumeroCifrado`.
- **Explicar:** número, titular y vencimiento se cifran con `ENCRYPTBYKEY` dentro de `app.sp_ComprarBoletos`; el autenticador `UsuarioID` impide copiar el dato cifrado a otra fila; el CVV se valida en PHP y se descarta.

### R18. Login con procedimiento almacenado
- **Ejecutar** el bloque **R18**: `Usuarios` solo tiene `PasswordHash` (64 bytes) y `Sal` (32 bytes); `app.sp_Login` con la contraseña correcta da *Resultado 0* y con otra da *Resultado 1*; la definición de `dbo.fn_HashPassword` usa `HASHBYTES('SHA2_512', @Sal + contraseña)`.
- Abrir `login.php` para mostrar que PHP solo llama `app.sp_Login`; la comparación ocurre dentro de SQL Server. Tras 5 intentos fallidos la cuenta se bloquea 5 minutos.

### R19. Copia de seguridad en vivo
**Opción A (asistente):** SSMS > clic derecho en *CineAuroraDB* > *Tareas* > *Copia de seguridad…* > Tipo *Completa* > Destino *Disco* `C:\Respaldos\CineAurora\Respaldo_Proyecto_3.BAK` > *Opciones de medios*: *Sobrescribir todos los conjuntos de copia de seguridad existentes* y *Comprobar copia de seguridad cuando finalice* > Aceptar.

**Opción B (script):** abrir y ejecutar `sql/09_respaldo.sql`.
- **Resultado:** *BACKUP DATABASE successfully processed …*, *The backup set on file 1 is valid*, y en la carpeta aparecen el `.BAK` y los respaldos de la llave maestra, el certificado (`.cer` + `.pvk`) y la llave simétrica.
- **Explicar:** para restaurar en otra instancia sin perder las tarjetas se usa `10_restaurar_otra_instancia.sql` (abre la llave maestra con su contraseña y la liga a la nueva instancia).

---

## Si algo falla durante la revisión

| Situación | Qué hacer |
|---|---|
| La cartelera está vacía | Ejecutar `12_preparar_revision.sql` |
| Página con *Ocurrió un problema* | Ver `C:\xampp\htdocs\cine\logs\php_errores.log`; casi siempre es SQL Server detenido o TCP/IP |
| Cuenta bloqueada por intentos | Ejecutar `12_preparar_revision.sql` (desbloquea) |
| Se perdió el acceso de administrador a SQL Server | Restaurar el snapshot `03 Listo para revisión` |

## Entrega en Teams (antes del jueves 19 de noviembre de 2026, 5:00 PM)

**Cada integrante** sube:
- `Paginas_Proyecto_3.zip` (carpeta `entregables/` del repositorio)
- `Respaldo_Proyecto_3.BAK` (generado en la VM con el script 09)
- `Presentación_Proyecto_3.pptx` (carpeta `presentacion/`)

> La rúbrica general del PIA pide los nombres `PIA_(#Equipo)_LSBD.zip` y `BD_(#Equipo)_LSBD.BAK`, es decir `PIA_3_LSBD.zip` y `BD_3_LSBD.BAK`. Confirmen con el profesor qué nombre espera; si hay duda, suban ambas copias con los dos nombres.

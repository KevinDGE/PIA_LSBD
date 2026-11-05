# Guía de instalación · Cine Aurora (PIA LSBD, Equipo 3)

Pasos en orden para dejar funcionando el sistema en una **máquina virtual local con Windows Server 2022**, **SQL Server 2022 Express**, **Apache de XAMPP** y **PHP con los drivers oficiales de Microsoft**.

> Tiempo aproximado: 2 a 3 horas (la mayor parte es instalar Windows Server).
> Todo se hace dentro de la VM. Al final, el sitio queda en `http://localhost/cine/`.

## 0. Versiones compatibles

| Componente | Versión recomendada | Notas |
|---|---|---|
| Hipervisor | VirtualBox 7.x o VMware Workstation Pro 17 | Cualquiera de los dos sirve (R2) |
| Sistema operativo | Windows Server 2022 Standard **Evaluation (Experiencia de escritorio)** | ISO gratuita de 180 días del Microsoft Evaluation Center |
| Motor de base de datos | SQL Server 2022 **Express** (16.x) | Instancia `SQLEXPRESS` |
| Herramienta de administración | SQL Server Management Studio (SSMS) 20 o 21 | |
| Servidor web | XAMPP para Windows **8.2.x** (probado en diseño con 8.2.12: Apache 2.4.58 + PHP 8.2.12 x64 Thread Safe) | |
| Driver ODBC | Microsoft ODBC Driver **18** for SQL Server (x64) | También funciona el 17 |
| Drivers de PHP | Microsoft Drivers for PHP for SQL Server **5.12** (`SQLSRV512.ZIP`) | Soporta PHP 8.1, 8.2 y 8.3. Se usa `pdo_sqlsrv` |
| Paquete de Visual C++ | Microsoft Visual C++ Redistributable 2015-2022 (x64) | Lo piden XAMPP y el ODBC |

**Regla de oro de los drivers:** el archivo `.dll` debe coincidir con la **versión de PHP**, con **Thread Safe (ts)** y con **x64**. XAMPP usa PHP *Thread Safe* x64, así que para PHP 8.2 los archivos son `php_pdo_sqlsrv_82_ts_x64.dll` y `php_sqlsrv_82_ts_x64.dll`.

## 1. Máquina virtual con Windows Server 2022 (R2)

1. Descarga la ISO de *Windows Server 2022 Evaluation* (Microsoft Evaluation Center).
2. Crea la VM:
   - VirtualBox: *Nueva* > Tipo *Microsoft Windows*, Versión *Windows 2022 (64-bit)*. 2 CPU, **4 a 6 GB de RAM**, disco de **60 GB**. Marca "Omitir instalación desatendida" si quieres elegir la edición a mano.
   - VMware: *Create a New Virtual Machine* > *Typical* > ISO > *Windows Server 2022*. Mismos recursos.
3. Instala eligiendo **Windows Server 2022 Standard Evaluation (Experiencia de escritorio)**. Sin "Experiencia de escritorio" no hay interfaz gráfica.
4. Define la contraseña del usuario `Administrador` y anótala.
5. Instala *Guest Additions* (VirtualBox) o *VMware Tools* para tener pantalla completa y portapapeles.
6. Cambia el nombre del equipo si quieres (por ejemplo `SRV-CINE`) y reinicia.
7. Pon la zona horaria en *(UTC-06:00) Guadalajara, Ciudad de México, Monterrey*. La cartelera usa la hora del servidor.
8. **Toma un snapshot** llamado `01 Windows limpio`.

## 2. SQL Server 2022 Express (R3)

1. Descarga `SQL2022-SSEI-Expr.exe` desde la página de descargas de SQL Server de Microsoft y ejecútalo.
2. Elige **Personalizada** (Custom). Así puedes escoger el modo de autenticación durante la instalación.
3. En el *Centro de instalación*: *Nueva instalación independiente de SQL Server*.
4. Características: *Servicios de Motor de base de datos* (lo demás es opcional).
5. Instancia con nombre: **SQLEXPRESS** (valor por defecto).
6. **Configuración del motor de base de datos > Configuración del servidor**:
   - Selecciona **Modo mixto (autenticación de SQL Server y de Windows)**. La aplicación entra con un login de SQL Server (`cine_app`).
   - Escribe una contraseña para `sa` (se desactiva más adelante con el script 08; anótala de todos modos).
   - En *Especificar administradores de SQL Server* pulsa **Agregar usuario actual** (`SRV-CINE\Administrador`). **Esta es la vía de administración** que queda cuando se desactive `sa`.
7. Termina la instalación.
8. Instala **SSMS** (SQL Server Management Studio) y conéctate con *Servidor:* `localhost\SQLEXPRESS`, *Autenticación:* **Autenticación de Windows**.

### 2.1 Si ya tenías SQL Server instalado solo con autenticación de Windows

En SSMS: clic derecho en el servidor > *Propiedades* > *Seguridad* > **Modo de autenticación de SQL Server y de Windows** > Aceptar. Después reinicia el servicio (clic derecho en el servidor > *Reiniciar*). Sin el reinicio el login `cine_app` falla con *Login failed*.

### 2.2 Habilitar TCP/IP en el puerto 1433

La aplicación se conecta a `127.0.0.1,1433`.

1. Abre **SQL Server 2022 Configuration Manager** (si no aparece en el menú, ejecuta `SQLServerManager16.msc`).
2. *Configuración de red de SQL Server* > *Protocolos de SQLEXPRESS* > **TCP/IP** > clic derecho > **Habilitar**.
3. Doble clic en *TCP/IP* > pestaña *Direcciones IP* > sección **IPAll**:
   - *Puertos dinámicos TCP*: **vacío** (borra el 0 o el número que tenga).
   - *Puerto TCP*: **1433**.
4. *Servicios de SQL Server* > **SQL Server (SQLEXPRESS)** > *Reiniciar*.
5. Comprueba en PowerShell: `Test-NetConnection 127.0.0.1 -Port 1433` debe decir `TcpTestSucceeded : True`.

No hace falta abrir el firewall: Apache y SQL Server están en la misma VM.

**Alternativa sin puerto fijo:** deja el puerto dinámico, inicia el servicio *SQL Server Browser* y en `config.php` usa `DB_SERVER = 'localhost\SQLEXPRESS'`.

## 3. Base de datos y seguridad (scripts SQL)

Abre cada archivo de la carpeta `sql/` en SSMS (conectado con **Autenticación de Windows**) y ejecútalo con F5, **en este orden**:

| # | Script | Qué hace |
|---|---|---|
| 01 | `01_crear_base.sql` | Crea `CineAuroraDB` (dueño `sa`), modo de recuperación FULL y esquema `app` |
| 02 | `02_tablas.sql` | Tablas, PK, FK (incluidas compuestas), UNIQUE, CHECK e índices |
| 03 | `03_datos_ejemplo.sql` | 3 salas, 296 asientos, 6 películas ficticias y funciones para 21 días |
| 04 | `04_cifrado.sql` | Llave maestra, certificado, llave simétrica AES_256 y restricción de datos cifrados |
| 05 | `05_procedimientos.sql` | Funciones y 24 procedimientos del esquema `app` (incluye login y compra) |
| 06 | `06_triggers.sql` | Trigger de log de usuarios y trigger de máximo 10 boletos |
| 07 | `07_datos_demo.sql` | Usuarios de prueba y 4 compras de ejemplo (pasan por los procedimientos) |
| 08 | `08_usuarios_permisos.sql` | Crea `cine_app` con mínimo privilegio y **desactiva `sa`** |
| 09 | `09_respaldo.sql` | Respalda llave maestra, certificado, llave simétrica y la base (.BAK) |
| 10 | `10_restaurar_otra_instancia.sql` | Solo si restauras en otra instancia |
| 11 | `11_consultas_revision.sql` | Consultas de evidencia para la revisión (por bloques) |
| 12 | `12_preparar_revision.sql` | El día de la revisión: completa funciones y deja listo el caso del límite de 10 |

Antes de ejecutar, **cambia las contraseñas** si quieres que no sean las del repositorio:

- `04_cifrado.sql`: contraseña de la llave maestra (`Aurora#LlaveMaestra_2026!`). Si la cambias, cámbiala también en `10_restaurar_otra_instancia.sql`.
- `08_usuarios_permisos.sql` **y** `htdocs/cine/includes/config.php`: contraseña de `cine_app` (deben ser iguales).
- `09_respaldo.sql`: contraseñas de los archivos de respaldo de llaves.

### 3.1 Antes del script 08: snapshot y vía de administración

El script 08 desactiva `sa` y cualquier otro login SQL que no sea `cine_app`.

1. **Toma un snapshot de la VM** llamado `02 Antes de desactivar sa` (VirtualBox: *Máquina > Tomar instantánea*; VMware: *VM > Snapshot > Take Snapshot*).
2. Verifica que tu usuario de Windows es sysadmin: en SSMS, *Seguridad > Inicios de sesión* debe aparecer `SRV-CINE\Administrador` y en sus *Propiedades > Roles de servidor* estar marcado **sysadmin**. También puedes ejecutar `SELECT IS_SRVROLEMEMBER('sysadmin');` (debe dar 1).
3. Ejecuta el script **conectado con Autenticación de Windows**. Si no encuentra un login de Windows sysadmin activo, o si estás conectado con un login SQL, **se detiene sin cambiar nada** y te dice por qué.

### 3.2 Si se pierde el acceso de administrador

- **Lo más rápido:** restaura el snapshot `02 Antes de desactivar sa`.
- **Modo de un solo usuario** (cualquier administrador local de Windows entra como sysadmin):
  1. PowerShell como administrador: `net stop "MSSQL$SQLEXPRESS"`
  2. `net start "MSSQL$SQLEXPRESS" /m"SQLCMD"`
  3. `sqlcmd -S .\SQLEXPRESS -E`
  4. `CREATE LOGIN [SRV-CINE\Administrador] FROM WINDOWS;` (si no existe) y `ALTER SERVER ROLE sysadmin ADD MEMBER [SRV-CINE\Administrador];` y luego `GO`.
  5. `net stop "MSSQL$SQLEXPRESS"` y `net start "MSSQL$SQLEXPRESS"`.

## 4. XAMPP con Apache (R4)

1. Instala el **Visual C++ Redistributable 2015-2022 x64**.
2. Descarga **XAMPP para Windows 8.2.x** e instálalo en `C:\xampp` (ruta por defecto). Componentes mínimos: *Apache* y *PHP*.
3. Abre el **XAMPP Control Panel** como administrador.
4. Marca la casilla **Service** junto a Apache para instalarlo como servicio de Windows (así queda activo al reiniciar la VM) y pulsa **Start**.
5. Comprueba `http://localhost/` en el navegador de la VM: debe abrir la página de bienvenida de XAMPP.
6. Si el puerto 80 está ocupado (por ejemplo, IIS), detén el servicio *World Wide Web Publishing Service* o cambia `Listen 80` en `C:\xampp\apache\conf\httpd.conf`.

## 5. Drivers de Microsoft para PHP

1. Instala **Microsoft ODBC Driver 18 for SQL Server (x64)** (`msodbcsql.msi`).
2. Descarga **Microsoft Drivers for PHP for SQL Server 5.12** (`SQLSRV512.ZIP`) y descomprímelo.
3. Revisa tu PHP: en `C:\xampp\php` ejecuta `php -v` (versión) y `php -i | findstr "Thread"` (debe decir *Thread Safety => enabled*).
4. Copia a `C:\xampp\php\ext\` los dos archivos que coinciden (para XAMPP 8.2: `php_pdo_sqlsrv_82_ts_x64.dll` y `php_sqlsrv_82_ts_x64.dll`).
5. Edita `C:\xampp\php\php.ini` (XAMPP Control Panel > Apache > *Config* > *PHP (php.ini)*) y agrega al final de la sección de extensiones:

   ```ini
   extension=php_pdo_sqlsrv_82_ts_x64.dll
   extension=php_sqlsrv_82_ts_x64.dll
   ```

   y revisa estos valores:

   ```ini
   date.timezone=America/Monterrey
   display_errors=Off
   extension=mbstring
   ```

6. Reinicia Apache desde el Control Panel.
7. Verifica: `C:\xampp\php\php -m` debe listar `pdo_sqlsrv` y `sqlsrv`. Si aparece *Unable to load dynamic library*, el `.dll` no coincide con la versión de PHP, con *ts* o con *x64*, o falta el ODBC Driver.

## 6. Páginas del portal

1. Copia la carpeta `htdocs/cine` del repositorio (o del zip `Paginas_Proyecto_3.zip`) a **`C:\xampp\htdocs\cine`**.
2. Si cambiaste la contraseña de `cine_app`, edita `C:\xampp\htdocs\cine\includes\config.php` (es el **único** archivo con credenciales).
3. Da permiso de escritura a la carpeta `C:\xampp\htdocs\cine\logs` (ahí PHP guarda los errores; con el usuario Administrador ya lo tiene).
4. Abre `http://localhost/cine/`. Debes ver la cartelera con las 6 películas.
5. Prueba que lo protegido está bloqueado: `http://localhost/cine/includes/config.php` debe responder **403 Forbidden** (lo hace `includes/.htaccess`; XAMPP trae `AllowOverride All` en `htdocs`).

## 7. Comprobación final

1. Inicia sesión con `ana.garcia@correo.test` / `Cliente#Ana2026` (ver `CREDENCIALES_PRUEBA.md`), compra un boleto con la Visa de prueba e imprime.
2. Inicia sesión con `admin@cineaurora.test` / `Admin#Aurora2026` y abre *Administración*.
3. Registra un usuario nuevo desde la web y en SSMS ejecuta `SELECT TOP 3 Correo, LoginBD, Aplicacion FROM CineAuroraDB.dbo.LogUsuarios ORDER BY LogID DESC;`: el registro hecho desde la web muestra `LoginBD = cine_app` y `Aplicacion = CineAuroraWeb` (la web entra con ese login y con conexión cifrada por TLS).
4. Ejecuta `09_respaldo.sql` y copia `C:\Respaldos\CineAurora\Respaldo_Proyecto_3.BAK` al escritorio para subirlo a Teams.
5. **Toma un snapshot** `03 Listo para revisión`.

## 8. Problemas frecuentes

| Mensaje en `htdocs\cine\logs\php_errores.log` | Causa y solución |
|---|---|
| `could not find driver` | `pdo_sqlsrv` no cargó: revisa el paso 5 (versión, ts, x64) y reinicia Apache |
| `This extension requires the Microsoft ODBC Driver for SQL Server` | Falta instalar el ODBC Driver 18 (x64) |
| `Login failed for user 'cine_app'` | No está activo el modo mixto o no reiniciaste el servicio; o la contraseña de `config.php` no coincide con la del script 08 |
| `TCP Provider: No connection could be made` / `Login timeout expired` | TCP/IP deshabilitado o el puerto no es 1433 (paso 2.2) |
| `SSL Provider: The certificate chain was issued by an authority that is not trusted` | Falta `DB_TRUST_CERT = true` en `config.php` (ya viene así) |
| `Cannot execute as the database principal because the principal "dbo" does not exist` | La base se restauró en otra instancia sin cambiar el dueño: ejecuta `10_restaurar_otra_instancia.sql` |
| La cartelera sale vacía | Las funciones ya pasaron: ejecuta `12_preparar_revision.sql` |
| "Cuenta bloqueada por intentos fallidos" | Espera 5 minutos o ejecuta `12_preparar_revision.sql` (desbloquea cuentas) |

## 9. Respaldo del certificado y llaves, y restauración en otra instancia

**Por qué importa:** las tarjetas están cifradas con la llave `SK_Tarjetas`, protegida por el certificado `Cert_Tarjetas`, que a su vez está protegido por la llave maestra de la base (DMK). La DMK está cifrada con su contraseña **y** con la *Service Master Key* de la instancia. El `.BAK` contiene todo eso, pero en otra instancia la Service Master Key es distinta, así que la DMK no se abre sola y no se pueden descifrar ni cifrar tarjetas.

**Qué guardar fuera de la VM** (USB o nube del equipo):

1. Los archivos que genera `09_respaldo.sql` en `C:\Respaldos\CineAurora\`: `DMK_CineAuroraDB_*.key`, `Cert_Tarjetas_*.cer`, `Cert_Tarjetas_*.pvk`, `SK_Tarjetas_*.key` y `Respaldo_Proyecto_3.BAK`.
2. Las contraseñas: la de la DMK (script 04) y las de los archivos (script 09).

**Restaurar en otra instancia:** copia el `.BAK`, ajusta la ruta en `10_restaurar_otra_instancia.sql` y ejecútalo. El script restaura la base, deja a `sa` como dueño, abre la DMK con su contraseña y la vuelve a proteger con la Service Master Key nueva (`ALTER MASTER KEY ADD ENCRYPTION BY SERVICE MASTER KEY`), comprueba que las tarjetas se descifran y vuelve a ligar el usuario `cine_app`. Si se perdió la contraseña de la DMK, el mismo script trae el **Plan B** con `RESTORE MASTER KEY FROM FILE`. Después ejecuta `08_usuarios_permisos.sql` en esa instancia.

Esta restauración se probó en el banco de pruebas: el `.BAK` se restauró en una segunda instancia de SQL Server 2022 Express, las 4 tarjetas de ejemplo se descifraron y `cine_app` pudo comprar y consultar compras.

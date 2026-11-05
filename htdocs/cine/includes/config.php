<?php
/* =====================================================================
   config.php · ÚNICO archivo con las credenciales y ajustes del sitio.
   La carpeta includes/ está bloqueada para el navegador (.htaccess).
   ===================================================================== */
if (!defined('CINE_APP')) {
    http_response_code(403);
    exit;
}

/* ---- Conexión a SQL Server 2022 Express ----
   127.0.0.1,1433 requiere TCP/IP habilitado en el puerto fijo 1433
   (ver GUIA_INSTALACION.md). Alternativa con SQL Browser: 'localhost\SQLEXPRESS'. */
define('DB_SERVER', '127.0.0.1,1433');
define('DB_NAME',   'CineAuroraDB');
define('DB_USER',   'cine_app');               // único login tipo SQL Server (script 08)
define('DB_PASS',   'C1ne#Aurora_App2026');    // debe coincidir con 08_usuarios_permisos.sql
// ODBC Driver 18 cifra la conexión por defecto; en la VM local el certificado
// del servidor es autofirmado, por eso se confía en él explícitamente.
define('DB_ENCRYPT',    true);
define('DB_TRUST_CERT', true);

/* ---- Sitio ---- */
define('SITIO_NOMBRE', 'Cine Aurora');
define('SITIO_LEMA',   'Historias que iluminan la noche');
define('EQUIPO',       'Equipo 3 · LSBD · FCFM UANL');
define('ZONA_HORARIA', 'America/Monterrey');
define('MAX_BOLETOS_FUNCION', 10);
define('SESION_INACTIVIDAD_MIN', 30);

/* ---- Errores: nunca se muestran al usuario; se guardan en logs/ ---- */
define('MODO_DEPURACION', false);   // en true solo para desarrollo, nunca en la revisión

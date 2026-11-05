<?php
/* =====================================================================
   app.php · Arranque común de todas las páginas
   ===================================================================== */
define('CINE_APP', true);
require_once __DIR__ . '/config.php';

date_default_timezone_set(ZONA_HORARIA);
mb_internal_encoding('UTF-8');

/* ---- Errores: al log, nunca a la pantalla (R14 / reglas técnicas) ---- */
ini_set('display_errors', MODO_DEPURACION ? '1' : '0');
ini_set('display_startup_errors', '0');
ini_set('log_errors', '1');
ini_set('error_log', dirname(__DIR__) . '/logs/php_errores.log');
error_reporting(E_ALL);

set_exception_handler(function (Throwable $e): void {
    error_log('[' . date('c') . '] ' . get_class($e) . ': ' . $e->getMessage() . ' en ' . $e->getFile() . ':' . $e->getLine());
    if (!headers_sent()) {
        http_response_code(500);
    }
    pagina_error(500, 'Ocurrió un problema', 'No pudimos completar la operación. Intente de nuevo en unos minutos.');
});

require_once __DIR__ . '/db.php';
require_once __DIR__ . '/seguridad.php';
require_once __DIR__ . '/validacion.php';
require_once __DIR__ . '/plantilla.php';

/* ---- URL base: funciona en http://localhost/cine/ o en cualquier carpeta ---- */
function base_url(): string
{
    static $base = null;
    if ($base === null) {
        $raiz    = str_replace('\\', '/', realpath(dirname(__DIR__)));
        $archivo = str_replace('\\', '/', realpath($_SERVER['SCRIPT_FILENAME'] ?? ''));
        $rel     = substr($archivo, strlen($raiz));                 // /admin/index.php
        $script  = $_SERVER['SCRIPT_NAME'] ?? '';
        $base    = ($rel !== '' && str_ends_with($script, $rel)) ? substr($script, 0, -strlen($rel)) : '';
    }
    return $base;
}

function url(string $ruta = ''): string
{
    return base_url() . '/' . ltrim($ruta, '/');
}

function redirigir(string $ruta): never
{
    header('Location: ' . url($ruta));
    exit;
}

/* ---- Mensajes flash (se muestran una vez) ---- */
function flash(string $tipo, string $mensaje): void
{
    $_SESSION['flash'][] = ['tipo' => $tipo, 'mensaje' => $mensaje];
}

function tomar_flash(): array
{
    $f = $_SESSION['flash'] ?? [];
    unset($_SESSION['flash']);
    return $f;
}

iniciar_sesion_segura();
enviar_cabeceras_seguridad();

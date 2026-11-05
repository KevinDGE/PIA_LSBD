<?php
/* =====================================================================
   seguridad.php · Sesión, CSRF, escape de salida, control de acceso
   ===================================================================== */
if (!defined('CINE_APP')) {
    http_response_code(403);
    exit;
}

/** Escape de toda salida HTML */
function e(mixed $valor): string
{
    return htmlspecialchars((string)($valor ?? ''), ENT_QUOTES | ENT_SUBSTITUTE | ENT_HTML5, 'UTF-8');
}

function iniciar_sesion_segura(): void
{
    if (session_status() === PHP_SESSION_ACTIVE) {
        return;
    }
    $https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off');
    ini_set('session.use_strict_mode', '1');     // no acepta IDs de sesión inventados
    ini_set('session.use_only_cookies', '1');
    ini_set('session.use_trans_sid', '0');
    ini_set('session.sid_length', '48');
    ini_set('session.sid_bits_per_character', '6');
    session_name('CINEAURORA_SID');
    session_set_cookie_params([
        'lifetime' => 0,
        'path'     => base_url() . '/',
        'secure'   => $https,
        'httponly' => true,                     // JavaScript no puede leer la cookie
        'samesite' => 'Lax',
    ]);
    session_start();

    // Expiración por inactividad
    $ahora = time();
    if (isset($_SESSION['uid'], $_SESSION['ultimo']) && $ahora - $_SESSION['ultimo'] > SESION_INACTIVIDAD_MIN * 60) {
        $_SESSION = [];
        session_regenerate_id(true);
        flash('aviso', 'Tu sesión expiró por inactividad. Inicia sesión de nuevo.');
    }
    $_SESSION['ultimo'] = $ahora;

    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(32));
    }
}

function enviar_cabeceras_seguridad(): void
{
    if (headers_sent()) {
        return;
    }
    header("Content-Security-Policy: default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; "
         . "connect-src 'self'; form-action 'self'; frame-ancestors 'none'; base-uri 'self'; object-src 'none'");
    header('X-Frame-Options: DENY');
    header('X-Content-Type-Options: nosniff');
    header('Referrer-Policy: same-origin');
    header('Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()');
    header('Cross-Origin-Opener-Policy: same-origin');
    header_remove('X-Powered-By');
}

/* ---------------- CSRF ---------------- */
function csrf_token(): string
{
    return $_SESSION['csrf'];
}

function csrf_campo(): string
{
    return '<input type="hidden" name="csrf" value="' . e(csrf_token()) . '">';
}

/** Detiene la petición si el token no coincide. Llamar al inicio de todo POST. */
function csrf_verificar(): void
{
    $enviado = $_POST['csrf'] ?? '';
    if (!is_string($enviado) || !hash_equals($_SESSION['csrf'] ?? '', $enviado)) {
        http_response_code(400);
        pagina_error(400, 'Formulario vencido', 'Por seguridad, el formulario expiró o no es válido. Vuelve a la página e inténtalo otra vez.');
    }
}

function exigir_post(): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
        http_response_code(405);
        header('Allow: POST');
        pagina_error(405, 'Método no permitido', 'Esta acción solo se puede enviar desde su formulario.');
    }
    csrf_verificar();
}

/* ---------------- Sesión de usuario ---------------- */
function usuario_actual(): ?array
{
    return isset($_SESSION['uid']) ? [
        'id'     => (int)$_SESSION['uid'],
        'nombre' => (string)$_SESSION['nombre'],
        'rol'    => (string)$_SESSION['rol'],
    ] : null;
}

function es_admin(): bool
{
    return (usuario_actual()['rol'] ?? '') === 'ADMIN';
}

function iniciar_sesion_usuario(array $u): void
{
    session_regenerate_id(true);                 // evita fijación de sesión
    $_SESSION['uid']    = (int)$u['UsuarioID'];
    $_SESSION['nombre'] = (string)$u['Nombre'];
    $_SESSION['rol']    = (string)$u['Rol'];
    $_SESSION['inicio'] = time();
    $_SESSION['ultimo'] = time();
    $_SESSION['csrf']   = bin2hex(random_bytes(32));
}

function cerrar_sesion_usuario(): void
{
    $_SESSION = [];
    if (ini_get('session.use_cookies')) {
        $p = session_get_cookie_params();
        setcookie(session_name(), '', [
            'expires' => time() - 42000, 'path' => $p['path'], 'secure' => $p['secure'],
            'httponly' => $p['httponly'], 'samesite' => $p['samesite'],
        ]);
    }
    session_destroy();
}

/** Ruta interna segura para volver después del login (evita redirecciones abiertas) */
function ruta_retorno(?string $ruta): string
{
    $ruta = (string)$ruta;
    return preg_match('#^[a-z_]+\.php(\?[a-z_]+=\d+)?$#', $ruta) ? $ruta : 'index.php';
}

/**
 * Exige sesión iniciada. Además revalida en la base que el usuario siga activo
 * y toma el rol de la base (no solo de la sesión).
 */
function requerir_login(?string $volverA = null): array
{
    $u = usuario_actual();
    if ($u === null) {
        flash('aviso', 'Inicia sesión o crea una cuenta para comprar boletos.');
        redirigir('login.php' . ($volverA ? '?volver=' . rawurlencode($volverA) : ''));
    }
    $fila = sp_fila('app.sp_ValidarSesion', ['UsuarioID' => $u['id']]);
    if ($fila === null) {
        cerrar_sesion_usuario();
        iniciar_sesion_segura();
        flash('error', 'Tu cuenta ya no está activa.');
        redirigir('login.php');
    }
    $_SESSION['rol']    = $fila['Rol'];
    $_SESSION['nombre'] = $fila['Nombre'];
    return usuario_actual();
}

/** Exige rol ADMIN validado contra la base en cada página protegida */
function requerir_admin(): array
{
    $u = requerir_login();
    if ($u['rol'] !== 'ADMIN') {
        http_response_code(403);
        pagina_error(403, 'Acceso restringido', 'Esta sección es solo para administradores.');
    }
    header('Cache-Control: no-store');
    return $u;
}

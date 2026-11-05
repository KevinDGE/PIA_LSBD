<?php
/* =====================================================================
   plantilla.php · Encabezado, pie, formato de fechas y dinero
   ===================================================================== */
if (!defined('CINE_APP')) {
    http_response_code(403);
    exit;
}

const DIAS  = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
const MESES = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
               'septiembre', 'octubre', 'noviembre', 'diciembre'];

function fecha_obj(mixed $f): DateTimeImmutable
{
    if ($f instanceof DateTimeInterface) {
        return DateTimeImmutable::createFromInterface($f);
    }
    return new DateTimeImmutable((string)$f);
}

/** "jueves 19 de noviembre" */
function fecha_larga(mixed $f): string
{
    $d = fecha_obj($f);
    return DIAS[(int)$d->format('w')] . ' ' . $d->format('j') . ' de ' . MESES[(int)$d->format('n')];
}

/** "Hoy", "Mañana" o "jue 19 nov" */
function fecha_corta(mixed $f): string
{
    $d = fecha_obj($f);
    $hoy = new DateTimeImmutable('today');
    $dia = $d->setTime(0, 0);
    if ($dia == $hoy) {
        return 'Hoy';
    }
    if ($dia == $hoy->modify('+1 day')) {
        return 'Mañana';
    }
    return mb_substr(DIAS[(int)$d->format('w')], 0, 3) . ' ' . $d->format('j') . ' ' . mb_substr(MESES[(int)$d->format('n')], 0, 3);
}

function hora(mixed $f): string
{
    return fecha_obj($f)->format('H:i');
}

function dinero(mixed $v): string
{
    return '$' . number_format((float)$v, 2, '.', ',');
}

function poster_url(string $archivo): string
{
    return url('assets/img/posters/' . rawurlencode($archivo));
}

function clasificacion_desc(string $c): string
{
    return [
        'AA' => 'Para todo público, atractiva para niños', 'A' => 'Para todo público',
        'B' => 'Adolescentes y adultos', 'B15' => 'Mayores de 15 años',
        'C' => 'Mayores de 18 años', 'D' => 'Solo adultos',
    ][$c] ?? $c;
}

function idioma_txt(string $i): string
{
    return $i === 'SUBTITULADA' ? 'Subtitulada' : 'Doblada';
}

/** Lista de pósters disponibles (lista blanca para el formulario de películas) */
function posters_disponibles(): array
{
    $archivos = glob(dirname(__DIR__) . '/assets/img/posters/*.svg') ?: [];
    $nombres = array_map('basename', $archivos);
    return array_values(array_filter($nombres, fn($n) => preg_match('/^[a-z0-9][a-z0-9._-]*\.svg$/', $n)));
}

/* ---------------- Encabezado y pie ---------------- */

function encabezado(string $titulo, string $seccion = '', array $op = []): void
{
    $u = usuario_actual();
    $esAdminPag = !empty($op['admin']);
    $clases = trim(($op['clase'] ?? '') . ($esAdminPag ? ' pagina-admin' : ''));
    if ($u !== null) {
        header('Cache-Control: no-store');
    }
    ?>
<!DOCTYPE html>
<html lang="es-MX">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= e($titulo) ?> | <?= e(SITIO_NOMBRE) ?></title>
<meta name="description" content="<?= e(SITIO_NOMBRE . ' · ' . SITIO_LEMA) ?>">
<meta name="theme-color" content="#12101f">
<link rel="icon" href="<?= e(url('favicon.ico')) ?>" sizes="32x32">
<link rel="icon" href="<?= e(url('assets/img/favicon.svg')) ?>" type="image/svg+xml">
<link rel="apple-touch-icon" href="<?= e(url('assets/img/apple-touch-icon.png')) ?>">
<link rel="stylesheet" href="<?= e(url('assets/css/estilos.css')) ?>">
<script src="<?= e(url('assets/js/app.js')) ?>" defer></script>
<?php foreach (($op['scripts'] ?? []) as $js): ?>
<script src="<?= e(url('assets/js/' . $js)) ?>" defer></script>
<?php endforeach; ?>
</head>
<body class="<?= e($clases) ?>">
<a class="saltar" href="#contenido">Saltar al contenido</a>
<header class="barra">
  <div class="contenedor barra-int">
    <a class="marca" href="<?= e(url('index.php')) ?>" aria-label="<?= e(SITIO_NOMBRE) ?>, ir a la cartelera">
      <img src="<?= e(url('assets/img/logo.svg')) ?>" alt="" width="36" height="36">
      <span><?= e(SITIO_NOMBRE) ?></span>
    </a>
    <button class="menu-btn" type="button" aria-expanded="false" aria-controls="menu-principal" data-menu>
      <span class="sr">Abrir menú</span><span aria-hidden="true">☰</span>
    </button>
    <nav id="menu-principal" class="menu" aria-label="Principal">
      <a href="<?= e(url('index.php')) ?>" class="<?= $seccion === 'cartelera' ? 'activo' : '' ?>">Cartelera</a>
      <?php if ($u): ?>
        <a href="<?= e(url('mis_compras.php')) ?>" class="<?= $seccion === 'compras' ? 'activo' : '' ?>">Mis boletos</a>
        <?php if ($u['rol'] === 'ADMIN'): ?>
          <a href="<?= e(url('admin/index.php')) ?>" class="<?= str_starts_with($seccion, 'admin') ? 'activo' : '' ?>">Administración</a>
        <?php endif; ?>
        <span class="menu-usuario" title="Sesión iniciada">👤 <?= e($u['nombre']) ?></span>
        <form method="post" action="<?= e(url('logout.php')) ?>" class="form-salir">
          <?= csrf_campo() ?>
          <button type="submit" class="btn btn-borde btn-chico">Cerrar sesión</button>
        </form>
      <?php else: ?>
        <a href="<?= e(url('login.php')) ?>" class="<?= $seccion === 'login' ? 'activo' : '' ?>">Iniciar sesión</a>
        <a href="<?= e(url('registro.php')) ?>" class="btn btn-primario btn-chico">Crear cuenta</a>
      <?php endif; ?>
    </nav>
  </div>
  <?php if ($esAdminPag): ?>
  <nav class="subnav" aria-label="Administración">
    <div class="contenedor">
      <a href="<?= e(url('admin/index.php')) ?>" class="<?= $seccion === 'admin' ? 'activo' : '' ?>">Panel en vivo</a>
      <a href="<?= e(url('admin/funciones.php')) ?>" class="<?= $seccion === 'admin-funciones' ? 'activo' : '' ?>">Funciones y horarios</a>
      <a href="<?= e(url('admin/peliculas.php')) ?>" class="<?= $seccion === 'admin-peliculas' ? 'activo' : '' ?>">Películas</a>
      <a href="<?= e(url('admin/ventas.php')) ?>" class="<?= $seccion === 'admin-ventas' ? 'activo' : '' ?>">Ventas</a>
      <a href="<?= e(url('admin/log_usuarios.php')) ?>" class="<?= $seccion === 'admin-log' ? 'activo' : '' ?>">Log de usuarios</a>
    </div>
  </nav>
  <?php endif; ?>
</header>
<main id="contenido" class="<?= e($op['main'] ?? 'contenedor') ?>">
<?php foreach (tomar_flash() as $f): ?>
  <div class="alerta alerta-<?= e($f['tipo']) ?>" role="status"><?= e($f['mensaje']) ?></div>
<?php endforeach;
}

function pie(): void
{
    ?>
</main>
<footer class="pie">
  <div class="contenedor pie-int">
    <div>
      <strong><?= e(SITIO_NOMBRE) ?></strong> · <?= e(SITIO_LEMA) ?><br>
      <small>Proyecto académico con datos ficticios. No se realizan cobros reales.</small>
    </div>
    <div class="pie-der"><small><?= e(EQUIPO) ?></small></div>
  </div>
</footer>
</body>
</html>
<?php
}

/** Página de error completa y fin de la petición. Nunca muestra detalles técnicos. */
function pagina_error(int $codigo, string $titulo, string $mensaje): never
{
    if (!headers_sent()) {
        http_response_code($codigo);
    }
    if (!function_exists('url') || session_status() !== PHP_SESSION_ACTIVE) {
        echo '<!DOCTYPE html><html lang="es-MX"><head><meta charset="utf-8"><title>Error | Cine Aurora</title></head><body><h1>'
            . e($titulo) . '</h1><p>' . e($mensaje) . '</p></body></html>';
        exit;
    }
    encabezado($titulo);
    ?>
  <section class="vacio">
    <div class="vacio-icono" aria-hidden="true">🎬</div>
    <h1><?= e($titulo) ?></h1>
    <p><?= e($mensaje) ?></p>
    <p><a class="btn btn-primario" href="<?= e(url('index.php')) ?>">Volver a la cartelera</a></p>
  </section>
<?php
    pie();
    exit;
}

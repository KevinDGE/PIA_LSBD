<?php
/* Página individual de una película con todos sus horarios (R10) */
require __DIR__ . '/includes/app.php';

$id = entero_positivo($_GET['id'] ?? null);
$peli = $id ? sp_fila('app.sp_DetallePelicula', ['PeliculaID' => $id]) : null;
if ($peli === null) {
    pagina_error(404, 'Película no encontrada', 'La película que buscas no existe o ya no está en cartelera.');
}
$funciones = sp_filas('app.sp_FuncionesPelicula', ['PeliculaID' => $id]);

// Agrupar por día
$porDia = [];
foreach ($funciones as $f) {
    $porDia[substr((string)$f['FechaHora'], 0, 10)][] = $f;
}
$u = usuario_actual();

encabezado($peli['Titulo'], 'cartelera', ['main' => 'detalle']);
?>
<section class="detalle-hero">
  <div class="detalle-fondo" aria-hidden="true"><img src="<?= e(poster_url($peli['Imagen'])) ?>" alt=""></div>
  <div class="contenedor detalle-int">
    <img class="detalle-poster" src="<?= e(poster_url($peli['Imagen'])) ?>" alt="Póster de <?= e($peli['Titulo']) ?>" width="400" height="600">
    <div class="detalle-texto">
      <p class="migas"><a href="<?= e(url('index.php')) ?>">Cartelera</a> / <?= e($peli['Titulo']) ?></p>
      <h1><?= e($peli['Titulo']) ?></h1>
      <p class="hero-meta">
        <span class="clasif clasif-<?= e(strtolower($peli['Clasificacion'])) ?>"><?= e($peli['Clasificacion']) ?></span>
        <?= e(clasificacion_desc($peli['Clasificacion'])) ?>
      </p>
      <dl class="ficha">
        <div><dt>Género</dt><dd><?= e($peli['Genero']) ?></dd></div>
        <div><dt>Duración</dt><dd><?= (int)$peli['DuracionMin'] ?> min</dd></div>
        <div><dt>Dirección</dt><dd><?= e($peli['Director']) ?></dd></div>
        <div><dt>Estreno</dt><dd><?= e(fecha_larga($peli['FechaEstreno'])) ?></dd></div>
      </dl>
      <p class="sinopsis"><?= e($peli['Sinopsis']) ?></p>
    </div>
  </div>
</section>

<section class="contenedor seccion" id="horarios">
  <div class="seccion-titulo">
    <h2>Horarios</h2>
    <?php if (!$u): ?>
      <p class="aviso-login">🔒 Para comprar necesitas <a href="<?= e(url('login.php?volver=' . rawurlencode('pelicula.php?id=' . $id))) ?>">iniciar sesión</a> o <a href="<?= e(url('registro.php')) ?>">crear una cuenta</a>.</p>
    <?php else: ?>
      <p>Elige una función para ver el mapa de asientos.</p>
    <?php endif; ?>
  </div>

  <?php if (!$porDia): ?>
    <div class="vacio"><p>No hay funciones programadas para esta película.</p></div>
  <?php endif; ?>

  <?php foreach ($porDia as $dia => $lista): ?>
  <div class="dia">
    <h3 class="dia-titulo"><?= e(fecha_corta($dia)) ?> <small><?= e(fecha_larga($dia)) ?></small></h3>
    <div class="horarios">
      <?php foreach ($lista as $f): $disp = (int)$f['Disponibles']; ?>
        <?php if ($disp > 0): ?>
        <a class="horario" href="<?= e(url('asientos.php?funcion=' . (int)$f['FuncionID'])) ?>">
        <?php else: ?>
        <span class="horario agotado" aria-disabled="true">
        <?php endif; ?>
          <strong><?= e(hora($f['FechaHora'])) ?></strong>
          <span><?= e($f['Sala']) ?> · <?= e($f['Formato']) ?> · <?= e(idioma_txt($f['Idioma'])) ?></span>
          <span class="horario-pie"><?= e(dinero($f['Precio'])) ?> · <?= $disp > 0 ? $disp . ' lugares' : 'Agotado' ?></span>
        <?= $disp > 0 ? '</a>' : '</span>' ?>
      <?php endforeach; ?>
    </div>
  </div>
  <?php endforeach; ?>
</section>
<?php pie();

<?php
/* Cartelera (R8): visible para cualquier visitante, con o sin sesión */
require __DIR__ . '/includes/app.php';

$sets      = sp('app.sp_Cartelera');
$peliculas = $sets[0] ?? [];
$horarios  = [];
foreach ($sets[1] ?? [] as $h) {
    $horarios[(int)$h['PeliculaID']][] = $h;
}
$destacada = $peliculas[0] ?? null;

encabezado('Cartelera', 'cartelera', ['main' => 'cartelera']);
?>
<?php if ($destacada): ?>
<section class="hero">
  <div class="hero-fondo" aria-hidden="true">
    <img src="<?= e(poster_url($destacada['Imagen'])) ?>" alt="">
  </div>
  <div class="contenedor hero-int">
    <div class="hero-texto">
      <p class="etiqueta">Estreno en cartelera</p>
      <h1><?= e($destacada['Titulo']) ?></h1>
      <p class="hero-meta">
        <span class="clasif clasif-<?= e(strtolower($destacada['Clasificacion'])) ?>"><?= e($destacada['Clasificacion']) ?></span>
        <?= e($destacada['Genero']) ?> · <?= (int)$destacada['DuracionMin'] ?> min
      </p>
      <p class="hero-sinopsis"><?= e($destacada['Sinopsis']) ?></p>
      <a class="btn btn-primario" href="<?= e(url('pelicula.php?id=' . (int)$destacada['PeliculaID'])) ?>">Ver horarios y comprar</a>
    </div>
  </div>
</section>
<?php endif; ?>

<section class="contenedor seccion">
  <div class="seccion-titulo">
    <h2>En cartelera</h2>
    <p><?= count($peliculas) ?> películas · Compra hasta <?= MAX_BOLETOS_FUNCION ?> boletos por función</p>
  </div>

  <?php if (!$peliculas): ?>
    <div class="vacio"><p>Por ahora no hay funciones programadas. Vuelve pronto.</p></div>
  <?php else: ?>
  <div class="rejilla-peliculas">
    <?php foreach ($peliculas as $p): $id = (int)$p['PeliculaID']; ?>
    <article class="tarjeta-pelicula">
      <a class="poster" href="<?= e(url('pelicula.php?id=' . $id)) ?>">
        <img src="<?= e(poster_url($p['Imagen'])) ?>" alt="Póster de <?= e($p['Titulo']) ?>" loading="lazy" width="400" height="600">
        <span class="clasif clasif-<?= e(strtolower($p['Clasificacion'])) ?>" title="<?= e(clasificacion_desc($p['Clasificacion'])) ?>"><?= e($p['Clasificacion']) ?></span>
        <span class="poster-titulo"><?= e($p['Titulo']) ?></span>
      </a>
      <div class="tarjeta-cuerpo">
        <h3><a href="<?= e(url('pelicula.php?id=' . $id)) ?>"><?= e($p['Titulo']) ?></a></h3>
        <p class="meta"><?= e($p['Genero']) ?> · <?= (int)$p['DuracionMin'] ?> min</p>
        <div class="chips" aria-label="Próximas funciones">
          <?php foreach ($horarios[$id] ?? [] as $h): ?>
            <a class="chip" href="<?= e(url('asientos.php?funcion=' . (int)$h['FuncionID'])) ?>">
              <small><?= e(fecha_corta($h['FechaHora'])) ?></small> <?= e(hora($h['FechaHora'])) ?>
            </a>
          <?php endforeach; ?>
        </div>
        <a class="enlace-mas" href="<?= e(url('pelicula.php?id=' . $id)) ?>">Todos los horarios (<?= (int)$p['FuncionesProgramadas'] ?>) →</a>
      </div>
    </article>
    <?php endforeach; ?>
  </div>
  <?php endif; ?>
</section>

<section class="contenedor seccion beneficios">
  <div class="beneficio"><span aria-hidden="true">💺</span><h3>Elige tu asiento</h3><p>Mapa en vivo de lugares disponibles y ocupados.</p></div>
  <div class="beneficio"><span aria-hidden="true">🔒</span><h3>Pago protegido</h3><p>Los datos de tu tarjeta se guardan cifrados con AES-256.</p></div>
  <div class="beneficio"><span aria-hidden="true">🎟️</span><h3>Boletos al instante</h3><p>Imprímelos o muéstralos en tu celular.</p></div>
</section>
<?php pie();

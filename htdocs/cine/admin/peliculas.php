<?php
/* Catálogo de películas (R11: modificar el nombre de las películas) */
require __DIR__ . '/../includes/app.php';
$u = requerir_admin();
$peliculas = sp_filas('app.sp_AdminListarPeliculas', ['AdminID' => $u['id']]);

encabezado('Películas', 'admin-peliculas', ['admin' => true]);
?>
<div class="seccion-titulo con-accion">
  <div><h1>Películas</h1><p><?= count($peliculas) ?> en el catálogo</p></div>
  <a class="btn btn-primario" href="<?= e(url('admin/pelicula_form.php')) ?>">＋ Agregar película</a>
</div>
<div class="lista-admin-peliculas">
  <?php foreach ($peliculas as $p): ?>
  <article class="compra<?= (int)$p['Activa'] ? '' : ' pasada' ?>">
    <img src="<?= e(poster_url($p['Imagen'])) ?>" alt="" width="400" height="600">
    <div class="compra-info">
      <h2><?= e($p['Titulo']) ?> <?php if (!(int)$p['Activa']): ?><span class="insignia insignia-gris">Inactiva</span><?php endif; ?></h2>
      <p class="meta"><?= e($p['Genero']) ?> · <?= e($p['Clasificacion']) ?> · <?= (int)$p['DuracionMin'] ?> min · Dir. <?= e($p['Director']) ?></p>
      <p class="meta"><?= (int)$p['FuncionesFuturas'] ?> función(es) futuras en venta</p>
    </div>
    <div class="acciones">
      <a class="btn btn-borde btn-chico" href="<?= e(url('admin/pelicula_form.php?id=' . (int)$p['PeliculaID'])) ?>">Editar</a>
      <a class="btn btn-borde btn-chico" href="<?= e(url('admin/funciones.php?pelicula=' . (int)$p['PeliculaID'])) ?>">Horarios</a>
    </div>
  </article>
  <?php endforeach; ?>
</div>
<?php pie();

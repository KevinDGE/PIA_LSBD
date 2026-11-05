<?php
/* Historial de compras del usuario */
require __DIR__ . '/includes/app.php';
$u = requerir_login('mis_compras.php');
$compras = sp_filas('app.sp_ComprasUsuario', ['UsuarioID' => $u['id']]);
$ahora = new DateTimeImmutable();

encabezado('Mis boletos', 'compras');
?>
<div class="seccion-titulo">
  <h1>Mis boletos</h1>
  <p><?= count($compras) ?> compra(s) registradas</p>
</div>

<?php if (!$compras): ?>
  <div class="vacio">
    <div class="vacio-icono" aria-hidden="true">🎟️</div>
    <p>Aún no tienes compras.</p>
    <a class="btn btn-primario" href="<?= e(url('index.php')) ?>">Ver cartelera</a>
  </div>
<?php else: ?>
<div class="lista-compras">
  <?php foreach ($compras as $c): $pasada = fecha_obj($c['FechaHora']) < $ahora; ?>
  <article class="compra<?= $pasada ? ' pasada' : '' ?>">
    <img src="<?= e(poster_url($c['Imagen'])) ?>" alt="" width="400" height="600">
    <div class="compra-info">
      <h2><?= e($c['Titulo']) ?></h2>
      <p><?= e(fecha_larga($c['FechaHora'])) ?> · <strong><?= e(hora($c['FechaHora'])) ?></strong> · <?= e($c['Sala']) ?></p>
      <p class="meta">Asientos <?= e($c['Asientos']) ?> · <?= (int)$c['Cantidad'] ?> boleto(s) · <?= e(dinero($c['Total'])) ?></p>
      <p class="meta">Folio <?= e($c['Folio']) ?> · comprado el <?= e(fecha_obj($c['FechaCompra'])->format('d/m/Y H:i')) ?><?= $pasada ? ' · función concluida' : '' ?></p>
    </div>
    <a class="btn btn-borde" href="<?= e(url('boletos.php?compra=' . (int)$c['CompraID'])) ?>">Ver / imprimir</a>
  </article>
  <?php endforeach; ?>
</div>
<?php endif; ?>
<?php pie();

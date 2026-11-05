<?php
/* Detalle de ventas. La tarjeta se descifra dentro del procedimiento y
   aquí solo llega la marca y los últimos 4 dígitos. */
require __DIR__ . '/../includes/app.php';
$u = requerir_admin();
$ventas = sp_filas('app.sp_AdminUltimasVentas', ['AdminID' => $u['id'], 'Top' => 200]);
$total = array_sum(array_map(fn($v) => (float)$v['Total'], $ventas));

encabezado('Ventas', 'admin-ventas', ['admin' => true]);
?>
<div class="seccion-titulo">
  <h1>Ventas</h1>
  <p><?= count($ventas) ?> compra(s) más recientes · <?= e(dinero($total)) ?></p>
</div>
<section class="panel">
  <div class="tabla-scroll">
    <table class="tabla">
      <thead><tr><th>Folio</th><th>Fecha de compra</th><th>Cliente</th><th>Película</th><th>Función</th><th class="num">Boletos</th><th class="num">Total</th><th>Tarjeta</th><th></th></tr></thead>
      <tbody>
      <?php foreach ($ventas as $v): ?>
        <tr>
          <td><?= e($v['Folio']) ?></td>
          <td><?= e(fecha_obj($v['FechaCompra'])->format('d/m/Y H:i')) ?></td>
          <td><?= e($v['Cliente']) ?><br><small class="meta"><?= e($v['Correo']) ?></small></td>
          <td><?= e($v['Titulo']) ?></td>
          <td><?= e($v['Sala']) ?> · <?= e(fecha_obj($v['FechaHora'])->format('d/m H:i')) ?></td>
          <td class="num"><?= (int)$v['Cantidad'] ?></td>
          <td class="num"><?= e(dinero($v['Total'])) ?></td>
          <td><?= e($v['Marca']) ?> •••• <?= e($v['Ultimos4']) ?></td>
          <td><a class="btn btn-borde btn-chico" href="<?= e(url('boletos.php?compra=' . (int)$v['CompraID'])) ?>">Boletos</a></td>
        </tr>
      <?php endforeach; ?>
      <?php if (!$ventas): ?><tr><td colspan="9">Aún no hay ventas.</td></tr><?php endif; ?>
      </tbody>
    </table>
  </div>
</section>
<?php pie();

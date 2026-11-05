<?php
/* Panel del administrador en tiempo real (R11): funciones vendidas y
   dinero recaudado. Se actualiza solo cada 5 segundos (admin/api_resumen.php). */
require __DIR__ . '/../includes/app.php';
$u = requerir_admin();

$resumen    = sp_fila('app.sp_AdminResumen', ['AdminID' => $u['id']]);
$vendidas   = sp_filas('app.sp_AdminFuncionesVendidas', ['AdminID' => $u['id']]);
$porPeli    = sp_filas('app.sp_AdminVentasPorPelicula', ['AdminID' => $u['id']]);
$maxPeli    = max(1, ...array_map(fn($p) => (float)$p['Recaudado'], $porPeli ?: [['Recaudado' => 1]]));

encabezado('Panel de administración', 'admin', ['admin' => true, 'scripts' => ['admin.js']]);
?>
<div class="seccion-titulo">
  <h1>Panel en vivo</h1>
  <p class="en-vivo" id="estado-vivo"><span class="punto" aria-hidden="true"></span> Actualizado <span id="actualizado"><?= e(fecha_obj($resumen['Actualizado'])->format('H:i:s')) ?></span> · se refresca cada 5 s</p>
</div>

<div class="kpis" id="panel-vivo" data-api="<?= e(url('admin/api_resumen.php')) ?>">
  <div class="kpi kpi-destacado"><span>Total recaudado</span><strong data-kpi="TotalRecaudado"><?= e(dinero($resumen['TotalRecaudado'])) ?></strong></div>
  <div class="kpi"><span>Recaudado hoy</span><strong data-kpi="RecaudadoHoy"><?= e(dinero($resumen['RecaudadoHoy'])) ?></strong></div>
  <div class="kpi"><span>Boletos vendidos</span><strong data-kpi="BoletosVendidos"><?= (int)$resumen['BoletosVendidos'] ?></strong></div>
  <div class="kpi"><span>Compras</span><strong data-kpi="Compras"><?= (int)$resumen['Compras'] ?></strong></div>
  <div class="kpi"><span>Funciones con venta</span><strong data-kpi="FuncionesConVenta"><?= (int)$resumen['FuncionesConVenta'] ?></strong></div>
  <div class="kpi"><span>Clientes registrados</span><strong data-kpi="Clientes"><?= (int)$resumen['Clientes'] ?></strong></div>
</div>

<div class="admin-rejilla">
  <section class="panel">
    <h2>Funciones vendidas</h2>
    <div class="tabla-scroll">
      <table class="tabla">
        <thead><tr><th>Película</th><th>Sala</th><th>Función</th><th class="num">Boletos</th><th>Ocupación</th><th class="num">Recaudado</th></tr></thead>
        <tbody id="tabla-vendidas">
        <?php foreach ($vendidas as $f): $pct = round(100 * (int)$f['Boletos'] / max(1, (int)$f['Capacidad'])); ?>
          <tr>
            <td><?= e($f['Titulo']) ?><?= (int)$f['Activa'] ? '' : ' <span class="insignia">retirada</span>' ?></td>
            <td><?= e($f['Sala']) ?></td>
            <td><?= e(fecha_obj($f['FechaHora'])->format('d/m/Y H:i')) ?></td>
            <td class="num"><?= (int)$f['Boletos'] ?> / <?= (int)$f['Capacidad'] ?></td>
            <td><span class="barra-ocup"><span data-pct="<?= (int)$pct ?>"></span></span> <?= (int)$pct ?>%</td>
            <td class="num"><?= e(dinero($f['Recaudado'])) ?></td>
          </tr>
        <?php endforeach; ?>
        <?php if (!$vendidas): ?><tr><td colspan="6">Aún no hay ventas.</td></tr><?php endif; ?>
        </tbody>
      </table>
    </div>
  </section>

  <section class="panel">
    <h2>Recaudado por película</h2>
    <ul class="barras-h" id="lista-peliculas">
      <?php foreach ($porPeli as $p): ?>
      <li>
        <span class="bh-nombre"><?= e($p['Titulo']) ?></span>
        <span class="bh-barra"><span data-pct="<?= (int)round(100 * (float)$p['Recaudado'] / $maxPeli) ?>"></span></span>
        <span class="bh-valor"><?= e(dinero($p['Recaudado'])) ?> · <?= (int)$p['Boletos'] ?> bol.</span>
      </li>
      <?php endforeach; ?>
    </ul>
    <p><a class="btn btn-borde btn-chico" href="<?= e(url('admin/ventas.php')) ?>">Ver detalle de ventas</a></p>
  </section>
</div>
<?php pie();

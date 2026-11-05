<?php
/* Administración de funciones y horarios (R11): listar, borrar; alta y
   modificación en funcion_form.php */
require __DIR__ . '/../includes/app.php';
$u = requerir_admin();

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
    csrf_verificar();
    $id = entero_positivo($_POST['funcion'] ?? null);
    $volverFecha = validar_fecha($_POST['fecha'] ?? null);
    if (($_POST['accion'] ?? '') === 'eliminar' && $id !== null) {
        $r = sp_fila('app.sp_AdminEliminarFuncion', ['AdminID' => $u['id'], 'FuncionID' => $id]);
        $res = (int)($r['Resultado'] ?? 99);
        flash($res === 0 ? 'exito' : ($res === 1 ? 'aviso' : 'error'), (string)($r['Mensaje'] ?? 'Operación no completada.'));
    } else {
        flash('error', 'Solicitud no válida.');
    }
    redirigir('admin/funciones.php' . ($volverFecha ? '?fecha=' . $volverFecha : ''));
}

$fecha = validar_fecha($_GET['fecha'] ?? null) ?? date('Y-m-d');
$peliculaId = entero_positivo($_GET['pelicula'] ?? null);
$funciones = sp_filas('app.sp_AdminListarFunciones', ['AdminID' => $u['id'], 'Fecha' => $fecha, 'PeliculaID' => $peliculaId]);
$peliculas = sp_filas('app.sp_AdminListarPeliculas', ['AdminID' => $u['id']]);
$dias = [];
for ($i = -1; $i < 13; $i++) {
    $dias[] = (new DateTimeImmutable('today'))->modify(($i >= 0 ? '+' : '') . $i . ' day');
}

encabezado('Funciones y horarios', 'admin-funciones', ['admin' => true]);
?>
<div class="seccion-titulo con-accion">
  <div>
    <h1>Funciones y horarios</h1>
    <p><?= count($funciones) ?> función(es) el <?= e(fecha_larga($fecha)) ?></p>
  </div>
  <a class="btn btn-primario" href="<?= e(url('admin/funcion_form.php?fecha=' . $fecha)) ?>">＋ Agregar función</a>
</div>

<nav class="dias-nav" aria-label="Días">
  <?php foreach ($dias as $d): $f = $d->format('Y-m-d'); ?>
    <a href="<?= e(url('admin/funciones.php?fecha=' . $f . ($peliculaId ? '&pelicula=' . $peliculaId : ''))) ?>" class="<?= $f === $fecha ? 'activo' : '' ?>">
      <small><?= e(mb_substr(DIAS[(int)$d->format('w')], 0, 3)) ?></small><strong><?= e($d->format('j')) ?></strong>
    </a>
  <?php endforeach; ?>
</nav>

<form method="get" action="<?= e(url('admin/funciones.php')) ?>" class="filtros">
  <label>Fecha <input type="date" name="fecha" value="<?= e($fecha) ?>"></label>
  <label>Película
    <select name="pelicula">
      <option value="">Todas</option>
      <?php foreach ($peliculas as $p): ?>
        <option value="<?= (int)$p['PeliculaID'] ?>" <?= $peliculaId === (int)$p['PeliculaID'] ? 'selected' : '' ?>><?= e($p['Titulo']) ?></option>
      <?php endforeach; ?>
    </select>
  </label>
  <button class="btn btn-borde btn-chico" type="submit">Filtrar</button>
</form>

<section class="panel">
  <div class="tabla-scroll">
    <table class="tabla">
      <thead><tr><th>#</th><th>Hora</th><th>Película</th><th>Sala</th><th>Formato</th><th class="num">Precio</th><th class="num">Vendidos</th><th>Estado</th><th>Acciones</th></tr></thead>
      <tbody>
      <?php foreach ($funciones as $f): $id = (int)$f['FuncionID']; $pasada = fecha_obj($f['FechaHora']) < new DateTimeImmutable(); ?>
        <tr class="<?= $pasada ? 'fila-pasada' : '' ?>">
          <td><?= $id ?></td>
          <td><strong><?= e(hora($f['FechaHora'])) ?></strong></td>
          <td><?= e($f['Titulo']) ?> <small class="meta">(<?= (int)$f['DuracionMin'] ?> min)</small></td>
          <td><?= e($f['Sala']) ?></td>
          <td><?= e($f['Formato']) ?> · <?= e(idioma_txt($f['Idioma'])) ?></td>
          <td class="num"><?= e(dinero($f['Precio'])) ?></td>
          <td class="num"><?= (int)$f['Vendidos'] ?> / <?= (int)$f['Capacidad'] ?></td>
          <td>
            <?php if (!(int)$f['Activa']): ?><span class="insignia insignia-gris">Retirada</span>
            <?php elseif ($pasada): ?><span class="insignia insignia-gris">Concluida</span>
            <?php else: ?><span class="insignia insignia-verde">En venta</span><?php endif; ?>
          </td>
          <td class="acciones">
            <a class="btn btn-borde btn-chico" href="<?= e(url('admin/funcion_form.php?id=' . $id)) ?>">Editar</a>
            <form method="post" action="<?= e(url('admin/funciones.php')) ?>" data-confirmar="<?= (int)$f['Vendidos'] > 0 ? '¿Retirar esta función? Tiene boletos vendidos: se ocultará de la cartelera y se conservará su historial.' : '¿Borrar esta función definitivamente?' ?>">
              <?= csrf_campo() ?>
              <input type="hidden" name="accion" value="eliminar">
              <input type="hidden" name="funcion" value="<?= $id ?>">
              <input type="hidden" name="fecha" value="<?= e($fecha) ?>">
              <button class="btn btn-peligro btn-chico" type="submit"><?= (int)$f['Vendidos'] > 0 ? 'Retirar' : 'Borrar' ?></button>
            </form>
          </td>
        </tr>
      <?php endforeach; ?>
      <?php if (!$funciones): ?><tr><td colspan="9">No hay funciones para este filtro.</td></tr><?php endif; ?>
      </tbody>
    </table>
  </div>
</section>
<?php pie();

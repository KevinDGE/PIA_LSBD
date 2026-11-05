<?php
/* Alta y modificación de funciones con su horario (R11) */
require __DIR__ . '/../includes/app.php';
$u = requerir_admin();

$id = entero_positivo($_GET['id'] ?? ($_POST['funcion'] ?? null));
$peliculas = sp_filas('app.sp_AdminListarPeliculas', ['AdminID' => $u['id']]);
$salas     = sp_filas('app.sp_AdminListarSalas', ['AdminID' => $u['id']]);
$error = null;

$v = ['PeliculaID' => '', 'SalaID' => '', 'FechaHora' => '', 'Precio' => '75.00', 'Formato' => '2D', 'Idioma' => 'DOBLADA', 'Activa' => 1, 'Vendidos' => 0];
if ($id !== null) {
    $f = sp_fila('app.sp_AdminObtenerFuncion', ['AdminID' => $u['id'], 'FuncionID' => $id]);
    if ($f === null) {
        pagina_error(404, 'Función no encontrada', 'La función no existe.');
    }
    $v = $f;
    $v['FechaHora'] = fecha_obj($f['FechaHora'])->format('Y-m-d\TH:i');
} elseif ($fechaSug = validar_fecha($_GET['fecha'] ?? null)) {
    $v['FechaHora'] = $fechaSug . 'T18:30';
}

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
    csrf_verificar();
    $v['PeliculaID'] = entero_positivo($_POST['pelicula'] ?? null);
    $v['SalaID']     = entero_positivo($_POST['sala'] ?? null);
    $fechaHora       = validar_fecha_hora($_POST['fechahora'] ?? null);
    $precio          = validar_precio(is_string($_POST['precio'] ?? null) ? $_POST['precio'] : null);
    $formato         = in_array($_POST['formato'] ?? '', ['2D', '3D'], true) ? $_POST['formato'] : null;
    $idioma          = in_array($_POST['idioma'] ?? '', ['DOBLADA', 'SUBTITULADA'], true) ? $_POST['idioma'] : null;
    $activa          = isset($_POST['activa']) ? 1 : 0;
    $v['FechaHora']  = is_string($_POST['fechahora'] ?? null) ? $_POST['fechahora'] : '';
    $v['Precio']     = is_string($_POST['precio'] ?? null) ? $_POST['precio'] : '';
    $v['Formato']    = (string)$formato;
    $v['Idioma']     = (string)$idioma;
    $v['Activa']     = $activa;

    if ($v['PeliculaID'] === null || $v['SalaID'] === null) {
        $error = 'Elige la película y la sala.';
    } elseif ($fechaHora === null) {
        $error = 'Escribe una fecha y hora válidas.';
    } elseif ($precio === null) {
        $error = 'El precio debe estar entre $30.00 y $500.00.';
    } elseif ($formato === null || $idioma === null) {
        $error = 'Elige formato e idioma.';
    } else {
        $r = sp_fila('app.sp_AdminGuardarFuncion', [
            'AdminID' => $u['id'], 'FuncionID' => $id, 'PeliculaID' => $v['PeliculaID'], 'SalaID' => $v['SalaID'],
            'FechaHora' => $fechaHora, 'Precio' => $precio, 'Formato' => $formato, 'Idioma' => $idioma, 'Activa' => $activa,
        ]);
        if ((int)($r['Resultado'] ?? 99) === 0) {
            flash('exito', 'Función guardada: ' . fecha_larga($fechaHora) . ' a las ' . hora($fechaHora) . '.');
            redirigir('admin/funciones.php?fecha=' . substr($fechaHora, 0, 10));
        }
        $error = (string)($r['Mensaje'] ?? 'No fue posible guardar la función.');
    }
}
$titulo = $id ? 'Editar función #' . $id : 'Agregar función';

encabezado($titulo, 'admin-funciones', ['admin' => true, 'main' => 'contenedor angosto']);
?>
<p class="migas"><a href="<?= e(url('admin/funciones.php')) ?>">Funciones</a> / <?= e($titulo) ?></p>
<section class="panel panel-form">
  <h1><?= e($titulo) ?></h1>
  <?php if ((int)$v['Vendidos'] > 0): ?>
    <div class="alerta alerta-info">Esta función tiene <?= (int)$v['Vendidos'] ?> boleto(s) vendidos: puedes cambiar horario, precio y estado, pero no la sala ni la película.</div>
  <?php endif; ?>
  <?php if ($error): ?><div class="alerta alerta-error" role="alert"><?= e($error) ?></div><?php endif; ?>

  <form method="post" action="<?= e(url('admin/funcion_form.php' . ($id ? '?id=' . $id : ''))) ?>" class="formulario">
    <?= csrf_campo() ?>
    <?php if ($id): ?><input type="hidden" name="funcion" value="<?= $id ?>"><?php endif; ?>
    <label class="campo"><span>Película</span>
      <select name="pelicula" required>
        <option value="">Elige…</option>
        <?php foreach ($peliculas as $p): ?>
          <option value="<?= (int)$p['PeliculaID'] ?>" <?= (int)$v['PeliculaID'] === (int)$p['PeliculaID'] ? 'selected' : '' ?>>
            <?= e($p['Titulo']) ?> (<?= (int)$p['DuracionMin'] ?> min)<?= (int)$p['Activa'] ? '' : ' · inactiva' ?>
          </option>
        <?php endforeach; ?>
      </select>
    </label>
    <label class="campo"><span>Sala</span>
      <select name="sala" required>
        <option value="">Elige…</option>
        <?php foreach ($salas as $s): ?>
          <option value="<?= (int)$s['SalaID'] ?>" <?= (int)$v['SalaID'] === (int)$s['SalaID'] ? 'selected' : '' ?>><?= e($s['Nombre']) ?> · <?= e($s['Tipo']) ?> · <?= (int)$s['Capacidad'] ?> lugares</option>
        <?php endforeach; ?>
      </select>
    </label>
    <div class="campos-fila">
      <label class="campo"><span>Fecha y hora</span>
        <input type="datetime-local" name="fechahora" value="<?= e($v['FechaHora']) ?>" required>
      </label>
      <label class="campo"><span>Precio por boleto</span>
        <input type="text" name="precio" inputmode="decimal" value="<?= e($v['Precio']) ?>" pattern="\d{1,3}(\.\d{1,2})?" required>
      </label>
    </div>
    <div class="campos-fila">
      <label class="campo"><span>Formato</span>
        <select name="formato"><?php foreach (['2D', '3D'] as $o): ?><option <?= $v['Formato'] === $o ? 'selected' : '' ?>><?= $o ?></option><?php endforeach; ?></select>
      </label>
      <label class="campo"><span>Idioma</span>
        <select name="idioma">
          <option value="DOBLADA" <?= $v['Idioma'] === 'DOBLADA' ? 'selected' : '' ?>>Doblada</option>
          <option value="SUBTITULADA" <?= $v['Idioma'] === 'SUBTITULADA' ? 'selected' : '' ?>>Subtitulada</option>
        </select>
      </label>
    </div>
    <label class="check"><input type="checkbox" name="activa" value="1" <?= (int)$v['Activa'] ? 'checked' : '' ?>> En venta (visible en cartelera)</label>
    <p class="ayuda">La base de datos rechaza horarios que se encimen con otra función de la misma sala (duración de la película + 15 min de limpieza).</p>
    <div class="botones">
      <button class="btn btn-primario" type="submit">Guardar función</button>
      <a class="btn btn-borde" href="<?= e(url('admin/funciones.php')) ?>">Cancelar</a>
    </div>
  </form>
</section>
<?php pie();

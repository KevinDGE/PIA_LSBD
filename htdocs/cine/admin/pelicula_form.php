<?php
/* Alta y edición de películas, incluido el cambio de nombre (R11) */
require __DIR__ . '/../includes/app.php';
$u = requerir_admin();

$id = entero_positivo($_GET['id'] ?? ($_POST['pelicula'] ?? null));
$posters = posters_disponibles();
$clasifs = ['AA', 'A', 'B', 'B15', 'C', 'D'];
$error = null;
$v = ['Titulo' => '', 'Sinopsis' => '', 'Genero' => '', 'Clasificacion' => 'B', 'DuracionMin' => '110',
      'Director' => '', 'Imagen' => $posters[0] ?? '', 'FechaEstreno' => date('Y-m-d'), 'Activa' => 1];

if ($id !== null) {
    $encontrada = null;
    foreach (sp_filas('app.sp_AdminListarPeliculas', ['AdminID' => $u['id']]) as $p) {
        if ((int)$p['PeliculaID'] === $id) {
            $encontrada = $p;
        }
    }
    if ($encontrada === null) {
        pagina_error(404, 'Película no encontrada', 'La película no existe.');
    }
    $v = $encontrada;
    $v['FechaEstreno'] = substr((string)$encontrada['FechaEstreno'], 0, 10);
}

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
    csrf_verificar();
    $v['Titulo']        = texto_post('titulo', 100);
    $v['Sinopsis']      = texto_post('sinopsis', 600);
    $v['Genero']        = texto_post('genero', 40);
    $v['Director']      = texto_post('director', 80);
    $v['Clasificacion'] = in_array($_POST['clasificacion'] ?? '', $clasifs, true) ? $_POST['clasificacion'] : null;
    $v['DuracionMin']   = entero_positivo($_POST['duracion'] ?? null, 240);
    $v['Imagen']        = in_array($_POST['imagen'] ?? '', $posters, true) ? $_POST['imagen'] : null;
    $v['FechaEstreno']  = validar_fecha(is_string($_POST['estreno'] ?? null) ? $_POST['estreno'] : null);
    $v['Activa']        = isset($_POST['activa']) ? 1 : 0;

    if ($v['Titulo'] === null || mb_strlen($v['Titulo']) < 2 || preg_match('/[<>]/', $v['Titulo'])) {
        $error = 'El nombre debe tener de 2 a 100 caracteres (sin < ni >).';
    } elseif ($v['Sinopsis'] === null || mb_strlen($v['Sinopsis']) < 10) {
        $error = 'La sinopsis debe tener de 10 a 600 caracteres.';
    } elseif ($v['Genero'] === null || mb_strlen($v['Genero']) < 3 || $v['Director'] === null || mb_strlen($v['Director']) < 3) {
        $error = 'Escribe el género y la dirección.';
    } elseif ($v['Clasificacion'] === null || $v['DuracionMin'] === null || $v['DuracionMin'] < 60) {
        $error = 'Elige la clasificación y una duración entre 60 y 240 minutos.';
    } elseif ($v['Imagen'] === null || $v['FechaEstreno'] === null) {
        $error = 'Elige un póster y la fecha de estreno.';
    } else {
        $r = sp_fila('app.sp_AdminGuardarPelicula', [
            'AdminID' => $u['id'], 'PeliculaID' => $id, 'Titulo' => $v['Titulo'], 'Sinopsis' => $v['Sinopsis'],
            'Genero' => $v['Genero'], 'Clasificacion' => $v['Clasificacion'], 'DuracionMin' => $v['DuracionMin'],
            'Director' => $v['Director'], 'Imagen' => $v['Imagen'], 'FechaEstreno' => $v['FechaEstreno'], 'Activa' => $v['Activa'],
        ]);
        if ((int)($r['Resultado'] ?? 99) === 0) {
            flash('exito', 'Película guardada: ' . $v['Titulo'] . '.');
            redirigir('admin/peliculas.php');
        }
        $error = (string)($r['Mensaje'] ?? 'No fue posible guardar la película.');
    }
    foreach ($v as $k => $x) {
        $v[$k] = (string)$x;
    }
}
$titulo = $id ? 'Editar película' : 'Agregar película';

encabezado($titulo, 'admin-peliculas', ['admin' => true, 'main' => 'contenedor angosto']);
?>
<p class="migas"><a href="<?= e(url('admin/peliculas.php')) ?>">Películas</a> / <?= e($titulo) ?></p>
<section class="panel panel-form">
  <h1><?= e($titulo) ?></h1>
  <?php if ($error): ?><div class="alerta alerta-error" role="alert"><?= e($error) ?></div><?php endif; ?>
  <form method="post" action="<?= e(url('admin/pelicula_form.php' . ($id ? '?id=' . $id : ''))) ?>" class="formulario">
    <?= csrf_campo() ?>
    <?php if ($id): ?><input type="hidden" name="pelicula" value="<?= $id ?>"><?php endif; ?>
    <label class="campo"><span>Nombre de la película</span>
      <input type="text" name="titulo" value="<?= e($v['Titulo']) ?>" maxlength="100" required>
    </label>
    <label class="campo"><span>Sinopsis</span>
      <textarea name="sinopsis" rows="4" maxlength="600" required><?= e($v['Sinopsis']) ?></textarea>
    </label>
    <div class="campos-fila">
      <label class="campo"><span>Género</span><input type="text" name="genero" value="<?= e($v['Genero']) ?>" maxlength="40" required></label>
      <label class="campo"><span>Dirección</span><input type="text" name="director" value="<?= e($v['Director']) ?>" maxlength="80" required></label>
    </div>
    <div class="campos-fila">
      <label class="campo"><span>Clasificación</span>
        <select name="clasificacion"><?php foreach ($clasifs as $c): ?><option <?= $v['Clasificacion'] === $c ? 'selected' : '' ?>><?= $c ?></option><?php endforeach; ?></select>
      </label>
      <label class="campo"><span>Duración (min)</span><input type="number" name="duracion" min="60" max="240" value="<?= e($v['DuracionMin']) ?>" required></label>
      <label class="campo"><span>Estreno</span><input type="date" name="estreno" value="<?= e($v['FechaEstreno']) ?>" required></label>
    </div>
    <fieldset class="posters">
      <legend>Póster (ilustraciones propias del equipo)</legend>
      <?php foreach ($posters as $p): ?>
        <label class="poster-op">
          <input type="radio" name="imagen" value="<?= e($p) ?>" <?= $v['Imagen'] === $p ? 'checked' : '' ?>>
          <img src="<?= e(poster_url($p)) ?>" alt="<?= e($p) ?>" width="400" height="600" loading="lazy">
        </label>
      <?php endforeach; ?>
    </fieldset>
    <label class="check"><input type="checkbox" name="activa" value="1" <?= (int)$v['Activa'] ? 'checked' : '' ?>> Activa (se muestra en cartelera si tiene funciones)</label>
    <div class="botones">
      <button class="btn btn-primario" type="submit">Guardar película</button>
      <a class="btn btn-borde" href="<?= e(url('admin/peliculas.php')) ?>">Cancelar</a>
    </div>
  </form>
</section>
<?php pie();

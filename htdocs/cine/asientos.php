<?php
/* Mapa de asientos de una función (R10). Requiere sesión iniciada. */
require __DIR__ . '/includes/app.php';

$funcionId = entero_positivo($_GET['funcion'] ?? null);
if ($funcionId === null) {
    pagina_error(404, 'Función no encontrada', 'La función que buscas no existe.');
}
$u = requerir_login('asientos.php?funcion=' . $funcionId);   // sin sesión no se compra

$f = sp_fila('app.sp_DetalleFuncion', ['FuncionID' => $funcionId]);
if ($f === null) {
    pagina_error(404, 'Función no encontrada', 'La función que buscas no existe.');
}
if (!(int)$f['Vendible']) {
    pagina_error(410, 'Función no disponible', 'Esta función ya comenzó o fue retirada de la cartelera.');
}

$mapa      = sp_filas('app.sp_MapaAsientos', ['FuncionID' => $funcionId, 'UsuarioID' => $u['id']]);
$comprados = (int)(sp_fila('app.sp_BoletosUsuarioFuncion', ['UsuarioID' => $u['id'], 'FuncionID' => $funcionId])['Comprados'] ?? 0);
$restantes = max(0, MAX_BOLETOS_FUNCION - $comprados);

$filas = [];
$libres = 0;
foreach ($mapa as $a) {
    $filas[$a['Fila']][] = $a;
    if (!(int)$a['Ocupado']) {
        $libres++;
    }
}
$porFila  = (int)$f['AsientosPorFila'];
$pasillo  = intdiv($porFila, 2);

encabezado('Asientos · ' . $f['Titulo'], 'cartelera', ['scripts' => ['asientos.js']]);
?>
<p class="migas"><a href="<?= e(url('index.php')) ?>">Cartelera</a> / <a href="<?= e(url('pelicula.php?id=' . (int)$f['PeliculaID'])) ?>"><?= e($f['Titulo']) ?></a> / Asientos</p>

<div class="pasos" aria-label="Pasos de compra">
  <span class="paso hecho">1. Función</span><span class="paso actual">2. Asientos</span><span class="paso">3. Pago</span><span class="paso">4. Boletos</span>
</div>

<form method="post" action="<?= e(url('pago.php')) ?>" id="form-asientos" class="compra-layout" data-max="<?= $restantes ?>" data-precio="<?= e($f['Precio']) ?>">
  <?= csrf_campo() ?>
  <input type="hidden" name="paso" value="resumen">
  <input type="hidden" name="funcion" value="<?= $funcionId ?>">
  <section class="panel">
    <header class="panel-titulo">
      <h1><?= e($f['Titulo']) ?></h1>
      <p><?= e(fecha_larga($f['FechaHora'])) ?> · <strong><?= e(hora($f['FechaHora'])) ?></strong> · <?= e($f['Sala']) ?> · <?= e($f['Formato']) ?> · <?= e(idioma_txt($f['Idioma'])) ?></p>
    </header>

    <?php if ($restantes === 0): ?>
      <div class="alerta alerta-error">Ya tienes <?= MAX_BOLETOS_FUNCION ?> boletos para esta función, que es el máximo permitido.</div>
    <?php elseif ($comprados > 0): ?>
      <div class="alerta alerta-info">Ya tienes <?= $comprados ?> boleto(s) para esta función. Puedes comprar <?= $restantes ?> más.</div>
    <?php endif; ?>

      <div class="sala" role="group" aria-label="Mapa de asientos">
        <div class="pantalla">PANTALLA</div>
        <div class="mapa">
          <?php foreach ($filas as $letra => $asientos): ?>
          <div class="fila">
            <span class="fila-letra"><?= e($letra) ?></span>
            <?php foreach ($asientos as $a):
                $ocupado = (int)$a['Ocupado'];
                $mio     = (int)$a['EsMio'];
                $clase   = $mio ? 'mio' : ($ocupado ? 'ocupado' : 'libre');
                $etq     = $a['Fila'] . $a['Numero'];
            ?>
              <label class="asiento <?= $clase ?><?= (int)$a['Numero'] === $pasillo ? ' pasillo' : '' ?>" title="<?= e($etq . ($ocupado ? ($mio ? ' (tuyo)' : ' (ocupado)') : ' (disponible)')) ?>">
                <input type="checkbox" name="asientos[]" value="<?= (int)$a['AsientoID'] ?>" data-etq="<?= e($etq) ?>" <?= ($ocupado || $restantes === 0) ? 'disabled' : '' ?>>
                <span><?= (int)$a['Numero'] ?></span>
              </label>
            <?php endforeach; ?>
            <span class="fila-letra"><?= e($letra) ?></span>
          </div>
          <?php endforeach; ?>
        </div>
      </div>

      <ul class="leyenda">
        <li><span class="asiento libre muestra"></span> Disponible (<?= $libres ?>)</li>
        <li><span class="asiento seleccionado muestra"></span> Tu selección</li>
        <li><span class="asiento ocupado muestra"></span> Ocupado (<?= count($mapa) - $libres ?>)</li>
        <li><span class="asiento mio muestra"></span> Comprado por ti</li>
      </ul>
  </section>

  <aside class="panel resumen">
    <img class="resumen-poster" src="<?= e(poster_url($f['Imagen'])) ?>" alt="" width="400" height="600">
    <h2>Tu selección</h2>
    <p class="seleccion" id="sel-lista" aria-live="polite">Ningún asiento seleccionado</p>
    <dl class="totales">
      <div><dt>Boletos</dt><dd id="sel-cantidad">0</dd></div>
      <div><dt>Precio unitario</dt><dd><?= e(dinero($f['Precio'])) ?></dd></div>
      <div class="total"><dt>Total</dt><dd id="sel-total">$0.00</dd></div>
    </dl>
    <p class="nota">Máximo <?= MAX_BOLETOS_FUNCION ?> boletos por función por cliente (incluye compras anteriores).</p>
    <button class="btn btn-primario btn-bloque" type="submit" id="btn-continuar" <?= $restantes === 0 ? 'disabled' : '' ?>>Continuar al pago</button>
  </aside>
</form>
<?php pie();

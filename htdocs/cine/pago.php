<?php
/* Pago simulado con tarjeta Visa / Mastercard / American Express (R10, R17).
   Paso "resumen": recibe los asientos elegidos y muestra el formulario.
   Paso "pagar":   valida la tarjeta y llama a app.sp_ComprarBoletos, que
                   hace todo dentro de una transacción.                 */
require __DIR__ . '/includes/app.php';

exigir_post();                 // solo POST con token CSRF válido
$u = requerir_login();         // y con sesión iniciada (también lo valida la base)

$paso      = $_POST['paso'] ?? '';
$funcionId = entero_positivo($_POST['funcion'] ?? null);
if ($funcionId === null || !in_array($paso, ['resumen', 'pagar'], true)) {
    pagina_error(400, 'Solicitud no válida', 'Vuelve a elegir tu función y tus asientos.');
}

$f = sp_fila('app.sp_DetalleFuncion', ['FuncionID' => $funcionId]);
if ($f === null || !(int)$f['Vendible']) {
    pagina_error(410, 'Función no disponible', 'Esta función ya comenzó o fue retirada de la cartelera.');
}

$ids = validar_asientos($paso === 'resumen' ? ($_POST['asientos'] ?? null) : ($_POST['asientos'] ?? ''), MAX_BOLETOS_FUNCION);
if ($ids === null) {
    flash('error', 'Selecciona entre 1 y ' . MAX_BOLETOS_FUNCION . ' asientos.');
    redirigir('asientos.php?funcion=' . $funcionId);
}

// Límite de 10 por usuario y función, contando compras anteriores (también lo valida la base)
$comprados = (int)(sp_fila('app.sp_BoletosUsuarioFuncion', ['UsuarioID' => $u['id'], 'FuncionID' => $funcionId])['Comprados'] ?? 0);
if ($comprados + count($ids) > MAX_BOLETOS_FUNCION) {
    flash('error', 'Límite de ' . MAX_BOLETOS_FUNCION . ' boletos por función: ya tienes ' . $comprados . ' y puedes comprar ' . max(0, MAX_BOLETOS_FUNCION - $comprados) . ' más.');
    redirigir('asientos.php?funcion=' . $funcionId);
}

// Los asientos deben ser de esta sala y estar libres en este momento
$mapa = [];
foreach (sp_filas('app.sp_MapaAsientos', ['FuncionID' => $funcionId, 'UsuarioID' => $u['id']]) as $a) {
    $mapa[(int)$a['AsientoID']] = $a;
}
$etiquetas = [];
foreach ($ids as $id) {
    if (!isset($mapa[$id])) {
        pagina_error(400, 'Selección no válida', 'Uno de los asientos no pertenece a esta sala.');
    }
    if ((int)$mapa[$id]['Ocupado']) {
        flash('error', 'El asiento ' . $mapa[$id]['Fila'] . $mapa[$id]['Numero'] . ' acaba de ocuparse. Elige otro.');
        redirigir('asientos.php?funcion=' . $funcionId);
    }
    $etiquetas[] = $mapa[$id]['Fila'] . $mapa[$id]['Numero'];
}
$total = count($ids) * (float)$f['Precio'];
$errores = [];
$previo  = ['titular' => '', 'marca' => '', 'mes' => '', 'anio' => ''];

if ($paso === 'pagar') {
    // Token de un solo uso: evita que un doble clic intente pagar dos veces
    $token = $_POST['token_pago'] ?? '';
    if (!is_string($token) || !isset($_SESSION['token_pago']) || !hash_equals($_SESSION['token_pago'], $token)) {
        flash('info', 'Ese formulario de pago ya se usó o fue reemplazado por otro. Revisa tus boletos o vuelve a elegir asientos.');
        redirigir('mis_compras.php');
    }

    [$errores, $tarjeta] = validar_pago($_POST);
    $previo = [
        'titular' => (string)($_POST['titular'] ?? ''), 'marca' => (string)($_POST['marca'] ?? ''),
        'mes' => (string)($_POST['mes'] ?? ''), 'anio' => (string)($_POST['anio'] ?? ''),
    ];

    // Simulación de rechazo del banco con la tarjeta de prueba 4000 0000 0000 0002
    if (!$errores && $tarjeta['numero'] === '4000000000000002') {
        $errores['numero'] = 'Pago rechazado por el banco emisor (simulación). Usa otra tarjeta.';
    }

    if (!$errores) {
        unset($_SESSION['token_pago']);
        $r = sp_fila('app.sp_ComprarBoletos', [
            'UsuarioID' => $u['id'],
            'FuncionID' => $funcionId,
            'Asientos'  => implode(',', $ids),
            'Numero'    => $tarjeta['numero'],
            'Titular'   => $tarjeta['titular'],
            'MesExp'    => $tarjeta['mes'],
            'AnioExp'   => $tarjeta['anio'],
        ]);
        unset($tarjeta, $_POST['numero'], $_POST['cvv']);   // no se conservan en memoria
        $res = (int)($r['Resultado'] ?? 99);

        if ($res === 0) {
            flash('exito', '¡Compra realizada! Tus boletos están listos para imprimir.');
            redirigir('boletos.php?compra=' . (int)$r['CompraID']);
        }
        if (in_array($res, [12, 13, 14], true)) {
            flash('error', (string)$r['Mensaje']);
            redirigir('asientos.php?funcion=' . $funcionId);
        }
        if ($res === 11) {
            pagina_error(410, 'Función no disponible', (string)$r['Mensaje']);
        }
        $errores['general'] = (string)($r['Mensaje'] ?? 'No fue posible completar la compra.');
    }
}

$_SESSION['token_pago'] = bin2hex(random_bytes(16));
$anioActual = (int)date('Y');

encabezado('Pago · ' . $f['Titulo'], 'cartelera', ['scripts' => ['pago.js']]);
?>
<p class="migas"><a href="<?= e(url('index.php')) ?>">Cartelera</a> / <a href="<?= e(url('asientos.php?funcion=' . $funcionId)) ?>">Asientos</a> / Pago</p>
<div class="pasos" aria-label="Pasos de compra">
  <span class="paso hecho">1. Función</span><span class="paso hecho">2. Asientos</span><span class="paso actual">3. Pago</span><span class="paso">4. Boletos</span>
</div>

<div class="compra-layout">
  <section class="panel">
    <h1>Pago con tarjeta</h1>
    <p class="nota">🔒 Pago simulado para fines académicos: usa una <strong>tarjeta de prueba</strong>. No se realiza ningún cargo.
      El número se guarda cifrado (AES-256) y el código de seguridad no se guarda.</p>

    <?php if (!empty($errores['general'])): ?>
      <div class="alerta alerta-error"><?= e($errores['general']) ?></div>
    <?php elseif ($errores): ?>
      <div class="alerta alerta-error">Revisa los datos marcados.</div>
    <?php endif; ?>

    <form method="post" action="<?= e(url('pago.php')) ?>" class="formulario" id="form-pago" autocomplete="off" novalidate>
      <?= csrf_campo() ?>
      <input type="hidden" name="paso" value="pagar">
      <input type="hidden" name="funcion" value="<?= $funcionId ?>">
      <input type="hidden" name="asientos" value="<?= e(implode(',', $ids)) ?>">
      <input type="hidden" name="token_pago" value="<?= e($_SESSION['token_pago']) ?>">

      <fieldset class="marcas">
        <legend>Tipo de tarjeta (crédito o débito)</legend>
        <?php foreach (['VISA' => 'Visa', 'MASTERCARD' => 'Mastercard', 'AMEX' => 'American Express'] as $val => $txt): ?>
          <label class="marca-op marca-<?= strtolower($val) ?>">
            <input type="radio" name="marca" value="<?= $val ?>" <?= $previo['marca'] === $val ? 'checked' : '' ?> required>
            <span><?= $txt ?></span>
          </label>
        <?php endforeach; ?>
        <?php if (!empty($errores['marca'])): ?><p class="error-campo"><?= e($errores['marca']) ?></p><?php endif; ?>
      </fieldset>

      <label class="campo">
        <span>Número de tarjeta</span>
        <input type="text" name="numero" id="numero" inputmode="numeric" maxlength="23" placeholder="4111 1111 1111 1111" required aria-describedby="ayuda-numero">
        <small id="ayuda-numero" class="ayuda">Se detecta la marca automáticamente.</small>
        <?php if (!empty($errores['numero'])): ?><p class="error-campo"><?= e($errores['numero']) ?></p><?php endif; ?>
      </label>

      <label class="campo">
        <span>Nombre del titular</span>
        <input type="text" name="titular" maxlength="60" value="<?= e($previo['titular']) ?>" placeholder="Como aparece en la tarjeta" required>
        <?php if (!empty($errores['titular'])): ?><p class="error-campo"><?= e($errores['titular']) ?></p><?php endif; ?>
      </label>

      <div class="campos-fila">
        <label class="campo">
          <span>Mes</span>
          <select name="mes" required>
            <option value="">MM</option>
            <?php for ($m = 1; $m <= 12; $m++): ?>
              <option value="<?= $m ?>" <?= $previo['mes'] === (string)$m ? 'selected' : '' ?>><?= sprintf('%02d', $m) ?></option>
            <?php endfor; ?>
          </select>
        </label>
        <label class="campo">
          <span>Año</span>
          <select name="anio" required>
            <option value="">AAAA</option>
            <?php for ($a = $anioActual; $a <= $anioActual + 12; $a++): ?>
              <option value="<?= $a ?>" <?= $previo['anio'] === (string)$a ? 'selected' : '' ?>><?= $a ?></option>
            <?php endfor; ?>
          </select>
        </label>
        <label class="campo">
          <span>CVV</span>
          <input type="password" name="cvv" id="cvv" inputmode="numeric" maxlength="4" placeholder="•••" required>
        </label>
      </div>
      <?php if (!empty($errores['vencimiento'])): ?><p class="error-campo"><?= e($errores['vencimiento']) ?></p><?php endif; ?>
      <?php if (!empty($errores['cvv'])): ?><p class="error-campo"><?= e($errores['cvv']) ?></p><?php endif; ?>

      <button class="btn btn-primario btn-bloque" type="submit" data-enviando="Procesando pago…">Pagar <?= e(dinero($total)) ?></button>
    </form>
  </section>

  <aside class="panel resumen">
    <img class="resumen-poster" src="<?= e(poster_url($f['Imagen'])) ?>" alt="" width="400" height="600">
    <h2><?= e($f['Titulo']) ?></h2>
    <p><?= e(fecha_larga($f['FechaHora'])) ?> · <strong><?= e(hora($f['FechaHora'])) ?></strong><br><?= e($f['Sala']) ?> · <?= e($f['Formato']) ?> · <?= e(idioma_txt($f['Idioma'])) ?></p>
    <dl class="totales">
      <div><dt>Asientos</dt><dd><?= e(implode(', ', $etiquetas)) ?></dd></div>
      <div><dt>Boletos</dt><dd><?= count($ids) ?> × <?= e(dinero($f['Precio'])) ?></dd></div>
      <div class="total"><dt>Total</dt><dd><?= e(dinero($total)) ?></dd></div>
    </dl>
    <a class="btn btn-borde btn-bloque" href="<?= e(url('asientos.php?funcion=' . $funcionId)) ?>">Cambiar asientos</a>
  </aside>
</div>
<?php pie();

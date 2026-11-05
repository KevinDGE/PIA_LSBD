<?php
/* Boletos imprimibles de una compra (R10). Solo el dueño o un administrador. */
require __DIR__ . '/includes/app.php';
require __DIR__ . '/includes/codigo_barras.php';

$compraId = entero_positivo($_GET['compra'] ?? null);
if ($compraId === null) {
    pagina_error(404, 'Compra no encontrada', 'No encontramos esa compra.');
}
$u = requerir_login('boletos.php?compra=' . $compraId);

// El procedimiento solo devuelve la compra si es del usuario (o si es ADMIN)
$sets    = sp('app.sp_ObtenerCompra', ['CompraID' => $compraId, 'UsuarioID' => $u['id']]);
$c       = $sets[0][0] ?? null;
$boletos = $sets[1] ?? [];
if ($c === null) {
    pagina_error(404, 'Compra no encontrada', 'No encontramos esa compra en tu cuenta.');
}

encabezado('Boletos ' . $c['Folio'], 'compras', ['clase' => 'pagina-boletos']);
?>
<div class="pasos no-imprimir" aria-label="Pasos de compra">
  <span class="paso hecho">1. Función</span><span class="paso hecho">2. Asientos</span><span class="paso hecho">3. Pago</span><span class="paso actual">4. Boletos</span>
</div>

<section class="panel recibo">
  <div class="recibo-cab">
    <div>
      <p class="etiqueta">Compra confirmada</p>
      <h1>Folio <?= e($c['Folio']) ?></h1>
      <p><?= e($c['Cliente']) ?> · <?= e($c['Correo']) ?></p>
    </div>
    <div class="recibo-acciones no-imprimir">
      <button type="button" class="btn btn-primario" data-imprimir>🖨️ Imprimir boletos</button>
      <a class="btn btn-borde" href="<?= e(url('mis_compras.php')) ?>">Mis boletos</a>
    </div>
  </div>
  <dl class="recibo-datos">
    <div><dt>Película</dt><dd><?= e($c['Titulo']) ?> (<?= e($c['Clasificacion']) ?>)</dd></div>
    <div><dt>Función</dt><dd><?= e(fecha_larga($c['FechaHora'])) ?>, <?= e(hora($c['FechaHora'])) ?></dd></div>
    <div><dt>Sala</dt><dd><?= e($c['Sala']) ?> · <?= e($c['Formato']) ?> · <?= e(idioma_txt($c['Idioma'])) ?></dd></div>
    <div><dt>Boletos</dt><dd><?= (int)$c['Cantidad'] ?> × <?= e(dinero($c['Precio'])) ?></dd></div>
    <div><dt>Total pagado</dt><dd><strong><?= e(dinero($c['Total'])) ?></strong></dd></div>
    <div><dt>Tarjeta</dt><dd><?= e($c['Marca']) ?> •••• <?= e($c['Ultimos4']) ?></dd></div>
    <div><dt>Autorización</dt><dd><?= e($c['CodigoAutorizacion']) ?></dd></div>
    <div><dt>Fecha de compra</dt><dd><?= e(fecha_obj($c['FechaCompra'])->format('d/m/Y H:i')) ?></dd></div>
  </dl>
</section>

<section class="boletos">
  <?php foreach ($boletos as $b): ?>
  <article class="boleto">
    <div class="boleto-izq">
      <img src="<?= e(poster_url($c['Imagen'])) ?>" alt="" width="400" height="600">
    </div>
    <div class="boleto-centro">
      <p class="boleto-cine"><?= e(SITIO_NOMBRE) ?></p>
      <h2><?= e($c['Titulo']) ?></h2>
      <p><?= e(fecha_larga($c['FechaHora'])) ?> · <strong><?= e(hora($c['FechaHora'])) ?></strong></p>
      <p><?= e($c['Sala']) ?> · <?= e($c['Formato']) ?> · <?= e(idioma_txt($c['Idioma'])) ?> · <?= e($c['Clasificacion']) ?></p>
      <div class="boleto-barras"><?= code39_svg($b['Codigo']) ?><span><?= e($b['Codigo']) ?></span></div>
    </div>
    <div class="boleto-der">
      <span>Asiento</span>
      <strong><?= e($b['Fila'] . $b['Numero']) ?></strong>
      <span><?= e(dinero($b['Precio'])) ?></span>
      <small>Folio <?= e($c['Folio']) ?></small>
    </div>
  </article>
  <?php endforeach; ?>
</section>
<p class="nota no-imprimir">Presenta tus boletos impresos o en tu celular en la entrada de la sala. Llega 15 minutos antes.</p>
<?php pie();

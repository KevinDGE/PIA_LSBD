<?php
/* Inicio de sesión (R9, R18). La contraseña se compara dentro de SQL Server
   con app.sp_Login (sal + HASHBYTES SHA2_512). */
require __DIR__ . '/includes/app.php';

$volver = ruta_retorno($_GET['volver'] ?? ($_POST['volver'] ?? null));
if (usuario_actual()) {
    redirigir($volver);
}

$error = null;
$correo = '';
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
    csrf_verificar();
    $correo   = texto_post('correo', 120);
    $password = $_POST['password'] ?? '';

    // Validación de tipo y longitud. El texto llega al procedimiento como
    // parámetro: un intento como  ' OR 1=1 --  se trata como un correo literal.
    if ($correo === null || $correo === '' || !is_string($password) || $password === '' || strlen($password) > 128) {
        $error = 'Escribe tu correo y tu contraseña.';
        $correo = (string)$correo;
    } else {
        $r = sp_fila('app.sp_Login', ['Correo' => $correo, 'Password' => $password]);
        $res = (int)($r['Resultado'] ?? 1);
        if ($res === 0) {
            iniciar_sesion_usuario($r);          // regenera el ID de sesión
            flash('exito', 'Hola, ' . $r['Nombre'] . '. Iniciaste sesión correctamente.');
            if ($r['Rol'] === 'ADMIN' && $volver === 'index.php') {
                redirigir('admin/index.php');
            }
            redirigir($volver);
        }
        $error = (string)($r['Mensaje'] ?? 'Correo o contraseña incorrectos.');
    }
}

encabezado('Iniciar sesión', 'login', ['main' => 'contenedor angosto']);
?>
<section class="panel panel-form">
  <h1>Iniciar sesión</h1>
  <p class="nota">Necesitas una cuenta para comprar boletos.</p>
  <?php if ($error): ?><div class="alerta alerta-error" role="alert"><?= e($error) ?></div><?php endif; ?>
  <form method="post" action="<?= e(url('login.php')) ?>" class="formulario" novalidate>
    <?= csrf_campo() ?>
    <input type="hidden" name="volver" value="<?= e($volver) ?>">
    <label class="campo">
      <span>Correo electrónico</span>
      <input type="text" name="correo" value="<?= e($correo) ?>" maxlength="120" autocomplete="username" required autofocus>
    </label>
    <label class="campo">
      <span>Contraseña</span>
      <input type="password" name="password" maxlength="128" autocomplete="current-password" required>
    </label>
    <button class="btn btn-primario btn-bloque" type="submit">Entrar</button>
  </form>
  <p class="form-pie">¿No tienes cuenta? <a href="<?= e(url('registro.php')) ?>">Regístrate aquí</a></p>
</section>
<?php pie();

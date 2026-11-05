<?php
/* Registro de clientes (R9). Alimenta dbo.Usuarios mediante
   app.sp_RegistrarUsuario; el trigger trg_Usuarios_LogAlta lo anota en
   dbo.LogUsuarios (R15). */
require __DIR__ . '/includes/app.php';

if (usuario_actual()) {
    redirigir('index.php');
}

$v = ['nombre' => '', 'apellidos' => '', 'correo' => '', 'telefono' => ''];
$err = [];
$general = null;

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
    csrf_verificar();
    $v['nombre']    = texto_post('nombre', 60);
    $v['apellidos'] = texto_post('apellidos', 80);
    $v['correo']    = texto_post('correo', 120);
    $v['telefono']  = texto_post('telefono', 10);
    $pass  = $_POST['password'] ?? '';
    $pass2 = $_POST['password2'] ?? '';

    if (!validar_nombre($v['nombre'], 60))    { $err['nombre'] = 'Escribe tu nombre (solo letras, 2 a 60 caracteres).'; }
    if (!validar_nombre($v['apellidos'], 80)) { $err['apellidos'] = 'Escribe tus apellidos (solo letras, 2 a 80 caracteres).'; }
    if (!validar_correo($v['correo']))        { $err['correo'] = 'Escribe un correo válido.'; }
    if (!validar_telefono($v['telefono']))    { $err['telefono'] = 'El teléfono debe tener 10 dígitos (o déjalo vacío).'; }
    if (!is_string($pass) || !validar_password($pass)) {
        $err['password'] = 'Usa de 8 a 72 caracteres con al menos una mayúscula, una minúscula y un número.';
    } elseif (!is_string($pass2) || !hash_equals($pass, $pass2)) {
        $err['password2'] = 'Las contraseñas no coinciden.';
    }

    if (!$err) {
        $r = sp_fila('app.sp_RegistrarUsuario', [
            'Nombre'    => $v['nombre'],
            'Apellidos' => $v['apellidos'],
            'Correo'    => mb_strtolower($v['correo']),
            'Telefono'  => $v['telefono'] === '' ? null : $v['telefono'],
            'Password'  => $pass,
        ]);
        $res = (int)($r['Resultado'] ?? 99);
        if ($res === 0) {
            flash('exito', 'Tu cuenta quedó creada. Ya puedes iniciar sesión.');
            redirigir('login.php');
        }
        if ($res === 1) {
            $err['correo'] = (string)$r['Mensaje'];
        } else {
            $general = (string)($r['Mensaje'] ?? 'No fue posible crear la cuenta.');
        }
    }
    foreach ($v as $k => $x) {
        $v[$k] = (string)$x;
    }
}

encabezado('Crear cuenta', 'registro', ['main' => 'contenedor angosto']);
?>
<section class="panel panel-form">
  <h1>Crear cuenta</h1>
  <p class="nota">Regístrate para comprar hasta <?= MAX_BOLETOS_FUNCION ?> boletos por función.</p>
  <?php if ($general): ?><div class="alerta alerta-error" role="alert"><?= e($general) ?></div><?php endif; ?>
  <?php if ($err): ?><div class="alerta alerta-error" role="alert">Revisa los campos marcados.</div><?php endif; ?>
  <form method="post" action="<?= e(url('registro.php')) ?>" class="formulario" novalidate>
    <?= csrf_campo() ?>
    <div class="campos-fila">
      <label class="campo">
        <span>Nombre(s)</span>
        <input type="text" name="nombre" value="<?= e($v['nombre']) ?>" maxlength="60" autocomplete="given-name" required>
        <?php if (isset($err['nombre'])): ?><p class="error-campo"><?= e($err['nombre']) ?></p><?php endif; ?>
      </label>
      <label class="campo">
        <span>Apellidos</span>
        <input type="text" name="apellidos" value="<?= e($v['apellidos']) ?>" maxlength="80" autocomplete="family-name" required>
        <?php if (isset($err['apellidos'])): ?><p class="error-campo"><?= e($err['apellidos']) ?></p><?php endif; ?>
      </label>
    </div>
    <label class="campo">
      <span>Correo electrónico</span>
      <input type="email" name="correo" value="<?= e($v['correo']) ?>" maxlength="120" autocomplete="email" required>
      <?php if (isset($err['correo'])): ?><p class="error-campo"><?= e($err['correo']) ?></p><?php endif; ?>
    </label>
    <label class="campo">
      <span>Teléfono (opcional)</span>
      <input type="tel" name="telefono" value="<?= e($v['telefono']) ?>" maxlength="10" inputmode="numeric" autocomplete="tel-national" placeholder="10 dígitos">
      <?php if (isset($err['telefono'])): ?><p class="error-campo"><?= e($err['telefono']) ?></p><?php endif; ?>
    </label>
    <div class="campos-fila">
      <label class="campo">
        <span>Contraseña</span>
        <input type="password" name="password" maxlength="72" autocomplete="new-password" required>
        <?php if (isset($err['password'])): ?><p class="error-campo"><?= e($err['password']) ?></p><?php endif; ?>
      </label>
      <label class="campo">
        <span>Confirmar contraseña</span>
        <input type="password" name="password2" maxlength="72" autocomplete="new-password" required>
        <?php if (isset($err['password2'])): ?><p class="error-campo"><?= e($err['password2']) ?></p><?php endif; ?>
      </label>
    </div>
    <p class="ayuda">Mínimo 8 caracteres, con mayúscula, minúscula y número. Tu contraseña se guarda como hash SHA-512 con sal; nadie puede leerla.</p>
    <button class="btn btn-primario btn-bloque" type="submit">Crear cuenta</button>
  </form>
  <p class="form-pie">¿Ya tienes cuenta? <a href="<?= e(url('login.php')) ?>">Inicia sesión</a></p>
</section>
<?php pie();

<?php
/* Lo que registró el trigger trg_Usuarios_LogAlta (R15). Sin contraseñas. */
require __DIR__ . '/../includes/app.php';
$u = requerir_admin();
$log = sp_filas('app.sp_AdminLogUsuarios', ['AdminID' => $u['id']]);

encabezado('Log de usuarios', 'admin-log', ['admin' => true]);
?>
<div class="seccion-titulo">
  <h1>Log de usuarios nuevos</h1>
  <p>Tabla <code>dbo.LogUsuarios</code>, llenada por el trigger <code>trg_Usuarios_LogAlta</code> en cada registro.</p>
</div>
<section class="panel">
  <div class="tabla-scroll">
    <table class="tabla">
      <thead><tr><th>LogID</th><th>UsuarioID</th><th>Correo</th><th>Nombre</th><th>Rol</th><th>Evento</th><th>Fecha del log</th><th>Login de BD</th><th>Equipo</th></tr></thead>
      <tbody>
      <?php foreach ($log as $l): ?>
        <tr>
          <td><?= (int)$l['LogID'] ?></td>
          <td><?= (int)$l['UsuarioID'] ?></td>
          <td><?= e($l['Correo']) ?></td>
          <td><?= e($l['NombreCompleto']) ?></td>
          <td><?= e($l['Rol']) ?></td>
          <td><?= e($l['Evento']) ?></td>
          <td><?= e(fecha_obj($l['FechaLog'])->format('d/m/Y H:i:s')) ?></td>
          <td><code><?= e($l['LoginBD']) ?></code></td>
          <td><?= e($l['Equipo']) ?></td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </div>
</section>
<?php pie();

<?php
/* Cierre de sesión: solo por POST con token CSRF */
require __DIR__ . '/includes/app.php';
exigir_post();
cerrar_sesion_usuario();
iniciar_sesion_segura();          // sesión nueva y vacía, con otro ID
flash('info', 'Cerraste sesión. ¡Vuelve pronto!');
redirigir('index.php');

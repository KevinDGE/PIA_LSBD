<?php
/* JSON del panel en vivo. Protegido igual que las páginas de administrador. */
require __DIR__ . '/../includes/app.php';

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

$u = usuario_actual();
$fila = $u ? sp_fila('app.sp_ValidarSesion', ['UsuarioID' => $u['id']]) : null;
if ($fila === null || $fila['Rol'] !== 'ADMIN') {
    http_response_code(403);
    echo json_encode(['error' => 'No autorizado']);
    exit;
}

$r = sp_fila('app.sp_AdminResumen', ['AdminID' => $u['id']]);
$vendidas = array_map(fn($f) => [
    'titulo'    => $f['Titulo'],
    'sala'      => $f['Sala'],
    'fecha'     => fecha_obj($f['FechaHora'])->format('d/m/Y H:i'),
    'boletos'   => (int)$f['Boletos'],
    'capacidad' => (int)$f['Capacidad'],
    'recaudado' => dinero($f['Recaudado']),
    'activa'    => (bool)(int)$f['Activa'],
], sp_filas('app.sp_AdminFuncionesVendidas', ['AdminID' => $u['id']]));

$pelis = sp_filas('app.sp_AdminVentasPorPelicula', ['AdminID' => $u['id']]);
$max = max(1, ...array_map(fn($p) => (float)$p['Recaudado'], $pelis ?: [['Recaudado' => 1]]));
$pelis = array_map(fn($p) => [
    'titulo' => $p['Titulo'], 'boletos' => (int)$p['Boletos'],
    'recaudado' => dinero($p['Recaudado']), 'pct' => (int)round(100 * (float)$p['Recaudado'] / $max),
], $pelis);

echo json_encode([
    'kpi' => [
        'TotalRecaudado'    => dinero($r['TotalRecaudado']),
        'RecaudadoHoy'      => dinero($r['RecaudadoHoy']),
        'BoletosVendidos'   => (int)$r['BoletosVendidos'],
        'Compras'           => (int)$r['Compras'],
        'FuncionesConVenta' => (int)$r['FuncionesConVenta'],
        'Clientes'          => (int)$r['Clientes'],
    ],
    'actualizado' => fecha_obj($r['Actualizado'])->format('H:i:s'),
    'vendidas'    => $vendidas,
    'peliculas'   => $pelis,
], JSON_UNESCAPED_UNICODE | JSON_HEX_TAG | JSON_HEX_AMP);

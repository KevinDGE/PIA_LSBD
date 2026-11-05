<?php
/* =====================================================================
   codigo_barras.php · Código de barras Code 39 en SVG (sin librerías)
   Se dibuja con rectángulos; el texto del código solo contiene A-Z y 2-9.
   ===================================================================== */
if (!defined('CINE_APP')) {
    http_response_code(403);
    exit;
}

function code39_svg(string $texto, int $alto = 56): string
{
    static $tabla = [
        '0' => 'nnnwwnwnn', '1' => 'wnnwnnnnw', '2' => 'nnwwnnnnw', '3' => 'wnwwnnnnn',
        '4' => 'nnnwwnnnw', '5' => 'wnnwwnnnn', '6' => 'nnwwwnnnn', '7' => 'nnnwnnwnw',
        '8' => 'wnnwnnwnn', '9' => 'nnwwnnwnn', 'A' => 'wnnnnwnnw', 'B' => 'nnwnnwnnw',
        'C' => 'wnwnnwnnn', 'D' => 'nnnnwwnnw', 'E' => 'wnnnwwnnn', 'F' => 'nnwnwwnnn',
        'G' => 'nnnnnwwnw', 'H' => 'wnnnnwwnn', 'I' => 'nnwnnwwnn', 'J' => 'nnnnwwwnn',
        'K' => 'wnnnnnnww', 'L' => 'nnwnnnnww', 'M' => 'wnwnnnnwn', 'N' => 'nnnnwnnww',
        'O' => 'wnnnwnnwn', 'P' => 'nnwnwnnwn', 'Q' => 'nnnnnnwww', 'R' => 'wnnnnnwwn',
        'S' => 'nnwnnnwwn', 'T' => 'nnnnwnwwn', 'U' => 'wwnnnnnnw', 'V' => 'nwwnnnnnw',
        'W' => 'wwwnnnnnn', 'X' => 'nwnnwnnnw', 'Y' => 'wwnnwnnnn', 'Z' => 'nwwnwnnnn',
        '*' => 'nwnnwnwnn',
    ];
    $texto = '*' . strtoupper(preg_replace('/[^A-Z0-9]/i', '', $texto)) . '*';
    $angosto = 2;
    $ancho = 5;
    $x = 10;                     // zona de silencio
    $rects = '';
    foreach (str_split($texto) as $i => $c) {
        if (!isset($tabla[$c])) {
            continue;
        }
        foreach (str_split($tabla[$c]) as $j => $tipo) {
            $w = $tipo === 'w' ? $ancho : $angosto;
            if ($j % 2 === 0) {  // posiciones pares = barra negra
                $rects .= '<rect x="' . $x . '" y="0" width="' . $w . '" height="' . $alto . '"/>';
            }
            $x += $w;
        }
        $x += $angosto;          // separador entre caracteres
    }
    $x += 10;
    return '<svg class="barras" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' . $x . ' ' . $alto
        . '" preserveAspectRatio="none" role="img" aria-label="Código de barras ' . e(trim($texto, '*')) . '">'
        . '<rect x="0" y="0" width="' . $x . '" height="' . $alto . '" fill="#fff"/><g fill="#000">' . $rects . '</g></svg>';
}

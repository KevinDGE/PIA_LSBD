<?php
/* =====================================================================
   validacion.php · Validación de entradas en el servidor (R14)
   Cada dato que llega por GET/POST se valida aquí antes de usarse; la
   base de datos vuelve a validar las reglas importantes (doble barrera).
   ===================================================================== */
if (!defined('CINE_APP')) {
    http_response_code(403);
    exit;
}

/** Entero positivo o null */
function entero_positivo(mixed $v, int $max = 2147483647): ?int
{
    if (!is_string($v) && !is_int($v)) {
        return null;
    }
    $n = filter_var($v, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1, 'max_range' => $max]]);
    return $n === false ? null : $n;
}

/** Texto de un campo POST, recortado y con longitud máxima; null si no es texto */
function texto_post(string $campo, int $max): ?string
{
    $v = $_POST[$campo] ?? '';
    if (!is_string($v)) {
        return null;
    }
    $v = trim($v);
    return mb_strlen($v) > $max ? null : $v;
}

function validar_correo(?string $c): bool
{
    return $c !== null && mb_strlen($c) <= 120 && filter_var($c, FILTER_VALIDATE_EMAIL) !== false;
}

/** Nombres y apellidos: letras (con acentos), espacios, apóstrofo, punto y guion */
function validar_nombre(?string $n, int $max): bool
{
    return $n !== null && preg_match("/^[\\p{L}][\\p{L} .'-]{1," . ($max - 1) . "}$/u", $n) === 1;
}

function validar_telefono(?string $t): bool
{
    return $t === '' || ($t !== null && preg_match('/^\d{10}$/', $t) === 1);
}

/** 8 a 72 caracteres con mayúscula, minúscula y número */
function validar_password(?string $p): bool
{
    return $p !== null && strlen($p) >= 8 && strlen($p) <= 72
        && preg_match('/[A-Z]/', $p) && preg_match('/[a-z]/', $p) && preg_match('/\d/', $p);
}

/* ---------------- Tarjetas (solo números de prueba; no hay cobro real) ---------------- */

function limpiar_tarjeta(string $n): string
{
    return preg_replace('/[\s-]/', '', $n) ?? '';
}

function marca_tarjeta(string $n): ?string
{
    if (!ctype_digit($n)) {
        return null;
    }
    $l = strlen($n);
    if ($n[0] === '4' && in_array($l, [13, 16, 19], true)) {
        return 'VISA';
    }
    if ($l === 16) {
        $p2 = (int)substr($n, 0, 2);
        $p4 = (int)substr($n, 0, 4);
        if (($p2 >= 51 && $p2 <= 55) || ($p4 >= 2221 && $p4 <= 2720)) {
            return 'MASTERCARD';
        }
    }
    if ($l === 15 && in_array(substr($n, 0, 2), ['34', '37'], true)) {
        return 'AMEX';
    }
    return null;
}

function luhn_valido(string $n): bool
{
    if (!ctype_digit($n) || strlen($n) < 13 || strlen($n) > 19) {
        return false;
    }
    $suma = 0;
    $doble = false;
    for ($i = strlen($n) - 1; $i >= 0; $i--) {
        $d = (int)$n[$i];
        if ($doble) {
            $d *= 2;
            if ($d > 9) {
                $d -= 9;
            }
        }
        $suma += $d;
        $doble = !$doble;
    }
    return $suma % 10 === 0;
}

/**
 * Valida todos los datos de pago. Devuelve [errores[], datosLimpios[]].
 * El CVV solo se valida aquí y se descarta: nunca se envía a la base.
 */
function validar_pago(array $in): array
{
    $err = [];
    $numero  = limpiar_tarjeta((string)($in['numero'] ?? ''));
    $titular = trim((string)($in['titular'] ?? ''));
    $mes     = entero_positivo($in['mes'] ?? '', 12);
    $anio    = entero_positivo($in['anio'] ?? '', 9999);
    $cvv     = (string)($in['cvv'] ?? '');
    $marcaElegida = (string)($in['marca'] ?? '');

    $marca = marca_tarjeta($numero);
    if ($marca === null) {
        $err['numero'] = 'Solo se aceptan Visa, Mastercard o American Express (revisa el número).';
    } elseif (!luhn_valido($numero)) {
        $err['numero'] = 'El número de tarjeta no es válido (falla el dígito verificador).';
    } elseif ($marcaElegida !== $marca) {
        $err['marca'] = 'La marca seleccionada no coincide con el número de la tarjeta.';
    }

    if (!preg_match("/^[\\p{L}][\\p{L} .'-]{2,59}$/u", $titular)) {
        $err['titular'] = 'Escribe el nombre como aparece en la tarjeta.';
    }

    $anioActual = (int)date('Y');
    if ($mes === null || $anio === null || $anio < $anioActual || $anio > $anioActual + 15) {
        $err['vencimiento'] = 'Selecciona mes y año de vencimiento.';
    } elseif ($anio === $anioActual && $mes < (int)date('n')) {
        $err['vencimiento'] = 'La tarjeta está vencida.';
    }

    $largoCvv = $marca === 'AMEX' ? 4 : 3;
    if (!preg_match('/^\d{' . $largoCvv . '}$/', $cvv)) {
        $err['cvv'] = $marca === 'AMEX' ? 'El código de seguridad de AMEX tiene 4 dígitos.' : 'El código de seguridad tiene 3 dígitos.';
    }

    return [$err, ['numero' => $numero, 'titular' => mb_strtoupper($titular), 'mes' => $mes, 'anio' => $anio, 'marca' => $marca]];
}

/** Lista de IDs de asientos: enteros únicos, entre 1 y $max elementos */
function validar_asientos(mixed $lista, int $max): ?array
{
    if (is_string($lista)) {
        $lista = $lista === '' ? [] : explode(',', $lista);
    }
    if (!is_array($lista) || count($lista) < 1 || count($lista) > $max) {
        return null;
    }
    $ids = [];
    foreach ($lista as $v) {
        $n = entero_positivo($v);
        if ($n === null || isset($ids[$n])) {
            return null;
        }
        $ids[$n] = $n;
    }
    return array_values($ids);
}

/** Fecha 'Y-m-d' válida o null */
function validar_fecha(?string $f): ?string
{
    if ($f === null || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $f)) {
        return null;
    }
    $d = DateTime::createFromFormat('!Y-m-d', $f);
    return ($d && $d->format('Y-m-d') === $f) ? $f : null;
}

/** Fecha y hora de <input type="datetime-local"> → 'Y-m-d\TH:i:s' o null */
function validar_fecha_hora(?string $f): ?string
{
    if ($f === null || !preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/', $f)) {
        return null;
    }
    $d = DateTime::createFromFormat('!Y-m-d\TH:i', $f);
    return ($d && $d->format('Y-m-d\TH:i') === $f) ? $d->format('Y-m-d\TH:i:s') : null;
}

/** Precio con hasta 2 decimales entre 30 y 500 → texto '75.00' o null */
function validar_precio(?string $p): ?string
{
    if ($p === null || !preg_match('/^\d{1,3}(\.\d{1,2})?$/', $p)) {
        return null;
    }
    $v = (float)$p;
    return ($v >= 30 && $v <= 500) ? number_format($v, 2, '.', '') : null;
}

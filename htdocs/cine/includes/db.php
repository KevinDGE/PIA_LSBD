<?php
/* =====================================================================
   db.php · Conexión PDO_SQLSRV y llamada a procedimientos almacenados

   R14: TODAS las consultas pasan por sp(), que ejecuta
        EXEC app.sp_Nombre @Param1 = ?, @Param2 = ?
   con parámetros enlazados (bindValue). El texto del usuario nunca se
   concatena al SQL: el nombre del procedimiento y de los parámetros son
   constantes del código y además se validan con una expresión regular.
   ===================================================================== */
if (!defined('CINE_APP')) {
    http_response_code(403);
    exit;
}

function db(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        $dsn = sprintf(
            'sqlsrv:Server=%s;Database=%s;Encrypt=%s;TrustServerCertificate=%s;LoginTimeout=5;APP=CineAuroraWeb',
            DB_SERVER,
            DB_NAME,
            DB_ENCRYPT ? 'yes' : 'no',
            DB_TRUST_CERT ? 'yes' : 'no'
        );
        $pdo = new PDO($dsn, DB_USER, DB_PASS, [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,      // preparación real en el servidor
            PDO::SQLSRV_ATTR_ENCODING    => PDO::SQLSRV_ENCODING_UTF8,
            PDO::SQLSRV_ATTR_QUERY_TIMEOUT => 15,
        ]);
    }
    return $pdo;
}

/**
 * Ejecuta un procedimiento del esquema app y devuelve todos sus conjuntos de resultados.
 *
 * @param string $proc   p. ej. 'app.sp_Login'
 * @param array  $params ['Correo' => $correo, 'Password' => $pass]  (los nombres son del código)
 * @return array<int, array<int, array<string, mixed>>>
 */
function sp(string $proc, array $params = []): array
{
    if (!preg_match('/^app\.sp_[A-Za-z]+$/', $proc)) {
        throw new InvalidArgumentException('Nombre de procedimiento no permitido');
    }
    $partes = [];
    foreach (array_keys($params) as $nombre) {
        if (!preg_match('/^[A-Za-z]+$/', (string)$nombre)) {
            throw new InvalidArgumentException('Nombre de parámetro no permitido');
        }
        $partes[] = '@' . $nombre . ' = ?';
    }
    $sql  = 'SET NOCOUNT ON; EXEC ' . $proc . ($partes ? ' ' . implode(', ', $partes) : '') . ';';
    $stmt = db()->prepare($sql);

    $i = 1;
    foreach ($params as $valor) {
        if ($valor === null) {
            $stmt->bindValue($i, null, PDO::PARAM_NULL);
        } elseif (is_int($valor)) {
            $stmt->bindValue($i, $valor, PDO::PARAM_INT);
        } elseif (is_bool($valor)) {
            $stmt->bindValue($i, $valor ? 1 : 0, PDO::PARAM_INT);
        } else {
            $stmt->bindValue($i, (string)$valor, PDO::PARAM_STR);
        }
        $i++;
    }
    $stmt->execute();

    $conjuntos = [];
    do {
        if ($stmt->columnCount() > 0) {
            $conjuntos[] = $stmt->fetchAll();
        }
    } while ($stmt->nextRowset());
    $stmt->closeCursor();
    return $conjuntos;
}

/** Primer conjunto de resultados */
function sp_filas(string $proc, array $params = []): array
{
    return sp($proc, $params)[0] ?? [];
}

/** Primera fila del primer conjunto (o null) */
function sp_fila(string $proc, array $params = []): ?array
{
    return sp_filas($proc, $params)[0] ?? null;
}

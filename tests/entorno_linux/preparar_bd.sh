#!/usr/bin/env bash
# ----------------------------------------------------------------------
# Banco de pruebas en Linux (NO es parte de la entrega para Windows).
# Levanta SQL Server 2022 Express en Docker y ejecuta los scripts 01..09
# tal como están, con solo dos ajustes propios de Linux:
#   * 08: sin la validación de "login de Windows sysadmin" (en Linux no
#         hay autenticación de Windows) y sin desactivar dba_prueba, el
#         login sysadmin temporal que usa este banco para administrar.
#   * 09: ruta de respaldo /var/opt/mssql/backup/ en lugar de C:\...
# Uso: bash tests/entorno_linux/preparar_bd.sh
# ----------------------------------------------------------------------
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="${TMPDIR:-/tmp}/cine_pruebas"; mkdir -p "$TMP"
SA_PASS='Lab_Sa_Temp#2026'
DBA_PASS='Dba_Prueba#2026'
SQLCMD="/opt/mssql-tools18/bin/sqlcmd -S 127.0.0.1 -C -b -I"
CONT=${CONT:-mssql}

docker rm -f "$CONT" >/dev/null 2>&1 || true
docker run -d --name "$CONT" --network host -e ACCEPT_EULA=Y -e MSSQL_PID=Express -e TZ=America/Monterrey \
  -e "MSSQL_SA_PASSWORD=$SA_PASS" mcr.microsoft.com/mssql/server:2022-latest >/dev/null
for i in $(seq 1 60); do
  $SQLCMD -U sa -P "$SA_PASS" -Q "SELECT 1" >/dev/null 2>&1 && break; sleep 2
done
echo "SQL Server listo: $($SQLCMD -U sa -P "$SA_PASS" -h -1 -Q "SET NOCOUNT ON; SELECT SERVERPROPERTY('Edition')")"

$SQLCMD -U sa -P "$SA_PASS" -Q "CREATE LOGIN dba_prueba WITH PASSWORD='$DBA_PASS', CHECK_POLICY=OFF; ALTER SERVER ROLE sysadmin ADD MEMBER dba_prueba;" >/dev/null

for f in 01 02 03 04 05 06 07; do
  echo "== $f"; $SQLCMD -U dba_prueba -P "$DBA_PASS" -i "$RAIZ"/sql/${f}_*.sql > "$TMP/salida_$f.txt"
done

python3 - "$RAIZ/sql/08_usuarios_permisos.sql" "$TMP/08_linux.sql" <<'EOF'
import sys
s = open(sys.argv[1], encoding='utf-8').read()
a = s.index('/* ---------- 0.'); b = s.index('/* ---------- 1.')
s = s[:a] + s[b:]
s = s.replace("AND name <> 'cine_app'", "AND name NOT IN ('cine_app', 'dba_prueba')")
open(sys.argv[2], 'w', encoding='utf-8').write(s)
EOF
echo "== 08 (variante Linux)"; $SQLCMD -U dba_prueba -P "$DBA_PASS" -i "$TMP/08_linux.sql" > "$TMP/salida_08.txt"

sed "s#N'C:\\\\Respaldos\\\\CineAurora\\\\'#N'/var/opt/mssql/backup/'#" "$RAIZ/sql/09_respaldo.sql" > "$TMP/09_linux.sql"
echo "== 09 (variante Linux)"; $SQLCMD -U dba_prueba -P "$DBA_PASS" -i "$TMP/09_linux.sql" > "$TMP/salida_09.txt"
echo "Listo. Salidas en $TMP"

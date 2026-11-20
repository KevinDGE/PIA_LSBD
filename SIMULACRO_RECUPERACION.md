# Simulacro de caída y recuperación · CineAuroraDB

Demuestra que el respaldo `.BAK` sirve: se daña la base a propósito y se recupera. Hay dos escenarios; pueden hacer uno o los dos.

- **A · Borrado accidental de datos:** alguien borra todos los boletos vendidos.
- **B · Pérdida total:** la base desaparece (DROP DATABASE).

Todo se hace en SSMS conectado con **Autenticación de Windows**. Se restaura en la **misma instancia**, así que la llave maestra se abre sola y las tarjetas cifradas se recuperan sin pasos extra. (Para otra instancia se usa `10_restaurar_otra_instancia.sql`.)

## 0. Preparación (obligatoria)

1. **Snapshot de la VM**: *Máquina > Tomar instantánea* > `Antes del simulacro`. Si algo sale mal, regresan aquí.
2. **Respaldo reciente**: SSMS > clic derecho en **CineAuroraDB** > *Tareas* > *Copia de seguridad…* > Completa > Disco `C:\Respaldos\CineAurora\Respaldo_Proyecto_3.BAK`; en *Opciones de medios* marcar **Sobrescribir** y **Comprobar copia de seguridad cuando finalice** > Aceptar. (O ejecutar `09_respaldo.sql`.)
3. **Foto del "antes"**, en una consulta nueva:

   ```sql
   USE CineAuroraDB;
   SELECT COUNT(*) AS Boletos FROM dbo.Boletos;
   SELECT COUNT(*) AS Compras, SUM(Total) AS Recaudado FROM dbo.Compras;
   ```
   Anotar los números y abrir `http://localhost/cine/` y el panel del administrador para que se vea que todo funciona.

> Lo que se haga **después** del respaldo (compras nuevas, usuarios nuevos) se pierde al restaurar. Es lo que se explica como *punto de recuperación*.

## Escenario A · Borrado accidental de datos

### A1. Provocar el daño

```sql
USE CineAuroraDB;
DELETE FROM dbo.Boletos;                 -- "alguien" borra todos los boletos
SELECT COUNT(*) AS Boletos FROM dbo.Boletos;   -- 0
```

**Mostrar el efecto:** en el sitio, abrir el mapa de asientos de una función que tenía ventas: los asientos ya aparecen **libres**, y *Mis boletos* de Ana o Luis sale vacío o sin asientos.

### A2. Recuperar desde la interfaz

1. Clic derecho en **Bases de datos** (*Databases*) > **Restaurar base de datos…** (*Restore Database…*).
2. **General** > *Origen*: **Dispositivo** (*Device*) > botón **…** > **Agregar** > elegir `C:\Respaldos\CineAurora\Respaldo_Proyecto_3.BAK` > Aceptar > Aceptar.
3. *Destino* > *Base de datos*: **CineAuroraDB**. En la lista de conjuntos de copia debe estar marcado el respaldo completo.
4. Página **Opciones** (*Options*):
   - Marcar **Sobrescribir la base de datos existente (WITH REPLACE)**.
   - **Desmarcar** *Realizar copia del final del registro antes de restaurar* (*Take tail-log backup before restore*).
   - Marcar **Cerrar las conexiones existentes con la base de datos de destino** (*Close existing connections*).
5. **Aceptar**. Mensaje: *La base de datos "CineAuroraDB" se restauró correctamente*.

**Alternativa con script:**

```sql
USE master;
ALTER DATABASE CineAuroraDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
RESTORE DATABASE CineAuroraDB
    FROM DISK = N'C:\Respaldos\CineAurora\Respaldo_Proyecto_3.BAK'
    WITH REPLACE, RECOVERY, STATS = 25;
ALTER DATABASE CineAuroraDB SET MULTI_USER;
```

Después hacer la **verificación** (abajo).

## Escenario B · Pérdida total de la base

### B1. Provocar la caída

```sql
USE master;
ALTER DATABASE CineAuroraDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE CineAuroraDB;
```

**Mostrar el efecto:**
- En SSMS, la base ya no aparece en *Bases de datos* (clic derecho > *Actualizar*).
- En el sitio, `http://localhost/cine/` muestra **"Ocurrió un problema"**: un mensaje genérico, sin detalles de SQL. El error real queda en `C:\xampp\htdocs\cine\logs\php_errores.log` (*Cannot open database "CineAuroraDB"…*).

### B2. Recuperar

**Desde la interfaz:** los mismos pasos de A2. Como la base no existe, en *Destino* escribir `CineAuroraDB`; en *Opciones* no aparece la copia del final del registro.

**Con script:**

```sql
USE master;
RESTORE DATABASE CineAuroraDB
    FROM DISK = N'C:\Respaldos\CineAurora\Respaldo_Proyecto_3.BAK'
    WITH REPLACE, RECOVERY, STATS = 25;
```

### B3. Devolver el dueño a `sa` (solo en el escenario B)

Al restaurar una base que no existía, queda como dueño el usuario que la restauró. Los procedimientos de compra y de ventas funcionan con los permisos del dueño, así que se deja como estaba:

```sql
ALTER AUTHORIZATION ON DATABASE::CineAuroraDB TO sa;
SELECT SUSER_SNAME(owner_sid) AS Dueno FROM sys.databases WHERE name = 'CineAuroraDB';   -- sa
```

## Verificación (después de A o B)

```sql
USE CineAuroraDB;
SELECT COUNT(*) AS Boletos FROM dbo.Boletos;                         -- igual al "antes"
SELECT COUNT(*) AS Compras, SUM(Total) AS Recaudado FROM dbo.Compras; -- igual al "antes"
SELECT TOP (3) TarjetaID, Marca, NumeroCifrado FROM dbo.Tarjetas;    -- siguen cifradas (0x…)

-- Las tarjetas se pueden descifrar: la llave volvió con el respaldo
DECLARE @admin INT = (SELECT UsuarioID FROM dbo.Usuarios WHERE Correo = 'admin@cineaurora.test');
EXEC app.sp_AdminUltimasVentas @AdminID = @admin, @Top = 5;          -- marca y últimos 4 dígitos
```

En el sitio:
1. `http://localhost/cine/` vuelve a mostrar la cartelera.
2. Iniciar sesión con `admin@cineaurora.test` / `Admin#Aurora2026`: el panel muestra el mismo total recaudado que antes y *Ventas* muestra las tarjetas enmascaradas.
3. Los asientos vendidos vuelven a verse ocupados.

## Qué explicar

- El `.BAK` regresa la base al momento del respaldo; lo que pasó después se pierde. Como la base está en modo de recuperación **FULL**, con respaldos de log periódicos se podría recuperar hasta un minuto antes del daño.
- Las tarjetas se recuperan porque el respaldo incluye la llave maestra, el certificado y la llave simétrica, y en la misma instancia la llave maestra se abre sola. En **otra** instancia hace falta la contraseña de la llave maestra (`10_restaurar_otra_instancia.sql`); por eso también se respaldan las llaves con el script 09.
- La web nunca mostró detalles del error de SQL, solo un mensaje genérico.

## Si algo sale mal

| Problema | Solución |
|---|---|
| *Exclusive access could not be obtained because the database is in use* | Marcar *Cerrar las conexiones existentes* o usar el script con `SET SINGLE_USER WITH ROLLBACK IMMEDIATE` |
| *The tail of the log for the database has not been backed up* | Desmarcar la copia del final del registro, o usar `WITH REPLACE` |
| *Operating system error 5 (Access is denied)* | El `.BAK` está en una carpeta sin permiso para SQL Server; usar `C:\Respaldos\CineAurora\` |
| La compra falla después del escenario B | Faltó el paso B3 (dueño `sa`) |
| Cualquier otra cosa | Restaurar el snapshot `Antes del simulacro` |

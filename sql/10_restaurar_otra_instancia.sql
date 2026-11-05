/* =====================================================================
   10_restaurar_otra_instancia.sql · Restaurar CineAuroraDB en OTRA
   instancia sin perder acceso a las tarjetas cifradas

   Por qué hace falta: la llave maestra de la base (DMK) está protegida por
   una contraseña y por la Service Master Key de la instancia ORIGINAL. En
   una instancia nueva, la Service Master Key es otra, así que SQL Server
   ya no puede abrir la DMK automáticamente y DECRYPTBYKEY devolvería NULL
   (o la compra fallaría al cifrar). Se arregla abriendo la DMK con su
   contraseña y volviéndola a proteger con la Service Master Key nueva.

   Requisitos: conectado con un login sysadmin de la instancia destino,
   el archivo .BAK y la contraseña de la DMK (script 04).
   Cambie @Bak a la ruta donde copió el respaldo.
   ===================================================================== */
USE master;
GO
DECLARE @Bak NVARCHAR(300) = N'C:\Respaldos\CineAurora\Respaldo_Proyecto_3.BAK';
DECLARE @Datos NVARCHAR(300) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(300));
DECLARE @Log   NVARCHAR(300) = CAST(SERVERPROPERTY('InstanceDefaultLogPath')  AS NVARCHAR(300));
DECLARE @DataFile NVARCHAR(300) = @Datos + N'CineAuroraDB.mdf';
DECLARE @LogFile  NVARCHAR(300) = @Log   + N'CineAuroraDB_log.ldf';

RESTORE FILELISTONLY FROM DISK = @Bak;   -- nombres lógicos: CineAuroraDB y CineAuroraDB_log

IF DB_ID(N'CineAuroraDB') IS NOT NULL
    ALTER DATABASE CineAuroraDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE CineAuroraDB
    FROM DISK = @Bak
    WITH MOVE N'CineAuroraDB'     TO @DataFile,
         MOVE N'CineAuroraDB_log' TO @LogFile,
         REPLACE, RECOVERY, CHECKSUM, STATS = 25;

ALTER DATABASE CineAuroraDB SET MULTI_USER;
GO
/* El dueño debe ser sa (SID 0x01, existe en toda instancia aunque esté
   desactivado). Si el dueño fuera un login que no existe aquí, los
   procedimientos WITH EXECUTE AS OWNER fallarían. */
DECLARE @sa SYSNAME = SUSER_NAME(0x01);
DECLARE @sql NVARCHAR(200) = N'ALTER AUTHORIZATION ON DATABASE::CineAuroraDB TO ' + QUOTENAME(@sa) + N';';
EXEC sys.sp_executesql @sql;
GO

/* ---------- Plan A: se conoce la contraseña de la DMK ---------- */
USE CineAuroraDB;
GO
OPEN MASTER KEY DECRYPTION BY PASSWORD = 'Aurora#LlaveMaestra_2026!';
ALTER MASTER KEY ADD ENCRYPTION BY SERVICE MASTER KEY;   -- desde ahora se abre sola en esta instancia
CLOSE MASTER KEY;
GO

/* ---------- Plan B (solo si se perdió la contraseña de la DMK) ----------
   Use el archivo .key que generó el script 09 y la contraseña con que se
   cifró ese archivo. Quite los comentarios y ajuste la ruta:

RESTORE MASTER KEY
    FROM FILE = N'C:\Respaldos\CineAurora\DMK_CineAuroraDB_AAAAMMDD_HHMM.key'
    DECRYPTION BY PASSWORD = 'Aurora#RespaldoDMK_2026!'     -- contraseña del archivo
    ENCRYPTION BY PASSWORD = 'NuevaContraseña#DMK_2026';    -- nueva contraseña de la DMK
OPEN MASTER KEY DECRYPTION BY PASSWORD = 'NuevaContraseña#DMK_2026';
ALTER MASTER KEY ADD ENCRYPTION BY SERVICE MASTER KEY;
CLOSE MASTER KEY;
------------------------------------------------------------------------- */

/* ---------- Comprobación: las tarjetas se descifran en la instancia nueva ---------- */
OPEN SYMMETRIC KEY SK_Tarjetas DECRYPTION BY CERTIFICATE Cert_Tarjetas;
SELECT TarjetaID, Marca,
       '**** ' + RIGHT(CONVERT(VARCHAR(19), DECRYPTBYKEY(NumeroCifrado, 1, CONVERT(VARBINARY(4), UsuarioID))), 4) AS NumeroDescifradoEnmascarado
FROM dbo.Tarjetas;
CLOSE SYMMETRIC KEY SK_Tarjetas;
GO

/* ---------- Usuario de la aplicación en la instancia nueva ----------
   El usuario cine_app viene dentro del respaldo, pero el login es de la
   instancia: hay que crearlo (si no existe) y volver a ligarlo. */
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'cine_app')
    CREATE LOGIN cine_app WITH PASSWORD = 'C1ne#Aurora_App2026',
        DEFAULT_DATABASE = CineAuroraDB, CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;
GO
USE CineAuroraDB;
GO
ALTER USER cine_app WITH LOGIN = cine_app;
GO
/* Finalmente ejecute 08_usuarios_permisos.sql en esta instancia para
   desactivar sa y dejar los permisos mínimos. */
PRINT '10 · Base restaurada y llave maestra ligada a la nueva instancia.';
GO

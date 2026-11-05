/* =====================================================================
   09_respaldo.sql · Respaldo de la base, del certificado y de las llaves
   (R19 y continuidad del cifrado)

   Qué se respalda y por qué:
     1. Llave maestra (DMK) y certificado con su llave privada: sin ellos,
        o sin la contraseña de la DMK, los datos de tarjetas restaurados
        en otra instancia no se pueden descifrar.
     2. Llave simétrica SK_Tarjetas (BACKUP SYMMETRIC KEY, nuevo en 2022).
     3. La base completa en Respaldo_Proyecto_3.BAK (con CHECKSUM).
        SQL Server Express no admite COMPRESSION: no se usa.

   Para la revisión en vivo basta con la sección 3 (o el asistente de SSMS:
   clic derecho en CineAuroraDB > Tareas > Copia de seguridad...).

   Cambie @Carpeta si quiere otra ruta. xp_create_subdir crea la carpeta
   con la cuenta del servicio de SQL Server, así que tendrá permiso de
   escritura. Guarde los archivos .cer/.pvk/.key FUERA de la VM (USB o nube
   del equipo) junto con las contraseñas.
   ===================================================================== */
USE master;
GO
DECLARE @Carpeta NVARCHAR(200) = N'C:\Respaldos\CineAurora\';   -- termina en \
DECLARE @Sello   NVARCHAR(20)  = FORMAT(SYSDATETIME(), 'yyyyMMdd_HHmm');
DECLARE @sql     NVARCHAR(MAX);

EXEC master.dbo.xp_create_subdir @Carpeta;

/* ---------- 1. Llave maestra y certificado (una vez, o tras cambiarlos) ---------- */
SET @sql = N'USE CineAuroraDB;
BACKUP MASTER KEY TO FILE = N''' + @Carpeta + N'DMK_CineAuroraDB_' + @Sello + N'.key''
    ENCRYPTION BY PASSWORD = ''Aurora#RespaldoDMK_2026!'';
BACKUP CERTIFICATE Cert_Tarjetas TO FILE = N''' + @Carpeta + N'Cert_Tarjetas_' + @Sello + N'.cer''
    WITH PRIVATE KEY (FILE = N''' + @Carpeta + N'Cert_Tarjetas_' + @Sello + N'.pvk'',
                      ENCRYPTION BY PASSWORD = ''Aurora#RespaldoCert_2026!'');';
EXEC sys.sp_executesql @sql;
PRINT N'Llave maestra y certificado respaldados en ' + @Carpeta;

/* ---------- 2. Llave simétrica (SQL Server 2022 o posterior) ---------- */
SET @sql = N'USE CineAuroraDB;
OPEN SYMMETRIC KEY SK_Tarjetas DECRYPTION BY CERTIFICATE Cert_Tarjetas;
BACKUP SYMMETRIC KEY SK_Tarjetas TO FILE = N''' + @Carpeta + N'SK_Tarjetas_' + @Sello + N'.key''
    ENCRYPTION BY PASSWORD = ''Aurora#RespaldoSK_2026!'';
CLOSE SYMMETRIC KEY SK_Tarjetas;';
EXEC sys.sp_executesql @sql;
PRINT N'Llave simétrica respaldada.';

/* ---------- 3. Copia de seguridad completa (.BAK) ---------- */
DECLARE @Bak NVARCHAR(300) = @Carpeta + N'Respaldo_Proyecto_3.BAK';
BACKUP DATABASE CineAuroraDB
    TO DISK = @Bak
    WITH FORMAT, INIT,                       -- sobrescribe el archivo: un solo respaldo por .BAK
         NAME = N'CineAuroraDB - respaldo completo',
         DESCRIPTION = N'PIA LSBD Equipo 3 - Cine Aurora',
         CHECKSUM, STATS = 25;

/* ---------- 4. Verificación del respaldo ---------- */
RESTORE VERIFYONLY FROM DISK = @Bak WITH CHECKSUM;
RESTORE HEADERONLY FROM DISK = @Bak;
RESTORE FILELISTONLY FROM DISK = @Bak;

SELECT TOP (5) bs.database_name AS Base, bs.backup_start_date AS Inicio, bs.backup_finish_date AS Fin,
       CAST(bs.backup_size / 1048576.0 AS DECIMAL(10,2)) AS TamanoMB, bs.has_backup_checksums AS ConChecksum,
       bmf.physical_device_name AS Archivo
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = 'CineAuroraDB'
ORDER BY bs.backup_finish_date DESC;

PRINT N'09 · Respaldo creado y verificado: ' + @Bak;
PRINT N'Para Teams: copie el .BAK y, si el profesor usa el nombre de la rúbrica, renómbrelo a BD_3_LSBD.BAK.';
GO

/* =====================================================================
   08_usuarios_permisos.sql · Usuario de mínimo privilegio y
   desactivación de sa y demás logins privilegiados (R16)

   ANTES DE EJECUTAR:
     1. Cree un SNAPSHOT de la máquina virtual (VirtualBox: Máquina >
        Tomar instantánea · VMware: VM > Snapshot > Take Snapshot).
     2. Conéctese a SSMS con "Autenticación de Windows" (usuario
        Administrador de la VM), NO con sa.
     3. Cambie la contraseña de cine_app aquí y en
        htdocs/cine/includes/config.php (deben coincidir).

   Vía de administración que queda: el login de Windows que es sysadmin
   (el que instaló SQL Server). El script se detiene sin cambiar nada si
   no encuentra un login de Windows sysadmin activo, para no bloquear la
   instancia. Recuperación de emergencia: GUIA_INSTALACION.md, sección
   "Si se pierde el acceso de administrador".
   ===================================================================== */
USE master;
GO

/* ---------- 0. Validación de seguridad: debe existir otra vía de administración ---------- */
IF NOT EXISTS (
    SELECT 1
    FROM sys.server_role_members rm
    JOIN sys.server_principals r ON r.principal_id = rm.role_principal_id AND r.name = 'sysadmin'
    JOIN sys.server_principals p ON p.principal_id = rm.member_principal_id
    WHERE p.type IN ('U', 'G')          -- usuario o grupo de Windows
      AND p.is_disabled = 0)
BEGIN
    RAISERROR (N'DETENIDO: no hay un login de Windows con rol sysadmin activo. Si desactiva sa se quedaría sin administrador. Agregue su usuario de Windows como sysadmin y vuelva a ejecutar.', 16, 1);
    SET NOEXEC ON;   -- lo que sigue no se ejecuta
END
ELSE IF (SELECT type FROM sys.server_principals WHERE name = ORIGINAL_LOGIN()) NOT IN ('U', 'G')
BEGIN
    RAISERROR (N'DETENIDO: ejecute este script conectado con Autenticación de Windows, no con un login de SQL Server.', 16, 1);
    SET NOEXEC ON;
END
GO

/* ---------- 1. Login SQL Server de la aplicación (único login tipo SQL activo) ---------- */
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'cine_app')
    CREATE LOGIN cine_app
        WITH PASSWORD = 'C1ne#Aurora_App2026',   -- igual que DB_PASS en config.php
             DEFAULT_DATABASE = CineAuroraDB,
             CHECK_POLICY = ON,                   -- aplica la política de contraseñas de Windows
             CHECK_EXPIRATION = OFF;
ELSE
    ALTER LOGIN cine_app ENABLE;
GO
DENY VIEW ANY DATABASE TO cine_app;   -- no puede listar las demás bases de la instancia
GO

/* ---------- 2. Usuario en la base con permisos mínimos ---------- */
USE CineAuroraDB;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'cine_app')
    CREATE USER cine_app FOR LOGIN cine_app WITH DEFAULT_SCHEMA = app;
GO
-- Lo único que puede hacer: ejecutar los procedimientos del esquema app
GRANT EXECUTE ON SCHEMA::app TO cine_app;
-- Nada directo sobre las tablas (aunque intente SELECT/INSERT por su cuenta)
DENY SELECT, INSERT, UPDATE, DELETE, EXECUTE, ALTER ON SCHEMA::dbo TO cine_app;
-- No puede leer el código de los procedimientos ni la estructura
DENY VIEW DEFINITION TO cine_app;
-- Sin permisos sobre la llave ni el certificado: no puede abrir la llave
DENY CONTROL ON CERTIFICATE::Cert_Tarjetas TO cine_app;
DENY VIEW DEFINITION ON SYMMETRIC KEY::SK_Tarjetas TO cine_app;
-- El usuario invitado no debe poder entrar a la base
REVOKE CONNECT FROM guest;
GO

/* ---------- 3. Desactivar sa y otros logins SQL privilegiados ---------- */
USE master;
GO
DECLARE @sa SYSNAME = SUSER_NAME(0x01);   -- el login sa aunque lo hubieran renombrado
DECLARE @sql NVARCHAR(400) = N'ALTER LOGIN ' + QUOTENAME(@sa) + N' DISABLE;';
EXEC sys.sp_executesql @sql;
PRINT N'Login ' + @sa + N' desactivado.';

-- Cualquier otro login de tipo SQL creado en prácticas (excepto cine_app y los internos ##...##)
DECLARE @login SYSNAME;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT name FROM sys.server_principals
    WHERE type = 'S' AND is_disabled = 0
      AND name NOT LIKE '##%' AND name <> 'cine_app' AND principal_id <> 1;
OPEN c;
FETCH NEXT FROM c INTO @login;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'ALTER LOGIN ' + QUOTENAME(@login) + N' DISABLE;';
    EXEC sys.sp_executesql @sql;
    PRINT N'Login SQL desactivado: ' + @login;
    FETCH NEXT FROM c INTO @login;
END
CLOSE c; DEALLOCATE c;
GO

/* ---------- 4. Evidencia para la revisión ---------- */
SELECT p.name AS LoginName, p.type_desc AS Tipo, p.is_disabled AS Desactivado,
       IS_SRVROLEMEMBER('sysadmin', p.name) AS EsSysadmin, p.default_database_name AS BaseDefault
FROM sys.server_principals p
WHERE p.type IN ('S', 'U', 'G') AND p.name NOT LIKE '##%'
ORDER BY p.type, p.name;

USE CineAuroraDB;
SELECT dp.name AS Usuario, pe.state_desc AS Estado, pe.permission_name AS Permiso,
       pe.class_desc AS Ambito,
       CASE pe.class_desc
            WHEN 'SCHEMA'         THEN SCHEMA_NAME(pe.major_id)
            WHEN 'CERTIFICATE'    THEN (SELECT name FROM sys.certificates WHERE certificate_id = pe.major_id)
            WHEN 'SYMMETRIC_KEYS' THEN (SELECT name FROM sys.symmetric_keys WHERE symmetric_key_id = pe.major_id)
            WHEN 'DATABASE'       THEN DB_NAME()
            ELSE OBJECT_NAME(pe.major_id) END AS Objeto
FROM sys.database_permissions pe
JOIN sys.database_principals dp ON dp.principal_id = pe.grantee_principal_id
WHERE dp.name = 'cine_app'
ORDER BY pe.state_desc, pe.permission_name;
PRINT '08 · Usuario cine_app creado con privilegios mínimos; sa desactivado.';
GO
SET NOEXEC OFF;
GO

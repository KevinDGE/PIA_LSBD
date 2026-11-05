/* =====================================================================
   11_consultas_revision.sql · Evidencias para la revisión presencial
   Ejecutar por bloques (seleccionar el bloque y F5) en SSMS conectado
   con Autenticación de Windows. Ver GUIA_REVISION.md.
   ===================================================================== */
USE CineAuroraDB;
GO

/* ---------------- R13 · Llaves, índices y restricciones ---------------- */
SELECT OBJECT_NAME(parent_object_id) AS Tabla, name AS Restriccion, type_desc AS Tipo
FROM sys.objects
WHERE type IN ('PK', 'F', 'UQ', 'C') AND SCHEMA_NAME(schema_id) = 'dbo'
ORDER BY Tabla, Tipo, Restriccion;

SELECT fk.name AS LlaveForanea, OBJECT_NAME(fk.parent_object_id) AS Tabla,
       STRING_AGG(cp.name, ', ') AS Columnas, OBJECT_NAME(fk.referenced_object_id) AS Referencia
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
JOIN sys.columns cp ON cp.object_id = fkc.parent_object_id AND cp.column_id = fkc.parent_column_id
GROUP BY fk.name, fk.parent_object_id, fk.referenced_object_id
ORDER BY Tabla;

SELECT OBJECT_NAME(i.object_id) AS Tabla, i.name AS Indice, i.type_desc AS Tipo, i.is_unique AS Unico
FROM sys.indexes i
WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1 AND i.name IS NOT NULL
ORDER BY Tabla, Indice;

-- Prueba: vender dos veces el mismo asiento de la misma función -> error de UQ_Boletos_Funcion_Asiento
BEGIN TRY
    INSERT INTO dbo.Boletos (CompraID, FuncionID, SalaID, AsientoID, Precio, Codigo)
    SELECT TOP (1) CompraID, FuncionID, SalaID, AsientoID, Precio, 'DUPLICADO1' FROM dbo.Boletos;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

/* ---------------- R14 · SQL Injection ---------------- */
-- La app solo puede ejecutar procedimientos del esquema app:
SELECT pe.state_desc, pe.permission_name, pe.class_desc,
       CASE pe.class_desc WHEN 'SCHEMA' THEN SCHEMA_NAME(pe.major_id) ELSE '' END AS Esquema
FROM sys.database_permissions pe
WHERE USER_NAME(pe.grantee_principal_id) = 'cine_app';

-- El texto malicioso llega como parámetro y se compara como un correo literal:
EXEC app.sp_Login @Correo = N''' OR ''1''=''1'' --', @Password = N'x';
EXEC app.sp_Login @Correo = N'admin@cineaurora.test''; DROP TABLE dbo.Usuarios; --', @Password = N'x';
SELECT COUNT(*) AS UsuariosSiguenAhi FROM dbo.Usuarios;

-- Como cine_app no puede leer tablas aunque lo intente:
EXECUTE AS USER = 'cine_app';
BEGIN TRY SELECT TOP (1) * FROM dbo.Usuarios; END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje; END CATCH;
REVERT;
GO

/* ---------------- R15 · Trigger de log de usuarios nuevos ---------------- */
SELECT name AS TriggerNombre, OBJECT_NAME(parent_id) AS Tabla, is_disabled
FROM sys.triggers WHERE name = 'trg_Usuarios_LogAlta';

DECLARE @correo NVARCHAR(120) = N'revision.' + FORMAT(SYSDATETIME(), 'HHmmss') + N'@correo.test';
EXEC app.sp_RegistrarUsuario N'Usuario', N'De Revisión', @correo, NULL, N'Revision#2026';
SELECT TOP (5) * FROM dbo.LogUsuarios ORDER BY LogID DESC;   -- no hay columnas de contraseña
GO

/* ---------------- R16 · sa desactivado y usuario único de la app ---------------- */
SELECT name, type_desc, is_disabled, IS_SRVROLEMEMBER('sysadmin', name) AS EsSysadmin
FROM sys.server_principals
WHERE type IN ('S', 'U', 'G') AND name NOT LIKE '##%'
ORDER BY type_desc, name;
-- Con qué login entra la web: los usuarios registrados desde el portal quedan con LoginBD = cine_app
SELECT TOP (10) LogID, Correo, LoginBD, Aplicacion, FechaLog FROM dbo.LogUsuarios ORDER BY LogID DESC;
-- Conexiones abiertas en este momento (la web abre y cierra la suya en cada página; deje abierto el panel de admin)
SELECT s.session_id, s.login_name, s.program_name, c.encrypt_option AS ConexionCifrada
FROM sys.dm_exec_sessions s JOIN sys.dm_exec_connections c ON c.session_id = s.session_id
WHERE s.is_user_process = 1;
GO

/* ---------------- R17 · Tarjetas cifradas ---------------- */
-- 1. Lo que ve cualquiera que haga SELECT: solo VARBINARY cifrado
SELECT * FROM dbo.Tarjetas;

-- 2. Sin abrir la llave, DECRYPTBYKEY devuelve NULL
SELECT TarjetaID, CONVERT(VARCHAR(19), DECRYPTBYKEY(NumeroCifrado, 1, CONVERT(VARBINARY(4), UsuarioID))) AS SinLlave
FROM dbo.Tarjetas;

-- 3. El usuario de la app no puede abrir la llave por su cuenta
EXECUTE AS USER = 'cine_app';
BEGIN TRY OPEN SYMMETRIC KEY SK_Tarjetas DECRYPTION BY CERTIFICATE Cert_Tarjetas; END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje; END CATCH;
REVERT;

-- 4. Solo dentro del procedimiento se descifra, y sale enmascarado (marca + últimos 4)
DECLARE @admin INT = (SELECT UsuarioID FROM dbo.Usuarios WHERE Correo = 'admin@cineaurora.test');
EXEC app.sp_AdminUltimasVentas @AdminID = @admin, @Top = 5;

-- 5. Jerarquía de llaves
SELECT name, algorithm_desc, key_length FROM sys.symmetric_keys;
SELECT name, pvt_key_encryption_type_desc, expiry_date FROM sys.certificates WHERE name = 'Cert_Tarjetas';

-- 6. Guardar un número en claro está prohibido por restricción
BEGIN TRY
    INSERT INTO dbo.Tarjetas (UsuarioID, Marca, NumeroCifrado, TitularCifrado, VencimientoCifrado)
    VALUES (@admin, 'VISA', CAST('4111111111111111' AS VARBINARY(256)), 0x00, 0x00);
END TRY
BEGIN CATCH SELECT ERROR_NUMBER() AS Error, ERROR_MESSAGE() AS Mensaje; END CATCH;
GO

/* ---------------- R18 · Login con procedimiento, sal y SHA2_512 ---------------- */
SELECT UsuarioID, Correo, Rol, PasswordHash, Sal FROM dbo.Usuarios;     -- no hay contraseñas en claro
EXEC app.sp_Login @Correo = N'ana.garcia@correo.test', @Password = N'Cliente#Ana2026';  -- Resultado 0
EXEC app.sp_Login @Correo = N'ana.garcia@correo.test', @Password = N'otra';             -- Resultado 1
SELECT OBJECT_DEFINITION(OBJECT_ID('dbo.fn_HashPassword')) AS DefinicionHash;
GO

/* ---------------- R19 · Respaldo: ejecute 09_respaldo.sql ---------------- */
SELECT TOP (5) database_name, backup_finish_date, type, has_backup_checksums
FROM msdb.dbo.backupset WHERE database_name = 'CineAuroraDB' ORDER BY backup_finish_date DESC;
GO

/* =====================================================================
   06_triggers.sql

   trg_Usuarios_LogAlta (R15)
     Escucha cada INSERT en dbo.Usuarios y guarda en dbo.LogUsuarios quién
     se registró, cuándo y desde qué login/equipo/aplicación.
     NO copia PasswordHash ni Sal: el log nunca contiene contraseñas.
     Está escrito por conjuntos (INSERT ... SELECT FROM inserted), así que
     también funciona si se insertan varios usuarios en una sola sentencia.

   trg_Boletos_Max10 (regla técnica)
     Segunda barrera del límite de 10 boletos por usuario y función,
     sumando compras anteriores, aunque alguien insertara boletos sin pasar
     por app.sp_ComprarBoletos.
   ===================================================================== */
USE CineAuroraDB;
GO

CREATE OR ALTER TRIGGER dbo.trg_Usuarios_LogAlta
ON dbo.Usuarios
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.LogUsuarios (UsuarioID, Correo, NombreCompleto, Rol, FechaRegistro)
    SELECT i.UsuarioID, i.Correo, i.Nombre + N' ' + i.Apellidos, i.Rol, i.FechaRegistro
    FROM inserted i;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Boletos_Max10
ON dbo.Boletos
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM (SELECT DISTINCT c.UsuarioID, i.FuncionID
              FROM inserted i JOIN dbo.Compras c ON c.CompraID = i.CompraID) k
        CROSS APPLY (SELECT COUNT(*) AS Total
                     FROM dbo.Boletos b JOIN dbo.Compras c2 ON c2.CompraID = b.CompraID
                     WHERE c2.UsuarioID = k.UsuarioID AND b.FuncionID = k.FuncionID) t
        WHERE t.Total > 10)
    BEGIN
        THROW 50010, N'Límite de 10 boletos por usuario y función excedido.', 1;
    END
END;
GO

SELECT name AS TriggerCreado, OBJECT_NAME(parent_id) AS Tabla, is_disabled AS Deshabilitado
FROM sys.triggers WHERE parent_class = 1;
PRINT '06 · Triggers creados.';
GO

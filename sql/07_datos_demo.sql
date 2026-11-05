/* =====================================================================
   07_datos_demo.sql · Usuarios de prueba y compras de ejemplo

   Se ejecuta DESPUÉS del cifrado (04), los procedimientos (05) y el
   trigger (06) para que:
     * las contraseñas queden con sal + SHA2_512,
     * el trigger registre a estos usuarios en dbo.LogUsuarios,
     * las tarjetas de las compras de ejemplo queden cifradas.
   Todos los datos son ficticios (dominio reservado .test y tarjetas de
   prueba públicas que pasan Luhn; no existen ni cobran).
   Credenciales: ver CREDENCIALES_PRUEBA.md
   ===================================================================== */
USE CineAuroraDB;
GO
SET NOCOUNT ON;

/* ---------- Usuarios (el administrador solo se crea por script) ---------- */
EXEC dbo.sp_CrearUsuario N'Administrador', N'Cine Aurora', N'admin@cineaurora.test', NULL,         N'Admin#Aurora2026', 'ADMIN';
EXEC dbo.sp_CrearUsuario N'Ana',           N'García Treviño', N'ana.garcia@correo.test', '8112345678', N'Cliente#Ana2026', 'CLIENTE';
EXEC dbo.sp_CrearUsuario N'Luis',          N'Hernández Salinas', N'luis.hernandez@correo.test', '8187654321', N'Cliente#Luis2026', 'CLIENTE';
EXEC dbo.sp_CrearUsuario N'Sofía',         N'Martínez Cantú', N'sofia.martinez@correo.test', NULL, N'Cliente#Sofia2026', 'CLIENTE';
GO

/* ---------- Compras de ejemplo (pasan por el mismo procedimiento que la web) ---------- */
DECLARE @Ana INT  = (SELECT UsuarioID FROM dbo.Usuarios WHERE Correo = 'ana.garcia@correo.test');
DECLARE @Luis INT = (SELECT UsuarioID FROM dbo.Usuarios WHERE Correo = 'luis.hernandez@correo.test');
DECLARE @Manana DATE = DATEADD(DAY, 1, CAST(SYSDATETIME() AS DATE));
DECLARE @F1 INT, @F2 INT, @F3 INT, @A VARCHAR(200);

-- F1: mañana 18:30 en Sala 1 · F2: mañana 21:15 en Sala 2 (3D) · F3: pasado mañana 18:30 Sala VIP
SELECT @F1 = f.FuncionID FROM dbo.Funciones f JOIN dbo.Salas s ON s.SalaID = f.SalaID
 WHERE s.Nombre = N'Sala 1' AND f.FechaHora = DATEADD(MINUTE, 18*60+30, CAST(@Manana AS DATETIME2(0)));
SELECT @F2 = f.FuncionID FROM dbo.Funciones f JOIN dbo.Salas s ON s.SalaID = f.SalaID
 WHERE s.Nombre = N'Sala 2' AND f.FechaHora = DATEADD(MINUTE, 21*60+15, CAST(@Manana AS DATETIME2(0)));
SELECT @F3 = f.FuncionID FROM dbo.Funciones f JOIN dbo.Salas s ON s.SalaID = f.SalaID
 WHERE s.Nombre = N'Sala VIP' AND f.FechaHora = DATEADD(MINUTE, 18*60+30, CAST(DATEADD(DAY, 1, @Manana) AS DATETIME2(0)));

-- Ana: 3 boletos en F1 (fila E, 6-8) con Visa
SELECT @A = STRING_AGG(CAST(a.AsientoID AS VARCHAR(10)), ',') FROM dbo.Asientos a JOIN dbo.Funciones f ON f.SalaID = a.SalaID
 WHERE f.FuncionID = @F1 AND a.Fila = 'E' AND a.Numero BETWEEN 6 AND 8;
EXEC app.sp_ComprarBoletos @Ana, @F1, @A, '4111111111111111', N'ANA GARCIA TREVINO', 12, 2028;

-- Luis: 8 boletos en F1 (fila G, 3-10) con Mastercard -> le quedan 2 para probar el límite de 10
SELECT @A = STRING_AGG(CAST(a.AsientoID AS VARCHAR(10)), ',') FROM dbo.Asientos a JOIN dbo.Funciones f ON f.SalaID = a.SalaID
 WHERE f.FuncionID = @F1 AND a.Fila = 'G' AND a.Numero BETWEEN 3 AND 10;
EXEC app.sp_ComprarBoletos @Luis, @F1, @A, '5555555555554444', N'LUIS HERNANDEZ SALINAS', 6, 2029;

-- Ana: 4 boletos en F2 (fila D, 5-8) con American Express
SELECT @A = STRING_AGG(CAST(a.AsientoID AS VARCHAR(10)), ',') FROM dbo.Asientos a JOIN dbo.Funciones f ON f.SalaID = a.SalaID
 WHERE f.FuncionID = @F2 AND a.Fila = 'D' AND a.Numero BETWEEN 5 AND 8;
EXEC app.sp_ComprarBoletos @Ana, @F2, @A, '378282246310005', N'ANA GARCIA TREVINO', 3, 2030;

-- Luis: 2 boletos en F3 (fila C, 4-5) con Visa
SELECT @A = STRING_AGG(CAST(a.AsientoID AS VARCHAR(10)), ',') FROM dbo.Asientos a JOIN dbo.Funciones f ON f.SalaID = a.SalaID
 WHERE f.FuncionID = @F3 AND a.Fila = 'C' AND a.Numero BETWEEN 4 AND 5;
EXEC app.sp_ComprarBoletos @Luis, @F3, @A, '4242424242424242', N'LUIS HERNANDEZ SALINAS', 9, 2027;
GO

SELECT UsuarioID, Correo, Rol, FechaRegistro FROM dbo.Usuarios;
SELECT LogID, UsuarioID, Correo, Evento, FechaLog, LoginBD FROM dbo.LogUsuarios;
SELECT c.Folio, u.Correo, c.FuncionID, c.Cantidad, c.Total FROM dbo.Compras c JOIN dbo.Usuarios u ON u.UsuarioID = c.UsuarioID;
PRINT '07 · Usuarios de prueba y compras de ejemplo creados.';
GO

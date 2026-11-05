/* =====================================================================
   12_preparar_revision.sql · Ejecutar el DÍA DE LA REVISIÓN (se puede
   correr varias veces; no duplica nada)

   1. Agrega funciones para hoy y los próximos 20 días donde falten.
   2. Deja a Luis (luis.hernandez@correo.test) con 8 boletos en la próxima
      función de las 21:15 de la Sala 1, para demostrar el límite de 10.
   3. Muestra qué función usar en la demostración.
   Conectado con Autenticación de Windows (sysadmin).
   ===================================================================== */
USE CineAuroraDB;
GO
SET NOCOUNT ON;

DECLARE @Hoy DATE = CAST(SYSDATETIME() AS DATE);
;WITH Dias AS (
    SELECT TOP (21) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS d FROM sys.all_objects
),
Horarios AS (
    SELECT * FROM (VALUES (0, '13:00'), (1, '15:45'), (2, '18:30'), (3, '21:15')) h(slot, hora)
),
Pelis AS (
    SELECT PeliculaID, ROW_NUMBER() OVER (ORDER BY PeliculaID) - 1 AS idx, COUNT(*) OVER () AS total
    FROM dbo.Peliculas WHERE Activa = 1
),
Nuevas AS (
    SELECT p.PeliculaID, s.SalaID, s.Tipo, h.slot,
           DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', CAST(h.hora AS TIME)), CAST(DATEADD(DAY, d.d, @Hoy) AS DATETIME2(0))) AS FechaHora
    FROM Dias d CROSS JOIN dbo.Salas s CROSS JOIN Horarios h
    JOIN Pelis p ON p.idx = (DATEPART(DAYOFYEAR, DATEADD(DAY, d.d, @Hoy)) + s.SalaID * 2 + h.slot) % p.total
)
INSERT INTO dbo.Funciones (PeliculaID, SalaID, FechaHora, Precio, Formato, Idioma)
SELECT n.PeliculaID, n.SalaID, n.FechaHora,
       CASE n.Tipo WHEN 'VIP' THEN 150.00 WHEN '3D' THEN 95.00 ELSE 75.00 END,
       CASE n.Tipo WHEN '3D' THEN '3D' ELSE '2D' END,
       CASE WHEN n.slot = 3 THEN 'SUBTITULADA' ELSE 'DOBLADA' END
FROM Nuevas n
WHERE n.FechaHora > SYSDATETIME()
  AND NOT EXISTS (   -- nada en esa sala que se encime con el horario nuevo
        SELECT 1 FROM dbo.Funciones f JOIN dbo.Peliculas p2 ON p2.PeliculaID = f.PeliculaID
        WHERE f.SalaID = n.SalaID
          AND f.FechaHora < DATEADD(MINUTE, (SELECT DuracionMin FROM dbo.Peliculas WHERE PeliculaID = n.PeliculaID) + 15, n.FechaHora)
          AND n.FechaHora < DATEADD(MINUTE, p2.DuracionMin + 15, f.FechaHora));
PRINT CONCAT('Funciones agregadas: ', @@ROWCOUNT);

/* ---- Caso del límite de 10: Luis con 8 boletos en la próxima función 21:15 de Sala 1 ---- */
DECLARE @Luis INT = (SELECT UsuarioID FROM dbo.Usuarios WHERE Correo = 'luis.hernandez@correo.test');
DECLARE @F INT = (
    SELECT TOP (1) f.FuncionID FROM dbo.Funciones f JOIN dbo.Salas s ON s.SalaID = f.SalaID
    WHERE s.Nombre = N'Sala 1' AND f.Activa = 1 AND CAST(f.FechaHora AS TIME) = '21:15' AND f.FechaHora > SYSDATETIME()
    ORDER BY f.FechaHora);
DECLARE @Tiene INT = (SELECT COUNT(*) FROM dbo.Boletos b JOIN dbo.Compras c ON c.CompraID = b.CompraID
                      WHERE c.UsuarioID = @Luis AND b.FuncionID = @F);
IF @Luis IS NOT NULL AND @F IS NOT NULL AND @Tiene < 8
BEGIN
    DECLARE @A VARCHAR(200);
    SELECT @A = STRING_AGG(CAST(a.AsientoID AS VARCHAR(10)), ',')
    FROM (SELECT TOP (8 - @Tiene) a.AsientoID
          FROM dbo.Asientos a JOIN dbo.Funciones f ON f.SalaID = a.SalaID
          WHERE f.FuncionID = @F AND a.Fila = 'G'
            AND NOT EXISTS (SELECT 1 FROM dbo.Boletos b WHERE b.FuncionID = @F AND b.AsientoID = a.AsientoID)
          ORDER BY a.Numero) a;
    EXEC app.sp_ComprarBoletos @Luis, @F, @A, '5555555555554444', N'LUIS HERNANDEZ SALINAS', 6, 2029;
END

SELECT f.FuncionID, p.Titulo, s.Nombre AS Sala, f.FechaHora,
       (SELECT COUNT(*) FROM dbo.Boletos b JOIN dbo.Compras c ON c.CompraID = b.CompraID
        WHERE c.UsuarioID = @Luis AND b.FuncionID = f.FuncionID) AS BoletosDeLuis,
       'http://localhost/cine/asientos.php?funcion=' + CAST(f.FuncionID AS VARCHAR(10)) AS UrlDemostracion
FROM dbo.Funciones f JOIN dbo.Peliculas p ON p.PeliculaID = f.PeliculaID JOIN dbo.Salas s ON s.SalaID = f.SalaID
WHERE f.FuncionID = @F;

-- Desbloquear cuentas que quedaron bloqueadas por pruebas de contraseña
UPDATE dbo.Usuarios SET BloqueadoHasta = NULL, IntentosFallidos = 0 WHERE BloqueadoHasta IS NOT NULL;

SELECT CAST(FechaHora AS DATE) AS Dia, COUNT(*) AS Funciones
FROM dbo.Funciones WHERE Activa = 1 AND FechaHora > SYSDATETIME()
GROUP BY CAST(FechaHora AS DATE) ORDER BY Dia;
PRINT '12 · Listo para la revisión.';
GO

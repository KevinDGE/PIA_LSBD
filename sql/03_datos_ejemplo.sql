/* =====================================================================
   03_datos_ejemplo.sql · Datos de ejemplo (todos ficticios)

   * 3 salas y sus asientos.
   * 6 películas inventadas por el equipo (pósters propios en SVG, sin
     personajes ni carteles con derechos de autor).
   * Funciones para HOY y los 20 días siguientes, calculadas a partir de
     la fecha en que se ejecuta el script. El día de la revisión ejecute
     12_preparar_revision.sql: agrega las funciones que falten (sin
     duplicar) y deja listo el caso de prueba del límite de 10 boletos.
   Los usuarios de prueba y las compras de ejemplo se crean en el script 07
   (después del cifrado, los procedimientos y el trigger).
   ===================================================================== */
USE CineAuroraDB;
GO
SET NOCOUNT ON;

/* ---------------------------- Salas ---------------------------- */
INSERT INTO dbo.Salas (Nombre, Tipo, Filas, AsientosPorFila) VALUES
    (N'Sala 1',   'TRADICIONAL', 10, 14),
    (N'Sala 2',   '3D',           9, 12),
    (N'Sala VIP', 'VIP',          6,  8);

/* --------------------------- Asientos -------------------------- */
;WITH N AS (
    SELECT TOP (30) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects
)
INSERT INTO dbo.Asientos (SalaID, Fila, Numero)
SELECT s.SalaID, CHAR(64 + f.n), a.n
FROM dbo.Salas s
JOIN N f ON f.n <= s.Filas
JOIN N a ON a.n <= s.AsientosPorFila
ORDER BY s.SalaID, f.n, a.n;

/* -------------------------- Películas -------------------------- */
INSERT INTO dbo.Peliculas (Titulo, Sinopsis, Genero, Clasificacion, DuracionMin, Director, Imagen, FechaEstreno) VALUES
(N'Órbita Silenciosa',
 N'Una ingeniera de una estación espacial mexicana descubre que la señal que llega desde el borde del sistema solar repite, nota por nota, la canción de cuna que le cantaba su madre.',
 N'Ciencia ficción', 'B', 128, N'Valeria Montemayor', 'orbita-silenciosa.svg', DATEADD(DAY, -10, CAST(SYSDATETIME() AS DATE))),
(N'El Último Faro',
 N'El guardián de un faro en Baja California tiene una semana para entregar su puesto a un sistema automático. En esos siete días recibe visitas que lo obligan a cerrar cuentas con su pasado.',
 N'Drama', 'B15', 112, N'Ernesto Garza Villarreal', 'ultimo-faro.svg', DATEADD(DAY, -17, CAST(SYSDATETIME() AS DATE))),
(N'La Receta de la Abuela Chela',
 N'Tres primos que no se hablan desde hace años deben ganar juntos un concurso de cocina regional para salvar la fonda familiar. El único problema: nadie recuerda el ingrediente secreto.',
 N'Comedia', 'A', 98, N'Lucía Benavides', 'receta-abuela.svg', DATEADD(DAY, -3, CAST(SYSDATETIME() AS DATE))),
(N'Sombras sobre la Sierra',
 N'Una periodista regresa a su pueblo en la sierra para investigar la desaparición de un topógrafo y encuentra que todos los mapas oficiales de la zona terminan en el mismo punto.',
 N'Suspenso', 'B15', 117, N'Rodrigo Saldaña', 'sombras-sierra.svg', DATEADD(DAY, -24, CAST(SYSDATETIME() AS DATE))),
(N'Pequeños Gigantes',
 N'Un grupo de hormigas inventoras construye una máquina para mudar su colonia antes de que llegue la temporada de lluvias. Película animada para toda la familia.',
 N'Animación', 'AA', 92, N'Paola Cantú', 'pequenos-gigantes.svg', DATEADD(DAY, -6, CAST(SYSDATETIME() AS DATE))),
(N'Ecos del Desierto',
 N'Dos hermanos cruzan el desierto de Coahuila en una camioneta vieja para cumplir la última voluntad de su padre: llevar su guitarra al lugar donde compuso su primera canción.',
 N'Aventura', 'B', 124, N'Andrés Quiroga', 'ecos-desierto.svg', DATEADD(DAY, -1, CAST(SYSDATETIME() AS DATE)));

/* -------------------------- Funciones -------------------------- */
/* 21 días x 3 salas x 4 horarios. La película rota por día, sala y horario. */
DECLARE @Hoy DATE = CAST(SYSDATETIME() AS DATE);

;WITH Dias AS (
    SELECT TOP (21) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS d FROM sys.all_objects
),
Horarios AS (
    SELECT * FROM (VALUES (0, '13:00'), (1, '15:45'), (2, '18:30'), (3, '21:15')) h(slot, hora)
),
Pelis AS (
    SELECT PeliculaID, ROW_NUMBER() OVER (ORDER BY PeliculaID) - 1 AS idx, COUNT(*) OVER () AS total
    FROM dbo.Peliculas
)
INSERT INTO dbo.Funciones (PeliculaID, SalaID, FechaHora, Precio, Formato, Idioma)
SELECT p.PeliculaID,
       s.SalaID,
       DATEADD(MINUTE, DATEDIFF(MINUTE, '00:00', CAST(h.hora AS TIME)), CAST(DATEADD(DAY, d.d, @Hoy) AS DATETIME2(0))),
       CASE s.Tipo WHEN 'VIP' THEN 150.00 WHEN '3D' THEN 95.00 ELSE 75.00 END,
       CASE s.Tipo WHEN '3D' THEN '3D' ELSE '2D' END,
       CASE WHEN h.slot = 3 THEN 'SUBTITULADA' ELSE 'DOBLADA' END
FROM Dias d
CROSS JOIN dbo.Salas s
CROSS JOIN Horarios h
JOIN Pelis p ON p.idx = (d.d + s.SalaID * 2 + h.slot) % p.total;

SELECT (SELECT COUNT(*) FROM dbo.Salas)     AS Salas,
       (SELECT COUNT(*) FROM dbo.Asientos)  AS Asientos,
       (SELECT COUNT(*) FROM dbo.Peliculas) AS Peliculas,
       (SELECT COUNT(*) FROM dbo.Funciones) AS Funciones;
PRINT '03 · Datos de ejemplo cargados.';
GO

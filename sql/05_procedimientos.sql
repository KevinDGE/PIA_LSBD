/* =====================================================================
   05_procedimientos.sql · Funciones y procedimientos almacenados

   Toda la comunicación de la aplicación con la base pasa por el esquema
   "app" (R14). Los procedimientos reciben parámetros tipados; no se arma
   SQL dinámico con texto del usuario en ningún lugar.

   Esquema dbo  -> funciones y procedimientos internos (sin permiso para la app)
   Esquema app  -> procedimientos que la app puede ejecutar (GRANT en script 08)

   Códigos de resultado comunes (columna Resultado):
      0 = correcto · 1..49 = error de negocio con mensaje para el usuario
     99 = error interno (se guarda en dbo.LogErrores; al usuario se le
          muestra un mensaje genérico)
   ===================================================================== */
USE CineAuroraDB;
GO

/* =================================================================== */
/*  Funciones auxiliares                                                */
/* =================================================================== */

/* Hash de contraseña: SHA2_512(sal + contraseña en UTF-16) · R18 */
CREATE OR ALTER FUNCTION dbo.fn_HashPassword (@Password NVARCHAR(128), @Sal VARBINARY(32))
RETURNS VARBINARY(64)
WITH SCHEMABINDING
AS
BEGIN
    RETURN HASHBYTES('SHA2_512', @Sal + CAST(@Password AS VARBINARY(256)));
END;
GO

/* Algoritmo de Luhn (dígito verificador de tarjetas) */
CREATE OR ALTER FUNCTION dbo.fn_LuhnValido (@Numero VARCHAR(19))
RETURNS BIT
WITH SCHEMABINDING
AS
BEGIN
    IF @Numero IS NULL OR LEN(@Numero) NOT BETWEEN 13 AND 19 OR @Numero LIKE '%[^0-9]%'
        RETURN 0;
    DECLARE @i INT = LEN(@Numero), @Suma INT = 0, @d INT, @Doble BIT = 0;
    WHILE @i > 0
    BEGIN
        SET @d = CAST(SUBSTRING(@Numero, @i, 1) AS INT);
        IF @Doble = 1
        BEGIN
            SET @d = @d * 2;
            IF @d > 9 SET @d = @d - 9;
        END
        SET @Suma = @Suma + @d;
        SET @Doble = 1 - @Doble;
        SET @i = @i - 1;
    END
    RETURN CASE WHEN @Suma % 10 = 0 THEN 1 ELSE 0 END;
END;
GO

/* Marca por prefijo y longitud: VISA, MASTERCARD o AMEX (NULL si no aplica) */
CREATE OR ALTER FUNCTION dbo.fn_MarcaTarjeta (@Numero VARCHAR(19))
RETURNS VARCHAR(10)
WITH SCHEMABINDING
AS
BEGIN
    IF @Numero IS NULL OR @Numero LIKE '%[^0-9]%' RETURN NULL;
    DECLARE @L INT = LEN(@Numero);
    IF @Numero LIKE '4%' AND @L IN (13, 16, 19) RETURN 'VISA';
    IF @L = 16 AND (LEFT(@Numero, 2) BETWEEN '51' AND '55'
                    OR CAST(LEFT(@Numero, 4) AS INT) BETWEEN 2221 AND 2720) RETURN 'MASTERCARD';
    IF @L = 15 AND LEFT(@Numero, 2) IN ('34', '37') RETURN 'AMEX';
    RETURN NULL;
END;
GO

/* ¿El usuario es un administrador activo? */
CREATE OR ALTER FUNCTION dbo.fn_EsAdmin (@UsuarioID INT)
RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN EXISTS (SELECT 1 FROM dbo.Usuarios
                             WHERE UsuarioID = @UsuarioID AND Rol = 'ADMIN' AND Activo = 1)
                THEN 1 ELSE 0 END;
END;
GO

/* Guarda el error actual en dbo.LogErrores (se llama desde los CATCH) */
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarError
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.LogErrores (Procedimiento, Numero, Mensaje, Linea)
    VALUES (ERROR_PROCEDURE(), ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE());
END;
GO

/* Alta interna de usuarios (no se otorga a la aplicación).
   La aplicación solo puede crear CLIENTES mediante app.sp_RegistrarUsuario. */
CREATE OR ALTER PROCEDURE dbo.sp_CrearUsuario
    @Nombre    NVARCHAR(60),
    @Apellidos NVARCHAR(80),
    @Correo    NVARCHAR(120),
    @Telefono  VARCHAR(10),
    @Password  NVARCHAR(128),
    @Rol       VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Nombre    = LTRIM(RTRIM(@Nombre));
    SET @Apellidos = LTRIM(RTRIM(@Apellidos));
    SET @Correo    = LOWER(LTRIM(RTRIM(@Correo)));
    SET @Telefono  = NULLIF(LTRIM(RTRIM(@Telefono)), '');

    IF LEN(ISNULL(@Nombre, '')) < 2 OR LEN(ISNULL(@Apellidos, '')) < 2
       OR @Correo IS NULL OR @Correo NOT LIKE '%_@_%._%' OR @Correo LIKE '% %'
       OR (@Telefono IS NOT NULL AND (LEN(@Telefono) <> 10 OR @Telefono LIKE '%[^0-9]%'))
       OR @Rol NOT IN ('CLIENTE', 'ADMIN')
    BEGIN
        SELECT 2 AS Resultado, N'Los datos de registro no son válidos.' AS Mensaje, CAST(NULL AS INT) AS UsuarioID;
        RETURN;
    END

    -- Política mínima también en la base: 8+ caracteres, al menos una letra y un dígito
    IF @Password IS NULL OR LEN(@Password) < 8
       OR @Password NOT LIKE '%[0-9]%' OR @Password NOT LIKE '%[a-zA-Z]%'
    BEGIN
        SELECT 3 AS Resultado, N'La contraseña no cumple la política de seguridad.' AS Mensaje, CAST(NULL AS INT) AS UsuarioID;
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Correo = @Correo)
    BEGIN
        SELECT 1 AS Resultado, N'Ese correo ya está registrado.' AS Mensaje, CAST(NULL AS INT) AS UsuarioID;
        RETURN;
    END

    BEGIN TRY
        DECLARE @Sal VARBINARY(32) = CRYPT_GEN_RANDOM(32);   -- sal aleatoria por usuario
        INSERT INTO dbo.Usuarios (Nombre, Apellidos, Correo, Telefono, PasswordHash, Sal, Rol)
        VALUES (@Nombre, @Apellidos, @Correo, @Telefono, dbo.fn_HashPassword(@Password, @Sal), @Sal, @Rol);

        SELECT 0 AS Resultado, N'Cuenta creada correctamente.' AS Mensaje, CAST(SCOPE_IDENTITY() AS INT) AS UsuarioID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        IF ERROR_NUMBER() IN (2601, 2627)
            SELECT 1 AS Resultado, N'Ese correo ya está registrado.' AS Mensaje, CAST(NULL AS INT) AS UsuarioID;
        ELSE
        BEGIN
            EXEC dbo.sp_RegistrarError;
            SELECT 99 AS Resultado, N'No fue posible crear la cuenta.' AS Mensaje, CAST(NULL AS INT) AS UsuarioID;
        END
    END CATCH
END;
GO

/* =================================================================== */
/*  Registro, login y sesión                                            */
/* =================================================================== */

CREATE OR ALTER PROCEDURE app.sp_RegistrarUsuario
    @Nombre    NVARCHAR(60),
    @Apellidos NVARCHAR(80),
    @Correo    NVARCHAR(120),
    @Telefono  VARCHAR(10),
    @Password  NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    -- Desde la web solo se crean clientes; el rol no lo decide el formulario.
    EXEC dbo.sp_CrearUsuario @Nombre, @Apellidos, @Correo, @Telefono, @Password, 'CLIENTE';
END;
GO

/* Login (R18): la comparación de la contraseña ocurre aquí, dentro de SQL Server.
   Tras 5 intentos fallidos la cuenta se bloquea 5 minutos. */
CREATE OR ALTER PROCEDURE app.sp_Login
    @Correo   NVARCHAR(120),
    @Password NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ID INT, @Hash VARBINARY(64), @Sal VARBINARY(32), @Activo BIT,
            @Bloqueado DATETIME2(0), @Intentos TINYINT, @Ahora DATETIME2(0) = SYSDATETIME();

    SET @Correo = LOWER(LTRIM(RTRIM(@Correo)));

    SELECT @ID = UsuarioID, @Hash = PasswordHash, @Sal = Sal, @Activo = Activo,
           @Bloqueado = BloqueadoHasta, @Intentos = IntentosFallidos
    FROM dbo.Usuarios
    WHERE Correo = @Correo;

    IF @ID IS NULL
    BEGIN
        -- Se calcula un hash de todos modos para no delatar por tiempo si el correo existe
        DECLARE @Descartado VARBINARY(64) = dbo.fn_HashPassword(ISNULL(@Password, N''), CRYPT_GEN_RANDOM(32));
        SELECT 1 AS Resultado, N'Correo o contraseña incorrectos.' AS Mensaje,
               CAST(NULL AS INT) AS UsuarioID, CAST(NULL AS NVARCHAR(60)) AS Nombre,
               CAST(NULL AS NVARCHAR(80)) AS Apellidos, CAST(NULL AS VARCHAR(10)) AS Rol;
        RETURN;
    END

    IF @Bloqueado IS NOT NULL AND @Bloqueado > @Ahora
    BEGIN
        SELECT 2 AS Resultado,
               N'Cuenta bloqueada por intentos fallidos. Intente de nuevo después de las '
                 + CONVERT(NVARCHAR(5), @Bloqueado, 108) + N'.' AS Mensaje,
               CAST(NULL AS INT) AS UsuarioID, CAST(NULL AS NVARCHAR(60)) AS Nombre,
               CAST(NULL AS NVARCHAR(80)) AS Apellidos, CAST(NULL AS VARCHAR(10)) AS Rol;
        RETURN;
    END

    IF @Activo = 1 AND dbo.fn_HashPassword(ISNULL(@Password, N''), @Sal) = @Hash
    BEGIN
        UPDATE dbo.Usuarios
           SET IntentosFallidos = 0, BloqueadoHasta = NULL, UltimoAcceso = @Ahora
         WHERE UsuarioID = @ID;

        SELECT 0 AS Resultado, N'Bienvenido.' AS Mensaje, UsuarioID, Nombre, Apellidos, Rol
        FROM dbo.Usuarios WHERE UsuarioID = @ID;
        RETURN;
    END

    UPDATE dbo.Usuarios
       SET IntentosFallidos = CASE WHEN IntentosFallidos + 1 >= 5 THEN 0 ELSE IntentosFallidos + 1 END,
           BloqueadoHasta   = CASE WHEN IntentosFallidos + 1 >= 5 THEN DATEADD(MINUTE, 5, @Ahora) ELSE NULL END
     WHERE UsuarioID = @ID;

    SELECT 1 AS Resultado, N'Correo o contraseña incorrectos.' AS Mensaje,
           CAST(NULL AS INT) AS UsuarioID, CAST(NULL AS NVARCHAR(60)) AS Nombre,
           CAST(NULL AS NVARCHAR(80)) AS Apellidos, CAST(NULL AS VARCHAR(10)) AS Rol;
END;
GO

/* Revalida en cada página protegida que el usuario sigue activo y con qué rol */
CREATE OR ALTER PROCEDURE app.sp_ValidarSesion
    @UsuarioID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT UsuarioID, Nombre, Apellidos, Correo, Rol
    FROM dbo.Usuarios
    WHERE UsuarioID = @UsuarioID AND Activo = 1;
END;
GO

/* =================================================================== */
/*  Cartelera y funciones (públicos)                                    */
/* =================================================================== */

/* Resultado 1: películas en exhibición. Resultado 2: próximas 4 funciones de cada una. */
CREATE OR ALTER PROCEDURE app.sp_Cartelera
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Ahora DATETIME2(0) = SYSDATETIME();

    SELECT p.PeliculaID, p.Titulo, p.Sinopsis, p.Genero, p.Clasificacion, p.DuracionMin,
           p.Director, p.Imagen, p.FechaEstreno,
           MIN(f.FechaHora) AS ProximaFuncion,
           COUNT(*)         AS FuncionesProgramadas
    FROM dbo.Peliculas p
    JOIN dbo.Funciones f ON f.PeliculaID = p.PeliculaID AND f.Activa = 1 AND f.FechaHora > @Ahora
    WHERE p.Activa = 1
    GROUP BY p.PeliculaID, p.Titulo, p.Sinopsis, p.Genero, p.Clasificacion, p.DuracionMin,
             p.Director, p.Imagen, p.FechaEstreno
    ORDER BY p.FechaEstreno DESC, p.Titulo;

    SELECT x.PeliculaID, x.FuncionID, x.FechaHora, x.Formato, x.Idioma
    FROM (
        SELECT f.PeliculaID, f.FuncionID, f.FechaHora, f.Formato, f.Idioma,
               ROW_NUMBER() OVER (PARTITION BY f.PeliculaID ORDER BY f.FechaHora) AS rn
        FROM dbo.Funciones f
        JOIN dbo.Peliculas p ON p.PeliculaID = f.PeliculaID AND p.Activa = 1
        WHERE f.Activa = 1 AND f.FechaHora > @Ahora
    ) x
    WHERE x.rn <= 4
    ORDER BY x.PeliculaID, x.FechaHora;
END;
GO

CREATE OR ALTER PROCEDURE app.sp_DetallePelicula
    @PeliculaID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT PeliculaID, Titulo, Sinopsis, Genero, Clasificacion, DuracionMin, Director, Imagen, FechaEstreno
    FROM dbo.Peliculas
    WHERE PeliculaID = @PeliculaID AND Activa = 1;
END;
GO

/* Todos los horarios futuros de una película, con asientos disponibles */
CREATE OR ALTER PROCEDURE app.sp_FuncionesPelicula
    @PeliculaID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT f.FuncionID, f.FechaHora, f.Precio, f.Formato, f.Idioma,
           s.SalaID, s.Nombre AS Sala, s.Tipo AS TipoSala,
           s.Filas * s.AsientosPorFila AS Capacidad,
           s.Filas * s.AsientosPorFila - ISNULL(v.Vendidos, 0) AS Disponibles
    FROM dbo.Funciones f
    JOIN dbo.Peliculas p ON p.PeliculaID = f.PeliculaID AND p.Activa = 1
    JOIN dbo.Salas s ON s.SalaID = f.SalaID
    OUTER APPLY (SELECT COUNT(*) AS Vendidos FROM dbo.Boletos b WHERE b.FuncionID = f.FuncionID) v
    WHERE f.PeliculaID = @PeliculaID AND f.Activa = 1 AND f.FechaHora > SYSDATETIME()
    ORDER BY f.FechaHora, s.Nombre;
END;
GO

/* Datos de una función; Vendible = 1 si aún se puede comprar */
CREATE OR ALTER PROCEDURE app.sp_DetalleFuncion
    @FuncionID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT f.FuncionID, f.FechaHora, f.Precio, f.Formato, f.Idioma,
           p.PeliculaID, p.Titulo, p.Clasificacion, p.DuracionMin, p.Imagen, p.Genero,
           s.SalaID, s.Nombre AS Sala, s.Tipo AS TipoSala, s.Filas, s.AsientosPorFila,
           CAST(CASE WHEN f.Activa = 1 AND p.Activa = 1 AND f.FechaHora > SYSDATETIME() THEN 1 ELSE 0 END AS BIT) AS Vendible
    FROM dbo.Funciones f
    JOIN dbo.Peliculas p ON p.PeliculaID = f.PeliculaID
    JOIN dbo.Salas s ON s.SalaID = f.SalaID
    WHERE f.FuncionID = @FuncionID;
END;
GO

/* Mapa de asientos: disponibles contra ocupados (y cuáles son del usuario) */
CREATE OR ALTER PROCEDURE app.sp_MapaAsientos
    @FuncionID INT,
    @UsuarioID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT a.AsientoID, a.Fila, a.Numero,
           CAST(CASE WHEN b.BoletoID IS NULL THEN 0 ELSE 1 END AS BIT) AS Ocupado,
           CAST(CASE WHEN c.UsuarioID = @UsuarioID THEN 1 ELSE 0 END AS BIT) AS EsMio
    FROM dbo.Funciones f
    JOIN dbo.Asientos a ON a.SalaID = f.SalaID
    LEFT JOIN dbo.Boletos b ON b.FuncionID = f.FuncionID AND b.AsientoID = a.AsientoID
    LEFT JOIN dbo.Compras c ON c.CompraID = b.CompraID
    WHERE f.FuncionID = @FuncionID
    ORDER BY a.Fila, a.Numero;
END;
GO

/* Boletos que el usuario ya compró para una función (para el límite de 10) */
CREATE OR ALTER PROCEDURE app.sp_BoletosUsuarioFuncion
    @UsuarioID INT,
    @FuncionID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(*) AS Comprados
    FROM dbo.Boletos b
    JOIN dbo.Compras c ON c.CompraID = b.CompraID
    WHERE c.UsuarioID = @UsuarioID AND b.FuncionID = @FuncionID;
END;
GO

/* =================================================================== */
/*  Compra (transacción) · R10, R13, R17                               */
/* =================================================================== */
/*  Pasos dentro de UNA transacción:
      1. Bloquea la fila de la función (UPDLOCK, HOLDLOCK): dos compras de la
         misma función se atienden una después de otra.
      2. Valida asientos (existen, son de la sala, están libres).
      3. Valida el máximo de 10 boletos por usuario y función, sumando
         compras anteriores.
      4. Abre la llave simétrica, cifra número, titular y vencimiento,
         inserta la tarjeta y cierra la llave.
      5. Registra la compra y genera los boletos con código aleatorio.
    Si algo falla se hace ROLLBACK de todo. La restricción
    UQ_Boletos_Funcion_Asiento es la última barrera contra la doble venta.
    El CVV no llega a la base de datos (lo valida PHP y lo descarta).
    WITH EXECUTE AS OWNER: la app no tiene permisos sobre la llave; el
    procedimiento la usa con los permisos de su dueño (dbo).            */
CREATE OR ALTER PROCEDURE app.sp_ComprarBoletos
    @UsuarioID INT,
    @FuncionID INT,
    @Asientos  VARCHAR(200),      -- IDs separados por coma, p. ej. '15,16,17'
    @Numero    VARCHAR(19),
    @Titular   NVARCHAR(60),
    @MesExp    TINYINT,
    @AnioExp   SMALLINT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Sel TABLE (AsientoID INT PRIMARY KEY);
    DECLARE @n INT, @Tokens INT, @SalaID INT, @Precio DECIMAL(8,2), @Marca VARCHAR(10),
            @Previos INT, @TarjetaID INT, @CompraID INT, @Ahora DATETIME2(0) = SYSDATETIME();

    /* --- Validaciones que no requieren bloqueo --- */
    IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE UsuarioID = @UsuarioID AND Activo = 1)
    BEGIN
        SELECT 10 AS Resultado, N'Debe iniciar sesión para comprar.' AS Mensaje, CAST(NULL AS INT) AS CompraID;
        RETURN;
    END

    IF @Asientos IS NULL OR @Asientos = '' OR @Asientos LIKE '%[^0-9,]%'
    BEGIN
        SELECT 12 AS Resultado, N'La selección de asientos no es válida.' AS Mensaje, CAST(NULL AS INT) AS CompraID;
        RETURN;
    END

    INSERT INTO @Sel (AsientoID)
    SELECT DISTINCT TRY_CAST(value AS INT) FROM STRING_SPLIT(@Asientos, ',')
    WHERE value <> '' AND TRY_CAST(value AS INT) IS NOT NULL;

    SELECT @n = COUNT(*) FROM @Sel;
    SELECT @Tokens = COUNT(*) FROM STRING_SPLIT(@Asientos, ',');

    IF @n = 0 OR @n <> @Tokens          -- vacíos o repetidos
    BEGIN
        SELECT 12 AS Resultado, N'La selección de asientos no es válida.' AS Mensaje, CAST(NULL AS INT) AS CompraID;
        RETURN;
    END
    IF @n > 10
    BEGIN
        SELECT 14 AS Resultado, N'Solo puede comprar hasta 10 boletos por función.' AS Mensaje, CAST(NULL AS INT) AS CompraID;
        RETURN;
    END

    SET @Numero  = REPLACE(REPLACE(@Numero, ' ', ''), '-', '');
    SET @Titular = LTRIM(RTRIM(@Titular));
    SET @Marca   = dbo.fn_MarcaTarjeta(@Numero);
    IF @Marca IS NULL OR dbo.fn_LuhnValido(@Numero) = 0
       OR ISNULL(@MesExp, 0) NOT BETWEEN 1 AND 12
       OR ISNULL(@AnioExp, 0) NOT BETWEEN YEAR(@Ahora) AND YEAR(@Ahora) + 15
       OR LEN(ISNULL(@Titular, N'')) < 3
    BEGIN
        SELECT 15 AS Resultado, N'Los datos de la tarjeta no son válidos.' AS Mensaje, CAST(NULL AS INT) AS CompraID;
        RETURN;
    END
    IF EOMONTH(DATEFROMPARTS(@AnioExp, @MesExp, 1)) < CAST(@Ahora AS DATE)
    BEGIN
        SELECT 15 AS Resultado, N'La tarjeta está vencida.' AS Mensaje, CAST(NULL AS INT) AS CompraID;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        /* 1. Bloqueo de la función */
        SELECT @SalaID = f.SalaID, @Precio = f.Precio
        FROM dbo.Funciones f WITH (UPDLOCK, HOLDLOCK)
        JOIN dbo.Peliculas p ON p.PeliculaID = f.PeliculaID
        WHERE f.FuncionID = @FuncionID AND f.Activa = 1 AND p.Activa = 1 AND f.FechaHora > @Ahora;

        IF @SalaID IS NULL
        BEGIN
            ROLLBACK;
            SELECT 11 AS Resultado, N'La función ya no está disponible para venta.' AS Mensaje, CAST(NULL AS INT) AS CompraID;
            RETURN;
        END

        /* 2. Asientos válidos y libres */
        IF EXISTS (SELECT 1 FROM @Sel s
                   LEFT JOIN dbo.Asientos a ON a.AsientoID = s.AsientoID AND a.SalaID = @SalaID
                   WHERE a.AsientoID IS NULL)
        BEGIN
            ROLLBACK;
            SELECT 12 AS Resultado, N'Uno o más asientos no pertenecen a la sala de esta función.' AS Mensaje, CAST(NULL AS INT) AS CompraID;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM dbo.Boletos b WITH (UPDLOCK, HOLDLOCK)
                   JOIN @Sel s ON s.AsientoID = b.AsientoID
                   WHERE b.FuncionID = @FuncionID)
        BEGIN
            ROLLBACK;
            SELECT 13 AS Resultado, N'Uno o más asientos acaban de ser vendidos. Elija otros.' AS Mensaje, CAST(NULL AS INT) AS CompraID;
            RETURN;
        END

        /* 3. Máximo 10 por usuario y función (incluye compras anteriores) */
        SELECT @Previos = COUNT(*)
        FROM dbo.Boletos b
        JOIN dbo.Compras c ON c.CompraID = b.CompraID
        WHERE c.UsuarioID = @UsuarioID AND b.FuncionID = @FuncionID;

        IF @Previos + @n > 10
        BEGIN
            ROLLBACK;
            SELECT 14 AS Resultado,
                   N'Límite de 10 boletos por función. Ya tiene ' + CAST(@Previos AS NVARCHAR(3))
                   + N' y puede comprar ' + CAST(10 - @Previos AS NVARCHAR(3)) + N' más.' AS Mensaje,
                   CAST(NULL AS INT) AS CompraID;
            RETURN;
        END

        /* 4. Tarjeta cifrada. El autenticador (UsuarioID) amarra el dato a su dueño:
              copiar el valor cifrado a otra fila no permite descifrarlo. */
        OPEN SYMMETRIC KEY SK_Tarjetas DECRYPTION BY CERTIFICATE Cert_Tarjetas;

        INSERT INTO dbo.Tarjetas (UsuarioID, Marca, NumeroCifrado, TitularCifrado, VencimientoCifrado)
        VALUES (@UsuarioID, @Marca,
                ENCRYPTBYKEY(KEY_GUID('SK_Tarjetas'), @Numero,  1, CONVERT(VARBINARY(4), @UsuarioID)),
                ENCRYPTBYKEY(KEY_GUID('SK_Tarjetas'), @Titular, 1, CONVERT(VARBINARY(4), @UsuarioID)),
                ENCRYPTBYKEY(KEY_GUID('SK_Tarjetas'),
                             RIGHT('0' + CAST(@MesExp AS VARCHAR(2)), 2) + '/' + CAST(@AnioExp AS VARCHAR(4)),
                             1, CONVERT(VARBINARY(4), @UsuarioID)));
        SET @TarjetaID = SCOPE_IDENTITY();

        CLOSE SYMMETRIC KEY SK_Tarjetas;

        /* 5. Compra y boletos */
        INSERT INTO dbo.Compras (UsuarioID, FuncionID, TarjetaID, Cantidad, Total, CodigoAutorizacion)
        VALUES (@UsuarioID, @FuncionID, @TarjetaID, @n, @n * @Precio,
                RIGHT('000000' + CAST(ABS(CAST(CRYPT_GEN_RANDOM(4) AS INT)) % 1000000 AS VARCHAR(7)), 6));
        SET @CompraID = SCOPE_IDENTITY();

        DECLARE @Alfabeto CHAR(32) = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        INSERT INTO dbo.Boletos (CompraID, FuncionID, SalaID, AsientoID, Precio, Codigo)
        SELECT @CompraID, @FuncionID, @SalaID, s.AsientoID, @Precio,
               SUBSTRING(@Alfabeto, CAST(SUBSTRING(r.b, 1, 1) AS INT) % 32 + 1, 1) +
               SUBSTRING(@Alfabeto, CAST(SUBSTRING(r.b, 2, 1) AS INT) % 32 + 1, 1) +
               SUBSTRING(@Alfabeto, CAST(SUBSTRING(r.b, 3, 1) AS INT) % 32 + 1, 1) +
               SUBSTRING(@Alfabeto, CAST(SUBSTRING(r.b, 4, 1) AS INT) % 32 + 1, 1) +
               SUBSTRING(@Alfabeto, CAST(SUBSTRING(r.b, 5, 1) AS INT) % 32 + 1, 1) +
               SUBSTRING(@Alfabeto, CAST(SUBSTRING(r.b, 6, 1) AS INT) % 32 + 1, 1) +
               SUBSTRING(@Alfabeto, CAST(SUBSTRING(r.b, 7, 1) AS INT) % 32 + 1, 1) +
               SUBSTRING(@Alfabeto, CAST(SUBSTRING(r.b, 8, 1) AS INT) % 32 + 1, 1) +
               SUBSTRING(@Alfabeto, CAST(SUBSTRING(r.b, 9, 1) AS INT) % 32 + 1, 1) +
               SUBSTRING(@Alfabeto, CAST(SUBSTRING(r.b, 10, 1) AS INT) % 32 + 1, 1)
        FROM @Sel s
        CROSS APPLY (SELECT HASHBYTES('SHA2_256', CAST(NEWID() AS VARBINARY(16)) + CAST(s.AsientoID AS VARBINARY(4))) AS b) r;

        COMMIT TRANSACTION;

        SELECT 0 AS Resultado, N'Compra realizada con éxito.' AS Mensaje, @CompraID AS CompraID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'SK_Tarjetas')
            CLOSE SYMMETRIC KEY SK_Tarjetas;

        IF ERROR_NUMBER() IN (2601, 2627) AND ERROR_MESSAGE() LIKE '%UQ_Boletos_Funcion_Asiento%'
            SELECT 13 AS Resultado, N'Uno o más asientos acaban de ser vendidos. Elija otros.' AS Mensaje, CAST(NULL AS INT) AS CompraID;
        ELSE IF ERROR_NUMBER() = 50010
            SELECT 14 AS Resultado, N'Límite de 10 boletos por función.' AS Mensaje, CAST(NULL AS INT) AS CompraID;
        ELSE
        BEGIN
            EXEC dbo.sp_RegistrarError;
            SELECT 99 AS Resultado, N'No fue posible completar la compra. Intente de nuevo.' AS Mensaje, CAST(NULL AS INT) AS CompraID;
        END
    END CATCH
END;
GO

/* Compra con sus boletos (para imprimir). Solo el dueño o un administrador.
   Descifra la tarjeta dentro del procedimiento y devuelve solo marca y
   últimos 4 dígitos. */
CREATE OR ALTER PROCEDURE app.sp_ObtenerCompra
    @CompraID  INT,
    @UsuarioID INT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Compras
                   WHERE CompraID = @CompraID
                     AND (UsuarioID = @UsuarioID OR dbo.fn_EsAdmin(@UsuarioID) = 1))
    BEGIN
        -- Encabezado vacío y boletos vacíos: la página responde "no encontrada"
        SELECT TOP (0) CAST(NULL AS INT) AS CompraID;
        SELECT TOP (0) CAST(NULL AS CHAR(10)) AS Codigo;
        RETURN;
    END

    OPEN SYMMETRIC KEY SK_Tarjetas DECRYPTION BY CERTIFICATE Cert_Tarjetas;

    SELECT c.CompraID, c.Folio, c.FechaCompra, c.Cantidad, c.Total, c.CodigoAutorizacion,
           t.Marca,
           RIGHT(CONVERT(VARCHAR(19), DECRYPTBYKEY(t.NumeroCifrado, 1, CONVERT(VARBINARY(4), t.UsuarioID))), 4) AS Ultimos4,
           u.Nombre + N' ' + u.Apellidos AS Cliente, u.Correo,
           f.FuncionID, f.FechaHora, f.Formato, f.Idioma, f.Precio,
           p.Titulo, p.Clasificacion, p.DuracionMin, p.Imagen,
           s.Nombre AS Sala
    FROM dbo.Compras c
    JOIN dbo.Tarjetas  t ON t.TarjetaID  = c.TarjetaID
    JOIN dbo.Usuarios  u ON u.UsuarioID  = c.UsuarioID
    JOIN dbo.Funciones f ON f.FuncionID  = c.FuncionID
    JOIN dbo.Peliculas p ON p.PeliculaID = f.PeliculaID
    JOIN dbo.Salas     s ON s.SalaID     = f.SalaID
    WHERE c.CompraID = @CompraID;

    CLOSE SYMMETRIC KEY SK_Tarjetas;

    SELECT b.BoletoID, b.Codigo, a.Fila, a.Numero, b.Precio
    FROM dbo.Boletos b
    JOIN dbo.Asientos a ON a.AsientoID = b.AsientoID
    WHERE b.CompraID = @CompraID
    ORDER BY a.Fila, a.Numero;
END;
GO

CREATE OR ALTER PROCEDURE app.sp_ComprasUsuario
    @UsuarioID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.CompraID, c.Folio, c.FechaCompra, c.Cantidad, c.Total,
           f.FechaHora, p.Titulo, p.Imagen, s.Nombre AS Sala,
           STRING_AGG(a.Fila + CAST(a.Numero AS VARCHAR(3)), ', ') WITHIN GROUP (ORDER BY a.Fila, a.Numero) AS Asientos
    FROM dbo.Compras c
    JOIN dbo.Funciones f ON f.FuncionID  = c.FuncionID
    JOIN dbo.Peliculas p ON p.PeliculaID = f.PeliculaID
    JOIN dbo.Salas     s ON s.SalaID     = f.SalaID
    JOIN dbo.Boletos   b ON b.CompraID   = c.CompraID
    JOIN dbo.Asientos  a ON a.AsientoID  = b.AsientoID
    WHERE c.UsuarioID = @UsuarioID
    GROUP BY c.CompraID, c.Folio, c.FechaCompra, c.Cantidad, c.Total, f.FechaHora, p.Titulo, p.Imagen, s.Nombre
    ORDER BY c.FechaCompra DESC;
END;
GO

/* =================================================================== */
/*  Módulo de administrador · R11                                       */
/*  Cada procedimiento comprueba en la base que @AdminID es ADMIN.      */
/* =================================================================== */

CREATE OR ALTER PROCEDURE app.sp_AdminResumen
    @AdminID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fn_EsAdmin(@AdminID) = 0 THROW 50403, N'Acceso solo para administradores.', 1;

    DECLARE @Hoy DATE = CAST(SYSDATETIME() AS DATE);
    SELECT
        (SELECT ISNULL(SUM(Total), 0) FROM dbo.Compras)                              AS TotalRecaudado,
        (SELECT COUNT(*) FROM dbo.Boletos)                                           AS BoletosVendidos,
        (SELECT COUNT(*) FROM dbo.Compras)                                           AS Compras,
        (SELECT COUNT(DISTINCT FuncionID) FROM dbo.Compras)                          AS FuncionesConVenta,
        (SELECT ISNULL(SUM(Total), 0) FROM dbo.Compras WHERE CAST(FechaCompra AS DATE) = @Hoy) AS RecaudadoHoy,
        (SELECT COUNT(*) FROM dbo.Usuarios WHERE Rol = 'CLIENTE')                   AS Clientes,
        (SELECT COUNT(*) FROM dbo.Funciones WHERE Activa = 1 AND FechaHora > SYSDATETIME()) AS FuncionesProgramadas,
        SYSDATETIME() AS Actualizado;
END;
GO

/* Funciones vendidas: cada función con al menos un boleto */
CREATE OR ALTER PROCEDURE app.sp_AdminFuncionesVendidas
    @AdminID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fn_EsAdmin(@AdminID) = 0 THROW 50403, N'Acceso solo para administradores.', 1;

    SELECT f.FuncionID, p.Titulo, s.Nombre AS Sala, f.FechaHora, f.Formato, f.Idioma, f.Precio, f.Activa,
           s.Filas * s.AsientosPorFila AS Capacidad,
           v.Boletos, v.Compras, v.Recaudado, v.UltimaVenta
    FROM dbo.Funciones f
    JOIN dbo.Peliculas p ON p.PeliculaID = f.PeliculaID
    JOIN dbo.Salas s ON s.SalaID = f.SalaID
    CROSS APPLY (
        SELECT SUM(c.Cantidad) AS Boletos, COUNT(*) AS Compras, SUM(c.Total) AS Recaudado, MAX(c.FechaCompra) AS UltimaVenta
        FROM dbo.Compras c WHERE c.FuncionID = f.FuncionID
    ) v
    WHERE v.Compras > 0
    ORDER BY v.UltimaVenta DESC;
END;
GO

CREATE OR ALTER PROCEDURE app.sp_AdminVentasPorPelicula
    @AdminID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fn_EsAdmin(@AdminID) = 0 THROW 50403, N'Acceso solo para administradores.', 1;

    SELECT p.PeliculaID, p.Titulo,
           ISNULL(SUM(c.Cantidad), 0) AS Boletos,
           ISNULL(SUM(c.Total), 0)    AS Recaudado
    FROM dbo.Peliculas p
    LEFT JOIN dbo.Funciones f ON f.PeliculaID = p.PeliculaID
    LEFT JOIN dbo.Compras c   ON c.FuncionID  = f.FuncionID
    GROUP BY p.PeliculaID, p.Titulo
    ORDER BY Recaudado DESC, p.Titulo;
END;
GO

/* Últimas compras. La tarjeta se descifra aquí y solo sale enmascarada. */
CREATE OR ALTER PROCEDURE app.sp_AdminUltimasVentas
    @AdminID INT,
    @Top     INT = 50
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fn_EsAdmin(@AdminID) = 0 THROW 50403, N'Acceso solo para administradores.', 1;
    IF @Top NOT BETWEEN 1 AND 500 SET @Top = 50;

    OPEN SYMMETRIC KEY SK_Tarjetas DECRYPTION BY CERTIFICATE Cert_Tarjetas;

    SELECT TOP (@Top) c.CompraID, c.Folio, c.FechaCompra, c.Cantidad, c.Total,
           u.Nombre + N' ' + u.Apellidos AS Cliente, u.Correo,
           p.Titulo, s.Nombre AS Sala, f.FechaHora, t.Marca,
           RIGHT(CONVERT(VARCHAR(19), DECRYPTBYKEY(t.NumeroCifrado, 1, CONVERT(VARBINARY(4), t.UsuarioID))), 4) AS Ultimos4
    FROM dbo.Compras c
    JOIN dbo.Usuarios  u ON u.UsuarioID  = c.UsuarioID
    JOIN dbo.Tarjetas  t ON t.TarjetaID  = c.TarjetaID
    JOIN dbo.Funciones f ON f.FuncionID  = c.FuncionID
    JOIN dbo.Peliculas p ON p.PeliculaID = f.PeliculaID
    JOIN dbo.Salas     s ON s.SalaID     = f.SalaID
    ORDER BY c.FechaCompra DESC, c.CompraID DESC;

    CLOSE SYMMETRIC KEY SK_Tarjetas;
END;
GO

CREATE OR ALTER PROCEDURE app.sp_AdminListarSalas
    @AdminID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fn_EsAdmin(@AdminID) = 0 THROW 50403, N'Acceso solo para administradores.', 1;
    SELECT SalaID, Nombre, Tipo, Filas * AsientosPorFila AS Capacidad FROM dbo.Salas ORDER BY Nombre;
END;
GO

/* Funciones para administrar (filtro opcional por fecha y película) */
CREATE OR ALTER PROCEDURE app.sp_AdminListarFunciones
    @AdminID    INT,
    @Fecha      DATE = NULL,
    @PeliculaID INT  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fn_EsAdmin(@AdminID) = 0 THROW 50403, N'Acceso solo para administradores.', 1;

    SELECT f.FuncionID, f.PeliculaID, p.Titulo, f.SalaID, s.Nombre AS Sala, f.FechaHora,
           f.Precio, f.Formato, f.Idioma, f.Activa, p.DuracionMin,
           s.Filas * s.AsientosPorFila AS Capacidad,
           (SELECT COUNT(*) FROM dbo.Boletos b WHERE b.FuncionID = f.FuncionID) AS Vendidos
    FROM dbo.Funciones f
    JOIN dbo.Peliculas p ON p.PeliculaID = f.PeliculaID
    JOIN dbo.Salas s ON s.SalaID = f.SalaID
    WHERE (@Fecha IS NULL OR CAST(f.FechaHora AS DATE) = @Fecha)
      AND (@PeliculaID IS NULL OR f.PeliculaID = @PeliculaID)
    ORDER BY f.FechaHora, s.Nombre;
END;
GO

CREATE OR ALTER PROCEDURE app.sp_AdminObtenerFuncion
    @AdminID   INT,
    @FuncionID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fn_EsAdmin(@AdminID) = 0 THROW 50403, N'Acceso solo para administradores.', 1;
    SELECT f.FuncionID, f.PeliculaID, f.SalaID, f.FechaHora, f.Precio, f.Formato, f.Idioma, f.Activa,
           (SELECT COUNT(*) FROM dbo.Boletos b WHERE b.FuncionID = f.FuncionID) AS Vendidos
    FROM dbo.Funciones f WHERE f.FuncionID = @FuncionID;
END;
GO

/* Alta (@FuncionID NULL) o modificación de una función y su horario.
   Valida que la sala no tenga otra función que se traslape
   (duración de la película + 15 min de limpieza). */
CREATE OR ALTER PROCEDURE app.sp_AdminGuardarFuncion
    @AdminID    INT,
    @FuncionID  INT = NULL,
    @PeliculaID INT,
    @SalaID     INT,
    @FechaHora  DATETIME2(0),
    @Precio     DECIMAL(8,2),
    @Formato    VARCHAR(3),
    @Idioma     VARCHAR(12),
    @Activa     BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF dbo.fn_EsAdmin(@AdminID) = 0 THROW 50403, N'Acceso solo para administradores.', 1;

    DECLARE @Duracion SMALLINT, @Vendidos INT = 0, @SalaActual INT, @FechaActual DATETIME2(0);

    SELECT @Duracion = DuracionMin FROM dbo.Peliculas WHERE PeliculaID = @PeliculaID;
    IF @Duracion IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.Salas WHERE SalaID = @SalaID)
    BEGIN
        SELECT 20 AS Resultado, N'Película o sala no válida.' AS Mensaje, CAST(NULL AS INT) AS FuncionID; RETURN;
    END
    IF @Precio IS NULL OR @Precio NOT BETWEEN 30 AND 500
    BEGIN
        SELECT 21 AS Resultado, N'El precio debe estar entre $30 y $500.' AS Mensaje, CAST(NULL AS INT) AS FuncionID; RETURN;
    END
    IF ISNULL(@Formato, '') NOT IN ('2D', '3D') OR ISNULL(@Idioma, '') NOT IN ('DOBLADA', 'SUBTITULADA') OR @Activa IS NULL OR @FechaHora IS NULL
    BEGIN
        SELECT 22 AS Resultado, N'Formato o idioma no válido.' AS Mensaje, CAST(NULL AS INT) AS FuncionID; RETURN;
    END

    IF @FuncionID IS NOT NULL
    BEGIN
        SELECT @SalaActual = SalaID, @FechaActual = FechaHora FROM dbo.Funciones WHERE FuncionID = @FuncionID;
        IF @SalaActual IS NULL
        BEGIN
            SELECT 23 AS Resultado, N'La función no existe.' AS Mensaje, CAST(NULL AS INT) AS FuncionID; RETURN;
        END
        SELECT @Vendidos = COUNT(*) FROM dbo.Boletos WHERE FuncionID = @FuncionID;
        IF @Vendidos > 0 AND @SalaActual <> @SalaID
        BEGIN
            SELECT 24 AS Resultado, N'La función ya tiene boletos vendidos: no se puede cambiar de sala.' AS Mensaje, @FuncionID AS FuncionID; RETURN;
        END
        IF @Vendidos > 0 AND (SELECT PeliculaID FROM dbo.Funciones WHERE FuncionID = @FuncionID) <> @PeliculaID
        BEGIN
            SELECT 25 AS Resultado, N'La función ya tiene boletos vendidos: no se puede cambiar la película.' AS Mensaje, @FuncionID AS FuncionID; RETURN;
        END
    END

    IF (@FuncionID IS NULL OR @FechaHora <> @FechaActual) AND @FechaHora <= SYSDATETIME()
    BEGIN
        SELECT 26 AS Resultado, N'El horario debe ser posterior a la fecha y hora actual.' AS Mensaje, @FuncionID AS FuncionID; RETURN;
    END

    IF @Activa = 1 AND EXISTS (
        SELECT 1 FROM dbo.Funciones f
        JOIN dbo.Peliculas p ON p.PeliculaID = f.PeliculaID
        WHERE f.SalaID = @SalaID AND f.Activa = 1 AND f.FuncionID <> ISNULL(@FuncionID, 0)
          AND f.FechaHora < DATEADD(MINUTE, @Duracion + 15, @FechaHora)
          AND @FechaHora  < DATEADD(MINUTE, p.DuracionMin + 15, f.FechaHora))
    BEGIN
        SELECT 27 AS Resultado, N'La sala ya tiene otra función en ese horario (se consideran la duración y 15 minutos de limpieza).' AS Mensaje, @FuncionID AS FuncionID; RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;
        IF @FuncionID IS NULL
        BEGIN
            INSERT INTO dbo.Funciones (PeliculaID, SalaID, FechaHora, Precio, Formato, Idioma, Activa)
            VALUES (@PeliculaID, @SalaID, @FechaHora, @Precio, @Formato, @Idioma, @Activa);
            SET @FuncionID = SCOPE_IDENTITY();
            INSERT INTO dbo.AuditoriaAdmin (AdminID, Accion, Tabla, RegistroID, Detalle)
            VALUES (@AdminID, 'ALTA', 'Funciones', @FuncionID, CONVERT(NVARCHAR(20), @FechaHora, 120));
        END
        ELSE
        BEGIN
            UPDATE dbo.Funciones
               SET PeliculaID = @PeliculaID, SalaID = @SalaID, FechaHora = @FechaHora, Precio = @Precio,
                   Formato = @Formato, Idioma = @Idioma, Activa = @Activa, FechaModificacion = SYSDATETIME()
             WHERE FuncionID = @FuncionID;
            INSERT INTO dbo.AuditoriaAdmin (AdminID, Accion, Tabla, RegistroID, Detalle)
            VALUES (@AdminID, 'MODIFICACION', 'Funciones', @FuncionID,
                    N'Antes: ' + CONVERT(NVARCHAR(20), @FechaActual, 120) + N' · Ahora: ' + CONVERT(NVARCHAR(20), @FechaHora, 120));
        END
        COMMIT TRANSACTION;
        SELECT 0 AS Resultado, N'Función guardada.' AS Mensaje, @FuncionID AS FuncionID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() IN (2601, 2627)
            SELECT 28 AS Resultado, N'Ya existe una función (activa o retirada) en esa sala a esa misma hora.' AS Mensaje, @FuncionID AS FuncionID;
        ELSE
        BEGIN
            EXEC dbo.sp_RegistrarError;
            SELECT 99 AS Resultado, N'No fue posible guardar la función.' AS Mensaje, @FuncionID AS FuncionID;
        END
    END CATCH
END;
GO

/* Borrar función. Si ya tiene boletos vendidos no se borra el historial
   de ventas: se retira de cartelera (Activa = 0). */
CREATE OR ALTER PROCEDURE app.sp_AdminEliminarFuncion
    @AdminID   INT,
    @FuncionID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF dbo.fn_EsAdmin(@AdminID) = 0 THROW 50403, N'Acceso solo para administradores.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Funciones WHERE FuncionID = @FuncionID)
    BEGIN
        SELECT 23 AS Resultado, N'La función no existe.' AS Mensaje; RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;
        IF EXISTS (SELECT 1 FROM dbo.Compras WITH (UPDLOCK, HOLDLOCK) WHERE FuncionID = @FuncionID)
        BEGIN
            UPDATE dbo.Funciones SET Activa = 0, FechaModificacion = SYSDATETIME() WHERE FuncionID = @FuncionID;
            INSERT INTO dbo.AuditoriaAdmin (AdminID, Accion, Tabla, RegistroID, Detalle)
            VALUES (@AdminID, 'RETIRO', 'Funciones', @FuncionID, N'Tenía boletos vendidos; se retiró de cartelera.');
            COMMIT TRANSACTION;
            SELECT 1 AS Resultado, N'La función tenía boletos vendidos: se retiró de la cartelera y se conservó su historial de ventas.' AS Mensaje;
            RETURN;
        END
        DELETE FROM dbo.Funciones WHERE FuncionID = @FuncionID;
        INSERT INTO dbo.AuditoriaAdmin (AdminID, Accion, Tabla, RegistroID, Detalle)
        VALUES (@AdminID, 'BAJA', 'Funciones', @FuncionID, N'Función eliminada.');
        COMMIT TRANSACTION;
        SELECT 0 AS Resultado, N'Función eliminada.' AS Mensaje;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        EXEC dbo.sp_RegistrarError;
        SELECT 99 AS Resultado, N'No fue posible eliminar la función.' AS Mensaje;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE app.sp_AdminListarPeliculas
    @AdminID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fn_EsAdmin(@AdminID) = 0 THROW 50403, N'Acceso solo para administradores.', 1;
    SELECT p.PeliculaID, p.Titulo, p.Sinopsis, p.Genero, p.Clasificacion, p.DuracionMin, p.Director,
           p.Imagen, p.FechaEstreno, p.Activa,
           (SELECT COUNT(*) FROM dbo.Funciones f WHERE f.PeliculaID = p.PeliculaID AND f.Activa = 1 AND f.FechaHora > SYSDATETIME()) AS FuncionesFuturas
    FROM dbo.Peliculas p
    ORDER BY p.Titulo;
END;
GO

/* Alta (@PeliculaID NULL) o modificación de una película (incluido su nombre) */
CREATE OR ALTER PROCEDURE app.sp_AdminGuardarPelicula
    @AdminID       INT,
    @PeliculaID    INT = NULL,
    @Titulo        NVARCHAR(100),
    @Sinopsis      NVARCHAR(600),
    @Genero        NVARCHAR(40),
    @Clasificacion VARCHAR(4),
    @DuracionMin   SMALLINT,
    @Director      NVARCHAR(80),
    @Imagen        VARCHAR(60),
    @FechaEstreno  DATE,
    @Activa        BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF dbo.fn_EsAdmin(@AdminID) = 0 THROW 50403, N'Acceso solo para administradores.', 1;

    SET @Titulo = LTRIM(RTRIM(@Titulo));
    DECLARE @TituloAnterior NVARCHAR(100), @DuracionAnterior SMALLINT;

    IF LEN(ISNULL(@Titulo, N'')) < 2 OR LEN(ISNULL(@Sinopsis, N'')) < 10 OR LEN(ISNULL(@Genero, N'')) < 3
       OR LEN(ISNULL(@Director, N'')) < 3 OR @FechaEstreno IS NULL
    BEGIN
        SELECT 30 AS Resultado, N'Revise los datos de la película.' AS Mensaje, @PeliculaID AS PeliculaID; RETURN;
    END
    IF ISNULL(@Clasificacion, '') NOT IN ('AA', 'A', 'B', 'B15', 'C', 'D') OR ISNULL(@DuracionMin, 0) NOT BETWEEN 60 AND 240
       OR @Activa IS NULL OR @Imagen IS NULL
    BEGIN
        SELECT 31 AS Resultado, N'Clasificación o duración no válida.' AS Mensaje, @PeliculaID AS PeliculaID; RETURN;
    END
    IF EXISTS (SELECT 1 FROM dbo.Peliculas WHERE Titulo = @Titulo AND PeliculaID <> ISNULL(@PeliculaID, 0))
    BEGIN
        SELECT 32 AS Resultado, N'Ya existe otra película con ese nombre.' AS Mensaje, @PeliculaID AS PeliculaID; RETURN;
    END

    IF @PeliculaID IS NOT NULL
    BEGIN
        SELECT @TituloAnterior = Titulo, @DuracionAnterior = DuracionMin FROM dbo.Peliculas WHERE PeliculaID = @PeliculaID;
        IF @TituloAnterior IS NULL
        BEGIN
            SELECT 33 AS Resultado, N'La película no existe.' AS Mensaje, @PeliculaID AS PeliculaID; RETURN;
        END
        -- Una duración mayor no debe encimar sus funciones futuras con la siguiente de la sala
        IF @DuracionMin > @DuracionAnterior AND EXISTS (
            SELECT 1
            FROM dbo.Funciones f
            JOIN dbo.Funciones g ON g.SalaID = f.SalaID AND g.FuncionID <> f.FuncionID AND g.Activa = 1
                                AND g.FechaHora >= f.FechaHora
                                AND g.FechaHora < DATEADD(MINUTE, @DuracionMin + 15, f.FechaHora)
            WHERE f.PeliculaID = @PeliculaID AND f.Activa = 1 AND f.FechaHora > SYSDATETIME())
        BEGIN
            SELECT 34 AS Resultado, N'Con esa duración, alguna función de la película se encimaría con la siguiente de su sala.' AS Mensaje, @PeliculaID AS PeliculaID; RETURN;
        END
    END

    BEGIN TRY
        BEGIN TRANSACTION;
        IF @PeliculaID IS NULL
        BEGIN
            INSERT INTO dbo.Peliculas (Titulo, Sinopsis, Genero, Clasificacion, DuracionMin, Director, Imagen, FechaEstreno, Activa)
            VALUES (@Titulo, @Sinopsis, @Genero, @Clasificacion, @DuracionMin, @Director, @Imagen, @FechaEstreno, @Activa);
            SET @PeliculaID = SCOPE_IDENTITY();
            INSERT INTO dbo.AuditoriaAdmin (AdminID, Accion, Tabla, RegistroID, Detalle)
            VALUES (@AdminID, 'ALTA', 'Peliculas', @PeliculaID, @Titulo);
        END
        ELSE
        BEGIN
            UPDATE dbo.Peliculas
               SET Titulo = @Titulo, Sinopsis = @Sinopsis, Genero = @Genero, Clasificacion = @Clasificacion,
                   DuracionMin = @DuracionMin, Director = @Director, Imagen = @Imagen,
                   FechaEstreno = @FechaEstreno, Activa = @Activa
             WHERE PeliculaID = @PeliculaID;
            INSERT INTO dbo.AuditoriaAdmin (AdminID, Accion, Tabla, RegistroID, Detalle)
            VALUES (@AdminID, 'MODIFICACION', 'Peliculas', @PeliculaID,
                    LEFT(N'Nombre: ' + @TituloAnterior + N' -> ' + @Titulo, 400));
        END
        COMMIT TRANSACTION;
        SELECT 0 AS Resultado, N'Película guardada.' AS Mensaje, @PeliculaID AS PeliculaID;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() IN (2601, 2627)
            SELECT 32 AS Resultado, N'Ya existe otra película con ese nombre.' AS Mensaje, @PeliculaID AS PeliculaID;
        ELSE
        BEGIN
            EXEC dbo.sp_RegistrarError;
            SELECT 99 AS Resultado, N'No fue posible guardar la película.' AS Mensaje, @PeliculaID AS PeliculaID;
        END
    END CATCH
END;
GO

/* Log de usuarios nuevos (lo llena el trigger) para verlo desde la web */
CREATE OR ALTER PROCEDURE app.sp_AdminLogUsuarios
    @AdminID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF dbo.fn_EsAdmin(@AdminID) = 0 THROW 50403, N'Acceso solo para administradores.', 1;
    SELECT TOP (100) LogID, UsuarioID, Correo, NombreCompleto, Rol, Evento, FechaRegistro, FechaLog, LoginBD, Equipo
    FROM dbo.LogUsuarios
    ORDER BY LogID DESC;
END;
GO

PRINT '05 · Funciones y procedimientos almacenados creados.';
GO

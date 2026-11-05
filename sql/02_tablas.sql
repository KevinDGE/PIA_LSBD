/* =====================================================================
   02_tablas.sql · Tablas, llaves primarias, llaves foráneas, índices y
   restricciones (R13).

   Reglas de integridad que garantiza la propia base de datos:
     * UQ_Boletos_Funcion_Asiento : un asiento no se vende dos veces en la
       misma función (aunque la aplicación fallara).
     * FK compuestas en Boletos   : el asiento pertenece a la sala de la
       función, y el boleto pertenece a la misma función que su compra.
     * CK_Compras_Cantidad        : de 1 a 10 boletos por compra.
       (el máximo de 10 por usuario y función, sumando compras anteriores,
        lo valida app.sp_ComprarBoletos y el trigger trg_Boletos_Max10).
     * Tarjetas no tiene columna para CVV: nunca se guarda.
   ===================================================================== */
USE CineAuroraDB;
GO

/* ---------------------------------------------------------------- */
/* Usuarios del portal (clientes y administradores)                 */
/* ---------------------------------------------------------------- */
CREATE TABLE dbo.Usuarios (
    UsuarioID         INT IDENTITY(1,1)  NOT NULL,
    Nombre            NVARCHAR(60)       NOT NULL,
    Apellidos         NVARCHAR(80)       NOT NULL,
    Correo            NVARCHAR(120)      NOT NULL,
    Telefono          VARCHAR(10)        NULL,
    PasswordHash      VARBINARY(64)      NOT NULL,   -- SHA2_512(sal + contraseña)
    Sal               VARBINARY(32)      NOT NULL,   -- 32 bytes aleatorios por usuario
    Rol               VARCHAR(10)        NOT NULL CONSTRAINT DF_Usuarios_Rol DEFAULT ('CLIENTE'),
    Activo            BIT                NOT NULL CONSTRAINT DF_Usuarios_Activo DEFAULT (1),
    IntentosFallidos  TINYINT            NOT NULL CONSTRAINT DF_Usuarios_Intentos DEFAULT (0),
    BloqueadoHasta    DATETIME2(0)       NULL,
    FechaRegistro     DATETIME2(0)       NOT NULL CONSTRAINT DF_Usuarios_Fecha DEFAULT (SYSDATETIME()),
    UltimoAcceso      DATETIME2(0)       NULL,
    CONSTRAINT PK_Usuarios PRIMARY KEY CLUSTERED (UsuarioID),
    CONSTRAINT UQ_Usuarios_Correo UNIQUE (Correo),
    CONSTRAINT CK_Usuarios_Rol CHECK (Rol IN ('CLIENTE', 'ADMIN')),
    CONSTRAINT CK_Usuarios_Correo CHECK (Correo LIKE '%_@_%._%' AND Correo NOT LIKE '% %'),
    CONSTRAINT CK_Usuarios_Telefono CHECK (Telefono IS NULL OR (LEN(Telefono) = 10 AND Telefono NOT LIKE '%[^0-9]%')),
    CONSTRAINT CK_Usuarios_Hash CHECK (DATALENGTH(PasswordHash) = 64),
    CONSTRAINT CK_Usuarios_Sal  CHECK (DATALENGTH(Sal) = 32),
    CONSTRAINT CK_Usuarios_Nombre CHECK (LEN(Nombre) >= 2 AND LEN(Apellidos) >= 2)
);
GO

/* ---------------------------------------------------------------- */
/* Log de usuarios nuevos (lo llena trg_Usuarios_LogAlta) · R15      */
/* Sin columnas de contraseña, hash ni sal.                          */
/* No lleva FK a Usuarios a propósito: el historial debe conservarse */
/* aunque el usuario se elimine.                                     */
/* ---------------------------------------------------------------- */
CREATE TABLE dbo.LogUsuarios (
    LogID             INT IDENTITY(1,1)  NOT NULL,
    UsuarioID         INT                NOT NULL,
    Correo            NVARCHAR(120)      NOT NULL,
    NombreCompleto    NVARCHAR(141)      NOT NULL,
    Rol               VARCHAR(10)        NOT NULL,
    Evento            VARCHAR(20)        NOT NULL CONSTRAINT DF_LogUsuarios_Evento DEFAULT ('ALTA DE USUARIO'),
    FechaRegistro     DATETIME2(0)       NOT NULL,
    FechaLog          DATETIME2(3)       NOT NULL CONSTRAINT DF_LogUsuarios_FechaLog DEFAULT (SYSDATETIME()),
    LoginBD           NVARCHAR(128)      NOT NULL CONSTRAINT DF_LogUsuarios_Login DEFAULT (ORIGINAL_LOGIN()),
    Equipo            NVARCHAR(128)      NULL     CONSTRAINT DF_LogUsuarios_Host DEFAULT (HOST_NAME()),
    Aplicacion        NVARCHAR(128)      NULL     CONSTRAINT DF_LogUsuarios_App DEFAULT (APP_NAME()),
    CONSTRAINT PK_LogUsuarios PRIMARY KEY CLUSTERED (LogID)
);
CREATE INDEX IX_LogUsuarios_Usuario ON dbo.LogUsuarios (UsuarioID);
GO

/* ---------------------------------------------------------------- */
/* Catálogo de películas (ficticias)                                 */
/* ---------------------------------------------------------------- */
CREATE TABLE dbo.Peliculas (
    PeliculaID        INT IDENTITY(1,1)  NOT NULL,
    Titulo            NVARCHAR(100)      NOT NULL,
    Sinopsis          NVARCHAR(600)      NOT NULL,
    Genero            NVARCHAR(40)       NOT NULL,
    Clasificacion     VARCHAR(4)         NOT NULL,
    DuracionMin       SMALLINT           NOT NULL,
    Director          NVARCHAR(80)       NOT NULL,
    Imagen            VARCHAR(60)        NOT NULL,   -- archivo dentro de assets/img/posters/
    FechaEstreno      DATE               NOT NULL,
    Activa            BIT                NOT NULL CONSTRAINT DF_Peliculas_Activa DEFAULT (1),
    FechaAlta         DATETIME2(0)       NOT NULL CONSTRAINT DF_Peliculas_Alta DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Peliculas PRIMARY KEY CLUSTERED (PeliculaID),
    CONSTRAINT UQ_Peliculas_Titulo UNIQUE (Titulo),
    CONSTRAINT CK_Peliculas_Clasif CHECK (Clasificacion IN ('AA', 'A', 'B', 'B15', 'C', 'D')),
    CONSTRAINT CK_Peliculas_Duracion CHECK (DuracionMin BETWEEN 60 AND 240),
    CONSTRAINT CK_Peliculas_Titulo CHECK (LEN(Titulo) >= 2),
    CONSTRAINT CK_Peliculas_Imagen CHECK (Imagen LIKE '[a-z0-9]%.svg' AND Imagen NOT LIKE '%[^a-z0-9._-]%')
);
GO

/* ---------------------------------------------------------------- */
/* Salas y asientos                                                  */
/* ---------------------------------------------------------------- */
CREATE TABLE dbo.Salas (
    SalaID            INT IDENTITY(1,1)  NOT NULL,
    Nombre            NVARCHAR(30)       NOT NULL,
    Tipo              VARCHAR(12)        NOT NULL,
    Filas             TINYINT            NOT NULL,
    AsientosPorFila   TINYINT            NOT NULL,
    CONSTRAINT PK_Salas PRIMARY KEY CLUSTERED (SalaID),
    CONSTRAINT UQ_Salas_Nombre UNIQUE (Nombre),
    CONSTRAINT CK_Salas_Tipo CHECK (Tipo IN ('TRADICIONAL', 'VIP', '3D')),
    CONSTRAINT CK_Salas_Filas CHECK (Filas BETWEEN 1 AND 26),
    CONSTRAINT CK_Salas_Asientos CHECK (AsientosPorFila BETWEEN 1 AND 30)
);
GO

CREATE TABLE dbo.Asientos (
    AsientoID         INT IDENTITY(1,1)  NOT NULL,
    SalaID            INT                NOT NULL,
    Fila              CHAR(1)            NOT NULL,
    Numero            TINYINT            NOT NULL,
    CONSTRAINT PK_Asientos PRIMARY KEY CLUSTERED (AsientoID),
    CONSTRAINT FK_Asientos_Salas FOREIGN KEY (SalaID) REFERENCES dbo.Salas (SalaID),
    CONSTRAINT UQ_Asientos_Sala_Fila_Numero UNIQUE (SalaID, Fila, Numero),
    CONSTRAINT UQ_Asientos_Asiento_Sala UNIQUE (AsientoID, SalaID),      -- destino de FK compuesta
    CONSTRAINT CK_Asientos_Fila CHECK (Fila LIKE '[A-Z]'),
    CONSTRAINT CK_Asientos_Numero CHECK (Numero BETWEEN 1 AND 30)
);
GO

/* ---------------------------------------------------------------- */
/* Funciones (película + sala + fecha y hora)                        */
/* ---------------------------------------------------------------- */
CREATE TABLE dbo.Funciones (
    FuncionID         INT IDENTITY(1,1)  NOT NULL,
    PeliculaID        INT                NOT NULL,
    SalaID            INT                NOT NULL,
    FechaHora         DATETIME2(0)       NOT NULL,
    Precio            DECIMAL(8,2)       NOT NULL,
    Formato           VARCHAR(3)         NOT NULL CONSTRAINT DF_Funciones_Formato DEFAULT ('2D'),
    Idioma            VARCHAR(12)        NOT NULL CONSTRAINT DF_Funciones_Idioma DEFAULT ('DOBLADA'),
    Activa            BIT                NOT NULL CONSTRAINT DF_Funciones_Activa DEFAULT (1),
    FechaAlta         DATETIME2(0)       NOT NULL CONSTRAINT DF_Funciones_Alta DEFAULT (SYSDATETIME()),
    FechaModificacion DATETIME2(0)       NULL,
    CONSTRAINT PK_Funciones PRIMARY KEY CLUSTERED (FuncionID),
    CONSTRAINT FK_Funciones_Peliculas FOREIGN KEY (PeliculaID) REFERENCES dbo.Peliculas (PeliculaID),
    CONSTRAINT FK_Funciones_Salas FOREIGN KEY (SalaID) REFERENCES dbo.Salas (SalaID),
    CONSTRAINT UQ_Funciones_Sala_FechaHora UNIQUE (SalaID, FechaHora),
    CONSTRAINT UQ_Funciones_Funcion_Sala UNIQUE (FuncionID, SalaID),     -- destino de FK compuesta
    CONSTRAINT CK_Funciones_Precio CHECK (Precio BETWEEN 30 AND 500),
    CONSTRAINT CK_Funciones_Formato CHECK (Formato IN ('2D', '3D')),
    CONSTRAINT CK_Funciones_Idioma CHECK (Idioma IN ('DOBLADA', 'SUBTITULADA'))
);
CREATE INDEX IX_Funciones_Pelicula_Fecha ON dbo.Funciones (PeliculaID, FechaHora) INCLUDE (SalaID, Precio, Formato, Idioma, Activa);
CREATE INDEX IX_Funciones_Fecha ON dbo.Funciones (FechaHora) INCLUDE (PeliculaID, SalaID, Activa);
GO

/* ---------------------------------------------------------------- */
/* Tarjetas (R17): número, titular y vencimiento cifrados con        */
/* ENCRYPTBYKEY (AES_256). VARBINARY y sin columna de CVV.           */
/* La restricción que exige el GUID de la llave se agrega en 04.     */
/* ---------------------------------------------------------------- */
CREATE TABLE dbo.Tarjetas (
    TarjetaID          INT IDENTITY(1,1) NOT NULL,
    UsuarioID          INT               NOT NULL,
    Marca              VARCHAR(10)       NOT NULL,
    NumeroCifrado      VARBINARY(256)    NOT NULL,
    TitularCifrado     VARBINARY(256)    NOT NULL,
    VencimientoCifrado VARBINARY(256)    NOT NULL,
    FechaRegistro      DATETIME2(0)      NOT NULL CONSTRAINT DF_Tarjetas_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Tarjetas PRIMARY KEY CLUSTERED (TarjetaID),
    CONSTRAINT FK_Tarjetas_Usuarios FOREIGN KEY (UsuarioID) REFERENCES dbo.Usuarios (UsuarioID),
    CONSTRAINT CK_Tarjetas_Marca CHECK (Marca IN ('VISA', 'MASTERCARD', 'AMEX'))
);
CREATE INDEX IX_Tarjetas_Usuario ON dbo.Tarjetas (UsuarioID);
GO

/* ---------------------------------------------------------------- */
/* Compras (tabla productiva) y boletos                              */
/* ---------------------------------------------------------------- */
CREATE TABLE dbo.Compras (
    CompraID           INT IDENTITY(1,1) NOT NULL,
    Folio              AS ('CA' + RIGHT('00000000' + CAST(CompraID AS VARCHAR(10)), 8)) PERSISTED,
    UsuarioID          INT               NOT NULL,
    FuncionID          INT               NOT NULL,
    TarjetaID          INT               NOT NULL,
    Cantidad           TINYINT           NOT NULL,
    Total              DECIMAL(10,2)     NOT NULL,
    CodigoAutorizacion CHAR(6)           NOT NULL,
    FechaCompra        DATETIME2(0)      NOT NULL CONSTRAINT DF_Compras_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Compras PRIMARY KEY CLUSTERED (CompraID),
    CONSTRAINT FK_Compras_Usuarios FOREIGN KEY (UsuarioID) REFERENCES dbo.Usuarios (UsuarioID),
    CONSTRAINT FK_Compras_Funciones FOREIGN KEY (FuncionID) REFERENCES dbo.Funciones (FuncionID),
    CONSTRAINT FK_Compras_Tarjetas FOREIGN KEY (TarjetaID) REFERENCES dbo.Tarjetas (TarjetaID),
    CONSTRAINT UQ_Compras_Tarjeta UNIQUE (TarjetaID),                    -- un registro de tarjeta por pago
    CONSTRAINT UQ_Compras_Compra_Funcion UNIQUE (CompraID, FuncionID),   -- destino de FK compuesta
    CONSTRAINT CK_Compras_Cantidad CHECK (Cantidad BETWEEN 1 AND 10),
    CONSTRAINT CK_Compras_Total CHECK (Total > 0),
    CONSTRAINT CK_Compras_Autorizacion CHECK (CodigoAutorizacion NOT LIKE '%[^0-9]%')
);
CREATE INDEX IX_Compras_Usuario ON dbo.Compras (UsuarioID, FechaCompra DESC);
CREATE INDEX IX_Compras_Funcion_Usuario ON dbo.Compras (FuncionID, UsuarioID) INCLUDE (Cantidad, Total);
GO

CREATE TABLE dbo.Boletos (
    BoletoID           INT IDENTITY(1,1) NOT NULL,
    CompraID           INT               NOT NULL,
    FuncionID          INT               NOT NULL,
    SalaID             INT               NOT NULL,
    AsientoID          INT               NOT NULL,
    Precio             DECIMAL(8,2)      NOT NULL,
    Codigo             CHAR(10)          NOT NULL,
    CONSTRAINT PK_Boletos PRIMARY KEY CLUSTERED (BoletoID),
    -- R13: evita vender dos veces el mismo asiento de la misma función
    CONSTRAINT UQ_Boletos_Funcion_Asiento UNIQUE (FuncionID, AsientoID),
    CONSTRAINT UQ_Boletos_Codigo UNIQUE (Codigo),
    -- el boleto pertenece a la misma función que la compra
    CONSTRAINT FK_Boletos_Compras FOREIGN KEY (CompraID, FuncionID) REFERENCES dbo.Compras (CompraID, FuncionID),
    -- la sala del boleto es la sala de la función
    CONSTRAINT FK_Boletos_Funciones FOREIGN KEY (FuncionID, SalaID) REFERENCES dbo.Funciones (FuncionID, SalaID),
    -- el asiento existe y pertenece a esa misma sala
    CONSTRAINT FK_Boletos_Asientos FOREIGN KEY (AsientoID, SalaID) REFERENCES dbo.Asientos (AsientoID, SalaID),
    CONSTRAINT CK_Boletos_Precio CHECK (Precio > 0),
    CONSTRAINT CK_Boletos_Codigo CHECK (Codigo NOT LIKE '%[^A-Z0-9]%' AND LEN(Codigo) = 10)
);
CREATE INDEX IX_Boletos_Compra ON dbo.Boletos (CompraID);
GO

/* ---------------------------------------------------------------- */
/* Bitácora de cambios hechos por administradores                    */
/* ---------------------------------------------------------------- */
CREATE TABLE dbo.AuditoriaAdmin (
    AuditoriaID        INT IDENTITY(1,1) NOT NULL,
    AdminID            INT               NOT NULL,
    Accion             VARCHAR(20)       NOT NULL,
    Tabla              VARCHAR(30)       NOT NULL,
    RegistroID         INT               NOT NULL,
    Detalle            NVARCHAR(400)     NULL,
    Fecha              DATETIME2(0)      NOT NULL CONSTRAINT DF_Auditoria_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_AuditoriaAdmin PRIMARY KEY CLUSTERED (AuditoriaID),
    CONSTRAINT FK_Auditoria_Usuarios FOREIGN KEY (AdminID) REFERENCES dbo.Usuarios (UsuarioID),
    CONSTRAINT CK_Auditoria_Accion CHECK (Accion IN ('ALTA', 'MODIFICACION', 'BAJA', 'RETIRO'))
);
GO

/* ---------------------------------------------------------------- */
/* Errores internos: los procedimientos los guardan aquí y la        */
/* aplicación solo muestra un mensaje genérico al usuario.           */
/* ---------------------------------------------------------------- */
CREATE TABLE dbo.LogErrores (
    ErrorID            INT IDENTITY(1,1) NOT NULL,
    Fecha              DATETIME2(3)      NOT NULL CONSTRAINT DF_LogErrores_Fecha DEFAULT (SYSDATETIME()),
    Procedimiento      NVARCHAR(128)     NULL,
    Numero             INT               NULL,
    Mensaje            NVARCHAR(4000)    NULL,
    Linea              INT               NULL,
    LoginBD            NVARCHAR(128)     NOT NULL CONSTRAINT DF_LogErrores_Login DEFAULT (ORIGINAL_LOGIN()),
    CONSTRAINT PK_LogErrores PRIMARY KEY CLUSTERED (ErrorID)
);
GO

PRINT '02 · Tablas, llaves, índices y restricciones creados.';
GO

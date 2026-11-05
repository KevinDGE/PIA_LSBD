/* =====================================================================
   01_crear_base.sql
   Proyecto Integrador · Laboratorio de Seguridad en Bases de Datos
   UANL · FCFM · Equipo 3 · Portal "Cine Aurora"

   Crea la base de datos CineAuroraDB y los esquemas:
     - dbo : tablas (nadie de la aplicación tiene permiso directo sobre ellas)
     - app : procedimientos almacenados que la aplicación sí puede ejecutar

   Ejecutar en SSMS conectado como administrador de la instancia
   (Autenticación de Windows, usuario Administrador de la VM).
   ===================================================================== */
USE master;
GO

IF DB_ID(N'CineAuroraDB') IS NOT NULL
BEGIN
    PRINT 'La base CineAuroraDB ya existe: se elimina para crearla de nuevo.';
    ALTER DATABASE CineAuroraDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE CineAuroraDB;
END
GO

-- Intercalación española, sin distinguir mayúsculas (correo "Ana@x.com" = "ana@x.com")
CREATE DATABASE CineAuroraDB
    COLLATE Modern_Spanish_100_CI_AS;
GO

/* Dueño de la base = sa (SID 0x01, igual en todas las instancias), aunque sa
   quede desactivado en el script 08. Así los procedimientos WITH EXECUTE AS
   OWNER siguen funcionando si la base se restaura en otra instancia, donde
   no existe el usuario de Windows que la creó. */
DECLARE @sa SYSNAME = SUSER_NAME(0x01);
DECLARE @sql NVARCHAR(200) = N'ALTER AUTHORIZATION ON DATABASE::CineAuroraDB TO ' + QUOTENAME(@sa) + N';';
EXEC sys.sp_executesql @sql;
GO

ALTER DATABASE CineAuroraDB SET RECOVERY FULL;          -- permite respaldos de log
ALTER DATABASE CineAuroraDB SET PAGE_VERIFY CHECKSUM;   -- detecta páginas dañadas
ALTER DATABASE CineAuroraDB SET TRUSTWORTHY OFF;        -- valor seguro (por defecto)
-- Lecturas sin bloqueo contra escrituras: el mapa de asientos no espera a las compras en curso
ALTER DATABASE CineAuroraDB SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
GO

USE CineAuroraDB;
GO
CREATE SCHEMA app AUTHORIZATION dbo;   -- procedimientos expuestos a la aplicación
GO

PRINT '01 · Base CineAuroraDB y esquema app creados.';
GO

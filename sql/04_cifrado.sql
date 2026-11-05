/* =====================================================================
   04_cifrado.sql · Cifrado por columna de tarjetas (R17)

   Jerarquía de llaves (todas disponibles en SQL Server 2022 Express):

     Service Master Key (de la instancia, la crea SQL Server)
        └── Database Master Key  (llave maestra de CineAuroraDB)
              └── Certificado Cert_Tarjetas
                    └── Llave simétrica SK_Tarjetas (AES_256)
                          └── ENCRYPTBYKEY(...) → columnas VARBINARY de dbo.Tarjetas

   * La llave simétrica solo se abre DENTRO de procedimientos almacenados
     (app.sp_ComprarBoletos y app.sp_AdminDetalleCompra, en el script 05).
   * El usuario de la aplicación no recibe ningún permiso sobre la llave ni
     sobre el certificado: no puede ejecutar OPEN SYMMETRIC KEY por su cuenta.
   * IMPORTANTE: cambie las contraseñas de este script antes de ejecutarlo
     en su VM y guárdelas fuera de la VM. Sin la contraseña de la llave
     maestra no se puede restaurar la base en otra instancia (ver 09 y 10).
   ===================================================================== */
USE CineAuroraDB;
GO

/* 1. Llave maestra de la base de datos (DMK) */
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Aurora#LlaveMaestra_2026!';
GO

/* 2. Certificado protegido por la llave maestra */
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'Cert_Tarjetas')
    CREATE CERTIFICATE Cert_Tarjetas
        WITH SUBJECT = 'Cine Aurora - proteccion de tarjetas',
             EXPIRY_DATE = '2031-12-31';
GO

/* 3. Llave simétrica AES de 256 bits protegida por el certificado */
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'SK_Tarjetas')
    CREATE SYMMETRIC KEY SK_Tarjetas
        WITH ALGORITHM = AES_256
        ENCRYPTION BY CERTIFICATE Cert_Tarjetas;
GO

/* 4. Restricción: toda fila de dbo.Tarjetas debe venir cifrada con SK_Tarjetas.
      Los primeros 16 bytes que produce ENCRYPTBYKEY son el GUID de la llave;
      si alguien intenta guardar un número en claro, la inserción falla. */
ALTER TABLE dbo.Tarjetas WITH CHECK ADD
    CONSTRAINT CK_Tarjetas_NumeroCifrado
        CHECK (SUBSTRING(NumeroCifrado, 1, 16) = CAST(KEY_GUID('SK_Tarjetas') AS VARBINARY(16))),
    CONSTRAINT CK_Tarjetas_TitularCifrado
        CHECK (SUBSTRING(TitularCifrado, 1, 16) = CAST(KEY_GUID('SK_Tarjetas') AS VARBINARY(16))),
    CONSTRAINT CK_Tarjetas_VencCifrado
        CHECK (SUBSTRING(VencimientoCifrado, 1, 16) = CAST(KEY_GUID('SK_Tarjetas') AS VARBINARY(16)));
GO

/* Comprobación */
SELECT name AS Llave, algorithm_desc AS Algoritmo, key_length AS Bits, create_date AS Creada
FROM sys.symmetric_keys;
SELECT name AS Certificado, subject AS Sujeto, pvt_key_encryption_type_desc AS ProteccionLlavePrivada, expiry_date AS Vence
FROM sys.certificates WHERE name = 'Cert_Tarjetas';
PRINT '04 · Llave maestra, certificado y llave simétrica AES_256 creados.';
GO

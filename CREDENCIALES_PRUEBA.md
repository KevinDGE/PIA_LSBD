# Credenciales de prueba · Cine Aurora

Todos los datos son **ficticios**. Los correos usan el dominio reservado `.test` y las tarjetas son números de prueba públicos que pasan la validación de Luhn pero no existen: no hay ningún cobro.

## Usuarios del portal (creados por `sql/07_datos_demo.sql`)

| Rol | Correo | Contraseña | Para qué sirve en la demostración |
|---|---|---|---|
| Administrador | `admin@cineaurora.test` | `Admin#Aurora2026` | Panel en vivo, funciones, películas, ventas y log |
| Cliente | `ana.garcia@correo.test` | `Cliente#Ana2026` | Tiene 2 compras de ejemplo (Visa y Amex) |
| Cliente | `luis.hernandez@correo.test` | `Cliente#Luis2026` | Tiene 8 boletos en una función: prueba del límite de 10 (ver `12_preparar_revision.sql`) |
| Cliente | `sofia.martinez@correo.test` | `Cliente#Sofia2026` | Sin compras: para la compra en vivo |

- El administrador **solo** se crea por script (`dbo.sp_CrearUsuario`, que la aplicación no puede ejecutar). Desde la web únicamente se registran clientes.
- Tras 5 contraseñas incorrectas la cuenta se bloquea 5 minutos. Para desbloquear: ejecutar `sql/12_preparar_revision.sql`.

## Tarjetas de prueba

| Marca | Número | CVV | Resultado |
|---|---|---|---|
| Visa | `4111 1111 1111 1111` | 3 dígitos (p. ej. `123`) | Aprobada |
| Visa | `4242 4242 4242 4242` | 3 dígitos | Aprobada |
| Mastercard | `5555 5555 5555 4444` | 3 dígitos | Aprobada |
| Mastercard (serie 2) | `2223 0031 2200 3222` | 3 dígitos | Aprobada |
| American Express | `3782 822463 10005` | **4 dígitos** (p. ej. `1234`) | Aprobada |
| American Express | `3714 496353 98431` | 4 dígitos | Aprobada |
| Visa | `4000 0000 0000 0002` | 3 dígitos | **Rechazada por el banco (simulación)** |
| Visa | `4111 1111 1111 1112` | — | Error: no pasa Luhn |
| Discover | `6011 1111 1111 1117` | — | Error: marca no aceptada |

Vencimiento: cualquier mes y año **futuros**. Un mes ya pasado del año actual da *La tarjeta está vencida*. La marca seleccionada debe coincidir con el número (el formulario la detecta sola).

## Inicios de sesión de SQL Server

| Login | Tipo | Estado | Uso |
|---|---|---|---|
| `SRV-CINE\Administrador` (su usuario de Windows) | Windows, sysadmin | Activo | Administración en SSMS con **Autenticación de Windows** |
| `cine_app` / `C1ne#Aurora_App2026` | SQL Server | Activo | **Único** login SQL: lo usa la aplicación (`includes/config.php`). Solo `EXECUTE` en el esquema `app` |
| `sa` | SQL Server | **Desactivado** (script 08) | Dueño de la base; no puede iniciar sesión |

## Contraseñas de cifrado y respaldo

Guárdenlas fuera de la VM. Sin la de la llave maestra (o sin sus archivos de respaldo) no se recuperan las tarjetas al restaurar en otra instancia.

| Elemento | Contraseña | Script |
|---|---|---|
| Llave maestra de `CineAuroraDB` (DMK) | `Aurora#LlaveMaestra_2026!` | 04, 10 |
| Archivo de respaldo de la DMK (`.key`) | `Aurora#RespaldoDMK_2026!` | 09, 10 (plan B) |
| Llave privada del certificado (`.pvk`) | `Aurora#RespaldoCert_2026!` | 09 |
| Archivo de respaldo de la llave simétrica | `Aurora#RespaldoSK_2026!` | 09 |

Si cambian alguna, cámbienla en todos los scripts indicados (y la de `cine_app` también en `config.php`).

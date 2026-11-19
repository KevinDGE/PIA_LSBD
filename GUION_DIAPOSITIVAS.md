# Guion de la presentación · Cine Aurora

**PIA Laboratorio de Seguridad en Bases de Datos · Equipo 3**

Solo las 13 diapositivas, sin la demostración en vivo. Duración: **unos 11 minutos**.

| Integrante | Diapositivas | Tiempo |
|---|---|---|
| **Kevin** Daniel Grimaldo Esquivel | 1, 2 y 3 · al final 12 y 13 | 4 min |
| **David** Emiliano Rangel Tovar | 4 y 5 | 2 min |
| **Fernando** Garza Chavez | 6 y 7 | 2 min |
| **Alejandro** Martinez Moya | 8 y 9 | 2 min |
| **Daniel** Diaz Viruega | 10 y 11 | 1 min 30 s |

Lo que está entre corchetes **[así]** es lo que se señala en pantalla; no se lee.

---

## 1 · Portada — Kevin (30 s)

> Buenas tardes. Somos el equipo 3 del Laboratorio de Seguridad en Bases de Datos. Nos tocó el proceso de compra de boletos de cine y les presentamos **Cine Aurora**: un portal de venta de boletos con cartelera, pago simulado y seguridad en SQL Server 2022.

## 2 · Equipo 3 — Kevin (30 s)

> El equipo somos Kevin Grimaldo, David Rangel, Fernando Garza, Alejandro Martínez y Daniel Díaz. **[Señalar la franja de abajo]** La base de datos se llama CineAuroraDB y el entorno es una máquina virtual con Windows Server 2022, SQL Server 2022 Express y Apache de XAMPP con PHP.

## 3 · Objetivo: vender boletos sin exponer datos — Kevin (1 min)

> El objetivo fue construir el portal de un cine donde cualquier visitante ve la cartelera, el cliente registrado elige función, asientos y paga con una tarjeta simulada, y el administrador ve las ventas en vivo, cuidando la base de datos en cada capa.
>
> Estos cuatro números resumen las reglas principales:
> - **[10]** Un cliente puede comprar máximo 10 boletos por función, contando sus compras anteriores. Lo validamos en PHP, en el procedimiento almacenado y con un trigger.
> - **[AES-256]** El número, el titular y el vencimiento de la tarjeta se guardan cifrados.
> - **[SHA2_512]** Las contraseñas se guardan como hash con una sal de 32 bytes por usuario, y el login se compara dentro de SQL Server.
> - **[1]** La aplicación usa un solo usuario de SQL Server, `cine_app`, que solo puede ejecutar procedimientos.
>
> David les explica cómo está armado.

## 4 · Arquitectura local en una máquina virtual — David (1 min)

> Todo corre dentro de la máquina virtual. **[De izquierda a derecha]** El navegador, del cliente o del administrador, habla por HTTP con Apache de XAMPP, que sirve las 17 páginas PHP. PHP se conecta con los drivers oficiales de Microsoft, `pdo_sqlsrv` sobre el ODBC Driver 18, y la conexión va cifrada. Del otro lado está SQL Server 2022 Express con la base CineAuroraDB, 24 procedimientos almacenados, la llave de cifrado, los triggers y el respaldo.
>
> **[Señalar el recuadro de conexión]** La aplicación entra por el puerto 1433 con el usuario `cine_app` y solo ejecuta procedimientos del esquema `app` con parámetros. El usuario `sa` está desactivado; la base se administra con autenticación de Windows. Además, las credenciales están en un solo archivo, `config.php`, que no se puede abrir desde el navegador.

## 5 · Modelo de datos con integridad en la base — David (1 min)

> Tenemos ocho tablas principales. **[Señalar Boletos, la del borde verde]** La más importante es **Boletos**. Tiene una restricción **UNIQUE sobre función y asiento**: aunque la aplicación fallara, SQL Server no deja vender dos veces el mismo asiento de la misma función.
>
> También usa llaves foráneas **compuestas**: el asiento tiene que ser de la sala de esa función, y el boleto tiene que ser de la misma función que su compra. Hay restricciones CHECK, como de 1 a 10 boletos por compra o la clasificación de la película, e índices para las búsquedas. **[Señalar Tarjetas]** La tabla de tarjetas guarda el número en VARBINARY y no tiene columna para el CVV.
>
> **[Señalar la línea de abajo]** Y tenemos tres bitácoras: el log de usuarios nuevos, que llena un trigger; los cambios del administrador; y los errores internos, que nunca se le muestran al usuario.
>
> Fernando les explica el flujo de compra.

## 6 · Flujo de compra del cliente — Fernando (1 min)

> El cliente sigue seis pasos. **[Recorrer los círculos]** Ve la cartelera sin necesidad de cuenta; entra a una película y ve todos sus horarios; para comprar tiene que iniciar sesión, y eso lo bloqueamos también en el servidor, no solo escondiendo el botón; elige sus asientos en un mapa que distingue libres y ocupados; paga con Visa, Mastercard o American Express, validando la marca, el algoritmo de Luhn y el vencimiento; y al final obtiene sus boletos con código de barras para imprimir.
>
> **[Señalar las capturas]** A la izquierda está el mapa de asientos de una función y a la derecha los boletos impresos.

## 7 · Una transacción por compra: o todo o nada — Fernando (1 min)

> Cuando el cliente paga, todo pasa dentro de una sola transacción en SQL Server, en cinco pasos. **[Recorrer los números]** Primero bloquea la función para que dos compras de la misma función se atiendan una después de otra. Luego valida que los asientos existan y sigan libres, y que no pase de 10 boletos. Después cifra la tarjeta y al final registra la compra y los boletos. Si algo falla, se deshace todo.
>
> **[Señalar 5 de 5]** Lo probamos con tres personas pagando el mismo asiento al mismo tiempo, en cinco rondas: siempre se hizo una compra y las otras dos fueron rechazadas. **[Señalar el recuadro de abajo]** Para el límite y la doble venta hay tres barreras: PHP, el procedimiento y la base de datos con la restricción UNIQUE y el trigger.
>
> Alejandro les explica la seguridad.

## 8 · Cifrado de tarjetas por columna (AES-256) — Alejandro (1 min)

> Este es el requisito de mayor peso. Usamos cifrado por columna, que sí funciona en la edición Express. **[Recorrer la cadena de arriba abajo]** La llave maestra del servicio protege la llave maestra de la base; esa protege un certificado; el certificado protege una llave simétrica AES de 256 bits; y con esa llave, usando ENCRYPTBYKEY, se cifra la tarjeta en la tabla.
>
> **[Señalar el recuadro negro]** Esto es lo que se ve si alguien hace un SELECT a la tabla: solo datos cifrados que empiezan con 0x.
>
> **[Señalar la lista]** La llave solo se abre dentro de los procedimientos almacenados, y el usuario de la aplicación no tiene permiso sobre ella. Cada dato va amarrado a su usuario, así que copiarlo a otra fila no sirve para descifrarlo. Una restricción impide guardar un número sin cifrar, el CVV nunca se guarda y en pantalla solo se ven la marca y los últimos cuatro dígitos.

## 9 · Medidas de seguridad en cada capa — Alejandro (1 min)

> Además del cifrado, cubrimos cada capa:
> - **[SQL Injection]** Todo pasa por procedimientos con parámetros y cada entrada se valida en el servidor. Si alguien escribe `' OR 1=1 --` en el login, se toma como texto y no entra.
> - **[Login]** El procedimiento `sp_Login` compara el hash SHA-512 con sal dentro de SQL Server y bloquea la cuenta 5 minutos tras 5 intentos fallidos.
> - **[Trigger de log]** Cada usuario nuevo queda registrado en una tabla de log con su login, equipo y fecha, sin contraseñas.
> - **[Mínimo privilegio]** `sa` está desactivado y `cine_app` solo puede ejecutar procedimientos; tiene negado leer o modificar las tablas.
> - **[Sesiones y CSRF]** Al iniciar sesión se regenera el identificador, el rol del administrador se revisa en cada página y cada formulario lleva un token contra peticiones falsas.
> - **[Salida y errores]** Toda salida se escapa para evitar código inyectado, y los errores de SQL van a un log, nunca a la pantalla.
>
> Daniel sigue con el administrador.

## 10 · Administrador: ventas en vivo y control de horarios — Daniel (45 s)

> **[Señalar la captura]** Este es el panel del administrador. Muestra en tiempo real, cada cinco segundos, el total recaudado, los boletos vendidos y las funciones que ya tienen ventas. **[Recorrer la lista]** El administrador puede agregar, modificar y borrar funciones, y la base rechaza horarios que se encimen en la misma sala; puede cambiar el nombre de las películas; ve las ventas con la tarjeta enmascarada, y su rol se valida en cada página y dentro de cada procedimiento.

## 11 · Respaldo y recuperación sin perder el cifrado — Daniel (45 s)

> Para el respaldo no basta con el archivo .BAK. **[Recorrer los cuatro pasos]** Primero respaldamos la llave maestra, el certificado y la llave simétrica; luego la base completa en el .BAK, con verificación de integridad; comprobamos que el respaldo sea válido; y para restaurarlo en otra computadora, se abre la llave maestra con su contraseña y se liga a la nueva instancia.
>
> **[Señalar el recuadro de abajo]** Lo probamos restaurando en otra instancia de SQL Server y las tarjetas se descifraron correctamente.
>
> Kevin cierra la presentación.

## 12 · Pruebas automatizadas: 81 de 81 correctas — Kevin (45 s)

> Para comprobar todo esto hicimos 81 pruebas automáticas que usan el sitio como lo haría una persona, y todas pasaron. **[Señalar la gráfica]** Cubren la cartelera, la compra sin sesión, el registro y login, SQL Injection, las validaciones de tarjeta, el límite de 10, la doble venta y el módulo de administrador.

## 13 · Conclusiones — Kevin (1 min)

> Nos llevamos tres aprendizajes. **[Recorrer las tarjetas]**
> - **La base se defiende sola:** las llaves, restricciones y triggers mantienen las reglas aunque la aplicación falle.
> - **Cifrar no basta, hay que administrar las llaves:** sin el respaldo del certificado y la contraseña de la llave maestra, un .BAK no recupera las tarjetas.
> - **Menos privilegios, menos riesgo:** aunque alguien robara las credenciales de la aplicación, no podría leer las tablas ni abrir la llave.
>
> En un sistema real agregaríamos HTTPS, un hash de contraseñas más lento como Argon2 y una pasarela de pago certificada en lugar de guardar tarjetas.
>
> Muchas gracias. ¿Tienen alguna pregunta?

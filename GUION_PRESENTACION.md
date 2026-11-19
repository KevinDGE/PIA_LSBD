# Guion de exposición · Cine Aurora

**PIA Laboratorio de Seguridad en Bases de Datos · Equipo 3 · Jueves 19 de noviembre de 2026, 6:00 PM**

Duración total: **unos 20 minutos** (8 de diapositivas y 12 de demostración en vivo), más preguntas.

## Reparto

Es una propuesta: cámbienla como les acomode, pero que cada quien practique su parte.

| Integrante | Diapositivas | Demostración en vivo | Tiempo |
|---|---|---|---|
| **Kevin** Daniel Grimaldo Esquivel | 1 a 4: portada, equipo, objetivo, arquitectura | R2, R3, R4: VM, SQL Server, Apache | 4 min |
| **David** Emiliano Rangel Tovar | 5 a 7: modelo de datos, flujo, transacción | R8, R9, R10: cartelera, registro, compra, límite de 10 | 5 min |
| **Fernando** Garza Chavez | 10: administrador | R11, R12: panel en vivo, funciones, películas | 3 min |
| **Alejandro** Martinez Moya | 8 y 9: cifrado, medidas de seguridad | R13 a R17 en SSMS | 5 min |
| **Daniel** Diaz Viruega | 11 a 13: respaldo, pruebas, conclusiones | R18, R19: login y respaldo en vivo | 3 min |

Kevin maneja la computadora todo el tiempo (es su VM); los demás hablan y le indican qué abrir. Si prefieren, cada quien pasa a manejar en su parte.

## Antes de empezar (5:30 PM)

- [ ] VM encendida; Apache en verde en XAMPP; SQL Server (SQLEXPRESS) en ejecución.
- [ ] En SSMS ya se ejecutó `12_preparar_revision.sql`. URL del límite de 10 anotada: `http://localhost/cine/asientos.php?funcion=____`
- [ ] Abiertos: la presentación, **navegador A** (normal, sin sesión) en `http://localhost/cine/`, **navegador B** (InPrivate) en el login, SSMS con `11_consultas_revision.sql`, y el XAMPP Control Panel.
- [ ] `CREDENCIALES_PRUEBA.md` impreso o en un celular.

Las indicaciones entre corchetes **[así]** son acciones, no se leen en voz alta.

---

## Parte 1 · Presentación del proyecto

### Kevin · Diapositiva 1, portada (30 s)

> Buenas tardes. Somos el equipo 3 del Laboratorio de Seguridad en Bases de Datos y nos tocó el proceso de **compra de boletos de cine**. Les presentamos **Cine Aurora**: un portal web donde cualquier persona ve la cartelera, el cliente registrado elige función y asientos y paga con una tarjeta simulada, y un administrador ve las ventas en tiempo real. Todo con el foco de la materia: que la base de datos esté protegida.

### Kevin · Diapositiva 2, equipo (30 s)

> El equipo somos Kevin Grimaldo, David Rangel, Fernando Garza, Alejandro Martínez y Daniel Díaz. La base de datos se llama **CineAuroraDB** y todo corre en una máquina virtual con Windows Server 2022, SQL Server 2022 Express y Apache de XAMPP con PHP.

### Kevin · Diapositiva 3, objetivo (45 s)

> El objetivo fue vender boletos sin exponer datos. Cuatro números resumen las reglas principales:
> - **10**: máximo de boletos por cliente y por función, contando sus compras anteriores, y se valida en tres lugares.
> - **AES-256**: así se cifran el número, el titular y el vencimiento de la tarjeta.
> - **SHA2_512 con sal**: así se guardan las contraseñas, y el login se compara dentro de SQL Server.
> - **1**: un solo usuario de SQL Server para la aplicación, que solo puede ejecutar procedimientos almacenados.

### Kevin · Diapositiva 4, arquitectura (1 min)

> Todo vive dentro de la máquina virtual. El navegador habla por HTTP con Apache de XAMPP, que sirve las 17 páginas PHP. PHP se conecta con los drivers oficiales de Microsoft, `pdo_sqlsrv`, por TCP en el puerto 1433 y con la conexión cifrada.
>
> Lo importante: la aplicación **nunca** arma SQL con lo que escribe el usuario. Solo llama a 24 procedimientos almacenados del esquema `app`, y entra con el usuario `cine_app`. El usuario `sa` está desactivado; la administración se hace con autenticación de Windows.

**[Demostración R2, R3 y R4: 1 min]**

> Les mostramos el entorno.

- **[R2]** Señalar la ventana de VirtualBox. Dentro de la VM: `Win + R` > `winver` → *Windows Server 2022*.
- **[R3]** En SSMS ejecutar `SELECT @@VERSION;` → *SQL Server 2022 … Express Edition*.
- **[R4]** Mostrar el XAMPP Control Panel con Apache en verde y abrir `http://localhost/cine/`.

> Aquí están la máquina virtual con Windows Server 2022, SQL Server 2022 Express y Apache activo sirviendo el sitio. Le paso la palabra a David.

### David · Diapositiva 5, modelo de datos (1 min)

> La base tiene ocho tablas principales. La tabla productiva es **Boletos**, y su regla más importante es una restricción **UNIQUE sobre función y asiento**: aunque la aplicación fallara, SQL Server no permite vender dos veces el mismo asiento de la misma función.
>
> Además usamos llaves foráneas **compuestas**: el asiento de un boleto tiene que pertenecer a la sala de esa función, y el boleto tiene que ser de la misma función que su compra. Hay restricciones CHECK, por ejemplo de 1 a 10 boletos por compra, e índices en funciones, compras y boletos. Y tres bitácoras: el log de usuarios nuevos, los cambios del administrador y los errores internos.

### David · Diapositiva 6, flujo de compra (30 s)

> El flujo del cliente tiene seis pasos: cartelera, película, inicio de sesión, asientos, pago y boletos. Mejor se los mostramos en vivo.

**[Demostración R8, R9 y R10: 3 min 30 s]**

1. **[R8, navegador A]** La cartelera abierta sin sesión.
   > Desde el inicio, sin cuenta, se ven las películas en exhibición con sus próximos horarios.
2. **[R10, bloqueo]** Abrir una película y pulsar un horario → manda a iniciar sesión.
   > La película muestra todos sus horarios, pero sin sesión no se puede comprar. Y no es solo el botón: si escribo la dirección del mapa de asientos a mano, el servidor también me regresa al login.
   **[Escribir `localhost/cine/asientos.php?funcion=1` → login]**
3. **[R9]** *Crear cuenta* con Nombre `Revisor`, Apellidos `De Prueba`, correo `revisor@correo.test`, contraseña `Revisor#2026` dos veces → *cuenta creada*. Iniciar sesión.
   > El registro alimenta la tabla de usuarios. La contraseña se guarda como hash con sal; en un momento Alejandro lo muestra en la base.
4. **[R10, compra]** Elegir película > horario > **3 asientos**.
   > El mapa distingue disponibles, mi selección, ocupados y los que ya compré.
   *Continuar al pago* > primero un número inválido, `4111 1111 1111 1112`:
   > Valida la marca, el algoritmo de Luhn, el vencimiento y el CVV.
   Luego `4111 1111 1111 1111`, titular `REVISOR DE PRUEBA`, vencimiento futuro, CVV `123` > *Pagar*.
   > La compra queda registrada y se generan los boletos con código de barras. **[Pulsar Imprimir boletos]** Se pueden imprimir. Si regreso al mapa, esos asientos ya aparecen ocupados.
5. **[Límite de 10]** Cerrar sesión. Entrar con `luis.hernandez@correo.test` / `Cliente#Luis2026` y abrir la URL anotada.
   > Luis ya tiene 8 boletos en esta función, así que solo puede comprar 2 más; el mapa no le deja elegir un tercero. Esto se valida en PHP, en el procedimiento almacenado y con un trigger en la tabla de boletos.

### David · Diapositiva 7, transacción (1 min)

> ¿Qué pasa por dentro al pagar? Todo ocurre en **una sola transacción**: primero se bloquea la fila de la función, luego se validan los asientos y el límite de 10, después se cifra la tarjeta y al final se registran la compra y los boletos. Si cualquier paso falla, se deshace todo.
>
> Probamos qué pasa si tres personas pagan el mismo asiento al mismo tiempo: en cinco rondas, siempre se hizo una compra y las otras dos recibieron el aviso de que el asiento ya se vendió. Le paso la palabra a Fernando.

### Fernando · Diapositiva 10, administrador (45 s)

**[Saltar a la diapositiva 10]**

> El administrador tiene un panel en vivo con las funciones vendidas y el total recaudado, que se actualiza solo cada cinco segundos. Puede agregar, modificar y borrar funciones con sus horarios, y cambiar el nombre de las películas. Su rol se valida en cada página y otra vez dentro de cada procedimiento almacenado.

**[Demostración R11 y R12: 2 min 15 s]**

1. **[Navegador B]** Entrar con `admin@cineaurora.test` / `Admin#Aurora2026` → *Panel en vivo*.
2. En el navegador A (sigue abierta la sesión de Luis) comprar **1 boleto** en su función: Visa `4111 1111 1111 1111`, CVV `123`.
   > Miren el total recaudado: sin recargar, en menos de cinco segundos se actualiza.
3. *Funciones y horarios* > **Agregar función**: Sala 1, mañana a las **23:45**, precio 80 → guardada.
   > Si intento otra en la misma sala a una hora que se encima, la base la rechaza. **[Opcional: probar 19:00]**
4. **Editar** esa función: cambiar a 23:50 → guardada. **Borrar** → eliminada.
   > Si una función ya tiene ventas, no se borra el historial: se retira de la cartelera.
5. *Películas* > **Editar** una > cambiar el **nombre** > guardar. En el navegador A recargar la cartelera.
   > El nombre cambia en la cartelera.
6. **[R12]** Señalar la pestaña del navegador.
   > Cada página tiene su propio título y el ícono del cine.

> Le paso la palabra a Alejandro para la parte de seguridad.

## Parte 2 · Seguridad

### Alejandro · Diapositiva 8, cifrado de tarjetas (1 min)

**[Regresar a la diapositiva 8]**

> Este es el requisito de mayor peso. Usamos cifrado por columna, que sí está disponible en la edición Express. La jerarquía es: la llave maestra de la base protege un certificado, el certificado protege una **llave simétrica AES de 256 bits**, y con esa llave y la función **ENCRYPTBYKEY** se cifran número, titular y vencimiento, que se guardan como **VARBINARY**.
>
> La llave solo se abre **dentro** de los procedimientos almacenados. El usuario de la aplicación no tiene ningún permiso sobre la llave. Además, una restricción impide guardar un número sin cifrar, y el **CVV nunca se guarda**: PHP lo valida y lo descarta.

### Alejandro · Diapositiva 9, medidas de seguridad (45 s)

> En resumen, la seguridad está en cada capa: consultas parametrizadas contra SQL Injection, login con hash y sal dentro de SQL Server, trigger de log, mínimo privilegio con `sa` desactivado, sesiones protegidas con token CSRF, y los errores de SQL nunca se muestran al usuario. Se los demostramos.

**[Demostración R13 a R17 en SSMS: 3 min 15 s]** Abrir `11_consultas_revision.sql`, seleccionar cada bloque y pulsar F5.

1. **[R13]** Bloque R13.
   > Aquí están las llaves primarias, foráneas, UNIQUE, CHECK e índices. Al final intentamos insertar un boleto repetido y SQL Server responde con el **error 2627** por la restricción UNIQUE de función y asiento.
2. **[R14]** En el **navegador A**, *Cerrar sesión* y luego *Iniciar sesión* con correo `' OR '1'='1' --` y contraseña `' OR '1'='1`.
   > La clásica inyección no entra: el texto viaja como parámetro y se compara como un correo literal.
   Luego el bloque R14 en SSMS.
   > Y si el usuario de la aplicación intenta leer una tabla directamente, SQL Server le niega el permiso.
3. **[R15]** Bloque R15.
   > El trigger `trg_Usuarios_LogAlta` registra cada usuario nuevo en la tabla de log. Aquí aparece el que acabamos de crear desde la web, con el login `cine_app` y la fecha. No hay ninguna columna de contraseña.
4. **[R16]** Bloque R16.
   > `sa` está desactivado y el único login de SQL Server activo es `cine_app`.
   **[Conectar > Autenticación de SQL Server > usuario `sa` → *Login failed … The account is disabled*]**
5. **[R17]** Bloque R17, consulta por consulta.
   > Un `SELECT` a la tabla de tarjetas solo muestra datos cifrados, `0x…`. Sin abrir la llave, descifrar da NULL. Si el usuario de la aplicación intenta abrir la llave, SQL Server responde que no existe o que no tiene permiso. Solo el procedimiento la abre, y aun así solo regresa la marca y los últimos cuatro dígitos. Y si alguien intenta guardar un número sin cifrar, la restricción lo bloquea.

> Le paso la palabra a Daniel.

### Daniel · R18, login (45 s)

**[Bloque R18 en SSMS]**

> Para el login usamos el procedimiento `app.sp_Login`. En la tabla solo hay un hash de 64 bytes y una sal de 32 bytes por usuario, nunca la contraseña. El procedimiento calcula `HASHBYTES('SHA2_512', sal + contraseña)` y lo compara dentro de SQL Server: con la contraseña correcta da resultado 0 y con otra da 1. Tras cinco intentos fallidos, la cuenta se bloquea cinco minutos.

### Daniel · Diapositiva 11, respaldo (1 min)

**[Diapositiva 11]**

> Para el respaldo no basta con el `.BAK`: como las tarjetas están cifradas, también respaldamos la llave maestra, el certificado y la llave simétrica. Sin ellos, el respaldo no se puede descifrar en otra computadora. Probamos restaurarlo en una segunda instancia y las tarjetas se descifraron bien.

**[Demostración R19: 1 min]** En SSMS: clic derecho en **CineAuroraDB** > *Tareas* > *Copia de seguridad…* > Completa > Disco > `C:\Respaldos\CineAurora\Respaldo_Proyecto_3.BAK` > Aceptar.

> Así se hace un respaldo completo en vivo. **[Mostrar el mensaje de éxito y el archivo en la carpeta]** El script `09_respaldo.sql` hace lo mismo y además respalda las llaves.

### Daniel · Diapositivas 12 y 13, pruebas y conclusiones (1 min)

> Probamos el sistema con 81 pruebas automáticas y todas pasaron: compras, tarjetas, accesos sin sesión, límite de 10, doble venta, SQL Injection y el módulo de administrador.
>
> Nos llevamos tres aprendizajes. Uno: la base de datos debe defenderse sola, con llaves, restricciones y triggers, aunque la aplicación falle. Dos: cifrar no basta; hay que administrar y respaldar las llaves. Tres: con menos privilegios hay menos riesgo, porque aunque alguien robara las credenciales de la aplicación, no podría leer las tablas ni abrir la llave.
>
> En un sistema real agregaríamos HTTPS, un hash de contraseñas más lento como Argon2 y una pasarela de pago certificada en lugar de guardar tarjetas. Muchas gracias. ¿Tienen alguna pregunta?

---

## Preguntas probables y respuestas cortas

| Pregunta | Respuesta |
|---|---|
| ¿Por qué VARBINARY? | Porque `ENCRYPTBYKEY` devuelve binario; ahí se guarda el dato cifrado tal cual sale. |
| ¿Dónde está el CVV? | En ningún lado. PHP valida que tenga 3 o 4 dígitos y lo descarta; ni siquiera llega a SQL Server. |
| ¿Cómo abren la llave si `cine_app` no tiene permisos? | Los procedimientos que cifran usan `WITH EXECUTE AS OWNER`: se ejecutan con los permisos del dueño de la base, no con los de `cine_app`. |
| ¿Qué es la sal y para qué sirve? | 32 bytes aleatorios distintos por usuario. Dos personas con la misma contraseña tienen hashes diferentes y no sirven las tablas precalculadas. |
| ¿Y si dos personas compran el mismo asiento a la vez? | La transacción bloquea la función; la segunda compra ve el asiento vendido y se rechaza. Si algo se saltara eso, la restricción UNIQUE lo impide. |
| ¿Cómo evitan SQL Injection? | Todo es procedimiento almacenado con parámetros enlazados (`bindValue`); además se valida cada entrada en PHP y `cine_app` no puede tocar las tablas. |
| ¿Por qué el dueño de la base es `sa` si está desactivado? | `sa` existe en toda instancia con el mismo identificador. Si el dueño fuera un usuario de Windows, al restaurar en otra computadora los procedimientos que cifran fallarían. |
| ¿Si desactivan `sa`, cómo administran? | Con autenticación de Windows: el usuario Administrador de la VM es sysadmin. |
| ¿Qué pasa si pierden la contraseña de la llave maestra? | Se restaura desde el archivo de respaldo de la llave (`RESTORE MASTER KEY`), que también está protegido con contraseña. |
| ¿Por qué no se borra una función con ventas? | Para no perder el historial ni el dinero registrado; se retira de la cartelera. |
| ¿Cómo es "en tiempo real" el panel? | La página consulta cada cinco segundos un endpoint JSON protegido que llama a procedimientos del administrador. |

## Si algo falla

| Problema | Qué decir y hacer |
|---|---|
| La cartelera sale vacía | "Las funciones de ejemplo ya pasaron." Ejecutar `12_preparar_revision.sql` y recargar. |
| "Ocurrió un problema" en una página | Revisar que SQL Server esté corriendo (*Servicios*). El detalle está en `C:\xampp\htdocs\cine\logs\php_errores.log`. |
| Cuenta bloqueada por intentos | Ejecutar `12_preparar_revision.sql` (desbloquea). |
| Se traba la VM | Restaurar el snapshot `Listo para revisión`. |

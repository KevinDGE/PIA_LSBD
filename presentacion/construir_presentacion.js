/* Genera Presentación_Proyecto_3.pptx
   Uso (desde la raíz del repositorio):
     cd presentacion && npm install && node construir_presentacion.js
   Nombres y matrículas: presentacion/equipo.json */
const path = require("path");
const fs = require("fs");
const pptxgen = require("pptxgenjs");

const AQUI = __dirname;
const R = (f) => path.join(AQUI, "recursos", f);
const CAP = (f) => path.join(AQUI, "capturas", f);
const DATOS = JSON.parse(fs.readFileSync(path.join(AQUI, "equipo.json"), "utf8"));
const SALIDA = path.join(AQUI, "Presentación_Proyecto_3.pptx");

const THEME = {
  name: "Cine Aurora",
  headFontFace: "Calibri",
  bodyFontFace: "Calibri",
  colors: {
    dk1: "0D0C16", lt1: "F2F0F8", dk2: "1B1928", lt2: "B6B1C9",
    accent1: "FFB547", accent2: "FF6F61", accent3: "8B5CF6", accent4: "34D399",
    accent5: "60A5FA", accent6: "2F2B45", hlink: "FFB547", folHlink: "FF6F61",
  },
};

const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE"; // 13.333 x 7.5 in
pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
pres.title = "Cine Aurora · Proyecto Integrador LSBD";
pres.author = "Equipo 3";
pres.subject = "Portal de venta de boletos con seguridad en SQL Server";
const C = pres.SchemeColor;
const W = 13.333;

/* ------------------------------ Layouts ------------------------------ */
pres.defineSlideMaster({
  title: "PORTADA",
  background: { path: R("fondo_portada.jpg") },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.8, y: 2.35, w: 8.6, h: 1.7, fontSize: 54, bold: true, color: C.background1, valign: "bottom", align: "left", margin: 0 }, text: "" } },
    { placeholder: { options: { name: "body", type: "body", x: 0.8, y: 4.15, w: 8.2, h: 1.1, fontSize: 22, color: C.background2, valign: "top", align: "left", margin: 0 }, text: "" } },
  ],
});
pres.defineSlideMaster({
  title: "CIERRE",
  background: { path: R("fondo_suave.jpg") },
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.8, y: 0.55, w: 11.7, h: 0.9, fontSize: 40, bold: true, color: C.background1, valign: "middle", align: "left", margin: 0 }, text: "" } },
  ],
});
pres.defineSlideMaster({
  title: "CONTENIDO",
  background: { color: "0D0C16" },
  margin: [0.5, 0.6, 0.6, 0.6],
  objects: [
    { placeholder: { options: { name: "title", type: "title", x: 0.6, y: 0.4, w: 12.1, h: 0.85, fontSize: 34, bold: true, color: C.background1, valign: "middle", align: "left", margin: 0 }, text: "" } },
    { text: { text: "Cine Aurora · Equipo 3 · LSBD · FCFM UANL", options: { x: 0.6, y: 7.0, w: 7, h: 0.3, fontSize: 10, color: C.background2, margin: 0 } } },
  ],
  slideNumber: { x: 12.2, y: 7.0, w: 0.5, h: 0.3, fontSize: 10, color: C.background2, align: "right", margin: 0 },
});

/* ------------------------------ Ayudas ------------------------------ */
let nObj = 0;
const id = (p) => `${p}_${++nObj}`;
function tarjeta(s, x, y, w, h, extra = {}) {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, rectRadius: 0.12, fill: { color: extra.fill || C.text2 }, line: { color: extra.line || C.accent6, width: 1 }, objectName: id("tarjeta") });
}
function texto(s, t, o) {
  s.addText(t, { isTextBox: true, margin: 0, color: C.background1, fontSize: 16, valign: "top", objectName: id("texto"), ...o });
}
function circuloNum(s, n, x, y, d, color) {
  s.addShape(pres.shapes.OVAL, { x, y, w: d, h: d, fill: { color }, line: { color, width: 0 }, objectName: id("circulo") });
  texto(s, String(n), { x, y, w: d, h: d, align: "center", valign: "middle", fontSize: d > 0.6 ? 20 : 15, bold: true, color: C.text1 });
}
function flecha(s, x, y, w, h, color = C.background2) {
  s.addShape(pres.shapes.LINE, { x, y, w, h, line: { color, width: 2, endArrowType: "triangle" }, objectName: id("flecha") });
}
function linea(s, x, y, w, h, color = C.accent6, flipH = false) {
  s.addShape(pres.shapes.LINE, { x, y, w, h, flipH, line: { color, width: 1.75 }, objectName: id("relacion") });
}
function captura(s, archivo, x, y, w) {
  const h = w * 768 / 1366;
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: x - 0.04, y: y - 0.04, w: w + 0.08, h: h + 0.08, rectRadius: 0.08, fill: { color: C.accent6 }, line: { color: C.accent6, width: 0 }, objectName: id("marco") });
  s.addImage({ path: CAP(archivo), x, y, w, h, altText: "Captura del sistema: " + archivo, objectName: id("captura") });
  return h;
}
function nueva(seccion, titulo) {
  const s = pres.addSlide({ masterName: "CONTENIDO", sectionTitle: seccion });
  s.addText(titulo, { placeholder: "title" });
  return s;
}

/* ============================ 1. Portada ============================ */
pres.addSection({ title: "Inicio" });
{
  const s = pres.addSlide({ masterName: "PORTADA", sectionTitle: "Inicio" });
  s.addImage({ path: R("uanl.png"), x: 0.8, y: 0.6, w: 1.05, h: 1.05, altText: "Logo UANL", objectName: "logo_uanl" });
  s.addImage({ path: R("facultad.png"), x: 2.05, y: 0.6, w: 1.05, h: 1.05, altText: "Logo FCFM", objectName: "logo_fcfm" });
  texto(s, "Universidad Autónoma de Nuevo León\nFacultad de Ciencias Físico Matemáticas", { x: 3.35, y: 0.7, w: 6, h: 0.9, fontSize: 15, color: C.background2, valign: "middle" });
  texto(s, "PROYECTO INTEGRADOR · " + DATOS.grupo.toUpperCase(), { x: 0.8, y: 1.95, w: 9, h: 0.35, fontSize: 13, bold: true, color: C.accent1, charSpacing: 3 });
  s.addText("Cine Aurora", { placeholder: "title" });
  s.addText("Portal de venta de boletos con cartelera, pago simulado y seguridad en SQL Server 2022", { placeholder: "body" });
  texto(s, `${DATOS.equipo} · Revisión: ${DATOS.fecha_revision}`, { x: 0.8, y: 6.55, w: 8, h: 0.4, fontSize: 15, color: C.background1 });
  s.addImage({ path: path.join(AQUI, "..", "htdocs", "cine", "assets", "img", "apple-touch-icon.png"), x: 10.7, y: 2.6, w: 1.9, h: 1.9, altText: "Logo de Cine Aurora", objectName: "logo_cine" });
  s.addNotes("Presentación del equipo 3. Proyecto: compra de boletos de cine en una interfaz estilo cartelera, con el enfoque del laboratorio: seguridad de la base de datos en SQL Server 2022 Express.");
}

/* ============================ 2. Equipo ============================ */
{
  const s = nueva("Inicio", "Equipo 3");
  const n = DATOS.integrantes.length;
  const gap = 0.35, w = (12.1 - gap * (n - 1)) / n;
  DATOS.integrantes.forEach((p, i) => {
    const x = 0.6 + i * (w + gap);
    tarjeta(s, x, 1.85, w, 3.2);
    s.addShape(pres.shapes.OVAL, { x: x + w / 2 - 0.6, y: 2.2, w: 1.2, h: 1.2, fill: { color: [C.accent3, C.accent2, C.accent1, C.accent4, C.accent5][i % 5] }, line: { width: 0, color: C.accent6 }, objectName: id("avatar") });
    const ini = p.nombre.split(/\s+/).filter(Boolean).slice(0, 2).map((x) => x[0]).join("").toUpperCase();
    texto(s, ini, { x: x + w / 2 - 0.6, y: 2.2, w: 1.2, h: 1.2, align: "center", valign: "middle", fontSize: 28, bold: true, color: C.text1 });
    texto(s, p.nombre, { x: x + 0.2, y: 3.6, w: w - 0.4, h: 0.8, align: "center", valign: "middle", fontSize: 17, bold: true });
    texto(s, "Matrícula " + p.matricula, { x: x + 0.2, y: 4.4, w: w - 0.4, h: 0.4, align: "center", fontSize: 14, color: C.background2 });
  });
  tarjeta(s, 0.6, 5.45, 12.1, 1.15, { fill: "15131F" });
  texto(s, [
    { text: "Base de datos: ", options: { bold: true, color: C.accent1 } }, { text: "CineAuroraDB   ·   " },
    { text: "Entorno: ", options: { bold: true, color: C.accent1 } }, { text: "Windows Server 2022 (VM) · SQL Server 2022 Express · Apache (XAMPP) · PHP" },
  ], { x: 0.9, y: 5.6, w: 11.5, h: 0.85, valign: "middle", fontSize: 16 });
  s.addNotes("Presentar a cada integrante y su matrícula. Los datos se editan en presentacion/equipo.json.");
}

/* ============================ 3. Objetivo ============================ */
pres.addSection({ title: "Proyecto" });
{
  const s = nueva("Proyecto", "Objetivo: vender boletos sin exponer datos");
  texto(s, "Construir el portal de un cine ficticio donde cualquier visitante ve la cartelera, el cliente registrado elige función y asientos y paga con tarjeta simulada, y el administrador ve las ventas en vivo, protegiendo la base de datos en cada capa.", { x: 0.6, y: 1.45, w: 12.1, h: 1.0, fontSize: 18, color: C.background2 });
  const stats = [
    ["10", "boletos máximo por cliente y función, validado en PHP, procedimiento y trigger", C.accent1],
    ["AES-256", "cifrado por columna de número, titular y vencimiento de tarjeta", C.accent2],
    ["SHA2_512", "con sal de 32 bytes por usuario; el login se compara dentro de SQL Server", C.accent3],
    ["1", "único login tipo SQL Server (cine_app) con permiso solo de EXECUTE", C.accent4],
  ];
  stats.forEach(([n, t, col], i) => {
    const x = 0.6 + i * 3.1;
    tarjeta(s, x, 2.85, 2.8, 3.6);
    texto(s, n, { x: x + 0.25, y: 3.15, w: 2.4, h: 1.0, fontSize: n.length > 4 ? 34 : 54, bold: true, color: col, valign: "middle" });
    texto(s, t, { x: x + 0.25, y: 4.35, w: 2.35, h: 1.9, fontSize: 15, color: C.background1 });
  });
  s.addNotes("Proceso de negocio asignado: compra de boletos de cine. Los cuatro números resumen las reglas más importantes que se demostrarán: límite de boletos, cifrado de tarjetas, hash de contraseñas y usuario de mínimo privilegio.");
}

/* ============================ 4. Arquitectura ============================ */
{
  const s = nueva("Proyecto", "Arquitectura local en una máquina virtual");
  // Cliente
  tarjeta(s, 0.6, 2.6, 2.3, 2.3, { fill: "15131F" });
  texto(s, "Navegador", { x: 0.8, y: 2.85, w: 1.9, h: 0.45, bold: true, fontSize: 18 });
  texto(s, "Cliente y administrador\nHTML + CSS + JS propios\nResponsivo (celular)", { x: 0.8, y: 3.35, w: 1.95, h: 1.4, fontSize: 13, color: C.background2 });
  // VM
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 3.45, y: 1.5, w: 9.25, h: 5.2, rectRadius: 0.15, fill: { color: "13111D" }, line: { color: C.accent3, width: 1.5, dashType: "dash" }, objectName: "vm" });
  texto(s, "Máquina virtual · Windows Server 2022 (VirtualBox / VMware)", { x: 3.75, y: 1.65, w: 8.6, h: 0.4, fontSize: 15, bold: true, color: C.accent3 });
  const cajas = [
    [3.8, "Apache 2.4 (XAMPP)", "htdocs\\cine\n17 páginas PHP\n.htaccess: bloquea includes/ y logs/", C.accent1],
    [6.75, "PHP 8.2 + PDO_SQLSRV", "Drivers Microsoft 5.12\nODBC Driver 18 (TLS)\nconfig.php: único archivo de credenciales", C.accent2],
    [9.7, "SQL Server 2022 Express", "CineAuroraDB\nEsquema app: 24 procedimientos\nLlave AES_256 · triggers · respaldo .BAK", C.accent4],
  ];
  cajas.forEach(([x, t, d, col]) => {
    tarjeta(s, x, 2.3, 2.65, 2.9);
    s.addShape(pres.shapes.OVAL, { x: x + 0.25, y: 2.55, w: 0.32, h: 0.32, fill: { color: col }, line: { color: col, width: 0 }, objectName: id("punto") });
    texto(s, t, { x: x + 0.7, y: 2.45, w: 1.85, h: 0.6, fontSize: 15, bold: true, valign: "middle" });
    texto(s, d, { x: x + 0.25, y: 3.2, w: 2.25, h: 1.9, fontSize: 13, color: C.background2 });
  });
  flecha(s, 2.95, 3.75, 0.8, 0);
  flecha(s, 6.5, 3.75, 0.2, 0);
  flecha(s, 9.45, 3.75, 0.2, 0);
  texto(s, "HTTP", { x: 2.95, y: 3.4, w: 0.45, h: 0.3, fontSize: 11, color: C.background2, align: "center" });
  tarjeta(s, 3.8, 5.5, 8.55, 0.95, { fill: "1F1C2E" });
  texto(s, [
    { text: "Conexión: ", options: { bold: true, color: C.accent1 } },
    { text: "127.0.0.1,1433 · autenticación SQL con cine_app · solo EXEC app.sp_* con parámetros enlazados · sa desactivado; administración por Autenticación de Windows" },
  ], { x: 4.05, y: 5.6, w: 8.1, h: 0.75, fontSize: 13, valign: "middle" });
  s.addNotes("Todo corre dentro de la VM: Apache de XAMPP sirve las páginas PHP desde htdocs\\cine, PHP usa los drivers oficiales de Microsoft (pdo_sqlsrv) y se conecta por TCP 1433 a SQL Server 2022 Express. La aplicación no tiene SQL armado con texto del usuario: solo llama procedimientos del esquema app.");
}

/* ============================ 5. Modelo de datos ============================ */
{
  const s = nueva("Proyecto", "Modelo de datos con integridad en la base");
  const cx = [0.6, 3.75, 6.9, 10.05], bw = 2.7, bh = 2.25, y1 = 1.45, y2 = 4.15;
  const ent = [
    [0, y1, "Usuarios", ["PK UsuarioID", "UQ Correo", "PasswordHash · Sal", "CHECK Rol"], C.accent3],
    [1, y1, "Compras", ["PK CompraID · Folio", "FK Usuario, Función, Tarjeta", "CHECK Cantidad 1..10"], C.accent1],
    [2, y1, "Funciones", ["PK FuncionID", "FK Película, Sala", "UQ (Sala, FechaHora)"], C.accent1],
    [3, y1, "Peliculas", ["PK PeliculaID", "UQ Titulo", "CHECK Clasif., Duración"], C.accent5],
    [0, y2, "Tarjetas", ["PK TarjetaID · FK Usuario", "NumeroCifrado VARBINARY", "Sin columna CVV"], C.accent2],
    [1, y2, "Boletos", ["FK (Compra, Función)", "FK (Asiento, Sala)", "UQ (FuncionID, AsientoID)"], C.accent4],
    [2, y2, "Asientos", ["PK AsientoID · FK Sala", "UQ (Sala, Fila, Número)"], C.accent5],
    [3, y2, "Salas", ["PK SalaID", "UQ Nombre", "CHECK Filas, Asientos"], C.accent5],
  ];
  // relaciones (antes que las cajas, para que queden detrás)
  const mid = (c) => cx[c] + bw / 2;
  linea(s, cx[0] + bw, y1 + 1.1, 0.45, 0);            // Usuarios-Compras
  linea(s, cx[1] + bw, y1 + 1.1, 0.45, 0);            // Compras-Funciones
  linea(s, cx[2] + bw, y1 + 1.1, 0.45, 0);            // Funciones-Películas
  linea(s, mid(0), y1 + bh, 0, y2 - y1 - bh);         // Usuarios-Tarjetas
  linea(s, mid(1), y1 + bh, 0, y2 - y1 - bh);         // Compras-Boletos
  linea(s, cx[1] + bw, y2 + 1.1, 0.45, 0);            // Boletos-Asientos
  linea(s, cx[2] + bw, y2 + 1.1, 0.45, 0);            // Asientos-Salas
  linea(s, mid(2), y1 + bh, mid(3) - mid(2), y2 - y1 - bh); // Funciones-Salas
  linea(s, cx[0] + bw - 0.3, y2, mid(1) - 0.6 - (cx[0] + bw - 0.3), -(y2 - y1 - bh), C.accent6); // Tarjetas-Compras
  ent.forEach(([c, y, nombre, campos, col]) => {
    const x = cx[c];
    tarjeta(s, x, y, bw, bh, { line: nombre === "Boletos" ? C.accent4 : C.accent6 });
    s.addShape(pres.shapes.OVAL, { x: x + 0.2, y: y + 0.22, w: 0.26, h: 0.26, fill: { color: col }, line: { color: col, width: 0 }, objectName: id("punto") });
    texto(s, nombre, { x: x + 0.6, y: y + 0.12, w: bw - 0.8, h: 0.45, fontSize: 17, bold: true, valign: "middle" });
    texto(s, campos.map((t, i) => ({ text: t, options: { bullet: true, breakLine: i < campos.length - 1 } })), { x: x + 0.2, y: y + 0.7, w: bw - 0.35, h: bh - 0.85, fontSize: 12, color: C.background2, paraSpaceAfter: 3 });
  });
  texto(s, [
    { text: "Bitácoras: ", options: { bold: true, color: C.accent1 } },
    { text: "LogUsuarios (trigger de altas, sin contraseñas) · AuditoriaAdmin (cambios del administrador) · LogErrores (errores internos ocultos al usuario)" },
  ], { x: 0.6, y: 6.5, w: 12.1, h: 0.4, fontSize: 13 });
  s.addNotes("La tabla productiva es Boletos: su restricción UNIQUE(FuncionID, AsientoID) impide vender dos veces el mismo asiento, y sus llaves foráneas compuestas garantizan que el asiento pertenece a la sala de la función y que el boleto es de la misma función que su compra. Hay índices en Funciones (película y fecha), Compras (usuario y función) y Boletos.");
}

/* ============================ 6. Flujo de compra ============================ */
pres.addSection({ title: "Funcionamiento" });
{
  const s = nueva("Funcionamiento", "Flujo de compra del cliente");
  const pasos = [
    ["Cartelera", "Visible sin sesión"],
    ["Película", "Todos sus horarios"],
    ["Sesión", "Sin login no hay compra"],
    ["Asientos", "Libres contra ocupados"],
    ["Pago", "Visa · MC · Amex + Luhn"],
    ["Boletos", "Código de barras, imprimir"],
  ];
  const paso = 2.02;
  pasos.forEach(([t, d], i) => {
    const x = 0.6 + i * paso;
    if (i > 0) linea(s, x - paso + 0.75, 1.82, paso - 0.6, 0, C.accent6);
    circuloNum(s, i + 1, x, 1.5, 0.64, [C.accent3, C.accent3, C.accent2, C.accent2, C.accent1, C.accent1][i]);
    texto(s, t, { x: x + 0.75, y: 1.45, w: 1.25, h: 0.38, fontSize: 16, bold: true });
    texto(s, d, { x: x + 0.75, y: 1.83, w: 1.25, h: 0.6, fontSize: 11, color: C.background2 });
  });
  const h = captura(s, "04_asientos.png", 0.6, 2.85, 5.9);
  captura(s, "06_boletos.png", 6.8, 2.85, 5.9);
  texto(s, "Mapa de asientos de la función", { x: 0.6, y: 2.95 + h, w: 5.9, h: 0.3, fontSize: 12, color: C.background2 });
  texto(s, "Boletos imprimibles con código Code 39", { x: 6.8, y: 2.95 + h, w: 5.9, h: 0.3, fontSize: 12, color: C.background2 });
  s.addNotes("Demostración: entrar sin sesión, abrir una película, intentar elegir horario y ver que pide iniciar sesión. Después elegir asientos (máximo 10), pagar con tarjeta de prueba e imprimir los boletos.");
}

/* ============================ 7. Transacción ============================ */
{
  const s = nueva("Funcionamiento", "Una transacción por compra: o todo o nada");
  const pasos = [
    ["Bloquea la función", "SELECT … WITH (UPDLOCK, HOLDLOCK): compras de la misma función en fila"],
    ["Valida asientos", "Existen, son de la sala y siguen libres"],
    ["Valida el límite", "Boletos previos + nuevos ≤ 10 por cliente y función"],
    ["Cifra la tarjeta", "OPEN SYMMETRIC KEY → ENCRYPTBYKEY → CLOSE"],
    ["Registra", "Compra, boletos con código aleatorio y COMMIT"],
  ];
  pasos.forEach(([t, d], i) => {
    const y = 1.5 + i * 1.0;
    circuloNum(s, i + 1, 0.6, y + 0.05, 0.55, C.accent1);
    texto(s, t, { x: 1.35, y, w: 5.6, h: 0.38, fontSize: 17, bold: true });
    texto(s, d, { x: 1.35, y: y + 0.38, w: 5.6, h: 0.5, fontSize: 13, color: C.background2 });
  });
  tarjeta(s, 7.4, 1.5, 5.3, 2.35);
  texto(s, "5 de 5", { x: 7.7, y: 1.65, w: 4.8, h: 0.85, fontSize: 48, bold: true, color: C.accent4 });
  texto(s, "rondas de prueba: 3 clientes pagan el mismo asiento al mismo tiempo; en cada ronda 1 compra y 2 rechazos", { x: 7.7, y: 2.55, w: 4.8, h: 1.2, fontSize: 15 });
  tarjeta(s, 7.4, 4.1, 5.3, 2.4);
  texto(s, "Tres barreras para el límite y la doble venta", { x: 7.7, y: 4.25, w: 4.8, h: 0.4, fontSize: 16, bold: true, color: C.accent1 });
  const b = ["PHP: valida antes de llamar a la base", "Procedimiento: revalida bajo bloqueo", "Base: UNIQUE(FuncionID, AsientoID) y trigger trg_Boletos_Max10"];
  texto(s, b.map((t, i) => ({ text: t, options: { bullet: true, breakLine: i < b.length - 1 } })), { x: 7.7, y: 4.75, w: 4.8, h: 1.6, fontSize: 15, paraSpaceAfter: 6 });
  s.addNotes("app.sp_ComprarBoletos usa SET XACT_ABORT ON y TRY/CATCH: si cualquier paso falla se revierte todo. Si dos personas eligen el mismo asiento, la segunda recibe 'Uno o más asientos acaban de ser vendidos'. Se probó con 3 sesiones simultáneas en 5 rondas.");
}

/* ============================ 8. Cifrado ============================ */
pres.addSection({ title: "Seguridad" });
{
  const s = nueva("Seguridad", "Cifrado de tarjetas por columna (AES-256)");
  const cadena = [
    ["Service Master Key", "de la instancia"],
    ["Database Master Key", "contraseña + SMK"],
    ["Certificado Cert_Tarjetas", "protegido por la DMK"],
    ["Llave simétrica SK_Tarjetas", "AES_256, protegida por el certificado"],
    ["dbo.Tarjetas", "VARBINARY con ENCRYPTBYKEY"],
  ];
  cadena.forEach(([t, d], i) => {
    const y = 1.45 + i * 1.05;
    tarjeta(s, 0.6, y, 4.6, 0.82, { line: i === 3 ? C.accent2 : C.accent6 });
    texto(s, t, { x: 0.85, y: y + 0.08, w: 4.2, h: 0.36, fontSize: 15, bold: true });
    texto(s, d, { x: 0.85, y: y + 0.43, w: 4.2, h: 0.32, fontSize: 12, color: C.background2 });
    if (i < cadena.length - 1) flecha(s, 2.9, y + 0.83, 0, 0.21, C.accent2);
  });
  tarjeta(s, 5.6, 1.45, 7.1, 2.0, { fill: "0A0912" });
  texto(s, "SELECT TarjetaID, Marca, NumeroCifrado FROM dbo.Tarjetas;", { x: 5.85, y: 1.6, w: 6.7, h: 0.35, fontSize: 13, fontFace: "Courier New", color: C.accent1 });
  texto(s, "1  VISA        0x0055D29EB9A7EF48A72395…41D0F741D417D68\n2  MASTERCARD  0x0055D29EB9A7EF48A72395…73851A9CFD9CFAF0\n3  AMEX        0x0055D29EB9A7EF48A72395…29A5A997C7F4DFAC", { x: 5.85, y: 2.05, w: 6.7, h: 1.2, fontSize: 13, fontFace: "Courier New", color: C.background1 });
  const p = [
    "La llave solo se abre dentro de procedimientos (WITH EXECUTE AS OWNER)",
    "cine_app no tiene permisos sobre la llave ni sobre el certificado",
    "Autenticador UsuarioID: copiar el dato a otra fila no lo descifra",
    "CHECK exige el GUID de la llave: no se puede guardar en claro",
    "El CVV se valida en PHP y se descarta: no existe columna",
    "En pantalla solo marca y últimos 4 dígitos",
  ];
  texto(s, p.map((t, i) => ({ text: t, options: { bullet: true, breakLine: i < p.length - 1 } })), { x: 5.6, y: 3.75, w: 7.1, h: 2.9, fontSize: 15, paraSpaceAfter: 6 });
  s.addNotes("Requisito de mayor peso (R17). Mostrar en SSMS: SELECT * FROM dbo.Tarjetas devuelve solo 0x…; DECRYPTBYKEY sin abrir la llave devuelve NULL; como cine_app OPEN SYMMETRIC KEY falla. Script 11, sección R17.");
}

/* ============================ 9. Otras medidas ============================ */
{
  const s = nueva("Seguridad", "Medidas de seguridad en cada capa");
  const items = [
    ["SQL Injection", "Solo procedimientos con parámetros enlazados; validación de cada entrada en el servidor. ' OR 1=1 -- se trata como texto.", C.accent2],
    ["Login (R18)", "app.sp_Login compara HASHBYTES('SHA2_512', sal + contraseña) dentro de SQL Server; bloqueo tras 5 intentos.", C.accent3],
    ["Trigger de log (R15)", "trg_Usuarios_LogAlta guarda cada alta en LogUsuarios con login, equipo y fecha, sin hash ni sal.", C.accent1],
    ["Mínimo privilegio (R16)", "sa desactivado; cine_app solo EXECUTE en el esquema app y DENY sobre las tablas.", C.accent4],
    ["Sesiones y CSRF", "ID regenerado al iniciar sesión, cookie HttpOnly, rol revalidado en la base en cada página, token en cada formulario.", C.accent5],
    ["Salida y errores", "htmlspecialchars en toda salida, CSP sin scripts en línea; errores SQL a un log, nunca al usuario.", C.accent1],
  ];
  items.forEach(([t, d, col], i) => {
    const x = 0.6 + (i % 3) * 4.1, y = 1.5 + Math.floor(i / 3) * 2.65;
    tarjeta(s, x, y, 3.85, 2.4);
    s.addShape(pres.shapes.OVAL, { x: x + 0.25, y: y + 0.28, w: 0.3, h: 0.3, fill: { color: col }, line: { color: col, width: 0 }, objectName: id("punto") });
    texto(s, t, { x: x + 0.7, y: y + 0.2, w: 3.0, h: 0.45, fontSize: 17, bold: true, valign: "middle" });
    texto(s, d, { x: x + 0.25, y: y + 0.8, w: 3.4, h: 1.5, fontSize: 14, color: C.background2 });
  });
  s.addNotes("Recorrer las seis tarjetas. Para la demostración: intento de inyección en el login, tabla LogUsuarios tras registrar a alguien, sys.server_principals con sa desactivado y la sesión de la web entrando como cine_app.");
}

/* ============================ 10. Administrador ============================ */
pres.addSection({ title: "Administración" });
{
  const s = nueva("Administración", "Administrador: ventas en vivo y control de horarios");
  const h = captura(s, "08_admin.png", 0.6, 1.5, 7.6);
  texto(s, "Panel en vivo: se actualiza cada 5 segundos", { x: 0.6, y: 1.6 + h, w: 7.6, h: 0.3, fontSize: 12, color: C.background2 });
  const p = [
    ["Funciones vendidas y total recaudado", "en tiempo real (API JSON protegida)"],
    ["Agregar, modificar y borrar funciones", "la base rechaza horarios encimados en la sala"],
    ["Modificar el nombre de las películas", "y su sinopsis, clasificación y póster"],
    ["Ventas con tarjeta enmascarada", "descifrada solo dentro del procedimiento"],
    ["Rol validado en cada página", "y otra vez dentro de cada procedimiento"],
  ];
  p.forEach(([t, d], i) => {
    const y = 1.5 + i * 1.0;
    circuloNum(s, i + 1, 8.6, y + 0.05, 0.5, C.accent3);
    texto(s, t, { x: 9.25, y, w: 3.5, h: 0.5, fontSize: 15, bold: true });
    texto(s, d, { x: 9.25, y: y + 0.48, w: 3.5, h: 0.45, fontSize: 12, color: C.background2 });
  });
  s.addNotes("Iniciar sesión como admin@cineaurora.test. Mientras otra ventana compra boletos, el panel cambia solo. Mostrar alta de una función, cambio de horario, borrado (si tiene ventas se retira y conserva el historial) y cambio de nombre de una película.");
}

/* ============================ 11. Respaldo ============================ */
{
  const s = nueva("Administración", "Respaldo y recuperación sin perder el cifrado");
  const pasos = [
    ["Respaldar llaves", "BACKUP MASTER KEY y BACKUP CERTIFICATE con llave privada, más BACKUP SYMMETRIC KEY (2022)"],
    ["Respaldar la base", "BACKUP DATABASE … TO DISK = 'Respaldo_Proyecto_3.BAK' WITH CHECKSUM"],
    ["Verificar", "RESTORE VERIFYONLY y RESTORE HEADERONLY"],
    ["Restaurar en otra instancia", "OPEN MASTER KEY con su contraseña y ALTER MASTER KEY ADD ENCRYPTION BY SERVICE MASTER KEY"],
  ];
  pasos.forEach(([t, d], i) => {
    const x = 0.6 + i * 3.1;
    tarjeta(s, x, 1.5, 2.85, 3.25);
    circuloNum(s, i + 1, x + 0.25, 1.75, 0.6, [C.accent3, C.accent2, C.accent1, C.accent4][i]);
    texto(s, t, { x: x + 0.25, y: 2.5, w: 2.4, h: 0.7, fontSize: 17, bold: true });
    texto(s, d, { x: x + 0.25, y: 3.2, w: 2.45, h: 1.45, fontSize: 13, color: C.background2 });
  });
  tarjeta(s, 0.6, 5.1, 12.1, 1.5, { fill: "15131F" });
  texto(s, [
    { text: "Probado: ", options: { bold: true, color: C.accent4 } },
    { text: "el .BAK se restauró en una segunda instancia de SQL Server 2022 Express; tras ligar la llave maestra, las 4 tarjetas de ejemplo se descifraron y la web siguió comprando. El dueño de la base es sa (desactivado) para que los procedimientos EXECUTE AS OWNER funcionen en cualquier instancia." },
  ], { x: 0.9, y: 5.25, w: 11.5, h: 1.2, fontSize: 14, valign: "middle" });
  s.addNotes("R19: en vivo basta con el asistente de SSMS (clic derecho en CineAuroraDB > Tareas > Copia de seguridad) o con el script 09_respaldo.sql. Explicar por qué sin la contraseña de la DMK o sin el respaldo del certificado no se recuperan las tarjetas.");
}

/* ============================ 12. Pruebas ============================ */
pres.addSection({ title: "Cierre" });
{
  const s = nueva("Cierre", "Pruebas automatizadas: 81 de 81 correctas");
  const cats = ["Cartelera y páginas", "Compra sin sesión", "Registro y login", "SQL Injection", "Compra y tarjetas", "Límite de 10", "Doble venta", "Administrador", "Archivos y cabeceras"];
  const vals = [4, 5, 9, 11, 15, 7, 7, 16, 7];
  s.addChart(pres.charts.BAR, [{ name: "Pruebas correctas", labels: cats, values: vals }], {
    x: 0.6, y: 1.45, w: 8.0, h: 5.3, barDir: "bar", chartColors: ["FFB547"],
    showValue: true, dataLabelPosition: "outEnd", dataLabelColor: "F2F0F8", dataLabelFontSize: 12, dataLabelFontFace: "+mn-lt",
    catAxisLabelColor: "B6B1C9", catAxisLabelFontSize: 12, catAxisLabelFontFace: "+mn-lt", catAxisOrientation: "maxMin",
    valAxisHidden: true, valGridLine: { style: "none" }, catGridLine: { style: "none" }, showLegend: false,
    showTitle: true, title: "Pruebas correctas por tema", titleColor: "F2F0F8", titleFontSize: 14, titleFontFace: "+mn-lt",
    plotArea: { fill: { color: "0D0C16" } }, objectName: "grafica_pruebas",
  });
  tarjeta(s, 9.0, 1.45, 3.7, 5.3);
  texto(s, "81/81", { x: 9.3, y: 1.7, w: 3.2, h: 1.0, fontSize: 54, bold: true, color: C.accent4 });
  const p = ["HTTP real contra Apache + PHP 8.3 + SQL Server 2022 Express", "Tarjetas: Luhn, marca, vencimiento, CVV y rechazo simulado", "Concurrencia con 3 sesiones simultáneas", "Script: tests/pruebas_web.py"];
  texto(s, p.map((t, i) => ({ text: t, options: { bullet: true, breakLine: i < p.length - 1 } })), { x: 9.3, y: 2.85, w: 3.2, h: 3.7, fontSize: 14, paraSpaceAfter: 8 });
  s.addNotes("Las pruebas se ejecutaron en un banco Linux con Docker (SQL Server 2022 Express en Linux, Apache y PHP 8.3 con pdo_sqlsrv 5.12). En la VM Windows se repiten con el guion de GUIA_REVISION.md.");
}

/* ============================ 13. Conclusiones ============================ */
{
  const s = pres.addSlide({ masterName: "CIERRE", sectionTitle: "Cierre" });
  s.addText("Conclusiones", { placeholder: "title" });
  const c = [
    ["La base se defiende sola", "Llaves, UNIQUE, CHECK y triggers sostienen las reglas aunque la aplicación fallara.", C.accent1],
    ["Cifrar no basta: hay que administrar llaves", "Sin el respaldo del certificado y la contraseña de la llave maestra, un .BAK no recupera las tarjetas.", C.accent2],
    ["Menos privilegios, menos riesgo", "La web solo ejecuta procedimientos: aunque roben config.php no pueden leer tablas ni abrir la llave.", C.accent3],
  ];
  c.forEach(([t, d, col], i) => {
    const x = 0.8 + i * 4.0;
    tarjeta(s, x, 1.75, 3.7, 3.0, { fill: "1B1928" });
    s.addShape(pres.shapes.OVAL, { x: x + 0.3, y: 2.05, w: 0.34, h: 0.34, fill: { color: col }, line: { color: col, width: 0 }, objectName: id("punto") });
    texto(s, t, { x: x + 0.3, y: 2.55, w: 3.15, h: 0.85, fontSize: 18, bold: true });
    texto(s, d, { x: x + 0.3, y: 3.4, w: 3.15, h: 1.25, fontSize: 14, color: C.background2 });
  });
  texto(s, [
    { text: "Siguientes pasos en producción: ", options: { bold: true, color: C.accent1 } },
    { text: "HTTPS con certificado válido, hash de contraseñas lento (Argon2/bcrypt), pasarela de pago certificada PCI DSS en lugar de guardar tarjetas y respaldos programados fuera del servidor." },
  ], { x: 0.8, y: 5.15, w: 11.7, h: 1.0, fontSize: 15 });
  texto(s, "¡Gracias! · Preguntas", { x: 0.8, y: 6.4, w: 8, h: 0.5, fontSize: 20, bold: true, color: C.accent1 });
  s.addNotes("Cerrar con los aprendizajes y abrir preguntas. Recordar que la entrega en Teams incluye el .zip de páginas, el .BAK y esta presentación.");
}

(async () => {
  await pres.writeFile({ fileName: SALIDA });
  await require("./aplicar_tema.js")(SALIDA, THEME);
  console.log("Generado:", SALIDA);
})();

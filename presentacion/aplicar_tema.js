/* Escribe la paleta de Cine Aurora en ppt/theme/theme1.xml (pptxgenjs deja la de Office). */
const fs = require("fs");
const path = require("path");
const JSZip = require(require.resolve("jszip", { paths: [path.dirname(require.resolve("pptxgenjs"))] }));
const SLOTS = ["dk1", "lt1", "dk2", "lt2", "accent1", "accent2", "accent3", "accent4", "accent5", "accent6", "hlink", "folHlink"];

module.exports = async function aplicarTema(archivo, tema) {
  const zip = await JSZip.loadAsync(fs.readFileSync(archivo));
  for (const nombre of Object.keys(zip.files).filter((n) => /^ppt\/theme\/theme\d+\.xml$/.test(n))) {
    let xml = await zip.file(nombre).async("string");
    const esquema = `<a:clrScheme name="${tema.name}">` + SLOTS.map((k) =>
      `<a:${k}><a:srgbClr val="${tema.colors[k]}"/></a:${k}>`).join("") + "</a:clrScheme>";
    xml = xml.replace(/<a:clrScheme[\s\S]*?<\/a:clrScheme>/, esquema)
             .replace(/(<a:theme[^>]*\sname=")[^"]*(")/, `$1${tema.name}$2`);
    zip.file(nombre, xml);
  }
  fs.writeFileSync(archivo, await zip.generateAsync({ type: "nodebuffer", compression: "DEFLATE" }));
};

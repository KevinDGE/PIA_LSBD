"""Crea entregables/Paginas_Proyecto_3.zip con la carpeta cine/ (para htdocs),
los scripts SQL y las guías. Uso: python3 herramientas/empaquetar.py"""
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "entregables" / "Paginas_Proyecto_3.zip"
SALIDA.parent.mkdir(exist_ok=True)

with zipfile.ZipFile(SALIDA, "w", zipfile.ZIP_DEFLATED) as z:
    for f in sorted((RAIZ / "htdocs" / "cine").rglob("*")):
        if f.is_file() and not f.name.endswith(".log"):
            z.write(f, "cine/" + f.relative_to(RAIZ / "htdocs" / "cine").as_posix())
    for f in sorted((RAIZ / "sql").glob("*.sql")):
        z.write(f, "scripts_sql/" + f.name)
    for nombre in ["README.md", "GUIA_INSTALACION.md", "GUIA_REVISION.md", "CREDENCIALES_PRUEBA.md"]:
        z.write(RAIZ / nombre, "documentacion/" + nombre)
print("Creado", SALIDA, f"({SALIDA.stat().st_size // 1024} KB)")

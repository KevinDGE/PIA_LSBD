"""Genera los pósters (ilustraciones abstractas propias, sin texto ni personajes),
el logo y los íconos del sitio. Uso: python3 herramientas/generar_imagenes.py"""
import math
import random
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent / "htdocs" / "cine"
POSTERS = RAIZ / "assets" / "img" / "posters"
IMG = RAIZ / "assets" / "img"
POSTERS.mkdir(parents=True, exist_ok=True)

W, H = 400, 600


def svg(cuerpo: str, defs: str = "") -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">'
            f"<defs>{defs}</defs>{cuerpo}</svg>\n")


def grad(id_, c1, c2, x2="0", y2="1"):
    return (f'<linearGradient id="{id_}" x1="0" y1="0" x2="{x2}" y2="{y2}">'
            f'<stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></linearGradient>')


def estrellas(n, semilla, y_max=H, color="#fff"):
    r = random.Random(semilla)
    return "".join(
        f'<circle cx="{r.uniform(0, W):.1f}" cy="{r.uniform(0, y_max):.1f}" r="{r.choice([0.8, 1.1, 1.6])}" '
        f'fill="{color}" opacity="{r.uniform(.35, .95):.2f}"/>' for _ in range(n))


def orbita():
    d = grad("f", "#05061a", "#1e1b4b") + grad("p", "#38bdf8", "#6d28d9", "1", "1") + \
        '<radialGradient id="h" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#a78bfa" stop-opacity=".55"/><stop offset="1" stop-color="#a78bfa" stop-opacity="0"/></radialGradient>'
    c = f'<rect width="{W}" height="{H}" fill="url(#f)"/>{estrellas(140, 1)}' \
        '<circle cx="210" cy="300" r="190" fill="url(#h)"/>' \
        '<circle cx="210" cy="300" r="105" fill="url(#p)"/>' \
        '<ellipse cx="210" cy="300" rx="185" ry="38" fill="none" stroke="#e0e7ff" stroke-width="5" opacity=".75" transform="rotate(-18 210 300)"/>' \
        '<ellipse cx="210" cy="300" rx="155" ry="28" fill="none" stroke="#c4b5fd" stroke-width="2" opacity=".6" transform="rotate(-18 210 300)"/>' \
        '<circle cx="330" cy="140" r="9" fill="#fde68a"/>' \
        '<path d="M60 520 q 60 -40 120 0 t 120 0 t 120 0" stroke="#38bdf8" stroke-width="2" fill="none" opacity=".5"/>' \
        '<path d="M40 545 q 60 -40 120 0 t 120 0 t 120 0" stroke="#a78bfa" stroke-width="2" fill="none" opacity=".4"/>'
    return svg(c, d)


def faro():
    d = grad("f", "#1e3a8a", "#f97316") + grad("m", "#0c4a6e", "#082f49") + \
        '<linearGradient id="luz" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#fef3c7" stop-opacity=".85"/><stop offset="1" stop-color="#fef3c7" stop-opacity="0"/></linearGradient>'
    c = f'<rect width="{W}" height="{H}" fill="url(#f)"/>{estrellas(40, 2, 220)}' \
        '<circle cx="300" cy="380" r="60" fill="#fdba74" opacity=".8"/>' \
        '<polygon points="150,170 400,90 400,250" fill="url(#luz)"/>' \
        '<polygon points="150,170 0,110 0,230" fill="url(#luz)" opacity=".6" transform="scale(-1 1) translate(-300 0)"/>' \
        '<rect y="420" width="400" height="180" fill="url(#m)"/>' \
        '<path d="M0 430 q 50 -12 100 0 t 100 0 t 100 0 t 100 0" stroke="#7dd3fc" stroke-width="2" fill="none" opacity=".5"/>' \
        '<path d="M0 470 q 50 -12 100 0 t 100 0 t 100 0 t 100 0" stroke="#7dd3fc" stroke-width="1.5" fill="none" opacity=".35"/>' \
        '<polygon points="70,440 230,440 205,400 95,400" fill="#1f2937"/>' \
        '<polygon points="120,400 180,400 168,190 132,190" fill="#f8fafc"/>' \
        '<rect x="124" y="240" width="52" height="16" fill="#dc2626"/><rect x="128" y="310" width="45" height="16" fill="#dc2626"/>' \
        '<rect x="128" y="150" width="44" height="40" fill="#fde68a"/><polygon points="122,150 178,150 150,122" fill="#1f2937"/>'
    return svg(c, d)


def receta():
    d = grad("f", "#7c2d12", "#f59e0b") + grad("o", "#b91c1c", "#7f1d1d")
    r = random.Random(3)
    papel = "".join(f'<circle cx="{r.uniform(0, W):.0f}" cy="{r.uniform(0, H):.0f}" r="{r.uniform(10, 40):.0f}" fill="#fde68a" opacity="{r.uniform(.05, .15):.2f}"/>' for _ in range(25))
    c = f'<rect width="{W}" height="{H}" fill="url(#f)"/>{papel}' \
        '<path d="M150 250 c -20 -40 20 -60 0 -100" stroke="#fff7ed" stroke-width="7" fill="none" stroke-linecap="round" opacity=".8"/>' \
        '<path d="M200 240 c -20 -40 20 -60 0 -110" stroke="#fff7ed" stroke-width="7" fill="none" stroke-linecap="round" opacity=".9"/>' \
        '<path d="M250 250 c -20 -40 20 -60 0 -100" stroke="#fff7ed" stroke-width="7" fill="none" stroke-linecap="round" opacity=".8"/>' \
        '<ellipse cx="200" cy="300" rx="130" ry="26" fill="#451a03"/>' \
        '<path d="M80 300 q 0 130 120 130 q 120 0 120 -130 z" fill="url(#o)"/>' \
        '<ellipse cx="200" cy="300" rx="120" ry="20" fill="#fbbf24" opacity=".9"/>' \
        '<rect x="40" y="295" width="50" height="14" rx="7" fill="#451a03"/><rect x="310" y="295" width="50" height="14" rx="7" fill="#451a03"/>' \
        '<path d="M110 360 q 90 30 180 0" stroke="#fca5a5" stroke-width="4" fill="none" opacity=".6"/>' \
        '<rect x="0" y="470" width="400" height="130" fill="#451a03" opacity=".55"/>' \
        + "".join(f'<rect x="{x}" y="470" width="25" height="130" fill="#fef3c7" opacity=".12"/>' for x in range(0, 400, 50))
    return svg(c, d)


def sierra():
    d = grad("f", "#020617", "#134e4a") + grad("n", "#e2e8f0", "#94a3b8")
    c = f'<rect width="{W}" height="{H}" fill="url(#f)"/>{estrellas(70, 4, 260)}' \
        '<circle cx="290" cy="150" r="48" fill="url(#n)"/><circle cx="310" cy="140" r="44" fill="#020617" opacity=".85"/>' \
        '<polygon points="0,380 90,250 170,330 250,210 330,300 400,240 400,600 0,600" fill="#0f3d3a"/>' \
        '<polygon points="0,440 70,350 150,420 230,330 320,410 400,350 400,600 0,600" fill="#0b2b29"/>' \
        '<polygon points="0,500 80,430 160,490 260,420 340,480 400,450 400,600 0,600" fill="#061a19"/>' \
        + "".join(f'<polygon points="{x},{y} {x-10},{y+34} {x+10},{y+34}" fill="#03110f"/>' for x, y in [(40, 470), (70, 462), (300, 455), (330, 466), (360, 458)]) + \
        '<rect x="0" y="300" width="400" height="40" fill="#cbd5e1" opacity=".06"/><rect x="0" y="360" width="400" height="30" fill="#cbd5e1" opacity=".05"/>' \
        '<circle cx="200" cy="520" r="3" fill="#fde047"/><circle cx="200" cy="520" r="14" fill="#fde047" opacity=".15"/>'
    return svg(c, d)


def gigantes():
    d = grad("f", "#bbf7d0", "#22c55e")
    hojas = "".join(
        f'<path d="M{x} {y} q 40 -60 0 -120 q -40 60 0 120 z" fill="{c}" transform="rotate({a} {x} {y})" opacity=".9"/>'
        for x, y, a, c in [(60, 600, -20, "#15803d"), (130, 610, 10, "#166534"), (330, 600, 25, "#15803d"), (280, 620, -10, "#14532d"), (390, 560, 40, "#166534")])
    def hormiga(x, y, s, c):
        return (f'<g transform="translate({x} {y}) scale({s})" fill="{c}">'
                '<circle cx="0" cy="0" r="10"/><circle cx="18" cy="-2" r="8"/><circle cx="-20" cy="2" r="13"/>'
                '<path d="M-6 6 l-8 16 M2 7 l2 17 M10 6 l10 15 M-6 -6 l-8 -14 M2 -8 l2 -15 M10 -6 l10 -13" stroke="' + c + '" stroke-width="3" stroke-linecap="round"/>'
                '<path d="M22 -8 q 8 -14 18 -14 M24 -6 q 14 -6 20 2" stroke="' + c + '" stroke-width="2.5" fill="none" stroke-linecap="round"/></g>')
    c = f'<rect width="{W}" height="{H}" fill="url(#f)"/>' \
        '<circle cx="320" cy="110" r="55" fill="#fde047"/>' \
        + "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#fff" opacity=".55"/>' for x, y, r in [(80, 120, 30), (115, 110, 38), (150, 125, 28), (230, 200, 20), (255, 195, 26)]) + \
        '<rect x="110" y="290" width="180" height="110" rx="18" fill="#f97316"/><circle cx="150" cy="410" r="22" fill="#7c2d12"/><circle cx="250" cy="410" r="22" fill="#7c2d12"/>' \
        '<rect x="135" y="260" width="20" height="40" fill="#fb923c"/><circle cx="145" cy="255" r="14" fill="#fdba74"/>' \
        '<rect x="200" y="310" width="70" height="40" rx="8" fill="#38bdf8"/>' \
        + hormiga(90, 470, 1.4, "#7c2d12") + hormiga(300, 480, 1.1, "#9a3412") + hormiga(200, 240, 1.0, "#7c2d12") + hojas
    return svg(c, d)


def desierto():
    d = grad("f", "#fb923c", "#fde68a") + grad("a", "#f59e0b", "#b45309")
    c = f'<rect width="{W}" height="{H}" fill="url(#f)"/>' \
        '<circle cx="200" cy="260" r="80" fill="#fff7ed" opacity=".85"/>' \
        '<path d="M0 360 q 100 -60 200 0 t 200 0 v 240 h -400 z" fill="#f59e0b"/>' \
        '<path d="M0 420 q 120 -50 240 10 t 160 -10 v 180 h -400 z" fill="url(#a)"/>' \
        '<path d="M0 500 q 140 -40 260 0 t 140 0 v 100 h -400 z" fill="#92400e"/>' \
        '<g fill="#14532d"><rect x="300" y="330" width="16" height="110" rx="8"/><rect x="282" y="360" width="12" height="40" rx="6"/><rect x="282" y="390" width="26" height="12" rx="6"/><rect x="322" y="345" width="12" height="40" rx="6"/><rect x="308" y="375" width="26" height="12" rx="6"/></g>' \
        '<g transform="translate(95 470) rotate(-25)"><ellipse cx="0" cy="0" rx="30" ry="38" fill="#7c2d12"/><ellipse cx="0" cy="-30" rx="24" ry="28" fill="#7c2d12"/><circle cx="0" cy="-5" r="9" fill="#1c1917"/><rect x="-4" y="-150" width="8" height="120" fill="#451a03"/><rect x="-8" y="-170" width="16" height="24" rx="3" fill="#451a03"/></g>' \
        '<path d="M40 120 l15 -8 l15 8 M260 90 l12 -6 l12 6" stroke="#7c2d12" stroke-width="3" fill="none"/>'
    return svg(c, d)


def generico(n):
    colores = [("#111827", "#7c3aed"), ("#0f172a", "#0891b2")][n - 1]
    d = grad("f", *colores)
    if n == 1:  # carrete
        hoyos = "".join(f'<circle cx="{200 + 70 * math.cos(a)}" cy="{290 + 70 * math.sin(a)}" r="26" fill="#111827"/>' for a in [i * math.pi / 3 for i in range(6)])
        c = f'<rect width="{W}" height="{H}" fill="url(#f)"/>{estrellas(50, 7)}' \
            f'<circle cx="200" cy="290" r="130" fill="#e5e7eb"/><circle cx="200" cy="290" r="120" fill="#9ca3af"/>{hoyos}<circle cx="200" cy="290" r="18" fill="#e5e7eb"/>' \
            '<path d="M200 420 q 120 60 200 30 v 40 q -90 30 -200 -30 z" fill="#1f2937"/>'
    else:      # claqueta
        franjas = "".join(f'<polygon points="{x},170 {x + 30},170 {x + 10},210 {x - 20},210" fill="#f8fafc"/>' for x in range(90, 330, 60))
        c = f'<rect width="{W}" height="{H}" fill="url(#f)"/>{estrellas(50, 8)}' \
            '<rect x="70" y="210" width="260" height="190" rx="10" fill="#111827"/>' \
            '<g transform="rotate(-12 70 210)"><rect x="70" y="170" width="260" height="40" fill="#111827"/>' + franjas + '</g>' \
            '<rect x="90" y="250" width="220" height="6" fill="#f8fafc" opacity=".6"/><rect x="90" y="300" width="220" height="6" fill="#f8fafc" opacity=".6"/><rect x="90" y="350" width="140" height="6" fill="#f8fafc" opacity=".6"/>'
    return svg(c, d)


def logo_svg(tam=64):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="{tam}" height="{tam}">'
            '<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#8b5cf6"/>'
            '<stop offset=".55" stop-color="#ff6f61"/><stop offset="1" stop-color="#ffb547"/></linearGradient></defs>'
            '<rect width="64" height="64" rx="16" fill="#12101f"/>'
            '<path d="M10 44 A22 22 0 0 1 54 44" fill="none" stroke="url(#g)" stroke-width="6" stroke-linecap="round"/>'
            '<path d="M18 44 A14 14 0 0 1 46 44" fill="none" stroke="url(#g)" stroke-width="4" stroke-linecap="round" opacity=".7"/>'
            '<circle cx="32" cy="44" r="5" fill="#ffb547"/>'
            '<rect x="10" y="50" width="44" height="4" rx="2" fill="#f2f0f8" opacity=".85"/></svg>\n')


if __name__ == "__main__":
    for nombre, f in [("orbita-silenciosa", orbita), ("ultimo-faro", faro), ("receta-abuela", receta),
                      ("sombras-sierra", sierra), ("pequenos-gigantes", gigantes), ("ecos-desierto", desierto)]:
        (POSTERS / f"{nombre}.svg").write_text(f(), encoding="utf-8")
    (POSTERS / "generico-carrete.svg").write_text(generico(1), encoding="utf-8")
    (POSTERS / "generico-claqueta.svg").write_text(generico(2), encoding="utf-8")
    (IMG / "logo.svg").write_text(logo_svg(), encoding="utf-8")
    (IMG / "favicon.svg").write_text(logo_svg(), encoding="utf-8")
    print("Imágenes SVG generadas en", IMG)

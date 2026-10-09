"""Iconos y logo del Comisario, estilo senal FIA real: banderas de tela en su asta y placas de comisario.

Dibuja cada imagen en SVG, la renderiza con Chromium (Playwright) y guarda los PNG.
Uso: python3 arte/generar_iconos.py carpeta_salida carpeta_de_la_letra
La letra: npm install @fontsource/barlow-condensed (carpeta node_modules/@fontsource/barlow-condensed/files).
Despues se copian a apps/lua/Comisario/img en 320x220 y se hacen los chicos: python3 arte/reducir_iconos.py carpeta_salida apps/lua/Comisario/img
"""
import base64
import math
import os
import sys

from playwright.sync_api import sync_playwright

OUT = sys.argv[1] if len(sys.argv) > 1 else 'out'
FONTS = sys.argv[2] if len(sys.argv) > 2 else 'fonts'
W, H = 640, 440

RED, ORANGE, GREEN = '#D3141C', '#EE7A00', '#11994A'


def font_face():
    css = []
    for weight, style in ((800, 'normal'), (900, 'normal'), (800, 'italic'), (900, 'italic')):
        path = os.path.join(FONTS, 'barlow-condensed-latin-%d-%s.woff2' % (weight, style))
        data = base64.b64encode(open(path, 'rb').read()).decode()
        css.append("@font-face{font-family:'BC';font-weight:%d;font-style:%s;src:url(data:font/woff2;base64,%s) format('woff2');}"
                   % (weight, style, data))
    return '\n'.join(css)


# ---------------------------------------------------------------------------------------------- banderas
def pole_x(y):
    # asta levemente inclinada: arriba en x=150, abajo en x=120
    return 150 - 30 * (y - 22) / 400


def flag_path():
    a, b = (pole_x(36), 36), (pole_x(272), 272)
    return ('M{ax:.1f},{ay} C250,0 350,70 452,34 C520,10 576,18 614,44 '
            'C626,120 606,200 612,290 C556,262 498,262 440,292 C350,336 248,262 {bx:.1f},{by} Z').format(
        ax=a[0], ay=a[1], bx=b[0], by=b[1])


FOLDS = [(0.00, '#000', 0.30), (0.10, '#fff', 0.22), (0.24, '#000', 0.34), (0.40, '#fff', 0.26),
         (0.55, '#000', 0.30), (0.70, '#fff', 0.20), (0.86, '#000', 0.30), (1.00, '#fff', 0.10)]


def flag_fill(kind, uid):
    """Contenido de la tela (sin sombras), en el cuadro 120..620 x 0..340."""
    solid = {'green': '#13A14A', 'yellow': '#FFD400', 'blue': '#1E6FE0', 'white': '#F2F2EE',
             'black': '#121214', 'red': '#D5131B'}
    if kind in solid:
        return '<rect x="100" y="-10" width="540" height="360" fill="%s"/>' % solid[kind]
    if kind == 'check':
        s = 48
        cells = ['<rect x="100" y="-10" width="540" height="360" fill="#F4F4F0"/>']
        for r in range(-1, 8):
            for c in range(-1, 12):
                if (r + c) % 2 == 0:
                    cells.append('<rect x="%d" y="%d" width="%d" height="%d" fill="#111"/>' % (140 + c * s, 20 + r * s, s, s))
        return '\n'.join(cells)
    if kind == 'warn':
        # blanca y negra dividida en diagonal: aviso por conducta antideportiva
        return ('<rect x="100" y="-10" width="540" height="360" fill="#F4F4F0"/>'
                '<polygon points="100,-10 100,350 640,350" fill="#111"/>')
    raise ValueError(kind)


def flag(kind, uid, transform=''):
    edge = '#ffffff' if kind == 'black' else '#000000'
    edge_op = 0.45 if kind == 'black' else 0.35
    hl = {'red': 0.45, 'blue': 0.6, 'green': 0.75}.get(kind, 1.0)   # brillo de los pliegues: menos en telas saturadas
    stops = ''.join('<stop offset="%.2f" stop-color="%s" stop-opacity="%.2f"/>' % (o, c, a * (hl if c == '#fff' else 1))
                    for o, c, a in FOLDS)
    return f'''
<g transform="{transform}">
  <defs>
    <clipPath id="fc{uid}"><path d="{flag_path()}"/></clipPath>
    <linearGradient id="fo{uid}" gradientUnits="userSpaceOnUse" x1="150" y1="0" x2="615" y2="40">{stops}</linearGradient>
    <linearGradient id="fv{uid}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#fff" stop-opacity="0.18"/><stop offset="0.45" stop-color="#fff" stop-opacity="0"/>
      <stop offset="1" stop-color="#000" stop-opacity="0.22"/>
    </linearGradient>
    <filter id="tx{uid}" x="0" y="0" width="100%" height="100%">
      <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" seed="4"/>
      <feColorMatrix values="0 0 0 0 0.5  0 0 0 0 0.5  0 0 0 0 0.5  0 0 0 0.10 0"/>
    </filter>
    <filter id="wv{uid}" x="-10%" y="-10%" width="120%" height="120%">
      <feTurbulence type="turbulence" baseFrequency="0.0035 0.009" numOctaves="1" seed="7" result="n"/>
      <feDisplacementMap in="SourceGraphic" in2="n" scale="26" xChannelSelector="R" yChannelSelector="G"/>
    </filter>
    <filter id="sh{uid}" x="-20%" y="-20%" width="140%" height="160%">
      <feDropShadow dx="7" dy="12" stdDeviation="9" flood-color="#000" flood-opacity="0.5"/>
    </filter>
    <linearGradient id="pl{uid}" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#2a2c30"/><stop offset="0.35" stop-color="#9aa0a8"/><stop offset="0.55" stop-color="#e6e9ee"/>
      <stop offset="1" stop-color="#3a3d42"/>
    </linearGradient>
    <radialGradient id="kn{uid}" cx="0.35" cy="0.35" r="0.7">
      <stop offset="0" stop-color="#fff"/><stop offset="0.5" stop-color="#b9bec6"/><stop offset="1" stop-color="#4a4e55"/>
    </radialGradient>
  </defs>
  <g filter="url(#sh{uid})">
    <g filter="url(#wv{uid})">
      <g clip-path="url(#fc{uid})">
        {flag_fill(kind, uid)}
        <rect x="100" y="-10" width="540" height="360" fill="url(#fo{uid})"/>
        <rect x="100" y="-10" width="540" height="360" fill="url(#fv{uid})"/>
        <rect x="100" y="-10" width="540" height="360" filter="url(#tx{uid})"/>
      </g>
      <path d="{flag_path()}" fill="none" stroke="{edge}" stroke-opacity="{edge_op}" stroke-width="3"/>
    </g>
    <polygon points="{pole_x(22) - 8:.1f},22 {pole_x(22) + 8:.1f},22 {pole_x(424) + 8:.1f},424 {pole_x(424) - 8:.1f},424"
      fill="url(#pl{uid})"/>
    <circle cx="{pole_x(18):.1f}" cy="18" r="13" fill="url(#kn{uid})"/>
  </g>
</g>'''


def crossed(left, right, uid, cx, cy, s, d, ang=18):
    """Dos banderas cruzadas: las astas se juntan abajo y las telas salen hacia afuera."""
    base = 'rotate(%g) scale(%g) translate(-120 -424)' % (ang, s)
    return (flag(left, uid + 'l', 'translate(%g %g) scale(-1 1) %s' % (cx + d, cy, base))
            + flag(right, uid + 'r', 'translate(%g %g) %s' % (cx - d, cy, base)))


# ---------------------------------------------------------------------------------------------- placas
def board(uid, border, inner, x=105, y=26, w=430, h=290, rot=-4, handle=True):
    cx, cy = x + w / 2, y + h / 2
    hx = cx - 26
    handle_svg = f'''
    <rect x="{hx}" y="{y + h - 6}" width="52" height="{424 - (y + h)}" rx="10" fill="url(#hd{uid})"/>
    <rect x="{hx + 6}" y="{y + h + 40}" width="40" height="6" rx="3" fill="#000" opacity="0.35"/>
    <rect x="{hx + 6}" y="{y + h + 58}" width="40" height="6" rx="3" fill="#000" opacity="0.35"/>''' if handle else ''
    screws = ''.join('<circle cx="%d" cy="%d" r="6" fill="url(#sc%s)"/>' % (px, py, uid)
                     for px, py in ((x + 26, y + 26), (x + w - 26, y + 26), (x + 26, y + h - 26), (x + w - 26, y + h - 26)))
    return f'''
<g transform="rotate({rot} {cx} {cy})">
  <defs>
    <filter id="bs{uid}" x="-20%" y="-20%" width="140%" height="160%">
      <feDropShadow dx="7" dy="12" stdDeviation="9" flood-color="#000" flood-opacity="0.55"/>
    </filter>
    <linearGradient id="bf{uid}" x1="0" y1="0" x2="0.3" y2="1">
      <stop offset="0" stop-color="#ffffff"/><stop offset="0.6" stop-color="#eeeeea"/><stop offset="1" stop-color="#d9d9d4"/>
    </linearGradient>
    <linearGradient id="bg{uid}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#fff" stop-opacity="0.35"/><stop offset="0.5" stop-color="#fff" stop-opacity="0"/>
    </linearGradient>
    <linearGradient id="hd{uid}" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#15161a"/><stop offset="0.45" stop-color="#4a4d54"/><stop offset="1" stop-color="#15161a"/>
    </linearGradient>
    <radialGradient id="sc{uid}" cx="0.35" cy="0.35" r="0.7">
      <stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#7b8088"/>
    </radialGradient>
    <filter id="bt{uid}" x="0" y="0" width="100%" height="100%">
      <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="11"/>
      <feColorMatrix values="0 0 0 0 0.5  0 0 0 0 0.5  0 0 0 0 0.5  0 0 0 0.07 0"/>
    </filter>
  </defs>
  <g filter="url(#bs{uid})">
    {handle_svg}
    <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="24" fill="{border}"/>
    <rect x="{x + 22}" y="{y + 22}" width="{w - 44}" height="{h - 44}" rx="12" fill="url(#bf{uid})"/>
    <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="24" filter="url(#bt{uid})"/>
    <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="24" fill="url(#bg{uid})"/>
    <rect x="{x + 1.5}" y="{y + 1.5}" width="{w - 3}" height="{h - 3}" rx="23" fill="none" stroke="#000" stroke-opacity="0.45" stroke-width="3"/>
    {screws}
    <g transform="translate({cx} {cy})">{inner}</g>
  </g>
</g>'''


def text(t, size, color='#111', dy=0, weight=900, spacing=0):
    return ('<text x="0" y="{dy}" text-anchor="middle" dominant-baseline="central" font-family="BC" font-weight="{w}" '
            'font-size="{s}" letter-spacing="{sp}" fill="{c}">{t}</text>').format(dy=dy, w=weight, s=size, sp=spacing, c=color, t=t)


def check_mark(color):
    return '<path d="M-110,-6 L-40,64 L112,-88" fill="none" stroke="%s" stroke-width="46" stroke-linecap="round" stroke-linejoin="round"/>' % color


def stopwatch():
    return '''
<g transform="translate(36 10)">
  <rect x="-18" y="-128" width="36" height="26" rx="6" fill="#111"/>
  <rect x="-8" y="-108" width="16" height="22" fill="#111"/>
  <rect x="62" y="-92" width="22" height="34" rx="6" fill="#111" transform="rotate(45 73 -75)"/>
  <circle cx="0" cy="0" r="92" fill="#111"/>
  <circle cx="0" cy="0" r="70" fill="#fff"/>
  <path d="M0,0 L0,-70 A70,70 0 0,1 60.6,35 Z" fill="#EE7A00"/>
  <circle cx="0" cy="0" r="12" fill="#111"/>
  <path d="M0,0 L44,-44" stroke="#111" stroke-width="12" stroke-linecap="round"/>
</g>
<path d="M-150,10 h64 M-118,-22 v64" stroke="#111" stroke-width="22" stroke-linecap="round"/>'''


def lift_pictogram():
    # pie que se levanta del pedal del acelerador
    return '''
<g transform="translate(-40 30) rotate(-18)">
  <rect x="-50" y="-30" width="100" height="150" rx="16" fill="#111"/>
  <g fill="#fff"><rect x="-32" y="-12" width="64" height="12" rx="4"/><rect x="-32" y="14" width="64" height="12" rx="4"/>
  <rect x="-32" y="40" width="64" height="12" rx="4"/><rect x="-32" y="66" width="64" height="12" rx="4"/>
  <rect x="-32" y="92" width="64" height="12" rx="4"/></g>
</g>
<path d="M88,90 L88,-70" stroke="#111" stroke-width="30" stroke-linecap="round"/>
<path d="M30,-30 L88,-100 L146,-30" fill="none" stroke="#111" stroke-width="30" stroke-linecap="round" stroke-linejoin="round"/>'''


def swap_arrows():
    return '''
<g fill="none" stroke="#111" stroke-width="30" stroke-linecap="round" stroke-linejoin="round">
  <path d="M-140,-45 H110"/><path d="M60,-95 L118,-45 L60,5"/>
  <path d="M140,55 H-110"/><path d="M-60,5 L-118,55 L-60,105"/>
</g>'''


ICONS = {
    'bandera_verde': lambda: flag('green', 'a'),
    'bandera_amarilla': lambda: flag('yellow', 'a'),
    'bandera_azul': lambda: flag('blue', 'a'),
    'bandera_blanca': lambda: flag('white', 'a'),
    'bandera_negra': lambda: flag('black', 'a'),
    'bandera_roja': lambda: flag('red', 'a'),
    'bandera_cuadros': lambda: flag('check', 'a'),
    'aviso': lambda: flag('warn', 'a'),
    # amarilla total: dos amarillas agitadas, cruzadas
    'bandera_amarilla_total': lambda: crossed('yellow', 'yellow', 'y', 320, 350, 0.62, 36, 13),
    'drive_through': lambda: board('d', RED, text('DT', 250, dy=8)),
    'stop_and_go': lambda: board('s', RED, text('SG', 250, dy=8)),
    'descalificado': lambda: (flag('black', 'a', 'translate(-10 0) scale(0.92)')
                              + board('q', RED, text('DSQ', 150, dy=6), x=300, y=170, w=300, h=200, rot=5, handle=False)),
    'levantar': lambda: board('l', ORANGE, lift_pictogram()),
    'devolver': lambda: board('g', ORANGE, swap_arrows()),
    'tiempo': lambda: board('t', ORANGE, stopwatch()),
    'cumplida': lambda: board('c', GREEN, check_mark(GREEN)),
}


# ---------------------------------------------------------------------------------------------- logo
def app_icon():
    # icono chico de la ventana (64 px): mismo medallon, banderas mas grandes y anillos finos para que se lean
    return f'''
<defs>
  <radialGradient id="ig" cx="0.5" cy="0.38" r="0.75"><stop offset="0" stop-color="#30333a"/><stop offset="1" stop-color="#0b0c0e"/></radialGradient>
  <linearGradient id="ir" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff3b42"/><stop offset="1" stop-color="#a50a10"/></linearGradient>
  <clipPath id="ic"><circle cx="256" cy="256" r="236"/></clipPath>
</defs>
<circle cx="256" cy="256" r="250" fill="url(#ir)"/>
<circle cx="256" cy="256" r="222" fill="url(#ig)"/>
<g clip-path="url(#ic)">{crossed('check', 'warn', 'xi', 256, 392, 0.56, 40, 14)}</g>'''


def roundel(uid, with_ring=True):
    # medallon: dos banderas cruzadas (aviso y cuadros) sobre fondo oscuro
    return f'''
<defs>
  <radialGradient id="rg{uid}" cx="0.5" cy="0.38" r="0.75">
    <stop offset="0" stop-color="#2c2f36"/><stop offset="1" stop-color="#0b0c0e"/>
  </radialGradient>
  <linearGradient id="rr{uid}" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#ff3b42"/><stop offset="1" stop-color="#a50a10"/>
  </linearGradient>
  <filter id="rs{uid}" x="-20%" y="-20%" width="140%" height="140%">
    <feDropShadow dx="0" dy="10" stdDeviation="12" flood-color="#000" flood-opacity="0.55"/>
  </filter>
</defs>
<g filter="url(#rs{uid})">
  <circle cx="256" cy="256" r="236" fill="url(#rr{uid})"/>
  <circle cx="256" cy="256" r="214" fill="#f2f2ee"/>
  <circle cx="256" cy="256" r="200" fill="url(#rg{uid})"/>
</g>
{crossed('check', 'warn', 'x' + uid, 256, 300, 0.5, 52)}'''


def logo_svg():
    return f'''
{roundel('L')}
<defs>
  <linearGradient id="bn" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#ff3b42"/><stop offset="1" stop-color="#b30c12"/>
  </linearGradient>
  <filter id="bns" x="-10%" y="-30%" width="120%" height="160%">
    <feDropShadow dx="0" dy="8" stdDeviation="8" flood-color="#000" flood-opacity="0.6"/>
  </filter>
</defs>
<g filter="url(#bns)">
  <polygon points="22,318 500,318 476,402 0,402" fill="#0b0c0e"/>
  <polygon points="34,326 488,326 466,394 12,394" fill="url(#bn)"/>
</g>
<text x="248" y="362" text-anchor="middle" dominant-baseline="central" font-family="BC" font-style="italic" font-weight="900"
  font-size="86" letter-spacing="2" fill="#fff" stroke="#0b0c0e" stroke-width="3" paint-order="stroke">COMISARIO</text>
<text x="256" y="440" text-anchor="middle" dominant-baseline="central" font-family="BC" font-weight="800"
  font-size="30" letter-spacing="7" fill="#f2f2ee" stroke="#0b0c0e" stroke-width="6" paint-order="stroke">RACE STEWARD</text>'''


def page(svg, w, h):
    return f'''<!doctype html><html><head><style>{font_face()} html,body{{margin:0;background:transparent}}</style></head>
<body><svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{svg}</svg></body></html>'''


def main():
    os.makedirs(OUT, exist_ok=True)
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page(device_scale_factor=2)
        for name, fn in ICONS.items():
            pg.set_viewport_size({'width': W, 'height': H})
            pg.set_content(page(fn(), W, H))
            pg.wait_for_timeout(150)
            pg.locator('svg').screenshot(path=os.path.join(OUT, name + '.png'), omit_background=True)
        pg.set_viewport_size({'width': 512, 'height': 512})
        pg.set_content(page(logo_svg(), 512, 512))
        pg.wait_for_timeout(150)
        pg.locator('svg').screenshot(path=os.path.join(OUT, 'logo.png'), omit_background=True)
        pg.set_content(page(app_icon(), 512, 512))
        pg.wait_for_timeout(150)
        pg.locator('svg').screenshot(path=os.path.join(OUT, 'emblema.png'), omit_background=True)
        b.close()
    print('listo', len(ICONS) + 2)


if __name__ == '__main__':
    main()

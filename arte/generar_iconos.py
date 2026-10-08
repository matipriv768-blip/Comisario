"""Redibuja en vectores los iconos de sancion (estilo placa inclinada con estela) y los exporta en alta resolucion."""
import asyncio, math, sys
from playwright.async_api import async_playwright

W, H = 640, 440          # lienzo de cada icono
TL, TR, BR, BL = (205, 60), (600, 60), (490, 360), (95, 360)   # placa inclinada

PAL = {
    'yellow': dict(a='#FFE83A', b='#F2B705', c='#C98A00', s1='#FFD21A', s2='#FF8A00'),
    'orange': dict(a='#FF9A2E', b='#F36A0A', c='#C44A00', s1='#FF8A1E', s2='#E0195A'),
    'red':    dict(a='#F2434B', b='#D11A22', c='#8E0D14', s1='#F0323A', s2='#B0126A'),
    'black':  dict(a='#5A5D63', b='#2A2C30', c='#0E0F11', s1='#3A3C42', s2='#5A1A8A'),
    'green':  dict(a='#3FD45A', b='#16A534', c='#0A6E20', s1='#2FC24A', s2='#0E7A3A'),
}

def pts(*p): return ' '.join('%g,%g' % q for q in p)

def streaks(pal, uid):
    # puntas de velocidad a la izquierda: salen desde el borde izquierdo inclinado de la placa
    out = []
    rows = [(78, 150, 13), (104, 95, 9), (128, 175, 15), (156, 120, 10), (182, 200, 16), (210, 110, 9),
            (236, 185, 15), (264, 130, 11), (290, 205, 16), (318, 105, 9), (342, 160, 13)]
    for y, length, th in rows:
        t = (y - TL[1]) / (BL[1] - TL[1])
        x_edge = TL[0] + (BL[0] - TL[0]) * t + 26          # un poco dentro de la placa
        x0 = x_edge - length - 26
        out.append('<polygon points="%s" fill="url(#st%s)"/>' % (pts((x0, y), (x_edge, y - th / 2), (x_edge, y + th / 2)), uid))
    return '\n'.join(out)

def plate(color, uid):
    p = PAL[color]
    off = 16
    sh = [(q[0] + off, q[1] + off) for q in (TL, TR, BR, BL)]
    return f'''
<defs>
  <linearGradient id="pg{uid}" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="{p['a']}"/><stop offset="0.55" stop-color="{p['b']}"/><stop offset="1" stop-color="{p['c']}"/>
  </linearGradient>
  <linearGradient id="st{uid}" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="{p['s2']}" stop-opacity="0.0"/><stop offset="0.35" stop-color="{p['s2']}" stop-opacity="0.85"/>
    <stop offset="1" stop-color="{p['s1']}"/>
  </linearGradient>
  <linearGradient id="gl{uid}" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.34"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
  </linearGradient>
  <pattern id="cf{uid}" width="12" height="12" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
    <rect width="12" height="12" fill="#17181B"/><rect width="6" height="6" fill="#2B2D32"/><rect x="6" y="6" width="6" height="6" fill="#2B2D32"/>
  </pattern>
  <clipPath id="cp{uid}"><polygon points="{pts(TL, TR, BR, BL)}"/></clipPath>
  <filter id="ds{uid}" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="7"/></filter>
  <filter id="sy{uid}" x="-20%" y="-20%" width="140%" height="140%">
    <feDropShadow dx="3" dy="5" stdDeviation="4" flood-color="#000" flood-opacity="0.35"/>
  </filter>
</defs>
<polygon points="{pts(*[(q[0] + 8, q[1] + 12) for q in sh])}" fill="#000" opacity="0.28" filter="url(#ds{uid})"/>
{streaks(p, uid)}
<polygon points="{pts(*sh)}" fill="url(#cf{uid})"/>
<polygon points="{pts(*sh)}" fill="none" stroke="#000" stroke-opacity="0.5" stroke-width="2"/>
<polygon points="{pts(TL, TR, BR, BL)}" fill="url(#pg{uid})"/>
<g clip-path="url(#cp{uid})">
  <polygon points="{pts((TL[0] - 40, TL[1]), (TR[0], TR[1]), (TR[0] - 48, TR[1] + 130), (TL[0] - 88, TL[1] + 130))}" fill="url(#gl{uid})"/>
</g>
<polygon points="{pts(TL, TR, BR, BL)}" fill="none" stroke="#FFFFFF" stroke-opacity="0.85" stroke-width="3.5" stroke-linejoin="round"/>
<polyline points="{pts(BL, BR, TR)}" fill="none" stroke="#000" stroke-opacity="0.28" stroke-width="3.5" stroke-linejoin="round"/>
'''

CX, CY = 348, 210   # centro visual de la placa

def sym(body, uid, skew=-10):
    return f'<g filter="url(#sy{uid})" transform="translate({CX} {CY}) skewX({skew})">{body}</g>'

def s_warning():
    return '<polygon points="-24,-112 24,-112 13,34 -13,34" fill="#fff"/><rect x="-19" y="58" width="38" height="38" rx="5" fill="#fff"/>'

def s_time():
    return ('<circle cx="0" cy="14" r="78" fill="none" stroke="#fff" stroke-width="22"/>'
            '<rect x="-17" y="-112" width="34" height="34" rx="5" fill="#fff"/>'
            '<rect x="-34" y="-124" width="68" height="20" rx="8" fill="#fff"/>'
            '<rect x="58" y="-84" width="34" height="20" rx="6" fill="#fff" transform="rotate(42 75 -74)"/>'
            '<line x1="0" y1="14" x2="34" y2="-30" stroke="#fff" stroke-width="15" stroke-linecap="round"/>'
            '<circle cx="0" cy="14" r="14" fill="#fff"/>')

def s_lift(color):
    hole = PAL[color]['b']
    holes = ''.join('<circle cx="%d" cy="%d" r="11" fill="%s"/>' % (x, y, hole) for y in (-66, -22, 22, 66) for x in (-76, -34))
    return ('<rect x="-106" y="-104" width="102" height="208" rx="18" fill="#fff" transform="rotate(4 -55 0)"/>' +
            '<g transform="rotate(4 -55 0)">' + holes + '</g>' +
            '<polygon points="66,-108 122,-34 88,-34 88,96 44,96 44,-34 10,-34" fill="#fff"/>')

def s_dt():
    # pista en perspectiva con linea central punteada y una flecha que sale hacia el costado
    road = ('<polygon points="-112,96 -72,-100 -44,-100 -52,96" fill="#fff"/>'
            '<polygon points="-22,96 -30,-100 -2,-100 38,96" fill="#fff"/>'
            '<rect x="-42" y="52" width="10" height="40" fill="#fff"/><rect x="-42" y="-12" width="10" height="40" fill="#fff"/>'
            '<rect x="-42" y="-76" width="10" height="40" fill="#fff"/>')
    arrow = ('<path d="M 62 96 L 62 20 Q 62 -34 112 -34" fill="none" stroke="#fff" stroke-width="30" stroke-linejoin="round"/>'
             '<polygon points="104,-84 162,-34 104,16" fill="#fff"/>')
    return road + arrow

def s_stop():
    # mano abierta de "alto": cuatro dedos separados, el del medio mas largo, palma redondeada y pulgar abierto
    fw, gap = 33, 9
    x0 = -(4 * fw + 3 * gap) / 2 + 8
    tops = (-98, -120, -108, -78)
    fingers = ''.join('<rect x="%g" y="%g" width="%g" height="%g" rx="%g" fill="#fff"/>' % (x0 + n * (fw + gap), top, fw, 40 - top, fw / 2)
                      for n, top in enumerate(tops))
    left, right = x0, x0 + 4 * fw + 3 * gap
    palm = ('<path d="M %g 6 H %g V 46 C %g 96 %g 116 %g 116 H %g C %g 116 %g 100 %g 70 L %g 30 Z" fill="#fff"/>'
            % (left, right, right, right - 28, right - 62, left + 46, left + 22, left + 6, left - 6, left))
    # pulgar: nace en el costado bajo de la palma y abre hacia afuera
    thumb = ('<path d="M %g 44 C %g 30 %g 6 %g -6 C %g -16 %g -12 %g 2 C %g 26 %g 58 %g 92 Z" fill="#fff"/>'
             % (left + 4, left - 22, left - 44, left - 58, left - 72, left - 86, left - 80, left - 66, left - 36, left + 10))
    return fingers + palm + thumb

def s_swap():
    top = ('<path d="M -104 -6 Q -104 -62 -40 -62 L 44 -62" fill="none" stroke="#fff" stroke-width="32"/>'
           '<polygon points="34,-118 116,-62 34,-6" fill="#fff"/>')
    bot = ('<path d="M 104 6 Q 104 62 40 62 L -44 62" fill="none" stroke="#fff" stroke-width="32"/>'
           '<polygon points="-34,6 -116,62 -34,118" fill="#fff"/>')
    return top + bot

def s_dq():
    bar = '<rect x="-112" y="-21" width="224" height="42" rx="8" fill="#F0222C"/>'
    return '<g transform="rotate(45)">%s</g><g transform="rotate(-45)">%s</g>' % (bar, bar)

def s_ok():
    return '<polyline points="-98,6 -32,74 106,-84" fill="none" stroke="#fff" stroke-width="44" stroke-linecap="butt" stroke-linejoin="miter"/>'

ICONS = [
    ('aviso', 'yellow', s_warning()), ('tiempo', 'orange', s_time()), ('levantar', 'orange', s_lift('orange')),
    ('drive_through', 'red', s_dt()), ('stop_and_go', 'red', s_stop()), ('devolver', 'orange', s_swap()),
    ('descalificado', 'black', s_dq()), ('cumplida', 'green', s_ok()),
]

def icon_svg(name, color, body, uid):
    return plate(color, uid) + sym(body, uid)

def single(name, color, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{icon_svg(name, color, body, "a")}</svg>'

def sheet(bg):
    cols, gapx, gapy, mx, my = 4, 60, 70, 80, 90
    sw, shh = mx * 2 + cols * W + (cols - 1) * gapx, my * 2 + 2 * H + gapy
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{sw}" height="{shh}" viewBox="0 0 {sw} {shh}">']
    if bg: parts.append(f'<rect width="{sw}" height="{shh}" fill="{bg}"/>')
    for n, (name, color, body) in enumerate(ICONS):
        x, y = mx + (n % cols) * (W + gapx), my + (n // cols) * (H + gapy)
        parts.append(f'<g transform="translate({x} {y})">{icon_svg(name, color, body, str(n))}</g>')
    parts.append('</svg>')
    return ''.join(parts), sw, shh


# ---------------------------------------------------------------- banderas (misma familia que las sanciones)
FPAL = {
    'green':  dict(a='#3DDB5C', b='#12A632', c='#0A6B1F', s1='#19B43A', s2='#0B5A1C'),
    'yellow': dict(a='#FFF05A', b='#FFD800', c='#D9A400', s1='#FFD800', s2='#FF9A00'),
    'red':    dict(a='#FF5A5F', b='#E01219', c='#96080D', s1='#E8151C', s2='#8A0A10'),
    'blue':   dict(a='#4C8DFF', b='#0E4FE0', c='#082E96', s1='#1658E8', s2='#081F7A'),
    'white':  dict(a='#FFFFFF', b='#EDEFF2', c='#B9BEC6', s1='#F2F4F7', s2='#8D949E'),
    'black':  dict(a='#4A4D53', b='#1B1D20', c='#060607', s1='#8A8E96', s2='#4A4D53'),
}

def flag_one(color, uid, dx=0, check=False, with_streaks=True):
    p = FPAL[color]
    P = [(q[0] + dx, q[1]) for q in (TL, TR, BR, BL)]
    tl, tr, br, bl = P
    off = 16
    sh = [(q[0] + off, q[1] + off) for q in P]
    st = ''
    if with_streaks:
        rows = [(92, 150, 20), (150, 110, 15), (208, 190, 22), (268, 125, 16), (326, 170, 20)]
        for y, length, th in rows:
            t = (y - TL[1]) / (BL[1] - TL[1])
            xe = TL[0] + dx + (BL[0] - TL[0]) * t + 30
            st += '<polygon points="%s" fill="url(#fs%s)"/>' % (pts((xe - length - 30, y), (xe, y - th / 2), (xe, y + th / 2)), uid)
    cloth = ''
    if check:
        # cuadros inclinados igual que la placa
        k = (TL[0] - BL[0]) / (BL[1] - TL[1])
        cols, rws = 6, 4
        cw, ch = (tr[0] - tl[0]) / cols, (bl[1] - tl[1]) / rws
        for r in range(rws):
            for c in range(cols):
                if (r + c) % 2 == 0:
                    y0, y1 = tl[1] + r * ch, tl[1] + (r + 1) * ch
                    x0 = tl[0] + c * cw
                    cloth += '<polygon points="%s" fill="#111214"/>' % pts(
                        (x0 - k * (y0 - tl[1]), y0), (x0 + cw - k * (y0 - tl[1]), y0),
                        (x0 + cw - k * (y1 - tl[1]), y1), (x0 - k * (y1 - tl[1]), y1))
    # pliegues de tela: bandas suaves claras y oscuras
    folds = ''
    for fx, wdt, op, col in ((0.16, 60, 0.20, '#fff'), (0.40, 70, 0.16, '#000'), (0.62, 60, 0.18, '#fff'), (0.86, 70, 0.16, '#000')):
        x = tl[0] + (tr[0] - tl[0]) * fx
        folds += '<polygon points="%s" fill="%s" opacity="%g" filter="url(#fb%s)"/>' % (
            pts((x, tl[1] - 10), (x + wdt, tl[1] - 10), (x + wdt - 150, bl[1] + 10), (x - 150, bl[1] + 10)), col, op, uid)
    return f"""
<defs>
  <linearGradient id="fg{uid}" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="{p['a']}"/><stop offset="0.5" stop-color="{p['b']}"/><stop offset="1" stop-color="{p['c']}"/>
  </linearGradient>
  <linearGradient id="fs{uid}" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="{p['s2']}" stop-opacity="0"/><stop offset="0.3" stop-color="{p['s2']}" stop-opacity="0.9"/>
    <stop offset="1" stop-color="{p['s1']}"/>
  </linearGradient>
  <linearGradient id="fm{uid}" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#FFFFFF"/><stop offset="0.35" stop-color="#B9BEC6"/><stop offset="0.6" stop-color="#F4F5F7"/>
    <stop offset="1" stop-color="#7C828C"/>
  </linearGradient>
  <pattern id="fc{uid}" width="12" height="12" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
    <rect width="12" height="12" fill="#17181B"/><rect width="6" height="6" fill="#2B2D32"/><rect x="6" y="6" width="6" height="6" fill="#2B2D32"/>
  </pattern>
  <clipPath id="fp{uid}"><polygon points="{pts(*P)}"/></clipPath>
  <filter id="fb{uid}" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="16"/></filter>
  <filter id="fd{uid}" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="7"/></filter>
</defs>
<polygon points="{pts(*[(q[0] + 8, q[1] + 12) for q in sh])}" fill="#000" opacity="0.28" filter="url(#fd{uid})"/>
{st}
<polygon points="{pts(*sh)}" fill="url(#fc{uid})"/>
<polygon points="{pts(*P)}" fill="url(#fg{uid})"/>
<g clip-path="url(#fp{uid})">{cloth}{folds}</g>
<polygon points="{pts(*P)}" fill="none" stroke="url(#fm{uid})" stroke-width="11" stroke-linejoin="miter"/>
<polygon points="{pts(*P)}" fill="none" stroke="#000" stroke-opacity="0.35" stroke-width="1.5"/>
"""

def flag_svg(kind, uid):
    if kind == 'fcy':   # amarilla total: dos banderas amarillas, una detras de la otra
        return flag_one('yellow', uid + 'a', dx=-34) + flag_one('yellow', uid + 'b', dx=34, with_streaks=False)
    if kind == 'check':
        return flag_one('white', uid, check=True)
    return flag_one(kind, uid)

FLAGS = [('verde', 'green'), ('amarilla', 'yellow'), ('amarilla_total', 'fcy'), ('roja', 'red'),
         ('azul', 'blue'), ('blanca', 'white'), ('cuadros', 'check'), ('negra', 'black')]

def flag_single(kind):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{flag_svg(kind, "f")}</svg>'

def flag_sheet(bg):
    cols, gapx, gapy, mx, my = 4, 60, 70, 80, 90
    sw, shh = mx * 2 + cols * W + (cols - 1) * gapx, my * 2 + 2 * H + gapy
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{sw}" height="{shh}" viewBox="0 0 {sw} {shh}">']
    if bg: parts.append(f'<rect width="{sw}" height="{shh}" fill="{bg}"/>')
    for n, (name, kind) in enumerate(FLAGS):
        x, y = mx + (n % cols) * (W + gapx), my + (n // cols) * (H + gapy)
        parts.append(f'<g transform="translate({x} {y})">{flag_svg(kind, "f" + str(n))}</g>')
    parts.append('</svg>')
    return ''.join(parts), sw, shh

async def render(page, svg, w, h, scale, out):
    await page.set_viewport_size({'width': w, 'height': h})
    await page.set_content('<html><body style="margin:0;background:transparent">%s</body></html>' % svg)
    await page.screenshot(path=out, omit_background=True, clip={'x': 0, 'y': 0, 'width': w, 'height': h}, scale='device')

async def main():
    outdir = sys.argv[1]
    async with async_playwright() as p:
        b = await p.chromium.launch()
        ctx = await b.new_context(device_scale_factor=2)
        page = await ctx.new_page()
        for bg, name in ((None, 'sanciones_transparente.png'), ('#14161A', 'sanciones_fondo_oscuro.png')):
            svg, sw, shh = sheet(bg)
            await render(page, svg, sw, shh, 2, f'{outdir}/{name}')
            if not bg: open(f'{outdir}/sanciones.svg', 'w').write(svg)
        for name, color, body in ICONS:
            await render(page, single(name, color, body), W, H, 2, f'{outdir}/{name}.png')
        for bg, name in ((None, 'banderas_transparente.png'), ('#14161A', 'banderas_fondo_oscuro.png')):
            svg, sw, shh = flag_sheet(bg)
            await render(page, svg, sw, shh, 2, f'{outdir}/{name}')
            if not bg: open(f'{outdir}/banderas.svg', 'w').write(svg)
        for name, kind in FLAGS:
            await render(page, flag_single(kind), W, H, 2, f'{outdir}/bandera_{name}.png')
        await b.close()

asyncio.run(main())

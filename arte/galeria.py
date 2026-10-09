"""Lamina con todas las senales del Comisario y su nombre (imagen del README).
Uso: python3 galeria.py carpeta_iconos carpeta_fuentes salida.png es|en"""
import base64, os, sys
from playwright.sync_api import sync_playwright
src, fonts, out, lang = sys.argv[1:5]
ITEMS = [('bandera_verde', 'Verde', 'Green'), ('bandera_amarilla', 'Amarilla', 'Yellow'),
         ('bandera_amarilla_total', 'Amarilla total', 'Full course yellow'), ('bandera_roja', 'Roja', 'Red'),
         ('bandera_azul', 'Azul', 'Blue'), ('bandera_blanca', 'Blanca', 'White'),
         ('bandera_cuadros', 'A cuadros', 'Chequered'), ('bandera_negra', 'Negra', 'Black'),
         ('aviso', 'Aviso', 'Warning'), ('tiempo', 'Tiempo', 'Time penalty'), ('levantar', 'Levantar el pie', 'Lift off'),
         ('drive_through', 'Drive-through', 'Drive-through'), ('stop_and_go', 'Stop and go', 'Stop and go'),
         ('devolver', 'Devolver la posición', 'Give the position back'), ('descalificado', 'Descalificado', 'Disqualified'),
         ('cumplida', 'Sanción cumplida', 'Penalty served')]
TITLE = {'es': 'BANDERAS Y SANCIONES', 'en': 'FLAGS AND PENALTIES'}[lang]
def b64(p): return base64.b64encode(open(p, 'rb').read()).decode()
face = ''.join("@font-face{font-family:BC;font-weight:%d;src:url(data:font/woff2;base64,%s)}" % (w, b64(os.path.join(fonts, 'barlow-condensed-latin-%d-normal.woff2' % w))) for w in (700, 800))
cells = ''.join('<div class="c"><img src="data:image/png;base64,%s"><span>%s</span></div>'
                % (b64(os.path.join(src, n + '.png')), es if lang == 'es' else en) for n, es, en in ITEMS)
html = f'''<!doctype html><html><head><style>{face}
body{{margin:0;background:transparent}}
#s{{width:1000px;padding:28px 30px 34px;box-sizing:border-box;border-radius:18px;
background:radial-gradient(ellipse at 50% 0%,#2b2e35,#121317 70%);font-family:BC;color:#f2f2ee}}
h1{{margin:0 0 18px;font-weight:800;font-size:34px;letter-spacing:4px;text-align:center}}
h1:after{{content:"";display:block;width:90px;height:5px;background:#D3141C;margin:10px auto 0;border-radius:3px}}
.g{{display:grid;grid-template-columns:repeat(4,1fr);gap:14px 10px}}
.c{{display:flex;flex-direction:column;align-items:center}}
.c img{{width:220px;height:151px}}
.c span{{font-weight:700;font-size:23px;letter-spacing:.5px;margin-top:2px}}
</style></head><body><div id="s"><h1>{TITLE}</h1><div class="g">{cells}</div></div></body></html>'''
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={'width': 1000, 'height': 1200})
    pg.set_content(html); pg.wait_for_timeout(200)
    pg.locator('#s').screenshot(path=out, omit_background=True); b.close()
print('ok', out)

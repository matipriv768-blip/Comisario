"""Dibuja la ventana de ajustes pestana por pestana, imitando la interfaz del juego, para revisar el diseno.

Uso: python3 test/preview_settings.py salida.png [es|en] [todas]
No es una captura del juego: los tamanos y la letra son aproximados. Sirve para ver el orden,
que nada se monte sobre otra cosa y que los nombres quepan en su columna.
"""
import re
import sys
from lupa import luajit21 as lj
from PIL import Image, ImageDraw, ImageFont

APP = 'pkg/apps/lua/Comisario/Comisario.lua'
REG = '/usr/share/fonts/opentype/inter/Inter-Regular.otf'
BOLD = '/usr/share/fonts/opentype/inter/Inter-Bold.otf'
SS = 2
FS = 13          # tamano de letra de la interfaz
TEXT_H = 17
FRAME_H = 23
GAP = 5
PAD = 10
WIN_W = 556
COL_TEXT = (235, 235, 235, 255)
COL_FRAME = (52, 56, 64, 255)
COL_ACCENT = (200, 40, 40, 255)

_fonts = {}


def font(bold=False, size=FS):
    key = (bold, size)
    if key not in _fonts:
        _fonts[key] = ImageFont.truetype(BOLD if bold else REG, size * SS)
    return _fonts[key]


def tw(text, bold=False):
    return font(bold).getlength(text) / SS


def rgba(c):
    a = c['mult'] if c['mult'] is not None else 1
    return (int(c['r'] * 255), int(c['g'] * 255), int(c['b'] * 255), int(max(0, min(1, a)) * 255))


class Panel:
    """Una ventana: lleva el cursor como lo hace la interfaz del juego y guarda lo que hay que dibujar."""

    def __init__(self, g, tab):
        self.g = g
        self.tab = tab
        self.tabs = []
        self.ops = []
        self.x, self.y = PAD, PAD
        self.line_h = 0
        self.last = (PAD, PAD, PAD, PAD)
        self.align = False
        self.next_w = None
        self.colors = []
        self.overlaps = []
        self.in_tab = True
        self.row_right = {}

    # --- colocacion -----------------------------------------------------
    def place(self, w, h, what=''):
        x, y = self.x, self.y
        # dos cosas en la misma linea no pueden pisarse
        key = round(y)
        if key in self.row_right and x < self.row_right[key] - 0.5:
            self.overlaps.append('%s (x=%d, lo anterior termina en %d)' % (what, x, self.row_right[key]))
        self.row_right[key] = max(self.row_right.get(key, 0), x + w)
        if x + w > WIN_W - PAD + 1:
            self.overlaps.append('%s se sale de la ventana (%d)' % (what, x + w))
        self.last = (x, y, x + w, y + h)
        self.line_h = max(self.line_h, h)
        self.cur_line_y = y
        # siguiente elemento: linea nueva
        self.x = PAD
        self.y = y + self.line_h + GAP
        self.pending_line_h = self.line_h
        self.line_h = 0
        return x, y

    def same_line(self, offset=0, spacing=None):
        x1, y1, x2, y2 = self.last
        self.y = y1
        self.line_h = self.pending_line_h
        if offset and offset > 0:
            self.x = offset
        else:
            self.x = x2 + (8 if spacing is None or spacing < 0 else spacing)

    def color(self):
        return self.colors[-1] if self.colors else COL_TEXT

    def visible(self):
        return self.in_tab

    # --- elementos --------------------------------------------------------
    def text(self, text, color=None, bold=False):
        text = str(text)
        h = FRAME_H if self.align else TEXT_H
        dy = (FRAME_H - TEXT_H) / 2 if self.align else 0
        self.align = False
        if not self.visible():
            return
        x, y = self.place(tw(text, bold), h, text[:30])
        self.ops.append(('text', x, y + dy, text, color or self.color(), bold))

    def wrapped(self, text):
        if not self.visible():
            return
        words, lines, cur = str(text).split(' '), [], ''
        width = WIN_W - PAD - self.x
        for w in words:
            t = (cur + ' ' + w).strip()
            if tw(t) > width and cur:
                lines.append(cur)
                cur = w
            else:
                cur = t
        lines.append(cur)
        for ln in lines:
            x, y = self.place(tw(ln), TEXT_H - GAP + 2, ln[:30])
            self.ops.append(('text', x, y, ln, self.color(), False))
        self.y += 3

    def frame_w(self):
        w = self.next_w if self.next_w else 200
        self.next_w = None
        return w

    def checkbox(self, label, value):
        if self.visible():
            label = str(label)
            x, y = self.place(FRAME_H + 6 + tw(label), FRAME_H, label[:30])
            self.ops.append(('check', x, y, bool(value)))
            self.ops.append(('text', x + FRAME_H + 6, y + 3, label, COL_TEXT, False))
        return False

    def radio(self, label, value):
        if self.visible():
            label = str(label).split('##')[0]
            x, y = self.place(FRAME_H + 5 + tw(label), FRAME_H, label[:30])
            self.ops.append(('radio', x, y, bool(value)))
            self.ops.append(('text', x + FRAME_H + 5, y + 3, label, COL_TEXT, False))
        return False

    def slider(self, label, value, lo, hi, fmt='%.3f', *rest):
        w = self.frame_w()
        if self.visible():
            x, y = self.place(w, FRAME_H, 'deslizador ' + str(label))
            shown = re.sub(r'%%', '%', re.sub(r'%[-+ 0#]*\d*(?:\.\d+)?f', lambda m: m.group(0) % value, str(fmt)))
            self.ops.append(('slider', x, y, w, (value - lo) / (hi - lo) if hi > lo else 0, shown))
        return value

    def combo(self, label, preview, *rest):
        w = self.frame_w()
        if self.visible():
            x, y = self.place(w, FRAME_H, 'lista ' + str(label))
            self.ops.append(('combo', x, y, w, str(preview)))

    def button(self, label):
        if self.visible():
            label = str(label)
            x, y = self.place(tw(label) + 16, FRAME_H, label[:30])
            self.ops.append(('button', x, y, tw(label) + 16, label))
        return False

    def input(self, label, text, flags=None):
        w = self.frame_w()
        if self.visible():
            x, y = self.place(w, FRAME_H, 'campo ' + str(label))
            self.ops.append(('input', x, y, w, '•' * len(str(text))))
        return text, False

    def header(self, text):
        if not self.visible():
            return
        self.y += 2
        x, y = self.place(WIN_W - 2 * PAD, TEXT_H + 4, str(text)[:30])
        self.ops.append(('header', x, y, str(text)))

    def bullet(self, text):
        if not self.visible():
            return
        x, y = self.place(14 + tw(str(text)), TEXT_H, str(text)[:30])
        self.ops.append(('bullet', x, y))
        self.ops.append(('text', x + 14, y, str(text), self.color(), False))

    def tab_item(self, label, fn):
        self.tabs.append(str(label).split('###')[0])
        self.in_tab = len(self.tabs) == self.tab
        if self.in_tab:
            fn()
        self.in_tab = False

    def tab_bar(self, id_, fn):
        x, y = self.place(WIN_W - 2 * PAD, FRAME_H + 2, 'pestanas')
        self.ops.append(('tabs', x, y))
        saved = (self.x, self.y)
        self.in_tab = False
        fn()
        self.in_tab = True

    # --- dibujo -------------------------------------------------------------
    def render(self):
        height = int(self.y + PAD)
        img = Image.new('RGBA', (WIN_W * SS, height * SS), (26, 28, 33, 255))
        d = ImageDraw.Draw(img)
        S = lambda v: int(round(v * SS))

        def draw_text(x, y, text, color=COL_TEXT, bold=False):
            d.text((S(x), S(y)), text, font=font(bold), fill=color)

        for op in self.ops:
            kind = op[0]
            if kind == 'text':
                draw_text(op[1], op[2], op[3], op[4], op[5])
            elif kind == 'check':
                _, x, y, on = op
                d.rounded_rectangle([S(x), S(y), S(x + FRAME_H), S(y + FRAME_H)], S(3), fill=COL_FRAME)
                if on:
                    d.line([S(x + 5), S(y + 12), S(x + 10), S(y + 17), S(x + 18), S(y + 6)], fill=(240, 240, 240, 255), width=S(2.2))
            elif kind == 'radio':
                _, x, y, on = op
                d.ellipse([S(x), S(y), S(x + FRAME_H), S(y + FRAME_H)], fill=COL_FRAME)
                if on:
                    d.ellipse([S(x + 6), S(y + 6), S(x + FRAME_H - 6), S(y + FRAME_H - 6)], fill=(240, 240, 240, 255))
            elif kind == 'slider':
                _, x, y, w, t, shown = op
                d.rounded_rectangle([S(x), S(y), S(x + w), S(y + FRAME_H)], S(3), fill=COL_FRAME)
                gx = x + 2 + (w - 14) * max(0, min(1, t))
                d.rounded_rectangle([S(gx), S(y + 2), S(gx + 10), S(y + FRAME_H - 2)], S(2), fill=COL_ACCENT)
                draw_text(x + (w - tw(shown)) / 2, y + 3, shown)
            elif kind == 'combo':
                _, x, y, w, preview = op
                d.rounded_rectangle([S(x), S(y), S(x + w), S(y + FRAME_H)], S(3), fill=COL_FRAME)
                d.rounded_rectangle([S(x + w - FRAME_H), S(y), S(x + w), S(y + FRAME_H)], S(3), fill=(76, 82, 94, 255))
                ax, ay = x + w - FRAME_H / 2, y + FRAME_H / 2
                d.polygon([S(ax - 4), S(ay - 2), S(ax + 4), S(ay - 2), S(ax), S(ay + 4)], fill=(230, 230, 230, 255))
                draw_text(x + 6, y + 3, preview)
            elif kind == 'button':
                _, x, y, w, label = op
                d.rounded_rectangle([S(x), S(y), S(x + w), S(y + FRAME_H)], S(3), fill=(74, 80, 92, 255))
                draw_text(x + 8, y + 3, label)
            elif kind == 'input':
                _, x, y, w, dots = op
                d.rounded_rectangle([S(x), S(y), S(x + w), S(y + FRAME_H)], S(3), fill=COL_FRAME)
                draw_text(x + 6, y + 3, dots)
            elif kind == 'header':
                _, x, y, text = op
                draw_text(x, y, text, (255, 255, 255, 255), True)
                d.line([S(x), S(y + TEXT_H + 3), S(WIN_W - PAD), S(y + TEXT_H + 3)], fill=(255, 255, 255, 50), width=S(1))
            elif kind == 'bullet':
                _, x, y = op
                d.ellipse([S(x + 3), S(y + 6), S(x + 8), S(y + 11)], fill=(200, 200, 200, 255))
            elif kind == 'tabs':
                _, x, y = op
                cx = x
                for n, name in enumerate(self.tabs, 1):
                    w = tw(name) + 14
                    active = n == self.tab
                    d.rounded_rectangle([S(cx), S(y), S(cx + w), S(y + FRAME_H + 2)], S(3), fill=COL_ACCENT if active else (44, 47, 54, 255))
                    draw_text(cx + 7, y + 4, name, COL_TEXT if active else (190, 190, 190, 255))
                    cx += w + 2
                if cx > WIN_W - PAD + 1:
                    self.overlaps.append('las pestanas no caben en una fila (%d de %d)' % (cx, WIN_W - PAD))
        return img.resize((WIN_W, height), Image.LANCZOS)


def build(lang, show_all, tab, setup=''):
    lua = lj.LuaRuntime(unpack_returned_tuples=True)
    lua.execute("STORED = { lang = %d, setAll = %s }" % (2 if lang == 'en' else 1, 'true' if show_all else 'false'))
    lua.execute("FRESH_INSTALL = true")
    lua.execute("local f = assert(loadfile('test/harness.lua')); f('%s')" % APP)
    g = lua.globals()
    ui = g.ui
    p = Panel(g, tab)
    ui.text = lambda t: p.text(t)
    ui.textColored = lambda t, c: p.text(t, rgba(c))
    ui.textWrapped = lambda t: p.wrapped(t)
    ui.bulletText = lambda t: p.bullet(t)
    ui.header = lambda t: p.header(t)
    ui.sameLine = lambda offset=0, spacing=None: p.same_line(offset or 0, spacing)
    ui.setCursorX = lambda x: setattr(p, 'x', x)
    ui.alignTextToFramePadding = lambda: setattr(p, 'align', True)
    ui.offsetCursorY = lambda v: setattr(p, 'y', p.y + v)
    ui.dummy = lambda v: None
    ui.setNextItemWidth = lambda w: setattr(p, 'next_w', w)
    ui.checkbox = lambda label, value: p.checkbox(label, value)
    ui.radioButton = lambda label, value: p.radio(label, value)
    ui.slider = lambda label, value, lo, hi, fmt='%.3f', *r: p.slider(label, value, lo, hi, fmt)
    ui.combo = lambda label, preview, *r: p.combo(label, preview)
    ui.button = lambda label: p.button(label)
    ui.inputText = lambda label, text, flags=None: p.input(label, text, flags)
    ui.tabBar = lambda id_, fn: p.tab_bar(id_, fn)
    ui.tabItem = lambda label, fn: p.tab_item(label, fn)
    ui.pushStyleColor = lambda which, c: p.colors.append(rgba(c))
    ui.popStyleColor = lambda *a: p.colors.pop() if p.colors else None
    ui.measureText = lambda t, *a: g.vec2(tw(str(t)), TEXT_H)
    ui.itemHovered = lambda *a: False
    ui.setTooltip = lambda t: None
    ui.separator = lambda: setattr(p, 'y', p.y + 4)
    if setup:
        lua.execute(setup)
    lua.execute('script.update(0.016)')
    g.script.windowSettings(0.016)
    return p


def main():
    out = sys.argv[1]
    lang = sys.argv[2] if len(sys.argv) > 2 else 'es'
    show_all = len(sys.argv) > 3 and sys.argv[3] == 'todas'
    tabs = [int(t) for t in sys.argv[4].split(',')] if len(sys.argv) > 4 else list(range(1, 10))
    panels, problems = [], []
    for tab in tabs:
        p = build(lang, show_all, tab, 'T.cfg.startMode = 2')
        panels.append(p.render())
        for o in p.overlaps:
            problems.append('pestana %d: %s' % (tab, o))
    cols = 3 if len(panels) > 4 else len(panels)
    rows = [panels[i:i + cols] for i in range(0, len(panels), cols)]
    gap = 14
    width = cols * WIN_W + (cols + 1) * gap
    height = gap + sum(max(im.height for im in r) + gap for r in rows)
    sheet = Image.new('RGB', (width, height), (12, 13, 16))
    y = gap
    for r in rows:
        x = gap
        for im in r:
            sheet.paste(im.convert('RGB'), (x, y))
            x += WIN_W + gap
        y += max(im.height for im in r) + gap
    sheet.save(out)
    print('%s: %d pestanas, %d problemas de espacio' % (out, len(panels), len(problems)))
    for pr in problems:
        print('  ' + pr)
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())

"""Genera los tamanos chicos de cada icono (carpetas img/48, img/80 e img/160) a partir de los grandes.

La app dibuja cada icono con la imagen del tamano mas cercano al que ocupa en pantalla: achicar mucho
una imagen grande al dibujarla la deja dentada.

Uso: python3 arte/reducir_iconos.py carpeta_con_los_png_grandes apps/lua/Comisario/img
"""
import glob
import os
import sys

from PIL import Image, ImageFilter

SIZES = {'48': (48, 33), '80': (80, 55), '160': (160, 110)}


def main(src, dst):
    names = [os.path.basename(f)[:-4] for f in glob.glob(os.path.join(dst, '*.png'))]
    names = [n for n in names if n != 'logo']
    for folder, (w, h) in SIZES.items():
        os.makedirs(os.path.join(dst, folder), exist_ok=True)
        for name in names:
            big = Image.open(os.path.join(src, name + '.png')).convert('RGBA')
            small = big.resize((w, h), Image.LANCZOS, reducing_gap=3.0)
            if w <= 80:
                small = small.filter(ImageFilter.UnsharpMask(radius=0.6, percent=60, threshold=0))
            small.save(os.path.join(dst, folder, name + '.png'), optimize=True)
    print('%d iconos en %d tamanos' % (len(names), len(SIZES)))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])

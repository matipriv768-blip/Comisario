"""Revisa las traducciones: cada texto dentro de tr() o N_() tiene su linea en ingles, con los mismos huecos (%s, %d...)."""
import re
import sys

src = open(sys.argv[1], encoding='utf-8').read()
STR = r"'((?:[^'\\]|\\.)*)'"
VAL = r"(?:'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\")"
keys = []
for m in re.finditer(r"\b(?:tr|N_)\(\s*" + STR, src):
    if m.group(1) not in keys:
        keys.append(m.group(1))
en = {}
for m in re.finditer(r"^EN\[" + STR + r"\] = " + VAL + r"\s*$", src, re.M):
    if m.group(1) in en:
        print('REPETIDA  ' + m.group(1))
    en[m.group(1)] = m.group(2) if m.group(2) is not None else m.group(3)
lines = len(re.findall(r"^EN\[", src, re.M))
bad = 0
if lines != len(en):
    print('Hay %d lineas EN[...] y solo se pudieron leer %d' % (lines, len(en)))
    bad += 1
spec = lambda t: re.findall(r'%[-+ 0#]*\d*(?:\.\d+)?[sdfx%]', t)
for k in keys:
    if k not in en:
        print('FALTA     ' + k)
        bad += 1
    elif spec(k) != spec(en[k]):
        print('HUECOS    %s  ->  %s' % (k, en[k]))
        bad += 1
    elif re.search('[áéíóúñÁÉÍÓÚÑ¿¡]', en[k]):
        print('TILDES    %s  ->  %s' % (k, en[k]))
        bad += 1
for k in en:
    if k not in keys:
        print('SOBRA     ' + k)
        bad += 1
print('%d textos, %d traducciones, %d problemas' % (len(keys), len(en), bad))
sys.exit(1 if bad else 0)

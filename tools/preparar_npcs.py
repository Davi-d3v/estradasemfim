#!/usr/bin/env python3
"""Prepara os avatares Rocketbox (Microsoft, MIT) para o jogo: converte as texturas TGA
(2048) em JPG/PNG menores e "suja" as roupas para combinar com o mundo pós-apocalíptico
do protagonista (dessatura, escurece, manchas de terra e graxa, poeira na barra).

Uso: python3 -I preparar_npcs.py pasta_rocketbox/Assets/Avatars saida_assets/npcs Nome1 Nome2 ...
"""
import os, sys, glob, shutil
import numpy as np
from PIL import Image, ImageFilter

def ruido(forma, escala, semente):
    r = np.random.default_rng(semente)
    h, w = forma
    im = Image.fromarray((r.random((max(2, h // escala), max(2, w // escala))) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(im).astype(np.float32) / 255.0

def sujar(img, forca, semente):
    a = np.asarray(img.convert('RGB')).astype(np.float32) / 255.0
    lado = a.shape[:2]
    cinza = a.mean(axis=2, keepdims=True)
    a = a * (1 - 0.28 * forca) + cinza * 0.28 * forca          # dessatura
    a *= 1.0 - 0.14 * forca                                       # escurece
    # manchas de terra (marrom quente, não cinza) e marcas menores de graxa
    m1 = ruido(lado, 40, semente) * 0.6 + ruido(lado, 12, semente + 1) * 0.4
    m1 = np.clip((m1 - 0.52) * 2.4, 0, 1)[..., None] * forca
    terra = np.array([0.80, 0.68, 0.52], np.float32)
    a = a * (1 - m1 * 0.6) + a * terra * m1 * 0.6
    m2 = np.clip((ruido(lado, 18, semente + 2) - 0.72) * 3.0, 0, 1)[..., None] * forca
    graxa = np.array([0.62, 0.58, 0.52], np.float32)
    a = a * (1 - m2 * 0.35) + a * graxa * m2 * 0.35
    # poeira fina geral
    g = ruido(lado, 2, semente + 3)[..., None]
    a = a * (0.92 + 0.08 * g)
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))

def main():
    base, saida = sys.argv[1], sys.argv[2]
    for i, nome in enumerate(sys.argv[3:]):
        pasta = None
        for grupo in ('Professions', 'Adults', 'Children'):
            if os.path.isdir(os.path.join(base, grupo, nome)):
                pasta = os.path.join(base, grupo, nome)
        if pasta is None:
            print('não achei', nome); continue
        dst = os.path.join(saida, nome)
        os.makedirs(dst, exist_ok=True)
        tex = glob.glob(os.path.join(pasta, 'Textures', '*.tga'))
        def achar(fim):
            for t in tex:
                if t.lower().endswith(fim):
                    return t
        for c in tex:
            b = os.path.basename(c).lower()[:-4]
            if '_color' not in b:
                continue
            parte = b.split('_', 1)[1].split('_color')[0]          # m111_helmet_color_acu -> helmet
            n = achar(parte + '_normal.tga')
            if parte == 'opacity':
                im = Image.open(c).convert('RGBA'); im.thumbnail((512, 512), Image.LANCZOS)
                im.save(os.path.join(dst, 'opacity.png'), optimize=True)
                continue
            forca = {'head': 0.35, 'pistol': 0.5, 'combat_knife': 0.5, 'stetoskop': 0.4}.get(parte, 1.0)
            im = Image.open(c).convert('RGB'); im.thumbnail((1024 if parte in ('body', 'head') else 512,) * 2, Image.LANCZOS)
            sujar(im, forca, 1000 + i * 7 + len(parte)).save(os.path.join(dst, parte + '.jpg'), quality=86)
            if n:
                im = Image.open(n).convert('RGB'); im.thumbnail((512, 512), Image.LANCZOS)
                im.save(os.path.join(dst, parte + '_n.jpg'), quality=92)
        shutil.copy(os.path.join(pasta, 'Export', nome + '.fbx'), os.path.join(saida, '..', '..', 'tools', '_fbx_' + nome + '.fbx') if False else os.path.join('/tmp/claude-0/fbx', nome + '.fbx'))
        print(nome, sorted(os.listdir(dst)))

if __name__ == '__main__':
    os.makedirs('/tmp/claude-0/fbx', exist_ok=True)
    main()

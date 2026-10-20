#!/usr/bin/env python3
"""Encolhe um .glb para o jogo: reduz as texturas embutidas (lado máximo em px) e
regrava o arquivo. Cor/rugosidade viram JPEG (PNG se tiver transparência de verdade),
normal map continua PNG-8 bits RGB->JPEG de alta qualidade.

Uso: python3 -I encolher_glb.py entrada.glb saida.glb [lado_max=512]
"""
import json, struct, sys, io
from PIL import Image

def ler_glb(caminho):
    d = open(caminho, 'rb').read()
    assert d[:4] == b'glTF', 'não é glb'
    i = 12
    js = None
    binario = b''
    while i < len(d):
        n, tipo = struct.unpack_from('<I4s', d, i)
        corpo = d[i + 8:i + 8 + n]
        if tipo == b'JSON':
            js = json.loads(corpo)
        elif tipo == b'BIN\0':
            binario = corpo
        i += 8 + n
    return js, binario

def gravar_glb(caminho, js, binario):
    j = json.dumps(js, separators=(',', ':')).encode()
    j += b' ' * ((4 - len(j) % 4) % 4)
    binario += b'\0' * ((4 - len(binario) % 4) % 4)
    total = 12 + 8 + len(j) + 8 + len(binario)
    with open(caminho, 'wb') as f:
        f.write(struct.pack('<4sII', b'glTF', 2, total))
        f.write(struct.pack('<I4s', len(j), b'JSON')); f.write(j)
        f.write(struct.pack('<I4s', len(binario), b'BIN\0')); f.write(binario)

def papel_das_imagens(js):
    """quais imagens são normal map e quais são usadas com transparência"""
    normal, alfa = set(), set()
    tex = js.get('textures', [])
    def img_de(t):
        if t is None: return None
        tx = tex[t['index']]
        return tx.get('source', (tx.get('extensions', {}).get('KHR_texture_basisu', {}) or {}).get('source'))
    for m in js.get('materials', []):
        if 'normalTexture' in m:
            normal.add(img_de(m['normalTexture']))
        pbr = m.get('pbrMetallicRoughness', {})
        if m.get('alphaMode', 'OPAQUE') != 'OPAQUE' and 'baseColorTexture' in pbr:
            alfa.add(img_de(pbr['baseColorTexture']))
    return normal, alfa

def encolher(entrada, saida, lado=512):
    js, binario = ler_glb(entrada)
    normal, alfa = papel_das_imagens(js)
    views = js.get('bufferViews', [])
    pedacos = {}       # bufferView -> bytes novos
    for k, im in enumerate(js.get('images', [])):
        if 'bufferView' not in im:
            continue
        bv = views[im['bufferView']]
        raw = binario[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]
        try:
            img = Image.open(io.BytesIO(raw))
            img.load()
        except Exception as ex:
            print('  imagem %d não abriu (%s), mantida' % (k, ex))
            continue
        w, h = img.size
        if max(w, h) > lado:
            f = lado / max(w, h)
            img = img.resize((max(4, int(w * f)), max(4, int(h * f))), Image.LANCZOS)
        buf = io.BytesIO()
        tem_alfa = img.mode in ('RGBA', 'LA', 'P') and k in alfa
        if tem_alfa:
            img.convert('RGBA').save(buf, 'PNG', optimize=True)
            im['mimeType'] = 'image/png'
        else:
            img.convert('RGB').save(buf, 'JPEG', quality=92 if k in normal else 85)
            im['mimeType'] = 'image/jpeg'
        pedacos[im['bufferView']] = buf.getvalue()
    # remonta o buffer binário com os pedaços novos, mantendo o resto
    novo = bytearray()
    for i, bv in enumerate(views):
        if bv.get('buffer', 0) != 0:
            continue
        dados = pedacos.get(i)
        if dados is None:
            o = bv.get('byteOffset', 0)
            dados = binario[o:o + bv['byteLength']]
        while len(novo) % 4:
            novo += b'\0'
        bv['byteOffset'] = len(novo)
        bv['byteLength'] = len(dados)
        novo += dados
    js['buffers'][0]['byteLength'] = len(novo)
    gravar_glb(saida, js, bytes(novo))

if __name__ == '__main__':
    encolher(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 512)
    import os
    print('%s: %.1f MB -> %.1f MB' % (os.path.basename(sys.argv[1]), os.path.getsize(sys.argv[1]) / 1e6, os.path.getsize(sys.argv[2]) / 1e6))

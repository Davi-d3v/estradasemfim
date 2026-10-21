#!/usr/bin/env python3
"""Reduz um scan pesado (.glb com milhões de triângulos) por agrupamento de vértices numa
grade: junta todas as malhas (com a transformação dos nós), funde vértices da mesma célula
(sem misturar UVs muito diferentes, para não borrar as costuras da textura), descarta
triângulos degenerados e grava um .glb com uma malha só e a textura reduzida.

Uso: python3 -I reduzir_scan.py entrada.glb saida.glb [celula_m=0.05] [lado_textura=1024]
"""
import io, json, struct, sys
import numpy as np
from PIL import Image

TIPOS = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
COMP = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}


def ler(caminho):
    d = open(caminho, 'rb').read()
    i, js, binario = 12, None, b''
    while i < len(d):
        n, tipo = struct.unpack_from('<I4s', d, i)
        if tipo == b'JSON':
            js = json.loads(d[i + 8:i + 8 + n])
        elif tipo == b'BIN\0':
            binario = d[i + 8:i + 8 + n]
        i += 8 + n
    return js, binario


def acessor(js, binario, k):
    a = js['accessors'][k]
    bv = js['bufferViews'][a['bufferView']]
    o = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    c = COMP[a['type']]
    arr = np.frombuffer(binario, TIPOS[a['componentType']], a['count'] * c, o)
    return arr.reshape(-1, c) if c > 1 else arr


def matriz(no):
    if 'matrix' in no:
        return np.array(no['matrix'], dtype=np.float64).reshape(4, 4).T
    m = np.eye(4)
    if 'scale' in no:
        m = np.diag(list(no['scale']) + [1.0]) @ m
    if 'rotation' in no:
        x, y, z, w = no['rotation']
        r = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                      [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                      [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
        rr = np.eye(4); rr[:3, :3] = r
        m = rr @ m
    if 'translation' in no:
        t = np.eye(4); t[:3, 3] = no['translation']
        m = t @ m
    return m


def juntar(js, binario):
    pos, uv, ind = [], [], []
    base = 0

    def visitar(k, pai):
        nonlocal base
        no = js['nodes'][k]
        m = pai @ matriz(no)
        if 'mesh' in no:
            for p in js['meshes'][no['mesh']]['primitives']:
                v = acessor(js, binario, p['attributes']['POSITION']).astype(np.float64)
                v = (np.c_[v, np.ones(len(v))] @ m.T)[:, :3]
                t = acessor(js, binario, p['attributes']['TEXCOORD_0']).astype(np.float64)
                i = acessor(js, binario, p['indices']).astype(np.int64)
                pos.append(v); uv.append(t); ind.append(i + base)
                base += len(v)
        for c in no.get('children', []):
            visitar(c, m)

    for r in js['scenes'][js.get('scene', 0)]['nodes']:
        visitar(r, np.eye(4))
    return np.concatenate(pos), np.concatenate(uv), np.concatenate(ind).reshape(-1, 3)


def reduzir(pos, uv, tri, cel):
    q = np.floor(pos / cel).astype(np.int64)
    qu = np.floor(uv / 0.05).astype(np.int64)        # células de UV: não funde lados de uma costura
    chave = np.c_[q, qu]
    _, novo, conta = np.unique(chave, axis=0, return_inverse=True, return_counts=True)
    novo = novo.reshape(-1)
    n = conta.size
    p2 = np.zeros((n, 3)); u2 = np.zeros((n, 2))
    np.add.at(p2, novo, pos); np.add.at(u2, novo, uv)
    p2 /= conta[:, None]; u2 /= conta[:, None]
    t2 = novo[tri]
    ok = (t2[:, 0] != t2[:, 1]) & (t2[:, 1] != t2[:, 2]) & (t2[:, 0] != t2[:, 2])
    t2 = t2[ok]
    t2 = np.unique(np.sort(t2, axis=1), axis=0, return_index=True)[1]
    t2 = novo[tri][ok][np.sort(t2)]
    # normais suaves
    a, b, c = p2[t2[:, 0]], p2[t2[:, 1]], p2[t2[:, 2]]
    fn = np.cross(b - a, c - a)
    nm = np.zeros_like(p2)
    for k in range(3):
        np.add.at(nm, t2[:, k], fn)
    nm /= np.maximum(np.linalg.norm(nm, axis=1), 1e-12)[:, None]
    return p2, u2, nm, t2


def gravar(caminho, pos, uv, nm, tri, jpeg, autoria):
    usados = np.unique(tri)
    remap = np.full(len(pos), -1, np.int64); remap[usados] = np.arange(len(usados))
    pos, uv, nm, tri = pos[usados], uv[usados], nm[usados], remap[tri]
    # gira em Y para o lado comprido ficar no eixo X (análise de componentes no chão)
    xz = pos[:, [0, 2]] - pos[:, [0, 2]].mean(0)
    w, v = np.linalg.eigh(xz.T @ xz)
    eixo = v[:, np.argmax(w)]
    a = np.arctan2(eixo[1], eixo[0])
    c, s_ = np.cos(a), np.sin(a)
    r = np.array([[c, 0, s_], [0, 1, 0], [-s_, 0, c]])
    pos = pos @ r.T
    nm = nm @ r.T
    pos -= np.r_[(pos[:, 0].min() + pos[:, 0].max()) / 2, pos[:, 1].min(), (pos[:, 2].min() + pos[:, 2].max()) / 2]
    partes = [pos.astype(np.float32).tobytes(), nm.astype(np.float32).tobytes(), uv.astype(np.float32).tobytes(),
              tri.astype(np.uint32).tobytes(), jpeg]
    bvs, buf = [], b''
    for p in partes:
        buf += b'\0' * ((4 - len(buf) % 4) % 4)
        bvs.append({'buffer': 0, 'byteOffset': len(buf), 'byteLength': len(p)})
        buf += p
    js = {
        'asset': {'version': '2.0', 'generator': 'reduzir_scan.py', 'extras': autoria},
        'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [{'mesh': 0, 'name': 'muro_carros'}],
        'meshes': [{'primitives': [{'attributes': {'POSITION': 0, 'NORMAL': 1, 'TEXCOORD_0': 2}, 'indices': 3, 'material': 0}]}],
        'materials': [{'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}, 'baseColorFactor': [0.5, 0.48, 0.46, 1.0], 'metallicFactor': 0.0, 'roughnessFactor': 0.9}, 'doubleSided': True}],
        'textures': [{'source': 0}], 'images': [{'bufferView': 4, 'mimeType': 'image/jpeg'}],
        'accessors': [
            {'bufferView': 0, 'componentType': 5126, 'count': len(pos), 'type': 'VEC3', 'min': pos.min(0).tolist(), 'max': pos.max(0).tolist()},
            {'bufferView': 1, 'componentType': 5126, 'count': len(pos), 'type': 'VEC3'},
            {'bufferView': 2, 'componentType': 5126, 'count': len(pos), 'type': 'VEC2'},
            {'bufferView': 3, 'componentType': 5125, 'count': tri.size, 'type': 'SCALAR'},
        ],
        'bufferViews': bvs, 'buffers': [{'byteLength': len(buf)}],
    }
    j = json.dumps(js, separators=(',', ':')).encode(); j += b' ' * ((4 - len(j) % 4) % 4)
    buf += b'\0' * ((4 - len(buf) % 4) % 4)
    with open(caminho, 'wb') as f:
        f.write(struct.pack('<4sII', b'glTF', 2, 12 + 16 + len(j) + len(buf)))
        f.write(struct.pack('<I4s', len(j), b'JSON')); f.write(j)
        f.write(struct.pack('<I4s', len(buf), b'BIN\0')); f.write(buf)
    return len(tri), pos.max(0) - pos.min(0)


if __name__ == '__main__':
    ent, sai = sys.argv[1], sys.argv[2]
    cel = float(sys.argv[3]) if len(sys.argv) > 3 else 0.05
    lado = int(sys.argv[4]) if len(sys.argv) > 4 else 1024
    js, binario = ler(ent)
    pos, uv, tri = juntar(js, binario)
    print('original: %d triângulos' % len(tri))
    p2, u2, nm, t2 = reduzir(pos, uv, tri, cel)
    bv = js['bufferViews'][js['images'][0]['bufferView']]
    img = Image.open(io.BytesIO(binario[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]))
    img.thumbnail((lado, lado), Image.LANCZOS)
    b = io.BytesIO(); img.convert('RGB').save(b, 'JPEG', quality=85)
    n, tam = gravar(sai, p2, u2, nm, t2, b.getvalue(), js['asset'].get('extras', {}))
    print('reduzido: %d triângulos, tamanho %s' % (n, np.round(tam, 2)))

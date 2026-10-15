#!/usr/bin/env python3
"""Reduz árvores/plantas da Poly Haven (glTF ou .obj vindo de blend_para_obj.py) para o jogo.

Folhagem (agulhas, folhas, cartões) é feita de milhares de pedacinhos soltos; o simplificador
comum não junta pedaços soltos, então aqui sorteamos pedaços inteiros (componentes conexos)
até caber no orçamento de triângulos e aumentamos um pouco cada pedaço mantido para a copa
não ficar rala. Tronco/casca passa direto (o Godot simplifica depois em montar_arvores.gd).

Uso:
  reduzir_arvore.py entrada.gltf saida_dir  [orcamento_folhagem]
  reduzir_arvore.py entrada.obj  saida.obj  orcamento   (um .obj só = folhagem)
Gera <saida_dir>/<no>__<material>.obj, com a malha centrada na origem (sem a translação
que o arquivo usa para enfileirar as variantes).
"""
import json, struct, sys, os, random
import numpy as np

FOLHAGEM = ('twig', 'leaves', 'leaf', 'needle', 'didelta', 'spinosa')

def eh_folhagem(nome):
    n = nome.lower()
    return any(k in n for k in FOLHAGEM)

def ler_gltf(caminho):
    g = json.load(open(caminho))
    base = os.path.dirname(caminho)
    bufs = [open(os.path.join(base, b['uri']), 'rb').read() for b in g['buffers']]
    def acc(i):
        a = g['accessors'][i]; bv = g['bufferViews'][a['bufferView']]
        tipo = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}[a['componentType']]
        nc = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
        off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
        passo = bv.get('byteStride', 0)
        isz = np.dtype(tipo).itemsize * nc
        dados = bufs[bv['buffer']]
        if passo and passo != isz:
            arr = np.frombuffer(dados, dtype=np.uint8, count=passo * a['count'], offset=off).reshape(a['count'], passo)[:, :isz]
            return np.frombuffer(arr.tobytes(), dtype=tipo).reshape(a['count'], nc)
        return np.frombuffer(dados, dtype=tipo, count=a['count'] * nc, offset=off).reshape(a['count'], nc)
    saida = []
    for nd in g['nodes']:
        if 'mesh' not in nd:
            continue
        esc = np.array(nd.get('scale', [1, 1, 1]), dtype=np.float32)
        for p in g['meshes'][nd['mesh']]['primitives']:
            pos = acc(p['attributes']['POSITION']).astype(np.float32) * esc
            uv = acc(p['attributes']['TEXCOORD_0']).astype(np.float32) if 'TEXCOORD_0' in p['attributes'] else np.zeros((len(pos), 2), np.float32)
            idx = acc(p['indices']).astype(np.int64).reshape(-1, 3)
            mat = g['materials'][p['material']]['name']
            saida.append((nd['name'], mat, pos, uv, idx))
    return saida

def ler_obj(caminho):
    v, vt, f = [], [], []
    for l in open(caminho):
        if l.startswith('v '): v.append([float(x) for x in l.split()[1:4]])
        elif l.startswith('vt '): vt.append([float(x) for x in l.split()[1:3]])
        elif l.startswith('f '):
            ids = [int(t.split('/')[0]) - 1 for t in l.split()[1:]]
            for k in range(1, len(ids) - 1):
                f.append([ids[0], ids[k], ids[k + 1]])
    pos = np.array(v, np.float32); uv = np.array(vt, np.float32) if vt else np.zeros((len(v), 2), np.float32)
    # no .obj do blend_para_obj o v e o vt têm o mesmo índice; e uv do Blender tem v invertido
    uv = uv.copy(); uv[:, 1] = 1.0 - uv[:, 1]
    return pos, uv, np.array(f, np.int64)

def componentes(idx, nv):
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components
    a = np.concatenate([idx[:, 0], idx[:, 1]]); b = np.concatenate([idx[:, 1], idx[:, 2]])
    g = coo_matrix((np.ones(len(a), np.int8), (a, b)), shape=(nv, nv))
    _, rotulo = connected_components(g, directed=False)
    return rotulo[idx[:, 0]]

def reduzir_folhagem(pos, uv, idx, orcamento, semente=7):
    nt = len(idx)
    if nt <= orcamento:
        return pos, uv, idx
    comp = componentes(idx, len(pos))
    ordem = np.argsort(comp, kind='stable')
    cs, ini = np.unique(comp[ordem], return_index=True)
    fim = np.append(ini[1:], len(ordem))
    grupos = {int(c): ordem[a:b] for c, a, b in zip(cs, ini, fim)}
    ids = list(grupos.keys())
    random.Random(semente).shuffle(ids)
    manter = []; total = 0
    for c in ids:
        if total + len(grupos[c]) > orcamento and total > 0:
            continue
        manter.append(c); total += len(grupos[c])
        if total >= orcamento:
            break
    fator = min(1.9, max(1.0, (nt / max(total, 1)) ** 0.5 * 0.6))
    tris = np.concatenate([grupos[c] for c in manter])
    sel = idx[tris]
    # centro de cada pedaço (por vértice): média dos centróides dos triângulos do pedaço
    comp_t = comp[tris]
    cent_t = pos[sel].mean(axis=1)
    somas = {}
    for c in manter:
        m = comp_t == c
        somas[c] = cent_t[m].mean(axis=0)
    novo_pos = pos.copy()
    vs = sel.reshape(-1); cv = np.repeat(comp_t, 3)
    centros = np.array([somas[c] for c in cv])
    novo_pos[vs] = centros + (pos[vs] - centros) * fator
    return novo_pos, uv, sel

def gravar(caminho, pos, uv, idx):
    usados = np.unique(idx)
    mapa = -np.ones(len(pos), np.int64); mapa[usados] = np.arange(len(usados))
    with open(caminho, 'w') as f:
        for p in pos[usados]: f.write('v %.5f %.5f %.5f\n' % tuple(p))
        for t in uv[usados]: f.write('vt %.5f %.5f\n' % (t[0], 1.0 - t[1]))
        for t in mapa[idx] + 1: f.write('f %d/%d %d/%d %d/%d\n' % (t[0], t[0], t[1], t[1], t[2], t[2]))
    return len(idx)

if __name__ == '__main__':
    ent, sai = sys.argv[1], sys.argv[2]
    orc = int(sys.argv[3]) if len(sys.argv) > 3 else 6000
    if ent.endswith('.obj'):
        pos, uv, idx = ler_obj(ent)
        p2, u2, i2 = reduzir_folhagem(pos, uv, idx, orc)
        print(os.path.basename(sai), len(idx), '->', gravar(sai, p2, u2, i2))
    else:
        os.makedirs(sai, exist_ok=True)
        for no, mat, pos, uv, idx in ler_gltf(ent):
            if eh_folhagem(mat):
                pos, uv, idx = reduzir_folhagem(pos, uv, idx, orc)
            nome = '%s__%s.obj' % (no, mat)
            print(nome, gravar(os.path.join(sai, nome), pos, uv, idx), 'triângulos')

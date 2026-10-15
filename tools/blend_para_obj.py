#!/usr/bin/env python3
"""Lê malhas de arquivos .blend (Blender 2.9 a 4.4) SEM o Blender e grava .obj por material.

Uso: blend_para_obj.py arquivo.blend[.raw] pasta_saida
O .blend precisa estar descomprimido (zstd/gzip) — ver tools/descomprimir_blend.py.
Suporta: malha antiga (MVert/MLoop/MPoly/MLoopUV) e nova (atributos "position",
".corner_vert", "material_index", UV em CD_PROP_FLOAT2). Objetos com loc/rot/escala e pai.
"""
import struct, sys, os, math

class Blend:
    def __init__(self, d):
        self.d = d
        assert d[:7] == b'BLENDER', d[:12]
        self.ps = 8 if d[7:8] == b'-' else 4
        self.le = d[8:9] == b'v'
        self.e = '<' if self.le else '>'
        self.ver = int(d[9:12])
        self.blocks = []
        self.porptr = {}
        i = 12
        P = 'Q' if self.ps == 8 else 'I'
        hdr = struct.Struct(self.e + '4si' + P + 'ii')
        while i < len(d):
            code, ln, old, sdna, nr = hdr.unpack_from(d, i)
            i += hdr.size
            b = (code.rstrip(b'\0'), i, ln, old, sdna, nr)
            self.blocks.append(b)
            if old:
                self.porptr[old] = b
            if code == b'DNA1':
                self._dna(i)
            if code == b'ENDB':
                break
            i += ln

    def _dna(self, i):
        d, e = self.d, self.e
        assert d[i:i+4] == b'SDNA'
        ini = i
        i += 4
        def al(i): return ini + ((i - ini + 3) & ~3)
        assert d[i:i+4] == b'NAME'; i += 4
        n, = struct.unpack_from(e+'i', d, i); i += 4
        names = []
        for _ in range(n):
            j = d.index(b'\0', i); names.append(d[i:j].decode()); i = j + 1
        i = al(i); assert d[i:i+4] == b'TYPE'; i += 4
        n, = struct.unpack_from(e+'i', d, i); i += 4
        types = []
        for _ in range(n):
            j = d.index(b'\0', i); types.append(d[i:j].decode()); i = j + 1
        i = al(i); assert d[i:i+4] == b'TLEN'; i += 4
        tlen = list(struct.unpack_from(e+'%dh' % n, d, i)); i += 2 * n
        i = al(i); assert d[i:i+4] == b'STRC'; i += 4
        ns, = struct.unpack_from(e+'i', d, i); i += 4
        self.structs = []
        self.snome = {}
        for s in range(ns):
            t, nf = struct.unpack_from(e+'hh', d, i); i += 4
            campos = []
            off = 0
            for _ in range(nf):
                ft, fn = struct.unpack_from(e+'hh', d, i); i += 4
                nome = names[fn]
                tam = self._tam(nome, tlen[ft])
                campos.append((nome, types[ft], off, tam))
                off += tam
            self.structs.append((types[t], campos))
            self.snome[types[t]] = s
        self.types, self.tlen = types, tlen

    def _tam(self, nome, tl):
        mult = 1
        base = nome
        while '[' in base:
            a = base.index('['); b = base.index(']', a)
            mult *= int(base[a+1:b]); base = base[:a] + base[b+1:]
        if base.startswith('*') or base.startswith('(*'):
            return self.ps * mult
        return tl * mult

    def campo(self, sdna, nome_puro):
        for nome, tipo, off, tam in self.structs[sdna][1]:
            n = nome.lstrip('*').split('[')[0]
            if n == nome_puro:
                return nome, tipo, off, tam
        return None

    # leitura de campos de uma struct num endereço do arquivo
    def ler(self, sdna, base, nome, fmt=None):
        c = self.campo(sdna, nome)
        if c is None:
            return None
        nm, tipo, off, tam = c
        if nm.startswith('*'):
            return struct.unpack_from(self.e + ('Q' if self.ps == 8 else 'I'), self.d, base + off)[0]
        if fmt is None:
            fmt = {'int': 'i', 'short': 'h', 'float': 'f', 'char': 'b', 'uchar': 'B', 'int64_t': 'q', 'uint64_t': 'Q'}.get(tipo)
        if fmt is None:
            return (base + off, tipo)
        n = tam // struct.calcsize(fmt)
        v = struct.unpack_from(self.e + '%d%s' % (n, fmt), self.d, base + off)
        return v if n > 1 else v[0]

    def sub(self, sdna, base, nome):
        """endereço e sdna de uma struct embutida"""
        nm, tipo, off, tam = self.campo(sdna, nome)
        return base + off, self.snome[tipo]

    def bloco(self, ptr):
        return self.porptr.get(ptr)

    def nome_id(self, sdna, base):
        a, s = self.sub(sdna, base, 'id')
        nm, tipo, off, tam = self.campo(s, 'name')
        raw = self.d[a + off:a + off + tam]
        return raw.split(b'\0')[0].decode('utf8', 'replace')[2:]


def camadas(b, cd_addr, cd_sdna):
    """lista de (tipo, nome, ptr) das camadas de um CustomData"""
    ptr = b.ler(cd_sdna, cd_addr, 'layers')
    tot = b.ler(cd_sdna, cd_addr, 'totlayer')
    r = []
    if not ptr or not tot:
        return r
    blk = b.bloco(ptr)
    s = b.snome['CustomDataLayer']
    tam = b.tlen[b.types.index('CustomDataLayer')]
    for k in range(tot):
        base = blk[1] + k * tam
        tipo = b.ler(s, base, 'type')
        nm, _, off, t = b.campo(s, 'name')
        nome = b.d[base + off:base + off + t].split(b'\0')[0].decode()
        dados = b.ler(s, base, 'data')
        r.append((tipo, nome, dados))
    return r

def arr(b, ptr, fmt, n):
    blk = b.bloco(ptr)
    if blk is None:
        return None
    return struct.unpack_from(b.e + fmt * n, b.d, blk[1])


def malha(b, base, sdna):
    """(vertices, uvs por canto, faces=[ [cantos...] ], material por face, corner_vert)"""
    nv = b.ler(sdna, base, 'totvert') if b.campo(sdna, 'totvert') else b.ler(sdna, base, 'verts_num')
    nf = b.ler(sdna, base, 'totpoly') if b.campo(sdna, 'totpoly') else b.ler(sdna, base, 'faces_num')
    nl = b.ler(sdna, base, 'totloop') if b.campo(sdna, 'totloop') else b.ler(sdna, base, 'corners_num')
    vd = b.sub(sdna, base, 'vdata'); ld = b.sub(sdna, base, 'ldata'); pd = b.sub(sdna, base, 'pdata')
    lv, ll, lp = camadas(b, *vd), camadas(b, *ld), camadas(b, *pd)
    pos = None
    for t, n, p in lv:
        if n == 'position':
            v = arr(b, p, 'f', nv * 3); pos = [v[i*3:i*3+3] for i in range(nv)]
    if pos is None:
        mv = b.ler(sdna, base, 'mvert')
        blk = b.bloco(mv); s = blk[4]; tam = b.tlen[b.types.index(b.structs[s][0])]
        pos = [b.ler(s, blk[1] + i * tam, 'co') for i in range(nv)]
    cv = None; uv = None
    for t, n, p in ll:
        if n == '.corner_vert':
            cv = arr(b, p, 'i', nl)
        if t == 49 and uv is None and not n.startswith('.'):     # CD_PROP_FLOAT2
            u = arr(b, p, 'f', nl * 2); uv = [u[i*2:i*2+2] for i in range(nl)]
        if t == 16 and uv is None:                                  # CD_MLOOPUV antigo
            blk = b.bloco(p); s = blk[4]; tam = b.tlen[b.types.index(b.structs[s][0])]
            uv = [b.ler(s, blk[1] + i * tam, 'uv') for i in range(nl)]
    if cv is None:
        ml = b.ler(sdna, base, 'mloop'); blk = b.bloco(ml); s = blk[4]; tam = b.tlen[b.types.index(b.structs[s][0])]
        cv = [b.ler(s, blk[1] + i * tam, 'v') for i in range(nl)]
    faces = []; mats = [0] * nf
    fo = b.ler(sdna, base, 'face_offset_indices') if b.campo(sdna, 'face_offset_indices') else (b.ler(sdna, base, 'poly_offset_indices') if b.campo(sdna, 'poly_offset_indices') else None)
    if fo:
        o = arr(b, fo, 'i', nf + 1)
        faces = [(o[i], o[i+1] - o[i]) for i in range(nf)]
        for t, n, p in lp:
            if n == 'material_index':
                mats = list(arr(b, p, 'i', nf))
    else:
        mp = b.ler(sdna, base, 'mpoly'); blk = b.bloco(mp); s = blk[4]; tam = b.tlen[b.types.index(b.structs[s][0])]
        for i in range(nf):
            a = blk[1] + i * tam
            faces.append((b.ler(s, a, 'loopstart'), b.ler(s, a, 'totloop')))
            mats[i] = b.ler(s, a, 'mat_nr')
    nomes_mat = []
    mp = b.ler(sdna, base, 'mat'); tm = b.ler(sdna, base, 'totcol')
    if mp and tm:
        ps = arr(b, mp, 'Q' if b.ps == 8 else 'I', tm)
        for p in ps:
            blk = b.bloco(p)
            nomes_mat.append(b.nome_id(blk[4], blk[1]) if blk else 'sem')
    return pos, uv, faces, mats, cv, nomes_mat


def matriz_obj(b, base, s):
    loc = b.ler(s, base, 'loc'); rot = b.ler(s, base, 'rot'); esc = b.ler(s, base, 'scale') or b.ler(s, base, 'size')
    cx, sx = math.cos(rot[0]), math.sin(rot[0]); cy, sy = math.cos(rot[1]), math.sin(rot[1]); cz, sz = math.cos(rot[2]), math.sin(rot[2])
    # Euler XYZ do Blender: R = Rz * Ry * Rx
    R = [[cy*cz, sx*sy*cz - cx*sz, cx*sy*cz + sx*sz],
         [cy*sz, sx*sy*sz + cx*cz, cx*sy*sz - sx*cz],
         [-sy, sx*cy, cx*cy]]
    M = [[R[i][j] * esc[j] for j in range(3)] + [loc[i]] for i in range(3)] + [[0, 0, 0, 1]]
    par = b.ler(s, base, 'parent')
    if par:
        blk = b.bloco(par)
        if blk:
            P = matriz_obj(b, blk[1], blk[4])
            M = [[sum(P[i][k] * M[k][j] for k in range(4)) for j in range(4)] for i in range(4)]
    return M


def exportar(caminho, saida, so_listar=False, filtro=None):
    b = Blend(open(caminho, 'rb').read())
    os.makedirs(saida, exist_ok=True)
    so = b.snome['Object']
    por_mat = {}       # material -> [linhas v, vt, f]
    for blk in b.blocks:
        if blk[0] != b'OB' or blk[4] != so:
            continue
        base = blk[1]
        if b.ler(so, base, 'type') != 1:
            continue
        nome = b.nome_id(so, base)
        dp = b.ler(so, base, 'data'); mb = b.bloco(dp)
        if not mb:
            continue
        if so_listar:
            ms = mb[4]
            nv = b.ler(ms, mb[1], 'totvert') if b.campo(ms, 'totvert') else b.ler(ms, mb[1], 'verts_num')
            print('  objeto %s: %d vértices, loc %s' % (nome, nv, [round(x, 2) for x in b.ler(so, base, 'loc')]))
            continue
        if filtro and nome not in filtro:
            continue
        try:
            pos, uv, faces, mats, cv, nmats = malha(b, mb[1], mb[4])
        except Exception as ex:
            print('  falhou', nome, ex); continue
        M = matriz_obj(b, base, so)
        if not os.environ.get('MANTER_LOC'):
            for i in range(3):
                M[i][3] = 0.0      # cada objeto centrado na origem (o arquivo espalha as variantes lado a lado)
        print('  objeto %s: %d vértices, %d faces, materiais %s' % (nome, len(pos), len(faces), nmats))
        for fi, (ini, n) in enumerate(faces):
            mn = nmats[mats[fi]] if mats[fi] < len(nmats) else (nmats[0] if nmats else 'sem')
            g = por_mat.setdefault(nome + '__' + mn, {'v': [], 'vt': [], 'f': []})
            idx = []
            for c in range(ini, ini + n):
                p = pos[cv[c]]
                x = M[0][0]*p[0] + M[0][1]*p[1] + M[0][2]*p[2] + M[0][3]
                y = M[1][0]*p[0] + M[1][1]*p[1] + M[1][2]*p[2] + M[1][3]
                z = M[2][0]*p[0] + M[2][1]*p[1] + M[2][2]*p[2] + M[2][3]
                g['v'].append((x, z, -y))            # Blender Z-up -> Godot Y-up
                g['vt'].append(uv[c] if uv else (0, 0))
                idx.append(len(g['v']))
            g['f'].append(idx)
    for mn, g in por_mat.items():
        nome_arq = os.path.join(saida, ''.join(ch if ch.isalnum() or ch in '_-' else '_' for ch in mn) + '.obj')
        with open(nome_arq, 'w') as f:
            f.write('# de %s, material %s\n' % (os.path.basename(caminho), mn))
            for v in g['v']:
                f.write('v %.5f %.5f %.5f\n' % v)
            for t in g['vt']:
                f.write('vt %.5f %.5f\n' % (t[0], t[1]))
            for fc in g['f']:
                f.write('f ' + ' '.join('%d/%d' % (i, i) for i in fc) + '\n')
        print('  ->', nome_arq, len(g['f']), 'faces')

if __name__ == '__main__':
    if sys.argv[2] == '--listar':
        exportar(sys.argv[1], '/tmp', True)
    else:
        exportar(sys.argv[1], sys.argv[2], False, sys.argv[3].split(',') if len(sys.argv) > 3 else None)

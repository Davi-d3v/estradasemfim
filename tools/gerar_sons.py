"""Sintetiza os efeitos sonoros do jogo (originais, sem licença de terceiros).
Uso: python3 tools/gerar_sons.py  ->  assets/sons/*.ogg
Precisa de numpy, scipy e ffmpeg."""
import numpy as np, os, subprocess, tempfile
from scipy import signal
from scipy.io import wavfile

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sons')
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(2026)

def t(d):
    return np.arange(int(SR * d)) / SR

def ruido(d):
    return rng.standard_normal(int(SR * d))

def env(n, a, d, forma=4.0):
    """ataque linear a (s), queda exponencial com constante d (s)"""
    x = np.arange(n) / SR
    e = np.minimum(1.0, x / max(a, 1e-4)) * np.exp(-np.maximum(0, x - a) / max(d, 1e-4))
    return e

def lp(x, f, ordem=2):
    b, a = signal.butter(ordem, min(f, SR * 0.45) / (SR / 2), 'low')
    return signal.lfilter(b, a, x)

def hp(x, f, ordem=2):
    b, a = signal.butter(ordem, f / (SR / 2), 'high')
    return signal.lfilter(b, a, x)

def bp(x, f1, f2, ordem=2):
    b, a = signal.butter(ordem, [f1 / (SR / 2), min(f2, SR * 0.45) / (SR / 2)], 'band')
    return signal.lfilter(b, a, x)

def reverb(x, tempo=0.6, mix=0.25, cor=3000):
    n = int(SR * tempo)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR / (tempo / 5.0))
    ir = lp(ir, cor)
    s = np.concatenate([x, np.zeros(n)])
    w = signal.fftconvolve(x, ir)[: len(s)]
    w = np.pad(w, (0, len(s) - len(w)))
    w = w / (np.max(np.abs(w)) + 1e-9)
    return s * (1 - mix) + w * mix * np.max(np.abs(x))

def norm(x, pico=0.9):
    return x / (np.max(np.abs(x)) + 1e-9) * pico

def fade(x, fi=0.005, fo=0.02):
    n1, n2 = min(int(SR * fi), len(x) // 4), min(int(SR * fo), len(x) // 3)
    x = x.copy()
    x[:n1] *= np.linspace(0, 1, n1)
    x[-n2:] *= np.linspace(1, 0, n2)
    return x

def loop_suave(x, cruz=0.5):
    """deixa um loop sem estalo: crossfade do fim com o começo"""
    n = int(SR * cruz)
    a = x[:n] * np.linspace(0, 1, n)
    b = x[-n:] * np.linspace(1, 0, n)
    meio = x[n:-n]
    return np.concatenate([a + b, meio])

def salvar(nome, x, pico=0.9, q=5):
    x = norm(x, pico)
    if q != 3:   # q=3 são os loops (já emendados); os outros ganham fade no fim
        x = fade(x, 0.001, 0.04)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        wavfile.write(f.name, SR, (x * 32767).astype(np.int16))
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', f.name, '-c:a', 'libvorbis', '-q:a', str(q), os.path.join(OUT, nome + '.ogg')], check=True)
        os.unlink(f.name)

# ------------------------------------------------------------ armas de fogo
def tiro(corpo=1.0, grave=80, cauda=0.9, brilho=6000, dur=1.6):
    n = int(SR * dur)
    estalo = ruido(dur) * env(n, 0.0005, 0.012)
    estalo = hp(estalo, 900)
    corpo_r = lp(ruido(dur), brilho) * env(n, 0.001, 0.06 * corpo)
    tt = t(dur)
    soco = np.sin(2 * np.pi * (grave + 60 * np.exp(-tt * 40)) * tt) * env(n, 0.001, 0.08 * corpo)
    eco = lp(ruido(dur), 1200) * env(n, 0.02, 0.35 * cauda) * 0.35
    x = estalo * 0.9 + corpo_r * 1.0 + soco * 1.4 + eco
    x = np.tanh(x * 1.6)
    return reverb(x, 1.2 * cauda, 0.22, 2500)[: int(SR * (dur + 0.4))]

salvar('tiro_pistola', tiro(0.8, 110, 0.7, 7000, 1.2))
salvar('tiro_espingarda', tiro(1.6, 60, 1.2, 4500, 1.8))
salvar('tiro_rifle', tiro(1.2, 75, 1.5, 8000, 2.0))

def clique(f=3500, d=0.03, vol=1.0):
    n = int(SR * d)
    return bp(ruido(d), f * 0.6, f * 1.6) * env(n, 0.0005, d / 6) * vol

def junta(*pedacos):
    total = max(int(SR * p[1]) + len(p[0]) for p in pedacos) + 10
    x = np.zeros(total)
    for s, ini in pedacos:
        i = int(SR * ini)
        x[i:i + len(s)] += s
    return x

salvar('recarga', junta((clique(2500, 0.05), 0.0), (clique(1800, 0.06, 0.8), 0.25), (clique(4200, 0.04), 0.7), (clique(3000, 0.08, 1.2), 1.0)), 0.6)
salvar('vazio', junta((clique(5000, 0.02), 0.0), (clique(3500, 0.03, 0.6), 0.04)), 0.5)
salvar('troca_arma', junta((lp(ruido(0.15), 2500) * env(int(SR * 0.15), 0.01, 0.04), 0.0), (clique(2800, 0.04), 0.1)), 0.5)

# ------------------------------------------------------------ corpo a corpo
def whoosh(d=0.35, f0=600, f1=2500, vol=1.0):
    n = int(SR * d)
    x = ruido(d)
    out = np.zeros(n)
    passos = 24
    for i in range(passos):
        a, b = i * n // passos, (i + 1) * n // passos
        fc = f0 + (f1 - f0) * np.sin(np.pi * i / passos)
        out[a:b] = bp(x, fc * 0.7, fc * 1.3)[a:b]
    e = np.sin(np.pi * np.linspace(0, 1, n)) ** 2
    return out * e * vol

salvar('golpe_ar', whoosh(0.32, 500, 2200), 0.5)
salvar('golpe_ar_pesado', whoosh(0.5, 250, 1200), 0.6)

def impacto_carne(d=0.4, peso=1.0):
    n = int(SR * d)
    tt = t(d)
    baque = np.sin(2 * np.pi * (70 + 80 * np.exp(-tt * 30)) * tt) * env(n, 0.001, 0.07 * peso)
    molhado = lp(ruido(d), 1800) * env(n, 0.002, 0.05) * 0.8
    estalo = hp(ruido(d), 2500) * env(n, 0.0005, 0.006) * 0.4
    return np.tanh((baque * 1.5 + molhado + estalo) * 1.4)

for i in range(3):
    salvar('impacto_carne_%d' % i, impacto_carne(0.4, 0.8 + 0.3 * i), 0.8)

def impacto_metal(d=0.8, f=420):
    n = int(SR * d)
    tt = t(d)
    x = sum(np.sin(2 * np.pi * f * k * tt + rng.random()) * env(n, 0.0005, 0.25 / k) for k in [1, 2.37, 3.91, 5.2])
    return x + hp(ruido(d), 2000) * env(n, 0.0005, 0.01)

salvar('impacto_metal', impacto_metal(), 0.6)
salvar('impacto_madeira', lp(ruido(0.3), 1400) * env(int(SR * 0.3), 0.001, 0.04) + np.sin(2 * np.pi * 180 * t(0.3)) * env(int(SR * 0.3), 0.001, 0.05), 0.7)

# ------------------------------------------------------------ zumbis
def voz(d, f0, vogais, aspereza=0.5, jitter=0.08, tremor=6.0, sopro=0.3, curva=None):
    """voz rouca: pulso glotal (dente de serra) com jitter + formantes de vogais"""
    n = int(SR * d)
    tt = t(d)
    f = np.full(n, float(f0))
    if curva is not None:
        f = f0 * np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(curva)), curva)
    f *= 1 + jitter * lp(rng.standard_normal(n), 30) * 3 + 0.04 * np.sin(2 * np.pi * tremor * tt)
    fase = np.cumsum(f) / SR
    pulso = 2 * (fase % 1.0) - 1
    pulso = pulso + aspereza * np.sign(np.sin(2 * np.pi * fase * 0.5)) * 0.3   # subharmônico (garganta)
    fonte = pulso + sopro * ruido(d)
    out = np.zeros(n)
    k = len(vogais)
    for i, (f1, f2, f3) in enumerate(vogais):
        a, b = i * n // k, (i + 1) * n // k
        seg = np.zeros(n)
        for fm, bw, g in [(f1, 90, 1.0), (f2, 130, 0.6), (f3, 200, 0.3)]:
            seg += bp(fonte, max(60, fm - bw), fm + bw) * g
        jan = np.zeros(n)
        jan[a:b] = 1
        jan = lp(jan, 8)
        out += seg * jan
    return out

U, O, A, E = (300, 700, 2400), (450, 850, 2500), (750, 1150, 2500), (500, 1500, 2400)

def gemido(i):
    d = rng.uniform(1.2, 2.2)
    f0 = rng.uniform(70, 115)
    vog = [[U, O, A], [O, A, O], [A, O, U], [U, A, U]][i % 4]
    curva = [1.0, 1.15, 0.95, 0.8] if i % 2 == 0 else [0.9, 1.2, 1.0, 0.85]
    x = voz(d, f0, vog, aspereza=0.7, jitter=0.12, curva=curva)
    x *= env(len(x), 0.15, d * 0.5) * 0.6 + np.sin(np.pi * np.linspace(0, 1, len(x))) * 0.6
    return reverb(np.tanh(x * 2.5), 0.5, 0.15)

for i in range(5):
    salvar('zumbi_gemido_%d' % i, gemido(i), 0.7)

def rosnado(d=0.7, f0=90):
    x = voz(d, f0, [A, E], aspereza=1.0, jitter=0.2, tremor=25, sopro=0.6, curva=[0.9, 1.3, 1.0])
    x *= env(len(x), 0.03, d * 0.4)
    return np.tanh(x * 4)

salvar('zumbi_ataque_0', rosnado(0.6, 95), 0.8)
salvar('zumbi_ataque_1', rosnado(0.8, 80), 0.8)
grito = voz(1.6, 260, [A, E, A], aspereza=0.6, jitter=0.15, tremor=9, sopro=0.4, curva=[0.8, 1.5, 1.7, 1.2])
salvar('zumbi_grito', reverb(np.tanh(grito * 3) * env(len(grito), 0.05, 0.9), 1.2, 0.3), 0.8)
morte = voz(1.0, 85, [A, O, U], aspereza=0.8, curva=[1.1, 0.9, 0.6]) * env(int(SR * 1.0), 0.02, 0.5)
salvar('zumbi_morte', np.tanh(morte * 2.5), 0.7)

# ------------------------------------------------------------ jogador
def grunhido(d=0.3, f0=140):
    x = voz(d, f0, [A, O], aspereza=0.3, jitter=0.05, sopro=0.5, curva=[1.1, 0.85])
    return np.tanh(x * 2) * env(len(x), 0.01, d * 0.35)

salvar('dor_0', grunhido(0.3, 150), 0.6)
salvar('dor_1', grunhido(0.4, 130), 0.6)
salvar('esforco', grunhido(0.18, 160), 0.4)

# ------------------------------------------------------------ passos
def passo(superficie):
    d = 0.18
    n = int(SR * d)
    if superficie == 'terra':
        x = lp(ruido(d), 900) * env(n, 0.003, 0.035) + bp(ruido(d), 1500, 4000) * env(n, 0.01, 0.03) * 0.25
    elif superficie == 'asfalto':
        x = bp(ruido(d), 300, 2500) * env(n, 0.001, 0.02) + np.sin(2 * np.pi * 90 * t(d)) * env(n, 0.001, 0.02) * 0.6
    elif superficie == 'grama':
        x = bp(ruido(d), 1500, 6000) * env(n, 0.015, 0.05) * 0.8 + lp(ruido(d), 600) * env(n, 0.003, 0.03)
    else:  # madeira
        x = lp(ruido(d), 1500) * env(n, 0.001, 0.02) + np.sin(2 * np.pi * 160 * t(d)) * env(n, 0.001, 0.04)
    return x

for sup in ['terra', 'asfalto', 'grama', 'madeira']:
    for i in range(4):
        salvar('passo_%s_%d' % (sup, i), passo(sup), 0.35 + 0.05 * i)

# ------------------------------------------------------------ ambiente (loops)
def vento(d=12.0):
    x = ruido(d)
    lento = lp(rng.standard_normal(int(SR * d)), 0.3)
    lento = (lento - lento.min()) / (np.ptp(lento) + 1e-9)
    out = lp(x, 500) * (0.4 + 0.6 * lento) + bp(x, 600, 1600) * (lento ** 2) * 0.3
    return loop_suave(out, 1.5)

salvar('vento', vento(), 0.5, 3)

def chuva(d=10.0):
    x = bp(ruido(d), 800, 9000) * 0.5
    gotas = np.zeros(int(SR * d))
    for _ in range(int(d * 220)):
        i = rng.integers(0, len(gotas) - 800)
        g = bp(rng.standard_normal(800), 2000, 7000) * np.exp(-np.arange(800) / 90.0)
        gotas[i:i + 800] += g * rng.uniform(0.2, 1.0)
    return loop_suave(x + gotas * 0.6, 1.0)

salvar('chuva', chuva(), 0.5, 3)

def grilos(d=8.0):
    out = np.zeros(int(SR * d))
    for k in range(5):
        f = rng.uniform(3800, 5200)
        tt = t(d)
        pulso = (np.sin(2 * np.pi * rng.uniform(14, 22) * tt) > 0.3).astype(float)
        frase = (np.sin(2 * np.pi * rng.uniform(0.3, 0.7) * tt + rng.random() * 6) > 0).astype(float)
        out += np.sin(2 * np.pi * f * tt) * lp(pulso * frase, 300) * rng.uniform(0.2, 0.6)
    return loop_suave(out + lp(ruido(d), 300) * 0.05, 1.0)

salvar('noite_grilos', grilos(), 0.35, 3)

def fogueira(d=8.0):
    base = lp(ruido(d), 400) * 0.3
    estalos = np.zeros(int(SR * d))
    for _ in range(int(d * 18)):
        i = rng.integers(0, len(estalos) - 2000)
        L = rng.integers(200, 2000)
        estalos[i:i + L] += hp(rng.standard_normal(L), 1500) * np.exp(-np.arange(L) / rng.uniform(40, 300)) * rng.uniform(0.2, 1.0)
    return loop_suave(base + estalos, 0.8)

salvar('fogueira', fogueira(), 0.5, 3)

def estatica(d=4.0):
    x = bp(ruido(d), 400, 5000)
    chiado = (lp(rng.standard_normal(int(SR * d)), 3) > 0.0) * 0.5 + 0.5
    tt = t(d)
    assobio = np.sin(2 * np.pi * (1200 + 300 * np.sin(2 * np.pi * 0.3 * tt)) * tt) * 0.08
    return loop_suave(x * chiado + assobio, 0.5)

salvar('radio_estatica', estatica(), 0.4, 3)

# ------------------------------------------------------------ objetos
def rangido(d=0.8, f0=180):
    tt = t(d)
    f = f0 * (1 + 0.5 * np.sin(np.pi * tt / d)) * (1 + 0.15 * rng.standard_normal(len(tt)).cumsum() / len(tt))
    fase = np.cumsum(f) / SR
    x = (2 * (fase % 1) - 1) * (np.sin(2 * np.pi * 23 * tt) > 0)
    return bp(x, 300, 3000) * np.sin(np.pi * np.linspace(0, 1, len(tt)))

salvar('porta', rangido(0.7, 160), 0.4)
salvar('compartimento', junta((rangido(0.35, 260), 0.0), (clique(1500, 0.06, 1.5), 0.33)), 0.45)

def mastigar():
    return junta(*[(bp(ruido(0.08), 1500, 6000) * env(int(SR * 0.08), 0.002, 0.02), 0.25 * i + rng.uniform(0, 0.05)) for i in range(5)])

salvar('comer', mastigar(), 0.4)

def gole():
    pedacos = []
    for i in range(3):
        tt = t(0.12)
        g = np.sin(2 * np.pi * (300 + 900 * tt / 0.12) * tt) * env(len(tt), 0.005, 0.03)
        pedacos.append((g, 0.35 * i))
    return junta(*pedacos)

salvar('beber', gole(), 0.4)
salvar('enfaixar', junta((bp(ruido(0.4), 2000, 8000) * env(int(SR * 0.4), 0.05, 0.12), 0.0), (bp(ruido(0.3), 1500, 6000) * env(int(SR * 0.3), 0.02, 0.1), 0.6)), 0.4)

def vidro():
    d = 1.0
    n = int(SR * d)
    x = hp(ruido(d), 3000) * env(n, 0.0005, 0.08)
    for _ in range(25):
        i = rng.integers(0, n // 2)
        f = rng.uniform(3000, 8000)
        L = 3000
        x[i:i + L] += np.sin(2 * np.pi * f * np.arange(L) / SR) * np.exp(-np.arange(L) / 600) * rng.uniform(0.1, 0.5)
    return x

salvar('vidro_quebra', vidro(), 0.6)
_fw = fogueira(2.0)[:int(SR * 1.2)]
salvar('fogo_whoosh', lp(ruido(1.2), 900) * env(int(SR * 1.2), 0.15, 0.4) + _fw * 0.3, 0.7)

def uivo(d=3.0):
    tt = t(d)
    curva = 380 + 220 * np.sin(np.pi * np.minimum(1, tt / (d * 0.4))) - 120 * np.maximum(0, tt - d * 0.6) / d
    f = curva * (1 + 0.01 * np.sin(2 * np.pi * 5 * tt))
    fase = np.cumsum(f) / SR
    x = np.sin(2 * np.pi * fase) + 0.25 * np.sin(4 * np.pi * fase) + 0.05 * ruido(d)
    x *= np.sin(np.pi * np.linspace(0, 1, len(tt))) ** 0.7
    return reverb(x, 2.0, 0.4)

salvar('lobo_uivo', uivo(), 0.5)
salvar('clique_ui', clique(2200, 0.03), 0.3)

# ------------------------------------------------------------ horda (loop)
def horda(d=14.0):
    n = int(SR * d)
    x = np.zeros(n + SR * 3)
    for i in range(46):
        g = gemido(i) * rng.uniform(0.25, 1.0)
        a = rng.integers(0, n)
        x[a:a + len(g)] += g[: len(x) - a]
    x = x[:n] + np.concatenate([x[n:], np.zeros(2 * n - len(x))])[:n]   # o que passou do fim volta no começo
    # arrastar de pés: ruído grave pulsando
    passos = lp(ruido(d), 220) * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 0.9 * t(d))))
    ronco = lp(np.cumsum(ruido(d)) * 0.002, 90)
    x = lp(x, 2600) * 0.8 + norm(passos, 0.35) + norm(ronco, 0.3)
    x = reverb(x, 1.8, 0.45, 1800)[:n]
    return loop_suave(x, 1.0)

salvar('horda', horda(), 0.75, 3)

# ------------------------------------------------------------ trovão
def trovao(d=5.0):
    n = int(SR * d)
    estalo = hp(ruido(0.25), 1500) * env(int(SR * 0.25), 0.002, 0.05)
    ronco = lp(ruido(d), 160) * 3.0
    ronco *= env(n, 0.08, 1.4) * (1.0 + 0.5 * np.sin(2 * np.pi * 1.3 * t(d)) * np.exp(-t(d) / 1.5))
    x = ronco
    x[:len(estalo)] += estalo * 0.4
    return reverb(lp(np.tanh(x * 1.5), 1200), 2.5, 0.5, 900)

salvar('trovao_0', trovao(4.5), 0.85)
salvar('trovao_1', trovao(6.0), 0.85)
print('ok', len(os.listdir(OUT)))

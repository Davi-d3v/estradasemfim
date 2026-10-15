shader_type spatial;
// Superfícies com textura procedural (sem imagens): o padrão é escolhido por 'padrao'.
// Projeção triplanar em coordenadas do mundo, então funciona em malhas mescladas.
// Cada padrão gera cor E altura; a altura vira relevo (normal) por derivadas de tela,
// então rejunte, frestas e telhas têm volume de verdade com a luz.
uniform vec3 cor : source_color = vec3(0.8);
uniform int padrao = 0;
uniform float rugosidade = 0.9;
uniform float metalico = 0.0;
uniform float sujeira = 0.4;
uniform float descascado = 0.0;    // reboco externo: tinta e massa caindo, tijolo aparecendo
uniform float relevo = 1.0;
// texturas fotográficas (ambientCG, CC0): cor, normal e rugosidade, projetadas em
// coordenadas do objeto em metros (escala = metros por repetição)
uniform bool tem_tex = false;
uniform sampler2D tex_cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 escala = vec2(2.0);
uniform vec3 media : source_color = vec3(0.5);       // cor média da foto (para tingir sem mudar o brilho)
uniform float tingir = 0.0;           // 1 = a cor do material manda (reboco pintado, metal pintado)
uniform float massa_caida = 0.0;      // reboco: quanto da massa caída da foto aparece (0 = parede inteira)
varying vec3 wpos;
varying vec3 wnorm;
varying vec3 opos;
varying vec3 onorm;

float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.07 + 3.1; a *= 0.5; } return v; }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize(mat3(MODEL_MATRIX) * NORMAL);
	opos = VERTEX;
	onorm = NORMAL;
}

// coordenada 2D na face dominante: (horizontal, vertical) para paredes, (x, z) para pisos
vec2 face_uv(out bool chao) {
	vec3 n = abs(wnorm);
	chao = n.y > 0.7;
	if (chao) return wpos.xz;
	if (n.x > n.z) return vec2(wpos.z, wpos.y);
	return vec2(wpos.x, wpos.y);
}

// tijolos: cor e altura (rejunte afundado, quina chanfrada)
void tijolos(vec2 uv, float grao, inout vec3 c, out float h) {
	vec2 b = uv * vec2(1.0 / 0.24, 1.0 / 0.075);
	b.x += step(1.0, mod(floor(b.y), 2.0)) * 0.5;
	vec2 f = fract(b);
	vec2 dist = min(f, 1.0 - f) * vec2(0.24, 0.075);      // distância (m) até a borda do tijolo
	float borda = min(dist.x, dist.y);
	float rejunte = 1.0 - smoothstep(0.004, 0.009, borda);
	float var_ = hash(floor(b));
	c = vec3(0.6, 0.31, 0.2) * (0.72 + var_ * 0.4 + grao * 0.1);
	c = mix(c, c * vec3(0.8, 0.85, 0.9), step(0.85, var_));   // alguns queimados
	c = mix(c, vec3(0.6, 0.58, 0.54), rejunte);
	h = smoothstep(0.004, 0.014, borda) * 0.008 + grao * 0.0015;
}

void fragment() {
	bool chao;
	vec2 uv = face_uv(chao);
	vec3 c = cor;
	float r = rugosidade;
	float m = metalico;
	float grao = noise(uv * 18.0);
	float manchas = fbm(uv * 0.6);
	float h = 0.0;          // altura do relevo (m)
	float ao = 1.0;         // sombra nas frestas
	if (tem_tex) {
		// projeção na face dominante, no espaço do objeto (telhas acompanham a casa girada)
		vec3 an = abs(onorm);
		vec2 st; vec3 T; vec3 Bt;
		if (an.y > 0.7) { st = vec2(opos.x, -opos.z); T = vec3(1, 0, 0); Bt = vec3(0, 0, 1); }
		else if (an.x > an.z) { st = vec2(opos.z, -opos.y); T = vec3(0, 0, 1); Bt = vec3(0, 1, 0); }
		else { st = vec2(opos.x, -opos.y); T = vec3(1, 0, 0); Bt = vec3(0, 1, 0); }
		st /= escala;
		vec3 tc = texture(tex_cor, st).rgb;
		vec2 nxy = texture(tex_normal, st).rg * 2.0 - 1.0;
		float nz = sqrt(max(0.0, 1.0 - dot(nxy, nxy)));
		vec3 N0 = normalize(onorm);
		T = normalize(T - N0 * dot(T, N0));
		Bt = normalize(Bt - N0 * dot(Bt, N0) - T * dot(Bt, T));
		vec3 nobj = normalize(T * nxy.x + Bt * nxy.y + N0 * nz);
		float lum = dot(tc, vec3(0.333));
		float tinta = 1.0;
		if (massa_caida >= 0.0 && padrao == 0) {
			// reboco: onde a foto mostra massa caída, só deixa aparecer em algumas áreas
			float area = smoothstep(0.45, 0.62, fbm(uv * 0.22 + 31.0) + massa_caida * 0.25 - 0.12);
			float inteiro = smoothstep(0.4, 0.55, lum);           // 1 = massa/tinta, 0 = tijolo à mostra
			float cobre = (1.0 - area) * (1.0 - inteiro);
			tc = mix(tc, vec3(0.62, 0.61, 0.58) * (0.9 + grao * 0.12 + (manchas - 0.5) * 0.1), cobre);
			nobj = normalize(mix(nobj, N0, cobre));
			tinta = max(inteiro, cobre);
		}
		c = tc * mix(vec3(1.0), cor / max(media, vec3(0.05)), tingir * tinta);
		r = texture(tex_rough, st).r * mix(1.0, rugosidade / 0.85, 0.3);
		if (!chao) {
			float pe = 1.0 - smoothstep(0.0, 0.55 + noise(vec2(uv.x * 3.0, 0.0)) * 0.3, fract(wpos.y / 3.0) * 3.0);
			c = mix(c, c * vec3(0.55, 0.47, 0.38), pe * sujeira * 0.8);
			float escorrido = smoothstep(0.55, 0.9, noise(vec2(uv.x * 6.0, uv.y * 0.35))) * smoothstep(0.3, 0.7, fract(wpos.y / 3.0));
			c = mix(c, c * vec3(0.62, 0.6, 0.56), escorrido * sujeira * 0.6);
		}
		NORMAL = normalize(mat3(VIEW_MATRIX) * (mat3(MODEL_MATRIX) * nobj));
	} else if (padrao == 0 || padrao == 6) {
		// reboco / concreto: textura de massa, manchas, rachaduras, umidade embaixo
		float massa = fbm(uv * 7.0);
		c *= 0.86 + manchas * 0.22 + grao * 0.05 + (massa - 0.5) * 0.08;
		h = massa * 0.0025 + grao * 0.0008;
		float rachv = abs(fbm(uv * 1.3) - 0.5);
		float rach = (1.0 - smoothstep(0.0, 0.004, rachv)) * step(0.6, fbm(uv * 0.3 + 7.0));
		c = mix(c, c * 0.62, rach);
		h -= rach * 0.003;
		if (!chao) {
			// barro respingado no pé da parede e escorridos de chuva
			float pe = 1.0 - smoothstep(0.0, 0.55 + noise(vec2(uv.x * 3.0, 0.0)) * 0.3, fract(wpos.y / 3.0) * 3.0);
			c = mix(c, c * vec3(0.55, 0.47, 0.38), pe * sujeira * 0.85);
			float escorrido = smoothstep(0.55, 0.9, noise(vec2(uv.x * 6.0, uv.y * 0.35))) * smoothstep(0.3, 0.7, fract(wpos.y / 3.0));
			c = mix(c, c * vec3(0.62, 0.6, 0.56), escorrido * sujeira * 0.7);
			// tinta e massa caindo: aparece o tijolo baiano por baixo
			if (descascado > 0.0) {
				float d = fbm(uv * 0.9 + 13.7) + (noise(uv * 6.0) - 0.5) * 0.12;
				float lim = 0.71 - descascado * 0.06;
				float buraco = smoothstep(lim, lim + 0.01, d);
				float borda = smoothstep(lim - 0.04, lim, d) - buraco;
				vec3 tij = c; float ht;
				tijolos(uv, grao, tij, ht);
				c = mix(c, c * 0.7, borda * 0.8);            // borda suja da massa
				c = mix(c, tij * 0.92, buraco);
				h = mix(h + borda * 0.002, ht - 0.012, buraco);
				ao = mix(ao, 0.85, buraco);
			}
		}
		if (padrao == 6) { c *= 0.9 + noise(uv * 40.0) * 0.15; h += noise(uv * 40.0) * 0.001; }
	} else if (padrao == 1) {
		tijolos(uv, grao, c, h);
		c *= cor / vec3(0.62, 0.34, 0.24);
		ao = 0.75 + 0.25 * smoothstep(0.0, 0.008, h);
		if (!chao) {
			float pe = 1.0 - smoothstep(0.0, 0.6, fract(wpos.y / 3.0) * 3.0);
			c = mix(c, c * vec3(0.5, 0.45, 0.38), pe * sujeira * 0.7);
		}
	} else if (padrao == 2 || padrao == 4) {
		// tábuas (verticais nas paredes, no piso ao longo de x)
		float largura = padrao == 4 ? 0.18 : 0.16;
		float coord = chao ? uv.y : uv.x;
		float ao_longo = chao ? uv.x : uv.y;
		float tab = floor(coord / largura);
		float f = fract(coord / largura);
		float veio = noise(vec2(tab * 7.0, ao_longo * 0.8)) * 0.5 + noise(vec2(coord * 60.0, ao_longo * 2.0)) * 0.25;
		float no_ = smoothstep(0.86, 0.95, noise(vec2(coord * 9.0, ao_longo * 3.0 + tab * 5.0)));   // nós da madeira
		c *= 0.7 + hash(vec2(tab, 3.0)) * 0.35 + veio * 0.25;
		c = mix(c, c * 0.55, no_);
		float fresta = 1.0 - smoothstep(0.0, 0.05, min(f, 1.0 - f));
		c *= 1.0 - fresta * 0.55;
		h = (1.0 - fresta) * 0.006 + veio * 0.0015 + hash(vec2(tab, 9.0)) * 0.002;
		ao = 1.0 - fresta * 0.4;
		if (padrao == 4) {
			float emenda = 1.0 - smoothstep(0.0, 0.01, fract(ao_longo / 1.2 + hash(vec2(tab, 1.0))));
			c *= 1.0 - emenda * 0.4;
			h -= emenda * 0.003;
		}
		if (!chao) {
			// madeira velha: mais escura e cinzenta embaixo, onde pega água
			float pe = 1.0 - smoothstep(0.0, 0.8, fract(wpos.y / 3.0) * 3.0);
			c = mix(c, vec3(0.3, 0.29, 0.27), pe * sujeira * 0.6);
		}
	} else if (padrao == 3) {
		// telhas coloniais: fileiras onduladas, sobrepostas, com limo
		vec2 t = vec2((chao ? wpos.x : uv.x) / 0.22, wpos.y / 0.2 + (chao ? wpos.z / 0.2 : 0.0));
		float fila = floor(t.y);
		t.x += hash(vec2(fila, 2.0)) * 0.3;
		float onda = 0.5 + 0.5 * cos(fract(t.x) * 6.2832);                  // canal e capa
		float sobre = smoothstep(0.0, 0.85, fract(t.y));                     // cada fila cobre a de baixo
		c *= 0.68 + hash(floor(t)) * 0.3;
		c *= 0.7 + 0.3 * onda;
		c *= 0.55 + 0.45 * sobre;
		h = onda * 0.02 + sobre * 0.012;
		ao = 0.6 + 0.4 * sobre;
		c = mix(c, vec3(0.22, 0.26, 0.16), smoothstep(0.55, 0.8, fbm(uv * 1.5)) * (1.0 - onda * 0.5) * 0.6);   // limo nos canais
		c = mix(c, vec3(0.12, 0.1, 0.09), smoothstep(0.7, 0.85, fbm(uv * 0.7 + 5.0)) * 0.35);                 // fuligem
	} else if (padrao == 5) {
		// cerâmica
		vec2 f = fract(uv / 0.4);
		float j = 1.0 - smoothstep(0.0, 0.035, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
		c *= 0.92 + hash(floor(uv / 0.4)) * 0.12;
		c = mix(c, c * 0.55, j);
		c = mix(c, c * 0.7, smoothstep(0.6, 0.8, fbm(uv * 1.1)) * sujeira);
		h = (1.0 - j) * 0.003;
		r = mix(0.3, 0.8, j + sujeira * manchas);
	} else if (padrao == 7) {
		// metal escovado com ferrugem
		c *= 0.85 + noise(vec2(uv.x * 2.0, uv.y * 80.0)) * 0.2;
		float fer = smoothstep(0.55, 0.7, fbm(uv * 1.2 + 3.0)) * sujeira;
		c = mix(c, vec3(0.38, 0.2, 0.09), fer);
		h = fer * fbm(uv * 20.0) * 0.002;
		m = mix(m, 0.0, fer);
		r = mix(r, 0.95, fer);
	} else if (padrao == 8) {
		// vidro sujo
		c *= 0.8 + manchas * 0.4;
		r = 0.1 + manchas * 0.3;
	} else if (padrao == 9) {
		// tecido: trama
		float trama = noise(uv * 90.0);
		c *= 0.85 + trama * 0.12 + manchas * 0.1;
		h = trama * 0.0004;
	} else if (padrao == 10) {
		// papelão
		c *= 0.85 + noise(vec2(uv.x * 40.0, uv.y * 3.0)) * 0.15;
		c = mix(c, c * 0.6, smoothstep(0.6, 0.8, fbm(uv * 2.0)) * 0.6);
	} else if (padrao == 12) {
		// casca de árvore: sulcos verticais
		vec2 q = vec2((wpos.x + wpos.z) * 9.0, wpos.y * 1.5);
		float sulco = noise(vec2(q.x, q.y * 0.4)) * 0.6 + noise(q * 2.3) * 0.4;
		c *= 0.6 + sulco * 0.6;
		h = sulco * 0.02;
		ao = 0.7 + 0.3 * sulco;
	} else if (padrao == 13) {
		// pedra
		float f3 = fbm(uv * 3.0);
		c *= 0.7 + f3 * 0.4 + grao * 0.1;
		c = mix(c, vec3(0.25, 0.3, 0.15), smoothstep(0.6, 0.75, fbm(uv * 1.7 + 4.0)) * (wnorm.y > 0.3 ? 0.7 : 0.2));
		h = f3 * 0.03 + grao * 0.004;
	} else if (padrao == 11) {
		// madeira de móvel (veio horizontal)
		float v = noise(vec2(uv.x * 2.0, uv.y * 30.0));
		c *= 0.8 + v * 0.25;
		h = v * 0.0008;
	}
	// poeira geral
	c = mix(c, vec3(0.45, 0.42, 0.37), sujeira * 0.12 * (0.5 + manchas));
	ALBEDO = c * ao;
	ROUGHNESS = clamp(r, 0.0, 1.0);
	METALLIC = m;
	AO = ao;
	// relevo: normal perturbada pela altura (bump mapping por derivadas de tela)
	if (relevo > 0.0) {
		vec3 dpdx = dFdx(VERTEX);
		vec3 dpdy = dFdy(VERTEX);
		float dhdx = dFdx(h);
		float dhdy = dFdy(h);
		vec3 r1 = cross(dpdy, NORMAL);
		vec3 r2 = cross(NORMAL, dpdx);
		float det = dot(dpdx, r1);
		vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
		vec3 nb = normalize(abs(det) * NORMAL - grad * relevo);
		// de longe as derivadas ficam ruidosas: some com a distância
		float longe = clamp(length(VERTEX) / 45.0, 0.0, 1.0);
		NORMAL = normalize(mix(nb, NORMAL, longe));
	}
}

shader_type spatial;
// Chão do mundo. Cores do bioma vêm por vértice:
//   COLOR.rgb = seco, COLOR.a = terra (beira da estrada), CUSTOM0.rgb = verde, CUSTOM0.a = floresta.
// Camadas: capim (manchas verde/seco + fios), terra batida, pedrisco, folhas secas na mata,
// rocha nas encostas. Detalhe fino some com a distância (sem listras de aliasing).

uniform vec2 origem = vec2(0.0);
uniform float neve = 0.0;
varying vec3 wpos;
varying vec3 wnorm;
varying vec3 cor_seco;
varying vec3 cor_verde;
varying float terra;
varying float mata;

vec2 hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = r * p * 2.03 + vec2(3.1, 7.7);
		a *= 0.5;
	}
	return v;
}
// Voronoi: distância ao ponto mais perto (pedrinhas, folhas) e um valor aleatório da célula.
vec2 voronoi(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash2(i + g);
			vec2 r = g + o - f;
			float dd = dot(r, r);
			if (dd < d) {
				d = dd;
				id = hash(i + g + 17.0);
			}
		}
	}
	return vec2(sqrt(d), id);
}
// Quanto do detalhe numa frequência sobrevive sem virar ruído de aliasing.
float nitidez(vec2 p, float freq) {
	float w = length(fwidth(p * freq));
	return 1.0 - smoothstep(0.25, 0.9, w);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	cor_seco = COLOR.rgb;
	cor_verde = CUSTOM0.rgb;
	terra = COLOR.a;
	mata = CUSTOM0.a;
}

void fragment() {
	vec2 p = wpos.xz - origem;

	// --- capim: manchas grandes de verde/seco e variação média
	float grande = fbm(p * 0.035);
	float media = fbm(p * 0.21 + 11.0);
	vec3 capim = mix(cor_verde, cor_seco, smoothstep(0.38, 0.66, grande + (media - 0.5) * 0.35));
	// tufos e fios (alta frequência, some de longe)
	float k_fio = nitidez(p, 6.0);
	float fio = noise(vec2(p.x * 7.0, p.y * 7.0)) * noise(vec2(p.x * 13.0 + 3.0, p.y * 13.0));
	float tufo = smoothstep(0.45, 0.8, noise(p * 1.7 + 5.0));
	capim *= 1.0 + ((fio - 0.25) * 0.55 * k_fio);
	capim = mix(capim, capim * vec3(0.78, 0.86, 0.7), tufo * 0.45);
	// folhinhas de capim (bem de perto): cada célula é uma folha clara ou escura
	float k_folhinha = nitidez(p, 16.0);
	if (k_folhinha > 0.01) {
		vec2 g = p * 16.0;
		g += vec2(noise(p * 3.0), noise(p * 3.0 + 9.0)) * 1.5;
		vec2 vg = voronoi(g);
		float lamina = 1.0 - smoothstep(0.1, 0.42, vg.x);
		vec3 tom = mix(cor_verde * 1.25, cor_seco * 1.2, step(0.55, vg.y + (grande - 0.5)));
		capim = mix(capim * (1.0 - 0.18 * k_folhinha), tom, lamina * 0.55 * k_folhinha);
	}

	// --- terra batida: aparece em clareiras, trilhas e na beira da estrada
	vec3 terra_cor = vec3(0.33, 0.26, 0.18);
	vec3 terra_escura = vec3(0.2, 0.15, 0.1);
	float terra_var = fbm(p * 0.5 + 2.0);
	vec3 chao_terra = mix(terra_escura, terra_cor, terra_var);
	// pedrisco na terra
	float k_ped = nitidez(p, 4.0);
	vec2 vp = voronoi(p * 4.0);
	float pedra = (1.0 - smoothstep(0.08, 0.2, vp.x)) * step(0.62, vp.y) * k_ped;
	chao_terra = mix(chao_terra, vec3(0.5, 0.47, 0.42) * (0.75 + vp.y * 0.4), pedra * 0.85);
	// rachaduras / marcas de pneu na beira da estrada
	float sulco = smoothstep(0.47, 0.5, noise(vec2(p.x * 0.9, p.y * 0.12))) * (1.0 - smoothstep(0.5, 0.53, noise(vec2(p.x * 0.9, p.y * 0.12))));
	chao_terra *= 1.0 - sulco * 0.25 * terra;

	float manchas_terra = smoothstep(0.56, 0.72, fbm(p * 0.09 + 40.0));
	float q_terra = clamp(manchas_terra * 0.75 + terra, 0.0, 1.0);
	// borda irregular entre capim e terra
	q_terra = smoothstep(0.25, 0.75, q_terra + (media - 0.5) * 0.5);
	vec3 c = mix(capim, chao_terra, q_terra);

	// --- chão da mata: folhas secas e galhinhos
	if (mata > 0.02) {
		float k_folha = nitidez(p, 7.0);
		vec2 vf = voronoi(p * 7.0 + vec2(fbm(p * 0.9) * 1.5));
		vec3 folha = mix(vec3(0.28, 0.19, 0.1), vec3(0.42, 0.3, 0.16), vf.y);
		folha = mix(folha, vec3(0.24, 0.25, 0.12), step(0.85, vf.y));   // folha ainda verde
		folha = mix(folha, vec3(0.16, 0.12, 0.08), step(vf.y, 0.12));   // folha podre
		float borda = smoothstep(0.05, 0.5, vf.x);
		vec3 serrapilheira = mix(folha, folha * 0.72, borda * k_folha);
		vec3 base_mata = mix(vec3(0.24, 0.18, 0.11), serrapilheira, 0.5 + 0.5 * k_folha);
		float musgo = smoothstep(0.55, 0.75, fbm(p * 0.3 + 70.0));
		base_mata = mix(base_mata, vec3(0.16, 0.22, 0.09), musgo * 0.6);
		c = mix(c, base_mata, smoothstep(0.05, 0.6, mata) * 0.92);
	}

	// --- rocha nas encostas mais íngremes
	float inclin = 1.0 - clamp(wnorm.y, 0.0, 1.0);
	float rocha = smoothstep(0.28, 0.42, inclin + (media - 0.5) * 0.15);
	vec3 rocha_cor = mix(vec3(0.36, 0.34, 0.31), vec3(0.5, 0.48, 0.44), fbm(p * 0.8 + vec2(wpos.y * 0.5)));
	c = mix(c, rocha_cor, rocha);

	// grão fino + oclusão grosseira nas manchas
	float k_grao = nitidez(p, 10.0);
	c *= 0.92 + (noise(p * 10.0) - 0.5) * 0.22 * k_grao;
	c *= 0.88 + grande * 0.24;

	// relevo fino: perturba a normal com o gradiente do ruído (pega luz rasante)
	float e = 0.08;
	float h0 = fbm(p * 1.3);
	float hx = fbm((p + vec2(e, 0.0)) * 1.3);
	float hz = fbm((p + vec2(0.0, e)) * 1.3);
	float forca = (0.35 + q_terra * 0.5 + rocha * 0.6) * nitidez(p, 1.3);
	vec3 nw = normalize(wnorm + vec3(-(hx - h0) / e, 0.0, -(hz - h0) / e) * forca);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	c = mix(c, vec3(0.88, 0.9, 0.94), clamp(neve * smoothstep(0.55, 0.85, nw.y), 0.0, 0.92));
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}

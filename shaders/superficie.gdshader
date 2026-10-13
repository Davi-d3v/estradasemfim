shader_type spatial;
// Superfícies com textura procedural (sem imagens): o padrão é escolhido por 'padrao'.
// Projeção triplanar em coordenadas do mundo, então funciona em malhas mescladas.
uniform vec3 cor : source_color = vec3(0.8);
uniform int padrao = 0;
uniform float rugosidade = 0.9;
uniform float metalico = 0.0;
uniform float sujeira = 0.4;
varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.07 + 3.1; a *= 0.5; } return v; }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

// coordenada 2D na face dominante: (horizontal, vertical) para paredes, (x, z) para pisos
vec2 face_uv(out bool chao) {
	vec3 n = abs(wnorm);
	chao = n.y > 0.7;
	if (chao) return wpos.xz;
	if (n.x > n.z) return vec2(wpos.z, wpos.y);
	return vec2(wpos.x, wpos.y);
}

void fragment() {
	bool chao;
	vec2 uv = face_uv(chao);
	vec3 c = cor;
	float r = rugosidade;
	float m = metalico;
	float grao = noise(uv * 18.0);
	float manchas = fbm(uv * 0.6);
	if (padrao == 0 || padrao == 6) {
		// reboco / concreto: manchas, rachaduras, umidade embaixo
		c *= 0.85 + manchas * 0.25 + grao * 0.06;
		float rach = 1.0 - smoothstep(0.0, 0.012, abs(fbm(uv * 1.3) - 0.5));
		c = mix(c, c * 0.55, rach * step(0.55, fbm(uv * 0.3 + 7.0)));
		if (!chao) c = mix(c, c * vec3(0.55, 0.55, 0.5), (1.0 - smoothstep(0.0, 0.9, fract(wpos.y / 3.0) * 3.0)) * sujeira * 0.5);
		if (padrao == 6) c *= 0.9 + noise(uv * 40.0) * 0.15;
	} else if (padrao == 1) {
		// tijolos
		vec2 b = uv * vec2(1.0 / 0.24, 1.0 / 0.075);
		b.x += step(1.0, mod(floor(b.y), 2.0)) * 0.5;
		vec2 f = fract(b);
		float rejunte = step(f.x, 0.06) + step(f.y, 0.12);
		float var_ = hash(floor(b));
		c *= 0.75 + var_ * 0.35 + grao * 0.08;
		c = mix(c, vec3(0.62, 0.6, 0.56), clamp(rejunte, 0.0, 1.0));
	} else if (padrao == 2 || padrao == 4) {
		// tábuas (verticais nas paredes, no piso ao longo de x)
		float largura = padrao == 4 ? 0.18 : 0.16;
		float coord = chao ? uv.y : uv.x;
		float ao_longo = chao ? uv.x : uv.y;
		float tab = floor(coord / largura);
		float f = fract(coord / largura);
		float veio = noise(vec2(tab * 7.0, ao_longo * 0.8)) * 0.5 + noise(vec2(coord * 60.0, ao_longo * 2.0)) * 0.25;
		c *= 0.7 + hash(vec2(tab, 3.0)) * 0.35 + veio * 0.25;
		c *= 1.0 - (1.0 - smoothstep(0.0, 0.06, f)) * 0.5;
		if (padrao == 4) c *= 1.0 - (1.0 - smoothstep(0.0, 0.01, fract(ao_longo / 1.2 + hash(vec2(tab, 1.0))))) * 0.4;
	} else if (padrao == 3) {
		// telhas: fileiras com sombra
		float fila = fract(wpos.y / 0.22 + wpos.z * 0.0);
		vec2 t = vec2((chao ? wpos.x : uv.x) / 0.3, wpos.y / 0.22);
		t.x += step(1.0, mod(floor(t.y), 2.0)) * 0.5;
		c *= 0.7 + hash(floor(t)) * 0.3;
		c *= 0.6 + 0.4 * smoothstep(0.0, 0.5, fract(t.y));
		c = mix(c, vec3(0.25, 0.27, 0.2), smoothstep(0.55, 0.8, fbm(uv * 1.5)) * 0.5);  // limo
	} else if (padrao == 5) {
		// cerâmica
		vec2 f = fract(uv / 0.4);
		float j = step(f.x, 0.03) + step(f.y, 0.03);
		c *= 0.92 + hash(floor(uv / 0.4)) * 0.12;
		c = mix(c, c * 0.6, clamp(j, 0.0, 1.0));
		r = 0.35;
	} else if (padrao == 7) {
		// metal escovado com ferrugem
		c *= 0.85 + noise(vec2(uv.x * 2.0, uv.y * 80.0)) * 0.2;
		float fer = smoothstep(0.55, 0.7, fbm(uv * 1.2 + 3.0)) * sujeira;
		c = mix(c, vec3(0.38, 0.2, 0.09), fer);
		m = mix(m, 0.0, fer);
		r = mix(r, 0.95, fer);
	} else if (padrao == 8) {
		// vidro sujo
		c *= 0.8 + manchas * 0.4;
		r = 0.1 + manchas * 0.3;
	} else if (padrao == 9) {
		// tecido
		c *= 0.85 + noise(uv * 90.0) * 0.12 + manchas * 0.1;
	} else if (padrao == 10) {
		// papelão
		c *= 0.85 + noise(vec2(uv.x * 40.0, uv.y * 3.0)) * 0.15;
		c = mix(c, c * 0.6, smoothstep(0.6, 0.8, fbm(uv * 2.0)) * 0.6);
	} else if (padrao == 12) {
		// casca de árvore: sulcos verticais
		float ang = atan(wpos.x - floor(wpos.x / 8.0) * 8.0 - 4.0, wpos.z - floor(wpos.z / 8.0) * 8.0 - 4.0);
		vec2 q = vec2((wpos.x + wpos.z) * 9.0, wpos.y * 1.5);
		float sulco = noise(vec2(q.x, q.y * 0.4)) * 0.6 + noise(q * 2.3) * 0.4;
		c *= 0.6 + sulco * 0.6;
	} else if (padrao == 13) {
		// pedra
		c *= 0.7 + fbm(uv * 3.0) * 0.4 + grao * 0.1;
		c = mix(c, vec3(0.25, 0.3, 0.15), smoothstep(0.6, 0.75, fbm(uv * 1.7 + 4.0)) * (wnorm.y > 0.3 ? 0.7 : 0.2));
	} else if (padrao == 11) {
		// madeira de móvel (veio horizontal)
		c *= 0.8 + noise(vec2(uv.x * 2.0, uv.y * 30.0)) * 0.25;
	}
	// poeira geral
	c = mix(c, vec3(0.45, 0.42, 0.37), sujeira * 0.12 * (0.5 + manchas));
	ALBEDO = c;
	ROUGHNESS = clamp(r, 0.0, 1.0);
	METALLIC = m;
}

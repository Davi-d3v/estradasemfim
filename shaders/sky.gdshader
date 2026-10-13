shader_type sky;
// Céu de entardecer com nuvens procedurais. Cores controladas pelo ciclo dia/noite.

uniform vec3 cor_topo : source_color = vec3(0.18, 0.12, 0.32);
uniform vec3 cor_meio : source_color = vec3(0.55, 0.28, 0.42);
uniform vec3 cor_horizonte : source_color = vec3(1.0, 0.45, 0.18);
uniform vec3 cor_sol : source_color = vec3(1.0, 0.75, 0.4);
uniform vec3 cor_chao : source_color = vec3(0.12, 0.08, 0.08);
uniform vec3 cor_nuvem_sombra : source_color = vec3(0.22, 0.14, 0.26);
uniform vec3 cor_nuvem_luz : source_color = vec3(1.0, 0.5, 0.25);
uniform float cobertura : hint_range(0.0, 1.0) = 0.5;
uniform float estrelas : hint_range(0.0, 1.0) = 0.0;
uniform float tempo_nuvem = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
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
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 sol = normalize(LIGHT0_DIRECTION);
	float h = d.y;
	float s = max(dot(d, sol), 0.0);

	vec3 cor;
	if (h >= 0.0) {
		float t1 = smoothstep(0.0, 0.18, h);
		float t2 = smoothstep(0.12, 0.65, h);
		cor = mix(cor_horizonte, cor_meio, t1);
		cor = mix(cor, cor_topo, t2);
		// brilho em volta do sol, mais forte no horizonte
		float halo = pow(s, 6.0) * 0.55 + pow(s, 40.0) * 0.8;
		cor += cor_sol * halo * (1.0 - t2 * 0.7);
		// disco do sol
		cor += cor_sol * 6.0 * smoothstep(0.9993, 0.9997, s);

		// nuvens
		vec2 uv = d.xz / (h + 0.12);
		uv = uv * 0.9 + vec2(tempo_nuvem * 0.01, 0.0);
		float n = fbm(uv * 1.3);
		n = n * 0.65 + fbm(uv * 4.0 + 3.1) * 0.35;
		float densidade = smoothstep(1.0 - cobertura - 0.15, 1.0 - cobertura + 0.25, n);
		densidade *= smoothstep(0.0, 0.08, h);
		float lado_sol = pow(s, 3.0);
		vec3 nuvem = mix(cor_nuvem_sombra, cor_nuvem_luz, clamp(lado_sol * 1.4 + (1.0 - t1) * 0.35 - n * 0.25, 0.0, 1.0));
		nuvem += cor_sol * pow(s, 12.0) * 0.8 * (1.0 - densidade);
		cor = mix(cor, nuvem, densidade * 0.92);

		// estrelas
		if (estrelas > 0.0) {
			vec2 su = d.xz / (h + 0.3) * 160.0;
			float st = step(0.997, hash(floor(su)));
			cor += vec3(st) * estrelas * smoothstep(0.1, 0.4, h) * (1.0 - densidade);
		}
	} else {
		cor = mix(cor_horizonte * 0.6, cor_chao, smoothstep(0.0, 0.1, -h));
	}
	COLOR = cor;
}

shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
// Folhagem em cartões: o formato das folhas é desenhado no próprio shader (sem imagem).
uniform vec3 cor_a : source_color = vec3(0.13, 0.2, 0.07);
uniform vec3 cor_b : source_color = vec3(0.24, 0.3, 0.1);
uniform int estilo = 0;          // 0 folhosa, 1 agulhas (pinheiro), 2 samambaia
uniform float vento = 1.0;
uniform float tempo = 0.0;
varying vec3 tinta;
varying vec3 wpos;

float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	tinta = COLOR.rgb;
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = tempo + base.x * 0.13 + base.z * 0.09;
	float alt = max(VERTEX.y, 0.0);
	float bal = (sin(t * 1.3 + VERTEX.x) * 0.5 + sin(t * 2.7 + VERTEX.z) * 0.25) * vento * 0.012 * alt;
	VERTEX.x += bal;
	VERTEX.z += bal * 0.6;
}

void fragment() {
	vec2 uv = UV;
	float a = 0.0;
	if (estilo == 0) {
		// aglomerado de folhas: muitas manchas arredondadas
		vec2 g = uv * 7.0;
		vec2 id = floor(g);
		float melhor = 0.0;
		for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
			vec2 c = id + vec2(float(x), float(y));
			vec2 centro = c + vec2(hash(c), hash(c + 7.0));
			float d = length((g - centro) * vec2(1.0, 1.6));
			melhor = max(melhor, 1.0 - smoothstep(0.35, 0.55, d));
		}
		float borda = 1.0 - smoothstep(0.35, 0.5, length(uv - 0.5));
		a = melhor * borda;
	} else if (estilo == 1) {
		// agulhas: listras finas a partir do centro do galho
		float x = abs(uv.x - 0.5) * 2.0;
		float linhas = step(0.45, fract((uv.y + x * 0.6) * 22.0));
		a = linhas * (1.0 - smoothstep(0.75, 1.0, x)) * smoothstep(0.0, 0.15, uv.y) * (1.0 - smoothstep(0.85, 1.0, uv.y));
		a = max(a, 1.0 - smoothstep(0.02, 0.05, abs(uv.x - 0.5)));
	} else {
		// samambaia: folíolos ao longo da nervura
		float x = abs(uv.x - 0.5) * 2.0;
		float larg = (1.0 - uv.y) * 0.9;
		float fol = step(0.35, fract(uv.y * 14.0 - x * 2.0));
		a = step(x, larg) * fol;
		a = max(a, 1.0 - smoothstep(0.015, 0.04, abs(uv.x - 0.5)));
	}
	if (a < 0.5) discard;
	float v = noise(uv * 9.0 + wpos.xz * 0.1);
	vec3 c = mix(cor_a, cor_b, v) * tinta;
	c *= 0.75 + 0.35 * uv.y;
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = c * 0.6;
}

shader_type spatial;
render_mode cull_disabled;
// Estrada de terra: duas trilhas de pneu, capim no meio e bordas irregulares. UV.x = 0..1 na largura.

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

void fragment() {
	float x = UV.x;
	float v = UV.y;
	float grao = noise(vec2(x * 30.0, v * 4.0));
	float mancha = noise(vec2(x * 3.0, v * 0.3));
	vec3 terra = mix(vec3(0.33, 0.25, 0.17), vec3(0.42, 0.33, 0.22), mancha) * (0.85 + grao * 0.3);
	float trilha = 1.0 - smoothstep(0.06, 0.12, abs(abs(x - 0.5) - 0.24));
	terra = mix(terra, terra * 0.72, trilha);
	float meio = 1.0 - smoothstep(0.06, 0.13, abs(x - 0.5));
	terra = mix(terra, vec3(0.27, 0.3, 0.14) * (0.8 + grao * 0.4), meio * 0.7 * step(0.4, noise(vec2(v * 0.8, 1.0))));
	float borda = smoothstep(0.0, 0.18, min(x, 1.0 - x) + (noise(vec2(v * 0.7, x)) - 0.5) * 0.15);
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ALBEDO = terra;
	ALPHA = borda;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}

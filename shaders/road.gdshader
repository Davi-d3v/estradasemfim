shader_type spatial;
// Asfalto velho: rachaduras, remendos, faixas apagadas e bordas esfareladas.
// UV.x = 0..1 através da pista; UV.y = metros ao longo da estrada.

uniform float largura = 8.0;

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
		p = p * 2.07 + vec2(3.1, 7.7);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = vec2(UV.x * largura, UV.y);
	float var_ = fbm(p * 0.35);
	float grao = noise(p * 40.0);
	vec3 asfalto = vec3(0.16, 0.155, 0.15) * (0.75 + var_ * 0.5) * (0.92 + grao * 0.16);

	// remendos
	float remendo = smoothstep(0.62, 0.64, fbm(p * 0.12 + 11.0));
	asfalto = mix(asfalto, vec3(0.09, 0.09, 0.09) * (0.9 + grao * 0.2), remendo * 0.85);

	// rachaduras
	float r1 = abs(fbm(p * 0.45) - 0.5);
	float r2 = abs(fbm(p * 1.1 + 5.0) - 0.5);
	float mascara = smoothstep(0.35, 0.6, fbm(p * 0.08 + 2.0));
	float rach = (1.0 - smoothstep(0.0, 0.02, r1)) * mascara + (1.0 - smoothstep(0.0, 0.014, r2)) * (mascara * 0.6 + 0.25);
	asfalto = mix(asfalto, vec3(0.04, 0.04, 0.035), clamp(rach, 0.0, 1.0));

	// faixas
	float desgaste = smoothstep(0.25, 0.7, fbm(p * 0.9 + 20.0));
	float centro = (1.0 - smoothstep(0.06, 0.08, abs(p.x - largura * 0.5))) * step(fract(p.y / 12.0), 0.5);
	float borda = (1.0 - smoothstep(0.05, 0.07, abs(p.x - 0.55))) + (1.0 - smoothstep(0.05, 0.07, abs(p.x - (largura - 0.55))));
	asfalto = mix(asfalto, vec3(0.78, 0.62, 0.16), centro * desgaste * 0.85);
	asfalto = mix(asfalto, vec3(0.75, 0.74, 0.7), borda * desgaste * 0.7);

	// bordas esfareladas com terra
	float dist_borda = min(p.x, largura - p.x);
	float esf = smoothstep(0.0, 0.5, dist_borda + (fbm(p * 1.5) - 0.5) * 0.8);
	vec3 terra = vec3(0.28, 0.23, 0.17) * (0.8 + grao * 0.3);
	vec3 cor = mix(terra, asfalto, esf);

	ALBEDO = cor;
	ROUGHNESS = mix(1.0, 0.92, esf) - remendo * 0.05;
	SPECULAR = 0.18;
}

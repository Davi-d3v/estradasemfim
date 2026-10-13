shader_type spatial;
// Pintura de veículo desgastada: sujeira subindo do chão, ferrugem, arranhões e manchas.
// Usa a posição local (triplanar simples) para não precisar de UV.

uniform vec3 cor : source_color = vec3(0.78, 0.38, 0.1);
uniform float condicao : hint_range(0.0, 1.0) = 0.6;
uniform float rugosidade = 0.65;
uniform float metalico = 0.1;
uniform float altura_sujeira = 1.1;
uniform float escala = 1.0;
uniform mat4 inv_raiz = mat4(1.0);

varying vec3 lpos;
varying vec3 lnorm;

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
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.13 + vec2(3.1, 7.7);
		a *= 0.5;
	}
	return v;
}
float tri(vec3 p, vec3 n, float s) {
	vec3 w = abs(n);
	w /= (w.x + w.y + w.z);
	return fbm(p.yz * s) * w.x + fbm(p.xz * s) * w.y + fbm(p.xy * s) * w.z;
}

void vertex() {
	mat4 m = inv_raiz * MODEL_MATRIX;
	lpos = (m * vec4(VERTEX, 1.0)).xyz * escala;
	lnorm = normalize(mat3(m) * NORMAL);
}

void fragment() {
	float desgaste = 1.0 - condicao;
	float n_grande = tri(lpos, lnorm, 1.6);
	float n_fino = tri(lpos, lnorm, 9.0);
	float n_micro = tri(lpos, lnorm, 35.0);

	vec3 c = cor * (0.88 + n_grande * 0.22);
	// desbotado pelo sol nas superfícies de cima
	c = mix(c, c * vec3(1.05, 1.0, 0.92) + 0.06, clamp(lnorm.y, 0.0, 1.0) * 0.35);

	// ferrugem em manchas
	float ferr = smoothstep(0.62 - desgaste * 0.22, 0.7 - desgaste * 0.18, n_grande * 0.6 + n_fino * 0.4);
	vec3 cor_ferr = mix(vec3(0.3, 0.13, 0.05), vec3(0.45, 0.24, 0.1), n_micro);
	c = mix(c, cor_ferr, ferr * (0.4 + desgaste * 0.6));

	// arranhões finos
	float arr = smoothstep(0.985 - desgaste * 0.02, 1.0, noise(vec2(lpos.x * 2.0 + lpos.z * 30.0, lpos.y * 60.0)));
	c = mix(c, vec3(0.55, 0.53, 0.5), arr * 0.5);

	// sujeira e lama subindo do chão
	float suj = 1.0 - smoothstep(altura_sujeira * 0.35, altura_sujeira, lpos.y + (n_fino - 0.5) * 0.5);
	vec3 lama = vec3(0.24, 0.19, 0.14) * (0.8 + n_micro * 0.4);
	c = mix(c, lama, suj * (0.55 + desgaste * 0.35));
	// poeira geral
	c = mix(c, vec3(0.38, 0.33, 0.27), 0.12 + desgaste * 0.12);

	ALBEDO = c;
	ROUGHNESS = clamp(rugosidade + ferr * 0.3 + suj * 0.25 - n_micro * 0.1, 0.0, 1.0);
	METALLIC = metalico * (1.0 - ferr) * (1.0 - suj);
}

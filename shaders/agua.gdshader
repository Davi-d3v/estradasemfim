shader_type spatial;
render_mode cull_disabled;
// Água parada/barrenta com leve ondulação.
uniform vec3 cor : source_color = vec3(0.16, 0.2, 0.18);
uniform float tempo = 0.0;
varying vec3 wpos;

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
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wpos.xz * 0.35 + vec2(tempo * 0.05, tempo * 0.03);
	float n = noise(p) * 0.6 + noise(p * 3.1) * 0.4;
	NORMAL = normalize(vec3((n - 0.5) * 0.15, 1.0, (noise(p + 7.0) - 0.5) * 0.15));
	NORMAL = (VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	ALBEDO = cor * (0.85 + n * 0.3);
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	ALPHA = 0.88;
}

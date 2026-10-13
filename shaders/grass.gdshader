shader_type spatial;
render_mode cull_disabled;
// Capim alto com vento. UV.y = 0 na base, 1 na ponta.

uniform float vento = 1.0;
uniform float tempo = 0.0;
uniform vec3 cor_base : source_color = vec3(0.12, 0.13, 0.05);
uniform vec3 cor_ponta : source_color = vec3(0.55, 0.47, 0.24);
varying float altura;
varying vec3 tinta;

void vertex() {
	altura = UV.y;
	tinta = COLOR.rgb;
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = tempo + w.x * 0.15 + w.z * 0.11;
	float b = (sin(t * 1.7) * 0.6 + sin(t * 3.1) * 0.25) * vento * UV.y * UV.y * 0.18;
	VERTEX.x += b;
	VERTEX.z += b * 0.4;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec3 c = mix(cor_base, cor_ponta, altura) * tinta;
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	BACKLIGHT = vec3(0.35, 0.3, 0.12) * altura;
}

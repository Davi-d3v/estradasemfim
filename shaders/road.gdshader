shader_type spatial;
// Asfalto velho: rachaduras, remendos, faixas apagadas e bordas esfareladas.
// UV.x = 0..1 através da pista; UV.y = metros ao longo da estrada.

uniform float largura = 8.0;
uniform float molhado = 0.0;   // chuva: asfalto escuro e brilhante, poças
uniform float neve = 0.0;      // neve acumulando nas bordas e no meio
// foto de asfalto (ambientCG Road008B, CC0): pista inteira com faixa amarela no meio
uniform bool tem_tex = false;
uniform sampler2D tex_cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

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
	vec3 n_tex = vec3(0.0, 0.0, 1.0);
	float rough_tex = 1.0;
	if (tem_tex) {
		// a foto já tem asfalto, remendos e a faixa do meio; as bordas viram brancas (padrão brasileiro)
		vec2 st = vec2(UV.x, UV.y / largura);
		vec3 ft = texture(tex_cor, st).rgb;
		float amarelo = clamp((ft.r - ft.b) * 3.0 - 0.3, 0.0, 1.0);
		float na_borda = 1.0 - smoothstep(0.03, 0.06, min(UV.x, 1.0 - UV.x));
		ft = mix(ft, vec3(0.72, 0.71, 0.67) * (0.8 + grao * 0.25), amarelo * na_borda);
		ft = mix(ft, ft * vec3(0.8, 0.82, 0.9), amarelo * (1.0 - na_borda) * (1.0 - desgaste) * 0.6);  // faixa apagada
		asfalto = mix(ft * (0.85 + var_ * 0.3), asfalto, 0.25);
		n_tex = texture(tex_normal, st).rgb * 2.0 - 1.0;
		rough_tex = texture(tex_rough, st).r;
	} else {
		float centro = (1.0 - smoothstep(0.06, 0.08, abs(p.x - largura * 0.5))) * step(fract(p.y / 12.0), 0.5);
		float borda = (1.0 - smoothstep(0.05, 0.07, abs(p.x - 0.55))) + (1.0 - smoothstep(0.05, 0.07, abs(p.x - (largura - 0.55))));
		asfalto = mix(asfalto, vec3(0.78, 0.62, 0.16), centro * desgaste * 0.85);
		asfalto = mix(asfalto, vec3(0.75, 0.74, 0.7), borda * desgaste * 0.7);
	}

	// bordas esfareladas com terra
	float dist_borda = min(p.x, largura - p.x);
	float esf = smoothstep(0.0, 0.5, dist_borda + (fbm(p * 1.5) - 0.5) * 0.8);
	vec3 terra = vec3(0.28, 0.23, 0.17) * (0.8 + grao * 0.3);
	vec3 cor = mix(terra, asfalto, esf);

	float rough = mix(1.0, 0.92, esf) - remendo * 0.05;
	float spec = 0.18;
	// molhado: escurece, poças nos remendos e nas depressões
	float poca = smoothstep(0.55, 0.62, fbm(p * 0.22 + 31.0)) * esf;
	cor *= 1.0 - molhado * 0.38;
	rough = mix(rough, 0.28, molhado * esf);
	rough = mix(rough, 0.05, molhado * poca);
	spec = mix(spec, 0.6, molhado * esf);
	// neve: cobre as bordas primeiro, deixa os trilhos dos pneus escuros
	float trilho = 1.0 - smoothstep(0.35, 0.7, abs(abs(p.x - largura * 0.5) - largura * 0.25));
	float cobre = clamp(neve * 1.4 - trilho * 0.6 + (fbm(p * 0.6) - 0.5) * 0.5, 0.0, 1.0);
	cor = mix(cor, vec3(0.86, 0.88, 0.92), cobre);
	rough = mix(rough, 0.8, cobre);
	if (tem_tex) {
		rough = mix(rough, rough_tex, 0.6 * (1.0 - molhado));
		// normal da foto: moldura tangente pelas derivadas (UV.x através, UV.y ao longo)
		vec2 st = vec2(UV.x, UV.y / largura);
		vec3 dp1 = dFdx(VERTEX);
		vec3 dp2 = dFdy(VERTEX);
		vec2 duv1 = dFdx(st);
		vec2 duv2 = dFdy(st);
		vec3 dp2p = cross(dp2, NORMAL);
		vec3 dp1p = cross(NORMAL, dp1);
		vec3 Tt = dp2p * duv1.x + dp1p * duv2.x;
		vec3 Bb = dp2p * duv1.y + dp1p * duv2.y;
		float im = inversesqrt(max(max(dot(Tt, Tt), dot(Bb, Bb)), 1e-12));
		vec3 nn = normalize(mat3(Tt * im, Bb * im, NORMAL) * vec3(n_tex.x, -n_tex.y, max(n_tex.z, 0.2)));
		float longe = clamp(length(VERTEX) / 60.0, 0.0, 1.0);
		NORMAL = normalize(mix(nn, NORMAL, longe * 0.6 + cobre * 0.8 + molhado * poca));
	}
	ALBEDO = cor;
	ROUGHNESS = rough;
	SPECULAR = spec;
}

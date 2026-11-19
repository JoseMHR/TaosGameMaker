shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 color_depth : source_color = vec4(0.015, 0.008, 0.035, 1.0);
uniform vec4 color_rift_dark : source_color = vec4(0.18, 0.04, 0.35, 1.0);
uniform vec4 color_rift_bright : source_color = vec4(0.48, 0.12, 0.85, 1.0);
uniform vec4 color_energy_cyan : source_color = vec4(0.05, 0.85, 0.95, 1.0);

uniform float swirl_speed : hint_range(0.01, 1.0) = 0.08;
uniform float emission_strength : hint_range(0.2, 5.0) = 2.0;

vec2 rotate_uv(vec2 uv, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return vec2(c * uv.x - s * uv.y, s * uv.x + c * uv.y);
}

// Hash procedural 2D
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
	               dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
	           mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
	               dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Sutil ondulación espacial casi imperceptible
	VERTEX.y += sin(world_pos.x * 0.4 + TIME * swirl_speed * 1.5) * cos(world_pos.z * 0.4 + TIME * swirl_speed * 1.2) * 0.06;
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = world_pos.xz * 0.08;
	
	// Capa 1: Torbellino en sentido horario
	vec2 rot1 = rotate_uv(p, TIME * swirl_speed * 0.4);
	float n1 = noise2d(rot1 * 2.5 + vec2(TIME * swirl_speed * 0.3));
	
	// Capa 2: Niebla dimensional en sentido antihorario
	vec2 rot2 = rotate_uv(p * 1.4, -TIME * swirl_speed * 0.3);
	float n2 = noise2d(rot2 * 3.2 - vec2(n1 * 0.8));
	
	float neb = clamp((n1 * 0.5 + n2 * 0.5) * 0.5 + 0.5, 0.0, 1.0);
	
	// Vetas de energía cósmica
	float energy_line = smoothstep(0.44, 0.50, neb) * (1.0 - smoothstep(0.50, 0.58, neb));
	
	// Gradiente: Fondo infinito -> Púrpura oscuro -> Violeta brillante
	vec3 col = mix(color_depth.rgb, color_rift_dark.rgb, smoothstep(0.15, 0.55, neb));
	col = mix(col, color_rift_bright.rgb, smoothstep(0.50, 0.85, neb));
	
	// Añadir vetas de energía cian/eléctrica
	col = mix(col, color_energy_cyan.rgb, energy_line * 0.85);
	
	// Micro-estrellas parpadeantes
	vec2 star_uv = fract(p * 12.0) - 0.5;
	float star_dist = length(star_uv);
	float star_h = fract(sin(dot(floor(p * 12.0), vec2(12.9898, 78.233))) * 43758.5453);
	if (star_h > 0.94) {
		float twinkle = 0.5 + 0.5 * sin(TIME * 3.0 + star_h * 50.0);
		float star = (1.0 - smoothstep(0.0, 0.12, star_dist)) * twinkle;
		col += color_energy_cyan.rgb * star * 1.5;
	}

	ALBEDO = col;
	METALLIC = 0.2;
	ROUGHNESS = 0.4;
	SPECULAR = 0.4;
	
	// Emisión que aporta la sensación de grieta dimensional
	float em_mask = smoothstep(0.3, 0.9, neb) + energy_line * 1.5;
	EMISSION = col * em_mask * emission_strength * (0.8 + 0.25 * sin(TIME * 1.5));
}

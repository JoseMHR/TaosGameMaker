shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 lava_color_deep : source_color = vec4(0.35, 0.02, 0.0, 1.0);
uniform vec4 lava_color_bright : source_color = vec4(1.0, 0.35, 0.0, 1.0);
uniform vec4 lava_crust_color : source_color = vec4(0.06, 0.05, 0.05, 1.0);

uniform float flow_speed : hint_range(0.01, 1.0) = 0.05;
uniform float uv_scale : hint_range(1.0, 30.0) = 4.0;
uniform float emission_intensity : hint_range(0.0, 8.0) = 2.8;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453123);
}

float voronoi_abyss(vec2 p, float t) {
	vec2 g = floor(p);
	vec2 f = fract(p);
	float min_dist = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 lattice = vec2(float(x), float(y));
			vec2 offset = hash2(g + lattice);
			offset = 0.5 + 0.5 * sin(t + 6.2831 * offset);
			vec2 dist_vec = lattice + offset - f;
			min_dist = min(min_dist, length(dist_vec));
		}
	}
	return min_dist;
}

void fragment() {
	vec2 uv_flow = UV * uv_scale + vec2(TIME * flow_speed, TIME * flow_speed * 0.3);
	float pattern = voronoi_abyss(uv_flow, TIME * 0.3);
	float mask = smoothstep(0.05, 0.35, pattern);

	vec3 magma = mix(lava_color_bright.rgb, lava_color_deep.rgb, smoothstep(0.0, 0.25, mask));
	vec3 final_albedo = mix(magma, lava_crust_color.rgb, smoothstep(0.15, 0.4, mask));

	ALBEDO = final_albedo;
	ROUGHNESS = 0.85;
	METALLIC = 0.0;

	float glow = 1.0 - smoothstep(0.05, 0.3, mask);
	EMISSION = lava_color_bright.rgb * glow * emission_intensity;
}
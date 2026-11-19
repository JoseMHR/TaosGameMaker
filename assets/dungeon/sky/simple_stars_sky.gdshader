shader_type sky;
void sky() {
	vec3 d = normalize(EYEDIR);
	float up = clamp(d.y * 0.5 + 0.5, 0.0, 1.0);
	
	// Fondo noche oscura y limpia
	vec3 base = mix(vec3(0.010, 0.012, 0.022), vec3(0.002, 0.003, 0.006), up);
	
	// Estrellas puntuales anti-aliased
	vec2 uv = vec2(atan(d.x, d.z) * 2.0, asin(clamp(d.y, -1.0, 1.0)) * 2.0);
	vec2 g_uv = uv * 36.0;
	vec2 ipos = floor(g_uv);
	vec2 fpos = fract(g_uv);
	
	float h = fract(sin(dot(ipos, vec2(12.9898, 78.233))) * 43758.5453);
	float dist = length(fpos - 0.5);
	
	float star_mask = step(0.982, h);
	float tw = 0.5 + 0.5 * sin(TIME * 2.5 + h * 90.0);
	
	float star = star_mask * (1.0 - smoothstep(0.0, 0.32, dist)) * tw;
	vec3 star_color = vec3(star) * mix(vec3(0.85, 0.92, 1.0), vec3(1.0, 0.95, 0.8), fract(h * 15.0));
	
	COLOR = base + star_color * 1.6;
}

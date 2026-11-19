shader_type sky;
void sky() {
	vec3 d = normalize(EYEDIR);
	float up = clamp(d.y * 0.5 + 0.5, 0.0, 1.0);
	
	// Fondo astral profundo: púrpura cósmico oscuro
	vec3 base = mix(vec3(0.016, 0.005, 0.032), vec3(0.003, 0.001, 0.007), up);
	
	// Rayitos de energía psíquica morados y arcos eléctricos dinámicos
	vec2 uv = vec2(atan(d.x, d.z) * 1.5, asin(clamp(d.y, -1.0, 1.0)) * 2.0);
	float t = TIME * 1.6;
	
	float bolt1 = abs(sin(uv.x * 5.0 + sin(uv.y * 7.0 + t * 2.2) * 1.4 + t));
	float ray1 = pow(1.0 - clamp(bolt1 * 1.3, 0.0, 1.0), 16.0);
	
	float bolt2 = abs(cos(uv.x * 4.0 - cos(uv.y * 5.0 - t * 1.8) * 1.2 - t * 1.2));
	float ray2 = pow(1.0 - clamp(bolt2 * 1.5, 0.0, 1.0), 18.0);
	
	float bolt3 = abs(sin((uv.x * 1.5 + uv.y * 2.0) * 4.0 + sin(t * 2.8) * 0.9));
	float ray3 = pow(1.0 - clamp(bolt3 * 1.6, 0.0, 1.0), 20.0);
	
	vec3 purple_bolt = vec3(0.88, 0.18, 1.0);
	vec3 cyan_spark = vec3(0.25, 0.70, 1.0);
	vec3 magenta_pulse = vec3(1.0, 0.22, 0.75);
	
	vec3 energy_rays = (ray1 * purple_bolt * 2.6) + (ray2 * cyan_spark * 1.5) + (ray3 * magenta_pulse * 2.2);
	
	// Estrellitas sutiles de fondo
	vec2 g_uv = uv * 32.0;
	vec2 ipos = floor(g_uv);
	vec2 fpos = fract(g_uv);
	float h = fract(sin(dot(ipos, vec2(12.9898, 78.233))) * 43758.5453);
	float star_mask = step(0.985, h);
	float tw = 0.5 + 0.5 * sin(TIME * 3.0 + h * 60.0);
	float star = star_mask * (1.0 - smoothstep(0.0, 0.30, length(fpos - 0.5))) * tw;
	vec3 stars = vec3(star) * vec3(0.9, 0.7, 1.0);
	
	COLOR = base + energy_rays + stars;
}

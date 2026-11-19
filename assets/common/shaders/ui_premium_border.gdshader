shader_type canvas_item;

// ui_premium_border.gdshader
// ─────────────────────────────────────────────────────────────────────────────
// MARCO PREMIUM REUTILIZABLE (task_newdesign.md, PARTE B).
// Se aplica sobre un ColorRect que cubre el rect completo de un panel/HUD/modal
// (ver UiKit.premium_frame). Sustituye a los bordes planos de 1px de
// StyleBoxFlat por un marco grueso con relieve (bisel), degradado de dos
// colores, brillo animado recorriendo el perímetro y (opcional) rotación de
// matiz continua para el theme "happyflower". Todo vía SDF de rectángulo
// redondeado: nítido a cualquier tamaño, sin texturas ni assets externos.
// ─────────────────────────────────────────────────────────────────────────────

uniform vec4 border_color : source_color = vec4(0.961, 0.769, 0.420, 1.0);
uniform vec4 border_color_2 : source_color = vec4(0.725, 0.467, 0.039, 1.0);
uniform vec4 bg_color : source_color = vec4(0.04, 0.035, 0.07, 0.96);
uniform float border_width : hint_range(0.0, 40.0) = 5.0;
uniform float corner_radius : hint_range(0.0, 100.0) = 14.0;
uniform float bevel_strength : hint_range(0.0, 1.0) = 0.5;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.35;
uniform float sweep_speed : hint_range(0.0, 3.0) = 0.15;
uniform float hue_shift_speed : hint_range(0.0, 3.0) = 0.0;
// 0.0 congela TODA la animación (brillo/pulso/matiz) — accesibilidad
// (Locale.reduce_motion, ver UiKit.premium_frame).
uniform float time_scale : hint_range(0.0, 1.0) = 1.0;
// Tamaño del rect en píxeles; UiKit.premium_frame lo mantiene sincronizado con
// el tamaño real del ColorRect (necesario porque UV no basta para SDF en px).
uniform vec2 rect_size = vec2(200.0, 100.0);
// Mosaico/filigrana tallada en el propio marco (task_themes.md, FASE 1):
// frecuencia de las teselas (más alto = piezas más pequeñas/numerosas) e
// intensidad de su relieve/grietas. mosaic_strength = 0.0 desactiva el
// efecto por completo (coste cero extra), tal como quedaban los themes
// anteriores a esta expansión.
uniform float mosaic_scale : hint_range(1.0, 50.0) = 18.0;
uniform float mosaic_strength : hint_range(0.0, 1.0) = 0.0;

// SDF de rectángulo redondeado centrado en el origen (`p` en píxeles relativos
// al centro). Negativo = dentro del rectángulo, positivo = fuera.
float sdf_round_rect(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + radius;
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
}

// Rotación de matiz aproximada (matriz YIQ), usada solo por el theme
// "happyflower" (hue_shift_speed > 0 en el resto de themes es 0 -> sin coste).
vec3 hue_shift(vec3 color, float shift) {
	float angle = shift * 6.2831853;
	float s = sin(angle);
	float c = cos(angle);
	mat3 m = mat3(
		vec3(0.299, 0.587, 0.114),
		vec3(0.596, -0.274, -0.322),
		vec3(0.211, -0.523, 0.312)
	);
	mat3 mi = inverse(m);
	vec3 yiq = m * color;
	float i2 = yiq.y * c - yiq.z * s;
	float q2 = yiq.y * s + yiq.z * c;
	return mi * vec3(yiq.x, i2, q2);
}

void fragment() {
	vec2 px = UV * rect_size;
	vec2 half_size = rect_size * 0.5;
	vec2 p = px - half_size;
	float r = min(corner_radius, min(half_size.x, half_size.y));
	float bw = min(border_width, min(half_size.x, half_size.y));

	float d = sdf_round_rect(p, half_size, r);
	float d_inner = sdf_round_rect(p, half_size - bw, max(r - bw, 0.0));

	// 1.0 = totalmente fuera del panel completo (borde+relleno); 0.0 = dentro.
	float outside = smoothstep(0.0, 1.5, d);
	float inside_all = 1.0 - outside;
	// 1.0 en la banda del borde (entre el filo exterior y el filo interior);
	// 0.0 en el relleno interior. Multiplicado por inside_all para no afectar
	// nada fuera del panel.
	float border_mask = smoothstep(0.0, 1.5, d_inner) * inside_all;

	float t_time = TIME * time_scale;

	// Pulso sutil de vida (glow "respirando"): con time_scale=0 (reduce_motion)
	// queda fijo en 0.85, sin animar.
	float pulse = 0.85 + 0.15 * sin(t_time * 1.6);

	// Brillo (sweep) que recorre el perímetro: aproximamos la posición en el
	// perímetro con el ángulo respecto al centro (barato y visualmente correcto
	// para un marco de HUD; no necesita ser exactamente longitud de arco).
	float ang = atan(p.y, p.x) / 6.2831853 + 0.5;
	float sweep_pos = fract(ang - t_time * sweep_speed);
	float sweep = pow(max(0.0, 1.0 - abs(sweep_pos - 0.5) * 12.0), 3.0);

	// Bisel/relieve: normal aproximada del SDF -> luz arriba-izquierda, sombra
	// abajo-derecha, como un marco tallado en relieve.
	vec2 eps = vec2(0.75, 0.0);
	float dx = sdf_round_rect(p + eps.xy, half_size, r) - sdf_round_rect(p - eps.xy, half_size, r);
	float dy = sdf_round_rect(p + eps.yx, half_size, r) - sdf_round_rect(p - eps.yx, half_size, r);
	vec2 normal = normalize(vec2(dx, dy) + 1e-5);
	float light = clamp(dot(normal, normalize(vec2(-0.6, -0.75))), -1.0, 1.0);
	float bevel = light * bevel_strength;

	// Degradado de dos colores (y de sus canales alfa) a lo largo del grosor
	// del borde (doble filo). Respetar la alfa de border_color/border_color_2
	// es necesario para que los llamantes puedan atenuar/pulsar el marco
	// (p. ej. NarrativeOverlay._glow_panel) sin depender solo de glow_strength.
	float border_t = clamp(d_inner / max(bw, 0.001) + 0.5, 0.0, 1.0);
	vec3 border_base = mix(border_color.rgb, border_color_2.rgb, border_t);
	float border_alpha = mix(border_color.a, border_color_2.a, border_t);
	if (hue_shift_speed > 0.0) {
		border_base = hue_shift(border_base, fract(t_time * hue_shift_speed * 0.12 + ang));
	}
	vec3 border_final = border_base + vec3(bevel * 0.35);
	border_final += vec3(1.0, 0.95, 0.85) * sweep * glow_strength * pulse;

	// Mosaico/filigrana tallada (task_themes.md, FASE 1): cuadrícula de teselas
	// engastadas dentro del propio borde, con variación por pieza (evita el
	// aspecto uniforme de una rejilla perfecta) y grietas que el barrido de luz
	// (sweep) resalta a su paso, como si la energía fluyera por las juntas.
	if (mosaic_strength > 0.0) {
		vec2 tile_uv = fract(px * (mosaic_scale / min(rect_size.x, rect_size.y)));
		vec2 tile_edge = abs(tile_uv - 0.5);
		float tile_border = smoothstep(0.38, 0.48, max(tile_edge.x, tile_edge.y));
		float tile_variance = sin(floor(px.x * 0.08) * 12.9898 + floor(px.y * 0.08) * 78.233) * 0.1;
		border_final += vec3(tile_variance) * mosaic_strength;
		border_final -= vec3(tile_border) * mosaic_strength;
		border_final += vec3(1.0, 0.95, 0.85) * sweep * tile_border * mosaic_strength * pulse;
	}

	vec3 col = mix(bg_color.rgb, border_final, border_mask);
	float alpha = mix(bg_color.a, border_alpha, border_mask) * inside_all;

	COLOR = vec4(col, alpha);
}

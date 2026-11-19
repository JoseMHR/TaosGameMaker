shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D water_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.92, 1.04, 1.18);
uniform float rough : hint_range(0.0, 1.0) = 0.08;
uniform float metal : hint_range(0.0, 1.0) = 0.06;
uniform vec2 uv_scroll = vec2(0.018, 0.014);
uniform float uv_scale : hint_range(0.01, 5.0) = 0.333333; // 1.0 / 3.0: 1 textura por celda de 3m
uniform float wave_amp : hint_range(0.0, 0.1) = 0.020;
uniform vec3 caustic_color : source_color = vec3(0.35, 0.85, 1.0); // Resplandor azul cristalino
uniform float caustic_energy : hint_range(0.0, 5.0) = 0.9;
uniform float caustic_pulse : hint_range(0.0, 2.0) = 0.35;

// Compatibilidad con asignaciones heredadas
uniform vec2 flow_direction = vec2(0.0, 0.0);
uniform float wave_distortion = 0.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Base UV continua por posición en el mundo para unir celdas adyacentes sin costuras
	vec2 base_uv = v_world.xz * uv_scale;
	vec2 scroll = (flow_direction != vec2(0.0)) ? flow_direction : uv_scroll;

	float effective_wave = (wave_distortion > 0.0) ? wave_distortion : wave_amp;
	vec2 wave_offset = vec2(0.0);
	if (effective_wave > 0.0) {
		wave_offset = vec2(
			sin(TIME * 2.2 + v_world.z * uv_scale * 3.14159) * effective_wave,
			cos(TIME * 1.8 + v_world.x * uv_scale * 3.14159) * effective_wave
		);
	}

	vec2 uv1 = base_uv + TIME * scroll + wave_offset;
	vec2 uv2 = base_uv * 1.2 - TIME * scroll * 0.7 + wave_offset * 0.6 + vec2(0.35, 0.55);

	vec4 tx1 = texture(water_texture, uv1);
	vec4 tx2 = texture(water_texture, uv2);
	vec3 blended_albedo = mix(tx1.rgb, tx2.rgb, 0.35) * tint;

	ALBEDO = blended_albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.85;

	// Destellos cáusticos de agua pura y cristalina que bailan con la luz
	float pulse = caustic_energy + sin(TIME * 2.0 + v_world.x * 0.4 + v_world.z * 0.4) * caustic_pulse;
	float caustic_mask = clamp(pow(tx1.r, 1.5) * 1.5, 0.0, 1.0);
	EMISSION = blended_albedo * caustic_color * pulse * caustic_mask;
}

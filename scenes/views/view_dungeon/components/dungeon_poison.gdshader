shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D poison_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.95, 1.15, 0.90);
uniform float rough : hint_range(0.0, 1.0) = 0.14;
uniform float metal : hint_range(0.0, 1.0) = 0.05;
uniform vec2 uv_scroll = vec2(0.016, -0.012);
uniform float uv_scale : hint_range(0.01, 5.0) = 0.333333; // 1.0 / 3.0: 1 textura por celda de 3m
uniform float wave_amp : hint_range(0.0, 0.1) = 0.024;
uniform vec3 emis_color : source_color = vec3(0.20, 0.90, 0.25); // Verde tóxico bioluminiscente
uniform float emis_energy : hint_range(0.0, 5.0) = 1.6;
uniform float emis_pulse : hint_range(0.0, 2.0) = 0.65;

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
			sin(TIME * 2.1 + v_world.z * uv_scale * 3.14159) * effective_wave,
			cos(TIME * 1.7 + v_world.x * uv_scale * 3.14159) * effective_wave
		);
	}

	vec2 uv1 = base_uv + TIME * scroll + wave_offset;
	vec2 uv2 = base_uv * 1.25 - TIME * scroll * 0.75 + wave_offset * 0.5 + vec2(0.4, 0.6);

	vec4 tx1 = texture(poison_texture, uv1);
	vec4 tx2 = texture(poison_texture, uv2);
	vec3 blended_albedo = mix(tx1.rgb, tx2.rgb, 0.3) * tint;

	ALBEDO = blended_albedo;
	ROUGHNESS = rough;
	METALLIC = metal;

	// Pulso lumínico orgánico: simula un fluido venenoso vivo que respira y emite luz química
	float pulse = emis_energy + sin(TIME * 2.5 + sin(v_world.x * 0.5 + v_world.z * 0.5)) * emis_pulse;
	float bright_mask = clamp(tx1.g * 1.2, 0.2, 1.0);
	EMISSION = blended_albedo * emis_color * pulse * bright_mask;
}

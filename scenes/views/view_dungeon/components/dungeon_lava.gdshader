shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D lava_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float rough : hint_range(0.0, 1.0) = 0.25;
uniform float metal : hint_range(0.0, 1.0) = 0.0;
uniform vec2 uv_scroll = vec2(0.025, -0.018);
uniform float uv_scale : hint_range(0.01, 5.0) = 0.333333; // 1.0 / 3.0: 1 textura por celda de 3m
uniform float wave_amp : hint_range(0.0, 0.1) = 0.02;
uniform vec3 emis_color : source_color = vec3(1.0, 0.333, 0.0); // #ff5500 del mapamundi
uniform float emis_energy : hint_range(0.0, 5.0) = 1.8;
uniform float emis_pulse : hint_range(0.0, 2.0) = 0.5;

// Compatibilidad con asignaciones heredadas
uniform vec2 flow_direction = vec2(0.0, 0.0);
uniform float wave_distortion = 0.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 base_uv = v_world.xz * uv_scale;
	vec2 scroll = (flow_direction != vec2(0.0)) ? flow_direction : uv_scroll;
	vec2 uv = base_uv + TIME * scroll;
	float effective_wave = (wave_distortion > 0.0) ? wave_distortion : wave_amp;
	if (effective_wave > 0.0) {
		uv += vec2(
			sin(TIME * 2.0 + v_world.z * uv_scale * 3.14159) * effective_wave,
			cos(TIME * 1.6 + v_world.x * uv_scale * 3.14159) * effective_wave
		);
	}
	vec4 tx = texture(lava_texture, uv);
	ALBEDO = tx.rgb * tint;
	ROUGHNESS = rough;
	METALLIC = metal;
	float pulse = emis_energy + sin(TIME * 3.0) * emis_pulse;
	EMISSION = tx.rgb * emis_color * pulse;
}
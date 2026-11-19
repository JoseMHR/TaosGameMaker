shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 albedo_color : source_color = vec4(0.82, 0.44, 0.18, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.75;
uniform float wind_speed = 2.0;
uniform float wind_strength = 0.015;

void vertex() {
	// Solo mueve los vértices superiores para simular tensión de lona sin costo adicional de texturas
	if (VERTEX.y > 0.2) {
		float wave = sin(TIME * wind_speed + VERTEX.x * 3.0 + VERTEX.z * 3.0);
		VERTEX.x += wave * wind_strength;
		VERTEX.z += wave * wind_strength;
	}
}

void fragment() {
	ALBEDO = albedo_color.rgb;
	ROUGHNESS = roughness;
}

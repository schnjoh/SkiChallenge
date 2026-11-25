shader_type spatial;
// Distant terrain rings: colour from the winterised orthophoto map (pipeline), slope-lit.
uniform sampler2D color_map : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 map_min;
uniform vec2 map_size;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (world_pos.xz - map_min) / map_size;
	vec3 col = texture(color_map, uv).rgb;
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.6, smoothstep(0.5, 0.85, lum));
}

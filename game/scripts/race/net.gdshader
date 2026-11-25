shader_type spatial;
// Safety net: procedural mesh pattern with alpha scissor (no texture asset needed).
render_mode cull_disabled, depth_prepass_alpha;

uniform vec4 net_color : source_color = vec4(0.9, 0.25, 0.1, 1.0);
uniform float mesh_size = 0.12;
uniform float strand = 0.18;
uniform float band_height = 0.12;

varying float v_height;

void vertex() {
	v_height = UV.y;
}

void fragment() {
	vec2 g = fract(UV2 / mesh_size);
	float line = step(1.0 - strand, max(abs(g.x - 0.5) * 2.0, abs(g.y - 0.5) * 2.0));
	// solid bands at the top and the bottom edge
	float band = step(1.0 - band_height, v_height) + step(v_height, band_height * 0.5);
	ALBEDO = net_color.rgb * (0.75 + 0.25 * band);
	ROUGHNESS = 0.8;
	ALPHA = clamp(line + band, 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}

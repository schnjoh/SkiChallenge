shader_type sky;
// HDRI sky without the HDRI's own ground: above `cut_deg` the panorama is used as is; below it the
// panorama row at `cut_deg` is stretched and blended into a horizon haze (the real terrain rings
// cover the ground, so the photographed hills of the HDRI must not show).
uniform sampler2D panorama : source_color, hint_default_black, filter_linear;
uniform float cut_deg = 12.0;
uniform float blend_deg = 6.0;
uniform vec3 haze_color : source_color = vec3(0.78, 0.84, 0.92);
uniform float energy = 1.0;
uniform float haze_energy = 1.05;

vec3 sample_dir(vec3 d) {
	float u = atan(d.x, -d.z) / (2.0 * PI) + 0.5;
	float v = acos(clamp(d.y, -1.0, 1.0)) / PI;
	return texture(panorama, vec2(u, v)).rgb;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float elev = degrees(asin(clamp(d.y, -1.0, 1.0)));
	vec3 col;
	if (elev >= cut_deg + blend_deg) {
		col = sample_dir(d);
	} else {
		float e = radians(cut_deg + blend_deg);
		vec2 h = normalize(d.xz);
		vec3 dc = vec3(h.x * cos(e), sin(e), h.y * cos(e));
		vec3 top = sample_dir(dc);
		float t = smoothstep(-2.0, cut_deg + blend_deg, elev);
		col = mix(haze_color * haze_energy, top, t);
	}
	COLOR = col * energy;
}

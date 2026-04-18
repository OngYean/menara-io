shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 10.0) = 0.0;
uniform float vignette_radius : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	// UV is 0.0 to 1.0 over the ColorRect
	float dist = distance(UV, vec2(0.5));
	// Only blur outside the vignette_radius
	float blur_strength = smoothstep(vignette_radius, 0.5, dist) * blur_amount;
	
	if (blur_strength < 0.01) {
		discard;
	} else {
		vec3 col = vec3(0.0);
		float count = 0.0;
		// 5x5 blur kernel
		for(float x = -2.0; x <= 2.0; x += 1.0) {
			for(float y = -2.0; y <= 2.0; y += 1.0) {
				vec2 offset = vec2(x, y) * SCREEN_PIXEL_SIZE * blur_strength;
				col += texture(screen_texture, SCREEN_UV + offset).rgb;
				count += 1.0;
			}
		}
		COLOR = vec4(col / count, 1.0);
	}
}

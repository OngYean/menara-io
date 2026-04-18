shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	if (intensity <= 0.0) {
		discard;
	} else {
		vec3 color = texture(screen_texture, SCREEN_UV).rgb;
		
		// Grayscale
		float gray = dot(color, vec3(0.299, 0.587, 0.114));
		vec3 moon_color = vec3(gray);
		
		// Add noise/grain
		float noise = hash(UV + vec2(TIME * 0.1, TIME * 0.15));
		moon_color += (noise - 0.5) * 0.15;
		
		// Add vertical scratches
		float scratch_x = hash(vec2(floor(UV.x * 200.0) + floor(TIME * 15.0), 0.0));
		if (scratch_x > 0.99) {
			moon_color += 0.2;
		}
		
		// Flicker (intensity variations)
		float flicker = 1.0 - (hash(vec2(TIME, 0.0)) * 0.1);
		moon_color *= flicker;
		
		// Slight contrast boost to make it look "blown out" like old footage
		moon_color = mix(vec3(0.5), moon_color, 1.2);
		
		COLOR = vec4(mix(color, moon_color, intensity), 1.0);
	}
}

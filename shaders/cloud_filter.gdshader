shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float speed = 1.0;
uniform float direction = 1.0;

// Pseudo-random value
float hash(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

// 2D Value Noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    // Cubic Hermite Curve
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i + vec2(0.0, 0.0));
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Fractional Brownian Motion
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

void fragment() {
    if (intensity < 0.01) {
        discard;
    }

    // Stretch UV horizontally for "wind" streaks
    vec2 uv = UV * vec2(2.0, 5.0);
    
    // Add scrolling based on time and direction. 
    // To move the texture in the direction of the force, we subtract from UV.
    uv.x -= TIME * speed * direction * 2.0;
    uv.y -= TIME * speed * 0.5; // Slight vertical drift
    
    // Combine two layers of fbm moving at different speeds
    float n1 = fbm(uv);
    // The second layer moves a bit faster in the same direction
    float n2 = fbm(uv * 1.5 - vec2(TIME * speed * direction * 1.5, 0.0));
    
    float final_noise = (n1 + n2) * 0.5;
    
    // Add some vignette to the clouds so it's heavier at edges
    float dist = distance(UV, vec2(0.5));
    float vignette = smoothstep(0.1, 0.7, dist);
    
    // Calculate final alpha
    float alpha = smoothstep(0.3, 0.7, final_noise) * intensity * (0.3 + vignette * 0.5);
    
    // Optional: make it denser at the top
    float top_gradient = smoothstep(0.8, 0.0, UV.y);
    alpha *= mix(1.0, top_gradient, 0.8);
    
    COLOR = vec4(0.85, 0.9, 0.95, alpha);
}

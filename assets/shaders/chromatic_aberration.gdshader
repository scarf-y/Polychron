shader_type canvas_item;

// Chromatic Aberration — separates R/B channels at screen edges.
// Makes the world look "broken" during Time Erase.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float aberration_amount : hint_range(0.0, 0.02) = 0.008;
uniform float time_val : hint_range(0.0, 1000.0) = 0.0;

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Distance from center — aberration is stronger at edges
    float dist_from_center = length(uv - vec2(0.5)) * 2.0;
    float edge_factor = smoothstep(0.2, 1.0, dist_from_center);
    
    // Animate the aberration slightly
    float animated_amount = aberration_amount * (1.0 + sin(time_val * 3.0) * 0.3);
    float offset = animated_amount * edge_factor * intensity;
    
    // Direction of aberration (radial from center)
    vec2 dir = normalize(uv - vec2(0.5));
    
    // Sample each channel with offset
    float r = textureLod(screen_texture, uv + dir * offset, 0.0).r;
    float g = textureLod(screen_texture, uv, 0.0).g;
    float b = textureLod(screen_texture, uv - dir * offset, 0.0).b;
    
    vec3 final_color = vec3(r, g, b);
    
    // Slight static noise for "broken" feel
    float noise = fract(sin(dot(uv * time_val, vec2(12.9898, 78.233))) * 43758.5453);
    final_color += vec3(noise * 0.03) * intensity;
    
    COLOR = vec4(final_color, intensity * 0.95);
}

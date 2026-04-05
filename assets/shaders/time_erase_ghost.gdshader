shader_type canvas_item;

// Time Erase ghost shader — ghostly blue transparency with wave distortion
// Applied via a full-screen ColorRect on a CanvasLayer

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_val : hint_range(0.0, 1000.0) = 0.0;

void fragment() {
    // Subtle wave distortion
    vec2 uv = SCREEN_UV;
    uv.x += sin(uv.y * 20.0 + time_val * 3.0) * 0.002 * intensity;
    uv.y += cos(uv.x * 15.0 + time_val * 2.0) * 0.002 * intensity;
    
    vec4 screen_color = textureLod(SCREEN_TEXTURE, uv, 0.0);
    
    // Ghostly blue-purple tint
    vec3 ghost_color = vec3(0.4, 0.5, 0.9);
    vec3 tinted = mix(screen_color.rgb, ghost_color, 0.3);
    
    // Pulsing alpha
    float pulse = 0.6 + sin(time_val * 4.0) * 0.15;
    
    vec3 final_color = mix(screen_color.rgb, tinted, intensity);
    COLOR = vec4(final_color, intensity * pulse * 0.6);
}

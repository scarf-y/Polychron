shader_type canvas_item;

// Time Stop inversion shader — inverts all colors on screen
// Applied via a full-screen ColorRect on a CanvasLayer

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(0.2, 0.8, 1.0, 1.0);

void fragment() {
    vec4 screen_color = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0);
    
    // Invert colors
    vec3 inverted = vec3(1.0) - screen_color.rgb;
    
    // Apply cyan tint to the inversion
    vec3 tinted = mix(inverted, tint_color.rgb, 0.3);
    
    // Blend between original and inverted based on intensity
    vec3 final_color = mix(screen_color.rgb, tinted, intensity);
    
    // Add slight vignette effect
    vec2 uv = SCREEN_UV;
    float vignette = 1.0 - smoothstep(0.4, 1.0, length(uv - vec2(0.5)));
    final_color *= mix(1.0, vignette, intensity * 0.3);
    
    COLOR = vec4(final_color, intensity * 0.9);
}

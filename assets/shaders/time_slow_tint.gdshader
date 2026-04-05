shader_type canvas_item;

// Time Slow tint shader — applies a golden/amber slow-motion feel
// Applied via a full-screen ColorRect on a CanvasLayer

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_val : hint_range(0.0, 1000.0) = 0.0;

void fragment() {
    vec4 screen_color = textureLod(SCREEN_TEXTURE, SCREEN_UV, 0.0);
    
    // Amber/golden tint
    vec3 amber = vec3(1.0, 0.85, 0.4);
    vec3 tinted = mix(screen_color.rgb, screen_color.rgb * amber, 0.4);
    
    // Subtle scan lines for "slow motion" feel
    float scanline = sin(SCREEN_UV.y * 360.0 + time_val * 2.0) * 0.03;
    tinted += vec3(scanline);
    
    // Desaturate slightly
    float gray = dot(tinted, vec3(0.299, 0.587, 0.114));
    tinted = mix(tinted, vec3(gray), 0.2);
    
    vec3 final_color = mix(screen_color.rgb, tinted, intensity);
    COLOR = vec4(final_color, intensity * 0.7);
}

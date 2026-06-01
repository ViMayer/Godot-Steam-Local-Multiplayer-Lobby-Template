shader_type canvas_item;

uniform vec4 background_color : source_color = vec4(0.2, 0.2, 0.2, 1);
uniform vec4 pulse_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_multiplier : hint_range(0.0, 1.0) = 1.0;
uniform float speed : hint_range(0.1, 10.0) = 5.0;
uniform float min_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float max_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float smoothness : hint_range(0.5, 10.0) = 1.0;

void fragment() {
    float raw_sine = (sin(TIME * speed) + 1.0) * 0.5;
    float pulse = raw_sine*smoothness;
    float intensity = mix(min_intensity, max_intensity, pulse);
    vec3 final_rgb = mix(background_color.rgb, pulse_color.rgb, intensity);
    float final_alpha = background_color.a * alpha_multiplier;
    COLOR = vec4(final_rgb, final_alpha);
}
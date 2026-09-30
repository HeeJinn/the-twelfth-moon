shader_type canvas_item;
// Makes the whole screen look like an old memory: warm and faded, with dark
// edges. Put it on a full-screen ColorRect above the scene.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
// 0 = full colour, 1 = fully faded.
uniform float fade : hint_range(0.0, 1.0) = 0.55;
uniform vec3 tint : source_color = vec3(1.0, 0.86, 0.78);
uniform float vignette : hint_range(0.0, 2.0) = 0.9;

void fragment() {
	vec3 colour = texture(screen_texture, SCREEN_UV).rgb;
	float grey = dot(colour, vec3(0.299, 0.587, 0.114));
	colour = mix(colour, vec3(grey) * tint, fade);
	vec2 from_centre = SCREEN_UV - 0.5;
	colour *= 1.0 - vignette * dot(from_centre, from_centre);
	COLOR = vec4(colour, 1.0);
}

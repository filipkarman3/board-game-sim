shader_type canvas_item;

uniform bool enabled = false;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float grey = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 greyscale = vec3(grey);
	COLOR.rgb = mix(tex_color.rgb, greyscale, float(enabled));
	COLOR.a = tex_color.a;
}
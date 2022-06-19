shader_type canvas_item;
uniform vec2 scale = vec2(1,1);
uniform float y_zoom;
uniform float max_size;

void fragment() {
	float uv_height = SCREEN_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.y;
	float c = textureLod(TEXTURE, UV, 0.0).r*0.5;//max_size;
	vec2 reflected_screen_uv = vec2(SCREEN_UV.x, SCREEN_UV.y - uv_height * c * scale.y * y_zoom*4.5);
	COLOR = textureLod(SCREEN_TEXTURE, reflected_screen_uv, 0.0);
}

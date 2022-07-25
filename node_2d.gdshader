shader_type canvas_item;
uniform float y_zoom;
uniform float max_size;

void fragment() {
	float uv_height = SCREEN_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.y;
	float c = texture(TEXTURE, UV, 0.0).r * max_size; // distance on screen to point to reflect from (in fraction of texture.)
	vec2 reflected_screen_uv = vec2(SCREEN_UV.x, SCREEN_UV.y - uv_height * c * y_zoom * 2.0);
	
	COLOR = texture(SCREEN_TEXTURE, reflected_screen_uv, 0.0);
}
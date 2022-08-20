shader_type canvas_item;
uniform float y_zoom;
uniform float max_size;
uniform int horizon_height;

void fragment() {
	float uv_height = SCREEN_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.y;
	vec4 texture_pixel = texture(TEXTURE, UV, 0.0); // Distance on screen to point to reflect from (in fraction of texture.)
	vec4 normal_pixel = texture(NORMAL_TEXTURE, UV, 0.0);
	float r = texture_pixel.r * max_size;
	float g = texture_pixel.g * max_size;
	float b = texture_pixel.b;
	float a = texture_pixel.a;
	vec2 uv_r = vec2(SCREEN_UV.x, SCREEN_UV.y - uv_height * r * y_zoom * 2.0);
	vec2 uv_g = vec2(SCREEN_UV.x, SCREEN_UV.y - uv_height * g * y_zoom * 2.0);
	vec2 uv_r_n = vec2(UV.x, UV.y - r * 2.0);
	vec2 uv_g_n = vec2(UV.x, UV.y - g * 2.0);
	
	vec4 reflection = textureLod(SCREEN_TEXTURE, uv_r, 0.0);
	vec4 reflection_n = textureLod(NORMAL_TEXTURE, uv_r_n, 0.0);
	reflection_n.a = reflection_n.a * (1.0 - normal_pixel.a);
	vec4 reflection_n_solid = vec4(reflection_n.r, reflection_n.g, reflection_n.b, 1);
	
	vec4 horizon = textureLod(SCREEN_TEXTURE, uv_g, 0.0);
	
	vec4 c3 = (1.0 - b) * reflection + (b) * horizon;
	vec4 final_color = vec4(0,0,0,0);
	if (normal_pixel.a >= 1.0) {
	} else if (normal_pixel.a > 0.0 && b > 0.0) {
		final_color = vec4(horizon.r, horizon.g, horizon.b, 1.0 - normal_pixel.a);
	} else if(normal_pixel.a > 0.0) {
		final_color = reflection_n_solid;
	} else if (reflection_n.a > 0.0) {
		final_color = mix(reflection_n_solid, horizon, 1.0-reflection_n.a);//vec4(1,0,0.75,1);
	}
	else {
		final_color = horizon;
	}

	COLOR = final_color;
}
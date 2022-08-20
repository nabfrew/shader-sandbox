@tool
extends Sprite2D

const MAX_SIZE : float = 2
# These constants are for using texture pixel colour values as flags 
const EMPTY_C := 0
const EMPTY := Color(0,0,0, EMPTY_C)

@onready var color_scale : float = MAX_SIZE * float(HEIGHT)

var last_pos = position
var last_size = texture.get_size()
@export var reflected_sprites : Array[String] = []
@export var WIDTH := 600
@export var HEIGHT := 200
@export var HORIZON : int = 120

@onready var last_change = Time.get_ticks_msec()
var scaled_images : Array

func _ready() -> void:
	material.set_shader_param("max_size", MAX_SIZE)
	reflected_sprites.sort_custom(sort_by_z)
	scaled_images = reflected_sprites.map(get_scaled_texture_reflection)
	
func sort_by_z(a : String, b : String):
	# assumes they're on the same scene node tree branch and don't have their z-index tinkered with.
	if get_z(a) < get_z(b):
		return true
	return false

func get_z(s : String) -> int:
	return get_owner().get_node(s).get_index()

# Copy the sprite to texture shape and size of reflection. Acounting for scaling.
func get_scaled_texture_reflection(sprite_path : String) -> Dictionary:
	var source_sprite : Sprite2D = get_owner().get_node(sprite_path)
	
	var return_dict = {
		"path" : sprite_path, 
		"position" : source_sprite.position, 
		"image" : Image.new(), 
		"norm_image" : Image.new()
	}
	
	var source_texture : Texture2D = source_sprite.texture
	var source_scale : Vector2 = source_sprite.scale
	var source_image := source_texture.get_image()
	var source_size : Vector2 = source_image.get_size()
	var source_position : Vector2 = source_sprite.position
	
	var source_min := reflected_to_source_v(Vector2(0,0), source_position, source_scale)
	source_min.x = max(0, source_min.x)
	var source_max := reflected_to_source_v(Vector2(WIDTH, HEIGHT), source_position, source_scale)
	source_max.x = min(source_image.get_size().x, source_max.x)
	
	if source_min.x >= source_max.x:
		return return_dict
	
	var image : Image = Image.new()
	image.create(int(round(source_size.x*source_scale.x)), int(2*round(source_size.y*source_scale.y)), false, Image.FORMAT_RGBAF)
	image.fill(EMPTY)
	var norm_image := Image.new()
	norm_image.create(int(round(source_size.x*source_scale.x)), int(2*round(source_size.y*source_scale.y)), false, Image.FORMAT_RGBAF)
	norm_image.fill(EMPTY)

	for i in range(image.get_size().x):
		var top : int = -1
		var bottom : int = 0
		for j in range(image.get_size().y):
			var pixel_color : Color = get_source_colour(i, j, source_scale, source_image)
			norm_image.set_pixel(i, j, pixel_color)
			
			if pixel_color.a > 0 and top < 0: 
				top = j
			if pixel_color.a == 1:
				bottom = j
		
		if top == -1 or bottom == 0:
			continue
		var reflection_range := bottom - top
		for j in range(image.get_size().y):
			var source_pixel := get_source_colour(i, j, source_scale, source_image)
			if j < top:
				image.set_pixel(i, j, EMPTY)
			elif  j < bottom:
				image.set_pixel(i, j, Color(0, 0, 1- source_pixel.a, 1))
			elif j - bottom < reflection_range:
				image.set_pixel(i, j, Color(coordinates_to_color(float(j), float(bottom)), 0, 0, 1 - source_pixel.a))
					
		return_dict.image = image
		return_dict.norm_image = norm_image
	return return_dict

func get_source_colour(i : int, j : int, source_scale : Vector2, source_image : Image) -> Color:
	var pixel_color : Color = EMPTY
	var source_size := source_image.get_size()
	var source_pixel_coordinates := Vector2i(int(round(float(i) / source_scale.x)), int(round(float(j) / source_scale.y)))
			
	if out_of_x_range(source_pixel_coordinates, source_size.x):
		return pixel_color
		
	if source_pixel_coordinates.y >= source_size.y:
		pixel_color = Color(0,1,1,0) # transparent non-empty
	else:
		pixel_color = source_image.get_pixelv(source_pixel_coordinates)
	return pixel_color

func out_of_x_range(source : Vector2i, source_size_x : int) -> bool:
	if source.x < 0 or source.x >= source_size_x:
		return true
	if source.y < 0:
		return true
	return false

func coordinates_to_color(j : float, bottom : float) -> float:
	return (j - bottom) / color_scale

func init_reflection_with_horizon() -> Image:
	var image : Image = init_empty_reflection()
	var h : float = HORIZON - position.y
	material.set_shader_param("horizon_uv", h / HEIGHT)
	var d : float = h
	if h < 0:
		h = 0
	d = position.y + h - HORIZON
	for y in range(h, image.get_size().y):
		var c = Color(0, float(d)/ color_scale, 0, 0)
		for x in range(image.get_size().x):
			image.set_pixel(x, y, c)
		d = d + 1.0
	return image

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if Time.get_ticks_msec() - last_change > 100:
		material.set_shader_param("y_zoom", get_viewport().get_final_transform().y.y)
		last_change = Time.get_ticks_msec()
		
		if position != last_pos or texture.get_size() != last_size:
			update_source_positions()
			texture = merge_sprites()
			
			last_pos = position
			last_size = Vector2(texture.get_width(), texture.get_height())

func update_source_positions() -> void:
	for image in scaled_images:
		for path in reflected_sprites:
			if image.path == path:
				var source_sprite : Sprite2D = get_owner().get_node(path)
				image.position = source_sprite.position


func init_empty_reflection() -> Image:
	var image = Image.new()
	image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBAF)
	image.fill(EMPTY)
	return image

func merge_sprites() -> CanvasTexture:
	var merged_image : Image = init_reflection_with_horizon()
	var merged_norm_image := init_empty_reflection()
	
	for source in scaled_images:
		for i in range(WIDTH):
			for j in HEIGHT:
				var current_pixel := merged_image.get_pixel(i,j)
				var c : Vector2 = (position + Vector2(i,j) - source.position)
				var source_coordinates := Vector2i(round(c.x), round(c.y))
				
				if source_coordinates.x < 0 or source_coordinates.x >= source.image.get_size().x:
					continue
				if source_coordinates.y < 0 or source_coordinates.y >= source.image.get_size().y:
					continue

				var current_norm_pixel := merged_norm_image.get_pixel(i, j)
				var source_norm_pixel : Color = source.norm_image.get_pixelv(source_coordinates)
				if current_norm_pixel == EMPTY:
					merged_norm_image.set_pixel(i, j, source_norm_pixel)
				else:
					merged_norm_image.set_pixel(i, j, current_norm_pixel.blend(source_norm_pixel))
				

				if current_pixel == EMPTY:
					continue # EMPTY implies above horizon
				var source_color : Color = source.image.get_pixelv(source_coordinates)
				if source_color != EMPTY:
					var g := merged_image.get_pixel(i, j).g
					merged_image.set_pixel(i, j, Color(source_color.r, g, source_color.b, source_color.a))

	var canvas_tex = CanvasTexture.new()
	var tex := ImageTexture.create_from_image(merged_image)
	var norm_tex := ImageTexture.create_from_image(merged_norm_image)
	canvas_tex.diffuse_texture = tex
	canvas_tex.normal_texture = norm_tex
	return canvas_tex

func reflected_to_source_v(reflected_coordinate : Vector2, source_position : Vector2, source_scale : Vector2) -> Vector2i:
	return Vector2i((position + reflected_coordinate - source_position)/source_scale)
	
func reflected_to_source(reflected_position : float, reflected_coordinate : float, source_position : float, source_scale : float) -> int:
	return int((reflected_position + reflected_coordinate - source_position)/source_scale)

func source_to_reflected_v(source_coordinates : Vector2, source_position : Vector2, source_scale : Vector2) -> Vector2i:
	return Vector2i(source_scale*source_coordinates - position + source_position)
	
func source_to_reflected(reflected_position : float, source_coordinates : float, source_position : float, source_scale : float) -> int:
	return int(source_scale*source_coordinates - reflected_position + source_position)

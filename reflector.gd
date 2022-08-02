@tool
extends Sprite2D

const MAX_SIZE : float = 5
const OCCUPIED := Color(0,1,0,0.5)
const EMPTY := Color(0,0,0,0.01)

@onready var color_scale : float = MAX_SIZE * float(HEIGHT)

var last_pos = position
var last_size = texture.get_size()
@export var reflected_sprites : Array[String] = []
@export var WIDTH := 600
@export var HEIGHT := 200
@export var HORIZON : int = 120

const OCCUPIED_THRESHOLD = 0.8 # alpha >= than this will count it as occupied.

@onready var last_change = Time.get_ticks_msec()
var scaled_images : Array

const TOP_D := Color(1,0,0,1)
const OCCUPIED_D := Color.GRAY
const BOTTOM_D  := Color(0,1,1,1)
const REFLECTING_D := Color(0,0,1,1)
const UNREFLECTING_D := Color(0.5,0.5,0,1)
const REFLECTION_BOTTOM_D := Color.DARK_BLUE

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
	
	var return_dict = {"path" : sprite_path, "position" : source_sprite.position, "image" : Image.new()}
	
	
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

	for i in range(image.get_size().x):
		var top : Array[int] = []
		var bottom : Array[int] = []
		for j in range(image.get_size().y):
			var source_pixel_coordinates := Vector2i(int(round(float(i) / source_scale.x)), int(round(float(j) / source_scale.y)))
			
			if source_pixel_coordinates.x < 0 or source_pixel_coordinates.x >= source_size.x:
				continue
			if source_pixel_coordinates.y < 0:
				image.set_pixel(i, j, Color.GREEN) 
				continue

			if (true):
				image.set_pixel(i, j, get_pixel_type(source_pixel_coordinates, source_image, top, bottom, j))
				continue
				
			var pixel_color : Color = EMPTY
			if source_pixel_coordinates.y >= source_size.y:
				pixel_color = Color(0,1,1,0)
			pixel_color = source_image.get_pixelv(source_pixel_coordinates)
			if pixel_color.a == 1: 
				if top.is_empty():
					top.append(j)
				image.set_pixel(i, j, OCCUPIED)
			if pixel_color.a < 1:
				if bottom.size() < top.size(): # top value is not paired with a bottom.
					bottom.append(j)
				if bottom.size() == top.size():
					if within_reflection_range(j, top, bottom):
						image.set_pixel(i, j, coordinates_to_color(float(j), float(bottom[-1])))
					
		return_dict.image = image
	return return_dict

func get_pixel_type(source_pixel_coordinates : Vector2i, source_image : Image, top : Array, bottom : Array, j : int) -> Color:
	# image size is 2x source size. pixel can be assumed empty, but must work out if part of reflection or not.
	var pixel_color : Color 
	if source_pixel_coordinates.y >= source_image.get_size().y:
		pixel_color = Color(0,1,1,0) # todo
	else:
		pixel_color = source_image.get_pixelv(source_pixel_coordinates)
	
	if pixel_color.a == 1: # part of a feature
		if top.is_empty() or top.size() == bottom.size(): # top of a new feature
			top.append(j)
			return TOP_D
		return OCCUPIED_D
	if pixel_color.a < 1: # not part of a feature
		if bottom.size() < top.size(): # top value is not paired with a bottom -> this *is* the feature bottom.
			bottom.append(j)
			return BOTTOM_D
		if bottom.size() == top.size():
			if within_reflection_range(j, top, bottom):
				return REFLECTING_D
	return UNREFLECTING_D

func coordinates_to_color(j : float, bottom : float) -> Color:
	var red_channel : float = (j - bottom) / color_scale
	return Color(red_channel, 0 , 0 , 1)

func within_reflection_range(j : int, top : Array[int], bottom : Array[int]) -> bool:
	if top.is_empty():
		return false
	if j >= 2 * bottom[-1] - top[-1]:
		top.pop_back()
		bottom.pop_back()
		return within_reflection_range(j, top, bottom) 
	return true

func init_reflection_with_horizon() -> Image:
	var image : Image = Image.new()
	image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBAF)
	image.fill(EMPTY)
	var h : float = HORIZON - position.y
	var d : float = h
	if h < 0:
		h = 0
	d = position.y + h - HORIZON
	for y in range(h, image.get_size().y):
		var c = Color(float(d)/ color_scale, 0, 0, 1)
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
			var image : Image = merge_sprites()
			var tex : ImageTexture = ImageTexture.create_from_image(image)
			texture = tex
			last_pos = position
			last_size = Vector2(texture.get_width(), texture.get_height())

func update_source_positions() -> void:
	for image in scaled_images:
		for path in reflected_sprites:
			if image.path == path:
				var source_sprite : Sprite2D = get_owner().get_node(path)
				image.position = source_sprite.position

func merge_sprites() -> Image:
	var merged_image : Image = init_reflection_with_horizon()
	
	for source in scaled_images:
		for i in range(WIDTH):
			for j in HEIGHT:
				var current_pixel := merged_image.get_pixel(i,j)
				if current_pixel == OCCUPIED_D or current_pixel == EMPTY:
					continue # EMPTY implies above horizon
				var c : Vector2 = (position + Vector2(i,j) - source.position)
				var source_coordinates := Vector2i(round(c.x), round(c.y))
				
				if source_coordinates.x < 0 or source_coordinates.x >= source.image.get_size().x:
					continue
				if source_coordinates.y < 0 or source_coordinates.y >= source.image.get_size().y:
					continue
				
				var source_color : Color = source.image.get_pixelv(source_coordinates)
				
				if source_color == OCCUPIED_D:
					merged_image.set_pixel(i, j, OCCUPIED_D)
				elif source_color != EMPTY:
					merged_image.set_pixel(i, j, source_color)

	return merged_image

func reflected_to_source_v(reflected_coordinate : Vector2, source_position : Vector2, source_scale : Vector2) -> Vector2i:
	return Vector2i((position + reflected_coordinate - source_position)/source_scale)
	
func reflected_to_source(reflected_position : float, reflected_coordinate : float, source_position : float, source_scale : float) -> int:
	return int((reflected_position + reflected_coordinate - source_position)/source_scale)

func source_to_reflected_v(source_coordinates : Vector2, source_position : Vector2, source_scale : Vector2) -> Vector2i:
	return Vector2i(source_scale*source_coordinates - position + source_position)
	
func source_to_reflected(reflected_position : float, source_coordinates : float, source_position : float, source_scale : float) -> int:
	return int(source_scale*source_coordinates - reflected_position + source_position)

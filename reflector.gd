@tool
extends Sprite2D

var last_pos = position
var last_size = texture.get_size()
@export var reflected_sprites : Array[String] = []
const MAX_SIZE := 100
@export var WIDTH := 600
@export var HEIGHT := 200
@onready var last_change = Time.get_ticks_msec()

func _ready() -> void:
	material.set_shader_param("max_height", MAX_SIZE)

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - last_change > 100:
		material.set_shader_param("y_zoom", get_viewport().get_final_transform().y.y)
		last_change = Time.get_ticks_msec()
		if position != last_pos or texture.get_size() != last_size:
			var image : Image = merge_sprites()
			texture.create_from_image(image)
			last_pos = position
			last_size = Vector2(texture.get_width(), texture.get_height())

func merge_sprites() -> Image:
	var merged_image : Image = Image.new()
	merged_image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	merged_image.fill(Color(0, 0, 0, 0))
	
	for image in reflected_sprites:
		merged_image = source_distance_with_alpha(image, merged_image)
	print("R %f\tB %f" % [merged_image.get_pixel(0,0).r, merged_image.get_pixel(0,0).b])
	return merged_image

func source_distance_with_alpha(source_sprite_path : String, merged_image : Image) -> Image:
	print(source_sprite_path)
	var source_sprite : Sprite2D = get_owner().get_node(source_sprite_path)
	var source_texture : Texture2D = source_sprite.texture
	var source_scale : Vector2 = source_sprite.scale
	var source_image := source_texture.get_image()
	var source_position : Vector2 = source_sprite.position
	var distance_map : Image = create_distance_map(source_image)
	
	for i in range(WIDTH):
		var source_x := reflected_to_source(position.x, i, source_position.x, source_scale.x)
		if source_x < 0 or source_x >= source_image.get_size().x:
			continue
		for j in range(HEIGHT):
			var reflected_pixel = Vector2i(i,j)
			var source_pixel := reflected_to_source_v(reflected_pixel, source_position, source_scale)
			if source_pixel.y >=0 and source_pixel.y < source_image.get_size().y:
				var color = distance_map.get_pixelv(source_pixel)
				merged_image.set_pixelv(reflected_pixel, color_to_set(reflected_pixel, merged_image, color))
			if source_pixel.y >= source_image.get_size().y:
				var pixel_value := bottom_color(source_pixel.x, distance_map, source_image)
				var distance := (source_pixel.y - source_image.get_size().y) / MAX_SIZE
				var color := Color(distance, distance, 0, 0) + pixel_value
				merged_image.set_pixelv(reflected_pixel, color_to_set(reflected_pixel, merged_image, color))
	return merged_image
	
func color_to_set(pixel : Vector2i, merged_image : Image, color : Color) -> Color:
	var existing_color = merged_image.get_pixelv(pixel)
	if existing_color.b >= 1 or color.b >= 1:
		return Color(0, 0 ,1 ,0)
	if (existing_color.r <= color.r and existing_color.a == 1) or color.a == 0:
		return existing_color
	return color

func create_distance_map(image : Image) -> Image:
	var image_map : Image = Image.new()
	var w := image.get_width()
	var h := image.get_height()
	image_map.create(w, h, false, Image.FORMAT_RGBA8)
	image_map.fill(Color(0, 0, 0, 0))
	for i in range(w):
		var column_has_opaque_pixels := false
		var count := 0
		for j in range(h):
			if image.get_pixel(i, j).a == 1:
				column_has_opaque_pixels = true
				image_map.set_pixel(i, j, Color(0, 0, 1, 0)) # b == 1 indicates occupied.
				count = 0
			elif column_has_opaque_pixels:
				count = count + 1
				var n := float(count) / MAX_SIZE 
				image_map.set_pixel(i , j, Color(n, n, 0, 1))
	return image_map
	
func bottom_color(column : int, image_map : Image, image : Image) -> Color:
	var color = image_map.get_pixel(column, image_map.get_size().y - 1) 
	if image.get_pixel(column, image.get_size().y - 1).a != 0:
		color = Color(0,0,0,1)
	return color

func reflected_to_source_v(reflected_coordinate : Vector2, source_position : Vector2, source_scale : Vector2) -> Vector2i:
	return Vector2i((position + reflected_coordinate - source_position)/source_scale)
	
func reflected_to_source(reflected_position : float, reflected_coordinate : float, source_position : float, source_scale : float) -> int:
	return int((reflected_position + reflected_coordinate - source_position)/source_scale)

func source_to_reflected_v(source_coordinates : Vector2, source_position : Vector2, source_scale : Vector2) -> Vector2i:
	return Vector2i(source_scale*source_coordinates - position + source_position)
	
func source_to_reflected(reflected_position : float, source_coordinates : float, source_position : float, source_scale : float) -> int:
	return int(source_scale*source_coordinates - reflected_position + source_position)

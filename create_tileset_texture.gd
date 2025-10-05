@tool
extends EditorScript

# Script to create tileset texture for the terrain
# Run this in Godot Editor: Tools > Execute Script

func _run():
	create_tileset_texture()
	print("Tileset texture created successfully!")

func create_tileset_texture():
	# Create a 96x32 image (3 tiles of 32x32 each)
	var image = Image.create(96, 32, false, Image.FORMAT_RGBA8)

	# Fill with transparent background
	image.fill(Color(0, 0, 0, 0))

	# Tile 1: Grass (0, 0) - Green with texture pattern
	create_grass_tile(image, 0, 0)

	# Tile 2: Dirt (32, 0) - Brown with texture pattern
	create_dirt_tile(image, 32, 0)

	# Tile 3: Stone (64, 0) - Gray with texture pattern
	create_stone_tile(image, 64, 0)

	# Save the image
	var texture_path = "res://terrain_tiles.png"
	image.save_png(texture_path)
	print("Tileset texture saved to: ", texture_path)

func create_grass_tile(image: Image, start_x: int, start_y: int):
	var base_color = Color(0.2, 0.7, 0.2)  # Green
	var dark_green = Color(0.1, 0.5, 0.1)
	var light_green = Color(0.3, 0.8, 0.3)

	for x in range(32):
		for y in range(32):
			var color = base_color

			# Add some texture variation
			if (x + y) % 4 == 0:
				color = dark_green
			elif (x * y) % 7 == 0:
				color = light_green

			# Add grass blade details on top
			if y < 8 and (x % 6 == 0 or (x + 2) % 6 == 0):
				color = light_green

			image.set_pixel(start_x + x, start_y + y, color)

func create_dirt_tile(image: Image, start_x: int, start_y: int):
	var base_color = Color(0.6, 0.4, 0.2)  # Brown
	var dark_brown = Color(0.4, 0.2, 0.1)
	var light_brown = Color(0.7, 0.5, 0.3)

	for x in range(32):
		for y in range(32):
			var color = base_color

			# Add texture variation
			if (x + y) % 3 == 0:
				color = dark_brown
			elif (x * y) % 5 == 0:
				color = light_brown

			# Add some random spots
			if (x * 3 + y * 7) % 11 == 0:
				color = dark_brown

			image.set_pixel(start_x + x, start_y + y, color)

func create_stone_tile(image: Image, start_x: int, start_y: int):
	var base_color = Color(0.5, 0.5, 0.5)  # Gray
	var dark_gray = Color(0.3, 0.3, 0.3)
	var light_gray = Color(0.7, 0.7, 0.7)

	for x in range(32):
		for y in range(32):
			var color = base_color

			# Add texture variation
			if (x + y) % 5 == 0:
				color = dark_gray
			elif (x * y) % 8 == 0:
				color = light_gray

			# Add stone cracks/lines
			if x % 16 == 0 or y % 16 == 0:
				color = dark_gray
			if (x - 8) % 16 == 0 or (y - 8) % 16 == 0:
				color = light_gray

			image.set_pixel(start_x + x, start_y + y, color)
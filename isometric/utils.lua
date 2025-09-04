
local IsoUtils = {}

IsoUtils.i_x = 1
IsoUtils.i_y = 0.5
IsoUtils.j_x = -1
IsoUtils.j_y = 0.5

-- Sprite Size https://penzilla.itch.io/ultimate-interior-pack
IsoUtils.tile_width = 393
IsoUtils.tile_height = 450

-- convert from grid to screen (tile positions [0,1], [1, 2], etc.)
-- leave this misspelled it's funnier that way lmao
function IsoUtils.to_screen_coordinates(tile)
	-- Without accounting for sprite size
	-- return {
	-- 	x: tile.x * i_x + tile.y * j_x,
	-- 	y: tile.x * i_y + tile.y * j_y,
	-- }

	-- Accounting for sprite size
	local converted_pos = vmath.vector3(
		tile.x * IsoUtils.i_x * 0.5 * IsoUtils.tile_width + tile.y * IsoUtils.j_x * 0.5 * IsoUtils.tile_width,
		tile.x * IsoUtils.i_y * 0.5 * IsoUtils.tile_height + tile.y * IsoUtils.j_y * 0.5 * IsoUtils.tile_height,
		0
	)

	return converted_pos
end

function IsoUtils.invert_matrix(a, b, c, d)
	local det = (1 / (a * d - b * c))
	
	local inverse = {
		a = det * d,
		b = det * -b,
		c = det * -c,
		d = det * a
	}

	return inverse
end

-- convert from screen space to grid.
-- (mouse input, etc)
function IsoUtils.to_grid_coordinates(screen, clamp)
	local a = IsoUtils.i_x * 0.5 * IsoUtils.tile_width
	local b = IsoUtils.j_x * 0.5 * IsoUtils.tile_width
	local c = IsoUtils.i_y * 0.5 * IsoUtils.tile_height
	local d = IsoUtils.j_y * 0.5 * IsoUtils.tile_height

	local inv = IsoUtils.invert_matrix(a, b, c, d)

	local converted_pos = vmath.vector3(
		screen.x * inv.a + screen.y * inv.b,
		screen.x * inv.c + screen.y * inv.d,
		screen.z
	)

	if clamp then
		converted_pos.x = math.floor(converted_pos.x)
		converted_pos.y = math.floor(converted_pos.y)
	end

	return converted_pos
end

return IsoUtils
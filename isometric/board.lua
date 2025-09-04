local Map = {}

-- local wall_enum = {
--   0 = 'no wall',
--   1 = 'west',
--   2 = 'northwest'
--   3 = 'north',
--   4 = 'northeast'
--   5 = 'east',
--   6 = 'southeast',
--   7 = 'south',
--   8 = 'southwest'
-- }

Map.width = 30
Map.height = 30
Map.sidewalk_width = 2

Map.left_spawn = vmath.vector3(Map.width - 1, 0, 0)
Map.right_spawn = vmath.vector3(0, Map.height - 1, 0)

Map.tiles = {}
Map.collision = {}
Map.decorations = {}

function Map.getIndex(x, y)
	return y * Map.width + x + 1 -- +1 for Lua's 1-based indexing
end

function Map.getTile(x, y)
	local index = Map.getIndex(x, y)
	return Map.tiles[index]
end

function Map.get_decoration(x, y)
	local index = Map.getIndex(x, y)
	return Map.decorations[index]
end

function Map.attachGoToTile(x, y, tile_id)
	local index = Map.getIndex(x, y)
	Map.tiles[index].tile_id = tile_id
end

function Map.update_collision(tile, collision)
	local index = Map.getIndex(tile.x, tile.y)
	Map.collision[index] = collision
end

function Map.change_tile_sprite(x, y, sprite)
	local index = Map.getIndex(x, y)
	Map.tiles[index].sprite = sprite

	return Map.tiles[index].tile_id
end

function Map.get_tiles_in_radius(center, radius)
	local tiles = {}

	local minX = math.max(0, center.x - radius)
	local maxX = math.min(Map.width - 1, center.x + radius)
	local minY = math.max(0, center.y - radius)
	local maxY = math.min(Map.height - 1, center.y + radius)

	for y = minY, maxY, 1 do
		for x = minX, maxX, 1 do
			local index = Map.getIndex(x, y)
			table.insert(tiles, Map.tiles[index])
		end
	end

	return tiles
end

function Map.move_to_adjacent_different_tile(tile_pos)
	local current_tile = Map.getTile(tile_pos.x, tile_pos.y)
	local current_sprite = current_tile.sprite

	-- Define adjacent directions (4-directional: up, down, left, right)
	local directions = {
		{ x = 0, y = 1 },   -- up
		{ x = 0, y = -1 },  -- down
		{ x = -1, y = 0 },  -- left
		{ x = 1, y = 0 }    -- right
	}

	-- Check each adjacent tile
	for _, dir in ipairs(directions) do
		local check_x = tile_pos.x + dir.x
		local check_y = tile_pos.y + dir.y

		local adjacent_tile = Map.getTile(check_x, check_y)

		-- If tile exists and has different sprite, move there
		if adjacent_tile and adjacent_tile.sprite ~= current_sprite then
			return vmath.vector3(check_x, check_y, 0)
		end
	end

	return tile_pos -- No valid adjacent tile found
end

function Map.getDefaultMap()
	Map.tiles = {}
	for y = 0, Map.height - 1, 1 do
		for x = 0, Map.width - 1, 1 do
			local index = Map.getIndex(x, y)

			local isLeftSidewalk = x < Map.sidewalk_width
			local isRightSidewalk = y < Map.sidewalk_width
			local isLeftLocked = x >= 12
			local isRightLocked = y >= 12

			local tile = 0

			local sprite = 'blackwhite_CheckeredFloor1_Sides2'
			if isLeftSidewalk or isRightSidewalk then
				sprite = 'blackwhite_BlankFloor_Sides2'
				tile = 1
			elseif isLeftLocked or isRightLocked then
				sprite = 'grey_Pattern1_Sides2'
				tile = 2
			end

			Map.tiles[index] = {
				sprite = sprite,
				wall = 'none',
				tile_id = ''
			}
			Map.decorations[index] = {
				category = 'none',
				texture = 'none',
				go_id = ''
			}
			Map.collision[index] = tile
		end
	end
end

return Map
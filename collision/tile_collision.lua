-- 3D Layer-Based Tile Collision System for Isometric Games in Defold
-- Works with layers[z][y][x] = tile_id format

local M = {}

-- Configuration
M.TILE_WIDTH = 32
M.TILE_HEIGHT = 32
M.TILE_DEPTH = 16  -- Z-axis height per layer
M.MAP_WIDTH = 50
M.MAP_HEIGHT = 50
M.MAP_DEPTH = 10

-- Reference to your tile layers (you'll set this from your main code)
-- Expected format: layers[z][y][x] = tile_id (0 = air, anything else = solid)
M.layers = nil

-- Initialize/set the layers reference
function M.set_layers(tile_layers)
	M.layers = tile_layers
end

-- Check if tile coordinates are valid
function M.is_valid_tile(x, y, z)
	return x >= 1 and x <= M.MAP_WIDTH and 
	y >= 1 and y <= M.MAP_HEIGHT and 
	z >= 1 and z <= M.MAP_DEPTH
end

-- Get tile ID at specific layer coordinates
function M.get_tile_id(x, y, z)
	if not M.layers or not M.is_valid_tile(x, y, z) then
		return 0
	end

	if not M.layers[z] or not M.layers[z][y] then
		return 0
	end

	return M.layers[z][y][x] or 0
end

-- Check if tile is solid (non-zero tile_id)
function M.is_tile_solid(x, y, z)
	return M.get_tile_id(x, y, z) ~= 0
end

-- Convert world position to tile coordinates
function M.world_to_tile(world_x, world_y, world_z)
	local tile_x = math.floor(world_x / M.TILE_WIDTH) + 1
	local tile_y = math.floor(world_y / M.TILE_HEIGHT) + 1
	local tile_z = math.floor(world_z / M.TILE_DEPTH) + 1
	return tile_x, tile_y, tile_z
end

-- Convert tile coordinates to world position (center of tile)
function M.tile_to_world(tile_x, tile_y, tile_z)
	local world_x = (tile_x - 1) * M.TILE_WIDTH + M.TILE_WIDTH / 2
	local world_y = (tile_y - 1) * M.TILE_HEIGHT + M.TILE_HEIGHT / 2
	local world_z = (tile_z - 1) * M.TILE_DEPTH + M.TILE_DEPTH / 2
	return world_x, world_y, world_z
end

-- Get the ground height (top of highest solid tile) at X,Y world position
function M.get_ground_height_at_position(world_x, world_y)
	local tile_x, tile_y = M.world_to_tile(world_x, world_y, 0)

	-- Search from top to bottom for the highest solid tile
	for z = M.MAP_DEPTH, 1, -1 do
		if M.is_tile_solid(tile_x, tile_y, z) then
			-- Return the top surface of this tile
			return z * M.TILE_DEPTH
		end
	end

	return 0  -- No solid ground found
end

-- Check if world position is inside a solid tile
function M.is_solid_at_position(world_x, world_y, world_z)
	local tile_x, tile_y, tile_z = M.world_to_tile(world_x, world_y, world_z)
	return M.is_tile_solid(tile_x, tile_y, tile_z)
end

-- Get all solid tiles in a 3D region
function M.get_solid_tiles_in_region(min_x, min_y, min_z, max_x, max_y, max_z)
	local tiles = {}

	local tile_min_x, tile_min_y, tile_min_z = M.world_to_tile(min_x, min_y, min_z)
	local tile_max_x, tile_max_y, tile_max_z = M.world_to_tile(max_x, max_y, max_z)

	for z = tile_min_z, tile_max_z do
		for y = tile_min_y, tile_max_y do
			for x = tile_min_x, tile_max_x do
				if M.is_tile_solid(x, y, z) then
					local world_x, world_y, world_z = M.tile_to_world(x, y, z)
					table.insert(tiles, {
						tile_x = x, tile_y = y, tile_z = z,
						world_x = world_x, world_y = world_y, world_z = world_z,
						tile_id = M.get_tile_id(x, y, z)
					})
				end
			end
		end
	end

	return tiles
end

-- Collision detection for a rectangular object
function M.check_collision(x, y, z, width, height, depth)
	local results = {
		collision = false,
		ground_height = 0,
		blocking_tiles = {}
	}

	-- Calculate the bounding box
	local min_x = x - width / 2
	local max_x = x + width / 2
	local min_y = y - height / 2
	local max_y = y + height / 2
	local min_z = z
	local max_z = z + depth

	-- Get ground height at this position
	results.ground_height = M.get_ground_height_at_position(x, y)

	-- Get all solid tiles in the object's bounding box
	local solid_tiles = M.get_solid_tiles_in_region(min_x, min_y, min_z, max_x, max_y, max_z)

	for _, tile in ipairs(solid_tiles) do
		-- Calculate tile bounding box
		local tile_min_x = tile.world_x - M.TILE_WIDTH / 2
		local tile_max_x = tile.world_x + M.TILE_WIDTH / 2
		local tile_min_y = tile.world_y - M.TILE_HEIGHT / 2
		local tile_max_y = tile.world_y + M.TILE_HEIGHT / 2
		local tile_min_z = tile.world_z - M.TILE_DEPTH / 2
		local tile_max_z = tile.world_z + M.TILE_DEPTH / 2

		-- Check for AABB collision
		if min_x < tile_max_x and max_x > tile_min_x and
		min_y < tile_max_y and max_y > tile_min_y and
		min_z < tile_max_z and max_z > tile_min_z then
			results.collision = true
			table.insert(results.blocking_tiles, tile)
		end
	end

	return results
end

-- Move with collision detection and response
function M.move_with_collision(current_x, current_y, current_z, target_x, target_y, target_z, width, height, depth)
	local result = {
		x = current_x,
		y = current_y,
		z = current_z,
		collided = false,
		ground_z = 0,
		blocked_directions = {x = false, y = false, z = false}
	}

	-- Get ground height at target position
	result.ground_z = M.get_ground_height_at_position(target_x, target_y)

	-- Try full movement first
	local collision = M.check_collision(target_x, target_y, target_z, width, height, depth)
	if not collision.collision then
		result.x = target_x
		result.y = target_y
		result.z = target_z
		return result
	end

	result.collided = true

	-- Try individual axis movement (sliding)
	-- Try X movement only
	collision = M.check_collision(target_x, current_y, current_z, width, height, depth)
	if not collision.collision then
		result.x = target_x
	else
		result.blocked_directions.x = true
	end

	-- Try Y movement only
	collision = M.check_collision(current_x, target_y, current_z, width, height, depth)
	if not collision.collision then
		result.y = target_y
	else
		result.blocked_directions.y = true
	end

	-- Try Z movement only (jumping/falling)
	collision = M.check_collision(current_x, current_y, target_z, width, height, depth)
	if not collision.collision then
		result.z = target_z
	else
		result.blocked_directions.z = true
		-- If blocked vertically and trying to fall, snap to ground
		if target_z < current_z and result.ground_z > 0 then
			result.z = result.ground_z
		end
	end

	return result
end

-- Raycast through the tile layers
function M.raycast(start_x, start_y, start_z, end_x, end_y, end_z, step_size)
	step_size = step_size or math.min(M.TILE_WIDTH, M.TILE_HEIGHT, M.TILE_DEPTH) / 2

	local dx = end_x - start_x
	local dy = end_y - start_y
	local dz = end_z - start_z
	local distance = math.sqrt(dx*dx + dy*dy + dz*dz)
	local steps = math.ceil(distance / step_size)

	if steps == 0 then
		return {hit = false}
	end

	local step_x = dx / steps
	local step_y = dy / steps
	local step_z = dz / steps

	for i = 0, steps do
		local test_x = start_x + step_x * i
		local test_y = start_y + step_y * i
		local test_z = start_z + step_z * i

		if M.is_solid_at_position(test_x, test_y, test_z) then
			local tile_x, tile_y, tile_z = M.world_to_tile(test_x, test_y, test_z)
			return {
				hit = true,
				x = test_x,
				y = test_y,
				z = test_z,
				tile_x = tile_x,
				tile_y = tile_y,
				tile_z = tile_z,
				tile_id = M.get_tile_id(tile_x, tile_y, tile_z),
				distance = math.sqrt((test_x-start_x)^2 + (test_y-start_y)^2 + (test_z-start_z)^2)
			}
		end
	end

	return { hit = false }
end

return M
-- 3D Layer-Based Tile Collision System for Isometric Games in Defold
-- Works with chunk-based world system
-- Y = height (vertical), Z = forward/back, X = left/right

local M = {}

-- Configuration - Fixed coordinate system
M.TILE_WIDTH = 16   -- X-axis (left/right)
M.TILE_HEIGHT = 16  -- Z-axis (forward/back) 
M.TILE_DEPTH = 16   -- Y-axis (up/down, vertical height)

-- Reference to your world system (you'll set this from your main code)
-- This should be your world module that has get_chunk() function
M.world = nil
M.layers = nil  -- Keep for backwards compatibility

-- Debug flags
M.debug_conversion = false
M.debug_collision = false

-- Initialize/set the world reference  
function M.set_world(world_system)
	M.world = world_system
end

-- Convert world coordinates to chunk coordinates (matching your rendering system)
function M.world_to_chunk(world_x, world_z)
	if not M.world then
		return 0, 0
	end

	local chunk_width_pixels = M.world.chunk_width * M.TILE_WIDTH
	local chunk_height_pixels = M.world.chunk_height * M.TILE_HEIGHT

	-- Correct handling for negative coordinates
	local function floor_div(a, b)
		local div = a / b
		if div >= 0 then
			return math.floor(div)
		else
			return math.ceil(div - 1)
		end
	end

	local chunk_world_x = floor_div(world_x, chunk_width_pixels)
	local chunk_world_z = floor_div(world_z, chunk_height_pixels)

	return chunk_world_x, chunk_world_z
end

-- Convert world coordinates to local tile coordinates within a chunk
function M.world_to_tile(world_x, world_y, world_z, offset)
	offset = offset or vmath.vector3(0, 0, 0)
	local local_x = world_x - offset.x
	local local_y = world_y - offset.y
	local local_z = world_z - offset.z

	-- Get which chunk we're in
	local chunk_x, chunk_z = M.world_to_chunk(local_x, local_z)

	-- Calculate the chunk's world position
	local chunk_world_x = chunk_x * M.world.chunk_width * M.TILE_WIDTH
	local chunk_world_z = chunk_z * M.world.chunk_height * M.TILE_HEIGHT

	-- Get local position within the chunk
	local chunk_local_x = local_x - chunk_world_x
	local chunk_local_z = local_z - chunk_world_z

	-- Convert to tile coordinates within the chunk (1-16)
	local tile_x = math.floor(chunk_local_x / M.TILE_WIDTH)
	local tile_y = math.floor(local_y / M.TILE_HEIGHT)
	local tile_z = math.floor(chunk_local_z / M.TILE_HEIGHT)

	-- Clamp to chunk bounds
	if tile_x == 0 then
		chunk_x = chunk_x - 1
		tile_x = M.world.chunk_width
	else
		tile_x = math.max(1, math.min(M.world.chunk_width, tile_x))
	end

	if tile_z == 0 then
		chunk_z = chunk_z - 1
		tile_z = M.world.chunk_height
	else
		tile_z = math.max(1, math.min(M.world.chunk_height, tile_z))
	end

	tile_z = math.max(1, tile_z)

	return tile_x, tile_y, tile_z, chunk_x, chunk_z
end

-- Convert tile coordinates to world position (center of tile) - Now chunk-aware
function M.tile_to_world(tile_x, tile_y, tile_z, chunk_x, chunk_z)
	chunk_x = chunk_x or 0
	chunk_z = chunk_z or 0

	-- Calculate chunk's world position
	local chunk_world_x = chunk_x * M.world.chunk_width * M.TILE_WIDTH
	local chunk_world_z = chunk_z * M.world.chunk_height * M.TILE_HEIGHT

	-- Calculate tile's local position within chunk, then add chunk offset
	local world_x = chunk_world_x + tile_x * M.TILE_WIDTH
	local world_y = (tile_y - 1) * M.TILE_HEIGHT  -- Use TILE_HEIGHT consistently
	local world_z = chunk_world_z + tile_z * M.TILE_HEIGHT

	return world_x, world_y, world_z
end

-- Check if tile coordinates are valid for any chunk
function M.is_valid_tile(x, z)
	if M.world then
		return x >= 1 and x <= M.world.chunk_width and 
		z >= 1 and z <= M.world.chunk_height
	else
		return x >= 1 and x <= M.MAP_WIDTH and 
		z >= 1 and z <= M.MAP_HEIGHT
	end
end

-- Get tile ID at specific coordinates - Now chunk-aware
function M.get_tile_id(tile_x, tile_y, tile_z, chunk_x, chunk_z)
	if M.world then
		-- Use chunk system
		if not M.world then
			return 0
		end

		-- Get the chunk
		local chunk = M.world.get_chunk(chunk_x, chunk_z)
		if not chunk or not chunk.layers then
			return 0
		end

		-- Check bounds
		if tile_x < 1 or tile_x > M.world.chunk_width or 
		tile_z < 1 or tile_z > M.world.chunk_height then
			return 0
		end

		-- Get tile from chunk
		if not chunk.layers[tile_y] or not chunk.layers[tile_y][tile_z] then
			return 0
		end

		return chunk.layers[tile_y][tile_z][tile_x] or 0
	else
		-- Fallback to old system
		if not M.layers or not M.is_valid_tile(tile_x, tile_z) then
			return 0
		end

		if not M.layers[tile_y] or not M.layers[tile_y][tile_z] then
			return 0
		end

		return M.layers[tile_y][tile_z][tile_x] or 0
	end
end

-- Check if tile is solid (non-zero tile_id) - Now chunk-aware
function M.is_tile_solid(tile_x, tile_y, tile_z, chunk_x, chunk_z)
	return M.get_tile_id(tile_x, tile_y, tile_z, chunk_x, chunk_z) ~= 0
end

-- Check if world position is inside a solid tile - Now chunk-aware
function M.is_solid_at_position(world_x, world_y, world_z)
	local tile_x, tile_y, tile_z, chunk_x, chunk_z = M.world_to_tile(world_x, world_y, world_z)
	local is_solid = M.is_tile_solid(tile_x, tile_y, tile_z, chunk_x, chunk_z)

	-- Debug output (remove this once working)
	if M.debug_collision then
		local tile_id = M.get_tile_id(tile_x, tile_y, tile_z, chunk_x, chunk_z)
		print(string.format("is_solid_at_position: world(%.2f,%.2f,%.2f) -> chunk(%d,%d) tile(%d,%d,%d) -> id:%d solid:%s", 
		world_x, world_y, world_z, chunk_x, chunk_z, tile_x, tile_y, tile_z, tile_id, tostring(is_solid)))
	end

	return is_solid
end

-- Get the ground height (top of highest solid tile) at X,Z world position - Now chunk-aware
function M.get_ground_height_at_position(world_x, world_z)
	local tile_x, _, tile_z, chunk_x, chunk_z = M.world_to_tile(world_x, 0, world_z)

	-- Get the chunks
	local chunk = M.world.get_chunk(chunk_x, chunk_z)
	if not chunk or not chunk.layers then
		return 0
	end

	-- Search from top to bottom for the highest solid tile
	for y = #chunk.layers, 1, -1 do
		if M.is_tile_solid(tile_x, y, tile_z, chunk_x, chunk_z) then
			-- Return the top surface of this tile
			return y * M.TILE_HEIGHT  -- Use TILE_HEIGHT consistently
		end
	end

	return 0  -- No solid ground found
end

-- Get all solid tiles in a 3D region - Now chunk-aware
function M.get_solid_tiles_in_region(min_x, min_y, min_z, max_x, max_y, max_z)
	local tiles = {}

	-- Get the range of chunks we need to check
	local min_chunk_x, min_chunk_z = M.world_to_chunk(min_x, min_z)
	local max_chunk_x, max_chunk_z = M.world_to_chunk(max_x, max_z)

	-- Check each chunk in the range
	for chunk_x = min_chunk_x, max_chunk_x do
		for chunk_z = min_chunk_z, max_chunk_z do
			-- Calculate what part of the region intersects with this chunk
			local chunk_world_min_x = chunk_x * M.world.chunk_width * M.TILE_WIDTH
			local chunk_world_max_x = chunk_world_min_x + M.world.chunk_width * M.TILE_WIDTH
			local chunk_world_min_z = chunk_z * M.world.chunk_height * M.TILE_HEIGHT
			local chunk_world_max_z = chunk_world_min_z + M.world.chunk_height * M.TILE_HEIGHT

			local region_min_x = math.max(min_x, chunk_world_min_x)
			local region_max_x = math.min(max_x, chunk_world_max_x)
			local region_min_z = math.max(min_z, chunk_world_min_z)
			local region_max_z = math.min(max_z, chunk_world_max_z)

			if region_min_x <= region_max_x and region_min_z <= region_max_z then
				local tile_min_x, tile_min_y, tile_min_z, _, _ = M.world_to_tile(region_min_x, min_y, region_min_z)
				local tile_max_x, tile_max_y, tile_max_z, _, _ = M.world_to_tile(region_max_x, max_y, region_max_z)

				for y = tile_min_y, tile_max_y do
					for z = tile_min_z, tile_max_z do
						for x = tile_min_x, tile_max_x do
							if M.is_tile_solid(x, y, z, chunk_x, chunk_z) then
								local world_x, world_y, world_z = M.tile_to_world(x, y, z, chunk_x, chunk_z)
								table.insert(tiles, {
									tile_x = x, tile_y = y, tile_z = z,
									chunk_x = chunk_x, chunk_z = chunk_z,
									world_x = world_x, world_y = world_y, world_z = world_z,
									tile_id = M.get_tile_id(x, y, z, chunk_x, chunk_z)
								})
							end
						end
					end
				end
			end
		end
	end

	return tiles
end

-- Collision detection for a rectangular object - Now chunk-aware
function M.check_collision(x, y, z, width, height, depth)
	local results = {
		collision = false,
		ground_height = 0,
		blocking_tiles = {}
	}

	-- Calculate the bounding box
	-- Note: width=X, height=Z, depth=Y in your coordinate system
	local min_x = x - width / 2   -- X extent
	local max_x = x + width / 2
	local min_y = y               -- Y is height (bottom of object)
	local max_y = y + depth       -- Y is height (top of object)
	local min_z = z - height / 2  -- Z extent (forward/back)
	local max_z = z + height / 2

	-- Get ground height at this position
	results.ground_height = M.get_ground_height_at_position(x, z)

	-- Get all solid tiles in the object's bounding box
	local solid_tiles = M.get_solid_tiles_in_region(min_x, min_y, min_z, max_x, max_y, max_z)

	for _, tile in ipairs(solid_tiles) do
		-- Calculate tile bounding box
		local tile_min_x = tile.world_x - M.TILE_WIDTH / 2
		local tile_max_x = tile.world_x + M.TILE_WIDTH / 2
		local tile_min_y = tile.world_y - M.TILE_HEIGHT / 2   -- Y is height, use TILE_HEIGHT
		local tile_max_y = tile.world_y + M.TILE_HEIGHT / 2
		local tile_min_z = tile.world_z - M.TILE_HEIGHT / 2  -- Z is forward
		local tile_max_z = tile.world_z + M.TILE_HEIGHT / 2

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
		ground_y = 0,
		blocked_directions = { x = false, y = false, z = false }
	}

	-- Get ground height at target position
	result.ground_y = M.get_ground_height_at_position(target_x, target_z)

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

	-- Try Z movement only
	collision = M.check_collision(current_x, current_y, target_z, width, height, depth)
	if not collision.collision then
		result.z = target_z
	else
		result.blocked_directions.z = true
	end

	-- Try Y movement only (jumping/falling)
	collision = M.check_collision(current_x, target_y, current_z, width, height, depth)
	if not collision.collision then
		result.y = target_y
	else
		result.blocked_directions.y = true
		-- If blocked vertically and trying to fall, snap to ground
		if target_y < current_y and result.ground_y > 0 then
			result.y = result.ground_y
		end
	end

	return result
end

-- Raycast through the tile layers - Now chunk-aware
function M.raycast(start_x, start_y, start_z, end_x, end_y, end_z, step_size)
	step_size = step_size or math.min(M.TILE_WIDTH, M.TILE_HEIGHT, M.TILE_HEIGHT) / 2

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
			local tile_x, tile_y, tile_z, chunk_x, chunk_z = M.world_to_tile(test_x, test_y, test_z)

			return {
				hit = true,
				x = test_x,
				y = test_y,
				z = test_z,
				tile_x = tile_x,
				tile_y = tile_y,
				tile_z = tile_z,
				chunk_x = chunk_x,
				chunk_z = chunk_z,
				tile_id = M.get_tile_id(tile_x, tile_y, tile_z, chunk_x, chunk_z),
				distance = math.sqrt((test_x-start_x)^2 + (test_y-start_y)^2 + (test_z-start_z)^2)
			}
		end
	end

	return { hit = false }
end

return M